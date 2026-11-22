-- Adım 13: yönetim ve güvenlik eksikleri (docs/harita/acik-isler.md; KARARLAR "Yönetim araçları").
--
-- 1. İstek bekçisi: PostgREST her API isteğinden önce `guard.check_request()`'i çağırır (db_pre_request).
--    Silinmiş ya da yasaklı hesabın elindeki erişim anahtarı süresi dolmadan da hiçbir istek geçmez (KB025).
--    Bekçi API'ye açık olmayan ayrı bir şemada; anonim ve giriş yapan çalıştırabilir (yalnızca okur).
-- 2. Süperadmin kullanıcı yasaklar / yasağı kaldırır: profil işareti + Supabase Auth engeli + oturumlar kapanır.
-- 3. Hakem ihtarını sıfırlama: süperadmin ya da kişinin okulunda `kullanici_bahsi_denetle` olan moderatör.
-- 4. Açık resmi bahiste (sabit oran) oran değiştirme; yapılmış yatırımlar kendi oranıyla kalır.

-- ---------------------------------------------------------------------------
-- Yasak bilgisi
-- ---------------------------------------------------------------------------

alter table public.profiles
  add column banned_at timestamptz,
  add column banned_reason text check (banned_reason is null or (char_length(banned_reason) between 3 and 300
                                                                 and banned_reason = btrim(banned_reason)));

-- ---------------------------------------------------------------------------
-- İstek bekçisi (db_pre_request)
-- ---------------------------------------------------------------------------

create schema guard;
revoke all on schema guard from public;
grant usage on schema guard to anon, authenticated;

create function guard.check_request() returns void
language plpgsql stable security definer set search_path = '' as $$
begin
  if exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and (p.deleted_at is not null or p.banned_at is not null)
  ) then
    raise exception 'Bu hesap kullanılamıyor' using errcode = 'KB025';
  end if;
end;
$$;

revoke execute on function guard.check_request() from public;
grant execute on function guard.check_request() to anon, authenticated;

alter role authenticator set pgrst.db_pre_request to 'guard.check_request';
notify pgrst, 'reload config';

-- ---------------------------------------------------------------------------
-- Yasaklama
-- ---------------------------------------------------------------------------

create function public.set_user_ban(p_user_id uuid, p_banned boolean, p_reason text default null) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_target public.profiles;
  v_reason text := btrim(coalesce(p_reason, ''));
begin
  if v_uid is null or not private.is_superadmin() then
    raise exception 'Bu işlem yalnızca süperadmin içindir' using errcode = '42501';
  end if;
  if p_user_id = v_uid then
    raise exception 'Kendini yasaklayamazsın' using errcode = '42501';
  end if;
  select * into v_target from public.profiles p where p.id = p_user_id for no key update;
  if not found or v_target.deleted_at is not null then
    raise exception 'Kullanıcı bulunamadı' using errcode = 'P0002';
  end if;
  if v_target.role = 'superadmin' then
    raise exception 'Süperadmin yasaklanamaz' using errcode = '42501';
  end if;

  if coalesce(p_banned, false) then
    if char_length(v_reason) < 3 then
      raise exception 'Yasak gerekçesi yazılmalı (en az 3 karakter)' using errcode = '23514';
    end if;
    update public.profiles set banned_at = now(), banned_reason = left(v_reason, 300) where id = p_user_id;
    update auth.users set banned_until = now() + interval '100 years', updated_at = now() where id = p_user_id;
    delete from auth.sessions where user_id = p_user_id;
    delete from auth.refresh_tokens where user_id = p_user_id::text;
  else
    update public.profiles set banned_at = null, banned_reason = null where id = p_user_id;
    update auth.users set banned_until = null, updated_at = now() where id = p_user_id;
  end if;

  insert into public.admin_audit_log (actor_id, action, target_user_id, cluster_id, details)
  values (v_uid, case when coalesce(p_banned, false) then 'user_ban' else 'user_unban' end, p_user_id,
          v_target.school_id, jsonb_build_object('reason', nullif(v_reason, '')));
end;
$$;

-- ---------------------------------------------------------------------------
-- Hakem ihtarını sıfırlama
-- ---------------------------------------------------------------------------

create function public.reset_referee_strikes(p_user_id uuid, p_note text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_target public.profiles;
  v_note text := btrim(coalesce(p_note, ''));
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  select * into v_target from public.profiles p where p.id = p_user_id for no key update;
  if not found or v_target.deleted_at is not null
     or not (private.is_superadmin() or v_target.school_id = private.current_school_id()) then
    raise exception 'Kullanıcı bulunamadı' using errcode = 'P0002';
  end if;
  if not private.has_permission(v_target.school_id, 'kullanici_bahsi_denetle') then
    raise exception 'Bu işlem için yetkin yok' using errcode = '42501';
  end if;
  if p_user_id = v_uid then
    raise exception 'Kendi ihtarını sıfırlayamazsın' using errcode = '42501';
  end if;
  if char_length(v_note) < 3 then
    raise exception 'Gerekçe yazılmalı (en az 3 karakter)' using errcode = '23514';
  end if;

  update public.profiles set referee_strikes = 0 where id = p_user_id;
  insert into public.admin_audit_log (actor_id, action, target_user_id, cluster_id, details)
  values (v_uid, 'referee_strikes_reset', p_user_id, v_target.school_id,
          jsonb_build_object('previous', v_target.referee_strikes, 'note', left(v_note, 300)));
end;
$$;

-- ---------------------------------------------------------------------------
-- Resmi bahiste oran değiştirme
-- ---------------------------------------------------------------------------

create function public.update_official_bet_odds(p_bet_id uuid, p_odds numeric[]) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_bet public.bets;
  v_school uuid;
  v_old numeric[];
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  -- Bahis satırı kilitlenir: aynı anda gelen yatırım ya eski ya yeni oranı görür, ikisinin karışımını değil.
  select * into v_bet from public.bets b where b.id = p_bet_id and b.type = 'ssp_official' for update;
  if not found then
    raise exception 'Bahis bulunamadı' using errcode = 'P0002';
  end if;
  select c.school_id into v_school from public.clusters c where c.id = v_bet.cluster_id;
  if not private.has_permission(v_school, 'resmi_bahis_ac') then
    raise exception 'Bu işlem için yetkin yok' using errcode = '42501';
  end if;
  if v_bet.odds_mode <> 'fixed' then
    raise exception 'Bu bahiste oran yok (havuzlu)' using errcode = '23514';
  end if;
  if v_bet.status <> 'open' or now() >= v_bet.locks_at then
    raise exception 'Bahis yatırıma kapalı, oran değiştirilemez' using errcode = 'KB003';
  end if;
  if p_odds is null or cardinality(p_odds) <> (select count(*) from public.bet_options o where o.bet_id = p_bet_id)
     or array_position(p_odds, null) is not null then
    raise exception 'Her seçenek için bir oran girilmeli' using errcode = '23514';
  end if;

  select array_agg(o.odds order by o.position) into v_old from public.bet_options o where o.bet_id = p_bet_id;
  -- Aralık (1,01–20,00) kolon kısıtıyla denetlenir.
  update public.bet_options o set odds = p_odds[o.position] where o.bet_id = p_bet_id;

  insert into public.admin_audit_log (actor_id, action, cluster_id, details)
  values (v_uid, 'official_bet_odds', v_bet.cluster_id,
          jsonb_build_object('bet_id', p_bet_id, 'old', v_old, 'new', p_odds));
end;
$$;

revoke execute on function
  public.set_user_ban(uuid, boolean, text),
  public.reset_referee_strikes(uuid, text),
  public.update_official_bet_odds(uuid, numeric[])
from public, anon;
grant execute on function
  public.set_user_ban(uuid, boolean, text),
  public.reset_referee_strikes(uuid, text),
  public.update_official_bet_odds(uuid, numeric[])
to authenticated;
