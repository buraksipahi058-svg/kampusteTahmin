-- Adım 15 testleri: okul arkadaşı arama (meydan okuma / hakem seçimi), bitmiş düellonun cevapları.
-- Tek transaction içinde çalışır ve sonunda geri alınır.
--
-- A okulu: Ali, Veli, Can (3 ihtarlı: hakem olamaz), Yeni (okul maili doğrulanmamış), Silik (silinmiş),
-- Yasak (yasaklı). B okulu: Zeynep. Profilsiz: 9. Hepsinin soyadı "Test".

begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
alter default privileges for role postgres grant execute on functions to public;

select plan(17);

-- ---------------------------------------------------------------------------
-- Hazırlık
-- ---------------------------------------------------------------------------

update public.economy_settings
set signup_bonus_sp = 1000, trivia_question_count = 5, trivia_seconds_per_question = 15,
    duel_max_stake_sp = 100, duel_accept_hours = 24, duel_play_hours = 24, referee_strike_limit = 3;
insert into public.clusters (id, name, type) values
  ('a0000000-0000-4000-8000-000000000001', 'Test Üniversitesi A', 'school'),
  ('b0000000-0000-4000-8000-000000000001', 'Test Üniversitesi B', 'school');

create function pg_temp.uid(p_n integer) returns uuid language sql immutable as
  $$ select ('c0000000-0000-4000-8000-' || lpad(p_n::text, 12, '0'))::uuid $$;
create function pg_temp.as_user(p_n integer) returns void language sql as
  $$ select set_config('request.jwt.claims', json_build_object('sub', pg_temp.uid(p_n), 'role', 'authenticated')::text, true) $$;

insert into auth.users (id, email, aud, role)
select pg_temp.uid(n), 'kisi' || n || '@test.local', 'authenticated', 'authenticated' from generate_series(1, 9) n;

do $$
declare r record;
begin
  for r in select * from (values
    (1, 'Ali', 'a0000000-0000-4000-8000-000000000001'::uuid), (2, 'Veli', 'a0000000-0000-4000-8000-000000000001'),
    (3, 'Can', 'a0000000-0000-4000-8000-000000000001'), (4, 'Yeni', 'a0000000-0000-4000-8000-000000000001'),
    (5, 'Silik', 'a0000000-0000-4000-8000-000000000001'), (6, 'Yasak', 'a0000000-0000-4000-8000-000000000001'),
    (7, 'Zeynep', 'b0000000-0000-4000-8000-000000000001')
  ) as v(n, ad, okul) loop
    perform pg_temp.as_user(r.n);
    perform public.create_profile(r.ad, 'Test', r.okul);
  end loop;
end $$;

update public.profile_private
set student_email = 'kisi' || right(user_id::text, 1) || '@ogr.test.edu.tr', student_email_verified_at = now()
where user_id in (select pg_temp.uid(n) from generate_series(1, 7) n) and user_id <> pg_temp.uid(4);
update public.profiles set referee_strikes = 3 where id = pg_temp.uid(3);
update public.profiles set deleted_at = now() where id = pg_temp.uid(5);
update public.profiles set banned_at = now() where id = pg_temp.uid(6);

create temp table t (k text primary key, id uuid not null) on commit drop;
grant all on t to authenticated;
create function pg_temp.id(p_k text) returns uuid language sql stable as $$ select id from t where k = p_k $$;

-- Kişinin cevapları: doğru şıklar ya da hepsi yanlış (doğru şıktan bir sonraki).
create function pg_temp.answers(p_bet uuid, p_correct boolean) returns smallint[] language sql stable as $$
  select array_agg((case when p_correct then q.correct_index else (q.correct_index + 1) % cardinality(q.options) end)::smallint
                   order by u.ord)
  from public.trivia_duels d
  cross join unnest(d.question_ids) with ordinality as u(question_id, ord)
  join public.trivia_questions q on q.id = u.question_id
  where d.bet_id = p_bet
$$;
-- Doğru şıkları öğrenci göremez: cevaplar postgres olarak hazırlanıp burada tutulur.
create temp table ans (k text primary key, a smallint[] not null) on commit drop;
grant select on ans to authenticated;
create function pg_temp.ans(p_k text) returns smallint[] language sql stable as $$ select a from ans where k = p_k $$;

-- ---------------------------------------------------------------------------
-- Okul arkadaşı arama
-- ---------------------------------------------------------------------------

set local role anon;
select throws_ok($$select * from public.search_schoolmates('Test')$$, '42501', null, 'anonim kişi arayamaz');

set local role authenticated;
select pg_temp.as_user(9);
select throws_ok($$select * from public.search_schoolmates('Test')$$, 'P0002', null, 'profili olmayan arayamaz');

select pg_temp.as_user(1);
select throws_ok($$select * from public.search_schoolmates(' a ')$$, '23514', null, 'arama en az 2 karakter');
select is((select array_agg(first_name order by first_name) from public.search_schoolmates('test')),
          array['Can', 'Veli'],
          'yalnızca okulun doğrulanmış öğrencileri: kendisi, doğrulanmamış, silinmiş, yasaklı, başka okul gelmez');
select is((select array_agg(first_name || ':' || can_referee order by first_name) from public.search_schoolmates('test')),
          array['Can:false', 'Veli:true'], 'ihtar sınırındaki kişi hakem olamaz diye işaretlenir');
select is((select array_agg(first_name) from public.search_schoolmates('VEL')), array['Veli'], 'büyük / küçük harf fark etmez');
select is((select count(*)::int from public.search_schoolmates('i_')), 0, 'LIKE özel karakterleri düz aranır');

-- ---------------------------------------------------------------------------
-- Düello cevapları
-- ---------------------------------------------------------------------------

-- 1. düello: Ali, Veli'ye meydan okur; ikisi de oynar (Ali hepsini bilir, Veli hiçbirini).
select pg_temp.as_user(1);
insert into t values ('d1', public.create_trivia_duel(10, pg_temp.uid(2)));
select pg_temp.as_user(2);
select public.accept_trivia_duel(pg_temp.id('d1'));
set local role postgres;
insert into ans values ('d1-ok', pg_temp.answers(pg_temp.id('d1'), true)), ('d1-bad', pg_temp.answers(pg_temp.id('d1'), false));
set local role authenticated;
select pg_temp.as_user(1);
select count(*) from public.start_trivia_duel(pg_temp.id('d1'));
select * from public.submit_trivia_answers(pg_temp.id('d1'), pg_temp.ans('d1-ok'));
select throws_ok($$select * from public.trivia_duel_review(pg_temp.id('d1'))$$, 'P0002', null,
                 'düello bitmeden cevaplar görünmez');

select pg_temp.as_user(2);
select count(*) from public.start_trivia_duel(pg_temp.id('d1'));
select * from public.submit_trivia_answers(pg_temp.id('d1'), pg_temp.ans('d1-bad'));

select pg_temp.as_user(1);
select is((select count(*)::int from public.trivia_duel_review(pg_temp.id('d1'))), 5,
          'düello bitince oyuncu 5 soruyu görür');
select is((select bool_and(my_answer = correct_index) from public.trivia_duel_review(pg_temp.id('d1'))), true,
          'kendi cevapları ve doğru şıklar gelir');
select is((select bool_and(opponent_answer <> correct_index) from public.trivia_duel_review(pg_temp.id('d1'))), true,
          'rakibin cevapları da gelir');

select pg_temp.as_user(3);
select throws_ok($$select * from public.trivia_duel_review(pg_temp.id('d1'))$$, 'P0002', null,
                 'düellonun oyuncusu olmayan cevapları göremez');
set local role anon;
select throws_ok($$select * from public.trivia_duel_review(pg_temp.id('d1'))$$, '42501', null, 'anonim göremez');

-- 2. düello: Veli kabul eder ama oynamaz; oynama süresi dolunca sonuçlanır.
set local role authenticated;
select pg_temp.as_user(1);
insert into t values ('d2', public.create_trivia_duel(10));
select pg_temp.as_user(2);
select public.accept_trivia_duel(pg_temp.id('d2'));
set local role postgres;
insert into ans values ('d2-ok', pg_temp.answers(pg_temp.id('d2'), true));
set local role authenticated;
select pg_temp.as_user(1);
select count(*) from public.start_trivia_duel(pg_temp.id('d2'));
select * from public.submit_trivia_answers(pg_temp.id('d2'), pg_temp.ans('d2-ok'));
set local role postgres;
update public.trivia_duels set play_deadline = now() - interval '1 minute' where bet_id = pg_temp.id('d2');
select private.process_trivia_duels();
set local role authenticated;

select pg_temp.as_user(2);
select throws_ok($$select * from public.trivia_duel_review(pg_temp.id('d2'))$$, 'P0002', null,
                 'hiç oynamayan oyuncu cevapları göremez (soruları görmedi)');
select pg_temp.as_user(1);
select is((select count(*)::int from public.trivia_duel_review(pg_temp.id('d2')) where opponent_answer is null), 5,
          'oynayan oyuncu görür; oynamayan rakibin cevabı boş');

set local role postgres;
select is((select status::text from public.bets where id = pg_temp.id('d1')), 'settled', 'ilk düello sonuçlandı');
select is((select count(*)::int from private.balance_mismatches()), 0, 'bakiye önbelleği ledger ile tutarlı');

select * from finish();
rollback;
