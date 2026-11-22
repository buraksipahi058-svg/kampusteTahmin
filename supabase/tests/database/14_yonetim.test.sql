-- Adım 13 testleri: istek bekçisi (silinmiş / yasaklı hesap), yasaklama, hakem ihtarını sıfırlama,
-- açık resmi bahiste oran değiştirme. Tek transaction içinde çalışır ve sonunda geri alınır.
--
-- A okulu: Ali (öğrenci), Veli (öğrenci, 2 ihtarlı), Mod (yetkili: A'da kullanici_bahsi_denetle, resmi_bahis_ac),
-- Süper (süperadmin), Silik (silinmiş). B okulu: Zeynep (öğrenci), Bmod (yetkili: B'de kullanici_bahsi_denetle).

begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
alter default privileges for role postgres grant execute on functions to public;

select plan(31);

-- ---------------------------------------------------------------------------
-- Hazırlık
-- ---------------------------------------------------------------------------

update public.economy_settings set signup_bonus_sp = 1000;
insert into public.clusters (id, name, type) values
  ('a0000000-0000-4000-8000-000000000001', 'Test Üniversitesi A', 'school'),
  ('b0000000-0000-4000-8000-000000000001', 'Test Üniversitesi B', 'school');

create function pg_temp.uid(p_n integer) returns uuid language sql immutable as
  $$ select ('c0000000-0000-4000-8000-' || lpad(p_n::text, 12, '0'))::uuid $$;
create function pg_temp.as_user(p_n integer) returns void language sql as
  $$ select set_config('request.jwt.claims', json_build_object('sub', pg_temp.uid(p_n), 'role', 'authenticated')::text, true) $$;

insert into auth.users (id, email, aud, role)
select pg_temp.uid(n), 'kisi' || n || '@test.local', 'authenticated', 'authenticated' from generate_series(1, 7) n;
insert into auth.sessions (id, user_id) values (gen_random_uuid(), pg_temp.uid(1));

do $$
declare r record;
begin
  for r in select * from (values
    (1, 'Ali', 'a0000000-0000-4000-8000-000000000001'::uuid), (2, 'Veli', 'a0000000-0000-4000-8000-000000000001'),
    (3, 'Mod', 'a0000000-0000-4000-8000-000000000001'), (4, 'Süper', 'a0000000-0000-4000-8000-000000000001'),
    (5, 'Silik', 'a0000000-0000-4000-8000-000000000001'), (6, 'Zeynep', 'b0000000-0000-4000-8000-000000000001'),
    (7, 'Bmod', 'b0000000-0000-4000-8000-000000000001')
  ) as v(n, ad, okul) loop
    perform pg_temp.as_user(r.n);
    perform public.create_profile(r.ad, 'Test', r.okul);
  end loop;
end $$;

update public.profile_private
set student_email = 'kisi' || right(user_id::text, 1) || '@ogr.test.edu.tr', student_email_verified_at = now()
where user_id in (select pg_temp.uid(n) from generate_series(1, 7) n);
update public.profiles set role = 'yetkili' where id in (pg_temp.uid(3), pg_temp.uid(7));
update public.profiles set role = 'superadmin' where id = pg_temp.uid(4);
update public.profiles set referee_strikes = 2 where id = pg_temp.uid(2);
update public.profiles set deleted_at = now() where id = pg_temp.uid(5);
insert into public.permissions (user_id, cluster_id, permission_key, granted_by) values
  (pg_temp.uid(3), 'a0000000-0000-4000-8000-000000000001', 'kullanici_bahsi_denetle', pg_temp.uid(4)),
  (pg_temp.uid(3), 'a0000000-0000-4000-8000-000000000001', 'resmi_bahis_ac', pg_temp.uid(4)),
  (pg_temp.uid(7), 'b0000000-0000-4000-8000-000000000001', 'kullanici_bahsi_denetle', pg_temp.uid(4));

create temp table t (k text primary key, id uuid not null) on commit drop;
grant select on t to authenticated;
create function pg_temp.id(p_k text) returns uuid language sql stable as $$ select id from t where k = p_k $$;

-- Mod'un açık sabit oranlı resmi bahsi (2,00 / 1,50) ve havuzlu (oransız) bir resmi bahis; Ali yatırır.
do $$
declare v_bet uuid;
begin
  v_bet := private.create_bet(pg_temp.uid(3), 'a0000000-0000-4000-8000-000000000001', 'ssp_official', 'school',
                              'Oranlı bahis', null, array['A', 'B'], now() + interval '1 hour', null, 1, null,
                              array[2.00, 1.50]::numeric[]);
  insert into t values ('fixed', v_bet);
  perform private.post_ledger(pg_temp.uid(1), 'SSP', 100, 'admin_grant', null, null, pg_temp.uid(4), 'test için SSP');
  perform private.stake_wager(v_bet, (select id from public.bet_options where bet_id = v_bet and position = 1), pg_temp.uid(1), 10);
  update public.wagers set odds = 2.00 where bet_id = v_bet;
  v_bet := private.create_bet(pg_temp.uid(3), 'a0000000-0000-4000-8000-000000000001', 'ssp_official', 'school',
                              'Havuzlu bahis', null, array['A', 'B'], now() + interval '1 hour');
  insert into t values ('pool', v_bet);
end $$;

-- ---------------------------------------------------------------------------
-- İstek bekçisi
-- ---------------------------------------------------------------------------

select is(
  (select setconfig::text from pg_db_role_setting where setrole = 'authenticator'::regrole) like '%pgrst.db_pre_request=guard.check_request%',
  true, 'PostgREST her istekten önce bekçiyi çağırır'
);
select is(
  (select array_agg(p.proname::text) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'guard'),
  array['check_request'], 'guard şemasında yalnızca bekçi var'
);

set local role anon;
select lives_ok($$select guard.check_request()$$, 'anonim istek bekçiden geçer (yetkiyi tablolar denetler)');

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';
select lives_ok($$select guard.check_request()$$, 'normal hesap bekçiden geçer');
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000005","role":"authenticated"}';
select throws_ok($$select guard.check_request()$$, 'KB025', null, 'silinmiş hesabın isteği reddedilir');

-- ---------------------------------------------------------------------------
-- Yasaklama
-- ---------------------------------------------------------------------------

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000003","role":"authenticated"}';
select throws_ok($$select public.set_user_ban('c0000000-0000-4000-8000-000000000001', true, 'kural ihlali')$$,
  '42501', null, 'süperadmin olmayan yasaklayamaz');

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000004","role":"authenticated"}';
select throws_ok($$select public.set_user_ban('c0000000-0000-4000-8000-000000000001', true, 'x')$$,
  '23514', null, 'yasak gerekçe ister');
select throws_ok($$select public.set_user_ban('c0000000-0000-4000-8000-000000000004', true, 'kendim')$$,
  '42501', null, 'süperadmin kendini yasaklayamaz');
select throws_ok($$select public.set_user_ban('c0000000-0000-4000-8000-000000000005', true, 'silinmiş')$$,
  'P0002', null, 'silinmiş hesap yasaklanamaz');
select lives_ok($$select public.set_user_ban('c0000000-0000-4000-8000-000000000001', true, 'Hile şüphesi')$$,
  'süperadmin yasaklar');

set local role postgres;
select is(
  (select row(p.banned_at is not null, (a.details ->> 'reason'))::text
   from public.profiles p join public.admin_audit_log a on a.target_user_id = p.id and a.action = 'user_ban'
   where p.id = pg_temp.uid(1)),
  '(t,"Hile şüphesi")', 'profilde yasak zamanı, gerekçe denetim kaydında'
);
select ok(
  (select u.banned_until > now() + interval '99 years' from auth.users u where u.id = pg_temp.uid(1))
  and not exists (select 1 from auth.sessions s where s.user_id = pg_temp.uid(1)),
  'Auth engeli konur, oturumlar kapanır'
);
select is((select count(*)::int from public.admin_audit_log where action = 'user_ban' and target_user_id = pg_temp.uid(1)),
  1, 'yasak denetim kaydına yazılır');

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';
select throws_ok($$select guard.check_request()$$, 'KB025', null, 'yasaklı hesabın isteği reddedilir');

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000004","role":"authenticated"}';
select lives_ok($$select public.set_user_ban('c0000000-0000-4000-8000-000000000001', false)$$, 'süperadmin yasağı kaldırır');
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';
select lives_ok($$select guard.check_request()$$, 'yasağı kalkan hesap yeniden geçer');

set local role postgres;
select ok(
  (select p.banned_at is null and u.banned_until is null
   from public.profiles p join auth.users u on u.id = p.id where p.id = pg_temp.uid(1)),
  'yasak kalkınca profil ve Auth temizlenir'
);

-- ---------------------------------------------------------------------------
-- Hakem ihtarını sıfırlama
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';
select throws_ok($$select public.reset_referee_strikes('c0000000-0000-4000-8000-000000000002', 'af')$$,
  '42501', null, 'öğrenci ihtar sıfırlayamaz');
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000007","role":"authenticated"}';
select throws_ok($$select public.reset_referee_strikes('c0000000-0000-4000-8000-000000000002', 'af diliyorum')$$,
  'P0002', null, 'başka okulun moderatörü kişiyi bulamaz');
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000003","role":"authenticated"}';
select throws_ok($$select public.reset_referee_strikes('c0000000-0000-4000-8000-000000000002', 'x')$$,
  '23514', null, 'ihtar sıfırlama gerekçe ister');
select lives_ok($$select public.reset_referee_strikes('c0000000-0000-4000-8000-000000000002', 'Yanlış ihtar düzeltildi')$$,
  'okulun moderatörü ihtarı sıfırlar');

set local role postgres;
select is(
  (select row(p.referee_strikes, (a.details ->> 'previous')::int)::text
   from public.profiles p join public.admin_audit_log a on a.target_user_id = p.id and a.action = 'referee_strikes_reset'
   where p.id = pg_temp.uid(2)),
  '(0,2)', 'ihtar sıfırlandı, eski sayı denetim kaydında'
);

-- ---------------------------------------------------------------------------
-- Oran değiştirme
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';
select throws_ok($$select public.update_official_bet_odds(pg_temp.id('fixed'), array[3.00, 1.20])$$,
  '42501', null, 'öğrenci oran değiştiremez');
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000003","role":"authenticated"}';
select throws_ok($$select public.update_official_bet_odds(pg_temp.id('fixed'), array[3.00])$$,
  '23514', null, 'her seçeneğe bir oran gerekir');
select throws_ok($$select public.update_official_bet_odds(pg_temp.id('fixed'), array[30.00, 1.20])$$,
  '23514', null, 'oran 20,00''yi aşamaz');
select throws_ok($$select public.update_official_bet_odds(pg_temp.id('pool'), array[3.00, 1.20])$$,
  '23514', null, 'havuzlu bahiste oran yok');
select lives_ok($$select public.update_official_bet_odds(pg_temp.id('fixed'), array[3.00, 1.20])$$,
  'açan okulun yetkilisi oranı değiştirir');

set local role postgres;
select is(
  (select array_agg(o.odds order by o.position) from public.bet_options o where o.bet_id = pg_temp.id('fixed')),
  array[3.00, 1.20]::numeric[], 'yeni oranlar yazıldı'
);
select is((select w.odds from public.wagers w where w.bet_id = pg_temp.id('fixed')), 2.00::numeric,
  'yapılmış yatırım eski oranıyla kalır');

do $$ begin perform private.lock_bet(pg_temp.id('fixed')); end $$;
set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000003","role":"authenticated"}';
select throws_ok($$select public.update_official_bet_odds(pg_temp.id('fixed'), array[2.50, 1.30])$$,
  'KB003', null, 'kapanmış bahiste oran değişmez');

set local role postgres;
select is((select count(*)::int from private.balance_mismatches()), 0, 'bakiye önbelleği ledger ile tutarlı');

select * from finish();
rollback;
