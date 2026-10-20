-- Adım 2: para çekirdeği. Ledger (yalnızca eklenen defter), önbelleklenmiş bakiye,
-- ekonomi ayarları, başlangıç SP'si, günlük giriş serisi ve süperadmin para işlemleri.
--
-- İlkeler:
-- * Bakiye yalnızca private.post_ledger ile değişir: bakiye satırını kilitler (FOR UPDATE),
--   yeni bakiyeyi hesaplar, negatife düşürmez, ledger satırını balance_after ile yazar.
--   Çağıran RPC'nin transaction'ı içinde çalışır; hepsi ya olur ya hiç olmaz.
-- * Kullanıcılar arası transfer fonksiyonu yoktur (KARARLAR).
-- * İstemci bu tablolara yazamaz; yalnızca kendi kayıtlarını okur.

-- ---------------------------------------------------------------------------
-- Türler
-- ---------------------------------------------------------------------------

create type public.currency as enum ('SP', 'SSP');

create type public.ledger_reason as enum (
  'signup_bonus',
  'daily_login',
  'quest_reward',
  'bet_stake',
  'bet_payout',
  'bet_refund',
  'market_purchase',
  'admin_grant',
  'admin_adjust'
);

create type public.ledger_ref_type as enum ('bet', 'wager', 'quest', 'market_item');

-- ---------------------------------------------------------------------------
-- Ekonomi ayarları (tek satır). Rakamlar taslaktır; market fiyatlarıyla birlikte kalibre edilecek.
-- ---------------------------------------------------------------------------

create table public.economy_settings (
  id boolean primary key default true check (id),
  signup_bonus_sp integer not null check (signup_bonus_sp >= 0),
  daily_base_sp integer not null check (daily_base_sp > 0),
  daily_step_sp integer not null check (daily_step_sp >= 0),
  daily_max_sp integer not null,
  -- Seri bu güne ulaştığında günlük ödüle eklenen bonus, ör. {"7": 200}
  streak_milestones jsonb not null default '{}'::jsonb check (jsonb_typeof(streak_milestones) = 'object'),
  -- "Gün" bu saat dilimine göre değişir.
  day_timezone text not null default 'Europe/Istanbul',
  updated_at timestamptz not null default now(),
  constraint economy_settings_daily_max check (daily_max_sp >= daily_base_sp)
);

insert into public.economy_settings
  (signup_bonus_sp, daily_base_sp, daily_step_sp, daily_max_sp, streak_milestones)
values
  (1000, 50, 10, 150, '{"7": 200, "14": 500, "30": 1500}');

-- ---------------------------------------------------------------------------
-- Ledger ve bakiye
-- ---------------------------------------------------------------------------

create table public.ledger_entries (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles (id) on delete restrict,
  currency public.currency not null,
  amount bigint not null,
  reason public.ledger_reason not null,
  ref_type public.ledger_ref_type,
  ref_id uuid,
  balance_after bigint not null check (balance_after >= 0),
  -- İşlemi başlatan kişi: kullanıcının kendisi ya da (admin işlemlerinde) süperadmin.
  actor_id uuid references public.profiles (id) on delete restrict,
  note text check (note is null or (char_length(note) between 3 and 500 and note = btrim(note))),
  created_at timestamptz not null default now(),
  constraint ledger_ref_pair check ((ref_type is null) = (ref_id is null)),
  -- Harcamalar eksi, kazançlar artı; düzeltme iki yönlü olabilir ama sıfır olamaz.
  constraint ledger_amount_sign check (
    case reason
      when 'bet_stake' then amount < 0
      when 'market_purchase' then amount < 0
      when 'admin_adjust' then amount <> 0
      else amount > 0
    end
  ),
  -- Başlangıç ve günlük ödüller yalnızca SP'dir; SSP yalnızca resmi görev ve süperadminden gelir.
  constraint ledger_sp_only_rewards check (reason not in ('signup_bonus', 'daily_login') or currency = 'SP'),
  -- Admin işlemlerinde kimin yaptığı ve gerekçe zorunlu.
  constraint ledger_admin_needs_actor_and_note check (
    reason not in ('admin_grant', 'admin_adjust') or (actor_id is not null and note is not null)
  )
);
create index ledger_entries_user_idx on public.ledger_entries (user_id, currency, id desc);
create index ledger_entries_ref_idx on public.ledger_entries (ref_type, ref_id) where ref_id is not null;
create index ledger_entries_actor_idx on public.ledger_entries (actor_id) where actor_id is not null;
-- Başlangıç SP'si kişi başı bir kez.
create unique index ledger_entries_one_signup_bonus on public.ledger_entries (user_id) where reason = 'signup_bonus';

create trigger ledger_entries_append_only
  before update or delete on public.ledger_entries
  for each row execute function private.forbid_change();

create trigger ledger_entries_no_truncate
  before truncate on public.ledger_entries
  for each statement execute function private.forbid_change();

create table public.balances (
  user_id uuid primary key references public.profiles (id) on delete restrict,
  sp_balance bigint not null default 0 check (sp_balance >= 0),
  ssp_balance bigint not null default 0 check (ssp_balance >= 0),
  updated_at timestamptz not null default now()
);

create table public.login_streaks (
  user_id uuid primary key references public.profiles (id) on delete restrict,
  current_streak integer not null default 0 check (current_streak >= 0),
  longest_streak integer not null default 0 check (longest_streak >= current_streak),
  last_login_date date
);

-- Daha önce açılmış profiller için (Adım 1'den kalan).
insert into public.balances (user_id) select id from public.profiles on conflict do nothing;
insert into public.login_streaks (user_id) select id from public.profiles on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Para hareketinin tek kapısı
-- ---------------------------------------------------------------------------

-- Bakiye satırını kilitler, yeni bakiyeyi hesaplar, ledger'a yazar ve yeni bakiyeyi döner.
-- Yetersiz bakiyede KB001 hatası verir. Birden fazla kullanıcıya dokunan işlemler
-- (ör. bahis sonuçlandırma) kilitlenmeyi önlemek için kullanıcıları user_id sırasıyla işlemeli.
create function private.post_ledger(
  p_user_id uuid,
  p_currency public.currency,
  p_amount bigint,
  p_reason public.ledger_reason,
  p_ref_type public.ledger_ref_type default null,
  p_ref_id uuid default null,
  p_actor_id uuid default null,
  p_note text default null
) returns bigint
language plpgsql set search_path = '' as $$
declare
  v_balance public.balances;
  v_new bigint;
begin
  select * into v_balance from public.balances b where b.user_id = p_user_id for update;
  if not found then
    raise exception 'Kullanıcının bakiye kaydı yok: %', p_user_id using errcode = 'P0002';
  end if;

  v_new := case p_currency
    when 'SP' then v_balance.sp_balance + p_amount
    else v_balance.ssp_balance + p_amount
  end;
  if v_new < 0 then
    raise exception 'Yetersiz bakiye' using errcode = 'KB001';
  end if;

  if p_currency = 'SP' then
    update public.balances set sp_balance = v_new, updated_at = now() where user_id = p_user_id;
  else
    update public.balances set ssp_balance = v_new, updated_at = now() where user_id = p_user_id;
  end if;

  insert into public.ledger_entries
    (user_id, currency, amount, reason, ref_type, ref_id, balance_after, actor_id, note)
  values
    (p_user_id, p_currency, p_amount, p_reason, p_ref_type, p_ref_id, v_new, p_actor_id, p_note);

  return v_new;
end;
$$;

-- Önbellekteki bakiye ile ledger toplamı arasındaki farklar (boş dönmeli).
create function private.balance_mismatches()
returns table (user_id uuid, currency public.currency, cached bigint, ledger_sum bigint)
language sql stable set search_path = '' as $$
  with sums as (
    select l.user_id, l.currency, sum(l.amount)::bigint as total
    from public.ledger_entries l
    group by l.user_id, l.currency
  ),
  cached as (
    select b.user_id, 'SP'::public.currency as currency, b.sp_balance as amount from public.balances b
    union all
    select b.user_id, 'SSP'::public.currency, b.ssp_balance from public.balances b
  )
  select c.user_id, c.currency, c.amount, coalesce(s.total, 0)
  from cached c
  left join sums s on s.user_id = c.user_id and s.currency = c.currency
  where c.amount <> coalesce(s.total, 0);
$$;

revoke execute on function
  private.post_ledger(uuid, public.currency, bigint, public.ledger_reason, public.ledger_ref_type, uuid, uuid, text),
  private.balance_mismatches()
from public;

-- ---------------------------------------------------------------------------
-- Profil oluşturma: bakiye, seri kaydı ve başlangıç SP'si eklenir
-- ---------------------------------------------------------------------------

create or replace function public.create_profile(
  p_first_name text,
  p_last_name text,
  p_school_id uuid,
  p_department text default null
) returns public.profiles
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_profile public.profiles;
  v_bonus integer;
begin
  if v_uid is null or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  if exists (select 1 from public.profiles p where p.id = v_uid) then
    raise exception 'Profil zaten oluşturulmuş' using errcode = '23505';
  end if;

  insert into public.profiles (id, first_name, last_name, school_id, department)
  values (v_uid, btrim(p_first_name), btrim(p_last_name), p_school_id, nullif(btrim(p_department), ''))
  returning * into v_profile;

  insert into public.profile_private (user_id) values (v_uid);
  insert into public.user_clusters (user_id, cluster_id, role_in_cluster) values (v_uid, p_school_id, 'member');
  insert into public.balances (user_id) values (v_uid);
  insert into public.login_streaks (user_id) values (v_uid);

  select s.signup_bonus_sp into v_bonus from public.economy_settings s;
  if v_bonus > 0 then
    perform private.post_ledger(v_uid, 'SP', v_bonus, 'signup_bonus', null, null, v_uid, null);
  end if;

  return v_profile;
end;
$$;

-- ---------------------------------------------------------------------------
-- Günlük giriş ödülü
-- ---------------------------------------------------------------------------

-- Günde bir kez SP verir. Dün de alındıysa seri bir artar, yoksa 1'e döner.
-- Ödül = min(taban + adım * (seri - 1), tavan) + seri bu güne ulaştıysa kilometre taşı bonusu.
-- Aynı gün tekrar çağrılırsa hata vermez, claimed = false döner.
create function public.claim_daily_login()
returns table (claimed boolean, amount bigint, current_streak integer, sp_balance bigint)
language plpgsql security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
  v_cfg public.economy_settings;
  v_today date;
  v_streak public.login_streaks;
  v_new_streak integer;
  v_amount bigint;
  v_balance bigint;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  if not exists (select 1 from public.profiles p where p.id = v_uid) then
    raise exception 'Önce profil oluşturulmalı' using errcode = 'P0002';
  end if;

  select * into v_cfg from public.economy_settings s where s.id;
  v_today := (now() at time zone v_cfg.day_timezone)::date;

  insert into public.login_streaks (user_id) values (v_uid) on conflict do nothing;
  select * into v_streak from public.login_streaks ls where ls.user_id = v_uid for update;

  if v_streak.last_login_date = v_today then
    select b.sp_balance into v_balance from public.balances b where b.user_id = v_uid;
    return query select false, 0::bigint, v_streak.current_streak, v_balance;
    return;
  end if;

  v_new_streak := case when v_streak.last_login_date = v_today - 1 then v_streak.current_streak + 1 else 1 end;
  v_amount := least(v_cfg.daily_base_sp + v_cfg.daily_step_sp * (v_new_streak - 1), v_cfg.daily_max_sp)
              + coalesce((v_cfg.streak_milestones ->> v_new_streak::text)::bigint, 0);

  update public.login_streaks ls
  set current_streak = v_new_streak,
      longest_streak = greatest(ls.longest_streak, v_new_streak),
      last_login_date = v_today
  where ls.user_id = v_uid;

  v_balance := private.post_ledger(v_uid, 'SP', v_amount, 'daily_login', null, null, v_uid, null);
  return query select true, v_amount, v_new_streak, v_balance;
end;
$$;

-- ---------------------------------------------------------------------------
-- Süperadmin para işlemleri (MIMARI §6.2: ssp_ver / bakiye_duzelt)
-- ---------------------------------------------------------------------------

create function private.assert_admin_money_op(p_user_id uuid, p_amount bigint, p_note text)
returns void
language plpgsql stable set search_path = '' as $$
begin
  if not private.is_superadmin() then
    raise exception 'Bu işlem yalnızca süperadmin içindir' using errcode = '42501';
  end if;
  if p_user_id = (select auth.uid()) then
    raise exception 'Süperadmin kendi bakiyesini değiştiremez' using errcode = '42501';
  end if;
  if p_amount is null or abs(p_amount) > 1000000 then
    raise exception 'Tek işlemde en fazla 1.000.000 verilebilir' using errcode = '22003';
  end if;
  if p_note is null or char_length(btrim(p_note)) < 3 then
    raise exception 'Gerekçe yazılmalı (en az 3 karakter)' using errcode = '23514';
  end if;
end;
$$;

revoke execute on function private.assert_admin_money_op(uuid, bigint, text) from public;

-- Kullanıcıya SP/SSP verir (yalnızca artı). Yeni bakiyeyi döner.
create function public.admin_grant(
  p_user_id uuid,
  p_currency public.currency,
  p_amount bigint,
  p_note text
) returns bigint
language plpgsql security definer set search_path = '' as $$
begin
  perform private.assert_admin_money_op(p_user_id, p_amount, p_note);
  if p_amount <= 0 then
    raise exception 'Verilen miktar artı olmalı' using errcode = '23514';
  end if;
  return private.post_ledger(p_user_id, p_currency, p_amount, 'admin_grant', null, null,
                             (select auth.uid()), btrim(p_note));
end;
$$;

-- Bakiyeyi artı ya da eksi yönde düzeltir. Bakiye negatife düşemez. Yeni bakiyeyi döner.
create function public.admin_adjust(
  p_user_id uuid,
  p_currency public.currency,
  p_amount bigint,
  p_note text
) returns bigint
language plpgsql security definer set search_path = '' as $$
begin
  perform private.assert_admin_money_op(p_user_id, p_amount, p_note);
  if p_amount = 0 then
    raise exception 'Düzeltme miktarı sıfır olamaz' using errcode = '23514';
  end if;
  return private.post_ledger(p_user_id, p_currency, p_amount, 'admin_adjust', null, null,
                             (select auth.uid()), btrim(p_note));
end;
$$;

revoke execute on function
  public.claim_daily_login(),
  public.admin_grant(uuid, public.currency, bigint, text),
  public.admin_adjust(uuid, public.currency, bigint, text)
from public, anon;

grant execute on function
  public.claim_daily_login(),
  public.admin_grant(uuid, public.currency, bigint, text),
  public.admin_adjust(uuid, public.currency, bigint, text)
to authenticated;

-- ---------------------------------------------------------------------------
-- Tablo yetkileri ve RLS
-- ---------------------------------------------------------------------------

revoke all on
  public.economy_settings,
  public.ledger_entries,
  public.balances,
  public.login_streaks
from anon, authenticated;

grant select on
  public.economy_settings,
  public.ledger_entries,
  public.balances,
  public.login_streaks
to authenticated;

alter table public.economy_settings enable row level security;
alter table public.ledger_entries enable row level security;
alter table public.balances enable row level security;
alter table public.login_streaks enable row level security;

create policy economy_settings_select on public.economy_settings
  for select to authenticated
  using (true);

create policy ledger_entries_select on public.ledger_entries
  for select to authenticated
  using (user_id = (select auth.uid()) or (select private.is_superadmin()));

create policy balances_select on public.balances
  for select to authenticated
  using (user_id = (select auth.uid()) or (select private.is_superadmin()));

create policy login_streaks_select on public.login_streaks
  for select to authenticated
  using (user_id = (select auth.uid()) or (select private.is_superadmin()));
