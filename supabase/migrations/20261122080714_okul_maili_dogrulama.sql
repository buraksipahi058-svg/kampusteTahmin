-- Adım 5: okul maili doğrulama.
--
-- Akış: kullanıcı okul mailini girer (request_student_email_code) → alan adı kendi okulunun mu,
-- mail başka hesapta mı, istek sınırı aşıldı mı kontrol edilir → 6 haneli kod üretilir, yalnızca
-- bcrypt özeti saklanır → kod mail olarak gönderilir → kullanıcı kodu girer
-- (confirm_student_email) → profile_private.student_email + student_email_verified_at yazılır.
--
-- Mail gönderimi de veritabanındadır (private.send_mail):
-- * 'dev_outbox': mail gönderilmez, private.dev_outbox tablosuna yazılır (yalnızca proje sahibi
--   SQL ile okur). Servis seçilene kadar varsayılan.
-- * 'brevo': pg_net ile Brevo API'sine gider; API anahtarı Supabase Vault'ta durur
--   (mail_settings.api_key_secret_name adıyla). Secret key / Edge Function gerekmez.
--
-- Sınırlar: kod 10 dk geçerli, en fazla 5 yanlış deneme; yeni kod için 60 sn bekleme,
-- günde (İstanbul günü) en fazla 5 kod.

create extension if not exists pg_net with schema extensions;

-- ---------------------------------------------------------------------------
-- Mail ayarları ve geliştirme kutusu (API'ye kapalı private şema)
-- ---------------------------------------------------------------------------

create table private.mail_settings (
  id boolean primary key default true check (id),
  provider text not null default 'dev_outbox' check (provider in ('dev_outbox', 'brevo')),
  sender_email text,
  sender_name text not null default 'KampüsBet',
  -- Vault'taki API anahtarının adı.
  api_key_secret_name text not null default 'brevo_api_key',
  constraint mail_settings_sender check (provider = 'dev_outbox' or sender_email is not null)
);
insert into private.mail_settings default values;

create table private.dev_outbox (
  id bigint generated always as identity primary key,
  to_email text not null,
  subject text not null,
  body text not null,
  created_at timestamptz not null default now()
);

create table private.student_email_challenges (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  email text not null,
  code_hash text not null,
  expires_at timestamptz not null,
  attempts integer not null default 0 check (attempts >= 0),
  last_sent_at timestamptz not null,
  sends_today integer not null check (sends_today > 0),
  sends_day date not null
);

alter table private.mail_settings enable row level security;
alter table private.dev_outbox enable row level security;
alter table private.student_email_challenges enable row level security;
revoke all on private.mail_settings, private.dev_outbox, private.student_email_challenges
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Mail gönderimi
-- ---------------------------------------------------------------------------

create function private.send_mail(p_to text, p_subject text, p_text text) returns void
language plpgsql set search_path = '' as $$
declare
  v_cfg private.mail_settings;
  v_key text;
begin
  select * into v_cfg from private.mail_settings;

  if v_cfg.provider = 'dev_outbox' then
    insert into private.dev_outbox (to_email, subject, body) values (p_to, p_subject, p_text);
    return;
  end if;

  select s.decrypted_secret into v_key from vault.decrypted_secrets s where s.name = v_cfg.api_key_secret_name;
  if v_key is null then
    raise exception 'Mail servisi yapılandırılmamış' using errcode = 'KB013';
  end if;

  -- pg_net isteği transaction commit edilince gönderir; geri alınırsa hiç gitmez.
  perform net.http_post(
    url := 'https://api.brevo.com/v3/smtp/email',
    headers := jsonb_build_object('api-key', v_key, 'content-type', 'application/json', 'accept', 'application/json'),
    body := jsonb_build_object(
      'sender', jsonb_build_object('name', v_cfg.sender_name, 'email', v_cfg.sender_email),
      'to', jsonb_build_array(jsonb_build_object('email', p_to)),
      'subject', p_subject,
      'textContent', p_text
    )
  );
end;
$$;

revoke execute on function private.send_mail(text, text, text) from public;

-- ---------------------------------------------------------------------------
-- Kod isteme
-- ---------------------------------------------------------------------------

create function public.request_student_email_code(p_email text)
returns table (email text, expires_at timestamptz)
language plpgsql security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
  v_email text := lower(btrim(coalesce(p_email, '')));
  v_school uuid;
  v_today date;
  v_challenge private.student_email_challenges;
  v_code text;
  v_expires timestamptz := now() + interval '10 minutes';
begin
  if v_uid is null or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;

  -- Profil satırı kilitlenir: aynı kişinin eşzamanlı istekleri sıraya girer.
  select p.school_id into v_school from public.profiles p where p.id = v_uid for update;
  if not found then
    raise exception 'Önce profil oluşturulmalı' using errcode = 'P0002';
  end if;
  if private.is_verified(v_uid) then
    raise exception 'Okul mailin zaten doğrulanmış' using errcode = 'KB009';
  end if;
  if char_length(v_email) > 254 or v_email !~ '^[a-z0-9._%+-]+@[a-z0-9-]+(\.[a-z0-9-]+)+$' then
    raise exception 'Geçerli bir mail adresi gir' using errcode = '23514';
  end if;
  if not exists (
    select 1 from public.school_email_domains d
    where d.domain = split_part(v_email, '@', 2) and d.school_id = v_school
  ) then
    raise exception 'Bu mail adresi okulunun öğrenci maili değil' using errcode = 'KB007';
  end if;
  if exists (select 1 from public.profile_private pp where pp.student_email = v_email and pp.user_id <> v_uid) then
    raise exception 'Bu okul maili başka bir hesaba bağlı' using errcode = 'KB008';
  end if;

  select (now() at time zone s.day_timezone)::date into strict v_today from public.economy_settings s;
  select * into v_challenge from private.student_email_challenges c where c.user_id = v_uid;
  if found then
    if v_challenge.last_sent_at > now() - interval '60 seconds' then
      raise exception 'Yeni kod istemeden önce biraz bekle' using errcode = 'KB010';
    end if;
    if v_challenge.sends_day = v_today and v_challenge.sends_today >= 5 then
      raise exception 'Bugün için kod isteme sınırına ulaştın' using errcode = 'KB010';
    end if;
  end if;

  -- Kriptografik rastgele 6 hane.
  v_code := lpad(((('x' || encode(extensions.gen_random_bytes(4), 'hex'))::bit(32)::bigint) % 1000000)::text, 6, '0');

  insert into private.student_email_challenges as c
    (user_id, email, code_hash, expires_at, attempts, last_sent_at, sends_today, sends_day)
  values
    (v_uid, v_email, extensions.crypt(v_code, extensions.gen_salt('bf', 8)), v_expires, 0, now(), 1, v_today)
  on conflict (user_id) do update set
    email = excluded.email,
    code_hash = excluded.code_hash,
    expires_at = excluded.expires_at,
    attempts = 0,
    last_sent_at = excluded.last_sent_at,
    sends_today = case when c.sends_day = excluded.sends_day then c.sends_today + 1 else 1 end,
    sends_day = excluded.sends_day;

  perform private.send_mail(
    v_email,
    'KampüsBet okul maili doğrulama kodu',
    format(E'Doğrulama kodun: %s\n\nKod 10 dakika geçerli. Bu isteği sen yapmadıysan bu maili yok sayabilirsin.', v_code)
  );

  return query select v_email, v_expires;
end;
$$;

-- ---------------------------------------------------------------------------
-- Kodu doğrulama
-- ---------------------------------------------------------------------------

-- Yanlış kodda hata vermez (deneme sayısı kalıcı olsun diye): verified = false ve kalan hak döner.
create function public.confirm_student_email(p_code text)
returns table (verified boolean, attempts_left integer)
language plpgsql security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
  v_challenge private.student_email_challenges;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;

  select * into v_challenge from private.student_email_challenges c where c.user_id = v_uid for update;
  if not found then
    raise exception 'Önce doğrulama kodu iste' using errcode = 'P0002';
  end if;
  if v_challenge.expires_at <= now() then
    raise exception 'Kodun süresi doldu, yeni kod iste' using errcode = 'KB011';
  end if;
  if v_challenge.attempts >= 5 then
    raise exception 'Çok fazla yanlış deneme, yeni kod iste' using errcode = 'KB012';
  end if;

  if p_code is null or v_challenge.code_hash <> extensions.crypt(btrim(p_code), v_challenge.code_hash) then
    update private.student_email_challenges set attempts = attempts + 1 where user_id = v_uid;
    return query select false, 5 - (v_challenge.attempts + 1);
    return;
  end if;

  begin
    update public.profile_private
    set student_email = v_challenge.email, student_email_verified_at = now()
    where user_id = v_uid;
  exception when unique_violation then
    raise exception 'Bu okul maili başka bir hesaba bağlı' using errcode = 'KB008';
  end;

  delete from private.student_email_challenges where user_id = v_uid;
  return query select true, 0;
end;
$$;

revoke execute on function
  public.request_student_email_code(text),
  public.confirm_student_email(text)
from public, anon;

grant execute on function
  public.request_student_email_code(text),
  public.confirm_student_email(text)
to authenticated;
