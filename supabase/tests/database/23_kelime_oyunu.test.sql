-- Adım 19 testleri: kampüs kelimesi (yönetim izinleri, gizli kelime, günün bulmacası, işaretleme, sözlük, ödül,
-- yöneten ödül almaz, RLS, dışa aktarma). Tek transaction içinde çalışır ve sonunda geri alınır.
--
-- A okulu: Ali, Veli, Can (öğrenci, doğrulanmış), Yeni (doğrulanmamış), Mod (yetkili: kelime_yonet), Süper.
-- B okulu: Zeynep (öğrenci), Bmod (yetkili: B'de kelime_yonet).

begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
alter default privileges for role postgres grant execute on functions to public;

select plan(49);

-- ---------------------------------------------------------------------------
-- Hazırlık
-- ---------------------------------------------------------------------------

update public.economy_settings set signup_bonus_sp = 1000;
-- Buluttaki gerçek kelimeler testi etkilemesin (bugünün genel kelimesi gibi): geri alınan işlemde 10 yıl geriye.
update public.word_puzzles set puzzle_date = puzzle_date - 3650;
insert into public.clusters (id, name, type) values
  ('a0000000-0000-4000-8000-000000000001', 'Test Üniversitesi A', 'school'),
  ('b0000000-0000-4000-8000-000000000001', 'Test Üniversitesi B', 'school');

create function pg_temp.uid(p_n integer) returns uuid language sql immutable as
  $$ select ('c0000000-0000-4000-8000-' || lpad(p_n::text, 12, '0'))::uuid $$;
create function pg_temp.as_user(p_n integer) returns void language sql as
  $$ select set_config('request.jwt.claims', json_build_object('sub', pg_temp.uid(p_n), 'role', 'authenticated')::text, true) $$;

insert into auth.users (id, email, aud, role)
select pg_temp.uid(n), 'kisi' || n || '@test.local', 'authenticated', 'authenticated' from generate_series(1, 8) n;
do $$
declare r record;
begin
  for r in select * from (values
    (1, 'Ali', 'a0000000-0000-4000-8000-000000000001'::uuid), (2, 'Veli', 'a0000000-0000-4000-8000-000000000001'),
    (3, 'Yeni', 'a0000000-0000-4000-8000-000000000001'), (4, 'Mod', 'a0000000-0000-4000-8000-000000000001'),
    (5, 'Süper', 'a0000000-0000-4000-8000-000000000001'), (6, 'Can', 'a0000000-0000-4000-8000-000000000001'),
    (7, 'Zeynep', 'b0000000-0000-4000-8000-000000000001'), (8, 'Bmod', 'b0000000-0000-4000-8000-000000000001')
  ) as v(n, ad, okul) loop
    perform pg_temp.as_user(r.n);
    perform public.create_profile(r.ad, 'Test', r.okul);
  end loop;
end $$;
update public.profile_private
set student_email = 'kisi' || right(user_id::text, 1) || '@ogr.test.edu.tr', student_email_verified_at = now()
where user_id in (select pg_temp.uid(n) from generate_series(1, 8) n) and user_id <> pg_temp.uid(3);
update public.profiles set role = 'yetkili' where id in (pg_temp.uid(4), pg_temp.uid(8));
update public.profiles set role = 'superadmin' where id = pg_temp.uid(5);
insert into public.permissions (user_id, cluster_id, permission_key, granted_by) values
  (pg_temp.uid(4), 'a0000000-0000-4000-8000-000000000001', 'kelime_yonet', pg_temp.uid(5)),
  (pg_temp.uid(8), 'b0000000-0000-4000-8000-000000000001', 'kelime_yonet', pg_temp.uid(5));

-- Testin kullandığı kelimeler sözlükte olsun (gerçek sözlük de yüklü; geri alınır).
insert into private.word_dictionary (word) values ('KALEM'), ('MELEK'), ('LAMBA'), ('KİTAP'), ('DEFTER'), ('SINAV')
on conflict do nothing;
delete from private.word_dictionary where word = 'ABCDE';

create temp table t (k text primary key, id uuid not null) on commit drop;
grant all on t to authenticated;
create function pg_temp.id(p_k text) returns uuid language sql stable as $$ select id from t where k = p_k $$;
-- Bugün (İstanbul) postgres olarak hesaplanıp tutulur: pg_temp.today() istemciye kapalı.
create temp table d on commit drop as select private.word_today() as today;
grant select on d to authenticated;
create function pg_temp.today() returns date language sql stable as $$ select today from d $$;

-- Dünün bulmacası (postgres olarak doğrudan).
with p as (
  insert into public.word_puzzles (school_id, puzzle_date, word_length, created_by)
  values ('a0000000-0000-4000-8000-000000000001', pg_temp.today() - 1, 5, pg_temp.uid(4)) returning id
)
insert into t select 'dun', id from p;
insert into private.word_answers values (pg_temp.id('dun'), 'SINAV');

-- ---------------------------------------------------------------------------
-- Yönetim
-- ---------------------------------------------------------------------------

set local role anon;
select throws_ok($$select public.save_word_puzzle(null, 'a0000000-0000-4000-8000-000000000001', current_date + 1, 'kalem')$$,
  '42501', null, 'anonim kelime giremez');
set local role authenticated;
select pg_temp.as_user(1);
select throws_ok($$select public.save_word_puzzle(null, 'a0000000-0000-4000-8000-000000000001', pg_temp.today(), 'kalem')$$,
  '42501', null, 'öğrenci kelime giremez');
select pg_temp.as_user(8);
select throws_ok($$select public.save_word_puzzle(null, 'a0000000-0000-4000-8000-000000000001', pg_temp.today(), 'kalem')$$,
  '42501', null, 'başka okulun yetkilisi giremez');
select pg_temp.as_user(4);
select throws_ok($$select public.save_word_puzzle(null, null, pg_temp.today(), 'kitap')$$,
  '42501', null, 'yetkili bütün okullara (genel) kelime giremez');
select lives_ok($$insert into t select 'a_bugun', public.save_word_puzzle(null, 'a0000000-0000-4000-8000-000000000001',
                                                                        pg_temp.today(), ' kaleM ')$$,
  'yetkili kendi okuluna bugünün kelimesini girer');
select throws_ok($$select public.save_word_puzzle(null, 'a0000000-0000-4000-8000-000000000001', pg_temp.today(), 'melek')$$,
  '23505', null, 'aynı güne ikinci kelime girilemez');
select throws_ok($$select public.save_word_puzzle(null, 'a0000000-0000-4000-8000-000000000001', pg_temp.today() - 1, 'melek')$$,
  '23514', null, 'geçmiş güne kelime girilemez');
select throws_ok($$select public.save_word_puzzle(null, 'a0000000-0000-4000-8000-000000000001', pg_temp.today() + 2, 'abc')$$,
  '23514', null, '4 harften kısa kelime olmaz');
select throws_ok($$select public.save_word_puzzle(null, 'a0000000-0000-4000-8000-000000000001', pg_temp.today() + 2, 'kal3m')$$,
  '23514', null, 'harf dışı karakter olmaz');
select lives_ok($$insert into t select 'a_yarin', public.save_word_puzzle(null, 'a0000000-0000-4000-8000-000000000001',
                                                                        pg_temp.today() + 1, 'defter')$$,
  'yetkili ileri tarihli kelime girer');
select pg_temp.as_user(5);
select lives_ok($$insert into t select 'genel', public.save_word_puzzle(null, null, pg_temp.today(), 'kitap')$$,
  'süperadmin bütün okullara bugünün kelimesini girer');

set local role postgres;
select is((select word from private.word_answers where puzzle_id = pg_temp.id('a_bugun')), 'KALEM',
  'kelime Türkçe büyük harfe çevrilip boşluksuz saklanır');
select is((select word_length from public.word_puzzles where id = pg_temp.id('a_bugun')), 5, 'uzunluk saklanır');
select is((select count(*)::int from public.admin_audit_log where action = 'word_puzzle_save' and actor_id = pg_temp.uid(4)), 2,
  'kelime girişi denetim kaydına yazılır');

set local role authenticated;
select pg_temp.as_user(4);
select is((select array_agg(word order by puzzle_date) from public.list_word_puzzles()), array['SINAV', 'KALEM', 'DEFTER'],
  'yetkili kendi okulunun kelimelerini görür, genel kelimeyi görmez');
select pg_temp.as_user(5);
select is((select count(*)::int from public.list_word_puzzles()), 4, 'süperadmin hepsini görür');
select pg_temp.as_user(1);
select throws_ok($$select * from public.list_word_puzzles()$$, '42501', null, 'öğrenci kelime listesini göremez');
select throws_ok($$select word from private.word_answers$$, '42501', null, 'kelimeler istemciye kapalı');
select throws_ok($$select word from private.word_dictionary$$, '42501', null, 'sözlük tablosu istemciye kapalı');
select is((select count(*)::int from public.word_puzzles where puzzle_date > pg_temp.today() - 30), 3,
  'öğrenci okulunun bugüne kadarki bulmacalarını görür (ileri tarihliyi görmez; genel bugün de görünür)');
select pg_temp.as_user(4);
select is((select count(*)::int from public.word_puzzles where school_id is not null), 3, 'yetkili ileri tarihliyi de görür');
select pg_temp.as_user(7);
select is((select count(*)::int from public.word_puzzles where school_id = 'a0000000-0000-4000-8000-000000000001'), 0,
  'başka okulun bulmacası görünmez');
select pg_temp.as_user(8);
select throws_ok(format('select public.delete_word_puzzle(%L)', pg_temp.id('a_yarin')), 'P0002', null,
  'başka okulun yetkilisi silemez');

-- ---------------------------------------------------------------------------
-- Oyun
-- ---------------------------------------------------------------------------

set local role anon;
select throws_ok($$select * from public.my_word_puzzle()$$, '42501', null, 'anonim oynayamaz');
set local role authenticated;
select pg_temp.as_user(3);
select throws_ok($$select * from public.my_word_puzzle()$$, 'KB002', null, 'okul maili doğrulanmamış oynayamaz');
select pg_temp.as_user(1);
select is((select (puzzle_id, word_length, answer, can_earn, rewards_sp[3])::text from public.my_word_puzzle()),
  (pg_temp.id('a_bugun'), 5, null::text, true, 40)::text,
  'öğrenci okulunun bugünkü bulmacasını görür; kelime dönmez');
select pg_temp.as_user(7);
select is((select puzzle_id from public.my_word_puzzle()), pg_temp.id('genel'),
  'okula özel kelime yoksa genel kelime oynanır');
select pg_temp.as_user(1);
select throws_ok(format('select * from public.submit_word_guess(%L, %L)', pg_temp.id('genel'), 'kitap'), 'P0002', null,
  'okulunun kendi kelimesi varken genel kelimeye tahmin olmaz');
select throws_ok(format('select * from public.submit_word_guess(%L, %L)', pg_temp.id('dun'), 'sınav'), 'P0002', null,
  'dünün kelimesine tahmin olmaz');
select throws_ok(format('select * from public.submit_word_guess(%L, %L)', pg_temp.id('a_bugun'), 'defter'), 'KB037', null,
  'yanlış uzunlukta tahmin reddedilir');
select throws_ok(format('select * from public.submit_word_guess(%L, %L)', pg_temp.id('a_bugun'), 'abcde'), 'KB038', null,
  'sözlükte olmayan tahmin reddedilir (hak gitmez)');
select is((select marks from public.submit_word_guess(pg_temp.id('a_bugun'), 'melek')), '10221',
  'işaretler: doğru yer 2, başka yerde var 1, yok 0');
select is((select marks from public.submit_word_guess(pg_temp.id('a_bugun'), 'LAMBA')), '12100',
  'tekrarlanan harf kelimedeki sayısı kadar işaretlenir');
select is((select (solved, finished, guesses_left, reward_sp, reward_xp, answer)::text
           from public.submit_word_guess(pg_temp.id('a_bugun'), 'kalem')),
  (true, true, 3, 40, 15, 'KALEM')::text, 'üçüncü tahminde bulan 3. sıranın ödülünü alır, kelime döner');
select throws_ok(format('select * from public.submit_word_guess(%L, %L)', pg_temp.id('a_bugun'), 'kalem'), 'KB039', null,
  'biten oyuna tahmin olmaz');
select is((select (cardinality(guesses), finished, answer)::text from public.my_word_puzzle()),
  (3, true, 'KALEM')::text, 'oyun bitince durum ve kelime döner');

set local role postgres;
select is((select amount from public.ledger_entries where user_id = pg_temp.uid(1) and reason = 'word_reward'), 40::bigint,
  'ödül ledger''a SP olarak yazılır');
select is((select amount from public.xp_events where user_id = pg_temp.uid(1) and reason = 'word_puzzle'), 15,
  'XP ledger kaydından tetiklenir');

set local role authenticated;
select pg_temp.as_user(2);
do $$
begin
  for i in 1 .. 5 loop
    perform * from public.submit_word_guess(pg_temp.id('a_bugun'), 'melek');
  end loop;
end $$;
select is((select (solved, finished, reward_sp, answer)::text from public.submit_word_guess(pg_temp.id('a_bugun'), 'lamba')),
  (false, true, 0, 'KALEM')::text, 'altı hakta bulamayan ödül almaz, kelimeyi görür');
select pg_temp.as_user(4);
select is((select (reward_sp, can_earn)::text from public.my_word_puzzle()), (0, false)::text,
  'kelimeyi yöneten oynayabilir ama ödül alamayacağı bilinir');
select is((select reward_sp from public.submit_word_guess(pg_temp.id('a_bugun'), 'kalem')), 0,
  'kelimeyi yöneten bulunca ödül almaz');
select throws_ok(format('select public.save_word_puzzle(%L, %L, %L, %L)', pg_temp.id('a_bugun'),
                        'a0000000-0000-4000-8000-000000000001', pg_temp.today(), 'melek'), 'KB040', null,
  'oynanmaya başlanan kelime değiştirilemez');
select throws_ok(format('select public.delete_word_puzzle(%L)', pg_temp.id('a_bugun')), 'KB040', null,
  'oynanmaya başlanan kelime silinemez');
select lives_ok(format('select public.save_word_puzzle(%L, %L, %L, %L)', pg_temp.id('a_yarin'),
                       'a0000000-0000-4000-8000-000000000001', pg_temp.today() + 1, 'lamba'),
  'ileri tarihli kelime düzenlenir');
select lives_ok(format('select public.delete_word_puzzle(%L)', pg_temp.id('a_yarin')), 'ileri tarihli kelime silinir');

select pg_temp.as_user(6);
select is((select count(*)::int from public.word_attempts), 0, 'başkasının tahminleri görünmez');
select throws_ok($$insert into public.word_attempts (puzzle_id, user_id) values (gen_random_uuid(), auth.uid())$$,
  '42501', null, 'deneme doğrudan yazılamaz');
select pg_temp.as_user(1);
select is((select (d -> 'word_puzzles' -> 0 ->> 'solved') || ':' || (d ->> 'format') from (select public.export_my_data() as d) x),
  'true:kampusbet-verilerim-2', 'verilerim kelime oyunu denemelerini de içerir');

set local role postgres;
select throws_ok($$update public.economy_settings set word_reward_sp = '{10,20}'$$, '23514', null,
  'ödül dizisi hak sayısı kadar olmalı');

select * from finish();
rollback;
