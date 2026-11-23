-- Adım 1 testleri: kümeler, profiller, üyelikler, yetkiler ve RLS.
-- Tek transaction içinde çalışır ve sonunda geri alınır; buluttaki veriye dokunmaz.
--
-- Kişiler (sabit uuid'ler):
--   A okulu: Ali (öğrenci, sonra yetkili), Veli (öğrenci), Su (süperadmin)
--   B okulu: Zeynep
--   Yeni: giriş yapmış ama profili olmayan kullanıcı

begin;
-- CLI'ın test rolü (cli_login_postgres) postgres yetkilerini kendiliğinden devralmaz.
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(52);

-- ---------------------------------------------------------------------------
-- Hazırlık (postgres rolüyle)
-- ---------------------------------------------------------------------------

insert into public.clusters (id, name, type) values
  ('a0000000-0000-4000-8000-000000000001', 'Test Üniversitesi A', 'school'),
  ('b0000000-0000-4000-8000-000000000001', 'Test Üniversitesi B', 'school');

insert into public.clusters (id, name, type, parent_cluster_id) values
  ('a0000000-0000-4000-8000-000000000002', 'A Satranç Kulübü', 'club', 'a0000000-0000-4000-8000-000000000001'),
  ('a0000000-0000-4000-8000-000000000003', 'A Özel Grup', 'group', 'a0000000-0000-4000-8000-000000000001');

insert into auth.users (id, email, aud, role) values
  ('c0000000-0000-4000-8000-000000000001', 'ali@test.local', 'authenticated', 'authenticated'),
  ('c0000000-0000-4000-8000-000000000002', 'veli@test.local', 'authenticated', 'authenticated'),
  ('c0000000-0000-4000-8000-000000000003', 'zeynep@test.local', 'authenticated', 'authenticated'),
  ('c0000000-0000-4000-8000-000000000004', 'su@test.local', 'authenticated', 'authenticated'),
  ('c0000000-0000-4000-8000-000000000005', 'yeni@test.local', 'authenticated', 'authenticated');

-- ---------------------------------------------------------------------------
-- Şema kuralları
-- ---------------------------------------------------------------------------

select is(
  (select school_id from public.clusters where id = 'a0000000-0000-4000-8000-000000000001'),
  'a0000000-0000-4000-8000-000000000001'::uuid,
  'okulun school_id değeri kendisi'
);

select is(
  (select school_id from public.clusters where id = 'a0000000-0000-4000-8000-000000000002'),
  'a0000000-0000-4000-8000-000000000001'::uuid,
  'alt kümenin school_id değeri bağlı olduğu okul'
);

select throws_ok(
  $$insert into public.clusters (name, type) values ('Sahipsiz Kulüp', 'club')$$,
  '23514', null,
  'okul olmayan küme üst kümesiz olamaz'
);

select throws_ok(
  $$update public.clusters set parent_cluster_id = 'b0000000-0000-4000-8000-000000000001'
    where id = 'a0000000-0000-4000-8000-000000000002'$$,
  '23514', null,
  'kümenin üst kümesi sonradan değiştirilemez'
);

select throws_ok(
  $$insert into public.school_email_domains (domain, school_id)
    values ('kulup.test.edu.tr', 'a0000000-0000-4000-8000-000000000002')$$,
  '23514', null,
  'mail alan adı yalnızca okula bağlanabilir'
);

select throws_ok(
  $$insert into public.school_email_domains (domain, school_id)
    values ('Ogr.Test.edu.tr', 'a0000000-0000-4000-8000-000000000001')$$,
  '23514', null,
  'mail alan adı küçük harf olmalı'
);

select is(
  (select count(*)::int from pg_tables where schemaname = 'public' and not rowsecurity),
  0,
  'public şemasındaki tüm tablolarda RLS açık'
);

-- ---------------------------------------------------------------------------
-- Profil oluşturma (profili olmayan kullanıcı)
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000005","role":"authenticated"}';

select ok(
  (select count(*) from public.clusters where type = 'school') >= 2,
  'profili olmayan kullanıcı okul listesini görür'
);

select is(
  (select count(*)::int from public.clusters where type <> 'school'),
  0,
  'profili olmayan kullanıcı alt kümeleri görmez'
);

select throws_ok(
  $$select public.create_profile('', 'Kişi', 'a0000000-0000-4000-8000-000000000001')$$,
  '23514', null,
  'boş ad reddedilir'
);

select throws_ok(
  $$select public.create_profile('Yeni', 'Kişi', 'a0000000-0000-4000-8000-000000000002')$$,
  '23514', null,
  'okul olmayan küme okul olarak seçilemez'
);

select throws_ok(
  $$insert into public.profiles (id, first_name, last_name, school_id)
    values ('c0000000-0000-4000-8000-000000000005', 'Yeni', 'Kişi', 'a0000000-0000-4000-8000-000000000001')$$,
  '42501', null,
  'profil tabloya doğrudan eklenemez'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000005","role":"authenticated","is_anonymous":true}';

select throws_ok(
  $$select public.create_profile('Anonim', 'Kişi', 'a0000000-0000-4000-8000-000000000001')$$,
  '42501', null,
  'anonim oturum profil oluşturamaz'
);

-- Ali
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';

select lives_ok(
  $$select public.create_profile('  Ali ', 'Kaya', 'a0000000-0000-4000-8000-000000000001', 'Bilgisayar Mühendisliği')$$,
  'profil oluşturulur'
);

select is(
  (select first_name from public.profiles where id = 'c0000000-0000-4000-8000-000000000001'),
  'Ali',
  'ad baştaki ve sondaki boşluklardan temizlenir'
);

select throws_ok(
  $$select public.create_profile('Ali', 'Kaya', 'a0000000-0000-4000-8000-000000000001')$$,
  '23505', null,
  'ikinci profil oluşturulamaz'
);

select ok(
  exists (
    select 1 from public.user_clusters
    where user_id = 'c0000000-0000-4000-8000-000000000001'
      and cluster_id = 'a0000000-0000-4000-8000-000000000001'
  ),
  'kullanıcı okul kümesine üye olur'
);

-- Diğer kullanıcıların profilleri
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000002","role":"authenticated"}';
do $$ begin perform public.create_profile('Veli', 'Demir', 'a0000000-0000-4000-8000-000000000001'); end $$;

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000003","role":"authenticated"}';
do $$ begin perform public.create_profile('Zeynep', 'Ak', 'b0000000-0000-4000-8000-000000000001'); end $$;

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000004","role":"authenticated"}';
do $$ begin perform public.create_profile('Su', 'Er', 'a0000000-0000-4000-8000-000000000001'); end $$;

-- ---------------------------------------------------------------------------
-- Öğrenci olarak Ali: görünürlük ve yazma sınırları
-- ---------------------------------------------------------------------------

-- Okul verisi (alt kümeler, okul arkadaşları) okul maili doğrulanmış öğrenciye açılır; doğrulanmamış hali
-- 22_guvenlik_duzeltmeleri'nde.
set local role postgres;
update public.profile_private set student_email = 'ali@ogr.test.edu.tr', student_email_verified_at = now()
where user_id = 'c0000000-0000-4000-8000-000000000001';
set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';

select is(
  (select count(*)::int from public.clusters where id = 'a0000000-0000-4000-8000-000000000002'),
  1,
  'okul içindeki kulüp görünür'
);

select is(
  (select count(*)::int from public.clusters where id = 'a0000000-0000-4000-8000-000000000003'),
  0,
  'üye olunmayan özel grup görünmez'
);

select is(
  (select count(*)::int from public.profiles where id = 'c0000000-0000-4000-8000-000000000002'),
  1,
  'aynı okuldaki profil görünür'
);

select is(
  (select count(*)::int from public.profiles where id = 'c0000000-0000-4000-8000-000000000003'),
  0,
  'başka okuldaki profil görünmez'
);

select is(
  (select count(*)::int from public.profile_private),
  1,
  'öğrenci yalnızca kendi gizli bilgisini görür'
);

select throws_ok(
  $$update public.profiles set role = 'superadmin' where id = 'c0000000-0000-4000-8000-000000000001'$$,
  '42501', null,
  'kullanıcı kendi rolünü değiştiremez'
);

select throws_ok(
  $$update public.profiles set xp = 1000 where id = 'c0000000-0000-4000-8000-000000000001'$$,
  '42501', null,
  'kullanıcı kendi XP değerini değiştiremez'
);

select lives_ok(
  $$update public.profiles set first_name = 'Ali Can' where id = 'c0000000-0000-4000-8000-000000000001'$$,
  'kullanıcı kendi adını değiştirebilir'
);

with u as (
  update public.profiles set first_name = 'Hack'
  where id = 'c0000000-0000-4000-8000-000000000002'
  returning 1
)
select is((select count(*)::int from u), 0, 'başkasının profili güncellenemez');

select throws_ok(
  $$insert into public.clusters (name, type) values ('Sahte Üniversite', 'school')$$,
  '42501', null,
  'kullanıcı küme ekleyemez'
);

select throws_ok(
  $$insert into public.user_clusters (user_id, cluster_id)
    values ('c0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000003')$$,
  '42501', null,
  'kullanıcı kendini gruba ekleyemez'
);

select throws_ok(
  $$select public.grant_permission('c0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001', 'resmi_bahis_ac')$$,
  '42501', null,
  'öğrenci yetki veremez'
);

select ok(
  not private.has_permission('a0000000-0000-4000-8000-000000000002', 'resmi_bahis_ac'),
  'öğrencinin izni yok'
);

-- ---------------------------------------------------------------------------
-- Başka okuldan Zeynep
-- ---------------------------------------------------------------------------

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000003","role":"authenticated"}';

select is(
  (select count(*)::int from public.clusters
   where school_id = 'a0000000-0000-4000-8000-000000000001' and type <> 'school'),
  0,
  'başka okulun alt kümeleri görünmez'
);

select is(
  (select count(*)::int from public.user_clusters where cluster_id = 'a0000000-0000-4000-8000-000000000001'),
  0,
  'başka okulun üye listesi görünmez'
);

-- ---------------------------------------------------------------------------
-- Süperadmin: yetki verme
-- ---------------------------------------------------------------------------

set local role postgres;
update public.profiles set role = 'superadmin' where id = 'c0000000-0000-4000-8000-000000000004';
update public.profile_private set student_email = 'ali@ogr.test.edu.tr'
where user_id = 'c0000000-0000-4000-8000-000000000001';

select throws_ok(
  $$update public.profile_private set student_email = 'ali@ogr.test.edu.tr'
    where user_id = 'c0000000-0000-4000-8000-000000000002'$$,
  '23505', null,
  'bir okul maili yalnızca bir hesaba bağlanır'
);

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000004","role":"authenticated"}';

select lives_ok(
  $$select public.grant_permission('c0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001', 'resmi_bahis_ac')$$,
  'süperadmin yetki verir'
);

select throws_ok(
  $$select public.grant_permission('c0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000001', 'resmi_bahis_ac')$$,
  '23514', null,
  'başka okulun öğrencisine bu okulda yetki verilemez'
);

select is(
  (select count(*)::int from public.admin_audit_log
   where action = 'permission_grant' and target_user_id = 'c0000000-0000-4000-8000-000000000001'),
  1,
  'yetki verme denetim kaydına yazılır'
);

select is(
  (select count(*)::int from public.profiles where id = 'c0000000-0000-4000-8000-000000000003'),
  1,
  'süperadmin başka okulun profilini görür'
);

select is(
  (select count(*)::int from public.profile_private
   where user_id in (
     'c0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000002',
     'c0000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000004')),
  4,
  'süperadmin gizli bilgileri görür'
);

-- ---------------------------------------------------------------------------
-- Yetkili olarak Ali
-- ---------------------------------------------------------------------------

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';

select is(
  (select role from public.profiles where id = 'c0000000-0000-4000-8000-000000000001'),
  'yetkili'::public.user_role,
  'yetki alan öğrenci yetkili olur'
);

select ok(
  private.has_permission('a0000000-0000-4000-8000-000000000002', 'resmi_bahis_ac'),
  'okul yetkisi alt kümede de geçerli'
);

select ok(
  not private.has_permission('b0000000-0000-4000-8000-000000000001', 'resmi_bahis_ac'),
  'yetki başka okulda geçerli değil'
);

select ok(
  not private.has_permission('a0000000-0000-4000-8000-000000000002', 'resmi_bahis_kapat'),
  'verilmeyen izin yok sayılır'
);

select is(
  (select count(*)::int from public.admin_audit_log),
  0,
  'yetkili denetim kaydını göremez'
);

select is(
  (select count(*)::int from public.profile_private),
  1,
  'kullanıcı yönetme izni olmayan yetkili başkasının gizli bilgisini göremez'
);

select throws_ok(
  $$select public.grant_permission('c0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000001', 'resmi_bahis_ac')$$,
  '42501', null,
  'yetkili başkasına yetki veremez'
);

-- ---------------------------------------------------------------------------
-- Süperadmin: yetkiyi geri alma
-- ---------------------------------------------------------------------------

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000004","role":"authenticated"}';

select lives_ok(
  $$select public.revoke_permission('c0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001', 'resmi_bahis_ac')$$,
  'süperadmin yetkiyi geri alır'
);

select is(
  (select role from public.profiles where id = 'c0000000-0000-4000-8000-000000000001'),
  'student'::public.user_role,
  'izni kalmayan yetkili öğrenciye döner'
);

select is(
  (select count(*)::int from public.admin_audit_log
   where action = 'permission_revoke' and target_user_id = 'c0000000-0000-4000-8000-000000000001'),
  1,
  'yetki geri alma denetim kaydına yazılır'
);

-- ---------------------------------------------------------------------------
-- Giriş yapmamış ziyaretçi (anon)
-- ---------------------------------------------------------------------------

set local role anon;
set local request.jwt.claims to '{"role":"anon"}';

select throws_ok(
  $$select * from public.profiles$$,
  '42501', null,
  'anon profilleri okuyamaz'
);

select throws_ok(
  $$select public.create_profile('Ziyaretçi', 'Kişi', 'a0000000-0000-4000-8000-000000000001')$$,
  '42501', null,
  'anon profil oluşturamaz'
);

-- ---------------------------------------------------------------------------
-- Denetim kaydı yalnızca eklenir (postgres rolü dahil)
-- ---------------------------------------------------------------------------

set local role postgres;

select throws_ok(
  $$update public.admin_audit_log set action = 'degisti'
    where target_user_id = 'c0000000-0000-4000-8000-000000000001'$$,
  '55000', null,
  'denetim kaydı güncellenemez'
);

select throws_ok(
  $$delete from public.admin_audit_log where target_user_id = 'c0000000-0000-4000-8000-000000000001'$$,
  '55000', null,
  'denetim kaydı silinemez'
);

select * from finish();
rollback;
