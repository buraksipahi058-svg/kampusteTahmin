-- Adım 14 testleri: sıralamadan çıkma, veri dışa aktarma, istek sınırı (bekçi).
-- Tek transaction içinde çalışır ve sonunda geri alınır.
--
-- A okulu: Ali, Veli, Can (öğrenci), Süper (süperadmin), Silik (silinmiş).
-- Süper'in havuzlu resmi bahsi: Ali ve Can "A"ya, Veli "B"ye 10'ar SSP; "A" kazanır (Ali ve Can +5 SSP).

begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
alter default privileges for role postgres grant execute on functions to public;

select plan(36);

-- ---------------------------------------------------------------------------
-- Hazırlık
-- ---------------------------------------------------------------------------

update public.economy_settings set signup_bonus_sp = 1000;
insert into public.clusters (id, name, type) values
  ('a0000000-0000-4000-8000-000000000001', 'Test Üniversitesi A', 'school');

create function pg_temp.uid(p_n integer) returns uuid language sql immutable as
  $$ select ('c0000000-0000-4000-8000-' || lpad(p_n::text, 12, '0'))::uuid $$;
create function pg_temp.as_user(p_n integer) returns void language sql as
  $$ select set_config('request.jwt.claims', json_build_object('sub', pg_temp.uid(p_n), 'role', 'authenticated')::text, true) $$;

insert into auth.users (id, email, aud, role)
select pg_temp.uid(n), 'kisi' || n || '@test.local', 'authenticated', 'authenticated' from generate_series(1, 5) n;

do $$
declare r record;
begin
  for r in select * from (values (1, 'Ali'), (2, 'Veli'), (3, 'Can'), (4, 'Süper'), (5, 'Silik')) as v(n, ad) loop
    perform pg_temp.as_user(r.n);
    perform public.create_profile(r.ad, 'Test', 'a0000000-0000-4000-8000-000000000001');
  end loop;
end $$;

update public.profile_private
set student_email = 'kisi' || right(user_id::text, 1) || '@ogr.test.edu.tr', student_email_verified_at = now()
where user_id in (select pg_temp.uid(n) from generate_series(1, 4) n);
update public.profiles set role = 'superadmin' where id = pg_temp.uid(4);
update public.profiles set deleted_at = now() where id = pg_temp.uid(5);

create temp table t (k text primary key, id uuid not null) on commit drop;
grant select on t to authenticated;
create function pg_temp.id(p_k text) returns uuid language sql stable as $$ select id from t where k = p_k $$;

do $$
declare
  v_bet uuid;
  v_a uuid;
  v_b uuid;
begin
  v_bet := private.create_bet(pg_temp.uid(4), 'a0000000-0000-4000-8000-000000000001', 'ssp_official', 'school',
                              'Havuzlu bahis', null, array['A', 'B'], now() + interval '1 hour');
  insert into t values ('bet', v_bet);
  select id into v_a from public.bet_options where bet_id = v_bet and position = 1;
  select id into v_b from public.bet_options where bet_id = v_bet and position = 2;
  perform private.post_ledger(pg_temp.uid(n), 'SSP', 100, 'admin_grant', null, null, pg_temp.uid(4), 'test için SSP')
  from generate_series(1, 3) n;
  perform private.stake_wager(v_bet, v_a, pg_temp.uid(1), 10);
  perform private.stake_wager(v_bet, v_a, pg_temp.uid(3), 10);
  perform private.stake_wager(v_bet, v_b, pg_temp.uid(2), 10);
  perform private.lock_bet(v_bet);
  perform private.settle_bet(v_bet, v_a, pg_temp.uid(4));
end $$;

insert into public.admin_audit_log (actor_id, action, target_user_id, details)
values (pg_temp.uid(4), 'test_kaydi', pg_temp.uid(1), '{"not": "Ali hakkında kayıt"}');

select private.store_leaderboard('a0000000-0000-4000-8000-000000000001', 'all_time', null, '-infinity', 'infinity');

-- Sıralama "Ad:sıra" listesi (çağıranın gözünden).
create function pg_temp.board(p_metric text) returns text[] language sql as $$
  select coalesce(array_agg(l.first_name || ':' || l.rank order by l.rank, l.first_name), '{}')
  from public.get_leaderboard(p_metric::public.leaderboard_metric, 'all_time') l
$$;

-- ---------------------------------------------------------------------------
-- Sıralamadan çıkma
-- ---------------------------------------------------------------------------

select is((select leaderboard_hidden from public.profile_private where user_id = pg_temp.uid(1)), false,
          'varsayılan: kişi sıralamada görünür');

set local role anon;
select throws_ok($$select public.set_leaderboard_hidden(true)$$, '42501', null, 'anonim sıralama tercihini değiştiremez');

set local role authenticated;
select pg_temp.as_user(3);
select is(pg_temp.board('ssp_profit'), array['Ali:1', 'Can:1'], 'gizlemeden önce Can, Ali''yi sıralamada görür');

select pg_temp.as_user(5);
select throws_ok($$select public.set_leaderboard_hidden(true)$$, 'P0002', null, 'silinmiş hesap tercih değiştiremez');

select pg_temp.as_user(1);
select throws_ok($$select public.set_leaderboard_hidden(null)$$, '23514', null, 'boş tercih reddedilir');
select lives_ok($$select public.set_leaderboard_hidden(true)$$, 'kişi sıralamadan çıkar');
select is((select leaderboard_hidden from public.profile_private where user_id = pg_temp.uid(1)), true,
          'kişi kendi tercihini görür');

select pg_temp.as_user(3);
select is((select count(*)::int from public.profile_private where user_id = pg_temp.uid(1)), 0,
          'okul arkadaşı başkasının sıralama tercihini göremez');
select is((select count(*)::int from public.leaderboard_snapshots where user_id = pg_temp.uid(1)), 0,
          'gizlenince sıralama satırları hemen silinir');
select is(pg_temp.board('ssp_profit'), array['Can:1'], 'gizlenen kişi sıralamada görünmez');

set local role postgres;
select private.store_leaderboard('a0000000-0000-4000-8000-000000000001', 'all_time', null, '-infinity', 'infinity');
select is((select count(*)::int from public.leaderboard_snapshots where user_id = pg_temp.uid(1)), 0,
          'yeniden hesaplamada gizli kişi sıralamaya girmez');
select is((select rank from public.leaderboard_snapshots where user_id = pg_temp.uid(3) and metric = 'best_streak'
           and period = 'all_time'), 1, 'gizli kişi yüzünden sırada boşluk olmaz');

-- Eşzamanlı hesaplama gizlenmeden hemen önce satır yazmış olsa da okuma göstermez.
insert into public.leaderboard_snapshots (school_id, period, period_start, metric, user_id, rank, value, sample, computed_at)
values ('a0000000-0000-4000-8000-000000000001', 'all_time', null, 'ssp_profit', pg_temp.uid(1), 1, 5, 1, now());
set local role authenticated;
select pg_temp.as_user(3);
select is(pg_temp.board('ssp_profit'), array['Can:1'], 'gizli kişinin artakalan satırı da gösterilmez');
select pg_temp.as_user(1);
select is((select count(*)::int from public.get_leaderboard('ssp_profit', 'all_time') where is_me), 0,
          'gizli kişi kendini de sıralamada görmez');

set local role postgres;
delete from public.leaderboard_snapshots where user_id = pg_temp.uid(1);
set local role authenticated;
select pg_temp.as_user(1);
select lives_ok($$select public.set_leaderboard_hidden(false)$$, 'kişi sıralamaya geri döner');
set local role postgres;
select private.store_leaderboard('a0000000-0000-4000-8000-000000000001', 'all_time', null, '-infinity', 'infinity');
set local role authenticated;
select pg_temp.as_user(3);
select is(pg_temp.board('ssp_profit'), array['Ali:1', 'Can:1'], 'geri dönen kişi sonraki hesaplamada görünür');

-- ---------------------------------------------------------------------------
-- Veri dışa aktarma
-- ---------------------------------------------------------------------------

set local role anon;
select throws_ok($$select public.export_my_data()$$, '42501', null, 'anonim veri dışa aktaramaz');

set local role authenticated;
select pg_temp.as_user(5);
select throws_ok($$select public.export_my_data()$$, 'P0002', null, 'silinmiş hesap veri dışa aktaramaz');

select pg_temp.as_user(1);
set local role postgres;
create temp table ex on commit drop as select public.export_my_data() as d;
select is((select d ->> 'format' from ex), 'kampusbet-verilerim-2', 'kişi verilerini dışa aktarır');
select is((select d -> 'account' ->> 'email' from ex), 'kisi1@test.local', 'hesap e-postası dahil');
select is((select d -> 'profile' ->> 'first_name' from ex), 'Ali', 'profil dahil');
select is((select jsonb_array_length(d -> 'ledger') from ex),
          (select count(*)::int from public.ledger_entries where user_id = pg_temp.uid(1)), 'bütün ledger satırları dahil');
select is((select d -> 'wagers' -> 0 ->> 'option' from ex), 'A', 'yatırım, bahis ve seçenekle dahil');
select is((select jsonb_array_length(d -> 'wagers') from ex), 1, 'yalnızca kişinin kendi yatırımı');
select is((select d -> 'admin_records_about_me' -> 0 ->> 'action' from ex), 'test_kaydi', 'yetkilinin kişi hakkındaki kaydı dahil');
select is((select d::text like '%' || pg_temp.uid(4) || '%' or d::text like '%kisi3@test.local%'
             or d::text like '%Veli%' from ex), false,
          'başkasının kimliği, e-postası ya da adı yok');

-- ---------------------------------------------------------------------------
-- İstek sınırı
-- ---------------------------------------------------------------------------

set local role postgres;
select is((select api_write_limit_per_minute from public.economy_settings where id), 60, 'varsayılan sınır dakikada 60');
update public.economy_settings set api_write_limit_per_minute = 10;
delete from private.request_log;

set local role authenticated;
select pg_temp.as_user(1);
select lives_ok($$select guard.check_request() from generate_series(1, 10)$$, 'sınıra kadar yazma isteği geçer');
select throws_ok($$select guard.check_request()$$, 'KB026', null, 'sınırı aşan yazma isteği reddedilir');
select pg_temp.as_user(3);
select lives_ok($$select guard.check_request()$$, 'sınır kişi başına: başkası etkilenmez');

select set_config('request.jwt.claims', '', true);
set local role anon;
select lives_ok($$select guard.check_request()$$, 'anonim istek sayılmaz');
set local role authenticated;
select throws_ok($$select count(*) from private.request_log$$, '42501', null, 'istemci sayaç tablosunu okuyamaz');

set local role postgres;
select is((select count(*)::int from private.request_log where user_id = pg_temp.uid(1)), 10, 'yalnızca geçen istekler sayılır');
update private.request_log set at = now() - interval '2 minutes' where user_id = pg_temp.uid(1);
set local role authenticated;
select pg_temp.as_user(1);
select lives_ok($$select guard.check_request()$$, 'bir dakikadan eski istekler sayılmaz');

set local role postgres;
update private.request_log set at = now() - interval '10 minutes' where user_id = pg_temp.uid(1);
select private.prune_request_log();
select is((select count(*)::int from private.request_log where user_id = pg_temp.uid(1)), 0, 'eski sayaç satırları temizlenir');

-- Sınırı doldur, sonra salt okunur transaction'da (GET, stable RPC) bekçi saymaz ve reddetmez.
insert into private.request_log (user_id) select pg_temp.uid(1) from generate_series(1, 10);
set transaction read only;
set local role authenticated;
select pg_temp.as_user(1);
select lives_ok($$select guard.check_request()$$, 'okuma isteği sayılmaz ve sınırda da geçer');

set local role postgres;
select * from finish();
rollback;
