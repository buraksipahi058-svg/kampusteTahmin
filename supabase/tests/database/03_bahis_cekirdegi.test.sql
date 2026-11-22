-- Adım 3 testleri: bahis açma, yatırım, pari-mutuel sonuçlandırma, iptal + iade.
-- Tek transaction içinde çalışır ve sonunda geri alınır.
--
-- Kişiler (hepsi 1000 SP ile başlar; Yeni hariç hepsinin okul maili doğrulanmış):
--   A okulu: Ali, Veli, Can, Deniz, Yeni (doğrulanmamış), Su (süperadmin)
--   B okulu: Zeynep
--   G: A okulunda özel grup; üyeleri Ali ve Veli
--
-- Bahisler (t tablosunda):
--   s1: sosyal, okul A, hakem Veli          -> Evet kazanır (normal paylaştırma)
--   s2: sosyal, hakem Su                    -> küsurat dağıtımı
--   s3: sosyal, hakem Su                    -> kazanana kimse yatırmamış, iade
--   s4: sosyal, hakem Su                    -> iptal
--   s5: sosyal, hakem Su                    -> süresi geçmiş
--   g1: sosyal, grup G, açan ve hakem Ali   -> özel grup görünürlüğü
--   o1: resmi SSP, açan Su

begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(61);

-- ---------------------------------------------------------------------------
-- Hazırlık
-- ---------------------------------------------------------------------------

update public.economy_settings set signup_bonus_sp = 1000;

insert into public.clusters (id, name, type) values
  ('a0000000-0000-4000-8000-000000000001', 'Test Üniversitesi A', 'school'),
  ('b0000000-0000-4000-8000-000000000001', 'Test Üniversitesi B', 'school');
insert into public.clusters (id, name, type, parent_cluster_id) values
  ('a0000000-0000-4000-8000-000000000003', 'A Özel Grup', 'group', 'a0000000-0000-4000-8000-000000000001');

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
    ('c0000000-0000-4000-8000-000000000004', 'Deniz', 'a0000000-0000-4000-8000-000000000001'),
    ('c0000000-0000-4000-8000-000000000005', 'Zeynep', 'b0000000-0000-4000-8000-000000000001'),
    ('c0000000-0000-4000-8000-000000000006', 'Yeni', 'a0000000-0000-4000-8000-000000000001'),
    ('c0000000-0000-4000-8000-000000000007', 'Su', 'a0000000-0000-4000-8000-000000000001')
  ) as v(id, ad, okul) loop
    perform set_config('request.jwt.claims', json_build_object('sub', r.id, 'role', 'authenticated')::text, true);
    perform public.create_profile(r.ad, 'Test', r.okul);
  end loop;
end $$;

update public.profile_private
set student_email = user_id::text || '@ogr.test.edu.tr', student_email_verified_at = now()
where user_id <> 'c0000000-0000-4000-8000-000000000006';

update public.profiles set role = 'superadmin' where id = 'c0000000-0000-4000-8000-000000000007';

insert into public.user_clusters (user_id, cluster_id) values
  ('c0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000003'),
  ('c0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000003');

do $$ begin perform private.post_ledger('c0000000-0000-4000-8000-000000000001', 'SSP', 100, 'admin_grant', null, null,
                                        'c0000000-0000-4000-8000-000000000007', 'test için SSP'); end $$;

-- Bahisler
create temp table t (k text primary key, id uuid not null) on commit drop;
grant select on t to authenticated;

insert into t values
  ('s1', private.create_bet('c0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000001', 'sp_social', 'school',
         'Final maçını mühendislik kazanır mı?', null, array['Evet', 'Hayır'], now() + interval '1 hour',
         'c0000000-0000-4000-8000-000000000002')),
  ('s2', private.create_bet('c0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000001', 'sp_social', 'school',
         'Küsurat bahsi', null, array['X', 'Y'], now() + interval '1 hour', 'c0000000-0000-4000-8000-000000000007')),
  ('s3', private.create_bet('c0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000001', 'sp_social', 'school',
         'Kimsenin bilemediği bahis', null, array['X', 'Y'], now() + interval '1 hour', 'c0000000-0000-4000-8000-000000000007')),
  ('s4', private.create_bet('c0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000001', 'sp_social', 'school',
         'İptal edilecek bahis', null, array['X', 'Y'], now() + interval '1 hour', 'c0000000-0000-4000-8000-000000000007')),
  ('s5', private.create_bet('c0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000001', 'sp_social', 'school',
         'Süresi geçecek bahis', null, array['X', 'Y'], now() + interval '1 hour', 'c0000000-0000-4000-8000-000000000007')),
  ('g1', private.create_bet('c0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000003', 'sp_social', 'private',
         'Grup içi bahis', null, array['A', 'B'], now() + interval '1 hour', 'c0000000-0000-4000-8000-000000000001')),
  ('o1', private.create_bet('c0000000-0000-4000-8000-000000000007', 'a0000000-0000-4000-8000-000000000001', 'ssp_official', 'school',
         'Bahar turnuvası finali', null, array['Kırmızı', 'Mavi'], now() + interval '1 hour'));

-- Bahis kimliği ve n'inci seçenek kimliği
create function pg_temp.bet(p_k text) returns uuid language sql stable as
  $$ select id from t where k = p_k $$;
create function pg_temp.opt(p_k text, p_position int) returns uuid language sql stable as
  $$ select o.id from public.bet_options o join t on t.id = o.bet_id where t.k = p_k and o.position = p_position $$;
create function pg_temp.payouts(p_k text) returns bigint[] language sql stable as
  $$ select array_agg(w.payout order by w.user_id) from public.wagers w where w.bet_id = (select id from t where k = p_k) $$;

-- ---------------------------------------------------------------------------
-- Bahis açma kuralları
-- ---------------------------------------------------------------------------

select throws_ok(
  $$select private.create_bet('c0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000001', 'sp_social', 'school',
      'Tek seçenekli', null, array['Evet'], now() + interval '1 hour', 'c0000000-0000-4000-8000-000000000002')$$,
  '23514', null, 'bahsin en az iki seçeneği olmalı'
);

select throws_ok(
  $$select private.create_bet('c0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000001', 'sp_social', 'school',
      'Geçmiş bahis', null, array['Evet', 'Hayır'], now() - interval '1 minute', 'c0000000-0000-4000-8000-000000000002')$$,
  '23514', null, 'kapanış zamanı geçmişte olamaz'
);

select throws_ok(
  $$select private.create_bet('c0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000001', 'sp_social', 'school',
      'Hakemsiz bahis', null, array['Evet', 'Hayır'], now() + interval '1 hour')$$,
  '23514', null, 'sosyal bahsin hakemi olmalı'
);

select throws_ok(
  $$select private.create_bet('c0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000001', 'sp_social', 'private',
      'Okulda özel bahis', null, array['Evet', 'Hayır'], now() + interval '1 hour', 'c0000000-0000-4000-8000-000000000002')$$,
  '23514', null, 'özel bahis okul kümesinde açılamaz'
);

select throws_ok(
  $$select private.create_bet('c0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000003', 'sp_social', 'school',
      'Grupta okul bahsi', null, array['Evet', 'Hayır'], now() + interval '1 hour', 'c0000000-0000-4000-8000-000000000001')$$,
  '23514', null, 'okul kapsamlı bahis grupta açılamaz'
);

select throws_ok(
  $$select private.create_bet('c0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000001', 'sp_social', 'global',
      'Genel bahis', null, array['Evet', 'Hayır'], now() + interval '1 hour', 'c0000000-0000-4000-8000-000000000002')$$,
  '23514', null, 'genel kapsam v1''de yok'
);

select throws_ok(
  $$select private.create_bet('c0000000-0000-4000-8000-000000000006', 'a0000000-0000-4000-8000-000000000001', 'sp_social', 'school',
      'Doğrulanmamış bahis', null, array['Evet', 'Hayır'], now() + interval '1 hour', 'c0000000-0000-4000-8000-000000000006')$$,
  'KB002', null, 'okul maili doğrulanmamış kişi bahis açamaz'
);

-- ---------------------------------------------------------------------------
-- Yatırım: Ali
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';

select is(
  (select count(*)::int from public.bets where id in (pg_temp.bet('s1'), pg_temp.bet('g1'), pg_temp.bet('o1'))),
  3,
  'okul ve üyesi olunan grubun bahisleri görünür'
);

select lives_ok(
  $$select public.place_wager(pg_temp.bet('s1'), pg_temp.opt('s1', 1), 100)$$,
  'doğrulanmış öğrenci yatırım yapar'
);

select is(
  (select sp_balance from public.balances where user_id = 'c0000000-0000-4000-8000-000000000001'),
  900::bigint,
  'yatırılan SP bakiyeden düşer'
);

select is(
  (select row(b.pool_total, o.pool_amount)::text from public.bets b join public.bet_options o on o.bet_id = b.id
   where b.id = pg_temp.bet('s1') and o.position = 1),
  '(100,100)',
  'havuz ve seçenek toplamı artar'
);

select is(
  (select row(l.amount, l.ref_type, l.ref_id = w.id)::text
   from public.ledger_entries l join public.wagers w on w.id = l.ref_id
   where l.reason = 'bet_stake' and w.bet_id = pg_temp.bet('s1') and w.user_id = 'c0000000-0000-4000-8000-000000000001'),
  '(-100,wager,t)',
  'yatırım ledger''a yatırım kaydına bağlı yazılır'
);

select throws_ok(
  $$select public.place_wager(pg_temp.bet('s1'), pg_temp.opt('s1', 2), 50)$$,
  'KB004', null, 'aynı bahse ikinci kez yatırım yapılamaz'
);

select throws_ok(
  $$select public.place_wager(pg_temp.bet('s2'), pg_temp.opt('s1', 1), 50)$$,
  'P0002', null, 'başka bahsin seçeneğine yatırım yapılamaz'
);

select throws_ok(
  $$select public.place_wager(pg_temp.bet('s2'), pg_temp.opt('s2', 1), 0)$$,
  '23514', null, 'sıfır tutarla yatırım yapılamaz'
);

select throws_ok(
  $$select public.place_wager(pg_temp.bet('s2'), pg_temp.opt('s2', 1), 5000)$$,
  'KB001', null, 'bakiyeden fazla yatırım yapılamaz'
);

select is(
  (select row(pool_total, (select count(*) from public.wagers w where w.bet_id = b.id))::text
   from public.bets b where b.id = pg_temp.bet('s2')),
  '(0,0)',
  'başarısız yatırım havuzda ve kayıtlarda iz bırakmaz'
);

select throws_ok(
  $$select public.place_wager(pg_temp.bet('g1'), pg_temp.opt('g1', 1), 10)$$,
  '42501', null, 'hakem kendi bahsine yatırım yapamaz'
);

select throws_ok(
  $$insert into public.wagers (bet_id, option_id, user_id, amount, currency)
    values (pg_temp.bet('s2'), pg_temp.opt('s2', 1), 'c0000000-0000-4000-8000-000000000001', 10, 'SP')$$,
  '42501', null, 'yatırım tabloya doğrudan eklenemez'
);

select throws_ok(
  $$update public.bets set pool_total = 0 where id = pg_temp.bet('s1')$$,
  '42501', null, 'bahis doğrudan değiştirilemez'
);

select throws_ok(
  $$select private.settle_bet(pg_temp.bet('s1'), pg_temp.opt('s1', 2), 'c0000000-0000-4000-8000-000000000001')$$,
  '42501', null, 'öğrenci iç sonuçlandırma fonksiyonunu çağıramaz'
);

select lives_ok(
  $$select public.place_wager(pg_temp.bet('o1'), pg_temp.opt('o1', 1), 50)$$,
  'resmi bahse SSP ile yatırım yapılır'
);

select is(
  (select row(sp_balance, ssp_balance)::text from public.balances where user_id = 'c0000000-0000-4000-8000-000000000001'),
  '(900,50)',
  'resmi bahis SP''ye dokunmaz, SSP''den düşer'
);

-- ---------------------------------------------------------------------------
-- Diğer kişiler
-- ---------------------------------------------------------------------------

-- Can: grubun üyesi değil
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000003","role":"authenticated"}';

select is(
  (select count(*)::int from public.bets where id = pg_temp.bet('g1')),
  0,
  'üye olunmayan grubun bahsi görünmez'
);

select throws_ok(
  $$select public.place_wager(pg_temp.bet('g1'), (select o.id from public.bet_options o where false), 10)$$,
  'P0002', null, 'üye olunmayan grubun bahsine yatırım yapılamaz'
);

select lives_ok(
  $$select public.place_wager(pg_temp.bet('s1'), pg_temp.opt('s1', 1), 300)$$,
  'aynı seçeneğe ikinci kişi yatırım yapar'
);

select is(
  (select count(*)::int from public.wagers where bet_id = pg_temp.bet('s1')),
  1,
  'başkalarının yatırımları görünmez'
);

-- Deniz
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000004","role":"authenticated"}';

select lives_ok(
  $$select public.place_wager(pg_temp.bet('s1'), pg_temp.opt('s1', 2), 200)$$,
  'karşı seçeneğe yatırım yapılır'
);

-- Veli: s1'in hakemi, G'nin üyesi
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000002","role":"authenticated"}';

select throws_ok(
  $$select public.place_wager(pg_temp.bet('s1'), pg_temp.opt('s1', 1), 10)$$,
  '42501', null, 'hakem hakemi olduğu bahse yatırım yapamaz'
);

select lives_ok(
  $$select public.place_wager(pg_temp.bet('g1'), pg_temp.opt('g1', 1), 100)$$,
  'grup üyesi grup bahsine yatırım yapar'
);

-- Zeynep: başka okul
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000005","role":"authenticated"}';

select is(
  (select count(*)::int from public.bets where id = pg_temp.bet('s1')),
  0,
  'başka okulun bahsi görünmez'
);

select throws_ok(
  $$select public.place_wager('00000000-0000-0000-0000-000000000000', null, 10)$$,
  'P0002', null, 'olmayan bahse yatırım yapılamaz'
);

-- Yeni: doğrulanmamış
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000006","role":"authenticated"}';

select throws_ok(
  $$select public.place_wager(pg_temp.bet('s1'), pg_temp.opt('s1', 1), 10)$$,
  'KB002', null, 'okul maili doğrulanmamış kişi yatırım yapamaz'
);

-- Su: resmi bahsi açan
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000007","role":"authenticated"}';

select throws_ok(
  $$select public.place_wager(pg_temp.bet('o1'), pg_temp.opt('o1', 2), 10)$$,
  '42501', null, 'resmi bahsi açan yatırım yapamaz'
);

-- ---------------------------------------------------------------------------
-- s2, s3, s4 için yatırımlar (hazırlık)
-- ---------------------------------------------------------------------------

set local role postgres;

do $$
declare r record;
begin
  for r in select * from (values
    ('c0000000-0000-4000-8000-000000000001'::uuid, 's2', 1, 1::bigint),
    ('c0000000-0000-4000-8000-000000000003', 's2', 1, 2),
    ('c0000000-0000-4000-8000-000000000004', 's2', 2, 2),
    ('c0000000-0000-4000-8000-000000000001', 's3', 1, 100),
    ('c0000000-0000-4000-8000-000000000003', 's3', 1, 50),
    ('c0000000-0000-4000-8000-000000000001', 's4', 1, 100),
    ('c0000000-0000-4000-8000-000000000004', 's4', 2, 50)
  ) as v(uid, k, pos, amount) loop
    perform set_config('request.jwt.claims', json_build_object('sub', r.uid, 'role', 'authenticated')::text, true);
    perform public.place_wager(pg_temp.bet(r.k), pg_temp.opt(r.k, r.pos), r.amount);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Süresi geçmiş ve kilitli bahis
-- ---------------------------------------------------------------------------

update public.bets set opens_at = now() - interval '2 hours', locks_at = now() - interval '1 minute'
where id = pg_temp.bet('s5');

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000003","role":"authenticated"}';

select throws_ok(
  $$select public.place_wager(pg_temp.bet('s5'), pg_temp.opt('s5', 1), 10)$$,
  'KB003', null, 'kapanış zamanı geçen bahse yatırım yapılamaz'
);

set local role postgres;

select throws_ok(
  $$select private.settle_bet(pg_temp.bet('s1'), pg_temp.opt('s1', 1), 'c0000000-0000-4000-8000-000000000002')$$,
  'KB005', null, 'yatırıma açık bahis sonuçlandırılamaz'
);

do $$ begin perform private.lock_bet(pg_temp.bet('s1')); end $$;

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000007","role":"authenticated"}';

select throws_ok(
  $$select public.place_wager(pg_temp.bet('s1'), pg_temp.opt('s1', 1), 10)$$,
  'KB003', null, 'kilitlenen bahse yatırım yapılamaz'
);

-- ---------------------------------------------------------------------------
-- Sonuçlandırma: s1 (Ali 100 Evet, Can 300 Evet, Deniz 200 Hayır; havuz 600)
-- ---------------------------------------------------------------------------

set local role postgres;

select lives_ok(
  $$select private.settle_bet(pg_temp.bet('s1'), pg_temp.opt('s1', 1), 'c0000000-0000-4000-8000-000000000002')$$,
  'kilitli bahis sonuçlandırılır'
);

select is(
  pg_temp.payouts('s1'),
  array[150, 450, 0]::bigint[],
  'kazananlar havuzu yatırımları oranında paylaşır (Ali 150, Can 450, Deniz 0)'
);

select is(
  (select sum(payout) from public.wagers where bet_id = pg_temp.bet('s1')),
  (select pool_total from public.bets where id = pg_temp.bet('s1'))::numeric,
  'dağıtılan toplam havuza eşit'
);

select is(
  (select row(b.status, array_agg(o.is_winner order by o.position))::text
   from public.bets b join public.bet_options o on o.bet_id = b.id
   where b.id = pg_temp.bet('s1') group by b.status),
  '(settled,"{t,f}")',
  'bahis sonuçlandı, kazanan seçenek işaretlendi'
);

select is(
  (select row(l.amount, l.actor_id)::text
   from public.ledger_entries l join public.wagers w on w.id = l.ref_id
   where l.reason = 'bet_payout' and w.bet_id = pg_temp.bet('s1') and w.user_id = 'c0000000-0000-4000-8000-000000000003'),
  '(450,c0000000-0000-4000-8000-000000000002)',
  'ödeme ledger''a sonuçlandıranla birlikte yazılır'
);

select throws_ok(
  $$select private.settle_bet(pg_temp.bet('s1'), pg_temp.opt('s1', 2), 'c0000000-0000-4000-8000-000000000002')$$,
  'KB006', null, 'sonuçlanmış bahis tekrar sonuçlandırılamaz'
);

select throws_ok(
  $$select private.cancel_bet(pg_temp.bet('s1'), 'sonradan iptal', 'c0000000-0000-4000-8000-000000000007')$$,
  'KB006', null, 'sonuçlanmış bahis iptal edilemez'
);

select throws_ok(
  $$select private.post_ledger('c0000000-0000-4000-8000-000000000001', 'SP', 150, 'bet_payout', 'wager',
      (select id from public.wagers where bet_id = pg_temp.bet('s1') and user_id = 'c0000000-0000-4000-8000-000000000001'),
      'c0000000-0000-4000-8000-000000000002')$$,
  '23505', null, 'bir yatırıma ikinci ödeme yazılamaz'
);

-- ---------------------------------------------------------------------------
-- Küsurat: s2 (Ali 1 X, Can 2 X, Deniz 2 Y; havuz 5, kazanan havuzu 3)
-- Ali 5/3 = 1,67 -> 1 + 1 (en büyük kesir), Can 10/3 = 3,33 -> 3
-- ---------------------------------------------------------------------------

do $$ begin
  perform private.lock_bet(pg_temp.bet('s2'));
  perform private.settle_bet(pg_temp.bet('s2'), pg_temp.opt('s2', 1), 'c0000000-0000-4000-8000-000000000007');
end $$;

select is(
  pg_temp.payouts('s2'),
  array[2, 3, 0]::bigint[],
  'küsurat kesirli payı en büyük olana verilir, havuzun tamamı dağıtılır'
);

-- ---------------------------------------------------------------------------
-- Kazanana kimse yatırmamış: s3 (Ali 100 X, Can 50 X; Y kazanır)
-- ---------------------------------------------------------------------------

do $$ begin
  perform private.lock_bet(pg_temp.bet('s3'));
  perform private.settle_bet(pg_temp.bet('s3'), pg_temp.opt('s3', 2), 'c0000000-0000-4000-8000-000000000007');
end $$;

select is(
  pg_temp.payouts('s3'),
  array[100, 50]::bigint[],
  'kazanan seçeneğe kimse yatırmadıysa herkes yatırdığını geri alır'
);

select is(
  (select count(*)::int from public.ledger_entries l join public.wagers w on w.id = l.ref_id
   where w.bet_id = pg_temp.bet('s3') and l.reason = 'bet_refund'),
  2,
  'geri ödemeler iade olarak yazılır'
);

-- ---------------------------------------------------------------------------
-- İptal: s4 (Ali 100 X, Deniz 50 Y)
-- ---------------------------------------------------------------------------

select throws_ok(
  $$select private.cancel_bet(pg_temp.bet('s4'), ' ', 'c0000000-0000-4000-8000-000000000007')$$,
  '23514', null, 'gerekçesiz iptal edilemez'
);

select lives_ok(
  $$select private.cancel_bet(pg_temp.bet('s4'), 'Maç ertelendi', 'c0000000-0000-4000-8000-000000000007')$$,
  'açık bahis iptal edilir'
);

select is(
  (select row(b.status, b.cancel_reason, pg_temp.payouts('s4'))::text from public.bets b where b.id = pg_temp.bet('s4')),
  '(cancelled,"Maç ertelendi","{100,50}")',
  'iptalde herkes yatırdığını geri alır'
);

select throws_ok(
  $$select private.cancel_bet(pg_temp.bet('s4'), 'tekrar iptal', 'c0000000-0000-4000-8000-000000000007')$$,
  'KB006', null, 'iptal edilmiş bahis tekrar iptal edilemez'
);

select throws_ok(
  $$select private.lock_bet(pg_temp.bet('s4'))$$,
  'KB003', null, 'iptal edilmiş bahis kilitlenemez'
);

-- ---------------------------------------------------------------------------
-- Ali'nin görünümü ve bakiyesi
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';

select is(
  (select count(*)::int from public.wagers),
  5,
  'kişi kendi tüm yatırımlarını görür (s1, s2, s3, s4, o1)'
);

select is(
  (select array_agg(payout order by w.payout desc) from public.wagers w join public.bets b on b.id = w.bet_id
   where b.status in ('settled', 'cancelled')),
  array[150, 100, 100, 2]::bigint[],
  'kişi kendi ödemelerini görür'
);

-- 1000 - 100 + 150 (s1) - 1 + 2 (s2) - 100 + 100 (s3) - 100 + 100 (s4)
select is(
  (select sp_balance from public.balances where user_id = 'c0000000-0000-4000-8000-000000000001'),
  1051::bigint,
  'bakiye tüm yatırım ve ödemelerin toplamı'
);

-- ---------------------------------------------------------------------------
-- Bütünlük
-- ---------------------------------------------------------------------------

set local role postgres;

select is_empty(
  $$select * from private.balance_mismatches()$$,
  'önbellekteki bakiye ledger toplamına eşit'
);

select is_empty(
  $$select id from (
      select id, balance_after, sum(amount) over (partition by user_id, currency order by id) as running
      from public.ledger_entries
    ) t where balance_after <> running$$,
  'her ledger satırının balance_after değeri o ana kadarki toplam'
);

select is_empty(
  $$select b.id from public.bets b join public.wagers w on w.bet_id = b.id
    where (b.status = 'cancelled' or (b.status = 'settled' and b.odds_mode = 'pool'))
    group by b.id, b.pool_total
    having sum(w.payout) <> b.pool_total or count(w.payout) <> count(*)$$,
  'sonuçlanan havuz bahislerinde ve iptallerde dağıtılan toplam havuza eşit, ödemesiz yatırım yok'
);

select is_empty(
  $$select b.id from public.bets b
    where b.pool_total <> coalesce((select sum(o.pool_amount) from public.bet_options o where o.bet_id = b.id), 0)
       or b.pool_total <> coalesce((select sum(w.amount) from public.wagers w where w.bet_id = b.id), 0)$$,
  'havuz toplamı seçenek toplamlarına ve yatırımların toplamına eşit'
);

select throws_ok(
  $$update public.ledger_entries set amount = 1 where reason = 'bet_payout'$$,
  '55000', null, 'bahis ödemeleri ledger''da değiştirilemez'
);

select * from finish();
rollback;
