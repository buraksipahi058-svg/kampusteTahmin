-- Adım 7: sosyal havuz (MIMARI §4.3). Öğrencilerin açtığı, hakemli, itiraz pencereli SP bahisleri.
--
-- Akış: doğrulanmış öğrenci okulunda ya da üyesi olduğu kümede bahis açar (hakem varsayılan
-- kendisi, kişi başı yatırım sınırı düşük) → herkes yatırır → hakem sonucu girer (status
-- 'settling', itiraz penceresi başlar; yatırımlar kapanır) → pencerede itiraz yoksa zamanlanmış
-- iş sonucu kesinleştirir ve öder → itiraz varsa kullanici_bahsi_denetle izni olan moderatör
-- sonucu onaylar, değiştirir ya da iptal + iade eder. Sonucu değişen / iptal edilen hakeme ihtar
-- yazılır; ihtar sınırına ulaşan kişi sosyal bahis açamaz ve hakem olamaz. Hakem süresi içinde
-- sonuç girmezse bahis iptal + iade edilir, hakeme ihtar yazılır.
-- Rakamlar economy_settings'te (taslak).

create extension if not exists pg_cron with schema pg_catalog;

-- ---------------------------------------------------------------------------
-- Ayarlar, kolonlar, itirazlar
-- ---------------------------------------------------------------------------

alter table public.economy_settings
  add column social_max_stake_sp integer not null default 100 check (social_max_stake_sp > 0),
  add column social_dispute_hours integer not null default 12 check (social_dispute_hours between 1 and 168),
  add column social_result_deadline_days integer not null default 7 check (social_result_deadline_days between 1 and 60),
  add column referee_strike_limit integer not null default 3 check (referee_strike_limit > 0);

-- Kullanıcı bu kolonu değiştiremez (profiles'ta yalnızca ad / soyad / bölüm güncellenebilir).
alter table public.profiles
  add column referee_strikes integer not null default 0 check (referee_strikes >= 0);

alter table public.bets
  add column proposed_option_id uuid,
  add column result_submitted_at timestamptz,
  add column dispute_until timestamptz,
  add constraint bets_proposed_option_same_bet
    foreign key (proposed_option_id, id) references public.bet_options (id, bet_id),
  add constraint bets_settling_has_result
    check (status <> 'settling' or (proposed_option_id is not null and dispute_until is not null));

create type public.dispute_status as enum ('open', 'resolved');
create type public.dispute_decision as enum ('confirmed', 'changed', 'cancelled');

create table public.bet_disputes (
  id uuid primary key default gen_random_uuid(),
  bet_id uuid not null references public.bets (id) on delete restrict,
  raised_by uuid not null references public.profiles (id) on delete restrict,
  reason text not null check (char_length(reason) between 3 and 500 and reason = btrim(reason)),
  status public.dispute_status not null default 'open',
  decision public.dispute_decision,
  resolved_by uuid references public.profiles (id) on delete restrict,
  resolution_note text check (resolution_note is null or (char_length(resolution_note) between 3 and 500 and resolution_note = btrim(resolution_note))),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  unique (bet_id, raised_by),
  constraint bet_disputes_resolution_fields
    check ((status = 'resolved') = (decision is not null and resolved_by is not null and resolved_at is not null))
);
create index bet_disputes_open_idx on public.bet_disputes (bet_id) where status = 'open';
create index bet_disputes_raised_by_idx on public.bet_disputes (raised_by);

-- ---------------------------------------------------------------------------
-- Görünürlük
-- ---------------------------------------------------------------------------

-- Moderatör, okulundaki özel grup bahislerini de görür (itirazları çözebilmek için).
drop policy bets_select on public.bets;
create policy bets_select on public.bets
  for select to authenticated
  using (
    cluster_id in (select private.my_cluster_ids())
    or (select private.is_superadmin())
    or private.has_permission(cluster_id, 'kullanici_bahsi_denetle')
  );

revoke all on public.bet_disputes from anon, authenticated;
grant select on public.bet_disputes to authenticated;
alter table public.bet_disputes enable row level security;

-- İtirazı açan, bahsin hakemi ve moderatör görür (alt sorgu bets RLS'ine tabidir).
create policy bet_disputes_select on public.bet_disputes
  for select to authenticated
  using (
    raised_by = (select auth.uid())
    or exists (
      select 1 from public.bets b
      where b.id = bet_id
        and (b.referee_id = (select auth.uid()) or private.has_permission(b.cluster_id, 'kullanici_bahsi_denetle'))
    )
  );

-- ---------------------------------------------------------------------------
-- İç yardımcılar
-- ---------------------------------------------------------------------------

create function private.referee_restricted(p_user_id uuid) returns boolean
language sql stable set search_path = '' as $$
  select coalesce(
    (select p.referee_strikes >= s.referee_strike_limit
     from public.profiles p cross join public.economy_settings s
     where p.id = p_user_id),
    false
  );
$$;

-- Sosyal bahsi kilitleyerek getirir; yoksa, sosyal değilse ya da görünmüyorsa P0002.
create function private.lock_social_bet(p_bet_id uuid) returns public.bets
language plpgsql set search_path = '' as $$
declare
  v_bet public.bets;
begin
  select * into v_bet from public.bets b where b.id = p_bet_id for update;
  if not found or v_bet.type <> 'sp_social'
     or not (exists (select 1 from private.my_cluster_ids() c where c = v_bet.cluster_id)
             or private.has_permission(v_bet.cluster_id, 'kullanici_bahsi_denetle')) then
    raise exception 'Sosyal bahis bulunamadı' using errcode = 'P0002';
  end if;
  return v_bet;
end;
$$;

-- İtiraz penceresi dolmuş, açık itirazı olmayan sonucu kesinleştirir. Kesinleştiyse true.
create function private.finalize_social_bet(p_bet_id uuid) returns boolean
language plpgsql set search_path = '' as $$
declare
  v_bet public.bets;
begin
  select * into v_bet from public.bets b where b.id = p_bet_id for update;
  if not found or v_bet.type <> 'sp_social' or v_bet.status <> 'settling' or v_bet.dispute_until > now()
     or exists (select 1 from public.bet_disputes d where d.bet_id = p_bet_id and d.status = 'open') then
    return false;
  end if;
  perform private.settle_bet(p_bet_id, v_bet.proposed_option_id, v_bet.referee_id);
  return true;
end;
$$;

-- Zamanlanmış iş: süresi dolan sonuçları kesinleştirir, sonuç girmeyen hakemin bahsini iptal eder.
-- Bir bahiste hata olursa diğerleri etkilenmez. İşlenen bahis sayısını döner.
create function private.process_social_bets() returns integer
language plpgsql set search_path = '' as $$
declare
  v_cfg public.economy_settings;
  v_bet record;
  v_count integer := 0;
begin
  select * into v_cfg from public.economy_settings s where s.id;

  for v_bet in
    select b.id from public.bets b
    where b.type = 'sp_social' and b.status = 'settling' and b.dispute_until <= now()
    order by b.id
  loop
    begin
      if private.finalize_social_bet(v_bet.id) then
        v_count := v_count + 1;
      end if;
    exception when others then
      raise warning 'Sosyal bahis % kesinleştirilemedi: %', v_bet.id, sqlerrm;
    end;
  end loop;

  for v_bet in
    select b.id, b.referee_id from public.bets b
    where b.type = 'sp_social' and b.status in ('open', 'locked')
      and b.locks_at + make_interval(days => v_cfg.social_result_deadline_days) <= now()
    order by b.id
  loop
    begin
      perform private.cancel_bet(v_bet.id, 'Hakem süresi içinde sonuç girmedi', null);
      update public.profiles set referee_strikes = referee_strikes + 1 where id = v_bet.referee_id;
      v_count := v_count + 1;
    exception when others then
      raise warning 'Sosyal bahis % iptal edilemedi: %', v_bet.id, sqlerrm;
    end;
  end loop;

  return v_count;
end;
$$;

revoke execute on function
  private.referee_restricted(uuid),
  private.lock_social_bet(uuid),
  private.finalize_social_bet(uuid),
  private.process_social_bets()
from public;

-- ---------------------------------------------------------------------------
-- Öğrenci işlemleri
-- ---------------------------------------------------------------------------

create function public.create_social_bet(
  p_cluster_id uuid,
  p_title text,
  p_description text,
  p_options text[],
  p_locks_at timestamptz,
  p_referee_id uuid default null,
  p_max_stake bigint default null
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_referee uuid := coalesce(p_referee_id, (select auth.uid()));
  v_cluster_type public.cluster_type;
  v_cap bigint;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  select c.type into v_cluster_type from public.clusters c
  where c.id = p_cluster_id and c.id in (select private.my_cluster_ids());
  if not found then
    raise exception 'Küme bulunamadı' using errcode = 'P0002';
  end if;
  if private.referee_restricted(v_uid) then
    raise exception 'Çok fazla itiraz kaybettiğin için şimdilik sosyal bahis açamazsın' using errcode = 'KB014';
  end if;
  if not exists (select 1 from public.user_clusters uc where uc.user_id = v_referee and uc.cluster_id = p_cluster_id)
     or not private.is_verified(v_referee) then
    raise exception 'Hakem bu kümenin üyesi olmalı ve okul maili doğrulanmış olmalı' using errcode = '23514';
  end if;
  if private.referee_restricted(v_referee) then
    raise exception 'Seçilen kişinin hakemlik hakkı kısıtlı' using errcode = 'KB014';
  end if;
  if p_locks_at > now() + interval '30 days' then
    raise exception 'Kapanış en fazla 30 gün sonrası olabilir' using errcode = '23514';
  end if;

  select s.social_max_stake_sp into v_cap from public.economy_settings s where s.id;
  if p_max_stake is not null and (p_max_stake < 1 or p_max_stake > v_cap) then
    raise exception 'Kişi başı en fazla yatırım 1 ile % arasında olmalı', v_cap using errcode = '23514';
  end if;

  return private.create_bet(
    v_uid, p_cluster_id, 'sp_social',
    case v_cluster_type when 'school' then 'school' else 'private' end::public.bet_scope,
    p_title, p_description, p_options, p_locks_at, v_referee, 1, coalesce(p_max_stake, v_cap)
  );
end;
$$;

-- Hakem sonucu girer: yatırımlar kapanır, itiraz penceresi başlar. Pencerenin bitişini döner.
create function public.submit_social_result(p_bet_id uuid, p_option_id uuid) returns timestamptz
language plpgsql security definer set search_path = '' as $$
declare
  v_bet public.bets := private.lock_social_bet(p_bet_id);
  v_until timestamptz;
begin
  if v_bet.referee_id is distinct from (select auth.uid()) then
    raise exception 'Sonucu yalnızca bahsin hakemi girebilir' using errcode = '42501';
  end if;
  if v_bet.status in ('settled', 'cancelled') then
    raise exception 'Bahis zaten sonuçlandı ya da iptal edildi' using errcode = 'KB006';
  end if;
  if v_bet.status = 'settling' then
    raise exception 'Bu bahsin sonucu zaten girildi' using errcode = 'KB015';
  end if;
  if not exists (select 1 from public.bet_options o where o.id = p_option_id and o.bet_id = p_bet_id) then
    raise exception 'Seçenek bu bahse ait değil' using errcode = 'P0002';
  end if;

  select now() + make_interval(hours => s.social_dispute_hours) into v_until from public.economy_settings s where s.id;
  update public.bets
  set status = 'settling', proposed_option_id = p_option_id, result_submitted_at = now(), dispute_until = v_until
  where id = p_bet_id;
  return v_until;
end;
$$;

-- Bahse yatırım yapan, itiraz penceresinde hakemin sonucuna itiraz eder.
create function public.dispute_social_result(p_bet_id uuid, p_reason text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_bet public.bets := private.lock_social_bet(p_bet_id);
  v_id uuid;
begin
  if v_bet.status <> 'settling' or v_bet.dispute_until <= now() then
    raise exception 'Bu bahsin sonucuna şu an itiraz edilemez' using errcode = 'KB016';
  end if;
  if not exists (select 1 from public.wagers w where w.bet_id = p_bet_id and w.user_id = v_uid) then
    raise exception 'Yalnızca bu bahse yatırım yapanlar itiraz edebilir' using errcode = '42501';
  end if;
  if exists (select 1 from public.bet_disputes d where d.bet_id = p_bet_id and d.raised_by = v_uid) then
    raise exception 'Bu bahse zaten itiraz ettin' using errcode = '23505';
  end if;

  insert into public.bet_disputes (bet_id, raised_by, reason)
  values (p_bet_id, v_uid, btrim(coalesce(p_reason, '')))
  returning id into v_id;
  return v_id;
end;
$$;

-- Açan, henüz kimse yatırmamışken kendi bahsini geri çekebilir; moderatör her zaman iptal edebilir.
create function public.cancel_social_bet(p_bet_id uuid, p_reason text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_bet public.bets := private.lock_social_bet(p_bet_id);
  v_moderator boolean := private.has_permission(v_bet.cluster_id, 'kullanici_bahsi_denetle');
begin
  if not v_moderator and not (v_bet.creator_id = v_uid and v_bet.status = 'open' and v_bet.pool_total = 0) then
    raise exception 'Bu bahsi yalnızca açan (henüz yatırım yokken) ya da moderatör iptal edebilir' using errcode = '42501';
  end if;
  perform private.cancel_bet(p_bet_id, p_reason, v_uid);
  update public.bet_disputes
  set status = 'resolved', decision = 'cancelled', resolved_by = v_uid, resolved_at = now(), resolution_note = btrim(p_reason)
  where bet_id = p_bet_id and status = 'open';
  if v_moderator then
    insert into public.admin_audit_log (actor_id, action, cluster_id, details)
    values (v_uid, 'social_bet_cancel', v_bet.cluster_id, jsonb_build_object('bet_id', p_bet_id, 'reason', btrim(p_reason)));
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Moderatör: itirazı çözme
-- ---------------------------------------------------------------------------

create function public.resolve_social_dispute(
  p_bet_id uuid,
  p_decision public.dispute_decision,
  p_note text,
  p_option_id uuid default null
) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_bet public.bets := private.lock_social_bet(p_bet_id);
  v_note text := btrim(coalesce(p_note, ''));
begin
  if not private.has_permission(v_bet.cluster_id, 'kullanici_bahsi_denetle') then
    raise exception 'Bu işlem için yetkin yok' using errcode = '42501';
  end if;
  if v_uid = v_bet.referee_id or exists (select 1 from public.wagers w where w.bet_id = p_bet_id and w.user_id = v_uid) then
    raise exception 'İlgili olduğun bahsin itirazını çözemezsin' using errcode = '42501';
  end if;
  if v_bet.status <> 'settling'
     or not exists (select 1 from public.bet_disputes d where d.bet_id = p_bet_id and d.status = 'open') then
    raise exception 'Çözülecek açık itiraz yok' using errcode = 'KB017';
  end if;
  if char_length(v_note) < 3 then
    raise exception 'Karar gerekçesi yazılmalı (en az 3 karakter)' using errcode = '23514';
  end if;

  case p_decision
    when 'confirmed' then
      perform private.settle_bet(p_bet_id, v_bet.proposed_option_id, v_uid);
    when 'changed' then
      if p_option_id is null or p_option_id = v_bet.proposed_option_id
         or not exists (select 1 from public.bet_options o where o.id = p_option_id and o.bet_id = p_bet_id) then
        raise exception 'Hakemin sonucundan farklı bir seçenek seç' using errcode = '23514';
      end if;
      perform private.settle_bet(p_bet_id, p_option_id, v_uid);
      update public.profiles set referee_strikes = referee_strikes + 1 where id = v_bet.referee_id;
    when 'cancelled' then
      perform private.cancel_bet(p_bet_id, v_note, v_uid);
      update public.profiles set referee_strikes = referee_strikes + 1 where id = v_bet.referee_id;
  end case;

  update public.bet_disputes
  set status = 'resolved', decision = p_decision, resolved_by = v_uid, resolved_at = now(), resolution_note = v_note
  where bet_id = p_bet_id and status = 'open';

  insert into public.admin_audit_log (actor_id, action, target_user_id, cluster_id, details)
  values (v_uid, 'social_dispute_resolve', v_bet.referee_id, v_bet.cluster_id,
          jsonb_build_object('bet_id', p_bet_id, 'decision', p_decision, 'option_id', p_option_id));
end;
$$;

revoke execute on function
  public.create_social_bet(uuid, text, text, text[], timestamptz, uuid, bigint),
  public.submit_social_result(uuid, uuid),
  public.dispute_social_result(uuid, text),
  public.cancel_social_bet(uuid, text),
  public.resolve_social_dispute(uuid, public.dispute_decision, text, uuid)
from public, anon;

grant execute on function
  public.create_social_bet(uuid, text, text, text[], timestamptz, uuid, bigint),
  public.submit_social_result(uuid, uuid),
  public.dispute_social_result(uuid, text),
  public.cancel_social_bet(uuid, text),
  public.resolve_social_dispute(uuid, public.dispute_decision, text, uuid)
to authenticated;

-- ---------------------------------------------------------------------------
-- Zamanlanmış iş: 5 dakikada bir
-- ---------------------------------------------------------------------------

select cron.schedule('kampusbet_sosyal_bahisler', '*/5 * * * *', 'select private.process_social_bets()');
