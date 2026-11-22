-- Adım 8 (devam) testleri: günün tahmini (açma, yatırma, sonuç, iptal, zamanlanmış iş).
-- Tek transaction içinde çalışır ve sonunda geri alınır.
--
-- A okulu: Ali, Veli, Can (öğrenci), Acan (yetkili: resmi_bahis_ac), Kapat (yetkili: resmi_bahis_kapat).
-- B okulu: Zeynep (öğrenci), Bmod (yetkili: B'de resmi_bahis_kapat). Herkes 1000 SP ile başlar.

begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(45);

-- ---------------------------------------------------------------------------
-- Hazırlık
-- ---------------------------------------------------------------------------

update public.economy_settings set signup_bonus_sp = 1000, daily_max_stake_sp = 100, daily_result_deadline_days = 3;

insert into public.clusters (id, name, type) values
  ('a0000000-0000-4000-8000-000000000001', 'Test Üniversitesi A', 'school'),
  ('b0000000-0000-4000-8000-000000000001', 'Test Üniversitesi B', 'school');

insert into auth.users (id, email, aud, role)
select id, id::text || '@test.local', 'authenticated', 'authenticated'
from unnest(array[
  'c0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000002',
  'c0000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000004',
  'c0000000-0000-4000-8000-000000000005', 'c0000000-0000-4000-8000-000000000006',
  'c0000000-0000-4000-8000-000000000007'
]::uuid[]) as id;

do $$
declare r record;
begin
  for r in select * from (values
    ('c0000000-0000-4000-8000-000000000001'::uuid, 'Ali', 'a0000000-0000-4000-8000-000000000001'::uuid),
    ('c0000000-0000-4000-8000-000000000002', 'Veli', 'a0000000-0000-4000-8000-000000000001'),
    ('c0000000-0000-4000-8000-000000000003', 'Can', 'a0000000-0000-4000-8000-000000000001'),
    ('c0000000-0000-4000-8000-000000000004', 'Acan', 'a0000000-0000-4000-8000-000000000001'),
    ('c0000000-0000-4000-8000-000000000005', 'Kapat', 'a0000000-0000-4000-8000-000000000001'),
    ('c0000000-0000-4000-8000-000000000006', 'Zeynep', 'b0000000-0000-4000-8000-000000000001'),
    ('c0000000-0000-4000-8000-000000000007', 'Bmod', 'b0000000-0000-4000-8000-000000000001')
  ) as v(id, ad, okul) loop
    perform set_config('request.jwt.claims', json_build_object('sub', r.id, 'role', 'authenticated')::text, true);
    perform public.create_profile(r.ad, 'Test', r.okul);
  end loop;
end $$;

update public.profile_private
set student_email = user_id::text || '@ogr.test.edu.tr', student_email_verified_at = now()
where user_id::text like 'c0000000-0000-4000-8000-00000000000_';

update public.profiles set role = 'yetkili'
where id in ('c0000000-0000-4000-8000-000000000004', 'c0000000-0000-4000-8000-000000000005',
             'c0000000-0000-4000-8000-000000000007');
-- Verenin kim olduğu bu testte önemsiz (granted_by zorunlu).
insert into public.permissions (user_id, cluster_id, permission_key, granted_by) values
  ('c0000000-0000-4000-8000-000000000004', 'a0000000-0000-4000-8000-000000000001', 'resmi_bahis_ac', 'c0000000-0000-4000-8000-000000000007'),
  ('c0000000-0000-4000-8000-000000000005', 'a0000000-0000-4000-8000-000000000001', 'resmi_bahis_kapat', 'c0000000-0000-4000-8000-000000000007'),
  ('c0000000-0000-4000-8000-000000000007', 'b0000000-0000-4000-8000-000000000001', 'resmi_bahis_kapat', 'c0000000-0000-4000-8000-000000000007');

create temp table t (k text primary key, id uuid not null) on commit drop;
grant select, insert on t to authenticated;

create function pg_temp.bet(p_k text) returns uuid language sql stable as $$ select id from t where k = p_k $$;
create function pg_temp.opt(p_k text, p_label text) returns uuid language sql stable as
  $$ select o.id from public.bet_options o where o.bet_id = (select id from t where k = p_k) and o.label = p_label $$;
create function pg_temp.sp(p_uid uuid) returns bigint language sql stable as
  $$ select sp_balance from public.balances where user_id = p_uid $$;
create function pg_temp.payouts(p_k text) returns bigint[] language sql stable as
  $$ select array_agg(w.payout order by w.user_id) from public.wagers w where w.bet_id = (select id from t where k = p_k) $$;

-- Kendi kendine sonuçlanan bir mini oyun (düello yerine geçer), yatırım kapalılığını denemek için.
insert into t values ('duello', private.create_bet(
  'c0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001', 'sp_minigame', 'school',
  'Deneme düellosu', null, array['Meydan okuyan', 'Rakip'], now() + interval '1 hour'));

-- ---------------------------------------------------------------------------
-- Açma
-- ---------------------------------------------------------------------------

set local role anon;
select throws_ok(
  $$select public.create_daily_prediction('a0000000-0000-4000-8000-000000000001', 'Anonim soru?', now() + interval '1 hour')$$,
  '42501', null, 'oturumsuz istek fonksiyonu çağıramaz'
);

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';
select throws_ok(
  $$select public.create_daily_prediction('a0000000-0000-4000-8000-000000000001', 'Öğrenci sorusu?', now() + interval '1 hour')$$,
  '42501', null, 'öğrenci günün tahmini açamaz'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000005","role":"authenticated"}';
select throws_ok(
  $$select public.create_daily_prediction('a0000000-0000-4000-8000-000000000001', 'Kapatıcı sorusu?', now() + interval '1 hour')$$,
  '42501', null, 'yalnızca resmi_bahis_kapat izni olan açamaz'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000004","role":"authenticated"}';
select throws_ok(
  $$select public.create_daily_prediction('a0000000-0000-4000-8000-000000000001', 'Uzak soru?', now() + interval '8 days')$$,
  '23514', null, 'kapanış en geç 7 gün sonra'
);
select throws_ok(
  $$select public.create_daily_prediction('a0000000-0000-4000-8000-000000000001', 'Geçmiş soru?', now() - interval '1 minute')$$,
  '23514', null, 'kapanış ileride olmalı'
);
select throws_ok(
  $$select public.create_daily_prediction('d0000000-0000-4000-8000-000000000001', 'Okulsuz soru?', now() + interval '1 hour')$$,
  'P0002', null, 'olmayan okul'
);
select throws_ok(
  $$select public.create_daily_prediction('b0000000-0000-4000-8000-000000000001', 'Başka okul sorusu?', now() + interval '1 hour')$$,
  '42501', null, 'başka okulda açamaz'
);
select lives_ok(
  $$insert into t values ('d1', public.create_daily_prediction('a0000000-0000-4000-8000-000000000001',
      '  Bugün yemekhanede mercimek çorbası çıkar mı?  ', now() + interval '1 hour', 'Öğle menüsü'))$$,
  'resmi_bahis_ac izni olan okuluna günün tahmini açar'
);
select is(
  (select row(type, currency, settlement_mode, odds_mode, scope, min_stake, max_stake, title)::text
   from public.bets where id = pg_temp.bet('d1')),
  '(sp_minigame,SP,admin,pool,school,1,100,"Bugün yemekhanede mercimek çorbası çıkar mı?")',
  'SP havuzlu mini oyun, sonucu admin girer, kişi başı en fazla ayardaki tutar'
);
select is(
  (select array_agg(label order by position) from public.bet_options where bet_id = pg_temp.bet('d1')),
  array['Evet', 'Hayır'],
  'seçenekler Evet / Hayır'
);

set local role postgres;
select is(
  (select count(*)::int from public.admin_audit_log
   where action = 'daily_prediction_create' and details ->> 'bet_id' = pg_temp.bet('d1')::text),
  1, 'açma denetim kaydına yazılır'
);

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000006","role":"authenticated"}';
select is((select count(*)::int from public.bets where id = pg_temp.bet('d1')), 0, 'başka okulun öğrencisi tahmini görmez');
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';
select is((select count(*)::int from public.bets where id = pg_temp.bet('d1')), 1, 'okulun öğrencisi tahmini görür');

-- ---------------------------------------------------------------------------
-- Yatırma
-- ---------------------------------------------------------------------------

select lives_ok($$select public.place_wager(pg_temp.bet('d1'), pg_temp.opt('d1', 'Evet'), 60)$$, 'öğrenci Evet''e yatırır');
select throws_ok(
  $$select public.place_wager(pg_temp.bet('d1'), pg_temp.opt('d1', 'Hayır'), 10)$$,
  'KB004', null, 'tahmine bir kez yatırılır'
);
select throws_ok(
  $$select public.place_wager(pg_temp.bet('duello'), (select o.id from public.bet_options o where o.bet_id = pg_temp.bet('duello') and o.position = 2), 10)$$,
  '42501', null, 'kendi kendine sonuçlanan mini oyuna genel yatırım hâlâ kapalı'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000002","role":"authenticated"}';
select throws_ok(
  $$select public.place_wager(pg_temp.bet('d1'), pg_temp.opt('d1', 'Hayır'), 101)$$,
  '23514', null, 'kişi başı üst sınır aşılamaz'
);
select lives_ok($$select public.place_wager(pg_temp.bet('d1'), pg_temp.opt('d1', 'Hayır'), 25)$$, 'öğrenci Hayır''a yatırır');

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000003","role":"authenticated"}';
select lives_ok($$select public.place_wager(pg_temp.bet('d1'), pg_temp.opt('d1', 'Evet'), 30)$$, 'üçüncü öğrenci Evet''e yatırır');

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000004","role":"authenticated"}';
select throws_ok(
  $$select public.place_wager(pg_temp.bet('d1'), pg_temp.opt('d1', 'Evet'), 10)$$,
  '42501', null, 'soruyu açan yatırım yapamaz'
);
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000005","role":"authenticated"}';
select throws_ok(
  $$select public.place_wager(pg_temp.bet('d1'), pg_temp.opt('d1', 'Evet'), 10)$$,
  '42501', null, 'sonucu girebilecek olan yatırım yapamaz'
);
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000006","role":"authenticated"}';
select throws_ok(
  $$select public.place_wager(pg_temp.bet('d1'), pg_temp.opt('d1', 'Evet'), 10)$$,
  'P0002', null, 'başka okulun öğrencisi yatıramaz'
);

-- ---------------------------------------------------------------------------
-- Sonuçlandırma
-- ---------------------------------------------------------------------------

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000005","role":"authenticated"}';
select throws_ok(
  $$select public.settle_daily_prediction(pg_temp.bet('d1'), pg_temp.opt('d1', 'Evet'))$$,
  'KB005', null, 'kapanmadan sonuç girilemez'
);
select throws_ok(
  $$select public.settle_official_bet(pg_temp.bet('d1'), pg_temp.opt('d1', 'Evet'))$$,
  'P0002', null, 'günün tahmini resmi bahis fonksiyonuyla sonuçlandırılamaz'
);
select throws_ok(
  $$select public.settle_daily_prediction(pg_temp.bet('duello'), (select o.id from public.bet_options o where o.bet_id = pg_temp.bet('duello') and o.position = 1))$$,
  'P0002', null, 'düello günün tahmini fonksiyonuyla sonuçlandırılamaz'
);

set local role postgres;
update public.bets set opens_at = now() - interval '2 hours', locks_at = now() - interval '1 minute' where id = pg_temp.bet('d1');
set local role authenticated;

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';
select throws_ok(
  $$select public.settle_daily_prediction(pg_temp.bet('d1'), pg_temp.opt('d1', 'Evet'))$$,
  '42501', null, 'öğrenci sonuç giremez'
);
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000007","role":"authenticated"}';
select throws_ok(
  $$select public.settle_daily_prediction(pg_temp.bet('d1'), pg_temp.opt('d1', 'Evet'))$$,
  '42501', null, 'başka okulun yetkilisi sonuç giremez'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000005","role":"authenticated"}';
select lives_ok(
  $$select public.settle_daily_prediction(pg_temp.bet('d1'), pg_temp.opt('d1', 'Evet'))$$,
  'resmi_bahis_kapat izni olan sonucu girer'
);
-- Havuz 115, Evet 90: Ali 60 → 76,67, Can 30 → 38,33; kalan 1 SP kesri büyük olana (Ali).
set local role postgres;
select is(pg_temp.payouts('d1'), array[77, 0, 38]::bigint[], 'havuz pari-mutuel dağıtılır, toplam = havuz');
select is(
  array[pg_temp.sp('c0000000-0000-4000-8000-000000000001'), pg_temp.sp('c0000000-0000-4000-8000-000000000002'),
        pg_temp.sp('c0000000-0000-4000-8000-000000000003')],
  array[1017, 975, 1008]::bigint[],
  'bakiyeler ledger üzerinden güncellenir'
);
select is(
  (select count(*)::int from public.admin_audit_log
   where action = 'daily_prediction_settle' and details ->> 'bet_id' = pg_temp.bet('d1')::text),
  1, 'sonuç denetim kaydına yazılır'
);

set local role authenticated;
select throws_ok(
  $$select public.settle_daily_prediction(pg_temp.bet('d1'), pg_temp.opt('d1', 'Hayır'))$$,
  'KB006', null, 'sonuç bir kez girilir'
);

-- ---------------------------------------------------------------------------
-- İptal
-- ---------------------------------------------------------------------------

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000004","role":"authenticated"}';
insert into t values ('d2', public.create_daily_prediction('a0000000-0000-4000-8000-000000000001', 'Yarın ders iptal olur mu?', now() + interval '1 hour'));
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';
select public.place_wager(pg_temp.bet('d2'), pg_temp.opt('d2', 'Evet'), 40);

select throws_ok(
  $$select public.cancel_daily_prediction(pg_temp.bet('d2'), 'Öğrenci iptali')$$,
  '42501', null, 'öğrenci iptal edemez'
);
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000004","role":"authenticated"}';
select throws_ok(
  $$select public.cancel_daily_prediction(pg_temp.bet('d2'), 'Açanın iptali')$$,
  '42501', null, 'yalnızca açma izni olan iptal edemez'
);
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000005","role":"authenticated"}';
select lives_ok(
  $$select public.cancel_daily_prediction(pg_temp.bet('d2'), 'Soru yanlış yazıldı')$$,
  'resmi_bahis_kapat izni olan iptal eder'
);

set local role postgres;
select is(
  (select row(b.status, b.cancel_reason, w.payout)::text from public.bets b join public.wagers w on w.bet_id = b.id
   where b.id = pg_temp.bet('d2')),
  '(cancelled,"Soru yanlış yazıldı",40)',
  'iptalde yatırım iade edilir'
);
select is(pg_temp.sp('c0000000-0000-4000-8000-000000000001'), 1017::bigint, 'iade bakiyeye döner');

set local role authenticated;
select throws_ok(
  $$select public.cancel_daily_prediction(pg_temp.bet('d2'), 'İkinci iptal')$$,
  'KB006', null, 'iptal edilen tekrar iptal edilemez'
);

-- ---------------------------------------------------------------------------
-- Zamanlanmış iş: süresinde sonucu girilmeyen iptal
-- ---------------------------------------------------------------------------

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000004","role":"authenticated"}';
insert into t values ('d3', public.create_daily_prediction('a0000000-0000-4000-8000-000000000001', 'Unutulan soru?', now() + interval '1 hour'));
insert into t values ('d4', public.create_daily_prediction('a0000000-0000-4000-8000-000000000001', 'Bekleyen soru?', now() + interval '1 hour'));
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000002","role":"authenticated"}';
select public.place_wager(pg_temp.bet('d3'), pg_temp.opt('d3', 'Hayır'), 10);

set local role postgres;
update public.bets set opens_at = now() - interval '5 days', locks_at = now() - interval '4 days' where id = pg_temp.bet('d3');
update public.bets set opens_at = now() - interval '2 days', locks_at = now() - interval '1 day' where id = pg_temp.bet('d4');

select is(private.process_daily_predictions(), 1, 'iş yalnızca süresi geçeni iptal eder');
select is(
  (select row(status, cancel_reason)::text from public.bets where id = pg_temp.bet('d3')),
  '(cancelled,"Sonuç süresi içinde girilmedi")',
  'süresi geçen tahmin gerekçesiyle iptal'
);
select is(pg_temp.sp('c0000000-0000-4000-8000-000000000002'), 975::bigint, 'süresi geçen tahminde yatırım iade');
select is((select status::text from public.bets where id = pg_temp.bet('d4')), 'open', 'süresi dolmayan tahmine dokunulmaz');

-- ---------------------------------------------------------------------------
-- Kısıt ve genel kontroller
-- ---------------------------------------------------------------------------

select throws_ok(
  $$update public.bets set settlement_mode = 'referee' where id = pg_temp.bet('duello')$$,
  '23514', null, 'mini oyun hakemli olamaz'
);
select is_empty(
  $$select b.id from public.bets b join public.wagers w on w.bet_id = b.id
    where b.type = 'sp_minigame' and b.settlement_mode = 'admin' and b.status in ('settled', 'cancelled')
    group by b.id, b.pool_total
    having sum(w.payout) <> b.pool_total or count(w.payout) <> count(*)$$,
  'sonuçlanan ve iptal edilen tahminlerde dağıtılan toplam havuza eşit'
);
select is(
  (select count(*)::int from cron.job where jobname = 'kampusbet_gunun_tahmini' and schedule = '0 * * * *'),
  1,
  'günün tahmini işi saatte bir çalışacak şekilde zamanlanmış'
);

select * from finish();
rollback;
