-- Adım 16 eksiği: başarım ekleme / düzenleme (`save_achievement`, yalnızca süperadmin).
-- Tek transaction içinde çalışır ve sonunda geri alınır.
--
-- A okulu: Ali (öğrenci, okul maili doğrulanmış), Mod (yetkili: gorev_yonet), Süper (süperadmin).

begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
alter default privileges for role postgres grant execute on functions to public;

select plan(15);

-- ---------------------------------------------------------------------------
-- Hazırlık
-- ---------------------------------------------------------------------------

update public.economy_settings set signup_bonus_sp = 1000;
insert into public.clusters (id, name, type) values ('a0000000-0000-4000-8000-000000000001', 'Test Üniversitesi A', 'school');

create function pg_temp.uid(p_n integer) returns uuid language sql immutable as
  $$ select ('c0000000-0000-4000-8000-' || lpad(p_n::text, 12, '0'))::uuid $$;
create function pg_temp.as_user(p_n integer) returns void language sql as
  $$ select set_config('request.jwt.claims', json_build_object('sub', pg_temp.uid(p_n), 'role', 'authenticated')::text, true) $$;

insert into auth.users (id, email, aud, role)
select pg_temp.uid(n), 'kisi' || n || '@test.local', 'authenticated', 'authenticated' from generate_series(1, 3) n;
do $$
declare r record;
begin
  for r in select * from (values (1, 'Ali'), (2, 'Mod'), (3, 'Süper')) as v(n, ad) loop
    perform pg_temp.as_user(r.n);
    perform public.create_profile(r.ad, 'Test', 'a0000000-0000-4000-8000-000000000001');
  end loop;
end $$;
update public.profile_private
set student_email = 'kisi' || right(user_id::text, 1) || '@ogr.test.edu.tr', student_email_verified_at = now()
where user_id = pg_temp.uid(1);
update public.profiles set role = 'yetkili' where id = pg_temp.uid(2);
update public.profiles set role = 'superadmin' where id = pg_temp.uid(3);
insert into public.permissions (user_id, cluster_id, permission_key, granted_by)
values (pg_temp.uid(2), 'a0000000-0000-4000-8000-000000000001', 'gorev_yonet', pg_temp.uid(3));

create temp table t (k text primary key, id uuid not null) on commit drop;
grant all on t to authenticated;
create function pg_temp.id(p_k text) returns uuid language sql stable as $$ select id from t where k = p_k $$;

-- Yeni başarım çağrısı: anahtar, ölçüt, hedef, kademe, ödül değiştirilebilir.
create function pg_temp.save(p_id uuid, p_key text, p_metric text default 'verified', p_target integer default 1,
                             p_tier smallint default 1, p_title text default 'Deneme Başarımı',
                             p_active boolean default true) returns uuid language sql as $$
  select public.save_achievement(p_id, p_key, 'progress', p_title, 'Deneme açıklaması.', '🧪', p_metric, p_target,
                                 p_tier, 25, 5, false, 999, p_active)
$$;

-- ---------------------------------------------------------------------------
-- Yetki
-- ---------------------------------------------------------------------------

set local role anon;
select throws_ok($$select pg_temp.save(null, 'deneme_anonim')$$, '42501', null, 'anonim başarım ekleyemez');
set local role authenticated;
select pg_temp.as_user(1);
select throws_ok($$select pg_temp.save(null, 'deneme_ogrenci')$$, '42501', null, 'öğrenci başarım ekleyemez');
select pg_temp.as_user(2);
select throws_ok($$select pg_temp.save(null, 'deneme_yetkili')$$, '42501', null, 'görev yöneten yetkili de başarım ekleyemez');

-- ---------------------------------------------------------------------------
-- Ekleme
-- ---------------------------------------------------------------------------

select pg_temp.as_user(3);
select lives_ok($$insert into t values ('yeni', pg_temp.save(null, 'deneme_yeni'))$$, 'süperadmin başarım ekler');
select is((select key || '/' || reward_sp || '/' || active from public.achievements where id = pg_temp.id('yeni')),
          'deneme_yeni/25/true', 'yeni başarım katalogda');
set local role postgres;
select is((select count(*)::int from public.admin_audit_log
           where action = 'achievement_save' and actor_id = pg_temp.uid(3) and details ->> 'key' = 'deneme_yeni'
             and (details ->> 'new')::boolean), 1, 'denetim kaydına yazılır');
set local role authenticated;
select pg_temp.as_user(3);
select throws_ok($$select pg_temp.save(null, 'deneme_olcut', 'bilinmeyen_olcut')$$, '23514', null, 'bilinmeyen ölçüt reddedilir');
select throws_ok($$select pg_temp.save(null, 'deneme_kademe', 'verified', 1, 4::smallint)$$, '23514', null, 'kademe 1-3 dışında reddedilir');
select throws_ok($$select pg_temp.save(null, 'deneme_yeni')$$, '23505', null, 'aynı anahtar iki kez eklenemez');
select throws_ok($$select public.save_achievement(null, 'deneme_bos', 'progress', 'Boş', 'Açıklama.', '🧪', 'verified',
                                                  null, 1::smallint, 10, 0, false, 1, true)$$,
                 '23514', null, 'boş alan reddedilir');

-- ---------------------------------------------------------------------------
-- Düzenleme ve kapatma
-- ---------------------------------------------------------------------------

select lives_ok($$select pg_temp.save(pg_temp.id('yeni'), 'deneme_yeni', 'verified', 1, 2::smallint, 'Yeni Ad')$$,
                'süperadmin başarımı düzenler');
select throws_ok($$select pg_temp.save(pg_temp.id('yeni'), 'baska_anahtar')$$, '23514', null, 'anahtar değiştirilemez');
select throws_ok($$select pg_temp.save('00000000-0000-4000-8000-000000000000', 'deneme_yok')$$, 'P0002', null,
                 'olmayan başarım düzenlenemez');

-- Ali yeni başarımı kazanıp ödülünü alır; sonra başarım kapatılır: kazanılmış olarak kalır, kazanmayana görünmez.
select pg_temp.as_user(1);
select * from public.claim_achievement('deneme_yeni');
select pg_temp.as_user(3);
select pg_temp.save(pg_temp.id('yeni'), 'deneme_yeni', 'verified', 1, 2::smallint, 'Yeni Ad', false);
select pg_temp.as_user(1);
select is((select title || '/' || (unlocked_at is not null) from public.my_achievements() where key = 'deneme_yeni'),
          'Yeni Ad/true', 'kapatılan başarım kazanan kişide kazanılmış kalır');
select pg_temp.as_user(2);
select is((select count(*)::int from public.my_achievements() where key = 'deneme_yeni'), 0,
          'kapatılan başarım kazanmamış kişiye görünmez');

select * from finish();
rollback;
