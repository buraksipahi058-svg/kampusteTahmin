-- Genel güvenlik kontrolü (Adım 17b sonrası) testleri: veri dışa aktarma biçim 2, okul verisinin doğrulanmışa açılması,
-- yasak bilgisinin gizlenmesi, resmi bahsi yöneten yatıramaz, kampüs görevi tavanı / günlük sınır / SSP / onay kenar
-- durumları, fotoğraf depolama sınırları, iptal düelloda cevap yok, gizli başarım. Tek transaction, sonunda geri alınır.
--
-- A okulu: Ali, Veli (öğrenci, doğrulanmış), Mod (yetkili: kampus_gorevi_yonet), Yeni (öğrenci, doğrulanmamış),
-- Süper, Oranci (yetkili: yalnızca resmi_bahis_ac), Yasak (öğrenci, sonra yasaklanır), Moder (yetkili:
-- kullanici_bahsi_denetle), Gorevli (yetkili, okul maili yok, izin yok), Bmod (yetkili: kampus_gorevi_yonet, yasaklı).

begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
alter default privileges for role postgres grant execute on functions to public;

select plan(45);

-- ---------------------------------------------------------------------------
-- Hazırlık
-- ---------------------------------------------------------------------------

update public.economy_settings
set signup_bonus_sp = 1000, trivia_question_count = 5, duel_max_stake_sp = 100, duel_accept_hours = 24, duel_play_hours = 24,
    campus_task_daily_limit = 10, campus_task_staff_max_reward = 100, campus_task_staff_max_xp = 50;
insert into public.clusters (id, name, type) values ('a0000000-0000-4000-8000-000000000001', 'Test Üniversitesi A', 'school');

create function pg_temp.uid(p_n integer) returns uuid language sql immutable as
  $$ select ('c0000000-0000-4000-8000-' || lpad(p_n::text, 12, '0'))::uuid $$;
create function pg_temp.as_user(p_n integer) returns void language sql as
  $$ select set_config('request.jwt.claims', json_build_object('sub', pg_temp.uid(p_n), 'role', 'authenticated')::text, true) $$;

insert into auth.users (id, email, aud, role)
select pg_temp.uid(n), 'kisi' || n || '@test.local', 'authenticated', 'authenticated' from generate_series(1, 10) n;
do $$
declare r record;
begin
  for r in select * from (values (1, 'Ali'), (2, 'Veli'), (3, 'Mod'), (4, 'Yeni'), (5, 'Süper'), (6, 'Oranci'),
                                 (7, 'Yasak'), (8, 'Moder'), (9, 'Gorevli'), (10, 'Bmod')) as v(n, ad) loop
    perform pg_temp.as_user(r.n);
    perform public.create_profile(r.ad, 'Test', 'a0000000-0000-4000-8000-000000000001');
  end loop;
end $$;
update public.profile_private pp
set student_email = 'kisi' || n || '@ogr.test.edu.tr', student_email_verified_at = now()
from generate_series(1, 10) n
where pp.user_id = pg_temp.uid(n) and n not in (4, 9);
update public.profiles set role = 'yetkili' where id in (pg_temp.uid(3), pg_temp.uid(6), pg_temp.uid(8), pg_temp.uid(9),
                                                         pg_temp.uid(10));
update public.profiles set role = 'superadmin' where id = pg_temp.uid(5);
update public.profiles set banned_at = now() where id = pg_temp.uid(10);
insert into public.permissions (user_id, cluster_id, permission_key, granted_by)
select pg_temp.uid(n), 'a0000000-0000-4000-8000-000000000001', k::public.permission_key, pg_temp.uid(5)
from (values (3, 'kampus_gorevi_yonet'), (6, 'resmi_bahis_ac'), (8, 'kullanici_bahsi_denetle'),
             (10, 'kampus_gorevi_yonet')) as v(n, k);
do $$ begin
  perform private.post_ledger(pg_temp.uid(n), 'SSP', 500, 'admin_grant', null, null, pg_temp.uid(5), 'test için SSP')
  from generate_series(1, 2) n;
end $$;

create temp table t (k text primary key, id uuid not null) on commit drop;
grant all on t to authenticated;
create function pg_temp.id(p_k text) returns uuid language sql stable as $$ select id from t where k = p_k $$;
create temp table code (k text primary key, c text not null) on commit drop;
grant select on code to authenticated;
create function pg_temp.code(p_k text) returns text language sql stable as $$ select c from code where k = p_k $$;
create temp table path (k text primary key, p text not null) on commit drop;
grant all on path to authenticated;
create function pg_temp.path(p_k text) returns text language sql stable as $$ select p from path where k = p_k $$;
-- Kişinin klasörüne fotoğraf yükler (istemci yetkisiyle) ve yolunu saklar.
create function pg_temp.upload(p_k text, p_n integer) returns void language sql as $$
  insert into path values (p_k, pg_temp.uid(p_n)::text || '/' || gen_random_uuid()::text || '.jpg');
  insert into storage.objects (bucket_id, name) values ('campus-proofs', (select p from path where k = p_k));
$$;
create function pg_temp.task(p_title text, p_verification text, p_currency text, p_amount integer, p_xp integer)
returns uuid language sql as $$
  select public.save_campus_task(null, 'a0000000-0000-4000-8000-000000000001', p_title, null, '📍',
                                 p_verification::public.campus_verification, 'once', p_currency::public.currency,
                                 p_amount, p_xp, null, 0, null, null, true)
$$;

-- Mod QR görevi açar; Ali ve Veli okutur; Ali başarımını alır; Ali, Veli'ye düello açar.
set local role authenticated;
select pg_temp.as_user(3);
insert into t values ('yemek', pg_temp.task('Yemekhanede ye', 'qr', 'SP', 25, 10));
set local role postgres;
insert into code values ('yemek', private.campus_qr_code(pg_temp.id('yemek'), now()));
set local role authenticated;
select pg_temp.as_user(1);
select * from public.submit_campus_task_qr(pg_temp.id('yemek'), pg_temp.code('yemek'));
select public.claim_achievement('kampus_ilk');
insert into t values ('duello', public.create_trivia_duel(10, pg_temp.uid(2)));
select pg_temp.as_user(2);
select * from public.submit_campus_task_qr(pg_temp.id('yemek'), pg_temp.code('yemek'));

-- ---------------------------------------------------------------------------
-- Veri dışa aktarma (biçim 2)
-- ---------------------------------------------------------------------------

select pg_temp.as_user(1);
create temp table ex on commit drop as select public.export_my_data() as d;
select is((select d ->> 'format' from ex), 'kampusbet-verilerim-2', 'dışa aktarma biçim 2');
select is((select d -> 'campus_task_submissions' -> 0 ->> 'task' from ex) || ':' ||
          (select d -> 'campus_task_submissions' -> 0 ->> 'status' from ex), 'Yemekhanede ye:approved',
          'kampüs görevi gönderisi dahil');
select is((select jsonb_array_length(d -> 'campus_task_submissions') from ex), 1, 'yalnızca kişinin kendi gönderisi');
select is((select d -> 'achievements' -> 0 ->> 'key' from ex), 'kampus_ilk', 'açılan başarım dahil');
select is((select d -> 'trivia_duels' -> 0 ->> 'role' from ex), 'challenger', 'düello, kişinin rolüyle dahil');
set local role postgres;
select is((select jsonb_array_length(d -> 'notifications') from ex),
          (select count(*)::int from public.notifications where user_id = pg_temp.uid(1)), 'kişinin bütün bildirimleri dahil');
select is((select count(*)::int from public.notifications where user_id = pg_temp.uid(2)) > 0, true,
          'karşı tarafın da bildirimi var (davet)');
select is((select d::text like '%' || pg_temp.uid(2) || '%' or d::text like '%' || pg_temp.uid(3) || '%'
             or d::text like '%Veli%' or d::text like '%kisi2@%' from ex), false,
          'karşı tarafın ve yetkilinin kimliği, adı, e-postası yok');
set local role authenticated;
select pg_temp.as_user(2);
select is((select jsonb_array_length(d -> 'trivia_duels') || ':' || (d -> 'trivia_duels' -> 0 ->> 'role')
           from (select public.export_my_data() as d) x), '1:invited', 'davet edilen kendi rolünü görür');

-- ---------------------------------------------------------------------------
-- Okul verisi yalnızca okul maili doğrulanmışa ya da yetkiliye
-- ---------------------------------------------------------------------------

select pg_temp.as_user(4);
select is((select array_agg(first_name) from public.profiles), array['Yeni'],
          'doğrulanmamış öğrenci yalnızca kendi profilini görür');
select is((select count(*)::int from public.bets) + (select count(*)::int from public.trivia_duels)
          + (select count(*)::int from public.achievement_unlocks), 0,
          'doğrulanmamış öğrenci okulun bahislerini, düellolarını, başarımlarını göremez');
select throws_ok($$select * from public.get_leaderboard('ssp_profit', 'all_time')$$, 'KB002', null,
                 'doğrulanmamış öğrenci sıralamayı göremez');
select pg_temp.as_user(1);
select is((select count(*)::int from public.profiles), 10, 'doğrulanmış öğrenci okul arkadaşlarını görür');
select is((select count(*)::int from public.bets where id = pg_temp.id('duello')), 1, 'doğrulanmış öğrenci düelloyu görür');
select lives_ok($$select * from public.get_leaderboard('ssp_profit', 'all_time')$$, 'doğrulanmış öğrenci sıralamayı görür');
select pg_temp.as_user(9);
select is((select count(*)::int from public.profiles), 10, 'yetkili okul maili olmadan da okulunu görür');

-- ---------------------------------------------------------------------------
-- Yasak bilgisi
-- ---------------------------------------------------------------------------

select pg_temp.as_user(1);
select throws_ok($$select banned_at from public.profiles$$, '42501', null, 'öğrenci kimsenin yasak bilgisini okuyamaz');
select is((select count(*)::int from public.banned_users(array[pg_temp.uid(10), pg_temp.uid(1)])), 0,
          'öğrenci yasaklıları sorgulayamaz');
select pg_temp.as_user(8);
select is((select array_agg(user_id) from public.banned_users(array[pg_temp.uid(10), pg_temp.uid(1)])),
          array[pg_temp.uid(10)], 'okulun moderatörü yasaklıları görür');

-- ---------------------------------------------------------------------------
-- Resmi bahsi yöneten yatıramaz
-- ---------------------------------------------------------------------------

select pg_temp.as_user(5);
insert into t values ('final', public.create_official_bet('a0000000-0000-4000-8000-000000000001', 'Final', null,
                                                          array['Kırmızı', 'Mavi'], array[1.80, 2.10], now() + interval '1 hour', 200));
set local role postgres;
insert into t select 'kirmizi', o.id from public.bet_options o where o.bet_id = pg_temp.id('final') and o.position = 1;
set local role authenticated;
select pg_temp.as_user(6);
select throws_ok($$select public.place_wager(pg_temp.id('final'), pg_temp.id('kirmizi'), 10)$$, '42501', null,
                 'oran değiştirebilen (resmi_bahis_ac) resmi bahse yatıramaz');
select pg_temp.as_user(1);
select lives_ok($$select public.place_wager(pg_temp.id('final'), pg_temp.id('kirmizi'), 10)$$, 'öğrenci resmi bahse yatırır');

-- ---------------------------------------------------------------------------
-- Kampüs görevi
-- ---------------------------------------------------------------------------

select pg_temp.as_user(3);
select throws_ok($$select pg_temp.task('Çok ödüllü', 'qr', 'SP', 101, 0)$$, '23514', null,
                 'yetkili tavanın üstünde SP veremez');
select throws_ok($$select pg_temp.task('Çok XP''li', 'qr', 'SP', 10, 51)$$, '23514', null,
                 'yetkili tavanın üstünde XP veremez');
select lives_ok($$insert into t values ('kut', pg_temp.task('Kütüphane', 'qr', 'SP', 100, 50))$$,
                'yetkili tavan kadar ödüllü görev açar');
select pg_temp.as_user(5);
select lives_ok($$insert into t values ('ssp', pg_temp.task('Rektörlük', 'qr', 'SSP', 500, 100))$$,
                'süperadmin tavansız SSP ödüllü görev açar');
select is((select count(*)::int from public.campus_task_qr(pg_temp.id('ssp'))), 1, 'süperadmin SSP görevinin QR''ını alır');
select pg_temp.as_user(3);
select throws_ok($$select * from public.campus_task_qr(pg_temp.id('ssp'))$$, 'P0002', null,
                 'yetkili SSP görevinin QR''ını alamaz');
select throws_ok($$select public.reset_campus_task_qr(pg_temp.id('ssp'))$$, 'P0002', null,
                 'yetkili SSP görevinin QR''ını yenileyemez');

-- Günlük sınır: 2 (Ali bugün 1 görev yaptı).
insert into t values ('spor', pg_temp.task('Spor salonu', 'qr', 'SP', 10, 0));
set local role postgres;
update public.economy_settings set campus_task_daily_limit = 2;
insert into code values ('kut', private.campus_qr_code(pg_temp.id('kut'), now())),
                        ('spor', private.campus_qr_code(pg_temp.id('spor'), now()));
set local role authenticated;
select pg_temp.as_user(1);
select lives_ok($$select * from public.submit_campus_task_qr(pg_temp.id('kut'), pg_temp.code('kut'))$$,
                'günlük sınıra kadar görev yapılır');
select throws_ok($$select * from public.submit_campus_task_qr(pg_temp.id('spor'), pg_temp.code('spor'))$$, 'KB035', null,
                 'günlük sınır dolunca görev yapılamaz');
set local role postgres;
update public.economy_settings set campus_task_daily_limit = 10;

-- Onay: SSP'li gönderi, kendi gönderisi, yasaklı gönderen.
set local role authenticated;
select pg_temp.as_user(5);
insert into t values ('ssp-foto', pg_temp.task('Rektörlükte fotoğraf', 'photo', 'SSP', 30, 0));
select pg_temp.as_user(3);
insert into t values ('foto', pg_temp.task('Çöpü at', 'photo', 'SP', 20, 0));
select pg_temp.as_user(2);
select pg_temp.upload('veli-ssp', 2);
insert into t values ('g-ssp', public.submit_campus_task_photo(pg_temp.id('ssp-foto'), pg_temp.path('veli-ssp')));
select pg_temp.upload('veli', 2);
insert into t values ('g-veli', public.submit_campus_task_photo(pg_temp.id('foto'), pg_temp.path('veli')));
select pg_temp.as_user(7);
select pg_temp.upload('yasak', 7);
insert into t values ('g-yasak', public.submit_campus_task_photo(pg_temp.id('foto'), pg_temp.path('yasak')));

select pg_temp.as_user(3);
select throws_ok($$select public.review_campus_submission(pg_temp.id('g-ssp'), true)$$, '42501', null,
                 'yetkili SSP''li gönderiye karar veremez');
select pg_temp.as_user(5);
select lives_ok($$select public.review_campus_submission(pg_temp.id('g-ssp'), true)$$, 'süperadmin SSP''li gönderiyi onaylar');

set local role postgres;
insert into public.permissions (user_id, cluster_id, permission_key, granted_by)
values (pg_temp.uid(2), 'a0000000-0000-4000-8000-000000000001', 'kampus_gorevi_yonet', pg_temp.uid(5));
set local role authenticated;
select pg_temp.as_user(2);
select throws_ok($$select public.review_campus_submission(pg_temp.id('g-veli'), true)$$, '42501', null,
                 'sonradan yetki alan kendi gönderisini onaylayamaz');
set local role postgres;
delete from public.permissions where user_id = pg_temp.uid(2) and permission_key = 'kampus_gorevi_yonet';
update public.profiles set banned_at = now() where id = pg_temp.uid(7);
set local role authenticated;
select pg_temp.as_user(3);
select throws_ok($$select public.review_campus_submission(pg_temp.id('g-yasak'), true)$$, 'KB036', null,
                 'yasaklı kişinin gönderisi onaylanamaz');
select lives_ok($$select public.review_campus_submission(pg_temp.id('g-yasak'), false, 'Hesap yasaklı')$$,
                'yasaklı kişinin gönderisi reddedilir');

-- ---------------------------------------------------------------------------
-- Fotoğraf depolama
-- ---------------------------------------------------------------------------

set local role postgres;
select is((select file_size_limit from storage.buckets where id = 'campus-proofs'), 1048576::bigint,
          'fotoğraf en fazla 1 MB');
-- Ali'nin 2 saat önce 29 yüklemesi (saatlik sınıra girmez, günlüğe girer).
insert into storage.objects (bucket_id, name, created_at)
select 'campus-proofs', pg_temp.uid(1)::text || '/' || gen_random_uuid()::text || '.jpg', now() - interval '2 hours'
from generate_series(1, 29);
set local role authenticated;
select pg_temp.as_user(1);
select lives_ok($$select pg_temp.upload('ali-30', 1)$$, 'günün 30. yüklemesi geçer');
select throws_ok($$select pg_temp.upload('ali-31', 1)$$, '42501', null, 'günde 30''dan fazla yüklenemez');
select pg_temp.as_user(10);
select is((select count(*)::int from storage.objects where bucket_id = 'campus-proofs'), 0,
          'yasaklı yetkili fotoğraf göremez');
select pg_temp.as_user(3);
select is((select count(*)::int from storage.objects where bucket_id = 'campus-proofs') > 0, true,
          'okulun yetkilisi fotoğrafları görür');

-- ---------------------------------------------------------------------------
-- Düello cevapları: iptal olan düelloda yok
-- ---------------------------------------------------------------------------

select pg_temp.as_user(1);
select count(*) from public.start_trivia_duel(pg_temp.id('duello'));
select * from public.submit_trivia_answers(pg_temp.id('duello'), array[0, 0, 0, 0, 0]::smallint[]);
set local role postgres;
update public.trivia_duels set accept_deadline = now() - interval '1 minute' where bet_id = pg_temp.id('duello');
select private.process_trivia_duels();
set local role authenticated;
select pg_temp.as_user(1);
select throws_ok($$select * from public.trivia_duel_review(pg_temp.id('duello'))$$, 'P0002', null,
                 'tek başına oynanıp iptal olan düellonun cevapları görünmez');

-- ---------------------------------------------------------------------------
-- Gizli başarım
-- ---------------------------------------------------------------------------

select is((select count(*)::int from public.achievements where hidden), 0, 'öğrenci açmadığı gizli başarımı göremez');
select is((select count(*)::int from public.achievements where not hidden) > 0, true, 'öğrenci gizli olmayanları görür');
select pg_temp.as_user(5);
select is((select count(*)::int from public.achievements where hidden) > 0, true, 'süperadmin gizli başarımları görür');

set local role postgres;
select is((select count(*)::int from private.balance_mismatches()), 0, 'bakiye önbelleği ledger ile tutarlı');

select * from finish();
rollback;
