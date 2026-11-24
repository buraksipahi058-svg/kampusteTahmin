-- Güvenlik kontrolü 3 ve ipucu testleri: kampüs kelimesi (sözlük dışı cevap artık bedava denenemez, bitmiş oyunda
-- sözlük sorgusu yok, günde tek oyun, bugün genel kelime varken okula kelime girilemez, kelimeyi gören ödül almaz,
-- kelimeyi gireni öğrenci görmez, ipucu 3. tahminden sonra / oyun bitince). Sonunda geri alınır.
--
-- A okulu: Ali, Veli (öğrenci), Mod (yetkili: kelime_yonet), Süper, Can (önce kelime_yonet, sonra öğrenci).
-- B okulu: Zeynep (öğrenci).

begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
alter default privileges for role postgres grant execute on functions to public;

select plan(27);

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
select pg_temp.uid(n), 'kisi' || n || '@test.local', 'authenticated', 'authenticated' from generate_series(1, 7) n;
do $$
declare r record;
begin
  for r in select * from (values
    (1, 'Ali', 'a0000000-0000-4000-8000-000000000001'::uuid), (2, 'Veli', 'a0000000-0000-4000-8000-000000000001'),
    (4, 'Mod', 'a0000000-0000-4000-8000-000000000001'), (5, 'Süper', 'a0000000-0000-4000-8000-000000000001'),
    (6, 'Can', 'a0000000-0000-4000-8000-000000000001'), (7, 'Zeynep', 'b0000000-0000-4000-8000-000000000001')
  ) as v(n, ad, okul) loop
    perform pg_temp.as_user(r.n);
    perform public.create_profile(r.ad, 'Test', r.okul);
  end loop;
end $$;
update public.profile_private
set student_email = 'kisi' || right(user_id::text, 1) || '@ogr.test.edu.tr', student_email_verified_at = now()
where user_id in (select pg_temp.uid(n) from generate_series(1, 7) n);
update public.profiles set role = 'yetkili' where id in (pg_temp.uid(4), pg_temp.uid(6));
update public.profiles set role = 'superadmin' where id = pg_temp.uid(5);
insert into public.permissions (user_id, cluster_id, permission_key, granted_by) values
  (pg_temp.uid(4), 'a0000000-0000-4000-8000-000000000001', 'kelime_yonet', pg_temp.uid(5)),
  (pg_temp.uid(6), 'a0000000-0000-4000-8000-000000000001', 'kelime_yonet', pg_temp.uid(5));

insert into private.word_dictionary (word) values ('KALEM'), ('KİTAP'), ('DEFTER'), ('KANTİN'), ('KAPLAN')
on conflict do nothing;
delete from private.word_dictionary where word in ('NOTLAR', 'ABCÇDE');

create temp table t (k text primary key, id uuid not null) on commit drop;
grant all on t to authenticated;
create function pg_temp.id(p_k text) returns uuid language sql stable as $$ select id from t where k = p_k $$;
create temp table d on commit drop as select private.word_today() as today;
grant select on d to authenticated;
create function pg_temp.today() returns date language sql stable as $$ select today from d $$;

-- ---------------------------------------------------------------------------
-- Yönetim: ipucu, sözlüğe ekleme, gören kaydı, bugün kuralı
-- ---------------------------------------------------------------------------

set local role authenticated;
select pg_temp.as_user(4);
select lives_ok($$insert into t select 'a', public.save_word_puzzle(null, 'a0000000-0000-4000-8000-000000000001',
                                                                  pg_temp.today(), 'notlar', ' Sınavdan sonra açıklanır ')$$,
  'yetkili sözlükte olmayan kelimeyi ipucuyla girer');
select throws_ok($$select public.save_word_puzzle(null, 'a0000000-0000-4000-8000-000000000001', pg_temp.today() + 1,
                                                 'kalem', repeat('uzun ', 40))$$,
  '23514', null, '140 karakterden uzun ipucu olmaz');
select pg_temp.as_user(5);
select lives_ok($$insert into t select 'genel', public.save_word_puzzle(null, null, pg_temp.today(), 'kitap',
                                                                      'Kütüphanede çok var')$$,
  'süperadmin bugünün genel kelimesini girer');
select throws_ok($$select public.save_word_puzzle(null, 'b0000000-0000-4000-8000-000000000001', pg_temp.today(), 'kalem')$$,
  'KB041', null, 'bugün genel kelime oynanırken okula bugün için kelime girilemez');
select lives_ok($$select public.save_word_puzzle(null, 'b0000000-0000-4000-8000-000000000001', pg_temp.today() + 1, 'kalem')$$,
  'okula yarın için kelime girilir');

set local role postgres;
select ok(exists (select 1 from private.word_dictionary where word = 'NOTLAR'), 'girilen kelime sözlüğe eklenir');
select ok(exists (select 1 from private.word_puzzle_viewers where puzzle_id = pg_temp.id('a') and user_id = pg_temp.uid(4)),
  'kelimeyi giren gören olarak kaydedilir');
select is((select details ->> 'hint' from public.admin_audit_log
           where action = 'word_puzzle_save' and details ->> 'puzzle_id' = pg_temp.id('a')::text),
  'Sınavdan sonra açıklanır', 'ipucu kırpılıp denetim kaydına yazılır');

-- Can listeyi görür, sonra izni kalkar (öğrenciye döner).
set local role authenticated;
select pg_temp.as_user(6);
select is((select hint from public.list_word_puzzles() where id = pg_temp.id('a')), 'Sınavdan sonra açıklanır',
  'yönetim listesi ipucunu da gösterir');
set local role postgres;
delete from public.permissions where user_id = pg_temp.uid(6);
update public.profiles set role = 'student' where id = pg_temp.uid(6);

set local role authenticated;
select pg_temp.as_user(1);
select throws_ok($$select created_by from public.word_puzzles$$, '42501', null, 'kelimeyi gireni öğrenci göremez');
select is((select count(*)::int from public.word_puzzles where puzzle_date = pg_temp.today()), 2,
  'öğrenci bulmacanın günü ve uzunluğunu görür (okulunki ve genel)');

-- ---------------------------------------------------------------------------
-- Oyun: ipucu, sözlük, bitmiş oyun
-- ---------------------------------------------------------------------------

select is((select (has_hint, hint_after, hint)::text from public.my_word_puzzle()), (true, 3, null::text)::text,
  'ipucu var ama başta gösterilmez');
select throws_ok(format('select * from public.submit_word_guess(%L, %L)', pg_temp.id('a'), 'abcçde'), 'KB038', null,
  'sözlük dışı tahmin reddedilir (cevap hakkında bilgi vermez)');
select is((select hint from public.submit_word_guess(pg_temp.id('a'), 'defter')), null, '1. tahminde ipucu yok');
select is((select hint from public.submit_word_guess(pg_temp.id('a'), 'kantin')), null, '2. tahminde ipucu yok');
select is((select hint from public.submit_word_guess(pg_temp.id('a'), 'kaplan')), 'Sınavdan sonra açıklanır',
  '3. tahminden sonra ipucu gelir');
select is((select hint from public.my_word_puzzle()), 'Sınavdan sonra açıklanır', 'ipucu sonra da görünür');
select is((select (solved, reward_sp)::text from public.submit_word_guess(pg_temp.id('a'), 'NOTLAR')), (true, 40)::text,
  'sözlüğe eklenen cevap normal tahmin gibi bulunur (4. tahmin ödülü)');
select throws_ok(format('select * from public.submit_word_guess(%L, %L)', pg_temp.id('a'), 'abcçde'), 'KB039', null,
  'bitmiş oyunda tahmin denetlenmez (sözlük sorgusu yok)');

select pg_temp.as_user(2);
select is((select (solved, reward_sp, hint)::text from public.submit_word_guess(pg_temp.id('a'), 'notlar')),
  (true, 60, 'Sınavdan sonra açıklanır')::text, 'ilk tahminde bulana oyun bitince ipucu da gösterilir');

select pg_temp.as_user(6);
select is((select can_earn from public.my_word_puzzle()), false, 'listede kelimeyi görmüş, izni kalksa da ödül alamaz');
select is((select reward_sp from public.submit_word_guess(pg_temp.id('a'), 'notlar')), 0,
  'kelimeyi görmüş olan bulunca ödül almaz');

-- Günde tek oyun: Zeynep genel kelimeyi bitirir; sonradan (kuralı atlayarak) okuluna bugün kelime eklense de açılmaz.
select pg_temp.as_user(7);
select is((select reward_sp from public.submit_word_guess(pg_temp.id('genel'), 'kitap')), 60, 'okulunda kelime yoksa genel oynanır');
set local role postgres;
with p as (
  insert into public.word_puzzles (school_id, puzzle_date, word_length, created_by)
  values ('b0000000-0000-4000-8000-000000000001', pg_temp.today(), 5, pg_temp.uid(5)) returning id
)
insert into t select 'b_sonradan', id from p;
insert into private.word_answers (puzzle_id, word) values (pg_temp.id('b_sonradan'), 'KALEM');
set local role authenticated;
select pg_temp.as_user(7);
select is((select puzzle_id from public.my_word_puzzle()), pg_temp.id('genel'),
  'o gün başlanan bulmaca kalır (sonradan eklenen ikinci oyun açmaz)');
select throws_ok(format('select * from public.submit_word_guess(%L, %L)', pg_temp.id('b_sonradan'), 'kalem'), 'P0002', null,
  'aynı gün ikinci bulmacaya tahmin olmaz (ikinci ödül yok)');

select pg_temp.as_user(5);
select is((select (players, solvers, first_try)::text from public.list_word_puzzles() where id = pg_temp.id('a')),
  (3, 3, 2)::text, 'yönetim listesi oynayan, bulan ve ilk tahminde bulan sayısını gösterir');

set local role postgres;
select throws_ok($$update public.economy_settings set word_hint_after = 6$$, '23514', null,
  'ipucu hak sayısından önce açılmalı');

select * from finish();
rollback;
