-- Adım 17a: kampüs görevleri, QR doğrulamalı (KARARLAR "Kampüs görevleri").
--
-- Okulun yetkilisi (`kampus_gorevi_yonet`) ya da süperadmin "yemekhanede ye", "kütüphaneye git" gibi görev açar.
-- Öğrenci mekândaki QR'ı uygulamadan okutur; kod doğruysa ödül (SP + XP; süperadminin açtığında SSP de olabilir)
-- hemen verilir. Fotoğraflı görevler (onay kuyruğu) Adım 17b'de.
--
-- QR kodu sunucudaki gizli anahtardan HMAC ile üretilir; anahtar istemciye hiç açılmaz (`private`).
--   * Basılı QR (`qr_rotation_seconds = 0`): kod sabittir; sızarsa yetkili "QR'ı yenile" der, eski kod geçersizleşir.
--   * Ekran QR'ı (30–300 sn): kod döner; yetkili mekândaki ekranda admin panelinin QR sayfasını açık tutar.
--     Bir önceki dilimin kodu da kabul edilir (okutma sırasında değişebilir).
-- Kişi görevi dönem başına (bir kez / günlük / haftalık) bir kez yapar; toplam kontenjan (ör. ilk 100 kişi) olabilir.
-- Görevi yönetebilen (okulunda `kampus_gorevi_yonet`) ve süperadmin ödülü alamaz.

-- ---------------------------------------------------------------------------
-- Tablolar
-- ---------------------------------------------------------------------------

create type public.campus_verification as enum ('qr', 'photo');
create type public.campus_period as enum ('once', 'daily', 'weekly');
create type public.campus_submission_status as enum ('pending', 'approved', 'rejected', 'expired');

create table public.campus_tasks (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.clusters (id) on delete restrict,
  title text not null check (char_length(title) between 3 and 80 and title = btrim(title) and title !~ '[[:cntrl:]]'),
  description text check (description is null or (char_length(description) between 1 and 300
                                                    and description = btrim(description) and description !~ '[[:cntrl:]]')),
  icon text not null default '📍' check (char_length(icon) between 1 and 8),
  verification public.campus_verification not null,
  period public.campus_period not null default 'once',
  reward_currency public.currency not null default 'SP',
  reward_amount integer not null check (reward_amount between 1 and 1000),
  reward_xp integer not null default 0 check (reward_xp between 0 and 500),
  quota integer check (quota is null or quota between 1 and 100000),
  qr_rotation_seconds integer not null default 0 check (qr_rotation_seconds in (0, 30, 60, 120, 300)),
  starts_at timestamptz,
  ends_at timestamptz,
  active boolean not null default true,
  created_by uuid not null references public.profiles (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint campus_tasks_window check (starts_at is null or ends_at is null or ends_at > starts_at)
);
create index campus_tasks_school_idx on public.campus_tasks (school_id);

-- QR anahtarı: yalnızca sunucu (API'ye kapalı şema).
create table private.campus_task_secrets (
  task_id uuid primary key references public.campus_tasks (id) on delete cascade,
  secret bytea not null default extensions.gen_random_bytes(32),
  rotated_at timestamptz not null default now()
);
alter table private.campus_task_secrets enable row level security;
revoke all on private.campus_task_secrets from public, anon, authenticated;

create table public.campus_task_submissions (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.campus_tasks (id) on delete restrict,
  user_id uuid not null references public.profiles (id) on delete restrict,
  period_start timestamptz not null,
  method public.campus_verification not null,
  status public.campus_submission_status not null,
  photo_path text,
  reviewed_by uuid references public.profiles (id) on delete restrict,
  reviewed_at timestamptz,
  review_note text check (review_note is null or (char_length(review_note) between 1 and 300
                                                    and review_note = btrim(review_note) and review_note !~ '[[:cntrl:]]')),
  reward_currency public.currency not null,
  reward_amount integer not null check (reward_amount > 0),
  reward_xp integer not null check (reward_xp >= 0),
  created_at timestamptz not null default now()
);
-- Dönem başına bir onaylı ya da bekleyen gönderi (reddedilen yeniden denenebilir).
create unique index campus_submissions_one_per_period
  on public.campus_task_submissions (task_id, user_id, period_start) where status in ('pending', 'approved');
create index campus_submissions_task_status on public.campus_task_submissions (task_id, status);
create index campus_submissions_user on public.campus_task_submissions (user_id, created_at desc);

revoke all on public.campus_tasks, public.campus_task_submissions from anon, authenticated;
grant select on public.campus_tasks, public.campus_task_submissions to authenticated;
alter table public.campus_tasks enable row level security;
alter table public.campus_task_submissions enable row level security;

-- Görevler: okulun öğrencileri (açık olanlar), görevi yönetenler (kapalılar dahil), süperadmin.
create policy campus_tasks_select on public.campus_tasks
  for select to authenticated
  using (
    (active and school_id = (select private.current_school_id()))
    or private.has_permission(school_id, 'kampus_gorevi_yonet')
  );

-- Gönderiler: kişinin kendisi; görevin okulunda görevi yöneten; süperadmin.
create policy campus_task_submissions_select on public.campus_task_submissions
  for select to authenticated
  using (
    user_id = (select auth.uid())
    or private.has_permission(private.school_of_user(user_id), 'kampus_gorevi_yonet')
  );

-- ---------------------------------------------------------------------------
-- Yardımcılar
-- ---------------------------------------------------------------------------

-- Dönemin başı (İstanbul): bir kez → sabit; günlük → bugün 00:00; haftalık → pazartesi 00:00.
create function private.campus_period_start(p_period public.campus_period, p_at timestamptz)
returns timestamptz
language sql stable set search_path = '' as $$
  select case p_period
    when 'once' then 'epoch'::timestamptz
    when 'daily' then date_trunc('day', p_at at time zone 'Europe/Istanbul') at time zone 'Europe/Istanbul'
    else date_trunc('week', p_at at time zone 'Europe/Istanbul') at time zone 'Europe/Istanbul'
  end;
$$;

-- Görevin `p_at` anındaki QR kodu (12 hex karakter). Basılı QR'da zaman dilimi yoktur.
create function private.campus_qr_code(p_task_id uuid, p_at timestamptz)
returns text
language sql stable set search_path = '' as $$
  select upper(left(encode(extensions.hmac(
           convert_to(t.id::text || ':' || case when t.qr_rotation_seconds = 0 then 'static'
                                                else floor(extract(epoch from p_at) / t.qr_rotation_seconds)::bigint::text end,
                      'UTF8'),
           s.secret, 'sha256'), 'hex'), 12))
  from public.campus_tasks t join private.campus_task_secrets s on s.task_id = t.id
  where t.id = p_task_id;
$$;


revoke execute on function
  private.campus_period_start(public.campus_period, timestamptz),
  private.campus_qr_code(uuid, timestamptz)
from public;

-- ---------------------------------------------------------------------------
-- Ledger ve XP: kampüs görevi ödülü (SP ya da süperadmin görevinde SSP); XP ledger kaydından tetiklenir
-- ---------------------------------------------------------------------------

alter table public.xp_events drop constraint xp_events_source;
alter table public.xp_events add constraint xp_events_source check (
  (reason in ('daily_login', 'quest', 'achievement', 'campus_task')) = (ledger_entry_id is not null)
  and (reason = 'correct_pick') = (wager_id is not null)
);

create or replace function private.xp_on_ledger_entry() returns trigger
language plpgsql set search_path = '' as $$
declare
  v_amount integer;
begin
  if new.reason = 'daily_login' then
    select s.xp_daily_login into v_amount from public.economy_settings s where s.id;
    perform private.award_xp(new.user_id, 'daily_login', v_amount, new.id, null);
  elsif new.reason = 'quest_reward' and new.ref_type = 'quest' then
    select q.reward_xp into v_amount from public.quests q where q.id = new.ref_id;
    perform private.award_xp(new.user_id, 'quest', v_amount, new.id, null);
  elsif new.reason = 'achievement_reward' and new.ref_type = 'achievement' then
    select a.reward_xp into v_amount from public.achievements a where a.id = new.ref_id;
    perform private.award_xp(new.user_id, 'achievement', v_amount, new.id, null);
  elsif new.reason = 'campus_task_reward' and new.ref_type = 'campus_task' then
    -- Görevin XP'si gönderiye o anki haliyle yazılır (sonradan değişse de kişinin aldığı kadar).
    select s.reward_xp into v_amount from public.campus_task_submissions s
    where s.task_id = new.ref_id and s.user_id = new.user_id and s.status = 'approved'
    order by s.created_at desc limit 1;
    perform private.award_xp(new.user_id, 'campus_task', v_amount, new.id, null);
  end if;
  return null;
end;
$$;
revoke execute on function private.xp_on_ledger_entry() from public;

drop trigger ledger_entries_award_xp on public.ledger_entries;
create trigger ledger_entries_award_xp
  after insert on public.ledger_entries
  for each row when (new.reason in ('daily_login', 'quest_reward', 'achievement_reward', 'campus_task_reward'))
  execute function private.xp_on_ledger_entry();

-- Onaylanan gönderinin ödülünü yazar (QR'da hemen, fotoğrafta yetkili onaylayınca).
create function private.pay_campus_submission(p_submission_id uuid) returns bigint
language plpgsql set search_path = '' as $$
declare
  v_s public.campus_task_submissions;
begin
  select * into v_s from public.campus_task_submissions s where s.id = p_submission_id;
  return private.post_ledger(v_s.user_id, v_s.reward_currency, v_s.reward_amount, 'campus_task_reward', 'campus_task',
                             v_s.task_id, v_s.user_id, null);
end;
$$;
revoke execute on function private.pay_campus_submission(uuid) from public;

-- ---------------------------------------------------------------------------
-- Yönetim
-- ---------------------------------------------------------------------------

create function public.save_campus_task(
  p_id uuid,
  p_school_id uuid,
  p_title text,
  p_description text,
  p_icon text,
  p_verification public.campus_verification,
  p_period public.campus_period,
  p_reward_currency public.currency,
  p_reward_amount integer,
  p_reward_xp integer,
  p_quota integer,
  p_qr_rotation_seconds integer,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_active boolean
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_old public.campus_tasks;
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  if p_school_id is null or p_title is null or p_verification is null or p_period is null
     or p_reward_currency is null or p_reward_amount is null or p_reward_xp is null
     or p_qr_rotation_seconds is null or p_active is null then
    raise exception 'Zorunlu alanlar doldurulmalı' using errcode = '23514';
  end if;
  if not exists (select 1 from public.clusters c where c.id = p_school_id and c.type = 'school') then
    raise exception 'Okul bulunamadı' using errcode = 'P0002';
  end if;
  if not private.has_permission(p_school_id, 'kampus_gorevi_yonet') then
    raise exception 'Bu okulda kampüs görevi yönetme iznin yok' using errcode = '42501';
  end if;
  -- SSP prestijlidir: yalnızca süperadminin açtığı (ya da düzenlediği) görev SSP verir.
  if p_reward_currency = 'SSP' and not private.is_superadmin() then
    raise exception 'SSP ödüllü görevi yalnızca süperadmin açar' using errcode = '42501';
  end if;

  if p_id is not null then
    select * into v_old from public.campus_tasks t where t.id = p_id for update;
    if not found or not private.has_permission(v_old.school_id, 'kampus_gorevi_yonet') then
      raise exception 'Görev bulunamadı' using errcode = 'P0002';
    end if;
    if v_old.school_id <> p_school_id or v_old.verification <> p_verification then
      raise exception 'Görevin okulu ve doğrulama yöntemi sonradan değiştirilemez' using errcode = '23514';
    end if;
    if v_old.reward_currency = 'SSP' and not private.is_superadmin() then
      raise exception 'SSP ödüllü görevi yalnızca süperadmin düzenler' using errcode = '42501';
    end if;
    update public.campus_tasks t
    set title = btrim(p_title), description = nullif(btrim(coalesce(p_description, '')), ''),
        icon = coalesce(nullif(btrim(coalesce(p_icon, '')), ''), '📍'), period = p_period,
        reward_currency = p_reward_currency, reward_amount = p_reward_amount, reward_xp = p_reward_xp,
        quota = p_quota, qr_rotation_seconds = p_qr_rotation_seconds, starts_at = p_starts_at, ends_at = p_ends_at,
        active = p_active, updated_at = now()
    where t.id = p_id;
    v_id := p_id;
  else
    insert into public.campus_tasks (school_id, title, description, icon, verification, period, reward_currency,
                                     reward_amount, reward_xp, quota, qr_rotation_seconds, starts_at, ends_at, active,
                                     created_by)
    values (p_school_id, btrim(p_title), nullif(btrim(coalesce(p_description, '')), ''),
            coalesce(nullif(btrim(coalesce(p_icon, '')), ''), '📍'), p_verification, p_period, p_reward_currency,
            p_reward_amount, p_reward_xp, p_quota, p_qr_rotation_seconds, p_starts_at, p_ends_at, p_active, v_uid)
    returning id into v_id;
    insert into private.campus_task_secrets (task_id) values (v_id);
  end if;

  insert into public.admin_audit_log (actor_id, action, cluster_id, details)
  values (v_uid, 'campus_task_save', p_school_id,
          jsonb_build_object('task_id', v_id, 'title', btrim(p_title), 'verification', p_verification,
                             'reward', p_reward_amount, 'currency', p_reward_currency, 'xp', p_reward_xp,
                             'active', p_active, 'new', p_id is null));
  return v_id;
end;
$$;

-- QR'ı yenile: yeni anahtar, eski (basılı / sızmış) kod geçersizleşir.
create function public.reset_campus_task_qr(p_task_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_task public.campus_tasks;
begin
  select * into v_task from public.campus_tasks t where t.id = p_task_id;
  if v_uid is null or not found or not private.has_permission(v_task.school_id, 'kampus_gorevi_yonet') then
    raise exception 'Görev bulunamadı' using errcode = 'P0002';
  end if;
  update private.campus_task_secrets s set secret = extensions.gen_random_bytes(32), rotated_at = now()
  where s.task_id = p_task_id;
  insert into public.admin_audit_log (actor_id, action, cluster_id, details)
  values (v_uid, 'campus_task_qr_reset', v_task.school_id, jsonb_build_object('task_id', p_task_id));
end;
$$;

-- Yetkili için QR içeriği: kod, uygulamanın okuyacağı bağlantı, dönme süresi ve geçerlilik sonu (basılıda null).
create function public.campus_task_qr(p_task_id uuid)
returns table (code text, payload text, rotation_seconds integer, valid_until timestamptz)
language plpgsql security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_task public.campus_tasks;
  v_code text;
begin
  select * into v_task from public.campus_tasks t where t.id = p_task_id;
  if (select auth.uid()) is null or not found or v_task.verification <> 'qr'
     or not private.has_permission(v_task.school_id, 'kampus_gorevi_yonet') then
    raise exception 'Görev bulunamadı' using errcode = 'P0002';
  end if;
  v_code := private.campus_qr_code(p_task_id, now());
  return query select v_code,
    'com.kampusbet.kampusbet://kampus-gorev?t=' || p_task_id || '&c=' || v_code,
    v_task.qr_rotation_seconds,
    case when v_task.qr_rotation_seconds = 0 then null::timestamptz
         else to_timestamp((floor(extract(epoch from now()) / v_task.qr_rotation_seconds) + 1)
                           * v_task.qr_rotation_seconds) end;
end;
$$;

-- ---------------------------------------------------------------------------
-- Öğrenci
-- ---------------------------------------------------------------------------

-- Okulun açık kampüs görevleri ve kişinin bu dönemdeki durumu; okulda bu dönem yapan sayısı, kalan kontenjan.
create function public.my_campus_tasks()
returns table (
  id uuid, title text, description text, icon text, verification public.campus_verification,
  period public.campus_period, reward_currency public.currency, reward_amount integer, reward_xp integer,
  quota integer, remaining integer, done_this_period integer, starts_at timestamptz, ends_at timestamptz,
  my_status public.campus_submission_status, my_note text, can_submit boolean
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
  v_school uuid;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  select p.school_id into v_school from public.profiles p where p.id = v_uid and p.deleted_at is null;
  if v_school is null then
    raise exception 'Profil bulunamadı' using errcode = 'P0002';
  end if;

  return query
    with tasks as (
      select t.*, private.campus_period_start(t.period, now()) as ps
      from public.campus_tasks t
      where t.school_id = v_school and t.active and (t.ends_at is null or t.ends_at > now())
    ),
    mine as (
      -- Kişinin bu dönemdeki son gönderisi.
      select distinct on (s.task_id) s.task_id, s.status, s.review_note
      from public.campus_task_submissions s join tasks t on t.id = s.task_id
      where s.user_id = v_uid and s.period_start = t.ps
      order by s.task_id, s.created_at desc
    )
    select t.id, t.title, t.description, t.icon, t.verification, t.period, t.reward_currency, t.reward_amount,
           t.reward_xp, t.quota,
           case when t.quota is null then null
                else greatest(t.quota - (select count(*) from public.campus_task_submissions s
                                         where s.task_id = t.id and s.status = 'approved')::integer, 0) end,
           (select count(*) from public.campus_task_submissions s
            where s.task_id = t.id and s.status = 'approved' and s.period_start = t.ps)::integer,
           t.starts_at, t.ends_at, m.status, m.review_note,
           coalesce(m.status not in ('pending', 'approved'), true)
             and (t.starts_at is null or t.starts_at <= now())
             and not private.has_permission(t.school_id, 'kampus_gorevi_yonet')
    from tasks t left join mine m on m.task_id = t.id
    order by (m.status is null) desc, t.created_at desc;
end;
$$;

-- QR ile görev: kod doğruysa ödül hemen verilir. Hatalar: KB002 doğrulanmamış, P0002 görünmeyen görev,
-- KB032 açık değil, KB029 kod geçersiz / süresi geçti, KB030 bu dönem yapıldı, KB031 kontenjan doldu.
create function public.submit_campus_task_qr(p_task_id uuid, p_code text)
returns table (reward_currency public.currency, reward_amount integer, reward_xp integer, balance bigint)
language plpgsql security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
  v_task public.campus_tasks;
  v_code text := upper(btrim(coalesce(p_code, '')));
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
  -- Kontenjan ve dönem kontrolü sırayla: görev satırı kilitlenir (FOR NO KEY UPDATE: gönderi eklemenin
  -- yabancı anahtar kilidiyle çakışmaz).
  select * into v_task from public.campus_tasks t
  where t.id = p_task_id and t.school_id = private.current_school_id()
  for no key update;
  if not found then
    raise exception 'Görev bulunamadı' using errcode = 'P0002';
  end if;
  if private.has_permission(v_task.school_id, 'kampus_gorevi_yonet') then
    raise exception 'Kampüs görevlerini yöneten ödül alamaz' using errcode = '42501';
  end if;
  if not v_task.active or v_task.verification <> 'qr'
     or (v_task.starts_at is not null and v_task.starts_at > now())
     or (v_task.ends_at is not null and v_task.ends_at <= now()) then
    raise exception 'Bu görev şu an açık değil' using errcode = 'KB032';
  end if;
  if v_code = '' or (v_code <> private.campus_qr_code(v_task.id, now())
                     and (v_task.qr_rotation_seconds = 0
                          or v_code <> private.campus_qr_code(v_task.id, now() - make_interval(secs => v_task.qr_rotation_seconds)))) then
    raise exception 'QR kodu geçersiz ya da süresi geçti' using errcode = 'KB029';
  end if;

  v_ps := private.campus_period_start(v_task.period, now());
  if exists (select 1 from public.campus_task_submissions s
             where s.task_id = v_task.id and s.user_id = v_uid and s.period_start = v_ps
               and s.status in ('pending', 'approved')) then
    raise exception 'Bu görevi bu dönem zaten yaptın' using errcode = 'KB030';
  end if;
  if v_task.quota is not null and (select count(*) from public.campus_task_submissions s
                                   where s.task_id = v_task.id and s.status = 'approved') >= v_task.quota then
    raise exception 'Görevin kontenjanı doldu' using errcode = 'KB031';
  end if;

  insert into public.campus_task_submissions (task_id, user_id, period_start, method, status, reward_currency,
                                              reward_amount, reward_xp)
  values (v_task.id, v_uid, v_ps, 'qr', 'approved', v_task.reward_currency, v_task.reward_amount, v_task.reward_xp)
  returning id into v_id;

  reward_currency := v_task.reward_currency;
  reward_amount := v_task.reward_amount;
  reward_xp := v_task.reward_xp;
  balance := private.pay_campus_submission(v_id);
  return next;
end;
$$;

revoke execute on function
  public.save_campus_task(uuid, uuid, text, text, text, public.campus_verification, public.campus_period,
                          public.currency, integer, integer, integer, integer, timestamptz, timestamptz, boolean),
  public.reset_campus_task_qr(uuid),
  public.campus_task_qr(uuid),
  public.my_campus_tasks(),
  public.submit_campus_task_qr(uuid, text)
from public, anon;
grant execute on function
  public.save_campus_task(uuid, uuid, text, text, text, public.campus_verification, public.campus_period,
                          public.currency, integer, integer, integer, integer, timestamptz, timestamptz, boolean),
  public.reset_campus_task_qr(uuid),
  public.campus_task_qr(uuid),
  public.my_campus_tasks(),
  public.submit_campus_task_qr(uuid, text)
to authenticated;

-- ---------------------------------------------------------------------------
-- Başarım: kampüs görevi sayısı
-- ---------------------------------------------------------------------------

alter table public.achievements drop constraint achievements_metric_check;
alter table public.achievements add constraint achievements_metric_check check (metric in (
  'predictions', 'correct', 'best_streak', 'duels_played', 'duels_won', 'perfect_duels', 'social_created',
  'fair_referee', 'login_streak', 'sp_profit', 'level', 'items_owned', 'quests_claimed', 'verified',
  'official_wins', 'underdog_wins', 'campus_tasks'
));

create or replace function private.achievement_metrics(p_user_id uuid)
returns table (metric text, value bigint)
language sql stable set search_path = '' as $$
  with sw as (
    select * from private.settled_wagers(null, p_user_id, '-infinity', 'infinity')
  ),
  preds as (
    select sw.correct,
           row_number() over (order by sw.settled_at, sw.bet_id)
             - row_number() over (partition by sw.correct order by sw.settled_at, sw.bet_id) as grp
    from sw where sw.is_prediction
  )
  select 'predictions'::text, (select count(*) from preds)
  union all select 'correct', (select count(*) from preds where preds.correct)
  union all select 'best_streak',
    coalesce((select max(x.len) from (select count(*) as len from preds where preds.correct group by preds.grp) x), 0)
  union all select 'duels_played',
    (select count(*) from public.trivia_duel_plays d where d.player_id = p_user_id and d.submitted_at is not null)
  union all select 'duels_won', (select count(*) from sw where not sw.is_prediction and sw.net > 0)
  union all select 'perfect_duels',
    (select count(*) from public.trivia_duel_plays d join public.trivia_duels t on t.bet_id = d.bet_id
     where d.player_id = p_user_id and d.submitted_at is not null and d.score = cardinality(t.question_ids))
  union all select 'social_created',
    (select count(*) from public.bets b where b.creator_id = p_user_id and b.type = 'sp_social' and b.status = 'settled')
  union all select 'fair_referee',
    (select count(*) from public.bets b
     where b.referee_id = p_user_id and b.type = 'sp_social' and b.status = 'settled'
       and not exists (select 1 from public.bet_disputes d where d.bet_id = b.id and d.decision = 'changed'))
  union all select 'login_streak',
    coalesce((select ls.longest_streak::bigint from public.login_streaks ls where ls.user_id = p_user_id), 0)
  union all select 'sp_profit', coalesce((select sum(sw.net) from sw where sw.currency = 'SP'), 0)::bigint
  union all select 'level', coalesce((select p.level::bigint from public.profiles p where p.id = p_user_id), 0)
  union all select 'items_owned', (select count(*) from public.user_inventory i where i.user_id = p_user_id)
  union all select 'quests_claimed', (select count(*) from public.quest_claims q where q.user_id = p_user_id)
  union all select 'verified', case when private.is_verified(p_user_id) then 1::bigint else 0::bigint end
  union all select 'official_wins', (select count(*) from sw where sw.currency = 'SSP' and sw.net > 0)
  union all select 'underdog_wins',
    (select count(*) from public.wagers w
     join public.bets b on b.id = w.bet_id
     join public.bet_options o on o.id = w.option_id
     where w.user_id = p_user_id and b.status = 'settled' and b.odds_mode = 'pool' and o.is_winner
       and o.pool_amount * 5 < b.pool_total and coalesce(w.payout, 0) > w.amount)
  union all select 'campus_tasks',
    (select count(*) from public.campus_task_submissions s where s.user_id = p_user_id and s.status = 'approved');
$$;
revoke execute on function private.achievement_metrics(uuid) from public;

insert into public.achievements (key, category, title, description, icon, metric, target, tier, reward_sp, reward_xp, hidden, sort) values
  ('kampus_ilk',      'progress', 'Kampüs Kâşifi',  'İlk kampüs görevini tamamla.',  '🧭', 'campus_tasks',  1, 1,  20, 10, false, 84),
  ('kampus_gonullu',  'progress', 'Kampüs Gönüllüsü', '10 kampüs görevi tamamla.',   '🌱', 'campus_tasks', 10, 2, 100, 40, false, 85),
  ('kampus_efsanesi', 'progress', 'Kampüs Efsanesi', '50 kampüs görevi tamamla.',    '🏛️', 'campus_tasks', 50, 3, 300, 120, false, 86);
