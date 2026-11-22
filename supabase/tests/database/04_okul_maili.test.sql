-- Adım 5 testleri: okul maili doğrulama (kod isteme, doğrulama, sınırlar, mail gönderimi).
-- Tek transaction içinde çalışır ve sonunda geri alınır; pg_net istekleri commit olmadığı için gitmez.
--
-- Okullar: A (ogr.test-a.edu.tr), B (ogr.test-b.edu.tr)
-- Kişiler: Ali (A), Veli (A), Zeynep (B), Yeni (profili yok)

begin;
set local role postgres;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(32);

-- ---------------------------------------------------------------------------
-- Hazırlık
-- ---------------------------------------------------------------------------

update private.mail_settings set provider = 'dev_outbox', sender_email = null, api_key_secret_name = 'brevo_api_key';
update public.economy_settings set day_timezone = 'Europe/Istanbul';

insert into public.clusters (id, name, type) values
  ('a0000000-0000-4000-8000-000000000001', 'Test Üniversitesi A', 'school'),
  ('b0000000-0000-4000-8000-000000000001', 'Test Üniversitesi B', 'school');
insert into public.school_email_domains (domain, school_id) values
  ('ogr.test-a.edu.tr', 'a0000000-0000-4000-8000-000000000001'),
  ('ogr.test-b.edu.tr', 'b0000000-0000-4000-8000-000000000001');

insert into auth.users (id, email, aud, role)
select id, id::text || '@test.local', 'authenticated', 'authenticated'
from unnest(array[
  'c0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000002',
  'c0000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000004'
]::uuid[]) as id;

do $$
declare r record;
begin
  for r in select * from (values
    ('c0000000-0000-4000-8000-000000000001'::uuid, 'Ali', 'a0000000-0000-4000-8000-000000000001'::uuid),
    ('c0000000-0000-4000-8000-000000000002', 'Veli', 'a0000000-0000-4000-8000-000000000001'),
    ('c0000000-0000-4000-8000-000000000003', 'Zeynep', 'b0000000-0000-4000-8000-000000000001')
  ) as v(id, ad, okul) loop
    perform set_config('request.jwt.claims', json_build_object('sub', r.id, 'role', 'authenticated')::text, true);
    perform public.create_profile(r.ad, 'Test', r.okul);
  end loop;
end $$;

-- Geliştirme kutusundaki son kod (postgres okur, test kullanıcısına geçici tabloyla verilir)
create temp table kod (kisi text primary key, k text) on commit drop;
grant select on kod to authenticated;
create function pg_temp.son_kod(p_email text) returns text language sql stable as
  $$ select substring(o.body from '[0-9]{6}') from private.dev_outbox o where o.to_email = p_email order by o.id desc limit 1 $$;

-- ---------------------------------------------------------------------------
-- Ali: kod isteme
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000001","role":"authenticated"}';

select lives_ok(
  $$select public.request_student_email_code('  Ali.Kaya@OGR.Test-A.edu.tr ')$$,
  'okulun alan adındaki maile kod istenir (boşluk ve büyük harf temizlenir)'
);

select throws_ok($$select * from private.dev_outbox$$, '42501', null, 'kullanıcı geliştirme kutusunu okuyamaz');
select throws_ok($$select * from private.student_email_challenges$$, '42501', null, 'kullanıcı kod kayıtlarını okuyamaz');
select throws_ok($$select private.send_mail('x@y.com', 'konu', 'metin')$$, '42501', null, 'kullanıcı mail gönderme fonksiyonunu çağıramaz');

select throws_ok(
  $$select public.request_student_email_code('ali.kaya@ogr.test-a.edu.tr')$$,
  'KB010', null, '60 saniye dolmadan yeni kod istenemez'
);

select throws_ok(
  $$select public.request_student_email_code('ali@ogr.test-b.edu.tr')$$,
  'KB007', null, 'başka okulun alan adıyla kod istenemez'
);

select throws_ok(
  $$select public.request_student_email_code('ali.kaya@gmail.com')$$,
  'KB007', null, 'okul dışı mail adresiyle kod istenemez'
);

select throws_ok(
  $$select public.request_student_email_code('mail-degil')$$,
  '23514', null, 'geçersiz mail adresi reddedilir'
);

select is(
  (select row(verified, attempts_left)::text from public.confirm_student_email('12345')),
  '(f,4)',
  'yanlış kod hata vermez, kalan hakkı söyler'
);

select is(
  (select student_email_verified_at is null from public.profile_private),
  true,
  'yanlış kodla doğrulanmış sayılmaz'
);

-- ---------------------------------------------------------------------------
-- Ali: kodu doğrulama
-- ---------------------------------------------------------------------------

set local role postgres;
insert into kod values ('ali', pg_temp.son_kod('ali.kaya@ogr.test-a.edu.tr'));

select is(
  (select count(*)::int from private.dev_outbox
   where to_email = 'ali.kaya@ogr.test-a.edu.tr' and subject = 'KampüsBet okul maili doğrulama kodu' and body ~ '[0-9]{6}'),
  1,
  'kod geliştirme kutusuna mail olarak düşer'
);

select ok(
  (select code_hash like '$2%' and code_hash <> (select k from kod where kisi = 'ali')
   from private.student_email_challenges where user_id = 'c0000000-0000-4000-8000-000000000001'),
  'kodun kendisi değil yalnızca bcrypt özeti saklanır'
);

set local role authenticated;

select is(
  (select row(verified, attempts_left)::text from public.confirm_student_email((select k from kod where kisi = 'ali'))),
  '(t,0)',
  'doğru kodla mail doğrulanır'
);

select is(
  (select row(student_email, student_email_verified_at is not null)::text from public.profile_private),
  '(ali.kaya@ogr.test-a.edu.tr,t)',
  'okul maili ve doğrulama zamanı profile yazılır'
);

select throws_ok(
  $$select public.request_student_email_code('ali.kaya@ogr.test-a.edu.tr')$$,
  'KB009', null, 'doğrulanmış kişi yeniden kod isteyemez'
);

set local role postgres;

select is(
  (select count(*)::int from private.student_email_challenges where user_id = 'c0000000-0000-4000-8000-000000000001'),
  0,
  'doğrulama sonrası kod kaydı silinir'
);

-- ---------------------------------------------------------------------------
-- Veli: başkasının maili, deneme sınırı, süre, günlük sınır
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000002","role":"authenticated"}';

select throws_ok(
  $$select public.request_student_email_code('ali.kaya@ogr.test-a.edu.tr')$$,
  'KB008', null, 'başka hesaba bağlı okul maili istenemez'
);

select lives_ok(
  $$select public.request_student_email_code('veli@ogr.test-a.edu.tr')$$,
  'kendi okul mailine kod istenir'
);

do $$ begin
  for i in 1..4 loop
    perform public.confirm_student_email('12345');
  end loop;
end $$;

select is(
  (select row(verified, attempts_left)::text from public.confirm_student_email('12345')),
  '(f,0)',
  'beşinci yanlış denemede hak biter'
);

set local role postgres;
insert into kod values ('veli', pg_temp.son_kod('veli@ogr.test-a.edu.tr'));
set local role authenticated;

select throws_ok(
  $$select public.confirm_student_email((select k from kod where kisi = 'veli'))$$,
  'KB012', null, 'hak bitince doğru kod da kabul edilmez'
);

set local role postgres;
update private.student_email_challenges set expires_at = now() - interval '1 second', attempts = 0
where user_id = 'c0000000-0000-4000-8000-000000000002';
set local role authenticated;

select throws_ok(
  $$select public.confirm_student_email((select k from kod where kisi = 'veli'))$$,
  'KB011', null, 'süresi dolan kod kabul edilmez'
);

set local role postgres;
update private.student_email_challenges
set last_sent_at = now() - interval '2 minutes', sends_today = 5,
    sends_day = (now() at time zone 'Europe/Istanbul')::date
where user_id = 'c0000000-0000-4000-8000-000000000002';
set local role authenticated;

select throws_ok(
  $$select public.request_student_email_code('veli@ogr.test-a.edu.tr')$$,
  'KB010', null, 'günde en fazla 5 kod istenir'
);

set local role postgres;
update private.student_email_challenges set sends_day = (now() at time zone 'Europe/Istanbul')::date - 1
where user_id = 'c0000000-0000-4000-8000-000000000002';
set local role authenticated;

select lives_ok(
  $$select public.request_student_email_code('veli@ogr.test-a.edu.tr')$$,
  'yeni günde sınır sıfırlanır'
);

set local role postgres;

select is(
  (select sends_today from private.student_email_challenges where user_id = 'c0000000-0000-4000-8000-000000000002'),
  1,
  'yeni günün sayacı 1''den başlar'
);

-- ---------------------------------------------------------------------------
-- Kod istemeden doğrulama, profilsiz, giriş yapmamış
-- ---------------------------------------------------------------------------

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000003","role":"authenticated"}';

select throws_ok(
  $$select public.confirm_student_email('123456')$$,
  'P0002', null, 'kod istemeden doğrulama yapılamaz'
);

set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000004","role":"authenticated"}';

select throws_ok(
  $$select public.request_student_email_code('yeni@ogr.test-a.edu.tr')$$,
  'P0002', null, 'profili olmayan kod isteyemez'
);

set local role anon;
set local request.jwt.claims to '{"role":"anon"}';

select throws_ok(
  $$select public.request_student_email_code('x@ogr.test-a.edu.tr')$$,
  '42501', null, 'giriş yapmamış ziyaretçi kod isteyemez'
);

select throws_ok(
  $$select public.confirm_student_email('123456')$$,
  '42501', null, 'giriş yapmamış ziyaretçi doğrulama yapamaz'
);

-- ---------------------------------------------------------------------------
-- Brevo kipi
-- ---------------------------------------------------------------------------

set local role postgres;
update private.mail_settings
set provider = 'brevo', sender_email = 'noreply@test.local', api_key_secret_name = 'kampusbet_test_olmayan_anahtar';

set local role authenticated;
set local request.jwt.claims to '{"sub":"c0000000-0000-4000-8000-000000000003","role":"authenticated"}';

select throws_ok(
  $$select public.request_student_email_code('zeynep@ogr.test-b.edu.tr')$$,
  'KB013', null, 'API anahtarı yoksa mail servisi yapılandırılmamış hatası'
);

set local role postgres;
do $$ begin perform vault.create_secret('test-anahtari', 'kampusbet_test_anahtari'); end $$;
update private.mail_settings set api_key_secret_name = 'kampusbet_test_anahtari';
set local role authenticated;

select lives_ok(
  $$select public.request_student_email_code('zeynep@ogr.test-b.edu.tr')$$,
  'anahtar varken kod istenir'
);

set local role postgres;

select is(
  (select count(*)::int from net.http_request_queue
   where url = 'https://api.brevo.com/v3/smtp/email'
     and convert_from(body, 'UTF8') like '%zeynep@ogr.test-b.edu.tr%'),
  1,
  'mail isteği Brevo için kuyruğa girer (geri alınacağı için gönderilmez)'
);

select is(
  (select count(*)::int from private.dev_outbox where to_email = 'zeynep@ogr.test-b.edu.tr'),
  0,
  'Brevo kipinde geliştirme kutusuna yazılmaz'
);

select * from finish();
rollback;
