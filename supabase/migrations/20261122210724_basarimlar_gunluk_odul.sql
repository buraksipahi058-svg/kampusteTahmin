-- Adım 16: başarımlar ve günlük ödül takvimi (KARARLAR "Başarımlar ve günlük ödül takvimi").
--
-- Başarım: bir ölçütte (doğru tahmin, seri, düello galibiyeti...) hedefe ulaşınca kazanılır; kişi ödülünü
-- (SP + XP) görevlerdeki gibi kendisi alır ve o an "açılır". Kademe: 1 bronz, 2 gümüş, 3 altın. Gizli
-- başarımın adı ve açıklaması kazanılana kadar görünmez. İlerleme her istekte kayıtlardan hesaplanır
-- (ayrı sayaç yok, ledger ve bahis kayıtları tek gerçek). Ödül yalnızca SP (SSP prestiji korunur).
-- "Çok bahis yap" baskısı yaratmamak için sayı başarımları düşük tutulur, ağırlık beceride (doğru, seri, ters köşe).
--
-- Günlük ödül takvimi: `claim_daily_login` aynı kalır; `daily_login_calendar()` serinin içinde bulunulan
-- 7 günlük dilimini (ödül, kilometre taşı bonusu, alındı mı, bugün mü) verir. Mobil açılışta otomatik almak
-- yerine takvimi gösterip "Ödülü al" düğmesiyle alır.

-- ---------------------------------------------------------------------------
-- Tablolar
-- ---------------------------------------------------------------------------

create type public.achievement_category as enum ('prediction', 'streak', 'duel', 'social', 'loyalty', 'progress', 'secret');

create table public.achievements (
  id uuid primary key default gen_random_uuid(),
  key text not null unique check (key ~ '^[a-z0-9_]{3,40}$'),
  category public.achievement_category not null,
  title text not null check (char_length(title) between 2 and 40 and title = btrim(title) and title !~ '[[:cntrl:]]'),
  description text not null check (char_length(description) between 3 and 200 and description = btrim(description)
                                   and description !~ '[[:cntrl:]]'),
  icon text not null check (char_length(icon) between 1 and 8),
  metric text not null check (metric in (
    'predictions', 'correct', 'best_streak', 'duels_played', 'duels_won', 'perfect_duels', 'social_created',
    'fair_referee', 'login_streak', 'sp_profit', 'level', 'items_owned', 'quests_claimed', 'verified',
    'official_wins', 'underdog_wins'
  )),
  target integer not null check (target between 1 and 100000),
  tier smallint not null default 1 check (tier between 1 and 3),
  reward_sp integer not null check (reward_sp between 1 and 1000),
  reward_xp integer not null default 0 check (reward_xp between 0 and 500),
  hidden boolean not null default false,
  sort integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

-- Kazanılan başarımlar (yalnızca eklenir): ödül alındığı an açılır, ödül tutarı o anki haliyle saklanır.
create table public.achievement_unlocks (
  user_id uuid not null references public.profiles (id) on delete restrict,
  achievement_id uuid not null references public.achievements (id) on delete restrict,
  reward_sp integer not null check (reward_sp > 0),
  reward_xp integer not null check (reward_xp >= 0),
  unlocked_at timestamptz not null default now(),
  primary key (user_id, achievement_id)
);
create index achievement_unlocks_achievement_idx on public.achievement_unlocks (achievement_id);

create trigger achievement_unlocks_append_only
  before update or delete on public.achievement_unlocks
  for each row execute function private.forbid_change();
create trigger achievement_unlocks_no_truncate
  before truncate on public.achievement_unlocks
  for each statement execute function private.forbid_change();

revoke all on public.achievements, public.achievement_unlocks from anon, authenticated;
grant select on public.achievements, public.achievement_unlocks to authenticated;
alter table public.achievements enable row level security;
alter table public.achievement_unlocks enable row level security;

create policy achievements_select on public.achievements
  for select to authenticated using (true);

-- Kendi başarımları; okul arkadaşlarının kazandıkları da (profilde gösterilir); süperadmin hepsi.
create policy achievement_unlocks_select on public.achievement_unlocks
  for select to authenticated
  using (
    user_id = (select auth.uid())
    or private.school_of_user(user_id) = (select private.current_school_id())
    or (select private.is_superadmin())
  );

-- ---------------------------------------------------------------------------
-- Ledger ve XP: başarım ödülü SP'dir, XP'si ledger kaydından tetiklenir (görev ödülüyle aynı düzen)
-- ---------------------------------------------------------------------------

alter table public.ledger_entries drop constraint ledger_sp_only_rewards;
alter table public.ledger_entries add constraint ledger_sp_only_rewards
  check (reason not in ('signup_bonus', 'daily_login', 'achievement_reward') or currency = 'SP');

alter table public.xp_events drop constraint xp_events_source;
alter table public.xp_events add constraint xp_events_source check (
  (reason in ('daily_login', 'quest', 'achievement')) = (ledger_entry_id is not null)
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
  end if;
  return null;
end;
$$;
revoke execute on function private.xp_on_ledger_entry() from public;

drop trigger ledger_entries_award_xp on public.ledger_entries;
create trigger ledger_entries_award_xp
  after insert on public.ledger_entries
  for each row when (new.reason in ('daily_login', 'quest_reward', 'achievement_reward'))
  execute function private.xp_on_ledger_entry();

-- ---------------------------------------------------------------------------
-- İlerleme ölçütleri (tüm zamanlar, istek anında)
-- ---------------------------------------------------------------------------

create function private.achievement_metrics(p_user_id uuid)
returns table (metric text, value bigint)
language sql stable set search_path = '' as $$
  with sw as (
    select * from private.settled_wagers(null, p_user_id, '-infinity', 'infinity')
  ),
  preds as (
    -- grp: art arda aynı sonuçtaki tahminler aynı değeri alır (my_stats ile aynı seri hesabı).
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
  -- Ters köşe: havuzlu bahiste kazanan tarafın havuzu toplamın %20'sinden azken o tarafı bilip kazanmak.
  union all select 'underdog_wins',
    (select count(*) from public.wagers w
     join public.bets b on b.id = w.bet_id
     join public.bet_options o on o.id = w.option_id
     where w.user_id = p_user_id and b.status = 'settled' and b.odds_mode = 'pool' and o.is_winner
       and o.pool_amount * 5 < b.pool_total and coalesce(w.payout, 0) > w.amount);
$$;
revoke execute on function private.achievement_metrics(uuid) from public;

-- ---------------------------------------------------------------------------
-- İstemci
-- ---------------------------------------------------------------------------

-- Başarımlar, kişinin ilerlemesi ve okulunda kazananların oranı (Steam'deki nadirlik gibi).
-- Gizli başarım kazanılana (ya da hedefe ulaşılana) kadar adı, açıklaması, simgesi ve ölçütü gizlenir.
create function public.my_achievements()
returns table (
  key text, category public.achievement_category, title text, description text, icon text, tier smallint,
  metric text, target integer, progress bigint, reward_sp integer, reward_xp integer, hidden boolean,
  unlocked_at timestamptz, claimable boolean, school_rate numeric
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
  v_school uuid;
  v_members integer;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  select p.school_id into v_school from public.profiles p where p.id = v_uid and p.deleted_at is null;
  if v_school is null then
    raise exception 'Profil bulunamadı' using errcode = 'P0002';
  end if;
  select count(*) into v_members from public.profiles p where p.school_id = v_school and p.deleted_at is null;

  return query
    with m as (
      select * from private.achievement_metrics(v_uid)
    ),
    rates as (
      select u.achievement_id, count(*) as n
      from public.achievement_unlocks u join public.profiles p on p.id = u.user_id
      where p.school_id = v_school and p.deleted_at is null
      group by u.achievement_id
    ),
    ach as (
      select a.*, u.unlocked_at as got_at, coalesce(m.value, 0) as val, coalesce(r.n, 0) as n,
             a.hidden and u.user_id is null and coalesce(m.value, 0) < a.target as masked
      from public.achievements a
      left join m on m.metric = a.metric
      left join public.achievement_unlocks u on u.achievement_id = a.id and u.user_id = v_uid
      left join rates r on r.achievement_id = a.id
      where a.active or u.user_id is not null
    )
    select x.key, x.category,
           case when x.masked then 'Gizli başarım' else x.title end,
           case when x.masked then 'Kazanınca ne olduğu açılır.' else x.description end,
           case when x.masked then '❓' else x.icon end,
           x.tier,
           case when x.masked then null else x.metric end,
           x.target, least(x.val, x.target), x.reward_sp, x.reward_xp, x.hidden,
           x.got_at, x.got_at is null and x.val >= x.target,
           round(x.n::numeric / greatest(v_members, 1), 3)
    from ach x
    order by x.sort, x.key;
end;
$$;

revoke execute on function public.my_achievements() from public, anon;
grant execute on function public.my_achievements() to authenticated;

-- Başarımın ödülünü al: hedefe ulaşıldıysa açılır, SP ledger'a yazılır, XP ledger tetikleyicisiyle gelir.
create function public.claim_achievement(p_key text)
returns table (reward_sp integer, reward_xp integer, balance bigint)
language plpgsql security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
  v_a public.achievements;
  v_progress bigint;
  v_rows integer;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  if not exists (select 1 from public.profiles p where p.id = v_uid and p.deleted_at is null) then
    raise exception 'Profil bulunamadı' using errcode = 'P0002';
  end if;
  select * into v_a from public.achievements a where a.key = p_key and a.active;
  if not found then
    raise exception 'Başarım bulunamadı' using errcode = 'P0002';
  end if;
  select m.value into v_progress from private.achievement_metrics(v_uid) m where m.metric = v_a.metric;
  if coalesce(v_progress, 0) < v_a.target then
    raise exception 'Bu başarım henüz kazanılmadı' using errcode = 'KB027';
  end if;

  -- Aynı anda gelen ikinci istek birincil anahtarda bekler, sonra hiçbir şey eklemez.
  insert into public.achievement_unlocks (user_id, achievement_id, reward_sp, reward_xp)
  values (v_uid, v_a.id, v_a.reward_sp, v_a.reward_xp)
  on conflict do nothing;
  get diagnostics v_rows = row_count;
  if v_rows = 0 then
    raise exception 'Bu başarımın ödülünü zaten aldın' using errcode = 'KB028';
  end if;

  reward_sp := v_a.reward_sp;
  reward_xp := v_a.reward_xp;
  balance := private.post_ledger(v_uid, 'SP', v_a.reward_sp, 'achievement_reward', 'achievement', v_a.id, v_uid, null);
  return next;
end;
$$;

revoke execute on function public.claim_achievement(text) from public, anon;
grant execute on function public.claim_achievement(text) to authenticated;

-- Günlük ödül takvimi: serinin içinde bulunulan 7 günlük dilim. Bugün alınmadıysa "bugün" = yarın sürecek seri
-- günü (dün alındıysa seri + 1, değilse 1). Tutar `claim_daily_login` ile aynı formül.
create function public.daily_login_calendar()
returns table (day integer, amount bigint, bonus bigint, claimed boolean, is_today boolean)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
  v_cfg public.economy_settings;
  v_today date;
  v_streak public.login_streaks;
  v_day integer;
  v_claimed boolean := false;
  v_start integer;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  if not exists (select 1 from public.profiles p where p.id = v_uid and p.deleted_at is null) then
    raise exception 'Profil bulunamadı' using errcode = 'P0002';
  end if;
  select * into v_cfg from public.economy_settings s where s.id;
  v_today := (now() at time zone v_cfg.day_timezone)::date;
  select * into v_streak from public.login_streaks ls where ls.user_id = v_uid;

  if v_streak.last_login_date = v_today then
    v_day := v_streak.current_streak;
    v_claimed := true;
  elsif v_streak.last_login_date = v_today - 1 then
    v_day := v_streak.current_streak + 1;
  else
    v_day := 1;
  end if;
  v_start := ((v_day - 1) / 7) * 7 + 1;

  return query
    select d, least(v_cfg.daily_base_sp + v_cfg.daily_step_sp * (d - 1), v_cfg.daily_max_sp)::bigint,
           coalesce((v_cfg.streak_milestones ->> d::text)::bigint, 0),
           d < v_day or (d = v_day and v_claimed),
           d = v_day
    from generate_series(v_start, v_start + 6) d
    order by d;
end;
$$;

revoke execute on function public.daily_login_calendar() from public, anon;
grant execute on function public.daily_login_calendar() to authenticated;

-- ---------------------------------------------------------------------------
-- Başarım kataloğu (taslak; rakamlar ekonomi ayarlarıyla birlikte gözden geçirilecek)
-- ---------------------------------------------------------------------------

insert into public.achievements (key, category, title, description, icon, metric, target, tier, reward_sp, reward_xp, hidden, sort) values
  ('kampuslu',       'progress',   'Kampüslü',          'Okul mailini doğrula.',                                              '🎓', 'verified',       1,   1,  20,  10, false, 10),
  ('ilk_tahmin',     'prediction', 'İlk Adım',          'İlk tahminin sonuçlansın.',                                          '🎯', 'predictions',    1,   1,  20,  10, false, 20),
  ('tahminci',       'prediction', 'Tahminci',          '10 tahminin sonuçlansın.',                                           '📈', 'predictions',   10,   1,  50,  20, false, 21),
  ('mudavim',        'prediction', 'Müdavim',           '50 tahminin sonuçlansın.',                                           '🗂️', 'predictions',   50,   2, 100,  40, false, 22),
  ('keskin_goz',     'prediction', 'Keskin Göz',        '10 tahmini doğru bil.',                                              '👁️', 'correct',       10,   1,  50,  20, false, 30),
  ('bilge',          'prediction', 'Bilge',             '50 tahmini doğru bil.',                                              '🦉', 'correct',       50,   2, 150,  60, false, 31),
  ('muneccim',       'prediction', 'Müneccim',          '150 tahmini doğru bil.',                                             '🔮', 'correct',      150,   3, 300, 120, false, 32),
  ('isiniyor',       'streak',     'Isınıyor',          'Art arda 3 tahmini doğru bil.',                                      '🔥', 'best_streak',    3,   1,  30,  15, false, 40),
  ('alev_aldi',      'streak',     'Alev Aldı',         'Art arda 5 tahmini doğru bil.',                                      '☄️', 'best_streak',    5,   2,  80,  40, false, 41),
  ('durdurulamaz',   'streak',     'Durdurulamaz',      'Art arda 10 tahmini doğru bil.',                                     '🌋', 'best_streak',   10,   3, 250, 100, false, 42),
  ('meydan_okuyan',  'duel',       'Meydan Okuyan',     'İlk trivia düellonu oyna.',                                          '⚔️', 'duels_played',   1,   1,  20,  10, false, 50),
  ('duellocu',       'duel',       'Düellocu',          '5 düello kazan.',                                                    '🤺', 'duels_won',      5,   2,  80,  30, false, 51),
  ('bilgi_kupu',     'duel',       'Bilgi Küpü',        '25 düello kazan.',                                                   '🏆', 'duels_won',     25,   3, 200,  80, false, 52),
  ('kusursuz',       'duel',       'Kusursuz',          'Bir düelloda bütün soruları doğru bil.',                             '💯', 'perfect_duels',  1,   2,  60,  30, false, 53),
  ('ortaya_atan',    'social',     'Ortaya Atan',       'Açtığın bir sosyal bahis sonuçlansın.',                              '💬', 'social_created', 1,   1,  30,  10, false, 60),
  ('adil_hakem',     'social',     'Adil Hakem',        'Hakemi olduğun 5 sosyal bahis, kararın değiştirilmeden sonuçlansın.', '⚖️', 'fair_referee',   5,   2, 100,  40, false, 61),
  ('turnuva_ruhu',   'prediction', 'Turnuva Ruhu',      'Bir resmi bahsi kazan.',                                             '🏟️', 'official_wins',  1,   1,  30,  10, false, 33),
  ('sadik',          'loyalty',    'Sadık',             '7 gün art arda giriş yap.',                                          '📅', 'login_streak',   7,   1,  50,  20, false, 70),
  ('vazgecilmez',    'loyalty',    'Vazgeçilmez',       '30 gün art arda giriş yap.',                                         '🗓️', 'login_streak',  30,   3, 250, 100, false, 71),
  ('gorev_adami',    'progress',   'Görev Adamı',       '10 görev ödülü al.',                                                 '📋', 'quests_claimed',10,   1,  50,  20, false, 80),
  ('koleksiyoncu',   'progress',   'Koleksiyoncu',      'Marketten 3 ürün edin.',                                             '🎒', 'items_owned',    3,   2,  60,  20, false, 81),
  ('yukselen',       'progress',   'Yükselen',          '5. seviyeye ulaş.',                                                  '⭐', 'level',          5,   2,  80,   0, false, 82),
  ('efsane',         'progress',   'Efsane',            '10. seviyeye ulaş.',                                                 '🌟', 'level',         10,   3, 200,   0, false, 83),
  ('karda',          'prediction', 'Kârda',             'Bahislerden toplam +500 SP net kazanç elde et.',                     '💰', 'sp_profit',    500,   2, 100,  40, false, 34),
  ('ters_kose',      'secret',     'Ters Köşe',         'Havuzun beşte birinden azının yatırıldığı tarafı bilerek kazan.',    '🃏', 'underdog_wins',  1,   2, 100,  50, true,  90);
