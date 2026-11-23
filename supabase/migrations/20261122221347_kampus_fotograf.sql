-- Adım 17b: fotoğraflı kampüs görevleri, onay kuyruğu, 30 gün sonra silme (KARARLAR "Kampüs görevleri").
--
-- Öğrenci fotoğrafı uygulamada kamerayla çeker (galeri yok), uygulama küçültüp konum ve cihaz bilgisini (EXIF)
-- siler, kişiye özel depolama alanına (`campus-proofs`, herkese kapalı) yükler, sonra gönderiyi bildirir. Görevin
-- okulundaki yetkili (`kampus_gorevi_yonet`) ya da süperadmin onaylar (ödül o an) ya da gerekçeyle reddeder.
-- Fotoğrafı yalnızca sahibi ve okulun yetkilisi görür. 7 gün içinde karara bağlanmayan gönderi düşer.
-- Fotoğraf karardan 30 gün sonra, hesap silinince hemen silinir: veritabanı Storage API'yi pg_net ile çağırır;
-- bunun için Supabase Vault'ta servis anahtarı gerekir (kullanıcının işi, `private.storage_settings`). Anahtar
-- yoksa silme bekler (fotoğraf kalır), anahtar konunca iş kaldığı yerden devam eder.

-- ---------------------------------------------------------------------------
-- Depolama alanı ve erişim
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('campus-proofs', 'campus-proofs', false, 2097152, array['image/jpeg'])
on conflict (id) do nothing;

-- Yükleme: yalnızca kendi klasörüne (`<kişi>/<rastgele>.jpg`), okul maili doğrulanmış, yasaklı değil, saatte en fazla 10.
create function private.campus_upload_allowed(p_name text) returns boolean
language sql stable security definer set search_path = '' as $$
  select (select auth.uid()) is not null
    and p_name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.jpg$'
    and split_part(p_name, '/', 1) = (select auth.uid())::text
    and private.is_verified((select auth.uid()))
    and not exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.banned_at is not null)
    and (select count(*) from storage.objects o
         where o.bucket_id = 'campus-proofs' and o.name like (select auth.uid())::text || '/%'
           and o.created_at > now() - interval '1 hour') < 10;
$$;

-- Okuma: fotoğrafın sahibi, sahibin okulunda kampüs görevi yöneten, süperadmin.
create function private.campus_proof_readable(p_name text) returns boolean
language plpgsql stable security definer set search_path = '' as $$
declare
  v_owner uuid;
begin
  if (select auth.uid()) is null then
    return false;
  end if;
  begin
    v_owner := split_part(p_name, '/', 1)::uuid;
  exception when invalid_text_representation then
    return false;
  end;
  return v_owner = (select auth.uid())
    or private.has_permission(private.school_of_user(v_owner), 'kampus_gorevi_yonet');
end;
$$;

revoke execute on function private.campus_upload_allowed(text), private.campus_proof_readable(text) from public;
grant execute on function private.campus_upload_allowed(text), private.campus_proof_readable(text) to authenticated;

create policy campus_proofs_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'campus-proofs' and private.campus_upload_allowed(name));

create policy campus_proofs_select on storage.objects
  for select to authenticated
  using (bucket_id = 'campus-proofs' and private.campus_proof_readable(name));
-- Güncelleme ve silme politikası yok: istemci fotoğrafı değiştiremez ve silemez (silme sunucunun işi).

-- Fotoğraf silme ayarı: proje adresi ve servis anahtarının Vault'taki adı (anahtarı kullanıcı koyar).
create table private.storage_settings (
  id boolean primary key default true check (id),
  project_url text check (project_url is null or project_url ~ '^https://[a-z0-9.-]+$'),
  service_key_secret_name text not null default 'kampusbet_storage_service_key'
);
insert into private.storage_settings default values;
alter table private.storage_settings enable row level security;
revoke all on private.storage_settings from public, anon, authenticated;

-- Depolamadan siler (Storage API, pg_net; yanıt beklenmez). Ayar ya da anahtar yoksa false.
create function private.storage_delete(p_paths text[]) returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_cfg private.storage_settings;
  v_key text;
  v_headers jsonb;
begin
  if p_paths is null or cardinality(p_paths) = 0 then
    return true;
  end if;
  select * into v_cfg from private.storage_settings s where s.id;
  if v_cfg.project_url is null then
    return false;
  end if;
  select s.decrypted_secret into v_key from vault.decrypted_secrets s where s.name = v_cfg.service_key_secret_name;
  if v_key is null then
    return false;
  end if;
  v_headers := jsonb_build_object('apikey', v_key, 'Content-Type', 'application/json');
  -- Eski (JWT) servis anahtarı Authorization'da da beklenir; yeni gizli anahtar (sb_secret_) yalnızca apikey'de.
  if v_key like 'ey%' then
    v_headers := v_headers || jsonb_build_object('Authorization', 'Bearer ' || v_key);
  end if;
  perform net.http_delete(
    url := v_cfg.project_url || '/storage/v1/object/campus-proofs',
    body := jsonb_build_object('prefixes', to_jsonb(p_paths)),
    headers := v_headers,
    timeout_milliseconds := 10000
  );
  return true;
end;
$$;
revoke execute on function private.storage_delete(text[]) from public;

-- ---------------------------------------------------------------------------
-- Gönderiler
-- ---------------------------------------------------------------------------

alter table public.campus_task_submissions
  add column photo_delete_after timestamptz,
  add column photo_deleted_at timestamptz,
  add constraint campus_submissions_photo_path check (
    photo_path is null or photo_path ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.jpg$'
  ),
  add constraint campus_submissions_photo_method check ((method = 'photo') = (photo_path is not null));
create unique index campus_submissions_photo_unique on public.campus_task_submissions (photo_path) where photo_path is not null;
create index campus_submissions_pending on public.campus_task_submissions (created_at) where status = 'pending';

alter table public.notifications drop constraint notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check check (kind in (
  'bet_won', 'bet_lost', 'bet_refunded', 'bet_cancelled', 'social_result', 'dispute_received', 'dispute_new',
  'dispute_resolved', 'duel_invite', 'duel_accepted', 'level_up', 'referee_strike', 'referee_due', 'admin_grant',
  'campus_approved', 'campus_rejected', 'campus_expired', 'campus_review_new'
));

-- Fotoğraf gönder: dosya önce kişinin klasörüne yüklenmiş olmalı. Ret: KB002 doğrulanmamış, P0002 görünmeyen görev,
-- 42501 yöneten, KB032 açık değil, KB034 fotoğraf yok / kullanılmış, KB030 bu dönem bekleyen ya da onaylı var,
-- KB031 kontenjan doldu.
create function public.submit_campus_task_photo(p_task_id uuid, p_path text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_task public.campus_tasks;
  v_ps timestamptz;
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  if not exists (select 1 from public.profiles p where p.id = v_uid and p.deleted_at is null) then
    raise exception 'Profil bulunamadı' using errcode = 'P0002';
  end if;
  if not private.is_verified(v_uid) then
    raise exception 'Kampüs görevi için okul mailini doğrulamalısın' using errcode = 'KB002';
  end if;
  select * into v_task from public.campus_tasks t
  where t.id = p_task_id and t.school_id = private.current_school_id()
  for no key update;
  if not found then
    raise exception 'Görev bulunamadı' using errcode = 'P0002';
  end if;
  if private.has_permission(v_task.school_id, 'kampus_gorevi_yonet') then
    raise exception 'Kampüs görevlerini yöneten ödül alamaz' using errcode = '42501';
  end if;
  if not v_task.active or v_task.verification <> 'photo'
     or (v_task.starts_at is not null and v_task.starts_at > now())
     or (v_task.ends_at is not null and v_task.ends_at <= now()) then
    raise exception 'Bu görev şu an açık değil' using errcode = 'KB032';
  end if;
  if p_path is null or split_part(p_path, '/', 1) <> v_uid::text
     or not exists (select 1 from storage.objects o where o.bucket_id = 'campus-proofs' and o.name = p_path)
     or exists (select 1 from public.campus_task_submissions s where s.photo_path = p_path) then
    raise exception 'Fotoğraf bulunamadı ya da daha önce kullanıldı' using errcode = 'KB034';
  end if;

  v_ps := private.campus_period_start(v_task.period, now());
  if exists (select 1 from public.campus_task_submissions s
             where s.task_id = v_task.id and s.user_id = v_uid and s.period_start = v_ps
               and s.status in ('pending', 'approved')) then
    raise exception 'Bu görevi bu dönem zaten yaptın ya da onay bekliyor' using errcode = 'KB030';
  end if;
  if v_task.quota is not null and (select count(*) from public.campus_task_submissions s
                                   where s.task_id = v_task.id and s.status = 'approved') >= v_task.quota then
    raise exception 'Görevin kontenjanı doldu' using errcode = 'KB031';
  end if;

  insert into public.campus_task_submissions (task_id, user_id, period_start, method, status, photo_path,
                                              reward_currency, reward_amount, reward_xp)
  values (v_task.id, v_uid, v_ps, 'photo', 'pending', p_path, v_task.reward_currency, v_task.reward_amount,
          v_task.reward_xp)
  returning id into v_id;

  -- Okulun yetkililerine haber (görev başına günde bir).
  insert into public.notifications (user_id, kind, title, body, link, dedupe_key)
  select distinct pm.user_id, 'campus_review_new', 'Onay bekleyen fotoğraf',
         left('«' || v_task.title || '» için onay bekleyen gönderi var (yönetim paneli > Kampüs görevleri > Onay).', 400),
         null::text, 'campus_review:' || v_task.id || ':' || to_char(now() at time zone 'Europe/Istanbul', 'YYYYMMDD')
  from public.permissions pm join public.profiles p on p.id = pm.user_id and p.deleted_at is null
  where pm.cluster_id = v_task.school_id and pm.permission_key = 'kampus_gorevi_yonet'
  on conflict do nothing;
  return v_id;
end;
$$;

-- Onayla (ödül o an) ya da gerekçeyle reddet. Ret: P0002 görünmeyen, KB033 zaten karara bağlandı, KB031 kontenjan,
-- 23514 gerekçe yok.
create function public.review_campus_submission(p_submission_id uuid, p_approve boolean, p_note text default null)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_s public.campus_task_submissions;
  v_task public.campus_tasks;
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  select * into v_s from public.campus_task_submissions s where s.id = p_submission_id;
  if not found then
    raise exception 'Gönderi bulunamadı' using errcode = 'P0002';
  end if;
  -- Kilit sırası gönderiyle aynı: önce görev satırı (kontenjan), sonra gönderi.
  select * into v_task from public.campus_tasks t where t.id = v_s.task_id for no key update;
  if not private.has_permission(v_task.school_id, 'kampus_gorevi_yonet') then
    raise exception 'Gönderi bulunamadı' using errcode = 'P0002';
  end if;
  select * into v_s from public.campus_task_submissions s where s.id = p_submission_id for update;
  if v_s.status <> 'pending' then
    raise exception 'Bu gönderi zaten karara bağlandı' using errcode = 'KB033';
  end if;
  if p_approve is null or (not p_approve and (v_note is null or char_length(v_note) < 3)) then
    raise exception 'Reddederken gerekçe yaz (en az 3 karakter)' using errcode = '23514';
  end if;

  if p_approve then
    if v_task.quota is not null and (select count(*) from public.campus_task_submissions s
                                     where s.task_id = v_task.id and s.status = 'approved') >= v_task.quota then
      raise exception 'Görevin kontenjanı doldu' using errcode = 'KB031';
    end if;
    update public.campus_task_submissions s
    set status = 'approved', reviewed_by = v_uid, reviewed_at = now(), review_note = v_note,
        photo_delete_after = now() + interval '30 days'
    where s.id = v_s.id;
    perform private.pay_campus_submission(v_s.id);
    insert into public.notifications (user_id, kind, title, body, link, dedupe_key)
    select v_s.user_id, 'campus_approved', 'Kampüs görevin onaylandı',
           left('«' || v_task.title || '»: +' || v_s.reward_amount || ' ' || v_s.reward_currency
                || case when v_s.reward_xp > 0 then ' · +' || v_s.reward_xp || ' XP' else '' end || ' hesabında.', 400),
           '/kampus-gorevleri', 'campus_review_done:' || v_s.id
    from public.profiles p where p.id = v_s.user_id and p.deleted_at is null
    on conflict do nothing;
  else
    update public.campus_task_submissions s
    set status = 'rejected', reviewed_by = v_uid, reviewed_at = now(), review_note = v_note,
        photo_delete_after = now() + interval '30 days'
    where s.id = v_s.id;
    insert into public.notifications (user_id, kind, title, body, link, dedupe_key)
    select v_s.user_id, 'campus_rejected', 'Kampüs görevin reddedildi',
           left('«' || v_task.title || '»: ' || v_note || ' Yeniden deneyebilirsin.', 400),
           '/kampus-gorevleri', 'campus_review_done:' || v_s.id
    from public.profiles p where p.id = v_s.user_id and p.deleted_at is null
    on conflict do nothing;
  end if;

  insert into public.admin_audit_log (actor_id, action, target_user_id, cluster_id, details)
  values (v_uid, 'campus_review', v_s.user_id, v_task.school_id,
          jsonb_build_object('submission_id', v_s.id, 'task_id', v_task.id, 'approved', p_approve, 'note', v_note));
end;
$$;

revoke execute on function
  public.submit_campus_task_photo(uuid, text),
  public.review_campus_submission(uuid, boolean, text)
from public, anon;
grant execute on function
  public.submit_campus_task_photo(uuid, text),
  public.review_campus_submission(uuid, boolean, text)
to authenticated;

-- ---------------------------------------------------------------------------
-- Zamanlanmış iş: bekleyeni düşür, süresi gelen fotoğrafı ve sahipsiz yüklemeyi sil
-- ---------------------------------------------------------------------------

create function private.process_campus_submissions() returns void
language plpgsql set search_path = '' as $$
declare
  v_paths text[];
begin
  -- 7 günde karara bağlanmayan gönderi düşer; fotoğrafı 30 gün sonra silinir.
  with expired as (
    update public.campus_task_submissions s
    set status = 'expired', reviewed_at = now(), photo_delete_after = now() + interval '30 days'
    where s.status = 'pending' and s.created_at < now() - interval '7 days'
    returning s.id, s.user_id, s.task_id
  )
  insert into public.notifications (user_id, kind, title, body, link, dedupe_key)
  select e.user_id, 'campus_expired', 'Kampüs gönderinin süresi doldu',
         left('«' || t.title || '» gönderin 7 gün içinde onaylanmadı. Yeniden deneyebilirsin.', 400),
         '/kampus-gorevleri', 'campus_review_done:' || e.id
  from expired e join public.campus_tasks t on t.id = e.task_id
  join public.profiles p on p.id = e.user_id and p.deleted_at is null
  on conflict do nothing;

  -- Süresi gelen fotoğraflar (en fazla 100); silme isteği gönderilebildiyse işaretlenir.
  select array_agg(x.photo_path) into v_paths from (
    select s.photo_path from public.campus_task_submissions s
    where s.photo_path is not null and s.photo_deleted_at is null and s.photo_delete_after <= now()
    order by s.photo_delete_after limit 100
  ) x;
  if v_paths is not null and private.storage_delete(v_paths) then
    update public.campus_task_submissions s set photo_deleted_at = now() where s.photo_path = any (v_paths);
  end if;

  -- Sahipsiz yüklemeler (gönderiye bağlanmamış ya da silinmiş işaretli, 1 günden eski): yeniden silme dener.
  select array_agg(x.name) into v_paths from (
    select o.name from storage.objects o
    where o.bucket_id = 'campus-proofs' and o.created_at < now() - interval '1 day'
      and not exists (select 1 from public.campus_task_submissions s
                      where s.photo_path = o.name and s.photo_deleted_at is null)
    limit 100
  ) x;
  perform private.storage_delete(v_paths);
end;
$$;
revoke execute on function private.process_campus_submissions() from public;

select cron.schedule('kampusbet_kampus_gonderileri', '17 * * * *', 'select private.process_campus_submissions()');

-- Hesap silinince fotoğrafları hemen silinsin (profil tetikleyicisi; bildirimleri silmeyle birlikte).
create or replace function private.notify_profile() returns trigger
language plpgsql set search_path = '' as $$
declare
  v_limit integer;
begin
  if new.deleted_at is not null then
    if old.deleted_at is null then
      delete from public.notifications n where n.user_id = new.id;
      update public.campus_task_submissions s set photo_delete_after = now()
      where s.user_id = new.id and s.photo_path is not null and s.photo_deleted_at is null;
    end if;
    return null;
  end if;
  if new.level > old.level then
    insert into public.notifications (user_id, kind, title, body, link, dedupe_key)
    values (new.id, 'level_up', 'Seviye ' || new.level || '!',
            'Tebrikler, ' || new.level || '. seviyeye ulaştın. Markette seviyeyle açılan ürünlere göz at.',
            '/market', 'level:' || new.level)
    on conflict do nothing;
  end if;
  if new.referee_strikes > old.referee_strikes then
    select s.referee_strike_limit into v_limit from public.economy_settings s where s.id;
    insert into public.notifications (user_id, kind, title, body, link)
    values (new.id, 'referee_strike', 'Hakem ihtarı aldın',
            'Hakemi olduğun bir bahis yüzünden ihtar aldın (' || new.referee_strikes || '/' || v_limit
            || '). Sınıra ulaşınca hakemlik ve sosyal bahis açma kısıtlanır.', '/profil');
  end if;
  return null;
end;
$$;
revoke execute on function private.notify_profile() from public;
