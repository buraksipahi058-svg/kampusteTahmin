-- Adım 9 testleri: görevler (yönetim, görünürlük, ilerleme, ödül) ve kozmetik market (yönetim, satın alma,
-- kuşanma, görünürlük). Tek transaction içinde çalışır ve sonunda geri alınır.
--
-- A okulu: Ali, Veli (öğrenci), Gorevci (gorev_yonet), Marketci (market_yonet), Acan (resmi_bahis_ac + kapat),
-- Su (süperadmin). B okulu: Zeynep (öğrenci), Bmod (B'de gorev_yonet + market_yonet). Herkes 1000 SP ile başlar.

begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
-- Yeni fonksiyonlar varsayılan olarak kimseye açık değil (Adım 11); bu testin pg_temp yardımcıları
-- kullanıcı rolüyle de çağrılır. Transaction sonunda geri alınır.
alter default privileges for role postgres grant execute on functions to public;

select plan(72);

-- ---------------------------------------------------------------------------
-- Hazırlık
-- ---------------------------------------------------------------------------

update public.economy_settings set signup_bonus_sp = 1000, day_timezone = 'Europe/Istanbul';
-- Buluttaki örnek görev ve ürünler kapatılır ki sayımlar yalnızca bu testinkiler olsun.
update public.quests set active = false;
update public.market_items set active = false;

insert into public.clusters (id, name, type) values
  ('a0000000-0000-4000-8000-000000000001', 'Test Üniversitesi A', 'school'),
  ('b0000000-0000-4000-8000-000000000001', 'Test Üniversitesi B', 'school');

insert into auth.users (id, email, aud, role)
select id, id::text || '@test.local', 'authenticated', 'authenticated'
from unnest(array[
  'c0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000002',
  'c0000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000004',
  'c0000000-0000-4000-8000-000000000005', 'c0000000-0000-4000-8000-000000000006',
  'c0000000-0000-4000-8000-000000000007', 'c0000000-0000-4000-8000-000000000008'
]::uuid[]) as id;

do $$
declare r record;
begin
  for r in select * from (values
    ('c0000000-0000-4000-8000-000000000001'::uuid, 'Ali', 'a0000000-0000-4000-8000-000000000001'::uuid),
    ('c0000000-0000-4000-8000-000000000002', 'Veli', 'a0000000-0000-4000-8000-000000000001'),
    ('c0000000-0000-4000-8000-000000000003', 'Gorevci', 'a0000000-0000-4000-8000-000000000001'),
    ('c0000000-0000-4000-8000-000000000004', 'Marketci', 'a0000000-0000-4000-8000-000000000001'),
    ('c0000000-0000-4000-8000-000000000005', 'Su', 'a0000000-0000-4000-8000-000000000001'),
    ('c0000000-0000-4000-8000-000000000006', 'Acan', 'a0000000-0000-4000-8000-000000000001'),
    ('c0000000-0000-4000-8000-000000000007', 'Zeynep', 'b0000000-0000-4000-8000-000000000001'),
    ('c0000000-0000-4000-8000-000000000008', 'Bmod', 'b0000000-0000-4000-8000-000000000001')
  ) as v(id, ad, okul) loop
    perform set_config('request.jwt.claims', json_build_object('sub', r.id, 'role', 'authenticated')::text, true);
    perform public.create_profile(r.ad, 'Test', r.okul);
  end loop;
end $$;

update public.profile_private
set student_email = user_id::text || '@ogr.test.edu.tr', student_email_verified_at = now()
where user_id::text like 'c0000000-0000-4000-8000-00000000000_';

update public.profiles set role = 'yetkili'
where id in ('c0000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000004',
             'c0000000-0000-4000-8000-000000000006', 'c0000000-0000-4000-8000-000000000008');
update public.profiles set role = 'superadmin' where id = 'c0000000-0000-4000-8000-000000000005';
insert into public.permissions (user_id, cluster_id, permission_key, granted_by) values
  ('c0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000001', 'gorev_yonet', 'c0000000-0000-4000-8000-000000000005'),
  ('c0000000-0000-4000-8000-000000000004', 'a0000000-0000-4000-8000-000000000001', 'market_yonet', 'c0000000-0000-4000-8000-000000000005'),
  ('c0000000-0000-4000-8000-000000000006', 'a0000000-0000-4000-8000-000000000001', 'resmi_bahis_ac', 'c0000000-0000-4000-8000-000000000005'),
  ('c0000000-0000-4000-8000-000000000006', 'a0000000-0000-4000-8000-000000000001', 'resmi_bahis_kapat', 'c0000000-0000-4000-8000-000000000005'),
  ('c0000000-0000-4000-8000-000000000008', 'b0000000-0000-4000-8000-000000000001', 'gorev_yonet', 'c0000000-0000-4000-8000-000000000005'),
  ('c0000000-0000-4000-8000-000000000008', 'b0000000-0000-4000-8000-000000000001', 'market_yonet', 'c0000000-0000-4000-8000-000000000005');

create temp table t (k text primary key, id uuid not null) on commit drop;
grant select, insert on t to authenticated;

create function pg_temp.id(p_k text) returns uuid language sql stable as $$ select id from t where k = p_k $$;
create function pg_temp.opt(p_k text, p_label text) returns uuid language sql stable as
  $$ select o.id from public.bet_options o where o.bet_id = (select id from t where k = p_k) and o.label = p_label $$;
create function pg_temp.sp(p_uid uuid) returns bigint language sql stable as
  $$ select sp_balance from public.balances where user_id = p_uid $$;
create function pg_temp.ssp(p_uid uuid) returns bigint language sql stable as
  $$ select ssp_balance from public.balances where user_id = p_uid $$;
create function pg_temp.quest(p_k text) returns text language sql stable as
  $$ select row(progress, claimed)::text from public.my_quests() where quest_id = (select id from t where k = p_k) $$;

-- ---------------------------------------------------------------------------
-- Görev yönetimi
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';
select throws_ok(
  $$select public.save_quest(null, 'a0000000-0000-4000-8000-000000000001', 'Öğrenci görevi', null, 'daily', 'wager', 1, 'SP', 10)$$,
  '42501', null, 'öğrenci görev ekleyemez'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000003","role":"authenticated"}';
select throws_ok(
  $$select public.save_quest(null, null, 'Genel görev', null, 'daily', 'wager', 1, 'SP', 10)$$,
  '42501', null, 'tüm okullara görevi yalnızca süperadmin ekler'
);
select throws_ok(
  $$select public.save_quest(null, 'a0000000-0000-4000-8000-000000000001', 'SSP görevi', null, 'daily', 'wager', 1, 'SSP', 10)$$,
  '42501', null, 'SSP ödüllü görevi yalnızca süperadmin ekler'
);
select throws_ok(
  $$select public.save_quest(null, 'b0000000-0000-4000-8000-000000000001', 'Başka okul', null, 'daily', 'wager', 1, 'SP', 10)$$,
  '42501', null, 'başka okulun görevini ekleyemez'
);
select throws_ok(
  $$select public.save_quest(null, 'a0000000-0000-4000-8000-000000000001', 'Sezonluk görev', null, 'seasonal', 'win', 1, 'SP', 10)$$,
  '23514', null, 'sezonluk görevin başlangıcı ve bitişi olmalı'
);
select throws_ok(
  $$select public.save_quest(null, 'a0000000-0000-4000-8000-000000000001', 'Sıfır hedef', null, 'daily', 'wager', 0, 'SP', 10)$$,
  '23514', null, 'hedef en az 1'
);
select lives_ok(
  $$insert into t values ('qw', public.save_quest(null, 'a0000000-0000-4000-8000-000000000001',
      '  İki bahse katıl  ', 'Resmi, sosyal ya da günün tahmini', 'daily', 'wager', 2, 'SP', 30))$$,
  'gorev_yonet izni olan okuluna günlük görev ekler'
);
select lives_ok(
  $$select public.save_quest(pg_temp.id('qw'), 'a0000000-0000-4000-8000-000000000001',
      'İki bahse katıl', 'Resmi, sosyal ya da günün tahmini', 'daily', 'wager', 2, 'SP', 40)$$,
  'görevini düzenler (ödül 40)'
);
insert into t values ('qi', public.save_quest(null, 'a0000000-0000-4000-8000-000000000001', 'Kapalı görev', null, 'daily', 'wager', 1, 'SP', 10, null, null, false));
insert into t values ('qp', public.save_quest(null, 'a0000000-0000-4000-8000-000000000001', 'Günün tahminini yap', null, 'daily', 'prediction', 1, 'SP', 20));
insert into t values ('qs', public.save_quest(null, 'a0000000-0000-4000-8000-000000000001', 'Sosyal bahis aç', null, 'weekly', 'social_bet', 1, 'SP', 50));
insert into t values ('qwin', public.save_quest(null, 'a0000000-0000-4000-8000-000000000001', 'Bir bahis kazan', null, 'weekly', 'win', 1, 'SP', 60));
select is(
  (select row(title, description, reward_amount, created_by)::text from public.quests where id = pg_temp.id('qw')),
  '("İki bahse katıl","Resmi, sosyal ya da günün tahmini",40,c0000000-0000-4000-8000-000000000003)',
  'başlık boşluklardan temizlenir, düzenleme kaydedilir'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000008","role":"authenticated"}';
select throws_ok(
  $$select public.save_quest(pg_temp.id('qw'), 'b0000000-0000-4000-8000-000000000001', 'Taşınan görev', null, 'daily', 'wager', 1, 'SP', 10)$$,
  '42501', null, 'başka okulun görevini düzenleyemez (kendi okuluna taşıyamaz)'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000005","role":"authenticated"}';
select lives_ok(
  $$insert into t values ('qd', public.save_quest(null, null, 'Bir düello oyna', null, 'weekly', 'duel', 1, 'SSP', 5))$$,
  'süperadmin tüm okullara SSP ödüllü görev ekler'
);

set local role postgres;
select is(
  (select count(*)::int from public.admin_audit_log where action = 'quest_save' and details ->> 'quest_id' = pg_temp.id('qw')::text),
  2, 'görev ekleme ve düzenleme denetim kaydına yazılır'
);

-- ---------------------------------------------------------------------------
-- Görev görünürlüğü
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';
select is((select count(*)::int from public.quests), 5, 'öğrenci okulunun ve genel aktif görevleri görür, kapalıyı görmez');
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000007","role":"authenticated"}';
select is((select count(*)::int from public.quests), 1, 'başka okulun öğrencisi yalnızca genel görevi görür');
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000003","role":"authenticated"}';
select is((select count(*)::int from public.quests where id = pg_temp.id('qi')), 1, 'görev yöneten kapalı görevi de görür');

-- ---------------------------------------------------------------------------
-- İlerleme ve ödül
-- ---------------------------------------------------------------------------

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';
select is(pg_temp.quest('qw'), '(0,f)', 'başta ilerleme 0, ödül alınmamış');
select is((select count(*)::int from public.my_quests()), 5, 'my_quests yalnızca açık görevleri döner');
select throws_ok($$select public.claim_quest_reward(pg_temp.id('qw'))$$, 'KB019', null, 'tamamlanmayan görevin ödülü alınamaz');

-- Günün tahmini (Acan), sosyal bahis (Veli), düello (doğrudan) hazırlanır.
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000006","role":"authenticated"}';
insert into t values ('p', public.create_daily_prediction('a0000000-0000-4000-8000-000000000001', 'Yarın yağmur yağar mı?', now() + interval '1 hour'));
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000002","role":"authenticated"}';
insert into t values ('s', public.create_social_bet('a0000000-0000-4000-8000-000000000001', 'Maç berabere biter mi?', null,
                                                    array['Evet', 'Hayır'], now() + interval '1 hour'));
select public.place_wager(pg_temp.id('p'), pg_temp.opt('p', 'Hayır'), 30);

set local role postgres;
insert into t values ('duel', private.create_bet(
  'c0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001', 'sp_minigame', 'school',
  'Deneme düellosu', null, array['Meydan okuyan', 'Rakip'], now() + interval '1 hour'));
select private.stake_wager(pg_temp.id('duel'), pg_temp.opt('duel', 'Meydan okuyan'), 'c0000000-0000-4000-8000-000000000001', 10);
insert into public.trivia_duels (bet_id, school_id, challenger_id, stake, question_ids, accept_deadline)
values (pg_temp.id('duel'), 'a0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', 10, '{}', now() + interval '1 hour');
insert into public.trivia_duel_plays (bet_id, player_id, submitted_at, answers, score, elapsed_ms)
values (pg_temp.id('duel'), 'c0000000-0000-4000-8000-000000000001', now(), '{}', 0, 1000);

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';
select public.place_wager(pg_temp.id('p'), pg_temp.opt('p', 'Evet'), 20);
select is(pg_temp.quest('qw'), '(1,f)', 'günün tahmini bahis sayılır, düello yatırımı sayılmaz');
select is(pg_temp.quest('qp'), '(1,f)', 'günün tahmini görevi ilerler');
select public.place_wager(pg_temp.id('s'), pg_temp.opt('s', 'Evet'), 10);
select is(pg_temp.quest('qw'), '(2,f)', 'sosyal bahse yatırım da sayılır, ilerleme hedefte durur');

select is(
  (select row(reward_currency, reward_amount, balance)::text from public.claim_quest_reward(pg_temp.id('qw'))),
  '(SP,40,1000)',
  'tamamlanan görevin ödülü verilir, yeni bakiye döner (1000 − 20 − 10 − 10 + 40)'
);
select throws_ok($$select public.claim_quest_reward(pg_temp.id('qw'))$$, 'KB020', null, 'aynı dönemde ödül bir kez alınır');
select is(pg_temp.quest('qw'), '(2,t)', 'alınan ödül listede işaretli');
select throws_ok($$select public.claim_quest_reward(pg_temp.id('qi'))$$, 'P0002', null, 'kapalı görevin ödülü alınamaz');
select is(pg_temp.quest('qs'), '(0,f)', 'başkasının açtığı sosyal bahis sayılmaz');
select throws_ok($$select public.claim_quest_reward(pg_temp.id('qwin'))$$, 'KB019', null, 'sonuçlanmamış bahis kazanç sayılmaz');
select lives_ok($$select public.claim_quest_reward(pg_temp.id('qd'))$$, 'gönderilmiş düello oyunu düello görevini tamamlar');

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000002","role":"authenticated"}';
select is(pg_temp.quest('qs'), '(1,f)', 'açılan sosyal bahis sosyal bahis görevini ilerletir');
select is((select count(*)::int from public.quest_claims), 0, 'başkasının aldığı ödüller görünmez');

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000007","role":"authenticated"}';
select throws_ok($$select public.claim_quest_reward(pg_temp.id('qw'))$$, 'P0002', null, 'başka okulun görevi bulunamaz');

-- Günün tahmini sonuçlanır: Ali (Evet 20) havuzu alır (50), Veli kaybeder.
set local role postgres;
update public.bets set opens_at = now() - interval '2 hours', locks_at = now() - interval '1 minute' where id = pg_temp.id('p');
set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000006","role":"authenticated"}';
select public.settle_daily_prediction(pg_temp.id('p'), pg_temp.opt('p', 'Evet'));

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';
select lives_ok($$select public.claim_quest_reward(pg_temp.id('qwin'))$$, 'kazanılan bahis kazanma görevini tamamlar');
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000002","role":"authenticated"}';
select is(pg_temp.quest('qwin'), '(0,f)', 'kaybeden kazanma görevinde ilerlemez');

set local role postgres;
select is(
  array[pg_temp.sp('c0000000-0000-4000-8000-000000000001'), pg_temp.ssp('c0000000-0000-4000-8000-000000000001')],
  array[1110, 5]::bigint[],
  'Ali: 1000 − 40 yatırım + 40 + 60 görev + 50 kazanç SP, 5 SSP'
);
select is(
  (select count(*)::int from public.ledger_entries
   where user_id = 'c0000000-0000-4000-8000-000000000001' and reason = 'quest_reward' and ref_type = 'quest'),
  3, 'her ödül ledger''a görev kaydıyla yazılır'
);
select throws_ok(
  $$update public.quest_claims set reward_amount = 999$$,
  '55000', null, 'verilen ödül kayıtları değiştirilemez'
);
select is(
  (select row(o_end - o_start, extract(hour from o_start at time zone 'Europe/Istanbul'))::text
   from private.quest_window((select q from public.quests q where q.id = pg_temp.id('qw')))),
  '("1 day",0)',
  'günlük dönem İstanbul gece yarısında başlar, bir gün sürer'
);
select is(
  (select extract(isodow from o_start at time zone 'Europe/Istanbul')::int
   from private.quest_window((select q from public.quests q where q.id = pg_temp.id('qs')))),
  1, 'haftalık dönem pazartesi başlar'
);
select is(
  private.quest_progress('c0000000-0000-4000-8000-000000000001', 'wager', now() - interval '2 days', now() - interval '1 day'),
  0, 'dönem dışındaki yatırımlar sayılmaz'
);

-- ---------------------------------------------------------------------------
-- Market yönetimi
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';
select throws_ok(
  $$select public.save_market_item(null, 'a0000000-0000-4000-8000-000000000001', 'Öğrenci ürünü', null, 'title', 10, 'SP')$$,
  '42501', null, 'öğrenci ürün ekleyemez'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000004","role":"authenticated"}';
select throws_ok(
  $$select public.save_market_item(null, null, 'Genel ürün', null, 'title', 10, 'SP')$$,
  '42501', null, 'tüm okullara ürünü yalnızca süperadmin ekler'
);
select throws_ok(
  $$select public.save_market_item(null, 'a0000000-0000-4000-8000-000000000001', 'Renksiz çerçeve', null, 'frame', 10, 'SP')$$,
  '23514', null, 'çerçevenin rengi olmalı'
);
select lives_ok(
  $$insert into t values ('m1', public.save_market_item(null, 'a0000000-0000-4000-8000-000000000001',
      ' Kehanet Ustası ', 'Unvan', 'title', 300, 'SP', '🔮'))$$,
  'market_yonet izni olan okuluna ürün ekler'
);
insert into t values ('m2', public.save_market_item(null, 'a0000000-0000-4000-8000-000000000001', 'Altın çerçeve', null, 'frame', 200, 'SP', null, '#D4AF37'));
insert into t values ('m3', public.save_market_item(null, 'a0000000-0000-4000-8000-000000000001', 'Gümüş çerçeve', null, 'frame', 100, 'SP', null, '#C0C0C0'));
select lives_ok(
  $$insert into t values ('m4', public.save_market_item(null, 'a0000000-0000-4000-8000-000000000001', 'Turnuva rozeti', null, 'badge', 50, 'SSP', '🏆'))$$,
  'SSP fiyatlı ürün eklenebilir'
);
insert into t values ('m6', public.save_market_item(null, 'a0000000-0000-4000-8000-000000000001', 'Yarın satışta', null, 'badge', 10, 'SP', '⭐',
                                                     null, now() + interval '1 day'));
select throws_ok(
  $$select public.save_market_item(pg_temp.id('m1'), 'a0000000-0000-4000-8000-000000000001', 'Kehanet Ustası', null, 'badge', 300, 'SP')$$,
  '23514', null, 'ürünün türü sonradan değiştirilemez'
);
select throws_ok(
  $$select public.save_market_item(null, 'a0000000-0000-4000-8000-000000000001', 'Bedava', null, 'title', 0, 'SP')$$,
  '23514', null, 'fiyat en az 1'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000008","role":"authenticated"}';
select throws_ok(
  $$select public.save_market_item(pg_temp.id('m1'), 'b0000000-0000-4000-8000-000000000001', 'Taşınan', null, 'title', 1, 'SP')$$,
  '42501', null, 'başka okulun ürününü düzenleyemez'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000005","role":"authenticated"}';
insert into t values ('m5', public.save_market_item(null, null, 'Kapalı isim rengi', null, 'name_color', 10, 'SP', null, '#7E57C2',
                                                     null, null, false));

set local role postgres;
select is(
  (select count(*)::int from public.admin_audit_log where action = 'market_item_save' and details ->> 'item_id' = pg_temp.id('m1')::text),
  1, 'ürün ekleme denetim kaydına yazılır'
);

-- ---------------------------------------------------------------------------
-- Satın alma
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';
select is((select count(*)::int from public.market_items), 5, 'öğrenci okulunun ve genel aktif ürünleri görür (satış öncesi dahil), kapalıyı görmez');
select is(public.purchase_market_item(pg_temp.id('m1')), 810::bigint, 'ürün satın alınır, yeni bakiye döner (1110 − 300)');
select is(
  (select row(category, equipped, price_paid, currency)::text from public.user_inventory where item_id = pg_temp.id('m1')),
  '(title,f,300,SP)', 'ürün envantere girer, kuşanılmamış'
);
select throws_ok($$select public.purchase_market_item(pg_temp.id('m1'))$$, 'KB022', null, 'aynı ürün iki kez alınmaz');
select throws_ok($$select public.purchase_market_item(pg_temp.id('m4'))$$, 'KB001', null, 'SSP yetmezse alınamaz');
select is((select count(*)::int from public.user_inventory where item_id = pg_temp.id('m4')), 0, 'başarısız satın almada envanter satırı kalmaz');
select throws_ok($$select public.purchase_market_item(pg_temp.id('m5'))$$, 'KB021', null, 'kapalı ürün satılmaz');
select throws_ok($$select public.purchase_market_item(pg_temp.id('m6'))$$, 'KB021', null, 'satış başlamadan ürün alınmaz');

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000007","role":"authenticated"}';
select throws_ok($$select public.purchase_market_item(pg_temp.id('m1'))$$, 'P0002', null, 'başka okulun ürünü bulunamaz');

set local role anon;
select throws_ok($$select public.purchase_market_item('00000000-0000-4000-8000-000000000000')$$, '42501', null, 'oturumsuz satın alma yok');

set local role postgres;
select is(
  (select row(amount, ref_type)::text from public.ledger_entries
   where user_id = 'c0000000-0000-4000-8000-000000000001' and reason = 'market_purchase' and ref_id = pg_temp.id('m1')),
  '(-300,market_item)', 'satın alma ledger''a eksi kayıtla yazılır'
);

-- ---------------------------------------------------------------------------
-- Kuşanma ve görünürlük
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';
select public.purchase_market_item(pg_temp.id('m2'));
select public.purchase_market_item(pg_temp.id('m3'));
select lives_ok($$select public.set_item_equipped(pg_temp.id('m2'), true)$$, 'çerçeve kuşanılır');
select public.set_item_equipped(pg_temp.id('m3'), true);
select is(
  (select array_agg(item_id) from public.user_inventory where category = 'frame' and equipped),
  array[pg_temp.id('m3')],
  'aynı türde yeni kuşanılan eskisini çıkarır'
);
select public.set_item_equipped(pg_temp.id('m3'), false);
select is((select count(*)::int from public.user_inventory where equipped), 0, 'ürün çıkarılır');
select throws_ok($$select public.set_item_equipped(pg_temp.id('m4'), true)$$, 'P0002', null, 'sahip olunmayan ürün kuşanılamaz');
select public.set_item_equipped(pg_temp.id('m1'), true);
select is((select count(*)::int from public.user_inventory), 3, 'kişi tüm envanterini görür');

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000002","role":"authenticated"}';
select is(
  (select array_agg(item_id) from public.user_inventory where user_id = 'c0000000-0000-4000-8000-000000000001'),
  array[pg_temp.id('m1')],
  'okul arkadaşı yalnızca kuşanılmış ürünü görür'
);
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000007","role":"authenticated"}';
select is((select count(*)::int from public.user_inventory), 0, 'başka okul kuşanılmış ürünü de görmez');

-- Satıştan kalkan ürün sahibine ve (kuşanılmışsa) okul arkadaşlarına görünmeye devam eder.
set local role postgres;
update public.market_items set active = false where id in (pg_temp.id('m1'), pg_temp.id('m2'));
set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';
select is((select count(*)::int from public.market_items where id in (pg_temp.id('m1'), pg_temp.id('m2'))), 2,
          'satıştan kalkan ürünlerini sahibi görmeye devam eder');
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000002","role":"authenticated"}';
select is((select count(*)::int from public.market_items where id = pg_temp.id('m1')), 1, 'okul arkadaşının kuşandığı ürün görünür');
select is((select count(*)::int from public.market_items where id = pg_temp.id('m2')), 0, 'kuşanılmamış, satışta olmayan ürün görünmez');
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000007","role":"authenticated"}';
select is((select count(*)::int from public.market_items where id = pg_temp.id('m1')), 0, 'başka okul satışta olmayan ürünü görmez');

set local role postgres;
select is(pg_temp.sp('c0000000-0000-4000-8000-000000000001'), 510::bigint, 'bakiye: 810 − 200 − 100');
select is_empty($$select * from private.balance_mismatches()$$, 'bakiyeler ledger toplamına eşit');

select * from finish();
rollback;
