-- Adım 9: görevler + kozmetik market (MIMARI §7.4, §11, §12; KARARLAR "Görevler", "Market").
--
-- Görev ilerlemesi ayrı sayaçla tutulmaz: istek anında mevcut kayıtlardan sayılır (yatırımlar, düello
-- oyunları, açılan sosyal bahisler, kazanılan bahisler). Ödül, dönem başına bir kez, sunucu ilerlemeyi
-- yeniden sayınca verilir (quest_claims birincil anahtarı tekrarı engeller).
-- Market yalnızca kozmetik: satın alınan hiçbir şey bahis kurallarını, oranı ya da ödemeyi etkilemez
-- (MIMARI §2). SSP ödüllü görevi yalnızca süperadmin açar (SSP kıt kalır); SSP fiyatlı ürün serbesttir.

-- ---------------------------------------------------------------------------
-- Türler ve tablolar
-- ---------------------------------------------------------------------------

create type public.quest_period as enum ('daily', 'weekly', 'seasonal');
-- wager: bahse yatırım (resmi, sosyal, günün tahmini; düello hariç) · prediction: günün tahmini ·
-- duel: trivia düellosu oyna · social_bet: sosyal bahis aç (iptal edilmemiş) · win: kazanılan bahis
create type public.quest_action as enum ('wager', 'prediction', 'duel', 'social_bet', 'win');
create type public.market_category as enum ('title', 'badge', 'frame', 'name_color');

create table public.quests (
  id uuid primary key default gen_random_uuid(),
  -- null: tüm okullar (yalnızca süperadmin yönetir)
  school_id uuid references public.clusters (id) on delete restrict,
  title text not null check (char_length(title) between 3 and 80 and title = btrim(title) and title !~ '[[:cntrl:]]'),
  description text check (description is null or (char_length(description) between 1 and 300 and description = btrim(description))),
  period public.quest_period not null,
  action public.quest_action not null,
  target integer not null check (target between 1 and 100),
  reward_currency public.currency not null default 'SP',
  reward_amount integer not null check (reward_amount between 1 and 1000),
  -- Görevin göründüğü aralık (günlük / haftalıkta isteğe bağlı, sezonlukta zorunlu ve dönemin kendisi).
  starts_at timestamptz,
  ends_at timestamptz,
  active boolean not null default true,
  created_by uuid references public.profiles (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint quests_window check (starts_at is null or ends_at is null or ends_at > starts_at),
  constraint quests_seasonal_window check (period <> 'seasonal' or (starts_at is not null and ends_at is not null))
);
create index quests_school_idx on public.quests (school_id) where active;

create trigger quests_require_school
  before insert or update of school_id on public.quests
  for each row when (new.school_id is not null) execute function private.require_school('school_id');
create trigger quests_set_updated_at
  before update on public.quests
  for each row execute function private.set_updated_at();

-- Verilen ödüller; dönem başına bir. Yalnızca eklenir.
create table public.quest_claims (
  user_id uuid not null references public.profiles (id) on delete restrict,
  quest_id uuid not null references public.quests (id) on delete restrict,
  period_start timestamptz not null,
  reward_currency public.currency not null,
  reward_amount integer not null check (reward_amount > 0),
  claimed_at timestamptz not null default now(),
  primary key (user_id, quest_id, period_start)
);
create index quest_claims_quest_idx on public.quest_claims (quest_id);

create trigger quest_claims_append_only
  before update or delete on public.quest_claims
  for each row execute function private.forbid_change();
create trigger quest_claims_no_truncate
  before truncate on public.quest_claims
  for each statement execute function private.forbid_change();

create table public.market_items (
  id uuid primary key default gen_random_uuid(),
  -- null: tüm okullar (yalnızca süperadmin yönetir)
  school_id uuid references public.clusters (id) on delete restrict,
  name text not null check (char_length(name) between 2 and 60 and name = btrim(name) and name !~ '[[:cntrl:]]'),
  description text check (description is null or (char_length(description) between 1 and 300 and description = btrim(description))),
  category public.market_category not null,
  -- Rozet / unvan simgesi (emoji); çerçeve ve isim rengi için renk (#RRGGBB).
  icon text check (icon is null or (char_length(icon) between 1 and 8 and icon = btrim(icon))),
  color text check (color is null or color ~ '^#[0-9A-Fa-f]{6}$'),
  price integer not null check (price between 1 and 100000),
  currency public.currency not null default 'SP',
  available_from timestamptz,
  available_until timestamptz,
  active boolean not null default true,
  created_by uuid references public.profiles (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint market_items_window check (available_from is null or available_until is null or available_until > available_from),
  constraint market_items_color_needed check (category not in ('frame', 'name_color') or color is not null)
);
create index market_items_school_idx on public.market_items (school_id) where active;

create trigger market_items_require_school
  before insert or update of school_id on public.market_items
  for each row when (new.school_id is not null) execute function private.require_school('school_id');
create trigger market_items_set_updated_at
  before update on public.market_items
  for each row execute function private.set_updated_at();

create table public.user_inventory (
  user_id uuid not null references public.profiles (id) on delete restrict,
  item_id uuid not null references public.market_items (id) on delete restrict,
  -- Satın alma anındaki tür (ürünün türü sonradan değiştirilemez); kategori başına tek kuşanılmış ürün.
  category public.market_category not null,
  equipped boolean not null default false,
  price_paid integer not null check (price_paid > 0),
  currency public.currency not null,
  acquired_at timestamptz not null default now(),
  primary key (user_id, item_id)
);
create index user_inventory_item_idx on public.user_inventory (item_id);
create unique index user_inventory_one_equipped_per_category on public.user_inventory (user_id, category) where equipped;

-- ---------------------------------------------------------------------------
-- Görünürlük
-- ---------------------------------------------------------------------------

revoke all on public.quests, public.quest_claims, public.market_items, public.user_inventory from anon, authenticated;
grant select on public.quests, public.quest_claims, public.market_items, public.user_inventory to authenticated;
alter table public.quests enable row level security;
alter table public.quest_claims enable row level security;
alter table public.market_items enable row level security;
alter table public.user_inventory enable row level security;

-- Öğrenci okulunun ve genel aktif görevleri görür; yönetenler (pasifler dahil) yönettiklerini.
create policy quests_select on public.quests
  for select to authenticated
  using (
    (active and (school_id is null or school_id = (select private.current_school_id())))
    or (select private.is_superadmin())
    or (school_id is not null and private.has_permission(school_id, 'gorev_yonet'))
  );

create policy quest_claims_select on public.quest_claims
  for select to authenticated
  using (user_id = (select auth.uid()) or (select private.is_superadmin()));

create policy market_items_select on public.market_items
  for select to authenticated
  using (
    (active and (school_id is null or school_id = (select private.current_school_id())))
    or (select private.is_superadmin())
    or (school_id is not null and private.has_permission(school_id, 'market_yonet'))
  );

-- Kişi kendi envanterini görür; kuşanılmış ürünler okul arkadaşlarına da görünür (prestij).
create policy user_inventory_select on public.user_inventory
  for select to authenticated
  using (
    user_id = (select auth.uid())
    or (select private.is_superadmin())
    or (equipped and private.school_of_user(user_id) = (select private.current_school_id()))
  );

-- ---------------------------------------------------------------------------
-- Görev ilerlemesi (iç)
-- ---------------------------------------------------------------------------

-- Görevin şu anki dönemi: günlük / haftalık takvime göre (gün ayardaki saat diliminde, hafta pazartesi
-- başlar), sezonluk görevin kendi aralığı.
create function private.quest_window(p_quest public.quests, out o_start timestamptz, out o_end timestamptz)
language plpgsql stable set search_path = '' as $$
declare
  v_tz text;
  v_local timestamp;
begin
  select s.day_timezone into v_tz from public.economy_settings s where s.id;
  v_local := now() at time zone v_tz;
  case p_quest.period
    when 'daily' then
      o_start := date_trunc('day', v_local) at time zone v_tz;
      o_end := (date_trunc('day', v_local) + interval '1 day') at time zone v_tz;
    when 'weekly' then
      o_start := date_trunc('week', v_local) at time zone v_tz;
      o_end := (date_trunc('week', v_local) + interval '7 days') at time zone v_tz;
    else
      o_start := p_quest.starts_at;
      o_end := p_quest.ends_at;
  end case;
end;
$$;

-- Kişinin [p_from, p_to) aralığında görevin eylemini kaç kez yaptığı.
create function private.quest_progress(p_user_id uuid, p_action public.quest_action, p_from timestamptz, p_to timestamptz)
returns integer
language sql stable set search_path = '' as $$
  select case p_action
    when 'wager' then (
      select count(*) from public.wagers w join public.bets b on b.id = w.bet_id
      where w.user_id = p_user_id and w.created_at >= p_from and w.created_at < p_to
        and not (b.type = 'sp_minigame' and b.settlement_mode = 'auto'))
    when 'prediction' then (
      select count(*) from public.wagers w join public.bets b on b.id = w.bet_id
      where w.user_id = p_user_id and w.created_at >= p_from and w.created_at < p_to
        and b.type = 'sp_minigame' and b.settlement_mode = 'admin')
    when 'duel' then (
      select count(*) from public.trivia_duel_plays p
      where p.player_id = p_user_id and p.submitted_at >= p_from and p.submitted_at < p_to)
    when 'social_bet' then (
      select count(*) from public.bets b
      where b.creator_id = p_user_id and b.type = 'sp_social' and b.status <> 'cancelled'
        and b.created_at >= p_from and b.created_at < p_to)
    when 'win' then (
      select count(*) from public.wagers w join public.bets b on b.id = w.bet_id
      where w.user_id = p_user_id and b.status = 'settled' and b.settled_at >= p_from and b.settled_at < p_to
        and w.payout > w.amount)
  end::integer;
$$;

-- Kişinin şu an görebildiği ve dönemi açık görev.
create function private.quest_open_for(p_user_id uuid, p_quest public.quests) returns boolean
language sql stable set search_path = '' as $$
  select p_quest.active
    and (p_quest.school_id is null or p_quest.school_id = private.school_of_user(p_user_id))
    and (p_quest.starts_at is null or now() >= p_quest.starts_at)
    and (p_quest.ends_at is null or now() < p_quest.ends_at);
$$;

revoke execute on function
  private.quest_window(public.quests),
  private.quest_progress(uuid, public.quest_action, timestamptz, timestamptz),
  private.quest_open_for(uuid, public.quests)
from public;

-- ---------------------------------------------------------------------------
-- Görevler (öğrenci)
-- ---------------------------------------------------------------------------

-- Açık görevler, bu dönemdeki ilerleme (hedefle sınırlı) ve ödülün alınıp alınmadığı.
create function public.my_quests()
returns table (
  quest_id uuid, title text, description text, period public.quest_period, action public.quest_action,
  target integer, reward_currency public.currency, reward_amount integer, progress integer, claimed boolean,
  period_ends_at timestamptz
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
           w.o_end
    from public.quests q
    cross join lateral private.quest_window(q) w
    where private.quest_open_for(v_uid, q)
    order by q.period, q.reward_currency desc, q.reward_amount desc, q.title;
end;
$$;

-- Görev tamamlandıysa ödülü verir (dönem başına bir kez). Yeni bakiyeyi döner.
create function public.claim_quest_reward(p_quest_id uuid)
returns table (reward_currency public.currency, reward_amount integer, balance bigint)
language plpgsql security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
  v_quest public.quests;
  v_start timestamptz;
  v_end timestamptz;
  v_rows integer;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  if not exists (select 1 from public.profiles p where p.id = v_uid) then
    raise exception 'Profil bulunamadı' using errcode = 'P0002';
  end if;
  select * into v_quest from public.quests q where q.id = p_quest_id;
  if not found or not private.quest_open_for(v_uid, v_quest) then
    raise exception 'Görev bulunamadı' using errcode = 'P0002';
  end if;

  select w.o_start, w.o_end into v_start, v_end from private.quest_window(v_quest) w;
  if private.quest_progress(v_uid, v_quest.action, v_start, v_end) < v_quest.target then
    raise exception 'Görev henüz tamamlanmadı' using errcode = 'KB019';
  end if;

  -- Aynı anda gelen ikinci istek birincil anahtarda bekler, sonra hiçbir şey eklemez.
  insert into public.quest_claims (user_id, quest_id, period_start, reward_currency, reward_amount)
  values (v_uid, v_quest.id, v_start, v_quest.reward_currency, v_quest.reward_amount)
  on conflict do nothing;
  get diagnostics v_rows = row_count;
  if v_rows = 0 then
    raise exception 'Bu görevin ödülünü bu dönem zaten aldın' using errcode = 'KB020';
  end if;

  reward_currency := v_quest.reward_currency;
  reward_amount := v_quest.reward_amount;
  balance := private.post_ledger(v_uid, v_quest.reward_currency, v_quest.reward_amount, 'quest_reward', 'quest',
                                 v_quest.id, v_uid, null);
  return next;
end;
$$;

-- ---------------------------------------------------------------------------
-- Market (öğrenci)
-- ---------------------------------------------------------------------------

-- Ürünü satın alır: envantere ekler, fiyatı düşer (tek transaction). Yeni bakiyeyi döner.
create function public.purchase_market_item(p_item_id uuid) returns bigint
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_item public.market_items;
  v_rows integer;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  if not exists (select 1 from public.profiles p where p.id = v_uid) then
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

-- Ürünü kuşanır ya da çıkarır; kuşanınca aynı türdeki diğer ürün çıkarılır.
create function public.set_item_equipped(p_item_id uuid, p_equipped boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_row public.user_inventory;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  select * into v_row from public.user_inventory i where i.user_id = v_uid and i.item_id = p_item_id for update;
  if not found then
    raise exception 'Bu ürün sende değil' using errcode = 'P0002';
  end if;
  if coalesce(p_equipped, false) then
    update public.user_inventory set equipped = false
    where user_id = v_uid and category = v_row.category and equipped and item_id <> p_item_id;
  end if;
  update public.user_inventory set equipped = coalesce(p_equipped, false) where user_id = v_uid and item_id = p_item_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Yönetim (admin paneli)
-- ---------------------------------------------------------------------------

-- p_id null ise yeni görev. Genel görev ve SSP ödülü yalnızca süperadmin; okul görevi gorev_yonet.
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
  p_active boolean default true
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
                               starts_at, ends_at, active, created_by)
    values (p_school_id, btrim(p_title), nullif(btrim(p_description), ''), p_period, p_action, p_target,
            p_reward_currency, p_reward_amount, p_starts_at, p_ends_at, coalesce(p_active, true), v_uid)
    returning id into v_id;
  else
    update public.quests
    set school_id = p_school_id, title = btrim(p_title), description = nullif(btrim(p_description), ''),
        period = p_period, action = p_action, target = p_target, reward_currency = p_reward_currency,
        reward_amount = p_reward_amount, starts_at = p_starts_at, ends_at = p_ends_at, active = coalesce(p_active, true)
    where id = p_id
    returning id into v_id;
  end if;

  insert into public.admin_audit_log (actor_id, action, cluster_id, details)
  values (v_uid, 'quest_save', p_school_id,
          jsonb_build_object('quest_id', v_id, 'title', btrim(p_title), 'reward', p_reward_amount,
                             'currency', p_reward_currency, 'active', coalesce(p_active, true)));
  return v_id;
end;
$$;

-- p_id null ise yeni ürün. Genel ürün yalnızca süperadmin; okul ürünü market_yonet. Tür sonradan değişmez.
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
  p_active boolean default true
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
                                     available_from, available_until, active, created_by)
    values (p_school_id, btrim(p_name), nullif(btrim(p_description), ''), p_category, nullif(btrim(p_icon), ''),
            nullif(btrim(p_color), ''), p_price, p_currency, p_available_from, p_available_until,
            coalesce(p_active, true), v_uid)
    returning id into v_id;
  else
    update public.market_items
    set school_id = p_school_id, name = btrim(p_name), description = nullif(btrim(p_description), ''),
        icon = nullif(btrim(p_icon), ''), color = nullif(btrim(p_color), ''), price = p_price, currency = p_currency,
        available_from = p_available_from, available_until = p_available_until, active = coalesce(p_active, true)
    where id = p_id
    returning id into v_id;
  end if;

  insert into public.admin_audit_log (actor_id, action, cluster_id, details)
  values (v_uid, 'market_item_save', p_school_id,
          jsonb_build_object('item_id', v_id, 'name', btrim(p_name), 'price', p_price, 'currency', p_currency,
                             'active', coalesce(p_active, true)));
  return v_id;
end;
$$;

revoke execute on function
  public.my_quests(),
  public.claim_quest_reward(uuid),
  public.purchase_market_item(uuid),
  public.set_item_equipped(uuid, boolean),
  public.save_quest(uuid, uuid, text, text, public.quest_period, public.quest_action, integer, public.currency, integer,
                    timestamptz, timestamptz, boolean),
  public.save_market_item(uuid, uuid, text, text, public.market_category, integer, public.currency, text, text,
                          timestamptz, timestamptz, boolean)
from public, anon;

grant execute on function
  public.my_quests(),
  public.claim_quest_reward(uuid),
  public.purchase_market_item(uuid),
  public.set_item_equipped(uuid, boolean),
  public.save_quest(uuid, uuid, text, text, public.quest_period, public.quest_action, integer, public.currency, integer,
                    timestamptz, timestamptz, boolean),
  public.save_market_item(uuid, uuid, text, text, public.market_category, integer, public.currency, text, text,
                          timestamptz, timestamptz, boolean)
to authenticated;
