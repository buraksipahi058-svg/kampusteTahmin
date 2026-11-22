-- XP ve seviye (MIMARI §11; KARARLAR "XP ve seviye").
--
-- XP paradan ayrı bir ilerlemedir: satın alınmaz, harcanmaz, aktarılmaz, paraya dönmez ve yatırılan
-- miktarla büyümez. Kaynakları:
--   - günlük giriş (her gün bir kez),
--   - görev ödülü (görevin kendi XP'si),
--   - doğru tahmin ya da kazanılan düello (miktardan bağımsız sabit XP, günlük üst sınırlı:
--     "çok bahis = çok XP" olmasın).
-- Seviye toplam XP'den hesaplanır; bazı market ürünleri seviyeyle açılır.
--
-- XP olayları `xp_events`'e yazılır (yalnızca eklenir, tek gerçek); `profiles.xp` / `profiles.level`
-- önbellektir. XP, para işleminin içinde tetikleyiciyle verilir; para fonksiyonlarına dokunulmaz.
-- Kilit sırası: bahis satırı → bakiyeler (user_id) → profil satırları (XP, user_id sırasıyla).

-- ---------------------------------------------------------------------------
-- Ayarlar ve kolonlar
-- ---------------------------------------------------------------------------

create type public.xp_reason as enum ('daily_login', 'quest', 'correct_pick');

alter table public.economy_settings
  add column xp_daily_login integer not null default 10 check (xp_daily_login between 0 and 1000),
  add column xp_correct_pick integer not null default 15 check (xp_correct_pick between 0 and 1000),
  -- Doğru tahmin / düellodan bir günde (ayardaki saat dilimi) en fazla bu kadar XP.
  add column xp_daily_pick_cap integer not null default 60 check (xp_daily_pick_cap between 0 and 10000),
  -- Seviye L için gereken toplam XP: adım × L × (L − 1) / 2 (100 → 2. seviye 100, 3. 300, 4. 600, 5. 1000).
  add column xp_level_step integer not null default 100 check (xp_level_step between 10 and 100000);

alter table public.quests
  add column reward_xp integer not null default 0 check (reward_xp between 0 and 1000);
-- Mevcut görevler döneme göre XP verir (taslak).
update public.quests set reward_xp = case period when 'daily' then 20 when 'weekly' then 50 else 150 end;

alter table public.market_items
  add column min_level integer not null default 1 check (min_level between 1 and 100);
-- Örnek ürünlerden ikisi seviyeyle açılır (seed kimlikleri; yoksa etkisiz).
update public.market_items set min_level = 3 where id = '40000000-0000-4000-8000-000000000003'; -- Altın çerçeve
update public.market_items set min_level = 5 where id = '40000000-0000-4000-8000-000000000001'; -- Kehanet Ustası

-- ---------------------------------------------------------------------------
-- XP olayları (yalnızca eklenir)
-- ---------------------------------------------------------------------------

create table public.xp_events (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles (id) on delete restrict,
  reason public.xp_reason not null,
  amount integer not null check (amount > 0),
  -- Kaynağı: günlük giriş ve görevde ledger kaydı, doğru tahminde yatırım. Aynı kaynak iki kez XP vermez.
  ledger_entry_id bigint references public.ledger_entries (id) on delete restrict,
  wager_id uuid references public.wagers (id) on delete restrict,
  xp_after integer not null check (xp_after > 0),
  created_at timestamptz not null default now(),
  constraint xp_events_source check (
    (reason in ('daily_login', 'quest')) = (ledger_entry_id is not null)
    and (reason = 'correct_pick') = (wager_id is not null)
  )
);
create unique index xp_events_ledger_entry_key on public.xp_events (ledger_entry_id) where ledger_entry_id is not null;
create unique index xp_events_wager_key on public.xp_events (wager_id) where wager_id is not null;
create index xp_events_user_idx on public.xp_events (user_id, created_at desc);

create trigger xp_events_append_only
  before update or delete on public.xp_events
  for each row execute function private.forbid_change();
create trigger xp_events_no_truncate
  before truncate on public.xp_events
  for each statement execute function private.forbid_change();

revoke all on public.xp_events from anon, authenticated;
grant select on public.xp_events to authenticated;
alter table public.xp_events enable row level security;

create policy xp_events_select on public.xp_events
  for select to authenticated
  using (user_id = (select auth.uid()) or (select private.is_superadmin()));

-- ---------------------------------------------------------------------------
-- Seviye eğrisi
-- ---------------------------------------------------------------------------

-- Seviyeye ulaşmak için gereken toplam XP (1. seviye 0).
create function private.xp_for_level(p_level integer) returns integer
language sql stable set search_path = '' as $$
  select (s.xp_level_step::bigint * (greatest(p_level, 1) - 1) * greatest(p_level, 1) / 2)::integer
  from public.economy_settings s where s.id;
$$;

-- Toplam XP'nin seviyesi.
create function private.level_for_xp(p_xp integer) returns integer
language plpgsql stable set search_path = '' as $$
declare
  v_xp integer := greatest(coalesce(p_xp, 0), 0);
  v_step integer;
  v_level integer;
begin
  select s.xp_level_step into v_step from public.economy_settings s where s.id;
  v_level := greatest(1, floor((1 + sqrt(1 + 8.0 * v_xp / v_step)) / 2)::integer);
  -- Yuvarlama payı: sınırda bir aşağı / yukarı düzelt.
  while v_level > 1 and private.xp_for_level(v_level) > v_xp loop
    v_level := v_level - 1;
  end loop;
  while private.xp_for_level(v_level + 1) <= v_xp loop
    v_level := v_level + 1;
  end loop;
  return v_level;
end;
$$;

-- ---------------------------------------------------------------------------
-- XP verme
-- ---------------------------------------------------------------------------

-- Kişiye XP yazar, profil önbelleğini günceller; verilen XP'yi döner (sınır ya da tekrar yüzünden 0 olabilir).
-- Doğru tahmin XP'si günlük sınırla kırpılır. Çağıranın transaction'ında, bakiye kilitlerinden sonra çalışır.
create function private.award_xp(
  p_user_id uuid, p_reason public.xp_reason, p_amount integer,
  p_ledger_entry_id bigint default null, p_wager_id uuid default null
) returns integer
language plpgsql set search_path = '' as $$
declare
  v_cfg public.economy_settings;
  v_amount integer := coalesce(p_amount, 0);
  v_xp integer;
  v_used integer;
begin
  if v_amount <= 0 then
    return 0;
  end if;
  -- Aynı kişiye eşzamanlı XP sırayla yazılır (günlük sınır kesin kalır).
  select p.xp into v_xp from public.profiles p where p.id = p_user_id for update;
  if not found then
    raise exception 'Profil bulunamadı' using errcode = 'P0002';
  end if;

  if p_reason = 'correct_pick' then
    select * into v_cfg from public.economy_settings s where s.id;
    select coalesce(sum(e.amount), 0) into v_used
    from public.xp_events e
    where e.user_id = p_user_id and e.reason = 'correct_pick'
      and e.created_at >= (date_trunc('day', now() at time zone v_cfg.day_timezone) at time zone v_cfg.day_timezone);
    v_amount := least(v_amount, v_cfg.xp_daily_pick_cap - v_used);
    if v_amount <= 0 then
      return 0;
    end if;
  end if;

  insert into public.xp_events (user_id, reason, amount, ledger_entry_id, wager_id, xp_after)
  values (p_user_id, p_reason, v_amount, p_ledger_entry_id, p_wager_id, v_xp + v_amount)
  on conflict do nothing;
  if not found then
    return 0;
  end if;

  update public.profiles
  set xp = v_xp + v_amount, level = private.level_for_xp(v_xp + v_amount)
  where id = p_user_id;
  return v_amount;
end;
$$;

-- Günlük giriş ve görev ödülünün ledger kaydı XP de verir.
create function private.xp_on_ledger_entry() returns trigger
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
  end if;
  return null;
end;
$$;

create trigger ledger_entries_award_xp
  after insert on public.ledger_entries
  for each row when (new.reason in ('daily_login', 'quest_reward'))
  execute function private.xp_on_ledger_entry();

-- Sonuçlanan bahiste kazanan seçeneğe yatıranlar (düello kazananı dahil) XP alır.
-- settle_bet ödemeleri yaptıktan sonra durumu günceller: profil kilitleri bakiyelerden sonra gelir.
create function private.xp_on_settled_bet() returns trigger
language plpgsql set search_path = '' as $$
declare
  v_amount integer;
  v_w record;
begin
  select s.xp_correct_pick into v_amount from public.economy_settings s where s.id;
  for v_w in
    select w.id, w.user_id
    from public.wagers w join public.bet_options o on o.id = w.option_id
    where w.bet_id = new.id and o.is_winner
    order by w.user_id
  loop
    perform private.award_xp(v_w.user_id, 'correct_pick', v_amount, null, v_w.id);
  end loop;
  return null;
end;
$$;

create trigger bets_award_xp
  after update of status on public.bets
  for each row when (new.status = 'settled' and old.status is distinct from 'settled')
  execute function private.xp_on_settled_bet();

revoke execute on function
  private.xp_for_level(integer),
  private.level_for_xp(integer),
  private.award_xp(uuid, public.xp_reason, integer, bigint, uuid),
  private.xp_on_ledger_entry(),
  private.xp_on_settled_bet()
from public;

-- ---------------------------------------------------------------------------
-- İstemci: ilerleme
-- ---------------------------------------------------------------------------

-- Kişinin XP'si, seviyesi, seviyenin başladığı / sonraki seviyenin XP'si ve bugün tahminden aldığı XP.
create function public.my_progress()
returns table (xp integer, level integer, level_xp integer, next_level_xp integer, pick_xp_today integer)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
  v_profile public.profiles;
  v_tz text;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  select * into v_profile from public.profiles p where p.id = v_uid;
  if not found then
    raise exception 'Profil bulunamadı' using errcode = 'P0002';
  end if;
  select s.day_timezone into v_tz from public.economy_settings s where s.id;

  return query
    select v_profile.xp, v_profile.level,
           private.xp_for_level(v_profile.level), private.xp_for_level(v_profile.level + 1),
           (select coalesce(sum(e.amount), 0)::integer from public.xp_events e
            where e.user_id = v_uid and e.reason = 'correct_pick'
              and e.created_at >= (date_trunc('day', now() at time zone v_tz) at time zone v_tz));
end;
$$;

revoke execute on function public.my_progress() from public, anon;
grant execute on function public.my_progress() to authenticated;

-- ---------------------------------------------------------------------------
-- Market: seviye koşulu
-- ---------------------------------------------------------------------------

create or replace function public.purchase_market_item(p_item_id uuid) returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_item public.market_items;
  v_level integer;
  v_rows integer;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  select p.level into v_level from public.profiles p where p.id = v_uid;
  if not found then
    raise exception 'Profil bulunamadı' using errcode = 'P0002';
  end if;
  select * into v_item from public.market_items i where i.id = p_item_id;
  if not found or (v_item.school_id is not null and v_item.school_id is distinct from private.school_of_user(v_uid)) then
    raise exception 'Ürün bulunamadı' using errcode = 'P0002';
  end if;
  if not v_item.active
     or (v_item.available_from is not null and now() < v_item.available_from)
     or (v_item.available_until is not null and now() >= v_item.available_until) then
    raise exception 'Bu ürün şu an satışta değil' using errcode = 'KB021';
  end if;
  if v_level < v_item.min_level then
    raise exception 'Bu ürün için seviye % gerekir', v_item.min_level using errcode = 'KB023';
  end if;

  insert into public.user_inventory (user_id, item_id, category, price_paid, currency)
  values (v_uid, v_item.id, v_item.category, v_item.price, v_item.currency)
  on conflict do nothing;
  get diagnostics v_rows = row_count;
  if v_rows = 0 then
    raise exception 'Bu ürün zaten sende' using errcode = 'KB022';
  end if;

  -- Bakiye yetmezse KB001; envanter satırı da geri alınır.
  return private.post_ledger(v_uid, v_item.currency, -v_item.price, 'market_purchase', 'market_item', v_item.id, v_uid, null);
end;
$$;

-- ---------------------------------------------------------------------------
-- Görevler: XP'yi de döner
-- ---------------------------------------------------------------------------

drop function public.my_quests();
create function public.my_quests()
returns table (
  quest_id uuid, title text, description text, period public.quest_period, action public.quest_action,
  target integer, reward_currency public.currency, reward_amount integer, progress integer, claimed boolean,
  period_ends_at timestamptz, reward_xp integer
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  return query
    select q.id, q.title, q.description, q.period, q.action, q.target, q.reward_currency, q.reward_amount,
           least(private.quest_progress(v_uid, q.action, w.o_start, w.o_end), q.target),
           exists (select 1 from public.quest_claims c
                   where c.user_id = v_uid and c.quest_id = q.id and c.period_start = w.o_start),
           w.o_end, q.reward_xp
    from public.quests q
    cross join lateral private.quest_window(q) w
    where private.quest_open_for(v_uid, q)
    order by q.period, q.reward_currency desc, q.reward_amount desc, q.title;
end;
$$;

revoke execute on function public.my_quests() from public, anon;
grant execute on function public.my_quests() to authenticated;

-- ---------------------------------------------------------------------------
-- Yönetim: görevin XP'si, ürünün seviyesi (yeni parametreler sonda, varsayılanlı)
-- ---------------------------------------------------------------------------

drop function public.save_quest(uuid, uuid, text, text, public.quest_period, public.quest_action, integer,
                                public.currency, integer, timestamptz, timestamptz, boolean);
create function public.save_quest(
  p_id uuid,
  p_school_id uuid,
  p_title text,
  p_description text,
  p_period public.quest_period,
  p_action public.quest_action,
  p_target integer,
  p_reward_currency public.currency,
  p_reward_amount integer,
  p_starts_at timestamptz default null,
  p_ends_at timestamptz default null,
  p_active boolean default true,
  p_reward_xp integer default 0
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_old public.quests;
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  if p_id is not null then
    select * into v_old from public.quests q where q.id = p_id;
    if not found then
      raise exception 'Görev bulunamadı' using errcode = 'P0002';
    end if;
    if (v_old.school_id is null and not private.is_superadmin())
       or (v_old.school_id is not null and not private.has_permission(v_old.school_id, 'gorev_yonet')) then
      raise exception 'Bu işlem için yetkin yok' using errcode = '42501';
    end if;
  end if;
  if p_school_id is null and not private.is_superadmin() then
    raise exception 'Tüm okullara görevi yalnızca süperadmin ekler' using errcode = '42501';
  end if;
  if p_school_id is not null and not private.has_permission(p_school_id, 'gorev_yonet') then
    raise exception 'Bu işlem için yetkin yok' using errcode = '42501';
  end if;
  if p_reward_currency = 'SSP' and not private.is_superadmin() then
    raise exception 'SSP ödüllü görevi yalnızca süperadmin ekler' using errcode = '42501';
  end if;

  if p_id is null then
    insert into public.quests (school_id, title, description, period, action, target, reward_currency, reward_amount,
                               reward_xp, starts_at, ends_at, active, created_by)
    values (p_school_id, btrim(p_title), nullif(btrim(p_description), ''), p_period, p_action, p_target,
            p_reward_currency, p_reward_amount, coalesce(p_reward_xp, 0), p_starts_at, p_ends_at,
            coalesce(p_active, true), v_uid)
    returning id into v_id;
  else
    update public.quests
    set school_id = p_school_id, title = btrim(p_title), description = nullif(btrim(p_description), ''),
        period = p_period, action = p_action, target = p_target, reward_currency = p_reward_currency,
        reward_amount = p_reward_amount, reward_xp = coalesce(p_reward_xp, 0), starts_at = p_starts_at,
        ends_at = p_ends_at, active = coalesce(p_active, true)
    where id = p_id
    returning id into v_id;
  end if;

  insert into public.admin_audit_log (actor_id, action, cluster_id, details)
  values (v_uid, 'quest_save', p_school_id,
          jsonb_build_object('quest_id', v_id, 'title', btrim(p_title), 'reward', p_reward_amount,
                             'currency', p_reward_currency, 'xp', coalesce(p_reward_xp, 0),
                             'active', coalesce(p_active, true)));
  return v_id;
end;
$$;

drop function public.save_market_item(uuid, uuid, text, text, public.market_category, integer, public.currency, text,
                                      text, timestamptz, timestamptz, boolean);
create function public.save_market_item(
  p_id uuid,
  p_school_id uuid,
  p_name text,
  p_description text,
  p_category public.market_category,
  p_price integer,
  p_currency public.currency,
  p_icon text default null,
  p_color text default null,
  p_available_from timestamptz default null,
  p_available_until timestamptz default null,
  p_active boolean default true,
  p_min_level integer default 1
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_old public.market_items;
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  if p_id is not null then
    select * into v_old from public.market_items i where i.id = p_id;
    if not found then
      raise exception 'Ürün bulunamadı' using errcode = 'P0002';
    end if;
    if (v_old.school_id is null and not private.is_superadmin())
       or (v_old.school_id is not null and not private.has_permission(v_old.school_id, 'market_yonet')) then
      raise exception 'Bu işlem için yetkin yok' using errcode = '42501';
    end if;
    if v_old.category <> p_category then
      raise exception 'Ürünün türü sonradan değiştirilemez' using errcode = '23514';
    end if;
  end if;
  if p_school_id is null and not private.is_superadmin() then
    raise exception 'Tüm okullara ürünü yalnızca süperadmin ekler' using errcode = '42501';
  end if;
  if p_school_id is not null and not private.has_permission(p_school_id, 'market_yonet') then
    raise exception 'Bu işlem için yetkin yok' using errcode = '42501';
  end if;

  if p_id is null then
    insert into public.market_items (school_id, name, description, category, icon, color, price, currency,
                                     available_from, available_until, active, min_level, created_by)
    values (p_school_id, btrim(p_name), nullif(btrim(p_description), ''), p_category, nullif(btrim(p_icon), ''),
            nullif(btrim(p_color), ''), p_price, p_currency, p_available_from, p_available_until,
            coalesce(p_active, true), coalesce(p_min_level, 1), v_uid)
    returning id into v_id;
  else
    update public.market_items
    set school_id = p_school_id, name = btrim(p_name), description = nullif(btrim(p_description), ''),
        icon = nullif(btrim(p_icon), ''), color = nullif(btrim(p_color), ''), price = p_price, currency = p_currency,
        available_from = p_available_from, available_until = p_available_until, active = coalesce(p_active, true),
        min_level = coalesce(p_min_level, 1)
    where id = p_id
    returning id into v_id;
  end if;

  insert into public.admin_audit_log (actor_id, action, cluster_id, details)
  values (v_uid, 'market_item_save', p_school_id,
          jsonb_build_object('item_id', v_id, 'name', btrim(p_name), 'price', p_price, 'currency', p_currency,
                             'min_level', coalesce(p_min_level, 1), 'active', coalesce(p_active, true)));
  return v_id;
end;
$$;

revoke execute on function
  public.save_quest(uuid, uuid, text, text, public.quest_period, public.quest_action, integer, public.currency, integer,
                    timestamptz, timestamptz, boolean, integer),
  public.save_market_item(uuid, uuid, text, text, public.market_category, integer, public.currency, text, text,
                          timestamptz, timestamptz, boolean, integer)
from public, anon;
grant execute on function
  public.save_quest(uuid, uuid, text, text, public.quest_period, public.quest_action, integer, public.currency, integer,
                    timestamptz, timestamptz, boolean, integer),
  public.save_market_item(uuid, uuid, text, text, public.market_category, integer, public.currency, text, text,
                          timestamptz, timestamptz, boolean, integer)
to authenticated;

-- ---------------------------------------------------------------------------
-- Liderlik: satırda seviye
-- ---------------------------------------------------------------------------

drop function public.get_leaderboard(public.leaderboard_metric, public.leaderboard_period, integer, uuid, integer);
create function public.get_leaderboard(
  p_metric public.leaderboard_metric,
  p_period public.leaderboard_period,
  p_weeks_ago integer default 0,
  p_school_id uuid default null,
  p_limit integer default 50
)
returns table (
  rank integer, user_id uuid, first_name text, last_name text, value numeric, sample integer, is_me boolean,
  title text, title_icon text, badge text, badge_name text, frame_color text, name_color text,
  period_start date, computed_at timestamptz, level integer
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
  v_school uuid;
  v_day date;
  v_computed timestamptz;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  v_school := coalesce(p_school_id, private.school_of_user(v_uid));
  if v_school is null then
    raise exception 'Profil bulunamadı' using errcode = 'P0002';
  end if;
  if v_school is distinct from private.school_of_user(v_uid) and not private.has_permission(v_school, 'analitik_gor') then
    raise exception 'Okul bulunamadı' using errcode = 'P0002';
  end if;
  if p_weeks_ago is null or p_weeks_ago not between 0 and 52 or p_limit is null or p_limit not between 1 and 100 then
    raise exception 'Geçersiz sıralama isteği' using errcode = '23514';
  end if;
  if p_period = 'week' then
    select b.o_day into v_day from private.week_bounds(p_weeks_ago) b;
  end if;

  select r.computed_at into v_computed from private.leaderboard_runs r
  where r.school_id = v_school and r.period = p_period and r.period_start is not distinct from v_day;

  return query
    with s as (
      select l.* from public.leaderboard_snapshots l
      where l.school_id = v_school and l.period = p_period and l.metric = p_metric
        and l.period_start is not distinct from v_day
    ),
    picked as (
      (select s.user_id, s.rank, s.value, s.sample from s order by s.rank, s.user_id limit p_limit)
      union
      (select s.user_id, s.rank, s.value, s.sample from s where s.user_id = v_uid)
    )
    select pk.rank, pk.user_id, p.first_name, p.last_name, pk.value, pk.sample, pk.user_id = v_uid,
           c.title, c.title_icon, c.badge, c.badge_name, c.frame_color, c.name_color, v_day, v_computed, p.level
    from picked pk
    join public.profiles p on p.id = pk.user_id
    left join lateral (
      select max(m.name) filter (where m.category = 'title') as title,
             max(m.icon) filter (where m.category = 'title') as title_icon,
             max(m.icon) filter (where m.category = 'badge') as badge,
             max(m.name) filter (where m.category = 'badge') as badge_name,
             max(m.color) filter (where m.category = 'frame') as frame_color,
             max(m.color) filter (where m.category = 'name_color') as name_color
      from public.user_inventory i join public.market_items m on m.id = i.item_id
      where i.user_id = pk.user_id and i.equipped
    ) c on true
    order by pk.rank, p.first_name, p.last_name, pk.user_id;
end;
$$;

revoke execute on function
  public.get_leaderboard(public.leaderboard_metric, public.leaderboard_period, integer, uuid, integer)
from public, anon;
grant execute on function
  public.get_leaderboard(public.leaderboard_metric, public.leaderboard_period, integer, uuid, integer)
to authenticated;
