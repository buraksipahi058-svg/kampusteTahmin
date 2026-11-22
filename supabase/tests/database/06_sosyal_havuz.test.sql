-- Adım 7 testleri: sosyal havuz (hakem, itiraz penceresi, moderatör, ihtar, zamanlanmış iş).
-- Tek transaction içinde çalışır ve sonunda geri alınır.
--
-- A okulu: Ali, Veli (G grubunun üyeleri), Can, Deniz, Mod (yetkili: kullanici_bahsi_denetle),
--          Yeni (okul maili doğrulanmamış). B okulu: Zeynep. Herkes 1000 SP ile başlar.
-- Ayarlar: kişi başı en fazla 100 SP, itiraz penceresi 12 saat, hakem süresi 7 gün, 3 ihtar.

begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(54);

-- ---------------------------------------------------------------------------
-- Hazırlık
-- ---------------------------------------------------------------------------

update public.economy_settings
set signup_bonus_sp = 1000, social_max_stake_sp = 100, social_dispute_hours = 12,
    social_result_deadline_days = 7, referee_strike_limit = 3;

insert into public.clusters (id, name, type) values
  ('a0000000-0000-4000-8000-000000000001', 'Test Üniversitesi A', 'school'),
  ('b0000000-0000-4000-8000-000000000001', 'Test Üniversitesi B', 'school');
insert into public.clusters (id, name, type, parent_cluster_id) values
  ('a0000000-0000-4000-8000-000000000003', 'A Arkadaş Grubu', 'group', 'a0000000-0000-4000-8000-000000000001');

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
    ('c0000000-0000-4000-8000-000000000005', 'Mod', 'a0000000-0000-4000-8000-000000000001'),
    ('c0000000-0000-4000-8000-000000000006', 'Yeni', 'a0000000-0000-4000-8000-000000000001'),
    ('c0000000-0000-4000-8000-000000000007', 'Zeynep', 'b0000000-0000-4000-8000-000000000001')
  ) as v(id, ad, okul) loop
    perform set_config('request.jwt.claims', json_build_object('sub', r.id, 'role', 'authenticated')::text, true);
    perform public.create_profile(r.ad, 'Test', r.okul);
  end loop;
end $$;

update public.profile_private
set student_email = user_id::text || '@ogr.test.edu.tr', student_email_verified_at = now()
where user_id::text like 'c0000000-0000-4000-8000-00000000000_' and user_id <> 'c0000000-0000-4000-8000-000000000006';

insert into public.user_clusters (user_id, cluster_id) values
  ('c0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000003'),
  ('c0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000003');

update public.profiles set role = 'yetkili' where id = 'c0000000-0000-4000-8000-000000000005';
insert into public.permissions (user_id, cluster_id, permission_key, granted_by) values
  ('c0000000-0000-4000-8000-000000000005', 'a0000000-0000-4000-8000-000000000001', 'kullanici_bahsi_denetle',
   'c0000000-0000-4000-8000-000000000005');

create temp table t (k text primary key, id uuid not null) on commit drop;
grant select, insert on t to authenticated;
create function pg_temp.bet(p_k text) returns uuid language sql stable as $$ select id from t where k = p_k $$;
create function pg_temp.opt(p_k text, p_position int) returns uuid language sql stable as
  $$ select o.id from public.bet_options o join t on t.id = o.bet_id where t.k = p_k and o.position = p_position $$;
create function pg_temp.payouts(p_k text) returns bigint[] language sql stable as
  $$ select array_agg(w.payout order by w.user_id) from public.wagers w where w.bet_id = (select id from t where k = p_k) $$;
create function pg_temp.strikes(p_uid uuid) returns int language sql stable as
  $$ select referee_strikes from public.profiles where id = p_uid $$;

-- ---------------------------------------------------------------------------
-- Açma (Ali)
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';

select lives_ok(
  $$insert into t values ('s1', public.create_social_bet('a0000000-0000-4000-8000-000000000001',
      'Yarın yemekhanede pilav çıkar mı?', null, array['Evet', 'Hayır'], now() + interval '1 hour'))$$,
  'doğrulanmış öğrenci okulunda sosyal bahis açar'
);

select is(
  (select row(type, scope, settlement_mode, referee_id, max_stake, odds_mode)::text from public.bets where id = pg_temp.bet('s1')),
  '(sp_social,school,referee,c0000000-0000-4000-8000-000000000001,100,pool)',
  'hakem varsayılan olarak açan, kişi başı sınır ayardaki üst sınır, havuz sistemi'
);

select lives_ok(
  $$insert into t values ('s2', public.create_social_bet('a0000000-0000-4000-8000-000000000001',
      'Final sınavı ertelenir mi?', null, array['Evet', 'Hayır'], now() + interval '1 hour',
      'c0000000-0000-4000-8000-000000000002', 50))$$,
  'başka bir okul arkadaşı hakem seçilebilir'
);

select lives_ok(
  $$insert into t values ('g1', public.create_social_bet('a0000000-0000-4000-8000-000000000003',
      'Grup maçını kim kazanır?', null, array['Biz', 'Onlar'], now() + interval '1 hour'))$$,
  'üyesi olunan grupta sosyal bahis açılır'
);

select is((select scope from public.bets where id = pg_temp.bet('g1')), 'private'::public.bet_scope, 'grup bahsi özel kapsamlıdır');

select throws_ok(
  $$select public.create_social_bet('a0000000-0000-4000-8000-000000000001', 'Başka okuldan hakem', null,
      array['A', 'B'], now() + interval '1 hour', 'c0000000-0000-4000-8000-000000000007')$$,
  '23514', null, 'hakem bahsin kümesinin üyesi olmalı'
);

select throws_ok(
  $$select public.create_social_bet('a0000000-0000-4000-8000-000000000001', 'Doğrulanmamış hakem', null,
      array['A', 'B'], now() + interval '1 hour', 'c0000000-0000-4000-8000-000000000006')$$,
  '23514', null, 'hakemin okul maili doğrulanmış olmalı'
);

select throws_ok(
  $$select public.create_social_bet('a0000000-0000-4000-8000-000000000001', 'Büyük bahis', null,
      array['A', 'B'], now() + interval '1 hour', null, 500)$$,
  '23514', null, 'kişi başı sınır ayardaki üst sınırı aşamaz'
);

select throws_ok(
  $$select public.create_social_bet('a0000000-0000-4000-8000-000000000001', 'Çok uzak bahis', null,
      array['A', 'B'], now() + interval '40 days')$$,
  '23514', null, 'kapanış en fazla 30 gün sonra'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000003","role":"authenticated"}';

select throws_ok(
  $$select public.create_social_bet('a0000000-0000-4000-8000-000000000003', 'Gruba sızma', null,
      array['A', 'B'], now() + interval '1 hour')$$,
  'P0002', null, 'üye olunmayan grupta bahis açılamaz'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000006","role":"authenticated"}';

select throws_ok(
  $$select public.create_social_bet('a0000000-0000-4000-8000-000000000001', 'Doğrulanmamış bahis', null,
      array['A', 'B'], now() + interval '1 hour')$$,
  'KB002', null, 'okul maili doğrulanmamış kişi sosyal bahis açamaz'
);

-- ---------------------------------------------------------------------------
-- Yatırımlar
-- ---------------------------------------------------------------------------

set local role postgres;
do $$
declare r record;
begin
  for r in select * from (values
    ('c0000000-0000-4000-8000-000000000002'::uuid, 's1', 1, 100::bigint),
    ('c0000000-0000-4000-8000-000000000003', 's1', 2, 50),
    ('c0000000-0000-4000-8000-000000000004', 's1', 1, 60),
    ('c0000000-0000-4000-8000-000000000004', 's2', 1, 30),
    ('c0000000-0000-4000-8000-000000000003', 's2', 2, 20),
    ('c0000000-0000-4000-8000-000000000002', 'g1', 1, 40)
  ) as v(uid, k, pos, amount) loop
    perform set_config('request.jwt.claims', json_build_object('sub', r.uid, 'role', 'authenticated')::text, true);
    perform public.place_wager(pg_temp.bet(r.k), pg_temp.opt(r.k, r.pos), r.amount);
  end loop;
end $$;
set local role authenticated;

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';
select throws_ok(
  $$select public.place_wager(pg_temp.bet('s1'), pg_temp.opt('s1', 1), 10)$$,
  '42501', null, 'hakem kendi sosyal bahsine yatırım yapamaz'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000005","role":"authenticated"}';
select throws_ok(
  $$select public.place_wager(pg_temp.bet('s2'), pg_temp.opt('s2', 1), 51)$$,
  '23514', null, 'bahsin kişi başı sınırı aşılamaz'
);

-- ---------------------------------------------------------------------------
-- Sonuç girme (s1, hakem Ali)
-- ---------------------------------------------------------------------------

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000002","role":"authenticated"}';
select throws_ok(
  $$select public.submit_social_result(pg_temp.bet('s1'), pg_temp.opt('s1', 1))$$,
  '42501', null, 'hakem olmayan sonuç giremez'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';
select ok(
  (select public.submit_social_result(pg_temp.bet('s1'), pg_temp.opt('s1', 1))) > now() + interval '11 hours',
  'hakem sonucu girer, 12 saatlik itiraz penceresi başlar'
);

select is(
  (select row(status, proposed_option_id = pg_temp.opt('s1', 1))::text from public.bets where id = pg_temp.bet('s1')),
  '(settling,t)',
  'bahis sonuç bekliyor durumuna geçer'
);

select throws_ok(
  $$select public.submit_social_result(pg_temp.bet('s1'), pg_temp.opt('s1', 2))$$,
  'KB015', null, 'sonuç ikinci kez girilemez'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000005","role":"authenticated"}';
select throws_ok(
  $$select public.place_wager(pg_temp.bet('s1'), pg_temp.opt('s1', 1), 10)$$,
  'KB003', null, 'sonuç girilen bahse yatırım yapılamaz'
);

-- ---------------------------------------------------------------------------
-- İtiraz
-- ---------------------------------------------------------------------------

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';
select throws_ok(
  $$select public.dispute_social_result(pg_temp.bet('s1'), 'yanlış')$$,
  '42501', null, 'yatırım yapmayan itiraz edemez'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000003","role":"authenticated"}';
select lives_ok(
  $$select public.dispute_social_result(pg_temp.bet('s1'), 'Yemekhanede pilav değil makarna vardı')$$,
  'yatırım yapan itiraz eder'
);

select throws_ok(
  $$select public.dispute_social_result(pg_temp.bet('s1'), 'tekrar itiraz')$$,
  '23505', null, 'aynı kişi ikinci kez itiraz edemez'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000004","role":"authenticated"}';
select is((select count(*)::int from public.bet_disputes), 0, 'başkasının itirazı görünmez');

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';
select is((select count(*)::int from public.bet_disputes where bet_id = pg_temp.bet('s1')), 1, 'hakem sonucuna yapılan itirazı görür');

set local role postgres;
update public.bets set dispute_until = now() - interval '1 second' where id = pg_temp.bet('s1');
select is(private.finalize_social_bet(pg_temp.bet('s1')), false, 'açık itirazı olan sonuç kendiliğinden kesinleşmez');

-- ---------------------------------------------------------------------------
-- Moderatör kararı: sonuç değişir (Hayır kazandı)
-- s1: Veli 100 Evet, Can 50 Hayır, Deniz 60 Evet; havuz 210
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000002","role":"authenticated"}';
select throws_ok(
  $$select public.resolve_social_dispute(pg_temp.bet('s1'), 'confirmed', 'onaylıyorum')$$,
  '42501', null, 'izni olmayan itirazı çözemez'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000005","role":"authenticated"}';
select throws_ok(
  $$select public.resolve_social_dispute(pg_temp.bet('s1'), 'confirmed', ' ')$$,
  '23514', null, 'moderatör kararını gerekçesiz veremez'
);

select throws_ok(
  $$select public.resolve_social_dispute(pg_temp.bet('s1'), 'changed', 'aynı sonuç', pg_temp.opt('s1', 1))$$,
  '23514', null, 'değiştirme kararında hakemden farklı seçenek seçilmeli'
);

select lives_ok(
  $$select public.resolve_social_dispute(pg_temp.bet('s1'), 'changed', 'Fotoğrafa göre makarna vardı', pg_temp.opt('s1', 2))$$,
  'moderatör sonucu değiştirir'
);

set local role postgres;

select is(pg_temp.payouts('s1'), array[0, 210, 0]::bigint[], 'havuz moderatörün sonucuna göre dağıtılır (Can 210)');
select is(pg_temp.strikes('c0000000-0000-4000-8000-000000000001'), 1, 'sonucu değişen hakeme ihtar yazılır');

select is(
  (select row(status, decision, resolved_by)::text from public.bet_disputes where bet_id = pg_temp.bet('s1')),
  '(resolved,changed,c0000000-0000-4000-8000-000000000005)',
  'itiraz kararla kapanır'
);

select is(
  (select count(*)::int from public.admin_audit_log where action = 'social_dispute_resolve'
     and details ->> 'bet_id' = pg_temp.bet('s1')::text and target_user_id = 'c0000000-0000-4000-8000-000000000001'),
  1,
  'karar denetim kaydına hakemle birlikte yazılır'
);

set local role authenticated;
select throws_ok(
  $$select public.resolve_social_dispute(pg_temp.bet('s1'), 'confirmed', 'tekrar karar')$$,
  'KB017', null, 'açık itirazı kalmayan bahiste karar verilemez'
);

-- ---------------------------------------------------------------------------
-- İtirazsız sonuç zamanlanmış işle kesinleşir (s2, hakem Veli)
-- s2: Deniz 30 Evet, Can 20 Hayır; havuz 50
-- ---------------------------------------------------------------------------

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000002","role":"authenticated"}';
do $$ begin perform public.submit_social_result(pg_temp.bet('s2'), pg_temp.opt('s2', 1)); end $$;

set local role postgres;
select is(private.finalize_social_bet(pg_temp.bet('s2')), false, 'itiraz penceresi bitmeden kesinleşmez');

update public.bets set dispute_until = now() - interval '1 second' where id = pg_temp.bet('s2');
select ok(private.process_social_bets() >= 1, 'zamanlanmış iş süresi dolan sonucu işler');

select is(
  (select row(b.status, pg_temp.payouts('s2'))::text from public.bets b where b.id = pg_temp.bet('s2')),
  '(settled,"{0,50}")',
  'itirazsız sonuç kesinleşir, havuz dağıtılır (Can 0, Deniz 50)'
);

-- ---------------------------------------------------------------------------
-- Hakem süresinde sonuç girmezse iptal + iade + ihtar (g1, hakem Ali; Veli 40)
-- ---------------------------------------------------------------------------

update public.bets set opens_at = now() - interval '10 days', locks_at = now() - interval '8 days'
where id = pg_temp.bet('g1');

select ok(private.process_social_bets() >= 1, 'zamanlanmış iş süresi geçen bahsi işler');

select is(
  (select row(status, cancel_reason, pg_temp.payouts('g1'))::text from public.bets where id = pg_temp.bet('g1')),
  '(cancelled,"Hakem süresi içinde sonuç girmedi",{40})',
  'sonuç girilmeyen bahis iptal edilir, yatırım iade edilir'
);

select is(pg_temp.strikes('c0000000-0000-4000-8000-000000000001'), 2, 'sonuç girmeyen hakeme ihtar yazılır');

-- ---------------------------------------------------------------------------
-- İhtar sınırı
-- ---------------------------------------------------------------------------

update public.profiles set referee_strikes = 3 where id = 'c0000000-0000-4000-8000-000000000001';
set local role authenticated;

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';
select throws_ok(
  $$select public.create_social_bet('a0000000-0000-4000-8000-000000000001', 'Kısıtlı açan', null,
      array['A', 'B'], now() + interval '1 hour')$$,
  'KB014', null, 'ihtar sınırına ulaşan sosyal bahis açamaz'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000002","role":"authenticated"}';
select throws_ok(
  $$select public.create_social_bet('a0000000-0000-4000-8000-000000000001', 'Kısıtlı hakem', null,
      array['A', 'B'], now() + interval '1 hour', 'c0000000-0000-4000-8000-000000000001')$$,
  'KB014', null, 'ihtar sınırına ulaşan hakem seçilemez'
);

select throws_ok(
  $$update public.profiles set referee_strikes = 0 where id = 'c0000000-0000-4000-8000-000000000001'$$,
  '42501', null, 'kullanıcı ihtar sayısını değiştiremez'
);

-- ---------------------------------------------------------------------------
-- Moderatörün grup bahislerini görmesi
-- ---------------------------------------------------------------------------

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000005","role":"authenticated"}';
select is((select count(*)::int from public.bets where id = pg_temp.bet('g1')), 1, 'moderatör üyesi olmadığı grubun bahsini görür');

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000003","role":"authenticated"}';
select is((select count(*)::int from public.bets where id = pg_temp.bet('g1')), 0, 'izinsiz öğrenci üyesi olmadığı grubun bahsini görmez');

-- ---------------------------------------------------------------------------
-- İptal
-- ---------------------------------------------------------------------------

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000004","role":"authenticated"}';
select lives_ok(
  $$insert into t values ('s3', public.create_social_bet('a0000000-0000-4000-8000-000000000001',
      'Geri çekilecek bahis', null, array['A', 'B'], now() + interval '1 hour'))$$,
  'Deniz bahis açar'
);
select lives_ok(
  $$select public.cancel_social_bet(pg_temp.bet('s3'), 'Yanlış açtım')$$,
  'açan, yatırım yokken bahsini geri çeker'
);

select lives_ok(
  $$insert into t values ('s4', public.create_social_bet('a0000000-0000-4000-8000-000000000001',
      'Yatırımlı bahis', null, array['A', 'B'], now() + interval '1 hour'))$$,
  'Deniz ikinci bahsi açar'
);
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000002","role":"authenticated"}';
do $$ begin perform public.place_wager(pg_temp.bet('s4'), pg_temp.opt('s4', 1), 10); end $$;

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000004","role":"authenticated"}';
select throws_ok(
  $$select public.cancel_social_bet(pg_temp.bet('s4'), 'vazgeçtim')$$,
  '42501', null, 'yatırım varken açan bahsi geri çekemez'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000003","role":"authenticated"}';
select throws_ok(
  $$select public.cancel_social_bet(pg_temp.bet('s4'), 'beğenmedim')$$,
  '42501', null, 'başkası bahsi iptal edemez'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000005","role":"authenticated"}';
select lives_ok(
  $$select public.cancel_social_bet(pg_temp.bet('s4'), 'Uygunsuz içerik')$$,
  'moderatör bahsi iptal eder'
);

set local role postgres;
select is(pg_temp.payouts('s4'), array[10]::bigint[], 'moderatör iptalinde yatırım iade edilir');

-- ---------------------------------------------------------------------------
-- Bütünlük ve zamanlanmış iş
-- ---------------------------------------------------------------------------

select is_empty($$select * from private.balance_mismatches()$$, 'önbellekteki bakiye ledger toplamına eşit');

select is_empty(
  $$select b.id from public.bets b join public.wagers w on w.bet_id = b.id
    where b.type = 'sp_social' and b.status in ('settled', 'cancelled')
    group by b.id, b.pool_total
    having sum(w.payout) <> b.pool_total or count(w.payout) <> count(*)$$,
  'sonuçlanan ve iptal edilen sosyal bahislerde dağıtılan toplam havuza eşit'
);

select is(
  (select count(*)::int from cron.job where jobname = 'kampusbet_sosyal_bahisler' and schedule = '*/5 * * * *'),
  1,
  'sosyal bahis işi 5 dakikada bir çalışacak şekilde zamanlanmış'
);

select * from finish();
rollback;
