-- Adım 10: liderlik + istatistik (MIMARI §7.5, §8, §11; KARARLAR "Liderlik ve istatistik").
--
-- Sıralama beceriyi öne çıkarır, bahis sayısını değil: isabet oranı, net kazanç (SP ve SSP ayrı),
-- en uzun doğru tahmin serisi. "Tahmin" = düello dışı her bahis (resmi, sosyal, günün tahmini);
-- düello bir beceri oyunudur, isabet ve seriye girmez ama net SP kazancına girer.
-- Sıralama her 10 dakikada bir okul okul hesaplanıp `leaderboard_snapshots`'a yazılır (bu hafta ve
-- tüm zamanlar). Biten haftanın sıralaması hafta bittikten sonra bir kez daha hesaplanır ve kalır.
-- Kişisel istatistik (`my_stats`) ve okul özeti (`school_stats`) istek anında kayıtlardan sayılır.

-- ---------------------------------------------------------------------------
-- Türler, ayarlar, tablolar
-- ---------------------------------------------------------------------------

create type public.leaderboard_period as enum ('week', 'all_time');
create type public.leaderboard_metric as enum ('hit_rate', 'sp_profit', 'ssp_profit', 'best_streak');

-- İsabet oranı sıralamasına girmek için gereken en az sonuçlanmış tahmin (1/1 = %100 öne çıkmasın).
alter table public.economy_settings
  add column leaderboard_min_predictions_week integer not null default 5
    check (leaderboard_min_predictions_week between 1 and 100),
  add column leaderboard_min_predictions_all integer not null default 20
    check (leaderboard_min_predictions_all between 1 and 1000);

create table public.leaderboard_snapshots (
  school_id uuid not null references public.clusters (id) on delete restrict,
  period public.leaderboard_period not null,
  -- Haftanın ilk günü (pazartesi, ayardaki saat diliminde); tüm zamanlarda null.
  period_start date,
  metric public.leaderboard_metric not null,
  user_id uuid not null references public.profiles (id) on delete restrict,
  rank integer not null check (rank >= 1),
  -- hit_rate: 0–1 arası oran; sp_profit / ssp_profit: net kazanç; best_streak: art arda doğru tahmin.
  value numeric not null,
  -- hit_rate / best_streak: sonuçlanmış tahmin sayısı; kazanç: o para birimindeki sonuçlanmış yatırım sayısı.
  sample integer not null check (sample >= 1),
  computed_at timestamptz not null,
  constraint leaderboard_snapshots_period_start check ((period = 'week') = (period_start is not null)),
  constraint leaderboard_snapshots_unique unique nulls not distinct (school_id, period, period_start, metric, user_id)
);
create index leaderboard_snapshots_rank_idx
  on public.leaderboard_snapshots (school_id, period, period_start, metric, rank);
create index leaderboard_snapshots_user_idx on public.leaderboard_snapshots (user_id);

-- Hangi sıralama ne zaman hesaplandı (satırı olmayan sıralama için de).
create table private.leaderboard_runs (
  school_id uuid not null references public.clusters (id) on delete cascade,
  period public.leaderboard_period not null,
  period_start date,
  computed_at timestamptz not null,
  constraint leaderboard_runs_unique unique nulls not distinct (school_id, period, period_start)
);
alter table private.leaderboard_runs enable row level security;

-- Sıralama hesabı bahisleri sonuçlanma zamanına göre süzer.
create index if not exists bets_settled_at_idx on public.bets (settled_at) where status = 'settled';

-- ---------------------------------------------------------------------------
-- Görünürlük
-- ---------------------------------------------------------------------------

alter table public.leaderboard_snapshots enable row level security;
revoke all on public.leaderboard_snapshots from anon, authenticated;
grant select on public.leaderboard_snapshots to authenticated;

-- Okulun öğrencileri kendi okulununkini, `analitik_gor` sahibi (ve süperadmin) yetkili olduğu okulunkini görür.
create policy leaderboard_snapshots_select on public.leaderboard_snapshots
  for select to authenticated
  using (school_id = (select private.current_school_id()) or private.has_permission(school_id, 'analitik_gor'));

-- ---------------------------------------------------------------------------
-- Hesaplama (iç)
-- ---------------------------------------------------------------------------

-- Bu haftadan p_weeks_ago hafta önceki haftanın sınırları (hafta pazartesi başlar, gün ayardaki saat diliminde).
create function private.week_bounds(p_weeks_ago integer, out o_day date, out o_start timestamptz, out o_end timestamptz)
language plpgsql stable set search_path = '' as $$
declare
  v_tz text;
  v_week timestamp;
begin
  select s.day_timezone into v_tz from public.economy_settings s where s.id;
  v_week := date_trunc('week', now() at time zone v_tz) - make_interval(weeks => p_weeks_ago);
  o_day := v_week::date;
  o_start := v_week at time zone v_tz;
  o_end := (v_week + interval '7 days') at time zone v_tz;
end;
$$;

-- [p_from, p_to) aralığında sonuçlanan yatırımlar: okula ya da kişiye göre (null = süzme).
-- is_prediction: düello dışı; correct: seçilen seçenek kazandı (kazanan tarafa kimse yatırmadığı için
-- iade alan da yanlış bilmiştir); net: ödeme − yatırım.
create function private.settled_wagers(p_school_id uuid, p_user_id uuid, p_from timestamptz, p_to timestamptz)
returns table (
  user_id uuid, bet_id uuid, settled_at timestamptz, currency public.currency,
  is_prediction boolean, correct boolean, net bigint
)
language sql stable set search_path = '' as $$
  select w.user_id, b.id, b.settled_at, b.currency,
         not (b.type = 'sp_minigame' and b.settlement_mode = 'auto'),
         coalesce(o.is_winner, false),
         coalesce(w.payout, 0) - w.amount
  from public.wagers w
  join public.profiles p on p.id = w.user_id
  join public.bets b on b.id = w.bet_id
  join public.bet_options o on o.id = w.option_id
  where b.status = 'settled'
    and b.settled_at >= p_from and b.settled_at < p_to
    and (p_school_id is null or p.school_id = p_school_id)
    and (p_user_id is null or w.user_id = p_user_id);
$$;

-- Bir okulun bir dönemlik sıralamasını baştan yazar.
create function private.store_leaderboard(
  p_school_id uuid, p_period public.leaderboard_period, p_day date, p_from timestamptz, p_to timestamptz
) returns void
language plpgsql set search_path = '' as $$
declare
  v_min integer;
begin
  select case p_period when 'week' then s.leaderboard_min_predictions_week else s.leaderboard_min_predictions_all end
    into v_min
  from public.economy_settings s where s.id;

  delete from public.leaderboard_snapshots l
  where l.school_id = p_school_id and l.period = p_period and l.period_start is not distinct from p_day;

  insert into public.leaderboard_snapshots (school_id, period, period_start, metric, user_id, rank, value, sample, computed_at)
  with sw as (
    select * from private.settled_wagers(p_school_id, null, p_from, p_to)
  ),
  preds as (
    -- grp: art arda aynı sonuçtaki tahminler aynı değeri alır (boşluk-ada yöntemi).
    select sw.user_id, sw.correct,
           row_number() over (partition by sw.user_id order by sw.settled_at, sw.bet_id)
             - row_number() over (partition by sw.user_id, sw.correct order by sw.settled_at, sw.bet_id) as grp
    from sw where sw.is_prediction
  ),
  totals as (
    select p.user_id, count(*)::integer as n, count(*) filter (where p.correct)::integer as hits
    from preds p group by p.user_id
  ),
  runs as (
    select p.user_id, count(*)::integer as len from preds p where p.correct group by p.user_id, p.grp
  ),
  profit as (
    select sw.user_id, sw.currency, sum(sw.net) as total, count(*)::integer as n
    from sw group by sw.user_id, sw.currency
    having sum(sw.net) > 0
  ),
  scored as (
    select 'hit_rate'::public.leaderboard_metric as metric, t.user_id, t.hits::numeric / t.n as value, t.n as sample,
           rank() over (order by t.hits::numeric / t.n desc, t.n desc) as rnk
    from totals t where t.n >= v_min
    union all
    select 'best_streak', r.user_id, max(r.len)::numeric, t.n,
           rank() over (order by max(r.len) desc)
    from runs r join totals t on t.user_id = r.user_id
    group by r.user_id, t.n
    union all
    select case pr.currency when 'SP' then 'sp_profit'::public.leaderboard_metric else 'ssp_profit' end,
           pr.user_id, pr.total, pr.n,
           rank() over (partition by pr.currency order by pr.total desc)
    from profit pr
  )
  select p_school_id, p_period, p_day, sc.metric, sc.user_id, sc.rnk::integer, sc.value, sc.sample, now()
  from scored sc;

  delete from private.leaderboard_runs r
  where r.school_id = p_school_id and r.period = p_period and r.period_start is not distinct from p_day;
  insert into private.leaderboard_runs (school_id, period, period_start, computed_at)
  values (p_school_id, p_period, p_day, now());
end;
$$;

-- Zamanlanmış iş: her okul için bu hafta ve tüm zamanlar; geçen hafta, bittikten sonra bir kez hesaplanana dek.
create function private.refresh_leaderboards() returns void
language plpgsql set search_path = '' as $$
declare
  v_school uuid;
  v_cur record;
  v_prev record;
begin
  -- Aynı anda iki hesaplama birbirinin satırlarını silmesin.
  perform pg_advisory_xact_lock(hashtext('kampusbet_liderlik'));
  select * into v_cur from private.week_bounds(0);
  select * into v_prev from private.week_bounds(1);
  for v_school in select c.id from public.clusters c where c.type = 'school' order by c.id loop
    perform private.store_leaderboard(v_school, 'week', v_cur.o_day, v_cur.o_start, v_cur.o_end);
    perform private.store_leaderboard(v_school, 'all_time', null, '-infinity', 'infinity');
    if not exists (
      select 1 from private.leaderboard_runs r
      where r.school_id = v_school and r.period = 'week' and r.period_start = v_prev.o_day
        and r.computed_at >= v_prev.o_end
    ) then
      perform private.store_leaderboard(v_school, 'week', v_prev.o_day, v_prev.o_start, v_prev.o_end);
    end if;
  end loop;
end;
$$;

revoke execute on function
  private.week_bounds(integer),
  private.settled_wagers(uuid, uuid, timestamptz, timestamptz),
  private.store_leaderboard(uuid, public.leaderboard_period, date, timestamptz, timestamptz),
  private.refresh_leaderboards()
from public;

-- ---------------------------------------------------------------------------
-- İstemci
-- ---------------------------------------------------------------------------

-- Sıralama: ilk p_limit kişi + (listede yoksa) çağıranın kendi satırı; kuşanılmış kozmetiklerle.
-- p_school_id null = kendi okulu; başka okul için `analitik_gor` (ya da süperadmin) gerekir.
-- p_weeks_ago yalnızca haftalıkta: 0 bu hafta, 1 geçen hafta...
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
  period_start date, computed_at timestamptz
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
           c.title, c.title_icon, c.badge, c.badge_name, c.frame_color, c.name_color, v_day, v_computed
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

-- Kişinin kendi istatistikleri (tüm zamanlar, istek anında) ve bu haftaki sıraları (son hesaplamadan).
create function public.my_stats()
returns table (
  predictions integer, correct integer, sp_profit bigint, ssp_profit bigint,
  current_streak integer, best_streak integer, duels_played integer, duels_won integer, open_wagers integer,
  week_rank_hit_rate integer, week_rank_sp_profit integer, week_rank_best_streak integer
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
  v_school uuid;
  v_day date;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  v_school := private.school_of_user(v_uid);
  if v_school is null then
    raise exception 'Profil bulunamadı' using errcode = 'P0002';
  end if;
  select b.o_day into v_day from private.week_bounds(0) b;

  return query
    with sw as (
      select * from private.settled_wagers(null, v_uid, '-infinity', 'infinity')
    ),
    preds as (
      select sw.correct,
             row_number() over (order by sw.settled_at, sw.bet_id) as rn,
             row_number() over (order by sw.settled_at, sw.bet_id)
               - row_number() over (partition by sw.correct order by sw.settled_at, sw.bet_id) as grp
      from sw where sw.is_prediction
    ),
    week_rank as (
      select l.metric, l.rank from public.leaderboard_snapshots l
      where l.school_id = v_school and l.period = 'week' and l.period_start = v_day and l.user_id = v_uid
    )
    select
      (select count(*) from preds)::integer,
      (select count(*) from preds where preds.correct)::integer,
      coalesce((select sum(sw.net) from sw where sw.currency = 'SP'), 0)::bigint,
      coalesce((select sum(sw.net) from sw where sw.currency = 'SSP'), 0)::bigint,
      (select count(*) from preds
       where preds.correct and preds.rn > coalesce((select max(q.rn) from preds q where not q.correct), 0))::integer,
      coalesce((select max(x.len) from (select count(*) as len from preds where preds.correct group by preds.grp) x), 0)::integer,
      (select count(*) from public.trivia_duel_plays d where d.player_id = v_uid and d.submitted_at is not null)::integer,
      (select count(*) from sw where not sw.is_prediction and sw.net > 0)::integer,
      (select count(*) from public.wagers w join public.bets b on b.id = w.bet_id
       where w.user_id = v_uid and b.status in ('open', 'locked', 'settling'))::integer,
      (select wr.rank from week_rank wr where wr.metric = 'hit_rate'),
      (select wr.rank from week_rank wr where wr.metric = 'sp_profit'),
      (select wr.rank from week_rank wr where wr.metric = 'best_streak');
end;
$$;

-- Okul özeti (admin paneli): `analitik_gor` ya da süperadmin. Hafta = bu hafta (pazartesiden beri).
create function public.school_stats(p_school_id uuid)
returns table (
  members integer, verified_members integer, active_this_week integer, wagers_this_week integer,
  sp_staked_this_week bigint, ssp_staked_this_week bigint, open_bets integer, open_disputes integer,
  quest_claims_this_week integer, market_purchases_this_week integer, week_start date
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
  v_week record;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  if not exists (select 1 from public.clusters c where c.id = p_school_id and c.type = 'school') then
    raise exception 'Okul bulunamadı' using errcode = 'P0002';
  end if;
  if not private.has_permission(p_school_id, 'analitik_gor') then
    raise exception 'Bu işlem için yetkin yok' using errcode = '42501';
  end if;
  select * into v_week from private.week_bounds(0);

  return query
    with mem as (
      select p.id from public.profiles p where p.school_id = p_school_id
    ),
    week_wagers as (
      select w.user_id, w.amount, w.currency from public.wagers w
      where w.user_id in (select m.id from mem m)
        and w.created_at >= v_week.o_start and w.created_at < v_week.o_end
    ),
    school_bets as (
      select b.id, b.status from public.bets b
      join public.clusters c on c.id = b.cluster_id
      where c.school_id = p_school_id
    )
    select
      (select count(*) from mem)::integer,
      (select count(*) from public.profile_private pp
       where pp.user_id in (select m.id from mem m) and pp.student_email_verified_at is not null)::integer,
      (select count(distinct ww.user_id) from week_wagers ww)::integer,
      (select count(*) from week_wagers)::integer,
      coalesce((select sum(ww.amount) from week_wagers ww where ww.currency = 'SP'), 0)::bigint,
      coalesce((select sum(ww.amount) from week_wagers ww where ww.currency = 'SSP'), 0)::bigint,
      (select count(*) from school_bets sb where sb.status in ('open', 'locked', 'settling'))::integer,
      (select count(*) from public.bet_disputes d
       where d.status = 'open' and d.bet_id in (select sb.id from school_bets sb))::integer,
      (select count(*) from public.quest_claims q
       where q.user_id in (select m.id from mem m)
         and q.claimed_at >= v_week.o_start and q.claimed_at < v_week.o_end)::integer,
      (select count(*) from public.user_inventory i
       where i.user_id in (select m.id from mem m)
         and i.acquired_at >= v_week.o_start and i.acquired_at < v_week.o_end)::integer,
      v_week.o_day;
end;
$$;

revoke execute on function
  public.get_leaderboard(public.leaderboard_metric, public.leaderboard_period, integer, uuid, integer),
  public.my_stats(),
  public.school_stats(uuid)
from public, anon;
grant execute on function
  public.get_leaderboard(public.leaderboard_metric, public.leaderboard_period, integer, uuid, integer),
  public.my_stats(),
  public.school_stats(uuid)
to authenticated;

-- ---------------------------------------------------------------------------
-- Zamanlanmış iş: 10 dakikada bir; ilk hesaplama hemen
-- ---------------------------------------------------------------------------

select cron.schedule('kampusbet_liderlik', '*/10 * * * *', 'select private.refresh_leaderboards()');
select private.refresh_leaderboards();
