-- Adım 8 testleri: trivia düellosu (soru yönetimi, meydan okuma, oynama, puanlama, süreler).
-- Tek transaction içinde çalışır ve sonunda geri alınır. Aynı transaction'da now() sabit olduğundan
-- iki oyuncunun süresi eşittir; süre aşımı started_at geri çekilerek denenir.
--
-- A okulu: Ali, Veli, Can (öğrenci), Mod (yetkili: trivia_yonet), Yeni (doğrulanmamış), Su (süperadmin).
-- B okulu: Zeynep. 6 genel soru + B okuluna özel 2 soru. Herkes 1000 SP ile başlar. Düelloda 5 soru.

begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(45);

-- ---------------------------------------------------------------------------
-- Hazırlık
-- ---------------------------------------------------------------------------

update public.economy_settings
set signup_bonus_sp = 1000, trivia_question_count = 5, trivia_seconds_per_question = 15,
    duel_max_stake_sp = 100, duel_accept_hours = 24, duel_play_hours = 24;

insert into public.clusters (id, name, type) values
  ('a0000000-0000-4000-8000-000000000001', 'Test Üniversitesi A', 'school'),
  ('b0000000-0000-4000-8000-000000000001', 'Test Üniversitesi B', 'school');

insert into auth.users (id, email, aud, role)
select id, id::text || '@test.local', 'authenticated', 'authenticated'
from unnest(array[
  'c0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000002',
  'c0000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000004',
  'c0000000-0000-4000-8000-000000000005', 'c0000000-0000-4000-8000-000000000006',
  'c0000000-0000-4000-8000-000000000007'
]::uuid[]) as id;

do $$
declare r record;
begin
  for r in select * from (values
    ('c0000000-0000-4000-8000-000000000001'::uuid, 'Ali', 'a0000000-0000-4000-8000-000000000001'::uuid),
    ('c0000000-0000-4000-8000-000000000002', 'Veli', 'a0000000-0000-4000-8000-000000000001'),
    ('c0000000-0000-4000-8000-000000000003', 'Can', 'a0000000-0000-4000-8000-000000000001'),
    ('c0000000-0000-4000-8000-000000000004', 'Mod', 'a0000000-0000-4000-8000-000000000001'),
    ('c0000000-0000-4000-8000-000000000005', 'Yeni', 'a0000000-0000-4000-8000-000000000001'),
    ('c0000000-0000-4000-8000-000000000006', 'Zeynep', 'b0000000-0000-4000-8000-000000000001'),
    ('c0000000-0000-4000-8000-000000000007', 'Su', 'a0000000-0000-4000-8000-000000000001')
  ) as v(id, ad, okul) loop
    perform set_config('request.jwt.claims', json_build_object('sub', r.id, 'role', 'authenticated')::text, true);
    perform public.create_profile(r.ad, 'Test', r.okul);
  end loop;
end $$;

update public.profile_private
set student_email = user_id::text || '@ogr.test.edu.tr', student_email_verified_at = now()
where user_id::text like 'c0000000-0000-4000-8000-00000000000_' and user_id <> 'c0000000-0000-4000-8000-000000000005';

update public.profiles set role = 'yetkili' where id = 'c0000000-0000-4000-8000-000000000004';
update public.profiles set role = 'superadmin' where id = 'c0000000-0000-4000-8000-000000000007';
insert into public.permissions (user_id, cluster_id, permission_key, granted_by) values
  ('c0000000-0000-4000-8000-000000000004', 'a0000000-0000-4000-8000-000000000001', 'trivia_yonet',
   'c0000000-0000-4000-8000-000000000007');

-- Bu testin soruları: buluttaki diğer sorular kapatılır ki seçim yalnızca bunlardan yapılsın.
update public.trivia_questions set active = false;
insert into public.trivia_questions (school_id, question, options, correct_index) values
  (null, 'Türkiye''nin başkenti neresidir?', array['İstanbul', 'Ankara', 'İzmir'], 1),
  (null, 'Bir haftada kaç gün vardır?', array['5', '6', '7', '8'], 2),
  (null, 'Suyun kimyasal formülü nedir?', array['H2O', 'CO2'], 0),
  (null, '2 + 2 kaçtır?', array['3', '4', '5', '6'], 1),
  (null, 'Güneş hangi yönden doğar?', array['Batı', 'Kuzey', 'Doğu'], 2),
  (null, 'Bir yılda kaç ay vardır?', array['10', '12'], 1),
  ('b0000000-0000-4000-8000-000000000001', 'B okulunun rengi nedir?', array['Mavi', 'Kırmızı'], 0),
  ('b0000000-0000-4000-8000-000000000001', 'B okulunun kuruluş yılı?', array['1990', '2000'], 1);

create temp table t (k text primary key, id uuid not null) on commit drop;
create temp table cevap (k text primary key, a smallint[] not null) on commit drop;
grant select, insert on t, cevap to authenticated;

create function pg_temp.bet(p_k text) returns uuid language sql stable as $$ select id from t where k = p_k $$;
create function pg_temp.sp(p_uid uuid) returns bigint language sql stable as
  $$ select sp_balance from public.balances where user_id = p_uid $$;
create function pg_temp.payouts(p_k text) returns bigint[] language sql stable as
  $$ select array_agg(w.payout order by w.user_id) from public.wagers w where w.bet_id = (select id from t where k = p_k) $$;
-- Düellonun doğru cevapları; ilk n tanesi doğru, kalanı yanlış.
create function pg_temp.answers(p_k text, p_correct int) returns smallint[] language sql stable as $$
  select array_agg(case when u.ord <= p_correct then q.correct_index else ((q.correct_index + 1) % 2)::smallint end order by u.ord)
  from public.trivia_duels d, unnest(d.question_ids) with ordinality as u(qid, ord)
  join public.trivia_questions q on q.id = u.qid
  where d.bet_id = (select id from t where k = p_k)
$$;

-- ---------------------------------------------------------------------------
-- Soru yönetimi
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';
select is((select count(*)::int from public.trivia_questions), 0, 'öğrenci soruları (ve cevapları) göremez');
select throws_ok(
  $$select public.save_trivia_question(null, 'a0000000-0000-4000-8000-000000000001', 'Öğrenci sorusu?', array['A', 'B'], 0::smallint)$$,
  '42501', null, 'öğrenci soru ekleyemez'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000004","role":"authenticated"}';
select lives_ok(
  $$insert into t values ('q1', public.save_trivia_question(null, 'a0000000-0000-4000-8000-000000000001',
      '  Kampüsün en eski binası hangisi?  ', array[' Rektörlük ', 'Kütüphane'], 0::smallint, 'Kampüs'))$$,
  'trivia_yonet izni olan okuluna soru ekler'
);
select is(
  (select row(question, options, category)::text from public.trivia_questions where id = pg_temp.bet('q1')),
  '("Kampüsün en eski binası hangisi?","{Rektörlük,Kütüphane}",Kampüs)',
  'soru ve şıklar boşluklardan temizlenir'
);
select is((select count(*)::int from public.trivia_questions), 1, 'yetkili yalnızca okulunun sorularını görür (genel ve başka okul yok)');
select throws_ok(
  $$select public.save_trivia_question(null, null, 'Genel soru?', array['A', 'B'], 0::smallint)$$,
  '42501', null, 'genel soruyu yalnızca süperadmin ekler'
);
select throws_ok(
  $$select public.save_trivia_question(null, 'a0000000-0000-4000-8000-000000000001', 'Hatalı soru?', array['A', 'B'], 5::smallint)$$,
  '23514', null, 'doğru cevap şıklardan biri olmalı'
);
select lives_ok(
  $$select public.save_trivia_question(pg_temp.bet('q1'), 'a0000000-0000-4000-8000-000000000001',
      'Kampüsün en eski binası hangisi?', array['Rektörlük', 'Kütüphane'], 0::smallint, 'Kampüs', false)$$,
  'yetkili sorusunu kapatır'
);
select is((select active from public.trivia_questions where id = pg_temp.bet('q1')), false, 'kapatılan soru düellolarda çıkmaz');

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000007","role":"authenticated"}';
select lives_ok(
  $$select public.save_trivia_question(null, null, 'Bir saatte kaç dakika vardır?', array['60', '100'], 0::smallint)$$,
  'süperadmin genel soru ekler'
);

-- ---------------------------------------------------------------------------
-- Meydan okuma (Ali, açık)
-- ---------------------------------------------------------------------------

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';
select lives_ok(
  $$insert into t values ('d1', public.create_trivia_duel(50))$$,
  'doğrulanmış öğrenci okula açık meydan okur'
);

set local role postgres;
select is(
  (select row(b.type, b.status, cardinality(d.question_ids), d.stake)::text
   from public.trivia_duels d join public.bets b on b.id = d.bet_id where d.bet_id = pg_temp.bet('d1')),
  '(sp_minigame,open,5,50)',
  'düello bir mini oyun bahsidir, 5 soru seçilir'
);
select is_empty(
  $$select 1 from public.trivia_duels d, unnest(d.question_ids) qid join public.trivia_questions q on q.id = qid
    where d.bet_id = pg_temp.bet('d1') and (q.school_id is not null or not q.active)$$,
  'başka okulun ve kapalı sorular seçilmez'
);
select is(pg_temp.sp('c0000000-0000-4000-8000-000000000001'), 950::bigint, 'meydan okuyanın payı düşer');
set local role authenticated;

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000004","role":"authenticated"}';
select throws_ok($$select public.create_trivia_duel(10)$$, '42501', null, 'soru yönetebilen düello açamaz');

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000007","role":"authenticated"}';
select throws_ok($$select public.create_trivia_duel(10)$$, '42501', null, 'süperadmin düello açamaz');

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';
select throws_ok($$select public.create_trivia_duel(101)$$, '23514', null, 'düello tutarı üst sınırı aşamaz');

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000005","role":"authenticated"}';
select throws_ok($$select public.create_trivia_duel(10)$$, 'KB002', null, 'okul maili doğrulanmamış düello açamaz');

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000003","role":"authenticated"}';
select throws_ok(
  $$select public.place_wager(pg_temp.bet('d1'), (select id from public.bet_options where bet_id = pg_temp.bet('d1') and position = 2), 50)$$,
  '42501', null, 'mini oyuna genel yatırımla katılınamaz'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';
select throws_ok($$select public.accept_trivia_duel(pg_temp.bet('d1'))$$, '42501', null, 'kendi düellona rakip olamazsın');

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000006","role":"authenticated"}';
select throws_ok($$select public.accept_trivia_duel(pg_temp.bet('d1'))$$, 'P0002', null, 'başka okulun düellosu bulunamaz');

-- ---------------------------------------------------------------------------
-- Oynama: Ali hemen oynar, Can kabul edip oynar
-- ---------------------------------------------------------------------------

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';
select is((select count(*)::int from public.start_trivia_duel(pg_temp.bet('d1'))), 5, 'meydan okuyan oyunu başlatır, 5 soru gelir');
select ok(
  (select min(seconds_left) > 0 and count(*) = 5 from public.start_trivia_duel(pg_temp.bet('d1'))),
  'oyun yeniden açılınca aynı sorular ve kalan süre gelir'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000003","role":"authenticated"}';
select lives_ok($$select public.accept_trivia_duel(pg_temp.bet('d1'))$$, 'okuldan biri meydan okumayı kabul eder');

set local role postgres;
select is(
  (select row(b.status, pg_temp.sp('c0000000-0000-4000-8000-000000000003'))::text from public.bets b where b.id = pg_temp.bet('d1')),
  '(locked,950)',
  'kabul edenin payı düşer, düello kilitlenir'
);
insert into cevap values ('d1-ali', pg_temp.answers('d1', 5)), ('d1-can', pg_temp.answers('d1', 3));
set local role authenticated;

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000002","role":"authenticated"}';
select throws_ok($$select public.accept_trivia_duel(pg_temp.bet('d1'))$$, 'KB018', null, 'rakibi olan düelloya katılınamaz');

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';
select is(
  (select row(score, late)::text from public.submit_trivia_answers(pg_temp.bet('d1'), (select a from cevap where k = 'd1-ali'))),
  '(5,f)',
  'puanı sunucu hesaplar (5 doğru)'
);
select throws_ok(
  $$select public.submit_trivia_answers(pg_temp.bet('d1'), (select a from cevap where k = 'd1-ali'))$$,
  'KB018', null, 'cevaplar ikinci kez gönderilemez'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000003","role":"authenticated"}';
select is(
  (select count(*)::int from public.trivia_duel_plays where bet_id = pg_temp.bet('d1')),
  0,
  'düello bitmeden rakibin oyunu görünmez'
);
do $$ begin perform public.start_trivia_duel(pg_temp.bet('d1')); end $$;
select is(
  (select row(score, late)::text from public.submit_trivia_answers(pg_temp.bet('d1'), (select a from cevap where k = 'd1-can'))),
  '(3,f)',
  'rakip 3 doğru yapar'
);

set local role postgres;
select is(
  (select row(b.status, pg_temp.payouts('d1'))::text from public.bets b where b.id = pg_temp.bet('d1')),
  '(settled,"{100,0}")',
  'iki oyuncu da gönderince düello sonuçlanır, çok doğru yapan havuzu alır'
);
select is(pg_temp.sp('c0000000-0000-4000-8000-000000000001'), 1050::bigint, 'kazananın bakiyesi: 1000 - 50 + 100');
set local role authenticated;

select is(
  (select count(*)::int from public.trivia_duel_plays where bet_id = pg_temp.bet('d1')),
  2,
  'düello bitince iki oyuncu birbirinin sonucunu görür'
);

-- ---------------------------------------------------------------------------
-- Davetli düello ve tam beraberlik (Veli → Can)
-- ---------------------------------------------------------------------------

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000002","role":"authenticated"}';
select lives_ok(
  $$insert into t values ('d2', public.create_trivia_duel(20, 'c0000000-0000-4000-8000-000000000003'))$$,
  'belirli bir kişiye meydan okunur'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';
select throws_ok($$select public.accept_trivia_duel(pg_temp.bet('d2'))$$, '42501', null, 'davet edilmeyen kabul edemez');

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000003","role":"authenticated"}';
select lives_ok($$select public.accept_trivia_duel(pg_temp.bet('d2'))$$, 'davet edilen kabul eder');

set local role postgres;
insert into cevap values ('d2', pg_temp.answers('d2', 0));
do $$
declare u uuid;
begin
  foreach u in array array['c0000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000003']::uuid[] loop
    perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
    perform public.start_trivia_duel(pg_temp.bet('d2'));
    perform public.submit_trivia_answers(pg_temp.bet('d2'), (select a from cevap where k = 'd2'));
  end loop;
end $$;

select is(
  (select row(b.status, b.cancel_reason, pg_temp.payouts('d2'))::text from public.bets b where b.id = pg_temp.bet('d2')),
  '(cancelled,"Berabere, yatırımlar iade edildi","{20,20}")',
  'aynı puan ve aynı sürede düello iptal edilir, paylar iade edilir'
);

-- ---------------------------------------------------------------------------
-- Süre aşımı ve oynamayan oyuncu (Ali → Veli)
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';
do $$ begin insert into t values ('d3', public.create_trivia_duel(10, 'c0000000-0000-4000-8000-000000000002')); end $$;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000002","role":"authenticated"}';
do $$ begin perform public.accept_trivia_duel(pg_temp.bet('d3')); perform public.start_trivia_duel(pg_temp.bet('d3')); end $$;

set local role postgres;
insert into cevap values ('d3', pg_temp.answers('d3', 5));
update public.trivia_duel_plays set started_at = now() - interval '10 minutes'
where bet_id = pg_temp.bet('d3') and player_id = 'c0000000-0000-4000-8000-000000000002';
set local role authenticated;

select is(
  (select row(score, late)::text from public.submit_trivia_answers(pg_temp.bet('d3'), (select a from cevap where k = 'd3'))),
  '(0,t)',
  'süre (+10 sn pay) aşıldıysa doğru cevaplar da 0 puan'
);

set local role postgres;
update public.trivia_duels set play_deadline = now() - interval '1 second' where bet_id = pg_temp.bet('d3');
select ok(private.process_trivia_duels() >= 1, 'zamanlanmış iş oynama süresi dolan düelloyu işler');
select is(
  (select row(b.status, pg_temp.payouts('d3'))::text from public.bets b where b.id = pg_temp.bet('d3')),
  '(settled,"{0,20}")',
  'hiç oynamayan, geç gönderene de yenilir (Ali 0, Veli 20)'
);

-- ---------------------------------------------------------------------------
-- Kabul edilmeyen meydan okuma (Veli, açık)
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000002","role":"authenticated"}';
do $$ begin insert into t values ('d4', public.create_trivia_duel(15)); end $$;
set local role postgres;
update public.trivia_duels set accept_deadline = now() - interval '1 second' where bet_id = pg_temp.bet('d4');
select ok(private.process_trivia_duels() >= 1, 'zamanlanmış iş kabul süresi dolan meydan okumayı işler');
select is(
  (select row(b.status, b.cancel_reason, pg_temp.payouts('d4'))::text from public.bets b where b.id = pg_temp.bet('d4')),
  '(cancelled,"Rakip çıkmadı, yatırım iade edildi",{15})',
  'kabul edilmeyen meydan okumanın payı iade edilir'
);

-- ---------------------------------------------------------------------------
-- Bütünlük ve zamanlanmış iş
-- ---------------------------------------------------------------------------

select is_empty($$select * from private.balance_mismatches()$$, 'önbellekteki bakiye ledger toplamına eşit');
select is_empty(
  $$select b.id from public.bets b join public.wagers w on w.bet_id = b.id
    where b.type = 'sp_minigame' and b.status in ('settled', 'cancelled')
    group by b.id, b.pool_total
    having sum(w.payout) <> b.pool_total or count(w.payout) <> count(*)$$,
  'sonuçlanan ve iptal edilen düellolarda dağıtılan toplam havuza eşit'
);
select is(
  (select count(*)::int from cron.job where jobname = 'kampusbet_trivia_duellolari' and schedule = '*/5 * * * *'),
  1,
  'düello işi 5 dakikada bir çalışacak şekilde zamanlanmış'
);

select * from finish();
rollback;
