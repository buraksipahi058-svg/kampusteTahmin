-- Adım 11 hesap silme testleri: engeller (sonuçlanmamış bahis, hakemlik, süperadmin), anonimleştirme,
-- Supabase Auth temizliği, kalan kayıtların bütünlüğü, silinen kişinin sıralama ve okul özetinden çıkması.
-- Tek transaction içinde çalışır ve sonunda geri alınır.
--
-- A okulu: Ali (silinecek; yetkili: analitik_gor), Veli (açık bahiste yatırımı var), Hakem (açık sosyal
-- bahsin hakemi), Süper (süperadmin), Can (okul arkadaşı). Profilsiz: girişi var, profili yok.

begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
-- Yeni fonksiyonlar varsayılan olarak kimseye açık değil (Adım 11); bu testin pg_temp yardımcıları
-- kullanıcı rolüyle de çağrılır. Transaction sonunda geri alınır.
alter default privileges for role postgres grant execute on functions to public;

select plan(29);

-- ---------------------------------------------------------------------------
-- Hazırlık
-- ---------------------------------------------------------------------------

update public.economy_settings set signup_bonus_sp = 1000, leaderboard_min_predictions_week = 1, leaderboard_min_predictions_all = 1;

insert into public.clusters (id, name, type) values ('a0000000-0000-4000-8000-000000000001', 'Test Üniversitesi A', 'school');

create function pg_temp.uid(p_n integer) returns uuid language sql immutable as
  $$ select ('c0000000-0000-4000-8000-' || lpad(p_n::text, 12, '0'))::uuid $$;

insert into auth.users (id, email, aud, role)
select pg_temp.uid(n), 'kisi' || n || '@test.local', 'authenticated', 'authenticated' from generate_series(1, 6) n;
insert into auth.identities (provider_id, user_id, identity_data, provider)
values (pg_temp.uid(1)::text, pg_temp.uid(1), '{"email":"kisi1@test.local"}', 'email');
insert into auth.sessions (id, user_id) values (gen_random_uuid(), pg_temp.uid(1));

do $$
declare r record;
begin
  for r in select * from (values (1, 'Ali'), (2, 'Veli'), (3, 'Hakem'), (4, 'Süper'), (5, 'Can')) as v(n, ad) loop
    perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.uid(r.n), 'role', 'authenticated')::text, true);
    perform public.create_profile(r.ad, 'Test', 'a0000000-0000-4000-8000-000000000001', 'Bilgisayar');
  end loop;
end $$;

update public.profile_private
set student_email = 'kisi' || right(user_id::text, 1) || '@ogr.test.edu.tr', student_email_verified_at = now()
where user_id in (select pg_temp.uid(n) from generate_series(1, 5) n);
update public.profiles set role = 'yetkili' where id = pg_temp.uid(1);
update public.profiles set role = 'superadmin' where id = pg_temp.uid(4);
insert into public.permissions (user_id, cluster_id, permission_key, granted_by)
values (pg_temp.uid(1), 'a0000000-0000-4000-8000-000000000001', 'analitik_gor', pg_temp.uid(4));
insert into private.dev_outbox (to_email, subject, body) values ('kisi1@ogr.test.edu.tr', 'Kod', '123456');
insert into public.market_items (id, school_id, name, category, icon, price, currency)
values ('40000000-0000-4000-8000-0000000000aa', 'a0000000-0000-4000-8000-000000000001', 'Deneme rozeti', 'badge', '⭐', 10, 'SP');
insert into public.user_inventory (user_id, item_id, category, equipped, price_paid, currency)
values (pg_temp.uid(1), '40000000-0000-4000-8000-0000000000aa', 'badge', true, 10, 'SP');

create temp table t (k text primary key, id uuid not null) on commit drop;
grant select on t to authenticated;

do $$
declare
  v_bet uuid;
begin
  -- Ali'nin kazandığı, sonuçlanmış bahis.
  v_bet := private.create_bet(pg_temp.uid(5), 'a0000000-0000-4000-8000-000000000001', 'sp_minigame', 'school',
                              'Biten bahis', null, array['Bir', 'İki'], now() + interval '1 hour');
  perform private.stake_wager(v_bet, (select id from public.bet_options where bet_id = v_bet and position = 1), pg_temp.uid(1), 20);
  perform private.stake_wager(v_bet, (select id from public.bet_options where bet_id = v_bet and position = 2), pg_temp.uid(5), 20);
  perform private.lock_bet(v_bet);
  perform private.settle_bet(v_bet, (select id from public.bet_options where bet_id = v_bet and position = 1), null);

  -- Veli'nin yatırımı olan açık bahis.
  v_bet := private.create_bet(pg_temp.uid(5), 'a0000000-0000-4000-8000-000000000001', 'sp_minigame', 'school',
                              'Açık bahis', null, array['Bir', 'İki'], now() + interval '1 hour');
  perform private.stake_wager(v_bet, (select id from public.bet_options where bet_id = v_bet and position = 1), pg_temp.uid(2), 10);

  -- Ali'nin açıp iptal edilen düellosu: başlık "Trivia düellosu: Ali".
  insert into public.trivia_questions (school_id, question, options, correct_index)
  select 'a0000000-0000-4000-8000-000000000001', 'Soru ' || n || '?', array['A', 'B'], 0 from generate_series(1, 10) n;
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.uid(1), 'role', 'authenticated')::text, true);
  v_bet := public.create_trivia_duel(10);
  insert into t values ('duel', v_bet);
  perform private.cancel_bet(v_bet, 'Test iptali', null);

  -- Hakem'in hakemi olduğu açık sosyal bahis.
  v_bet := private.create_bet(pg_temp.uid(3), 'a0000000-0000-4000-8000-000000000001', 'sp_social', 'school',
                              'Hakemli bahis', null, array['Evet', 'Hayır'], now() + interval '1 hour', pg_temp.uid(3));
  perform private.refresh_leaderboards();
end $$;

create temp table onceki on commit drop as
select (select count(*) from public.ledger_entries where user_id = pg_temp.uid(1)) as ledger,
       (select count(*) from public.leaderboard_snapshots where user_id = pg_temp.uid(1)) as board;
grant select on onceki to authenticated;

-- ---------------------------------------------------------------------------
-- Engeller
-- ---------------------------------------------------------------------------

set local role anon;
select throws_ok($$select public.delete_my_account()$$, '42501', null, 'anonim hesap silemez');

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000006","role":"authenticated"}';
select throws_ok($$select public.delete_my_account()$$, 'P0002', null, 'profili olmayan hesap silemez');

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000004","role":"authenticated"}';
select throws_ok($$select public.delete_my_account()$$, '42501', null, 'süperadmin hesabı uygulamadan silinmez');

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000002","role":"authenticated"}';
select throws_ok($$select public.delete_my_account()$$, 'KB024', null, 'sonuçlanmamış bahsi olan silemez');

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000003","role":"authenticated"}';
select throws_ok($$select public.delete_my_account()$$, 'KB024', null, 'açık bahsin hakemi silemez');

-- ---------------------------------------------------------------------------
-- Silme ve anonimleştirme
-- ---------------------------------------------------------------------------

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';
select ok((select board from onceki) > 0, 'silinmeden önce kişi sıralamada');
select lives_ok($$select public.delete_my_account()$$, 'sonuçlanmamış işi olmayan kişi hesabını siler');
select throws_ok($$select public.delete_my_account()$$, 'P0002', null, 'silinmiş hesap ikinci kez silinemez');

-- Silinen kişinin elindeki anahtar süresi dolana kadar: adını geri yazamaz, yatırım yapamaz.
update public.profiles set first_name = 'Ali' where id = 'c0000000-0000-4000-8000-000000000001';
select throws_ok($$select public.place_wager(gen_random_uuid(), gen_random_uuid(), 10)$$, 'KB002', null,
  'silinen kişi yatırım yapamaz (okul maili silindi)');
select throws_ok($$select * from public.request_student_email_code('kisi1@ogr.test.edu.tr')$$, 'P0002', null,
  'silinen kişi okul maili kodu isteyemez');
select throws_ok($$select public.create_trivia_duel(10)$$, 'KB002', null, 'silinen kişi düello açamaz');

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000005","role":"authenticated"}';
select is(
  (select first_name || ' ' || last_name from public.profiles where id = 'c0000000-0000-4000-8000-000000000001'),
  'Silinmiş Kullanıcı', 'okul arkadaşı silinen kişiyi "Silinmiş Kullanıcı" görür (ad geri yazılamadı)'
);

set local role postgres;
select is(
  (select row(p.department, p.role, p.deleted_at is not null)::text from public.profiles p where p.id = pg_temp.uid(1)),
  '(,student,t)', 'bölüm silindi, rol öğrenci, silinme zamanı yazıldı'
);
select is(
  (select row(pp.student_email, pp.student_email_verified_at)::text from public.profile_private pp where pp.user_id = pg_temp.uid(1)),
  '(,)', 'okul maili ve doğrulama silindi'
);
select is((select count(*)::int from private.dev_outbox where to_email = 'kisi1@ogr.test.edu.tr'), 0,
  'geliştirme kutusundaki mailleri silindi');
select is((select count(*)::int from public.permissions where user_id = pg_temp.uid(1)), 0, 'izinleri silindi');
select is((select count(*)::int from public.user_clusters where user_id = pg_temp.uid(1)), 0, 'üyelikleri silindi');
select is(
  (select row(count(*), count(*) filter (where equipped))::text from public.user_inventory where user_id = pg_temp.uid(1)),
  '(1,0)', 'envanter kalır ama hiçbir ürün kuşanılı değil'
);
select is((select count(*)::int from public.leaderboard_snapshots where user_id = pg_temp.uid(1)), 0,
  'sıralama satırları silindi');
select is(
  (select row(u.email, u.phone, u.encrypted_password, u.banned_until > now() + interval '99 years', u.deleted_at is not null)::text
   from auth.users u where u.id = pg_temp.uid(1)),
  '(,,"",t,t)', 'Auth: e-posta, telefon, şifre silindi; hesap 100 yıl engellendi'
);
select is((select title from public.bets where id = (select id from t where k = 'duel')), 'Trivia düellosu: Silinmiş Kullanıcı',
  'düello başlığındaki ad silindi');
select is(
  (select count(*)::int from auth.identities where user_id = pg_temp.uid(1))
    + (select count(*)::int from auth.sessions where user_id = pg_temp.uid(1)),
  0, 'Auth: kimlikler ve oturumlar silindi'
);
select is(
  (select row(count(*), max((a.details ->> 'permissions_removed')::int))::text
   from public.admin_audit_log a where a.action = 'account_delete' and a.target_user_id = pg_temp.uid(1)),
  '(1,1)', 'silme denetim kaydına yazıldı'
);
select is((select count(*) from public.ledger_entries where user_id = pg_temp.uid(1)), (select ledger from onceki),
  'ledger kayıtları kalır');
select is((select count(*)::int from private.balance_mismatches()), 0, 'bakiye önbelleği ledger ile tutarlı');

do $$ begin perform private.refresh_leaderboards(); end $$;
select is((select count(*)::int from public.leaderboard_snapshots where user_id = pg_temp.uid(1)), 0,
  'yeniden hesaplanan sıralamaya silinen kişi girmez');

-- Eşzamanlı hesaplamada yazılmış gibi: silinen kişinin satırı olsa da sıralamada görünmez.
insert into public.leaderboard_snapshots (school_id, period, period_start, metric, user_id, rank, value, sample, computed_at)
values ('a0000000-0000-4000-8000-000000000001', 'all_time', null, 'sp_profit', pg_temp.uid(1), 1, 999, 1, now());
set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000005","role":"authenticated"}';
select is((select count(*)::int from public.get_leaderboard('sp_profit', 'all_time') l where l.user_id = 'c0000000-0000-4000-8000-000000000001'),
  0, 'silinen kişi sıralamada gösterilmez');

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000004","role":"authenticated"}';
select is((select s.members from public.school_stats('a0000000-0000-4000-8000-000000000001') s), 4,
  'okul özetinde üye sayısı silineni saymaz');

set local role postgres;
select lives_ok(
  $$update public.profile_private set student_email = 'kisi1@ogr.test.edu.tr' where user_id = 'c0000000-0000-4000-8000-000000000005'$$,
  'silinen kişinin okul maili başka hesaba bağlanabilir'
);

select * from finish();
rollback;
