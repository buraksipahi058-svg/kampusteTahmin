-- Adım 10 testleri: liderlik (haftalık / tüm zamanlar snapshot), kişisel istatistik, okul özeti.
-- Tek transaction içinde çalışır ve sonunda geri alınır.
--
-- A okulu: Ali, Veli, Can, Deniz, Ece (öğrenci), Acan (yetkili: resmi_bahis_ac / _kapat),
-- Analitik (yetkili: A'da analitik_gor). B okulu: Zeynep (öğrenci), Bana (yetkili: B'de resmi_bahis_ac,
-- A'da analitik_gor). Profilsiz: girişi var, profili yok.
--
-- Bu haftaki günün tahminleri (10'ar SP; E = Evet, H = Hayır, kazanan sonda):
--   d1 E[Ali, Veli]  H[Can, Deniz]  → E      d2 E[Ali, Deniz] H[Veli, Can]   → E
--   d3 E[Ali, Veli]  H[Can, Deniz]  → H      d4 E[Ali, Veli]  H[Can, Ece]    → E
--   d5 E[Ali]                       → E      d6 iptal, d7 açık (sayılmaz)
--   Düello: Veli (20) Can'ı (20) yener — isabete / seriye girmez, net SP'ye girer.
-- Geçen hafta: Ali'nin resmi bahsi (10 SSP, oran 2,00) kazandı.

begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
-- Yeni fonksiyonlar varsayılan olarak kimseye açık değil (Adım 11); bu testin pg_temp yardımcıları
-- kullanıcı rolüyle de çağrılır. Transaction sonunda geri alınır.
alter default privileges for role postgres grant execute on functions to public;

select plan(42);

-- ---------------------------------------------------------------------------
-- Hazırlık
-- ---------------------------------------------------------------------------

update public.economy_settings
set signup_bonus_sp = 1000, leaderboard_min_predictions_week = 2, leaderboard_min_predictions_all = 3;

insert into public.clusters (id, name, type) values
  ('a0000000-0000-4000-8000-000000000001', 'Test Üniversitesi A', 'school'),
  ('b0000000-0000-4000-8000-000000000001', 'Test Üniversitesi B', 'school');

create function pg_temp.uid(p_n integer) returns uuid language sql immutable as
  $$ select ('c0000000-0000-4000-8000-' || lpad(p_n::text, 12, '0'))::uuid $$;

insert into auth.users (id, email, aud, role)
select pg_temp.uid(n), pg_temp.uid(n)::text || '@test.local', 'authenticated', 'authenticated'
from generate_series(1, 10) n;

do $$
declare r record;
begin
  for r in select * from (values
    (1, 'Ali', 'a0000000-0000-4000-8000-000000000001'::uuid),
    (2, 'Veli', 'a0000000-0000-4000-8000-000000000001'),
    (3, 'Can', 'a0000000-0000-4000-8000-000000000001'),
    (4, 'Deniz', 'a0000000-0000-4000-8000-000000000001'),
    (5, 'Ece', 'a0000000-0000-4000-8000-000000000001'),
    (6, 'Acan', 'a0000000-0000-4000-8000-000000000001'),
    (7, 'Analitik', 'a0000000-0000-4000-8000-000000000001'),
    (8, 'Zeynep', 'b0000000-0000-4000-8000-000000000001'),
    (9, 'Bana', 'b0000000-0000-4000-8000-000000000001')
  ) as v(n, ad, okul) loop
    perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.uid(r.n), 'role', 'authenticated')::text, true);
    perform public.create_profile(r.ad, 'Test', r.okul);
  end loop;
end $$;

update public.profile_private
set student_email = user_id::text || '@ogr.test.edu.tr', student_email_verified_at = now()
where user_id::text like 'c0000000-0000-4000-8000-0000000000__';

update public.profiles set role = 'yetkili' where id in (pg_temp.uid(6), pg_temp.uid(7), pg_temp.uid(9));
-- Verenin kim olduğu bu testte önemsiz (granted_by zorunlu).
insert into public.permissions (user_id, cluster_id, permission_key, granted_by) values
  (pg_temp.uid(6), 'a0000000-0000-4000-8000-000000000001', 'resmi_bahis_ac', pg_temp.uid(9)),
  (pg_temp.uid(6), 'a0000000-0000-4000-8000-000000000001', 'resmi_bahis_kapat', pg_temp.uid(9)),
  (pg_temp.uid(7), 'a0000000-0000-4000-8000-000000000001', 'analitik_gor', pg_temp.uid(9)),
  (pg_temp.uid(9), 'b0000000-0000-4000-8000-000000000001', 'resmi_bahis_ac', pg_temp.uid(6)),
  (pg_temp.uid(9), 'a0000000-0000-4000-8000-000000000001', 'analitik_gor', pg_temp.uid(6));

create temp table t (k text primary key, id uuid not null) on commit drop;
create temp table wk on commit drop as
select c.o_day as cur_day, c.o_start as cur, p.o_day as prev_day, p.o_start as prev
from private.week_bounds(0) c, private.week_bounds(1) p;
grant select on t, wk to authenticated;

create function pg_temp.bet(p_k text) returns uuid language sql stable as $$ select id from t where k = p_k $$;
create function pg_temp.opt(p_k text, p_label text) returns uuid language sql stable as
  $$ select o.id from public.bet_options o where o.bet_id = (select id from t where k = p_k) and o.label = p_label $$;

-- Günün tahmini açar, 10'ar SP yatırır; kazanan verilirse sonuçlandırıp sonuçlanma zamanını p_at yapar.
create function pg_temp.tahmin(p_k text, p_school uuid, p_creator uuid, p_yes uuid[], p_no uuid[], p_winner text, p_at timestamptz)
returns void language plpgsql as $$
declare
  v_bet uuid;
  v_u uuid;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_creator, 'role', 'authenticated')::text, true);
  v_bet := public.create_daily_prediction(p_school, 'Soru ' || p_k || '?', now() + interval '1 hour');
  insert into t values (p_k, v_bet);
  foreach v_u in array p_yes loop perform private.stake_wager(v_bet, pg_temp.opt(p_k, 'Evet'), v_u, 10); end loop;
  foreach v_u in array p_no loop perform private.stake_wager(v_bet, pg_temp.opt(p_k, 'Hayır'), v_u, 10); end loop;
  if p_winner is not null then
    perform private.lock_bet(v_bet);
    perform private.settle_bet(v_bet, pg_temp.opt(p_k, p_winner), p_creator);
    update public.bets set settled_at = p_at where id = v_bet;
  end if;
end $$;

-- Sıralama "Ad:sıra:değer" listesi (çağıranın gözünden).
create function pg_temp.board(p_metric text, p_period text, p_weeks integer default 0) returns text[] language sql as $$
  select array_agg(l.first_name || ':' || l.rank || ':' || round(l.value, 3) order by l.rank, l.first_name)
  from public.get_leaderboard(p_metric::public.leaderboard_metric, p_period::public.leaderboard_period, p_weeks) l
$$;

do $$
declare
  a uuid := 'a0000000-0000-4000-8000-000000000001';
  b uuid := 'b0000000-0000-4000-8000-000000000001';
  cur timestamptz := (select wk.cur from wk);
  prev timestamptz := (select wk.prev from wk);
  ali uuid := pg_temp.uid(1);
  veli uuid := pg_temp.uid(2);
  can uuid := pg_temp.uid(3);
  deniz uuid := pg_temp.uid(4);
  ece uuid := pg_temp.uid(5);
  acan uuid := pg_temp.uid(6);
  v_bet uuid;
begin
  perform pg_temp.tahmin('d1', a, acan, array[ali, veli], array[can, deniz], 'Evet', cur + interval '1 minute');
  perform pg_temp.tahmin('d2', a, acan, array[ali, deniz], array[veli, can], 'Evet', cur + interval '2 minutes');
  perform pg_temp.tahmin('d3', a, acan, array[ali, veli], array[can, deniz], 'Hayır', cur + interval '3 minutes');
  perform pg_temp.tahmin('d4', a, acan, array[ali, veli], array[can, ece], 'Evet', cur + interval '4 minutes');
  perform pg_temp.tahmin('d5', a, acan, array[ali], '{}', 'Evet', cur + interval '5 minutes');
  perform pg_temp.tahmin('d6', a, acan, array[ali], array[veli], null, null);
  perform private.cancel_bet(pg_temp.bet('d6'), 'Test iptali', acan);
  perform pg_temp.tahmin('d7', a, acan, array[ali], '{}', null, null);

  v_bet := private.create_bet(veli, a, 'sp_minigame', 'school', 'Deneme düellosu', null,
                              array['Meydan okuyan', 'Rakip'], now() + interval '1 hour');
  insert into t values ('duel', v_bet);
  perform private.stake_wager(v_bet, pg_temp.opt('duel', 'Meydan okuyan'), veli, 20);
  perform private.stake_wager(v_bet, pg_temp.opt('duel', 'Rakip'), can, 20);
  perform private.lock_bet(v_bet);
  perform private.settle_bet(v_bet, pg_temp.opt('duel', 'Meydan okuyan'), null);
  update public.bets set settled_at = cur + interval '6 minutes' where id = v_bet;

  perform private.post_ledger(ali, 'SSP', 100, 'admin_grant', null, null, acan, 'Test SSP');
  v_bet := private.create_bet(acan, a, 'ssp_official', 'school', 'Resmi deneme', null, array['Biz', 'Onlar'],
                              now() + interval '1 hour', null, 1, null, array[2.00, 1.50]);
  insert into t values ('resmi', v_bet);
  perform set_config('request.jwt.claims', json_build_object('sub', ali, 'role', 'authenticated')::text, true);
  perform public.place_wager(v_bet, pg_temp.opt('resmi', 'Biz'), 10);
  perform private.lock_bet(v_bet);
  perform private.settle_bet(v_bet, pg_temp.opt('resmi', 'Biz'), acan);
  update public.bets set settled_at = prev + interval '1 hour' where id = v_bet;

  perform pg_temp.tahmin('b1', b, pg_temp.uid(9), array[pg_temp.uid(8)], '{}', 'Evet', cur + interval '1 minute');

  -- Ali'nin kuşanılmış isim rengi (liderlikte görünür).
  insert into public.market_items (id, school_id, name, category, color, price, currency)
  values ('40000000-0000-4000-8000-00000000aaaa', a, 'Test moru', 'name_color', '#AA00FF', 100, 'SP');
  insert into public.user_inventory (user_id, item_id, category, equipped, price_paid, currency)
  values (ali, '40000000-0000-4000-8000-00000000aaaa', 'name_color', true, 100, 'SP');

  perform private.refresh_leaderboards();
end $$;

-- ---------------------------------------------------------------------------
-- Sıralama değerleri (Ali'nin gözünden)
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';

select is(pg_temp.board('hit_rate', 'week'), array['Ali:1:0.800', 'Deniz:2:0.667', 'Veli:3:0.500', 'Can:4:0.250'],
  'haftalık isabet: iptal / açık bahis ve düello sayılmaz, en az 2 tahmini olmayan (Ece) listede yok');
select is(pg_temp.board('best_streak', 'week'), array['Ali:1:2.000', 'Deniz:1:2.000', 'Can:3:1.000', 'Veli:3:1.000'],
  'haftalık en iyi seri: eşitler aynı sırayı paylaşır, doğru tahmini olmayan yok');
select is(pg_temp.board('sp_profit', 'week'), array['Ali:1:20.000', 'Veli:1:20.000', 'Deniz:3:10.000'],
  'haftalık net SP kazancı: düello kazancı dahil, kazancı sıfır ya da eksi olan yok');
select is((select count(*)::integer from public.get_leaderboard('ssp_profit', 'week')), 0,
  'geçen hafta sonuçlanan resmi bahis bu haftaya girmez');
select is(pg_temp.board('ssp_profit', 'week', 1), array['Ali:1:10.000'], 'geçen haftanın SSP kazancı');
select is((select count(*)::integer from public.get_leaderboard('hit_rate', 'week', 1)), 0,
  'geçen hafta tek tahmini olan isabet sıralamasına girmez');
select is(pg_temp.board('hit_rate', 'all_time'), array['Ali:1:0.833', 'Deniz:2:0.667', 'Veli:3:0.500', 'Can:4:0.250'],
  'tüm zamanlar isabet (en az 3 tahmin)');
select is(pg_temp.board('best_streak', 'all_time'), array['Ali:1:3.000', 'Deniz:2:2.000', 'Can:3:1.000', 'Veli:3:1.000'],
  'tüm zamanlar seri, haftalar arası sırayla (geçen haftanın resmi bahsi + d1 + d2)');
select is(pg_temp.board('ssp_profit', 'all_time'), array['Ali:1:10.000'], 'tüm zamanlar SSP kazancı');
select is((select l.sample from public.get_leaderboard('hit_rate', 'week') l where l.first_name = 'Veli'), 4,
  'düello tahmin sayısına girmez');
select is((select distinct l.period_start from public.get_leaderboard('hit_rate', 'week') l), (select cur_day from wk),
  'haftalık sıralama bu haftanın pazartesisini döner');
select ok((select bool_and(l.computed_at is not null) from public.get_leaderboard('hit_rate', 'all_time') l),
  'hesaplanma zamanı döner');

-- ---------------------------------------------------------------------------
-- Erişim
-- ---------------------------------------------------------------------------

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000003","role":"authenticated"}';
select is(
  (select array_agg(l.first_name || ':' || l.is_me order by l.rank) from public.get_leaderboard('hit_rate', 'week', 0, null, 1) l),
  array['Ali:false', 'Can:true'],
  'ilk N dışındaki kişi kendi satırını da alır'
);
select is((select l.name_color from public.get_leaderboard('sp_profit', 'week') l where l.first_name = 'Ali'), '#AA00FF',
  'kuşanılmış isim rengi sıralamada görünür');

set local role anon;
select throws_ok($$select * from public.get_leaderboard('hit_rate', 'week')$$, '42501', null,
  'oturumsuz istek sıralamayı göremez');

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000008","role":"authenticated"}';
select throws_ok($$select * from public.get_leaderboard('hit_rate', 'week', 0, 'a0000000-0000-4000-8000-000000000001')$$,
  'P0002', null, 'başka okulun sıralaması istenemez');
select is(pg_temp.board('best_streak', 'week'), array['Zeynep:1:1.000'], 'kişi kendi okulunun sıralamasını görür');

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000009","role":"authenticated"}';
select is((select count(*)::integer from public.get_leaderboard('hit_rate', 'week', 0, 'a0000000-0000-4000-8000-000000000001')), 4,
  'analitik_gor sahibi o okulun sıralamasını görür');

select throws_ok($$select * from public.get_leaderboard('hit_rate', 'week', 53)$$, '23514', null,
  'en fazla 52 hafta geriye bakılır');

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000010","role":"authenticated"}';
select throws_ok($$select * from public.get_leaderboard('hit_rate', 'week')$$, 'P0002', null,
  'profili olmayan sıralama isteyemez');

-- ---------------------------------------------------------------------------
-- Tablo görünürlüğü (RLS)
-- ---------------------------------------------------------------------------

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';
select is((select count(*)::integer from public.leaderboard_snapshots where school_id = 'b0000000-0000-4000-8000-000000000001'), 0,
  'öğrenci başka okulun satırlarını görmez');
select ok((select count(*) from public.leaderboard_snapshots where school_id = 'a0000000-0000-4000-8000-000000000001') > 0,
  'öğrenci kendi okulunun satırlarını görür');
select throws_ok(
  $$insert into public.leaderboard_snapshots (school_id, period, metric, user_id, rank, value, sample, computed_at)
    values ('a0000000-0000-4000-8000-000000000001', 'all_time', 'hit_rate', 'c0000000-0000-4000-8000-000000000001', 1, 1, 1, now())$$,
  '42501', null, 'istemci sıralamaya yazamaz'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000008","role":"authenticated"}';
select is((select count(*)::integer from public.leaderboard_snapshots where school_id = 'a0000000-0000-4000-8000-000000000001'), 0,
  'B öğrencisi A satırlarını görmez');

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000009","role":"authenticated"}';
select ok((select count(*) from public.leaderboard_snapshots where school_id = 'a0000000-0000-4000-8000-000000000001') > 0,
  'analitik_gor sahibi o okulun satırlarını görür');

-- ---------------------------------------------------------------------------
-- Kişisel istatistik
-- ---------------------------------------------------------------------------

set local role anon;
select throws_ok($$select * from public.my_stats()$$, '42501', null, 'oturumsuz istek istatistik göremez');

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000010","role":"authenticated"}';
select throws_ok($$select * from public.my_stats()$$, 'P0002', null, 'profili olmayanın istatistiği yok');

-- predictions, correct, sp_profit, ssp_profit, current_streak, best_streak, duels_played, duels_won,
-- open_wagers, bu haftaki sıra: isabet, SP kazancı, seri
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';
select is(
  (select array[predictions, correct, sp_profit, ssp_profit, current_streak, best_streak, duels_played, duels_won,
                open_wagers, week_rank_hit_rate, week_rank_sp_profit, week_rank_best_streak]::bigint[] from public.my_stats()),
  array[6, 5, 20, 10, 2, 3, 0, 0, 1, 1, 1, 1]::bigint[],
  'Ali: 6 tahminde 5 doğru, net +20 SP / +10 SSP, şu anki seri 2, en iyi 3, bir açık yatırım'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000002","role":"authenticated"}';
select is(
  (select array[predictions, correct, sp_profit, ssp_profit, current_streak, best_streak, duels_played, duels_won,
                open_wagers, week_rank_hit_rate, week_rank_sp_profit, week_rank_best_streak]::bigint[] from public.my_stats()),
  array[4, 2, 20, 0, 1, 1, 0, 1, 0, 3, 1, 3]::bigint[],
  'Veli: düello kazancı net SP''de ve düello sayısında, tahminlerde değil; iptal edilen bahis açık sayılmaz'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000005","role":"authenticated"}';
select is(
  (select array[predictions, correct, sp_profit, ssp_profit, current_streak, best_streak, duels_played, duels_won,
                open_wagers, week_rank_hit_rate, week_rank_sp_profit, week_rank_best_streak]::bigint[] from public.my_stats()),
  array[1, 0, -10, 0, 0, 0, 0, 0, 0, null, null, null]::bigint[],
  'Ece: sıralamaya girmeyenin sırası boş'
);

-- ---------------------------------------------------------------------------
-- Okul özeti
-- ---------------------------------------------------------------------------

set local role anon;
select throws_ok($$select * from public.school_stats('a0000000-0000-4000-8000-000000000001')$$, '42501', null,
  'oturumsuz istek okul özetini göremez');

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';
select throws_ok($$select * from public.school_stats('a0000000-0000-4000-8000-000000000001')$$, '42501', null,
  'öğrenci okul özetini göremez');

-- members, verified, active, wagers, SP, SSP, açık bahis, açık itiraz, görev ödülü, satın alma
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000007","role":"authenticated"}';
select is(
  (select array[members, verified_members, active_this_week, wagers_this_week, sp_staked_this_week, ssp_staked_this_week,
                open_bets, open_disputes, quest_claims_this_week, market_purchases_this_week]::bigint[]
   from public.school_stats('a0000000-0000-4000-8000-000000000001')),
  array[7, 7, 5, 23, 240, 10, 1, 0, 0, 1]::bigint[],
  'analitik_gor okul özetini görür'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000009","role":"authenticated"}';
select is((select members from public.school_stats('a0000000-0000-4000-8000-000000000001')), 7,
  'başka okulda analitik_gor yetkisi olan o okulun özetini görür');
select throws_ok($$select * from public.school_stats('b0000000-0000-4000-8000-000000000001')$$, '42501', null,
  'kendi okulunda analitik_gor yetkisi yoksa göremez');
select throws_ok($$select * from public.school_stats('c0000000-0000-4000-8000-000000000001')$$, 'P0002', null,
  'okul olmayan kimlik için özet yok');

-- ---------------------------------------------------------------------------
-- Hesaplama işi
-- ---------------------------------------------------------------------------

select throws_ok($$select private.refresh_leaderboards()$$, '42501', null, 'istemci hesaplamayı çalıştıramaz');

set local role postgres;

-- Biten hafta bitişinden sonra bir kez hesaplandı: satırları silinse de bir daha hesaplanmaz.
delete from public.leaderboard_snapshots
where school_id = 'a0000000-0000-4000-8000-000000000001' and period = 'week' and period_start = (select prev_day from wk);
do $$ begin perform private.refresh_leaderboards(); end $$;
select is(
  (select count(*)::integer from public.leaderboard_snapshots
   where school_id = 'a0000000-0000-4000-8000-000000000001' and period = 'week' and period_start = (select prev_day from wk)),
  0, 'biten haftanın sıralaması donmuştur'
);

-- Bu hafta her hesaplamada yenilenir: Ece'nin ilk doğru tahmini seri sıralamasına girer.
do $$
begin
  perform pg_temp.tahmin('d8', 'a0000000-0000-4000-8000-000000000001', pg_temp.uid(6), array[pg_temp.uid(5)], '{}',
                         'Evet', (select cur from wk) + interval '7 minutes');
  perform private.refresh_leaderboards();
end $$;
select is(
  (select array[rank, value]::numeric[] from public.leaderboard_snapshots
   where school_id = 'a0000000-0000-4000-8000-000000000001' and period = 'week' and metric = 'best_streak'
     and user_id = pg_temp.uid(5)),
  array[3, 1]::numeric[], 'bu haftanın sıralaması yeniden hesaplanır'
);

select is((select count(*)::integer from cron.job where jobname = 'kampusbet_liderlik'), 1, 'zamanlanmış iş kurulu');

select throws_ok(
  $$insert into public.leaderboard_snapshots (school_id, period, metric, user_id, rank, value, sample, computed_at)
    values ('a0000000-0000-4000-8000-000000000001', 'week', 'hit_rate', 'c0000000-0000-4000-8000-000000000001', 1, 1, 1, now())$$,
  '23514', null, 'haftalık satırın haftası olmalı'
);

select is((select count(*)::integer from private.balance_mismatches()), 0, 'bakiye önbelleği ledger ile tutarlı');

select * from finish();
rollback;
