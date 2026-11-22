-- Kalite kontrolü düzeltmeleri (Adım 12 sonrası QA; docs/harita/acik-isler.md, KARARLAR "Kalite kontrolü").
--
-- 1. Kilitlenme: XP ve hesap silme profil satırını FOR UPDATE ile kilitliyordu; yabancı anahtar denetiminin
--    FOR KEY SHARE kilidiyle çakışıp aynı kişinin eşzamanlı iki görev ödülünde 40P01 veriyordu (eşzamanlılık
--    testinde görüldü). FOR NO KEY UPDATE yazmaları yine sıraya sokar, yabancı anahtar kilitleriyle çakışmaz.
-- 2. Silinen hesap, erişim anahtarının süresi dolana kadar okul mailini yeniden doğrulayıp düello açabiliyordu:
--    silinmiş profil doğrulanmış sayılmaz, okulu yok sayılır, yeni kod isteyemez.
-- 3. Silinen kişinin adı düello başlıklarında kalıyordu; silmede temizlenir. Auth'ta süresiz engel `infinity`
--    yerine 100 yıl (Supabase Auth'un zaman alanı `infinity`yi okuyamayabilir).
-- 4. Liderlik: silinen kişi eşzamanlı hesaplamada sıralamaya yazılsa da gösterilmez.
-- 5. Görev ödülü: okulunda `gorev_yonet` izni olan (ve süperadmin) o okulun görevlerinin ödülünü alamaz
--    (kendine görev yazıp SP / XP basamasın; bahiste "sonucu belirleyen yatıramaz" kuralının eşi).

-- ---------------------------------------------------------------------------
-- Yardımcılar: silinmiş profil
-- ---------------------------------------------------------------------------

create or replace function private.current_school_id() returns uuid
language sql stable security definer set search_path = '' as $$
  select p.school_id from public.profiles p where p.id = (select auth.uid()) and p.deleted_at is null;
$$;

create or replace function private.is_verified(p_user_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profile_private pp
    join public.profiles p on p.id = pp.user_id
    where pp.user_id = p_user_id and pp.student_email_verified_at is not null and p.deleted_at is null
  );
$$;

-- ---------------------------------------------------------------------------
-- Okul maili kodu: silinmiş profil isteyemez; profil kilidi FOR NO KEY UPDATE
-- ---------------------------------------------------------------------------

create or replace function public.request_student_email_code(p_email text)
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
  select p.school_id into v_school from public.profiles p
  where p.id = v_uid and p.deleted_at is null
  for no key update;
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
-- XP: profil kilidi FOR NO KEY UPDATE
-- ---------------------------------------------------------------------------

create or replace function private.award_xp(
  p_user_id uuid, p_reason public.xp_reason, p_amount integer,
  p_ledger_entry_id bigint default null, p_wager_id uuid default null
) returns integer
language plpgsql set search_path = '' as $$
declare
  v_cfg public.economy_settings;
  v_amount integer := coalesce(p_amount, 0);
  v_xp integer;
  v_used integer;
begin
  if v_amount <= 0 then
    return 0;
  end if;
  -- Aynı kişiye eşzamanlı XP sırayla yazılır (günlük sınır kesin kalır). FOR NO KEY UPDATE: yabancı anahtar
  -- denetiminin FOR KEY SHARE kilidiyle çakışmaz (FOR UPDATE çakışıp kilitlenmeye yol açıyordu).
  select p.xp into v_xp from public.profiles p where p.id = p_user_id for no key update;
  if not found then
    raise exception 'Profil bulunamadı' using errcode = 'P0002';
  end if;

  if p_reason = 'correct_pick' then
    select * into v_cfg from public.economy_settings s where s.id;
    select coalesce(sum(e.amount), 0) into v_used
    from public.xp_events e
    where e.user_id = p_user_id and e.reason = 'correct_pick'
      and e.created_at >= (date_trunc('day', now() at time zone v_cfg.day_timezone) at time zone v_cfg.day_timezone);
    v_amount := least(v_amount, v_cfg.xp_daily_pick_cap - v_used);
    if v_amount <= 0 then
      return 0;
    end if;
  end if;

  insert into public.xp_events (user_id, reason, amount, ledger_entry_id, wager_id, xp_after)
  values (p_user_id, p_reason, v_amount, p_ledger_entry_id, p_wager_id, v_xp + v_amount)
  on conflict do nothing;
  if not found then
    return 0;
  end if;

  update public.profiles
  set xp = v_xp + v_amount, level = private.level_for_xp(v_xp + v_amount)
  where id = p_user_id;
  return v_amount;
end;
$$;

-- ---------------------------------------------------------------------------
-- Görev ödülü: görevi yönetebilen o okulun görevinden ödül alamaz
-- ---------------------------------------------------------------------------

create or replace function public.claim_quest_reward(p_quest_id uuid)
returns table (reward_currency public.currency, reward_amount integer, balance bigint)
language plpgsql security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
  v_quest public.quests;
  v_start timestamptz;
  v_end timestamptz;
  v_rows integer;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  if not exists (select 1 from public.profiles p where p.id = v_uid) then
    raise exception 'Profil bulunamadı' using errcode = 'P0002';
  end if;
  select * into v_quest from public.quests q where q.id = p_quest_id;
  if not found or not private.quest_open_for(v_uid, v_quest) then
    raise exception 'Görev bulunamadı' using errcode = 'P0002';
  end if;
  if v_quest.school_id is not null and private.has_permission(v_quest.school_id, 'gorev_yonet') then
    raise exception 'Görevlerini yönettiğin okulun görev ödülünü alamazsın' using errcode = '42501';
  end if;

  select w.o_start, w.o_end into v_start, v_end from private.quest_window(v_quest) w;
  if private.quest_progress(v_uid, v_quest.action, v_start, v_end) < v_quest.target then
    raise exception 'Görev henüz tamamlanmadı' using errcode = 'KB019';
  end if;

  -- Aynı anda gelen ikinci istek birincil anahtarda bekler, sonra hiçbir şey eklemez.
  insert into public.quest_claims (user_id, quest_id, period_start, reward_currency, reward_amount)
  values (v_uid, v_quest.id, v_start, v_quest.reward_currency, v_quest.reward_amount)
  on conflict do nothing;
  get diagnostics v_rows = row_count;
  if v_rows = 0 then
    raise exception 'Bu görevin ödülünü bu dönem zaten aldın' using errcode = 'KB020';
  end if;

  reward_currency := v_quest.reward_currency;
  reward_amount := v_quest.reward_amount;
  balance := private.post_ledger(v_uid, v_quest.reward_currency, v_quest.reward_amount, 'quest_reward', 'quest',
                                 v_quest.id, v_uid, null);
  return next;
end;
$$;

-- ---------------------------------------------------------------------------
-- Hesap silme: FOR NO KEY UPDATE, düello başlıkları, Auth engeli 100 yıl
-- ---------------------------------------------------------------------------

create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_profile public.profiles;
  v_emails text[];
  v_permissions integer;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  select * into v_profile from public.profiles p where p.id = v_uid for no key update;
  if not found or v_profile.deleted_at is not null then
    raise exception 'Profil bulunamadı' using errcode = 'P0002';
  end if;
  if v_profile.role = 'superadmin' then
    raise exception 'Süperadmin hesabı uygulamadan silinemez' using errcode = '42501';
  end if;
  if exists (select 1 from public.wagers w join public.bets b on b.id = w.bet_id
             where w.user_id = v_uid and b.status in ('open', 'locked', 'settling'))
     or exists (select 1 from public.bets b
                where b.referee_id = v_uid and b.status in ('open', 'locked', 'settling')) then
    raise exception 'Sonuçlanmamış bahsin, düellon ya da hakemliğin varken hesap silinemez' using errcode = 'KB024';
  end if;

  -- Uygulama verisi: kişiyi tanıtan alanlar.
  select array_remove(array[pp.student_email] || coalesce((select array_agg(c.email) from private.student_email_challenges c
                                                           where c.user_id = v_uid), '{}'), null)
    into v_emails
  from public.profile_private pp where pp.user_id = v_uid;

  update public.profiles
  set first_name = 'Silinmiş', last_name = 'Kullanıcı', department = null, role = 'student', deleted_at = now()
  where id = v_uid;
  update public.profile_private set student_email = null, student_email_verified_at = null where user_id = v_uid;
  delete from private.student_email_challenges where user_id = v_uid;
  delete from private.dev_outbox where to_email = any (coalesce(v_emails, '{}'));
  delete from public.permissions where user_id = v_uid;
  get diagnostics v_permissions = row_count;
  delete from public.user_clusters where user_id = v_uid;
  update public.user_inventory set equipped = false where user_id = v_uid and equipped;
  delete from public.leaderboard_snapshots where user_id = v_uid;
  -- Düello başlığı açanın adını taşır ("Trivia düellosu: Ad"); okulun herkesi görür.
  update public.bets
  set title = 'Trivia düellosu: Silinmiş Kullanıcı'
  where creator_id = v_uid and type = 'sp_minigame' and settlement_mode = 'auto' and title like 'Trivia düellosu: %';

  -- Supabase Auth: giriş bilgileri silinir, oturumlar kapanır, hesap engellenir.
  delete from auth.identities where user_id = v_uid;
  delete from auth.sessions where user_id = v_uid;
  delete from auth.refresh_tokens where user_id = v_uid::text;
  delete from auth.mfa_factors where user_id = v_uid;
  delete from auth.one_time_tokens where user_id = v_uid;
  update auth.users
  set email = null, phone = null, encrypted_password = '', raw_user_meta_data = '{}'::jsonb,
      confirmation_token = '', recovery_token = '', email_change = '', email_change_token_new = '',
      email_change_token_current = '', phone_change = '', phone_change_token = '', reauthentication_token = '',
      banned_until = now() + interval '100 years', deleted_at = now(), updated_at = now()
  where id = v_uid;

  insert into public.admin_audit_log (actor_id, action, target_user_id, cluster_id, details)
  values (v_uid, 'account_delete', v_uid, v_profile.school_id, jsonb_build_object('permissions_removed', v_permissions));
end;
$$;

-- ---------------------------------------------------------------------------
-- Liderlik: silinmiş kişi gösterilmez (eşzamanlı hesaplamada yazılmış olsa da)
-- ---------------------------------------------------------------------------

create or replace function public.get_leaderboard(
  p_metric public.leaderboard_metric,
  p_period public.leaderboard_period,
  p_weeks_ago integer default 0,
  p_school_id uuid default null,
  p_limit integer default 50
)
returns table (
  rank integer, user_id uuid, first_name text, last_name text, value numeric, sample integer, is_me boolean,
  title text, title_icon text, badge text, badge_name text, frame_color text, name_color text,
  period_start date, computed_at timestamptz, level integer
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
  v_school uuid;
  v_day date;
  v_computed timestamptz;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  v_school := coalesce(p_school_id, private.school_of_user(v_uid));
  if v_school is null then
    raise exception 'Profil bulunamadı' using errcode = 'P0002';
  end if;
  if v_school is distinct from private.school_of_user(v_uid) and not private.has_permission(v_school, 'analitik_gor') then
    raise exception 'Okul bulunamadı' using errcode = 'P0002';
  end if;
  if p_weeks_ago is null or p_weeks_ago not between 0 and 52 or p_limit is null or p_limit not between 1 and 100 then
    raise exception 'Geçersiz sıralama isteği' using errcode = '23514';
  end if;
  if p_period = 'week' then
    select b.o_day into v_day from private.week_bounds(p_weeks_ago) b;
  end if;

  select r.computed_at into v_computed from private.leaderboard_runs r
  where r.school_id = v_school and r.period = p_period and r.period_start is not distinct from v_day;

  return query
    with s as (
      select l.* from public.leaderboard_snapshots l
      join public.profiles dp on dp.id = l.user_id and dp.deleted_at is null
      where l.school_id = v_school and l.period = p_period and l.metric = p_metric
        and l.period_start is not distinct from v_day
    ),
    picked as (
      (select s.user_id, s.rank, s.value, s.sample from s order by s.rank, s.user_id limit p_limit)
      union
      (select s.user_id, s.rank, s.value, s.sample from s where s.user_id = v_uid)
    )
    select pk.rank, pk.user_id, p.first_name, p.last_name, pk.value, pk.sample, pk.user_id = v_uid,
           c.title, c.title_icon, c.badge, c.badge_name, c.frame_color, c.name_color, v_day, v_computed, p.level
    from picked pk
    join public.profiles p on p.id = pk.user_id
    left join lateral (
      select max(m.name) filter (where m.category = 'title') as title,
             max(m.icon) filter (where m.category = 'title') as title_icon,
             max(m.icon) filter (where m.category = 'badge') as badge,
             max(m.name) filter (where m.category = 'badge') as badge_name,
             max(m.color) filter (where m.category = 'frame') as frame_color,
             max(m.color) filter (where m.category = 'name_color') as name_color
      from public.user_inventory i join public.market_items m on m.id = i.item_id
      where i.user_id = pk.user_id and i.equipped
    ) c on true
    order by pk.rank, p.first_name, p.last_name, pk.user_id;
end;
$$;
