-- Adım 17b testleri: fotoğraflı kampüs görevi (depolama erişimi, gönderi, onay / ret, süre dolması, silme kuyruğu).
-- Tek transaction içinde çalışır ve sonunda geri alınır.
--
-- A okulu: Ali, Veli (öğrenci, doğrulanmış), Yeni (doğrulanmamış), Mod (yetkili: kampus_gorevi_yonet), Süper,
-- Yasak (doğrulanmış, yasaklı). B okulu: Zeynep (öğrenci), Bmod (yetkili: B'de kampus_gorevi_yonet).

begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
alter default privileges for role postgres grant execute on functions to public;

select plan(39);

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
-- Kişinin klasöründe geçerli bir fotoğraf adı.
create function pg_temp.path(p_n integer) returns text language sql volatile as
  $$ select pg_temp.uid(p_n)::text || '/' || gen_random_uuid()::text || '.jpg' $$;

insert into auth.users (id, email, aud, role)
select pg_temp.uid(n), 'kisi' || n || '@test.local', 'authenticated', 'authenticated' from generate_series(1, 8) n;
do $$
declare r record;
begin
  for r in select * from (values
    (1, 'Ali', 'a0000000-0000-4000-8000-000000000001'::uuid), (2, 'Veli', 'a0000000-0000-4000-8000-000000000001'),
    (3, 'Yeni', 'a0000000-0000-4000-8000-000000000001'), (4, 'Mod', 'a0000000-0000-4000-8000-000000000001'),
    (5, 'Süper', 'a0000000-0000-4000-8000-000000000001'), (6, 'Yasak', 'a0000000-0000-4000-8000-000000000001'),
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
update public.profiles set banned_at = now() where id = pg_temp.uid(6);
insert into public.permissions (user_id, cluster_id, permission_key, granted_by) values
  (pg_temp.uid(4), 'a0000000-0000-4000-8000-000000000001', 'kampus_gorevi_yonet', pg_temp.uid(5)),
  (pg_temp.uid(8), 'b0000000-0000-4000-8000-000000000001', 'kampus_gorevi_yonet', pg_temp.uid(5));

create temp table t (k text primary key, v text not null) on commit drop;
grant all on t to authenticated;
create function pg_temp.v(p_k text) returns text language sql stable as $$ select v from t where k = p_k $$;
-- Görünen fotoğrafları güncellemeyi dener (istemci yetkisiyle); güncellenen satır sayısı.
create function pg_temp.try_update() returns integer language plpgsql as $$
declare n integer;
begin
  update storage.objects set name = name where bucket_id = 'campus-proofs';
  get diagnostics n = row_count;
  return n;
end $$;
create function pg_temp.upload(p_k text, p_n integer) returns void language sql as $$
  insert into t values (p_k, pg_temp.path(p_n));
  insert into storage.objects (bucket_id, name) values ('campus-proofs', (select v from t where k = p_k));
$$;

set local role authenticated;
select pg_temp.as_user(4);
insert into t values ('foto', public.save_campus_task(null, 'a0000000-0000-4000-8000-000000000001', 'Çöpü kutuya at', null,
                                                     '♻️', 'photo', 'once', 'SP', 25, 10, 1, 0, null, null, true)::text);
insert into t values ('foto2', public.save_campus_task(null, 'a0000000-0000-4000-8000-000000000001', 'Kampüsü temizle', null,
                                                      '🧹', 'photo', 'once', 'SP', 20, 0, null, 0, null, null, true)::text);
insert into t values ('qr', public.save_campus_task(null, 'a0000000-0000-4000-8000-000000000001', 'Kütüphane', null,
                                                   '📚', 'qr', 'once', 'SP', 10, 0, null, 0, null, null, true)::text);

-- ---------------------------------------------------------------------------
-- Depolama erişimi
-- ---------------------------------------------------------------------------

select pg_temp.as_user(1);
select lives_ok($$select pg_temp.upload('ali1', 1)$$, 'öğrenci kendi klasörüne yükler');
select throws_ok($$select pg_temp.upload('ali-veli', 2)$$, '42501', null, 'başkasının klasörüne yükleyemez');
select throws_ok($$insert into storage.objects (bucket_id, name) values ('campus-proofs', 'c0000000-0000-4000-8000-000000000001/x.jpg')$$,
                 '42501', null, 'adı kurala uymayan dosya yüklenemez');
select pg_temp.as_user(3);
select throws_ok($$select pg_temp.upload('yeni1', 3)$$, '42501', null, 'okul maili doğrulanmamış yükleyemez');
select pg_temp.as_user(6);
select throws_ok($$select pg_temp.upload('yasak1', 6)$$, '42501', null, 'yasaklı yükleyemez');
select pg_temp.as_user(1);
select lives_ok($$select pg_temp.upload('ali' || n, 1) from generate_series(2, 10) n$$, 'saatte 10 yüklemeye kadar geçer');
select throws_ok($$select pg_temp.upload('ali11', 1)$$, '42501', null, 'saatte 10''dan fazla yüklenemez');

select pg_temp.as_user(2);
select pg_temp.upload('veli1', 2);
select is((select count(*)::int from storage.objects where bucket_id = 'campus-proofs'), 1,
          'öğrenci yalnızca kendi fotoğrafını görür');
select pg_temp.as_user(4);
select is((select count(*)::int from storage.objects where bucket_id = 'campus-proofs'), 11,
          'okulun yetkilisi okulun fotoğraflarını görür');
select pg_temp.as_user(8);
select is((select count(*)::int from storage.objects where bucket_id = 'campus-proofs'), 0, 'başka okulun yetkilisi göremez');
select pg_temp.as_user(1);
select is(pg_temp.try_update(), 0, 'sahibi bile fotoğrafı değiştiremez (güncelleme politikası yok)');

-- ---------------------------------------------------------------------------
-- Gönderi
-- ---------------------------------------------------------------------------

set local role anon;
select throws_ok($$select public.submit_campus_task_photo(pg_temp.v('foto')::uuid, 'x')$$, '42501', null, 'anonim gönderemez');
set local role authenticated;
select pg_temp.as_user(3);
select throws_ok($$select public.submit_campus_task_photo(pg_temp.v('foto')::uuid, pg_temp.v('ali1'))$$, 'KB002', null,
                 'okul maili doğrulanmamış gönderemez');
select pg_temp.as_user(7);
select throws_ok($$select public.submit_campus_task_photo(pg_temp.v('foto')::uuid, pg_temp.v('ali1'))$$, 'P0002', null,
                 'başka okulun görevi bulunamaz');
select pg_temp.as_user(4);
select throws_ok($$select public.submit_campus_task_photo(pg_temp.v('foto')::uuid, pg_temp.v('ali1'))$$, '42501', null,
                 'görevi yöneten gönderemez');
select pg_temp.as_user(1);
select throws_ok($$select public.submit_campus_task_photo(pg_temp.v('foto')::uuid, pg_temp.v('veli1'))$$, 'KB034', null,
                 'başkasının fotoğrafıyla gönderilemez');
select throws_ok($$select public.submit_campus_task_photo(pg_temp.v('foto')::uuid, pg_temp.path(1))$$, 'KB034', null,
                 'yüklenmemiş fotoğrafla gönderilemez');
select throws_ok($$select public.submit_campus_task_photo(pg_temp.v('qr')::uuid, pg_temp.v('ali1'))$$, 'KB032', null,
                 'QR görevine fotoğraf gönderilemez');
select lives_ok($$insert into t values ('g1', public.submit_campus_task_photo(pg_temp.v('foto')::uuid, pg_temp.v('ali1'))::text)$$,
                'öğrenci fotoğraf gönderir');
select throws_ok($$select public.submit_campus_task_photo(pg_temp.v('foto')::uuid, pg_temp.v('ali2'))$$, 'KB030', null,
                 'onay beklerken aynı görev yeniden gönderilemez');

set local role postgres;
select is((select status::text || '/' || method::text from public.campus_task_submissions where id = pg_temp.v('g1')::uuid),
          'pending/photo', 'gönderi onay bekler');
select is((select count(*)::int from public.notifications where user_id = pg_temp.uid(4) and kind = 'campus_review_new'), 1,
          'okulun yetkilisine onay haberi');

-- ---------------------------------------------------------------------------
-- Onay / ret
-- ---------------------------------------------------------------------------

set local role authenticated;
select pg_temp.as_user(2);
select throws_ok($$select public.review_campus_submission(pg_temp.v('g1')::uuid, true)$$, 'P0002', null, 'öğrenci karar veremez');
select pg_temp.as_user(8);
select throws_ok($$select public.review_campus_submission(pg_temp.v('g1')::uuid, true)$$, 'P0002', null,
                 'başka okulun yetkilisi karar veremez');
select pg_temp.as_user(4);
select throws_ok($$select public.review_campus_submission(pg_temp.v('g1')::uuid, false)$$, '23514', null, 'gerekçesiz reddedilemez');
select lives_ok($$select public.review_campus_submission(pg_temp.v('g1')::uuid, false, 'Fotoğrafta çöp kutusu görünmüyor.')$$,
                'yetkili gerekçeyle reddeder');
select throws_ok($$select public.review_campus_submission(pg_temp.v('g1')::uuid, true)$$, 'KB033', null,
                 'karara bağlanan gönderi yeniden karara bağlanmaz');

select pg_temp.as_user(1);
select throws_ok($$select public.submit_campus_task_photo(pg_temp.v('foto')::uuid, pg_temp.v('ali1'))$$, 'KB034', null,
                 'aynı fotoğraf yeniden kullanılamaz');
select lives_ok($$insert into t values ('g2', public.submit_campus_task_photo(pg_temp.v('foto')::uuid, pg_temp.v('ali2'))::text)$$,
                'reddedilince yeni fotoğrafla yeniden gönderilir');
select pg_temp.as_user(4);
select lives_ok($$select public.review_campus_submission(pg_temp.v('g2')::uuid, true)$$, 'yetkili onaylar');

set local role postgres;
select is((select count(*)::int from public.ledger_entries where user_id = pg_temp.uid(1) and reason = 'campus_task_reward'
           and amount = 25)
          || '/' || (select coalesce(sum(amount), 0)::int from public.xp_events where user_id = pg_temp.uid(1) and reason = 'campus_task'),
          '1/10', 'onayda ödül ve XP verilir');
select is((select array_agg(kind order by id) from public.notifications where user_id = pg_temp.uid(1)
           and kind in ('campus_rejected', 'campus_approved')),
          array['campus_rejected', 'campus_approved'], 'öğrenciye ret ve onay bildirimi');
select is((select count(*)::int from public.admin_audit_log where action = 'campus_review'), 2, 'kararlar denetim kaydında');

set local role authenticated;
select pg_temp.as_user(2);
select throws_ok($$select public.submit_campus_task_photo(pg_temp.v('foto')::uuid, pg_temp.v('veli1'))$$, 'KB031', null,
                 'kontenjan dolunca gönderilemez');

-- ---------------------------------------------------------------------------
-- Süre dolması, fotoğraf silme, hesap silme
-- ---------------------------------------------------------------------------

insert into t values ('g3', public.submit_campus_task_photo(pg_temp.v('foto2')::uuid, pg_temp.v('veli1'))::text);
set local role postgres;
update public.campus_task_submissions set created_at = now() - interval '8 days' where id = pg_temp.v('g3')::uuid;
update public.campus_task_submissions set photo_delete_after = now() - interval '1 minute' where id = pg_temp.v('g1')::uuid;
update private.storage_settings set project_url = null;
select private.process_campus_submissions();
select is((select status::text from public.campus_task_submissions where id = pg_temp.v('g3')::uuid)
          || '/' || (select count(*) from public.notifications where user_id = pg_temp.uid(2) and kind = 'campus_expired'),
          'expired/1', '7 günde karara bağlanmayan gönderi düşer, öğrenciye haber');
select is((select photo_deleted_at is null from public.campus_task_submissions where id = pg_temp.v('g1')::uuid), true,
          'silme ayarı yoksa fotoğraf silinmiş sayılmaz (bekler)');

update private.storage_settings set project_url = 'https://ornek-proje.supabase.co';
select vault.create_secret('test-anahtari', 'kampusbet_storage_service_key');
select private.process_campus_submissions();
select is((select photo_deleted_at is not null from public.campus_task_submissions where id = pg_temp.v('g1')::uuid)
          and exists (select 1 from net.http_request_queue q
                      where q.method = 'DELETE' and q.url = 'https://ornek-proje.supabase.co/storage/v1/object/campus-proofs'),
          true, 'ayar varken süresi gelen fotoğraf için Storage API silme isteği gider');

update public.profiles set deleted_at = now() where id = pg_temp.uid(2);
select is((select bool_and(photo_delete_after <= now()) from public.campus_task_submissions
           where user_id = pg_temp.uid(2) and photo_path is not null), true, 'hesap silinince fotoğrafları hemen silinecek');

select is((select count(*)::int from private.balance_mismatches()), 0, 'bakiye önbelleği ledger ile tutarlı');

select * from finish();
rollback;
