-- Adım 17 testleri: uygulama içi bildirimler (üreticiler, RLS, okundu, silme, temizlik).
-- Tek transaction içinde çalışır ve sonunda geri alınır.
--
-- A okulu: Ali, Veli, Can (öğrenci, doğrulanmış), Mod (yetkili: kullanici_bahsi_denetle), Süper (süperadmin).

begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
alter default privileges for role postgres grant execute on functions to public;

select plan(26);

-- ---------------------------------------------------------------------------
-- Hazırlık
-- ---------------------------------------------------------------------------

update public.economy_settings
set signup_bonus_sp = 1000, social_max_stake_sp = 100, social_dispute_hours = 12, referee_strike_limit = 3,
    trivia_question_count = 5, duel_max_stake_sp = 100;
insert into public.clusters (id, name, type) values ('a0000000-0000-4000-8000-000000000001', 'Test Üniversitesi A', 'school');

create function pg_temp.uid(p_n integer) returns uuid language sql immutable as
  $$ select ('c0000000-0000-4000-8000-' || lpad(p_n::text, 12, '0'))::uuid $$;
create function pg_temp.as_user(p_n integer) returns void language sql as
  $$ select set_config('request.jwt.claims', json_build_object('sub', pg_temp.uid(p_n), 'role', 'authenticated')::text, true) $$;

insert into auth.users (id, email, aud, role)
select pg_temp.uid(n), 'kisi' || n || '@test.local', 'authenticated', 'authenticated' from generate_series(1, 5) n;
do $$
declare r record;
begin
  for r in select * from (values (1, 'Ali'), (2, 'Veli'), (3, 'Can'), (4, 'Mod'), (5, 'Süper')) as v(n, ad) loop
    perform pg_temp.as_user(r.n);
    perform public.create_profile(r.ad, 'Test', 'a0000000-0000-4000-8000-000000000001');
  end loop;
end $$;
update public.profile_private
set student_email = 'kisi' || right(user_id::text, 1) || '@ogr.test.edu.tr', student_email_verified_at = now()
where user_id in (select pg_temp.uid(n) from generate_series(1, 5) n);
update public.profiles set role = 'yetkili' where id = pg_temp.uid(4);
update public.profiles set role = 'superadmin' where id = pg_temp.uid(5);
insert into public.permissions (user_id, cluster_id, permission_key, granted_by)
values (pg_temp.uid(4), 'a0000000-0000-4000-8000-000000000001', 'kullanici_bahsi_denetle', pg_temp.uid(5));

create temp table t (k text primary key, id uuid not null) on commit drop;
grant all on t to authenticated;
create function pg_temp.id(p_k text) returns uuid language sql stable as $$ select id from t where k = p_k $$;
create function pg_temp.opt(p_k text, p_label text) returns uuid language sql stable as
  $$ select o.id from public.bet_options o where o.bet_id = pg_temp.id(p_k) and o.label = p_label $$;
-- Kişinin bildirimleri "tür|başlık" olarak (postgres gözünden).
create function pg_temp.notes(p_n integer, p_kind text) returns text[] language sql stable as $$
  select coalesce(array_agg(kind || '|' || title order by id), '{}') from public.notifications
  where user_id = pg_temp.uid(p_n) and kind = p_kind
$$;

-- ---------------------------------------------------------------------------
-- Resmi bahis sonuçlanınca / iptal edilince katılanlara
-- ---------------------------------------------------------------------------

do $$
declare
  v_bet uuid;
begin
  v_bet := private.create_bet(pg_temp.uid(5), 'a0000000-0000-4000-8000-000000000001', 'ssp_official', 'school',
                              'Final kim kazanır?', null, array['A', 'B'], now() + interval '1 hour');
  insert into t values ('resmi', v_bet);
  perform private.post_ledger(pg_temp.uid(n), 'SSP', 200, 'admin_grant', null, null, pg_temp.uid(5), 'test için SSP')
  from generate_series(1, 3) n;
  perform private.stake_wager(v_bet, pg_temp.opt('resmi', 'A'), pg_temp.uid(1), 10);
  perform private.stake_wager(v_bet, pg_temp.opt('resmi', 'A'), pg_temp.uid(2), 10);
  perform private.stake_wager(v_bet, pg_temp.opt('resmi', 'B'), pg_temp.uid(3), 100);
  perform private.lock_bet(v_bet);
  perform private.settle_bet(v_bet, pg_temp.opt('resmi', 'A'), pg_temp.uid(5));

  v_bet := private.create_bet(pg_temp.uid(5), 'a0000000-0000-4000-8000-000000000001', 'ssp_official', 'school',
                              'Ertelenen maç', null, array['A', 'B'], now() + interval '1 hour');
  insert into t values ('iptal', v_bet);
  perform private.stake_wager(v_bet, pg_temp.opt('iptal', 'A'), pg_temp.uid(1), 5);
  perform private.cancel_bet(v_bet, 'Maç ertelendi', pg_temp.uid(5));
end $$;

select is(pg_temp.notes(1, 'bet_won'), array['bet_won|Kazandın! +50 SSP'], 'kazanana kazanç bildirimi');
select is(pg_temp.notes(3, 'bet_lost'), array['bet_lost|Bu sefer olmadı'], 'kaybedene bildirim');
select is((select body from public.notifications where user_id = pg_temp.uid(1) and kind = 'bet_won'),
          '«Final kim kazanır?» sonuçlandı. Sonuç: A.', 'bildirimde bahis ve sonuç yazar');
select is((select body from public.notifications where user_id = pg_temp.uid(1) and kind = 'bet_cancelled'),
          '«Ertelenen maç» iptal edildi; yatırımın iade edildi. Gerekçe: Maç ertelendi', 'iptal bildirimi gerekçeyle');
select is(pg_temp.notes(4, 'bet_won') || pg_temp.notes(5, 'bet_won'), '{}'::text[], 'katılmayana bildirim gitmez');

-- ---------------------------------------------------------------------------
-- Sosyal bahis: hakem hatırlatması, sonuç, itiraz, karar, ihtar
-- ---------------------------------------------------------------------------

set local role authenticated;
select pg_temp.as_user(1);
insert into t values ('sosyal', public.create_social_bet('a0000000-0000-4000-8000-000000000001', 'Yarın yağmur yağar mı?', '',
                                                         array['Evet', 'Hayır'], now() + interval '1 hour'));
select pg_temp.as_user(2);
select public.place_wager(pg_temp.id('sosyal'), pg_temp.opt('sosyal', 'Evet'), 20);
select pg_temp.as_user(3);
select public.place_wager(pg_temp.id('sosyal'), pg_temp.opt('sosyal', 'Hayır'), 20);

set local role postgres;
update public.bets set opens_at = now() - interval '2 minutes', locks_at = now() - interval '1 minute' where id = pg_temp.id('sosyal');
select private.process_notifications();
select private.process_notifications();
select is(pg_temp.notes(1, 'referee_due'), array['referee_due|Sonucu girme zamanı'],
          'kapanınca hakeme hatırlatma (iki çalıştırmada bir kez)');

set local role authenticated;
select pg_temp.as_user(1);
select public.submit_social_result(pg_temp.id('sosyal'), pg_temp.opt('sosyal', 'Evet'));
set local role postgres;
select is((select count(*)::int from public.notifications where kind = 'social_result'
           and user_id in (pg_temp.uid(2), pg_temp.uid(3))), 2, 'hakem sonucu girince katılanlara bildirim');

set local role authenticated;
select pg_temp.as_user(3);
select public.dispute_social_result(pg_temp.id('sosyal'), 'Yağmur yağmadı, sonuç yanlış');
set local role postgres;
select is(pg_temp.notes(1, 'dispute_received'), array['dispute_received|Sonucuna itiraz edildi'], 'hakeme itiraz bildirimi');
select is(pg_temp.notes(4, 'dispute_new'), array['dispute_new|Yeni itiraz'], 'okulun moderatörüne yeni itiraz bildirimi');
select is(pg_temp.notes(3, 'dispute_new'), '{}'::text[], 'itiraz edene moderatör bildirimi gitmez');

set local role authenticated;
select pg_temp.as_user(4);
select public.resolve_social_dispute(pg_temp.id('sosyal'), 'changed', 'Fotoğraflarla doğrulandı', pg_temp.opt('sosyal', 'Hayır'));
set local role postgres;
select is((select body from public.notifications where user_id = pg_temp.uid(3) and kind = 'dispute_resolved'),
          '«Yarın yağmur yağar mı?»: sonuç değiştirildi. Not: Fotoğraflarla doğrulandı', 'itiraz edene karar bildirimi');
select is(pg_temp.notes(1, 'referee_strike'), array['referee_strike|Hakem ihtarı aldın'], 'kararı değişen hakeme ihtar bildirimi');
select is(pg_temp.notes(3, 'bet_won'), array['bet_won|Kazandın! +20 SP'], 'değişen sonuçla kazanana bildirim');

-- ---------------------------------------------------------------------------
-- Düello, seviye, yönetici işlemi
-- ---------------------------------------------------------------------------

set local role authenticated;
select pg_temp.as_user(1);
insert into t values ('duello', public.create_trivia_duel(10, pg_temp.uid(2)));
set local role postgres;
select is((select body from public.notifications where user_id = pg_temp.uid(2) and kind = 'duel_invite'),
          'Ali Test seni 10 SP''lik trivia düellosuna çağırdı.', 'davet edilene meydan okuma bildirimi');
set local role authenticated;
select pg_temp.as_user(2);
select public.accept_trivia_duel(pg_temp.id('duello'));
set local role postgres;
select is((select body from public.notifications where user_id = pg_temp.uid(1) and kind = 'duel_accepted'),
          'Veli Test düellonu kabul etti. Sıra sende!', 'meydan okuyana kabul bildirimi');

update public.profiles set level = 2 where id = pg_temp.uid(2);
select is(pg_temp.notes(2, 'level_up'), array['level_up|Seviye 2!'], 'seviye atlayınca bildirim');

set local role authenticated;
select pg_temp.as_user(5);
select public.admin_grant(pg_temp.uid(3), 'SSP', 50, 'Turnuva ödülü');
set local role postgres;
select is((select title || ' / ' || body from public.notifications where user_id = pg_temp.uid(3) and kind = 'admin_grant'
             and title like '%50 SSP%'),
          'Hesabına 50 SSP eklendi / Turnuva ödülü', 'yönetici SSP verince bildirim');

-- ---------------------------------------------------------------------------
-- RLS, okundu, silme, temizlik
-- ---------------------------------------------------------------------------

set local role anon;
select throws_ok($$select count(*) from public.notifications$$, '42501', null, 'anonim bildirim okuyamaz');
select throws_ok($$select public.mark_notifications_read()$$, '42501', null, 'anonim okundu işaretleyemez');

set local role postgres;
create temp table nid on commit drop as select id from public.notifications where user_id = pg_temp.uid(1) limit 1;
grant select on nid to authenticated;
set local role authenticated;
select pg_temp.as_user(3);
select is((select count(*)::int from public.notifications where user_id <> pg_temp.uid(3)), 0,
          'kişi yalnızca kendi bildirimlerini görür');
select throws_ok($$insert into public.notifications (user_id, kind, title, body) values ('c0000000-0000-4000-8000-000000000003', 'level_up', 'x', 'y')$$,
                 '42501', null, 'istemci bildirim yazamaz');
select is(public.mark_notifications_read(array(select id from public.notifications where kind = 'bet_lost')), 1,
          'seçilen bildirim okundu işaretlenir');
select is(public.mark_notifications_read(array(select id from nid)), 0, 'başkasının bildirimi işaretlenmez');
select is(public.mark_notifications_read() >= 1, true, 'hepsi okundu işaretlenir');
select is((select count(*)::int from public.notifications where read_at is null), 0, 'okunmamış kalmaz');

set local role postgres;
update public.notifications set created_at = now() - interval '100 days' where user_id = pg_temp.uid(1) and kind = 'bet_cancelled';
select private.process_notifications();
update public.profiles set deleted_at = now() where id = pg_temp.uid(2);
select is((select count(*)::int from public.notifications
           where (user_id = pg_temp.uid(1) and kind = 'bet_cancelled') or user_id = pg_temp.uid(2)), 0,
          '90 günden eski bildirim ve silinen hesabın bildirimleri silinir');

select * from finish();
rollback;
