-- Adım 6 testleri: resmi SSP bahisleri (sabit oran) ve yetki kontrollü yönetim.
-- Tek transaction içinde çalışır ve sonunda geri alınır.
--
-- A okulu: Su (süperadmin), Ayşe (yetkili: resmi_bahis_ac + resmi_bahis_kapat),
--          Mert (yetkili: yalnızca resmi_bahis_ac), Ali, Can, Ece (öğrenci; 500 SSP)
-- B okulu: Zeynep (yetkili: B'de resmi_bahis_ac + resmi_bahis_kapat)
-- Hepsinin okul maili doğrulanmış.

begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(37);

-- ---------------------------------------------------------------------------
-- Hazırlık
-- ---------------------------------------------------------------------------

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
    ('c0000000-0000-4000-8000-000000000001'::uuid, 'Su', 'a0000000-0000-4000-8000-000000000001'::uuid),
    ('c0000000-0000-4000-8000-000000000002', 'Ayse', 'a0000000-0000-4000-8000-000000000001'),
    ('c0000000-0000-4000-8000-000000000003', 'Mert', 'a0000000-0000-4000-8000-000000000001'),
    ('c0000000-0000-4000-8000-000000000004', 'Ali', 'a0000000-0000-4000-8000-000000000001'),
    ('c0000000-0000-4000-8000-000000000005', 'Can', 'a0000000-0000-4000-8000-000000000001'),
    ('c0000000-0000-4000-8000-000000000006', 'Ece', 'a0000000-0000-4000-8000-000000000001'),
    ('c0000000-0000-4000-8000-000000000007', 'Zeynep', 'b0000000-0000-4000-8000-000000000001')
  ) as v(id, ad, okul) loop
    perform set_config('request.jwt.claims', json_build_object('sub', r.id, 'role', 'authenticated')::text, true);
    perform public.create_profile(r.ad, 'Test', r.okul);
  end loop;
end $$;

update public.profile_private
set student_email = user_id::text || '@ogr.test.edu.tr', student_email_verified_at = now()
where user_id::text like 'c0000000-0000-4000-8000-00000000000_';

update public.profiles set role = 'superadmin' where id = 'c0000000-0000-4000-8000-000000000001';
update public.profiles set role = 'yetkili'
where id in ('c0000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000003',
             'c0000000-0000-4000-8000-000000000007');

insert into public.permissions (user_id, cluster_id, permission_key, granted_by) values
  ('c0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000001', 'resmi_bahis_ac', 'c0000000-0000-4000-8000-000000000001'),
  ('c0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000001', 'resmi_bahis_kapat', 'c0000000-0000-4000-8000-000000000001'),
  ('c0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000001', 'resmi_bahis_ac', 'c0000000-0000-4000-8000-000000000001'),
  ('c0000000-0000-4000-8000-000000000007', 'b0000000-0000-4000-8000-000000000001', 'resmi_bahis_ac', 'c0000000-0000-4000-8000-000000000001'),
  ('c0000000-0000-4000-8000-000000000007', 'b0000000-0000-4000-8000-000000000001', 'resmi_bahis_kapat', 'c0000000-0000-4000-8000-000000000001');

do $$
declare u uuid;
begin
  foreach u in array array['c0000000-0000-4000-8000-000000000004', 'c0000000-0000-4000-8000-000000000005',
                           'c0000000-0000-4000-8000-000000000006']::uuid[] loop
    perform private.post_ledger(u, 'SSP', 500, 'admin_grant', null, null,
                                'c0000000-0000-4000-8000-000000000001', 'test için SSP');
  end loop;
end $$;

create temp table t (k text primary key, id uuid not null) on commit drop;
grant select, insert on t to authenticated;
insert into t values ('sosyal', private.create_bet(
  'c0000000-0000-4000-8000-000000000004', 'a0000000-0000-4000-8000-000000000001', 'sp_social', 'school',
  'Sosyal bahis', null, array['Evet', 'Hayır'], now() + interval '1 hour', 'c0000000-0000-4000-8000-000000000005'));

create function pg_temp.bet(p_k text) returns uuid language sql stable as $$ select id from t where k = p_k $$;
create function pg_temp.opt(p_k text, p_position int) returns uuid language sql stable as
  $$ select o.id from public.bet_options o join t on t.id = o.bet_id where t.k = p_k and o.position = p_position $$;
create function pg_temp.ssp(p_uid uuid) returns bigint language sql stable as
  $$ select ssp_balance from public.balances where user_id = p_uid $$;

-- ---------------------------------------------------------------------------
-- Açma
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000002","role":"authenticated"}';

select lives_ok(
  $$insert into t values ('final', public.create_official_bet(
      'a0000000-0000-4000-8000-000000000001', 'Bahar turnuvası finali', 'Basketbol', array['Kırmızı', 'Mavi'],
      array[1.80, 2.10], now() + interval '1 hour', 200))$$,
  'resmi_bahis_ac izni olan yetkili resmi bahis açar'
);

select is(
  (select row(type, currency, odds_mode, settlement_mode, scope, max_stake)::text from public.bets where id = pg_temp.bet('final')),
  '(ssp_official,SSP,fixed,admin,school,200)',
  'resmi bahis SSP, sabit oranlı, admin sonuçlandırır'
);

select is(
  (select array_agg(odds order by position) from public.bet_options where bet_id = pg_temp.bet('final')),
  array[1.80, 2.10]::numeric[],
  'seçeneklerin oranları kaydedilir'
);

select throws_ok(
  $$select public.create_official_bet('a0000000-0000-4000-8000-000000000001', 'Tek oranlı', null,
      array['A', 'B'], array[1.50], now() + interval '1 hour')$$,
  '23514', null, 'oran sayısı seçenek sayısına eşit olmalı'
);

select throws_ok(
  $$select public.create_official_bet('a0000000-0000-4000-8000-000000000001', 'Uçuk oran', null,
      array['A', 'B'], array[1.50, 25.00], now() + interval '1 hour')$$,
  '23514', null, 'oran 1,01 ile 20,00 arasında olmalı'
);

select throws_ok(
  $$select public.create_official_bet('a0000000-0000-4000-8000-000000000001', 'Oransız', null,
      array['A', 'B'], null, now() + interval '1 hour')$$,
  '23514', null, 'resmi bahis oransız açılamaz'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000004","role":"authenticated"}';

select throws_ok(
  $$select public.create_official_bet('a0000000-0000-4000-8000-000000000001', 'Öğrenci bahsi', null,
      array['A', 'B'], array[1.50, 2.50], now() + interval '1 hour')$$,
  '42501', null, 'izni olmayan öğrenci resmi bahis açamaz'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000007","role":"authenticated"}';

select throws_ok(
  $$select public.create_official_bet('a0000000-0000-4000-8000-000000000001', 'Başka okul', null,
      array['A', 'B'], array[1.50, 2.50], now() + interval '1 hour')$$,
  '42501', null, 'başka okulun yetkilisi bu okulda resmi bahis açamaz'
);

set local role postgres;

select throws_ok(
  $$select private.create_bet('c0000000-0000-4000-8000-000000000004', 'a0000000-0000-4000-8000-000000000001',
      'sp_social', 'school', 'Oranlı sosyal', null, array['A', 'B'], now() + interval '1 hour',
      'c0000000-0000-4000-8000-000000000005', 1, null, array[1.50, 2.50])$$,
  '23514', null, 'sosyal bahis sabit oranlı olamaz'
);

select is(
  (select count(*)::int from public.admin_audit_log where action = 'official_bet_create'
     and details ->> 'bet_id' = pg_temp.bet('final')::text and actor_id = 'c0000000-0000-4000-8000-000000000002'),
  1,
  'resmi bahis açma denetim kaydına yazılır'
);

-- ---------------------------------------------------------------------------
-- Yatırım
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000004","role":"authenticated"}';

select lives_ok(
  $$select public.place_wager(pg_temp.bet('final'), pg_temp.opt('final', 1), 100)$$,
  'öğrenci resmi bahse SSP yatırır'
);

select is(
  (select row(amount, currency, odds)::text from public.wagers where bet_id = pg_temp.bet('final')),
  '(100,SSP,1.80)',
  'yatırım anındaki oran yatırımla birlikte saklanır'
);

select is(pg_temp.ssp('c0000000-0000-4000-8000-000000000004'), 400::bigint, 'SSP bakiyeden düşer');

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000005","role":"authenticated"}';

select lives_ok(
  $$select public.place_wager(pg_temp.bet('final'), pg_temp.opt('final', 2), 200)$$,
  'karşı seçeneğe en fazla tutarla yatırılır'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000006","role":"authenticated"}';

select throws_ok(
  $$select public.place_wager(pg_temp.bet('final'), pg_temp.opt('final', 1), 201)$$,
  '23514', null, 'en fazla tutarın üstü yatırılamaz'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000002","role":"authenticated"}';

select throws_ok(
  $$select public.place_wager(pg_temp.bet('final'), pg_temp.opt('final', 1), 10)$$,
  '42501', null, 'bahsi açan yetkili yatırım yapamaz'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';

select throws_ok(
  $$select public.place_wager(pg_temp.bet('final'), pg_temp.opt('final', 1), 10)$$,
  '42501', null, 'sonuçlandırabilecek olan süperadmin yatırım yapamaz'
);

-- ---------------------------------------------------------------------------
-- Kilitleme ve sonuçlandırma yetkisi
-- ---------------------------------------------------------------------------

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000003","role":"authenticated"}';

select throws_ok(
  $$select public.lock_official_bet(pg_temp.bet('final'))$$,
  '42501', null, 'yalnızca açma izni olan yetkili kilitleyemez'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000004","role":"authenticated"}';

select throws_ok(
  $$select public.settle_official_bet(pg_temp.bet('final'), pg_temp.opt('final', 1))$$,
  '42501', null, 'öğrenci sonuçlandıramaz'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000007","role":"authenticated"}';

select throws_ok(
  $$select public.lock_official_bet((select id from t where k = 'final'))$$,
  '42501', null, 'başka okulun yetkilisi kilitleyemez'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000002","role":"authenticated"}';

select throws_ok(
  $$select public.settle_official_bet(pg_temp.bet('sosyal'), pg_temp.opt('sosyal', 1))$$,
  'P0002', null, 'resmi olmayan bahis resmi bahis işlemleriyle sonuçlandırılamaz'
);

select throws_ok(
  $$select public.settle_official_bet(pg_temp.bet('final'), pg_temp.opt('final', 1))$$,
  'KB005', null, 'yatırıma açık resmi bahis sonuçlandırılamaz'
);

select lives_ok($$select public.lock_official_bet(pg_temp.bet('final'))$$, 'yetkili resmi bahsi kilitler');

select lives_ok(
  $$select public.settle_official_bet(pg_temp.bet('final'), pg_temp.opt('final', 1))$$,
  'yetkili resmi bahsi sonuçlandırır'
);

-- ---------------------------------------------------------------------------
-- Sabit oranlı ödeme: Ali 100 × 1,80 = 180, Can 0
-- ---------------------------------------------------------------------------

set local role postgres;

select is(
  (select array_agg(payout order by user_id) from public.wagers where bet_id = pg_temp.bet('final')),
  array[180, 0]::bigint[],
  'kazanan yatırım × oran alır, kaybeden 0'
);

select is(
  array[pg_temp.ssp('c0000000-0000-4000-8000-000000000004'), pg_temp.ssp('c0000000-0000-4000-8000-000000000005')],
  array[580, 300]::bigint[],
  'SSP bakiyeleri: Ali 400 + 180, Can 500 - 200'
);

select is(
  (select row(l.amount, l.actor_id)::text from public.ledger_entries l join public.wagers w on w.id = l.ref_id
   where l.reason = 'bet_payout' and w.bet_id = pg_temp.bet('final')),
  '(180,c0000000-0000-4000-8000-000000000002)',
  'ödeme ledger''a sonuçlandıran yetkiliyle yazılır'
);

select is(
  (select array_agg(action order by id) from public.admin_audit_log where details ->> 'bet_id' = pg_temp.bet('final')::text),
  array['official_bet_create', 'official_bet_lock', 'official_bet_settle'],
  'açma, kilitleme ve sonuçlandırma denetim kaydında'
);

select throws_ok(
  $$select public.cancel_official_bet(pg_temp.bet('final'), 'sonradan iptal')$$,
  'KB006', null, 'sonuçlanmış resmi bahis iptal edilemez'
);

-- ---------------------------------------------------------------------------
-- İptal: süperadmin açar, Ece yatırır, Ayşe iptal eder
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';

select lives_ok(
  $$insert into t values ('ertelenen', public.create_official_bet(
      'a0000000-0000-4000-8000-000000000001', 'Ertelenecek maç', null, array['Ev sahibi', 'Deplasman'],
      array[1.50, 2.60], now() + interval '2 hours'))$$,
  'süperadmin her okulda resmi bahis açar'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000006","role":"authenticated"}';
do $$ begin perform public.place_wager(pg_temp.bet('ertelenen'), pg_temp.opt('ertelenen', 2), 50); end $$;

select throws_ok(
  $$select public.cancel_official_bet(pg_temp.bet('ertelenen'), 'Maç ertelendi')$$,
  '42501', null, 'öğrenci iptal edemez'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000002","role":"authenticated"}';

select throws_ok(
  $$select public.cancel_official_bet(pg_temp.bet('ertelenen'), '  ')$$,
  '23514', null, 'gerekçesiz iptal edilemez'
);

select lives_ok(
  $$select public.cancel_official_bet(pg_temp.bet('ertelenen'), 'Maç ertelendi')$$,
  'yetkili başkasının açtığı resmi bahsi iptal eder'
);

set local role postgres;

select is(
  pg_temp.ssp('c0000000-0000-4000-8000-000000000006'),
  500::bigint,
  'iptalde SSP iade edilir'
);

select is(
  (select count(*)::int from public.admin_audit_log where action = 'official_bet_cancel'
     and details ->> 'bet_id' = pg_temp.bet('ertelenen')::text and details ->> 'reason' = 'Maç ertelendi'),
  1,
  'iptal gerekçesiyle denetim kaydına yazılır'
);

-- ---------------------------------------------------------------------------
-- Bütünlük
-- ---------------------------------------------------------------------------

select is_empty($$select * from private.balance_mismatches()$$, 'önbellekteki bakiye ledger toplamına eşit');

select is_empty(
  $$select w.id from public.wagers w join public.bets b on b.id = w.bet_id
    where b.status = 'settled' and b.odds_mode = 'fixed'
      and w.payout <> case when w.option_id = (select o.id from public.bet_options o where o.bet_id = b.id and o.is_winner)
                           then floor(w.amount * w.odds)::bigint else 0 end$$,
  'sabit oranlı her yatırımın ödemesi yatırım × oran ya da 0'
);

select * from finish();
rollback;
