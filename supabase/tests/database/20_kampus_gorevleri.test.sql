-- Adım 17a testleri: kampüs görevleri (yönetim izinleri, QR kodu, gönderi kuralları, kontenjan, ödül, RLS, başarım).
-- Tek transaction içinde çalışır ve sonunda geri alınır.
--
-- A okulu: Ali, Veli, Can (öğrenci, doğrulanmış), Yeni (doğrulanmamış), Mod (yetkili: kampus_gorevi_yonet), Süper.
-- B okulu: Zeynep (öğrenci), Bmod (yetkili: B'de kampus_gorevi_yonet).

begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
alter default privileges for role postgres grant execute on functions to public;

select plan(38);

-- ---------------------------------------------------------------------------
-- Hazırlık
-- ---------------------------------------------------------------------------

update public.economy_settings set signup_bonus_sp = 1000;
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
  (pg_temp.uid(4), 'a0000000-0000-4000-8000-000000000001', 'kampus_gorevi_yonet', pg_temp.uid(5)),
  (pg_temp.uid(8), 'b0000000-0000-4000-8000-000000000001', 'kampus_gorevi_yonet', pg_temp.uid(5));

create temp table t (k text primary key, id uuid not null) on commit drop;
grant all on t to authenticated;
create function pg_temp.id(p_k text) returns uuid language sql stable as $$ select id from t where k = p_k $$;
-- Kodlar postgres olarak hesaplanıp burada tutulur (anahtar öğrenciye kapalı).
create temp table codes (k text primary key, c text not null) on commit drop;
grant select on codes to authenticated;
create function pg_temp.code(p_k text) returns text language sql stable as $$ select c from codes where k = p_k $$;

create function pg_temp.save(p_id uuid, p_title text, p_currency public.currency default 'SP', p_rot integer default 0,
                             p_period public.campus_period default 'once', p_quota integer default null,
                             p_active boolean default true, p_starts timestamptz default null,
                             p_verification public.campus_verification default 'qr',
                             p_school uuid default 'a0000000-0000-4000-8000-000000000001') returns uuid
language sql as $$
  select public.save_campus_task(p_id, p_school, p_title, 'Açıklama', '🍽️', p_verification, p_period, p_currency,
                                 30, 15, p_quota, p_rot, p_starts, null, p_active)
$$;

-- ---------------------------------------------------------------------------
-- Yönetim
-- ---------------------------------------------------------------------------

set local role anon;
select throws_ok($$select pg_temp.save(null, 'Anonim görev')$$, '42501', null, 'anonim kampüs görevi açamaz');
set local role authenticated;
select pg_temp.as_user(1);
select throws_ok($$select pg_temp.save(null, 'Öğrenci görevi')$$, '42501', null, 'öğrenci açamaz');
select pg_temp.as_user(8);
select throws_ok($$select pg_temp.save(null, 'Başka okul')$$, '42501', null, 'başka okulun yetkilisi açamaz');
select pg_temp.as_user(4);
select throws_ok($$select pg_temp.save(null, 'SSP görevi', 'SSP')$$, '42501', null, 'yetkili SSP ödüllü görev açamaz');
select lives_ok($$insert into t values ('yemek', pg_temp.save(null, 'Yemekhanede ye', 'SP', 0, 'once', 2))$$,
                'okul yetkilisi QR görevi açar');

set local role postgres;
select is((select count(*)::int from private.campus_task_secrets where task_id = pg_temp.id('yemek')), 1,
          'görevin QR anahtarı oluşur');
select is((select count(*)::int from public.admin_audit_log where action = 'campus_task_save'
           and details ->> 'task_id' = pg_temp.id('yemek')::text), 1, 'denetim kaydına yazılır');

set local role authenticated;
select pg_temp.as_user(5);
select lives_ok($$insert into t values ('kutuphane', pg_temp.save(null, 'Kütüphaneye uğra', 'SSP', 60, 'daily'))$$,
                'süperadmin SSP ödüllü, dönen QR''lı görev açar');
select pg_temp.as_user(4);
select throws_ok($$select pg_temp.save(pg_temp.id('kutuphane'), 'Kütüphaneye uğra', 'SSP', 60, 'daily')$$, '42501', null,
                 'yetkili SSP ödüllü görevi düzenleyemez');
select throws_ok($$select pg_temp.save(pg_temp.id('yemek'), 'Yemekhanede ye', 'SP', 0, 'once', 2, true, null, 'photo')$$,
                 '23514', null, 'doğrulama yöntemi sonradan değişmez');
select throws_ok($$select count(*) from private.campus_task_secrets$$, '42501', null, 'istemci QR anahtarını okuyamaz');

select pg_temp.as_user(1);
select throws_ok($$select * from public.campus_task_qr(pg_temp.id('yemek'))$$, 'P0002', null, 'öğrenci QR içeriğini alamaz');
select pg_temp.as_user(4);
select is((select payload like 'com.kampusbet.kampusbet://kampus-gorev?t=%&c=' || code from public.campus_task_qr(pg_temp.id('yemek'))),
          true, 'yetkili QR içeriğini alır');

-- ---------------------------------------------------------------------------
-- QR ile gönderi
-- ---------------------------------------------------------------------------

set local role postgres;
insert into codes values
  ('yemek', private.campus_qr_code(pg_temp.id('yemek'), now())),
  ('kut-simdi', private.campus_qr_code(pg_temp.id('kutuphane'), now())),
  ('kut-once', private.campus_qr_code(pg_temp.id('kutuphane'), now() - interval '60 seconds')),
  ('kut-eski', private.campus_qr_code(pg_temp.id('kutuphane'), now() - interval '180 seconds'));

set local role anon;
select throws_ok($$select * from public.submit_campus_task_qr(pg_temp.id('yemek'), 'X')$$, '42501', null, 'anonim gönderemez');
set local role authenticated;
select pg_temp.as_user(3);
select throws_ok($$select * from public.submit_campus_task_qr(pg_temp.id('yemek'), pg_temp.code('yemek'))$$, 'KB002', null,
                 'okul maili doğrulanmamış gönderemez');
select pg_temp.as_user(7);
select throws_ok($$select * from public.submit_campus_task_qr(pg_temp.id('yemek'), pg_temp.code('yemek'))$$, 'P0002', null,
                 'başka okulun görevi bulunamaz');
select pg_temp.as_user(4);
select throws_ok($$select * from public.submit_campus_task_qr(pg_temp.id('yemek'), pg_temp.code('yemek'))$$, '42501', null,
                 'görevi yöneten ödül alamaz');
select pg_temp.as_user(1);
select throws_ok($$select * from public.submit_campus_task_qr(pg_temp.id('yemek'), 'ABCDEF123456')$$, 'KB029', null,
                 'yanlış kod reddedilir');
select is((select reward_currency || ':' || reward_amount || ':' || reward_xp
           from public.submit_campus_task_qr(pg_temp.id('yemek'), lower(pg_temp.code('yemek')))),
          'SP:30:15', 'doğru kodla ödül hemen verilir (küçük harf de olur)');
select throws_ok($$select * from public.submit_campus_task_qr(pg_temp.id('yemek'), pg_temp.code('yemek'))$$, 'KB030', null,
                 'aynı dönemde ikinci kez yapılamaz');
select pg_temp.as_user(2);
select lives_ok($$select * from public.submit_campus_task_qr(pg_temp.id('yemek'), pg_temp.code('yemek'))$$,
                'kontenjan içinde ikinci kişi yapar');
select pg_temp.as_user(6);
select throws_ok($$select * from public.submit_campus_task_qr(pg_temp.id('yemek'), pg_temp.code('yemek'))$$, 'KB031', null,
                 'kontenjan dolunca reddedilir');

set local role postgres;
select is((select count(*)::int from public.ledger_entries where user_id = pg_temp.uid(1) and reason = 'campus_task_reward'
           and ref_type = 'campus_task' and ref_id = pg_temp.id('yemek') and amount = 30 and currency = 'SP'), 1,
          'ödül ledger''a yazılır');
select is((select sum(amount)::int from public.xp_events where user_id = pg_temp.uid(1) and reason = 'campus_task'), 15,
          'XP ledger kaydından gelir');

-- Dönen QR: şimdiki ve bir önceki dilimin kodu geçer, daha eskisi geçmez; SSP ödülü.
set local role authenticated;
select pg_temp.as_user(1);
select is((select reward_currency::text from public.submit_campus_task_qr(pg_temp.id('kutuphane'), pg_temp.code('kut-simdi'))),
          'SSP', 'dönen QR''ın şimdiki koduyla süperadmin görevi SSP verir');
select pg_temp.as_user(2);
select lives_ok($$select * from public.submit_campus_task_qr(pg_temp.id('kutuphane'), pg_temp.code('kut-once'))$$,
                'bir önceki dilimin kodu da geçer');
select pg_temp.as_user(6);
select throws_ok($$select * from public.submit_campus_task_qr(pg_temp.id('kutuphane'), pg_temp.code('kut-eski'))$$, 'KB029', null,
                 'süresi geçmiş kod reddedilir');

select pg_temp.as_user(1);
select throws_ok($$select public.reset_campus_task_qr(pg_temp.id('kutuphane'))$$, 'P0002', null, 'öğrenci QR''ı yenileyemez');
-- SSP ödüllü görevin QR'ını yalnızca süperadmin yeniler (yetkilinin reddi 22_guvenlik_duzeltmeleri'nde).
select pg_temp.as_user(5);
select lives_ok($$select public.reset_campus_task_qr(pg_temp.id('kutuphane'))$$, 'süperadmin SSP görevinin QR''ını yeniler');
select pg_temp.as_user(6);
select throws_ok($$select * from public.submit_campus_task_qr(pg_temp.id('kutuphane'), pg_temp.code('kut-simdi'))$$, 'KB029', null,
                 'yenilenince eski kod geçmez');

-- Kapalı ve henüz başlamamış görev.
select pg_temp.as_user(4);
select pg_temp.save(pg_temp.id('yemek'), 'Yemekhanede ye', 'SP', 0, 'once', 2, false);
insert into t values ('sonra', pg_temp.save(null, 'Yarın başlar', 'SP', 0, 'once', null, true, now() + interval '1 day'));
set local role postgres;
insert into codes values ('sonra', private.campus_qr_code(pg_temp.id('sonra'), now()));
set local role authenticated;
select pg_temp.as_user(6);
select throws_ok($$select * from public.submit_campus_task_qr(pg_temp.id('sonra'), pg_temp.code('sonra'))$$, 'KB032', null,
                 'başlamamış görev yapılamaz');

-- ---------------------------------------------------------------------------
-- RLS ve öğrenci listesi
-- ---------------------------------------------------------------------------

select pg_temp.as_user(1);
select is((select count(*)::int from public.campus_task_submissions where user_id <> pg_temp.uid(1)), 0,
          'öğrenci başkasının gönderisini göremez');
select pg_temp.as_user(4);
select is((select count(*)::int from public.campus_task_submissions), 4, 'okulun yetkilisi okulun gönderilerini görür');
select pg_temp.as_user(8);
select is((select count(*)::int from public.campus_task_submissions), 0, 'başka okulun yetkilisi göremez');
select pg_temp.as_user(7);
select is((select count(*)::int from public.campus_tasks), 0, 'başka okulun öğrencisi görevleri göremez');

select pg_temp.as_user(1);
select is((select array_agg(title || ':' || coalesce(my_status::text, '-') || ':' || can_submit || ':' || done_this_period
                            order by title)
           from public.my_campus_tasks()),
          array['Kütüphaneye uğra:approved:false:2', 'Yarın başlar:-:false:0'],
          'öğrenci listesi: kapalı görev yok, durum ve bu dönem yapan sayısı');
select is((select claimable from public.my_achievements() where key = 'kampus_ilk'), true,
          'ilk kampüs görevi başarımı kazanılır');

set local role postgres;
select is((select count(*)::int from private.balance_mismatches()), 0, 'bakiye önbelleği ledger ile tutarlı');

select * from finish();
rollback;
