-- Adım 11 güvenlik denetimi: tüm şema üzerinde değişmezler (RLS, yetkiler, search_path, varsayılan
-- yetkiler) ve kimlik / okul sınırını aşmaya çalışan saldırı denemeleri.
-- Yeni tablo ya da fonksiyon bu kurallardan birini bozarsa test listeyle birlikte düşer.
-- Tek transaction içinde çalışır ve sonunda geri alınır.

begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(32);

-- Uzantıların ve Supabase'in kendi nesneleri hariç: yalnızca bizim public / private nesnelerimiz.
create temp table our_functions on commit drop as
  select p.oid, n.nspname, p.oid::regprocedure::text as sig, p.proname, p.proconfig
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname in ('public', 'private')
    and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
    and p.oid::regprocedure::text <> 'rls_auto_enable()';

-- ---------------------------------------------------------------------------
-- Şema değişmezleri
-- ---------------------------------------------------------------------------

select is(
  (select coalesce(array_agg(n.nspname || '.' || c.relname order by 1), '{}') from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where c.relkind in ('r', 'p') and n.nspname in ('public', 'private') and not c.relrowsecurity),
  '{}'::text[], 'her tabloda RLS açık'
);
select is(
  (select coalesce(array_agg(distinct g.grantee || ':' || g.table_schema || '.' || g.table_name || ':' || g.privilege_type), '{}')
   from information_schema.role_table_grants g
   where g.grantee in ('anon', 'authenticated') and g.table_schema in ('public', 'private') and g.privilege_type <> 'SELECT'),
  '{}'::text[], 'istemci rolleri hiçbir tabloya yazamaz (ekleme, güncelleme, silme, truncate)'
);
select is(
  (select array_agg(g.column_name::text order by g.column_name) from information_schema.column_privileges g
   where g.grantee = 'authenticated' and g.table_schema = 'public' and g.privilege_type <> 'SELECT'),
  array['department', 'first_name', 'last_name'], 'tek kolon izni: kişi profilinde ad, soyad, bölüm'
);
select is(
  (select count(*)::int from information_schema.role_table_grants g
   where g.grantee = 'anon' and g.table_schema in ('public', 'private')),
  0, 'anonim hiçbir tabloyu okuyamaz'
);
select is(
  (select coalesce(array_agg(f.sig order by f.sig), '{}') from our_functions f
   where not exists (select 1 from unnest(coalesce(f.proconfig, '{}')) c where c like 'search_path=%')),
  '{}'::text[], 'her fonksiyonda search_path sabit'
);
select is(
  (select coalesce(array_agg(f.sig order by f.sig), '{}') from our_functions f where has_function_privilege('anon', f.oid, 'execute')),
  '{}'::text[], 'anonim hiçbir fonksiyonu çalıştıramaz'
);
select is(
  (select array_agg(f.proname::text order by f.proname) from our_functions f
   where f.nspname = 'private' and has_function_privilege('authenticated', f.oid, 'execute')),
  array['campus_proof_readable', 'campus_upload_allowed', 'current_school_id', 'has_permission', 'is_superadmin',
        'my_cluster_ids', 'school_of_user'],
  'private şemada giriş yapanın çalıştırabildiği yalnızca RLS yardımcıları'
);
select is(
  (select count(*)::int from information_schema.role_usage_grants g
   where g.grantee in ('anon', 'authenticated') and g.object_schema in ('public', 'private')),
  0, 'kimlik dizileri istemcilere kapalı'
);
select is(
  (select array_agg(p.tablename || '.' || p.policyname) from pg_policies p where p.schemaname = 'public' and p.cmd <> 'SELECT'),
  array['profiles.profiles_update_own'], 'okuma dışındaki tek politika: kişinin kendi profilini güncellemesi'
);
select is(
  (select count(*)::int from pg_policies p
   where p.schemaname = 'public' and ('anon' = any (p.roles) or 'public' = any (p.roles))),
  0, 'anonime ya da herkese açık politika yok'
);
select is(
  (select count(*)::int from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where c.relkind in ('v', 'm') and n.nspname in ('public', 'private')),
  0, 'görünüm (view) yok: RLS''i atlayan yol yok'
);
select is(
  (select count(*)::int from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public'),
  0, 'Realtime ile yayınlanan tablo yok'
);
select ok(not has_schema_privilege('anon', 'private', 'usage'), 'anonim private şemaya erişemez');

-- Varsayılan yetkiler: yeni nesne istemcilere kendiliğinden açılmaz.
create table public.guvenlik_deneme (id integer);
create function public.guvenlik_deneme_fn() returns integer language sql set search_path = '' as $$ select 1 $$;
create function private.guvenlik_deneme_fn() returns integer language sql set search_path = '' as $$ select 1 $$;
select ok(
  not has_table_privilege('anon', 'public.guvenlik_deneme', 'select')
  and not has_table_privilege('authenticated', 'public.guvenlik_deneme', 'select,insert,update,delete'),
  'yeni tablo istemcilere kapalı başlar'
);
select ok(
  not has_function_privilege('anon', 'public.guvenlik_deneme_fn()', 'execute')
  and not has_function_privilege('authenticated', 'public.guvenlik_deneme_fn()', 'execute')
  and not has_function_privilege('authenticated', 'private.guvenlik_deneme_fn()', 'execute'),
  'yeni fonksiyon istemcilere kapalı başlar'
);

-- ---------------------------------------------------------------------------
-- Saldırı denemeleri
-- ---------------------------------------------------------------------------

insert into public.clusters (id, name, type) values
  ('a0000000-0000-4000-8000-000000000001', 'Test Üniversitesi A', 'school'),
  ('b0000000-0000-4000-8000-000000000001', 'Test Üniversitesi B', 'school');
insert into auth.users (id, email, aud, role)
select ('c0000000-0000-4000-8000-00000000000' || n)::uuid, n || '@test.local', 'authenticated', 'authenticated'
from generate_series(1, 3) n;

do $$
declare r record;
begin
  for r in select * from (values
    ('c0000000-0000-4000-8000-000000000001'::uuid, 'Ali', 'a0000000-0000-4000-8000-000000000001'::uuid),
    ('c0000000-0000-4000-8000-000000000002', 'Zeynep', 'b0000000-0000-4000-8000-000000000001'),
    ('c0000000-0000-4000-8000-000000000003', 'Süper', 'a0000000-0000-4000-8000-000000000001')
  ) as v(id, ad, okul) loop
    perform set_config('request.jwt.claims', json_build_object('sub', r.id, 'role', 'authenticated')::text, true);
    perform public.create_profile(r.ad, 'Test', r.okul);
  end loop;
end $$;
update public.profiles set role = 'superadmin' where id = 'c0000000-0000-4000-8000-000000000003';

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';

select throws_ok($$update public.profiles set role = 'superadmin' where id = 'c0000000-0000-4000-8000-000000000001'$$,
  '42501', null, 'kişi kendi rolünü değiştiremez');
select throws_ok($$update public.profiles set school_id = 'b0000000-0000-4000-8000-000000000001' where id = 'c0000000-0000-4000-8000-000000000001'$$,
  '42501', null, 'kişi okulunu değiştiremez');
select lives_ok($$update public.profiles set first_name = 'Alim' where id = 'c0000000-0000-4000-8000-000000000001'$$,
  'kişi kendi adını değiştirebilir');
select is((select count(*)::int from public.profiles where id = 'c0000000-0000-4000-8000-000000000002'), 0,
  'başka okulun profili görünmez');
select is((select count(*)::int from public.ledger_entries where user_id <> 'c0000000-0000-4000-8000-000000000001'), 0,
  'başkasının ledger kaydı görünmez');
select is((select count(*)::int from public.balances where user_id <> 'c0000000-0000-4000-8000-000000000001'), 0,
  'başkasının bakiyesi görünmez');
select is((select count(*)::int from public.profile_private where user_id <> 'c0000000-0000-4000-8000-000000000001'), 0,
  'başkasının gizli profili görünmez');
select throws_ok($$select count(*) from private.leaderboard_runs$$, '42501', null, 'private tablolar okunamaz');
select throws_ok(
  $$select private.post_ledger('c0000000-0000-4000-8000-000000000001', 'SP', 1000000, 'admin_grant', null, null,
    'c0000000-0000-4000-8000-000000000001', 'hile')$$,
  '42501', null, 'ledger''a doğrudan yazılamaz');
select throws_ok($$insert into public.ledger_entries (user_id, currency, amount, reason, balance_after)
  values ('c0000000-0000-4000-8000-000000000001', 'SP', 1000, 'admin_grant', 1000)$$,
  '42501', null, 'ledger tablosuna eklenemez');
select throws_ok($$delete from public.bets$$, '42501', null, 'bahis silinemez');
select throws_ok($$select public.admin_grant('c0000000-0000-4000-8000-000000000001', 'SP', 1000, 'kendime para')$$,
  '42501', null, 'öğrenci para veremez');
select throws_ok($$select public.grant_permission('c0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001', 'market_yonet')$$,
  '42501', null, 'öğrenci kendine izin veremez');

-- Erişim anahtarındaki rol iddiası veritabanı rolünü değiştirmez; yetki profildeki rolden gelir.
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"service_role"}';
select throws_ok($$select public.admin_grant('c0000000-0000-4000-8000-000000000001', 'SP', 1000, 'sahte rol')$$,
  '42501', null, 'sahte service_role iddiası işe yaramaz');

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000003","role":"authenticated"}';
select lives_ok($$select public.admin_grant('c0000000-0000-4000-8000-000000000001', 'SP', 10, 'deneme ödülü')$$,
  'süperadmin para verebilir');

set local role anon;
select throws_ok($$select count(*) from public.profiles$$, '42501', null, 'anonim profil okuyamaz');
select throws_ok($$select public.place_wager(gen_random_uuid(), gen_random_uuid(), 10)$$, '42501', null,
  'anonim yatırım yapamaz');

select * from finish();
rollback;
