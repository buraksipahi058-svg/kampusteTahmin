-- Adım 2 testleri: ledger, bakiye, başlangıç SP'si, günlük giriş serisi, süperadmin para işlemleri.
-- Tek transaction içinde çalışır ve sonunda geri alınır.
--
-- Ayarlar (taslak): başlangıç 1000 SP; günlük taban 50, adım 10, tavan 150;
-- kilometre taşları 7 -> +200, 14 -> +500, 30 -> +1500. Testler bu değerleri ayardan okur.
--
-- Kişiler: Ali (öğrenci), Veli (öğrenci), Su (süperadmin), Yeni (profili yok). Hepsi A okulunda.

begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(47);

-- ---------------------------------------------------------------------------
-- Hazırlık
-- ---------------------------------------------------------------------------

-- Ayarları sabitle (testler buluttaki ayar değişse de aynı rakamlarla çalışsın).
update public.economy_settings
set signup_bonus_sp = 1000, daily_base_sp = 50, daily_step_sp = 10, daily_max_sp = 150,
    streak_milestones = '{"7": 200, "14": 500, "30": 1500}', day_timezone = 'Europe/Istanbul';

insert into public.clusters (id, name, type) values
  ('a0000000-0000-4000-8000-000000000001', 'Test Üniversitesi A', 'school');

insert into auth.users (id, email, aud, role) values
  ('c0000000-0000-4000-8000-000000000001', 'ali@test.local', 'authenticated', 'authenticated'),
  ('c0000000-0000-4000-8000-000000000002', 'veli@test.local', 'authenticated', 'authenticated'),
  ('c0000000-0000-4000-8000-000000000004', 'su@test.local', 'authenticated', 'authenticated'),
  ('c0000000-0000-4000-8000-000000000005', 'yeni@test.local', 'authenticated', 'authenticated');

-- Bugün ve dün (oyun günü İstanbul saatine göre)
create temp table gun on commit drop as
  select (now() at time zone 'Europe/Istanbul')::date as bugun;
grant select on gun to authenticated;

-- ---------------------------------------------------------------------------
-- Başlangıç SP'si
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';

select lives_ok(
  $$select public.create_profile('Ali', 'Kaya', 'a0000000-0000-4000-8000-000000000001')$$,
  'profil oluşturulur'
);

select is(
  (select sp_balance from public.balances where user_id = 'c0000000-0000-4000-8000-000000000001'),
  1000::bigint,
  'yeni kullanıcı başlangıç SP''si ile başlar'
);

select is(
  (select row(amount, balance_after, actor_id)::text from public.ledger_entries
   where user_id = 'c0000000-0000-4000-8000-000000000001' and reason = 'signup_bonus'),
  '(1000,1000,c0000000-0000-4000-8000-000000000001)',
  'başlangıç SP''si ledger''a yazılır'
);

select is(
  (select ssp_balance from public.balances where user_id = 'c0000000-0000-4000-8000-000000000001'),
  0::bigint,
  'yeni kullanıcının SSP''si yok'
);

-- ---------------------------------------------------------------------------
-- Günlük giriş
-- ---------------------------------------------------------------------------

select is(
  (select row(claimed, amount, current_streak, sp_balance)::text from public.claim_daily_login()),
  '(t,50,1,1050)',
  'ilk gün: 50 SP, seri 1'
);

select is(
  (select row(claimed, amount, current_streak, sp_balance)::text from public.claim_daily_login()),
  '(f,0,1,1050)',
  'aynı gün ikinci kez ödül verilmez'
);

select is(
  (select count(*)::int from public.ledger_entries
   where user_id = 'c0000000-0000-4000-8000-000000000001' and reason = 'daily_login'),
  1,
  'aynı gün yalnızca bir günlük ödül kaydı var'
);

-- Dün giriş yapmış gibi
set local role postgres;
update public.login_streaks set last_login_date = (select bugun - 1 from gun)
where user_id = 'c0000000-0000-4000-8000-000000000001';
set local role authenticated;

select is(
  (select row(claimed, amount, current_streak)::text from public.claim_daily_login()),
  '(t,60,2)',
  'ardışık ikinci gün: seri 2, ödül 60'
);

-- Seri kırılır
set local role postgres;
update public.login_streaks set last_login_date = (select bugun - 3 from gun)
where user_id = 'c0000000-0000-4000-8000-000000000001';
set local role authenticated;

select is(
  (select row(claimed, amount, current_streak)::text from public.claim_daily_login()),
  '(t,50,1)',
  'bir gün atlanınca seri 1''e döner'
);

-- 7. gün kilometre taşı
set local role postgres;
update public.login_streaks set current_streak = 6, longest_streak = 6, last_login_date = (select bugun - 1 from gun)
where user_id = 'c0000000-0000-4000-8000-000000000001';
set local role authenticated;

select is(
  (select row(claimed, amount, current_streak)::text from public.claim_daily_login()),
  '(t,310,7)',
  '7. gün: 110 + 200 kilometre taşı bonusu'
);

-- Tavan + 30. gün kilometre taşı
set local role postgres;
update public.login_streaks set current_streak = 29, longest_streak = 29, last_login_date = (select bugun - 1 from gun)
where user_id = 'c0000000-0000-4000-8000-000000000001';
set local role authenticated;

select is(
  (select row(claimed, amount, current_streak)::text from public.claim_daily_login()),
  '(t,1650,30)',
  '30. gün: tavan 150 + 1500 kilometre taşı bonusu'
);

select is(
  (select longest_streak from public.login_streaks where user_id = 'c0000000-0000-4000-8000-000000000001'),
  30,
  'en uzun seri güncellenir'
);

select is(
  (select sp_balance from public.balances where user_id = 'c0000000-0000-4000-8000-000000000001'),
  (1000 + 50 + 60 + 50 + 310 + 1650)::bigint,
  'bakiye tüm ödüllerin toplamı'
);

-- ---------------------------------------------------------------------------
-- İstemci paraya doğrudan dokunamaz
-- ---------------------------------------------------------------------------

select throws_ok(
  $$insert into public.ledger_entries (user_id, currency, amount, reason, balance_after)
    values ('c0000000-0000-4000-8000-000000000001', 'SP', 100000, 'quest_reward', 100000)$$,
  '42501', null,
  'kullanıcı ledger''a satır ekleyemez'
);

select throws_ok(
  $$update public.balances set sp_balance = 999999 where user_id = 'c0000000-0000-4000-8000-000000000001'$$,
  '42501', null,
  'kullanıcı bakiyesini değiştiremez'
);

select throws_ok(
  $$update public.login_streaks set current_streak = 29 where user_id = 'c0000000-0000-4000-8000-000000000001'$$,
  '42501', null,
  'kullanıcı serisini değiştiremez'
);

select throws_ok(
  $$select private.post_ledger('c0000000-0000-4000-8000-000000000001', 'SP', 100000, 'quest_reward')$$,
  '42501', null,
  'kullanıcı iç para fonksiyonunu çağıramaz'
);

select throws_ok(
  $$update public.economy_settings set signup_bonus_sp = 999999$$,
  '42501', null,
  'kullanıcı ekonomi ayarlarını değiştiremez'
);

select is(
  (select count(*)::int from public.economy_settings),
  1,
  'ekonomi ayarları okunabilir'
);

select throws_ok(
  $$select public.admin_grant('c0000000-0000-4000-8000-000000000001', 'SSP', 50, 'kendime ödül')$$,
  '42501', null,
  'öğrenci para veremez'
);

-- ---------------------------------------------------------------------------
-- Başkasının parası görünmez
-- ---------------------------------------------------------------------------

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000002","role":"authenticated"}';
do $$ begin perform public.create_profile('Veli', 'Demir', 'a0000000-0000-4000-8000-000000000001'); end $$;

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';

select is(
  (select count(*)::int from public.balances where user_id = 'c0000000-0000-4000-8000-000000000002'),
  0,
  'başkasının bakiyesi görünmez'
);

select is(
  (select count(*)::int from public.ledger_entries where user_id = 'c0000000-0000-4000-8000-000000000002'),
  0,
  'başkasının ledger kayıtları görünmez'
);

select is(
  (select count(*)::int from public.login_streaks where user_id = 'c0000000-0000-4000-8000-000000000002'),
  0,
  'başkasının serisi görünmez'
);

-- ---------------------------------------------------------------------------
-- Süperadmin para işlemleri
-- ---------------------------------------------------------------------------

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000004","role":"authenticated"}';
do $$ begin perform public.create_profile('Su', 'Er', 'a0000000-0000-4000-8000-000000000001'); end $$;

set local role postgres;
update public.profiles set role = 'superadmin' where id = 'c0000000-0000-4000-8000-000000000004';
set local role authenticated;

select lives_ok(
  $$select public.admin_grant('c0000000-0000-4000-8000-000000000001', 'SSP', 50, 'Bahar turnuvası ödülü')$$,
  'süperadmin SSP verir'
);

select is(
  (select ssp_balance from public.balances where user_id = 'c0000000-0000-4000-8000-000000000001'),
  50::bigint,
  'SSP bakiyeye eklenir'
);

select is(
  (select row(actor_id, note)::text from public.ledger_entries
   where user_id = 'c0000000-0000-4000-8000-000000000001' and reason = 'admin_grant'),
  '(c0000000-0000-4000-8000-000000000004,"Bahar turnuvası ödülü")',
  'kimin verdiği ve gerekçe ledger''a yazılır'
);

select throws_ok(
  $$select public.admin_grant('c0000000-0000-4000-8000-000000000001', 'SP', 100, '  ')$$,
  '23514', null,
  'gerekçesiz para verilemez'
);

select throws_ok(
  $$select public.admin_grant('c0000000-0000-4000-8000-000000000001', 'SP', 0, 'sıfır ödül')$$,
  '23514', null,
  'sıfır ya da eksi miktar verilemez'
);

select throws_ok(
  $$select public.admin_grant('c0000000-0000-4000-8000-000000000001', 'SP', 2000000, 'çok büyük ödül')$$,
  '22003', null,
  'tek işlemde üst sınır aşılamaz'
);

select throws_ok(
  $$select public.admin_grant('c0000000-0000-4000-8000-000000000004', 'SSP', 100, 'kendime ödül')$$,
  '42501', null,
  'süperadmin kendine para veremez'
);

select throws_ok(
  $$select public.admin_adjust('c0000000-0000-4000-8000-000000000001', 'SSP', -51, 'hatalı ödül geri alındı')$$,
  'KB001', null,
  'düzeltme bakiyeyi negatife düşüremez'
);

select lives_ok(
  $$select public.admin_adjust('c0000000-0000-4000-8000-000000000001', 'SSP', -20, 'hatalı ödül geri alındı')$$,
  'süperadmin bakiyeyi eksi yönde düzeltir'
);

select is(
  (select ssp_balance from public.balances where user_id = 'c0000000-0000-4000-8000-000000000001'),
  30::bigint,
  'düzeltme bakiyeye yansır'
);

select throws_ok(
  $$select public.admin_adjust('c0000000-0000-4000-8000-000000000001', 'SP', 0, 'sıfır düzeltme')$$,
  '23514', null,
  'sıfır düzeltme yapılamaz'
);

select is(
  (select count(*)::int from public.balances where user_id = 'c0000000-0000-4000-8000-000000000002'),
  1,
  'süperadmin başkalarının bakiyesini görür'
);

-- ---------------------------------------------------------------------------
-- Ledger kuralları (postgres rolü dahil)
-- ---------------------------------------------------------------------------

set local role postgres;

select throws_ok(
  $$update public.ledger_entries set amount = 1 where user_id = 'c0000000-0000-4000-8000-000000000001'$$,
  '55000', null,
  'ledger satırı güncellenemez'
);

select throws_ok(
  $$delete from public.ledger_entries where user_id = 'c0000000-0000-4000-8000-000000000001'$$,
  '55000', null,
  'ledger satırı silinemez'
);

select throws_ok(
  $$select private.post_ledger('c0000000-0000-4000-8000-000000000001', 'SP', -999999, 'admin_adjust',
      null, null, 'c0000000-0000-4000-8000-000000000004', 'büyük düşüm')$$,
  'KB001', null,
  'bakiye hiçbir yoldan negatife düşmez'
);

select throws_ok(
  $$select private.post_ledger('c0000000-0000-4000-8000-000000000001', 'SP', 1000, 'signup_bonus')$$,
  '23505', null,
  'başlangıç SP''si ikinci kez verilemez'
);

select throws_ok(
  $$select private.post_ledger('c0000000-0000-4000-8000-000000000001', 'SSP', 50, 'daily_login')$$,
  '23514', null,
  'günlük ödül SSP olamaz'
);

select throws_ok(
  $$select private.post_ledger('c0000000-0000-4000-8000-000000000001', 'SP', 100, 'bet_stake')$$,
  '23514', null,
  'bahis yatırma artı tutar olamaz'
);

select throws_ok(
  $$select private.post_ledger('c0000000-0000-4000-8000-000000000001', 'SP', 100, 'admin_grant')$$,
  '23514', null,
  'admin işlemi kimin yaptığı ve gerekçe olmadan yazılamaz'
);

select is(
  (select sp_balance from public.balances where user_id = 'c0000000-0000-4000-8000-000000000001'),
  (1000 + 50 + 60 + 50 + 310 + 1650)::bigint,
  'başarısız işlemler bakiyeyi değiştirmez'
);

select is_empty(
  $$select * from private.balance_mismatches()$$,
  'önbellekteki bakiye ledger toplamına eşit'
);

select is_empty(
  $$select id from (
      select id, balance_after,
             sum(amount) over (partition by user_id, currency order by id) as running
      from public.ledger_entries
    ) t
    where balance_after <> running$$,
  'her ledger satırının balance_after değeri o ana kadarki toplam'
);

-- ---------------------------------------------------------------------------
-- Giriş yapmamış ya da profili olmayan
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000005","role":"authenticated"}';

select throws_ok(
  $$select * from public.claim_daily_login()$$,
  'P0002', null,
  'profili olmayan günlük ödül alamaz'
);

set local role anon;
set local request.jwt.claims to '{"role":"anon"}';

select throws_ok(
  $$select * from public.claim_daily_login()$$,
  '42501', null,
  'giriş yapmamış ziyaretçi günlük ödül alamaz'
);

select * from finish();
rollback;
