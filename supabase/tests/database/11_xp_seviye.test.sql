-- XP ve seviye testleri: seviye eğrisi, günlük giriş / görev / doğru tahmin XP'si, günlük sınır,
-- tekrar engeli, my_progress, xp_events görünürlüğü, seviyeli market ürünü, liderlikte seviye.
-- Tek transaction içinde çalışır ve sonunda geri alınır.
--
-- A okulu: Ali, Veli, Can (öğrenci), Mod (yetkili: resmi_bahis_ac / _kapat, gorev_yonet, market_yonet),
-- Süper (süperadmin). Profilsiz: girişi var, profili yok.
-- Ali'nin XP'si: giriş 10 + görev 40 + doğru tahmin 4 × 15 (beşincisi günlük sınırda) = 110 → 2. seviye.

begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
-- Yeni fonksiyonlar varsayılan olarak kimseye açık değil (Adım 11); bu testin pg_temp yardımcıları
-- kullanıcı rolüyle de çağrılır. Transaction sonunda geri alınır.
alter default privileges for role postgres grant execute on functions to public;

select plan(37);

-- ---------------------------------------------------------------------------
-- Hazırlık
-- ---------------------------------------------------------------------------

update public.economy_settings
set signup_bonus_sp = 1000, xp_daily_login = 10, xp_correct_pick = 15, xp_daily_pick_cap = 60, xp_level_step = 100;

insert into public.clusters (id, name, type) values
  ('a0000000-0000-4000-8000-000000000001', 'Test Üniversitesi A', 'school');

create function pg_temp.uid(p_n integer) returns uuid language sql immutable as
  $$ select ('c0000000-0000-4000-8000-' || lpad(p_n::text, 12, '0'))::uuid $$;

insert into auth.users (id, email, aud, role)
select pg_temp.uid(n), pg_temp.uid(n)::text || '@test.local', 'authenticated', 'authenticated'
from generate_series(1, 6) n;

do $$
declare r record;
begin
  for r in select * from (values (1, 'Ali'), (2, 'Veli'), (3, 'Can'), (4, 'Mod'), (5, 'Süper')) as v(n, ad) loop
    perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.uid(r.n), 'role', 'authenticated')::text, true);
    perform public.create_profile(r.ad, 'Test', 'a0000000-0000-4000-8000-000000000001');
  end loop;
end $$;

update public.profile_private
set student_email = user_id::text || '@ogr.test.edu.tr', student_email_verified_at = now()
where user_id in (select pg_temp.uid(n) from generate_series(1, 5) n);

update public.profiles set role = 'yetkili' where id = pg_temp.uid(4);
update public.profiles set role = 'superadmin' where id = pg_temp.uid(5);
insert into public.permissions (user_id, cluster_id, permission_key, granted_by)
select pg_temp.uid(4), 'a0000000-0000-4000-8000-000000000001', k::public.permission_key, pg_temp.uid(5)
from unnest(array['resmi_bahis_ac', 'resmi_bahis_kapat', 'gorev_yonet', 'market_yonet']) k;

create temp table t (k text primary key, id uuid not null) on commit drop;
grant select, insert on t to authenticated;

create function pg_temp.id(p_k text) returns uuid language sql stable as $$ select id from t where k = p_k $$;
create function pg_temp.opt(p_k text, p_label text) returns uuid language sql stable as
  $$ select o.id from public.bet_options o where o.bet_id = (select id from t where k = p_k) and o.label = p_label $$;
create function pg_temp.xp(p_n integer) returns text language sql stable as
  $$ select row(p.xp, p.level)::text from public.profiles p where p.id = pg_temp.uid(p_n) $$;

-- Günün tahmini açar (Mod), 10'ar SP yatırır; kazanan verilirse sonuçlandırır.
create function pg_temp.tahmin(p_k text, p_yes uuid[], p_no uuid[], p_winner text)
returns void language plpgsql as $$
declare
  v_bet uuid;
  v_u uuid;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.uid(4), 'role', 'authenticated')::text, true);
  v_bet := public.create_daily_prediction('a0000000-0000-4000-8000-000000000001', 'Soru ' || p_k || '?', now() + interval '1 hour');
  insert into t values (p_k, v_bet);
  foreach v_u in array p_yes loop perform private.stake_wager(v_bet, pg_temp.opt(p_k, 'Evet'), v_u, 10); end loop;
  foreach v_u in array p_no loop perform private.stake_wager(v_bet, pg_temp.opt(p_k, 'Hayır'), v_u, 10); end loop;
  if p_winner is not null then
    perform private.lock_bet(v_bet);
    perform private.settle_bet(v_bet, pg_temp.opt(p_k, p_winner), pg_temp.uid(4));
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Seviye eğrisi
-- ---------------------------------------------------------------------------

select is(
  (select array_agg(private.level_for_xp(x) order by x) from unnest(array[0, 99, 100, 299, 300, 600, 999, 1000, 4500]) x),
  array[1, 1, 2, 2, 3, 4, 4, 5, 10],
  'seviye: 100 → 2, 300 → 3, 600 → 4, 1000 → 5, 4500 → 10'
);
select is(
  (select array_agg(private.xp_for_level(l) order by l) from generate_series(1, 5) l),
  array[0, 100, 300, 600, 1000],
  'seviyenin gerektirdiği toplam XP'
);

-- ---------------------------------------------------------------------------
-- Günlük giriş
-- ---------------------------------------------------------------------------

do $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.uid(1), 'role', 'authenticated')::text, true);
  perform public.claim_daily_login();
  perform public.claim_daily_login();
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.uid(2), 'role', 'authenticated')::text, true);
  perform public.claim_daily_login();
end $$;

select is(pg_temp.xp(1), '(10,1)', 'günlük giriş 10 XP verir');
select is(
  (select count(*)::int from public.xp_events e where e.user_id = pg_temp.uid(1) and e.reason = 'daily_login'),
  1, 'aynı gün ikinci giriş XP vermez'
);
select is(
  (select e.ledger_entry_id from public.xp_events e where e.user_id = pg_temp.uid(1) and e.reason = 'daily_login'),
  (select l.id from public.ledger_entries l where l.user_id = pg_temp.uid(1) and l.reason = 'daily_login'),
  'giriş XP''si ledger kaydına bağlı'
);

-- ---------------------------------------------------------------------------
-- Görevler
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000004","role":"authenticated"}';

select lives_ok(
  $$insert into t values ('q40', public.save_quest(null, 'a0000000-0000-4000-8000-000000000001', 'XP görevi', null,
    'daily', 'wager', 1, 'SP', 10, null, null, true, 40))$$,
  'gorev_yonet görevine XP verebilir'
);
select is((select q.reward_xp from public.quests q where q.id = pg_temp.id('q40')), 40, 'görevin XP''si kaydedildi');
select throws_ok(
  $$select public.save_quest(null, 'a0000000-0000-4000-8000-000000000001', 'Çok XP', null,
    'daily', 'wager', 1, 'SP', 10, null, null, true, 2000)$$,
  '23514', null, 'görev XP''si 1000''i aşamaz'
);
insert into t values ('q0', public.save_quest(null, 'a0000000-0000-4000-8000-000000000001', 'XP''siz görev', null,
  'daily', 'wager', 1, 'SP', 5));

set local role postgres;
do $$ begin perform pg_temp.tahmin('d1', array[pg_temp.uid(1)], array[pg_temp.uid(2)], null); end $$;

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';

select is(
  (select row(q.reward_xp, q.progress)::text from public.my_quests() q where q.quest_id = pg_temp.id('q40')),
  '(40,1)', 'my_quests görevin XP''sini döner'
);
select lives_ok($$select public.claim_quest_reward(pg_temp.id('q40'))$$, 'görev ödülü alınır');
select lives_ok($$select public.claim_quest_reward(pg_temp.id('q0'))$$, 'XP''siz görevin ödülü alınır');

set local role postgres;
select is(pg_temp.xp(1), '(50,1)', 'görev ödülü görevin XP''sini verir, XP''siz görev vermez');
select is(
  (select array_agg(e.amount order by e.id) from public.xp_events e where e.user_id = pg_temp.uid(1) and e.reason = 'quest'),
  array[40], 'görev XP olayı tek'
);

-- ---------------------------------------------------------------------------
-- Doğru tahmin, iptal, günlük sınır
-- ---------------------------------------------------------------------------

do $$
declare
  ali uuid := pg_temp.uid(1);
  can uuid := pg_temp.uid(3);
begin
  perform private.lock_bet(pg_temp.id('d1'));
  perform private.settle_bet(pg_temp.id('d1'), pg_temp.opt('d1', 'Evet'), pg_temp.uid(4));
  perform pg_temp.tahmin('iptal', array[ali], array[can], null);
  perform private.cancel_bet(pg_temp.id('iptal'), 'Test iptali', pg_temp.uid(4));
end $$;

select is(pg_temp.xp(1), '(65,1)', 'doğru tahmin 15 XP verir');
select is(pg_temp.xp(2), '(10,1)', 'yanlış tahmin XP vermez');
select is(
  (select count(*)::int from public.xp_events e join public.wagers w on w.id = e.wager_id where w.bet_id = pg_temp.id('iptal')),
  0, 'iptal edilen bahis XP vermez'
);

do $$
declare
  ali uuid := pg_temp.uid(1);
  can uuid := pg_temp.uid(3);
begin
  perform pg_temp.tahmin('d2', array[ali], array[can], 'Evet');
  perform pg_temp.tahmin('d3', array[ali], array[can], 'Evet');
  perform pg_temp.tahmin('d4', array[ali], array[can], 'Evet');
  perform pg_temp.tahmin('d5', array[ali], array[can], 'Evet');
end $$;

select is(
  (select sum(e.amount)::int from public.xp_events e where e.user_id = pg_temp.uid(1) and e.reason = 'correct_pick'),
  60, 'doğru tahmin XP''si günde en fazla 60'
);
select is(
  (select count(*)::int from public.xp_events e join public.wagers w on w.id = e.wager_id where w.bet_id = pg_temp.id('d5')),
  0, 'sınır dolunca doğru tahmin XP vermez'
);
select is(pg_temp.xp(1), '(110,2)', '100 XP''yi geçen 2. seviyeye çıkar');
select is(
  (select count(*)::int from public.profiles p
   where p.id in (select pg_temp.uid(n) from generate_series(1, 5) n)
     and p.xp <> coalesce((select sum(e.amount) from public.xp_events e where e.user_id = p.id), 0)),
  0, 'profildeki XP olayların toplamına eşit'
);

-- Aynı kaynak iki kez XP vermez; kaynaksız olay kısıta takılır.
select is(
  private.award_xp(pg_temp.uid(1), 'daily_login', 10,
    (select l.id from public.ledger_entries l where l.user_id = pg_temp.uid(1) and l.reason = 'daily_login'), null),
  0, 'aynı ledger kaydı ikinci kez XP vermez'
);
select throws_ok(
  $$select private.award_xp('c0000000-0000-4000-8000-000000000001', 'quest', 10, null, null)$$,
  '23514', null, 'kaynağı olmayan XP olayı yazılamaz'
);

-- ---------------------------------------------------------------------------
-- my_progress ve görünürlük
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';

select is(
  (select row(p.xp, p.level, p.level_xp, p.next_level_xp, p.pick_xp_today)::text from public.my_progress() p),
  '(110,2,100,300,60)', 'my_progress: XP, seviye, seviye aralığı, bugünkü tahmin XP''si'
);
select is((select count(*)::int from public.xp_events), 6, 'kişi kendi XP olaylarını görür');
select is(
  (select count(*)::int from public.xp_events e where e.user_id = 'c0000000-0000-4000-8000-000000000002'),
  0, 'başkasının XP olaylarını göremez'
);
select throws_ok(
  $$insert into public.xp_events (user_id, reason, amount, ledger_entry_id, xp_after)
    values ('c0000000-0000-4000-8000-000000000001', 'daily_login', 1000, 1, 1000)$$,
  '42501', null, 'istemci XP olayı ekleyemez'
);
select throws_ok(
  $$select private.award_xp('c0000000-0000-4000-8000-000000000001', 'daily_login', 1000, 1, null)$$,
  '42501', null, 'istemci award_xp çağıramaz'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000005","role":"authenticated"}';
select is(
  (select count(*)::int from public.xp_events e where e.user_id = 'c0000000-0000-4000-8000-000000000002'),
  1, 'süperadmin herkesin XP olaylarını görür'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000006","role":"authenticated"}';
select throws_ok($$select * from public.my_progress()$$, 'P0002', null, 'profili olmayan my_progress alamaz');

set local role anon;
select throws_ok($$select * from public.my_progress()$$, '42501', null, 'anonim my_progress çağıramaz');

set local role postgres;
select throws_ok(
  $$update public.xp_events set amount = 1000 where user_id = 'c0000000-0000-4000-8000-000000000001'$$,
  '55000', null, 'XP olayları değiştirilemez'
);

-- ---------------------------------------------------------------------------
-- Market: seviyeyle açılan ürün
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000004","role":"authenticated"}';

select throws_ok(
  $$select public.save_market_item(null, 'a0000000-0000-4000-8000-000000000001', 'Seviyesiz', null, 'title', 10, 'SP',
    null, null, null, null, true, 0)$$,
  '23514', null, 'ürün seviyesi en az 1'
);
insert into t values ('lv2', public.save_market_item(null, 'a0000000-0000-4000-8000-000000000001', 'İkinci seviye unvanı',
  null, 'title', 50, 'SP', '⭐', null, null, null, true, 2));

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000002","role":"authenticated"}';
select throws_ok($$select public.purchase_market_item(pg_temp.id('lv2'))$$, 'KB023', null,
  'seviyesi yetmeyen ürünü alamaz');

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';
select lives_ok($$select public.purchase_market_item(pg_temp.id('lv2'))$$, 'seviyesi yeten ürünü alır');

-- ---------------------------------------------------------------------------
-- Liderlikte seviye, ayar kısıtı, bütünlük
-- ---------------------------------------------------------------------------

set local role postgres;
do $$ begin perform private.refresh_leaderboards(); end $$;

set local role authenticated;
select is(
  (select l.level from public.get_leaderboard('sp_profit', 'all_time') l where l.is_me),
  2, 'liderlik satırı seviyeyi döner'
);

set local role postgres;
select throws_ok($$update public.economy_settings set xp_daily_pick_cap = -1$$, '23514', null,
  'XP ayarları sınır dışına çıkamaz');
select is((select count(*)::int from private.balance_mismatches()), 0, 'bakiye önbelleği ledger ile tutarlı');

select * from finish();
rollback;
