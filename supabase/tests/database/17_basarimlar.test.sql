-- Adım 16 testleri: başarımlar (katalog, RLS, ilerleme, gizli başarım, ödül alma, XP, nadirlik) ve günlük ödül takvimi.
-- Tek transaction içinde çalışır ve sonunda geri alınır.
--
-- A okulu: Ali, Veli, Can (öğrenci), Süper (süperadmin), Silik (silinmiş). B okulu: Zeynep.
-- Süper'in havuzlu resmi bahsi: Ali "A"ya 10, Veli ve Can "B"ye 100'er SSP; "A" kazanır → Ali ters köşe yapar.

begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
alter default privileges for role postgres grant execute on functions to public;

select plan(32);

-- ---------------------------------------------------------------------------
-- Hazırlık
-- ---------------------------------------------------------------------------

update public.economy_settings
set signup_bonus_sp = 1000, daily_base_sp = 50, daily_step_sp = 10, daily_max_sp = 150,
    streak_milestones = '{"7": 200, "14": 500, "30": 1500}', xp_daily_login = 10;
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
    (3, 'Can', 'a0000000-0000-4000-8000-000000000001'), (4, 'Süper', 'a0000000-0000-4000-8000-000000000001'),
    (5, 'Silik', 'a0000000-0000-4000-8000-000000000001'), (7, 'Zeynep', 'b0000000-0000-4000-8000-000000000001')
  ) as v(n, ad, okul) loop
    perform pg_temp.as_user(r.n);
    perform public.create_profile(r.ad, 'Test', r.okul);
  end loop;
end $$;

update public.profile_private
set student_email = 'kisi' || right(user_id::text, 1) || '@ogr.test.edu.tr', student_email_verified_at = now()
where user_id in (select pg_temp.uid(n) from generate_series(1, 7) n);
update public.profiles set role = 'superadmin' where id = pg_temp.uid(4);
update public.profiles set deleted_at = now() where id = pg_temp.uid(5);

create function pg_temp.metric(p_user integer, p_metric text) returns bigint language sql as $$
  select m.value from private.achievement_metrics(pg_temp.uid(p_user)) m where m.metric = p_metric
$$;

-- ---------------------------------------------------------------------------
-- Katalog ve RLS
-- ---------------------------------------------------------------------------

set local role anon;
select throws_ok($$select count(*) from public.achievements$$, '42501', null, 'anonim başarım kataloğunu okuyamaz');

set local role authenticated;
select pg_temp.as_user(1);
select is((select count(*)::int from public.achievements where active), 25, 'giriş yapan kataloğu okur (25 başarım)');
select throws_ok(
  $$insert into public.achievement_unlocks (user_id, achievement_id, reward_sp, reward_xp)
    select 'c0000000-0000-4000-8000-000000000001', id, 1, 0 from public.achievements limit 1$$,
  '42501', null, 'istemci kendine başarım ekleyemez');

-- ---------------------------------------------------------------------------
-- İlerleme ve gizli başarım
-- ---------------------------------------------------------------------------

set local role anon;
select throws_ok($$select * from public.my_achievements()$$, '42501', null, 'anonim başarımlarını göremez');
set local role authenticated;
select pg_temp.as_user(5);
select throws_ok($$select * from public.my_achievements()$$, 'P0002', null, 'silinmiş hesap başarım göremez');

select pg_temp.as_user(1);
select is((select claimable from public.my_achievements() where key = 'kampuslu'), true,
          'okul maili doğrulanınca "Kampüslü" kazanılır');
select is((select title || '|' || icon || '|' || coalesce(metric, '-') from public.my_achievements() where key = 'ters_kose'),
          'Gizli başarım|❓|-', 'gizli başarımın adı, simgesi ve ölçütü kazanılana dek gizli');

set local role postgres;
do $$
declare
  v_bet uuid;
  v_a uuid;
  v_b uuid;
begin
  v_bet := private.create_bet(pg_temp.uid(4), 'a0000000-0000-4000-8000-000000000001', 'ssp_official', 'school',
                              'Havuzlu bahis', null, array['A', 'B'], now() + interval '1 hour');
  select id into v_a from public.bet_options where bet_id = v_bet and position = 1;
  select id into v_b from public.bet_options where bet_id = v_bet and position = 2;
  perform private.post_ledger(pg_temp.uid(n), 'SSP', 200, 'admin_grant', null, null, pg_temp.uid(4), 'test için SSP')
  from generate_series(1, 3) n;
  perform private.stake_wager(v_bet, v_a, pg_temp.uid(1), 10);
  perform private.stake_wager(v_bet, v_b, pg_temp.uid(2), 100);
  perform private.stake_wager(v_bet, v_b, pg_temp.uid(3), 100);
  perform private.lock_bet(v_bet);
  perform private.settle_bet(v_bet, v_a, pg_temp.uid(4));
end $$;

select is(pg_temp.metric(1, 'correct') || '/' || pg_temp.metric(1, 'underdog_wins') || '/' || pg_temp.metric(1, 'official_wins'),
          '1/1/1', 'doğru, ters köşe ve resmi galibiyet sayılır');
select is(pg_temp.metric(3, 'predictions') || '/' || pg_temp.metric(3, 'correct') || '/' || pg_temp.metric(3, 'best_streak'),
          '1/0/0', 'kaybeden: tahmin sayılır, doğru ve seri sayılmaz');

set local role authenticated;
select pg_temp.as_user(1);
select is((select progress || '/' || target || '/' || claimable from public.my_achievements() where key = 'ilk_tahmin'),
          '1/1/true', 'ilk sonuçlanan tahminle "İlk Adım" kazanılır');
select is((select title || '|' || claimable from public.my_achievements() where key = 'ters_kose'),
          'Ters Köşe|true', 'gizli başarım kazanılınca açılır');
select is((select progress || '/' || target || '/' || claimable from public.my_achievements() where key = 'tahminci'),
          '1/10/false', 'hedefe ulaşmayan başarım alınamaz, ilerlemesi görünür');

-- ---------------------------------------------------------------------------
-- Ödül alma
-- ---------------------------------------------------------------------------

select throws_ok($$select * from public.claim_achievement('tahminci')$$, 'KB027', null, 'kazanılmamış başarımın ödülü alınamaz');
select throws_ok($$select * from public.claim_achievement('yok_boyle')$$, 'P0002', null, 'olmayan başarım');
select is((select reward_sp || '/' || reward_xp from public.claim_achievement('ilk_tahmin')), '20/10',
          'kazanılan başarımın ödülü alınır (20 SP, 10 XP)');
select throws_ok($$select * from public.claim_achievement('ilk_tahmin')$$, 'KB028', null, 'aynı başarımın ödülü iki kez alınamaz');

set local role postgres;
select is((select count(*)::int from public.ledger_entries l join public.achievements a on a.id = l.ref_id
           where l.user_id = pg_temp.uid(1) and l.reason = 'achievement_reward' and l.ref_type = 'achievement'
             and a.key = 'ilk_tahmin' and l.amount = 20 and l.currency = 'SP'), 1, 'ödül ledger''a SP olarak yazılır');
select is((select count(*)::int from public.xp_events e join public.ledger_entries l on l.id = e.ledger_entry_id
           where e.user_id = pg_temp.uid(1) and e.reason = 'achievement' and e.amount = 10
             and l.reason = 'achievement_reward'), 1, 'XP ledger kaydından gelir');
select throws_ok($$update public.achievement_unlocks set reward_sp = 999$$, '55000', null, 'kazanılan başarımlar değiştirilemez');

set local role authenticated;
select pg_temp.as_user(1);
select is((select (unlocked_at is not null) || '/' || claimable || '/' || school_rate from public.my_achievements() where key = 'ilk_tahmin'),
          'true/false/0.250', 'açılan başarım: tarihli, yeniden alınamaz, okulun dörtte biri kazandı');

select pg_temp.as_user(2);
select is((select count(*)::int from public.achievement_unlocks where user_id = pg_temp.uid(1)), 1,
          'okul arkadaşı kazanılan başarımı görür (profil)');
select pg_temp.as_user(7);
select is((select count(*)::int from public.achievement_unlocks where user_id = pg_temp.uid(1)), 0,
          'başka okul göremez');

set local role anon;
select throws_ok($$select * from public.claim_achievement('kampuslu')$$, '42501', null, 'anonim ödül alamaz');

-- ---------------------------------------------------------------------------
-- Günlük ödül takvimi
-- ---------------------------------------------------------------------------

select throws_ok($$select * from public.daily_login_calendar()$$, '42501', null, 'anonim takvimi göremez');

set local role authenticated;
select pg_temp.as_user(1);
select is((select array_agg(day || ':' || amount || ':' || bonus order by day) from public.daily_login_calendar()),
          array['1:50:0', '2:60:0', '3:70:0', '4:80:0', '5:90:0', '6:100:0', '7:110:200'],
          'ilk giriş: 1-7. günler, artan ödül, 7. gün bonusu');
select is((select day || ':' || claimed from public.daily_login_calendar() where is_today), '1:false',
          'bugün 1. gün, ödül alınmadı');
select is((select claimed from public.claim_daily_login()), true, 'günlük ödül alınır');
select is((select day || ':' || claimed from public.daily_login_calendar() where is_today), '1:true',
          'alınınca bugün işaretli');

set local role postgres;
insert into public.login_streaks (user_id, current_streak, longest_streak, last_login_date)
values (pg_temp.uid(2), 13, 13, (now() at time zone 'Europe/Istanbul')::date - 1)
on conflict (user_id) do update set current_streak = 13, longest_streak = 13, last_login_date = excluded.last_login_date;
set local role authenticated;
select pg_temp.as_user(2);
select is((select array_agg(day order by day) from public.daily_login_calendar()), array[8, 9, 10, 11, 12, 13, 14],
          'seri sürüyorsa takvim serinin haftasını gösterir');
select is((select day || ':' || amount || ':' || bonus || ':' || claimed from public.daily_login_calendar() where is_today),
          '14:150:500:false', 'bugün 14. gün: üst sınırda ödül ve 14. gün bonusu');

set local role postgres;
update public.login_streaks set current_streak = 9, last_login_date = (now() at time zone 'Europe/Istanbul')::date - 3
where user_id = pg_temp.uid(2);
set local role authenticated;
select is((select day from public.daily_login_calendar() where is_today), 1, 'seri koptuysa 1. günden başlar');

set local role postgres;
select is((select count(*)::int from private.balance_mismatches()), 0, 'bakiye önbelleği ledger ile tutarlı');

select * from finish();
rollback;
