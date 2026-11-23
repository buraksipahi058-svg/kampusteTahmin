-- Genel güvenlik kontrolü düzeltmeleri (Adım 17b sonrası; bağımsız inceleme bulguları, KARARLAR "Güvenlik kontrolü 2").
--
--  1. Veri dışa aktarma: düello, başarım, bildirim, kampüs görevi gönderileri eklendi (biçim 2).
--  2. Okul verisi (okul arkadaşlarının profili, bahisler, düellolar, sıralama, başarımlar, kozmetik) yalnızca okul maili
--     doğrulanmış öğrenciye ya da yetkiliye açılır: kayıtta okul seçmek tek başına o okulun öğrencisi olmak değildir.
--  3. Yasak bilgisi (`profiles.banned_at`) okul arkadaşlarına kapalı; yönetim paneli `banned_users` ile okur.
--  4. Resmi bahiste oran değiştirebilen (`resmi_bahis_ac`) o bahse yatırım yapamaz (oranı yükseltip yatırıp geri alma).
--  5. Kampüs görevi: yetkilinin açtığı görevde ödül tavanı, kişi başı günlük görev sınırı, SSP'li görevin QR'ı ve
--     onayı yalnızca süperadmin, kişi kendi gönderisini onaylayamaz, yasaklı / silinmiş hesaba ödül verilmez.
--  6. Fotoğraf depolama: en fazla 1 MB, saatte 10 + günde 30 yükleme (eşzamanlı yüklemeler sıraya girer),
--     yasaklı / silinmiş yetkili fotoğraf göremez.
--  7. Düello cevapları yalnızca sonuçlanmış düelloda (tek başına oynayıp iptal olan düellodan bedava cevap
--     anahtarı toplanamaz).
--  8. Gizli başarımın adı ve açıklaması onu açmamış öğrenciye görünmez.

-- ---------------------------------------------------------------------------
-- 1. Veri dışa aktarma (biçim 2)
-- ---------------------------------------------------------------------------

create or replace function public.export_my_data() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  if not exists (select 1 from public.profiles p where p.id = v_uid and p.deleted_at is null) then
    raise exception 'Profil bulunamadı' using errcode = 'P0002';
  end if;

  select jsonb_build_object(
    'format', 'kampusbet-verilerim-2',
    'generated_at', now(),
    'account', (
      select jsonb_build_object('email', u.email, 'created_at', u.created_at, 'email_confirmed_at', u.email_confirmed_at,
                                'last_sign_in_at', u.last_sign_in_at)
      from auth.users u where u.id = v_uid
    ),
    'profile', (
      select jsonb_build_object('first_name', p.first_name, 'last_name', p.last_name, 'department', p.department,
                                'school', c.name, 'role', p.role, 'xp', p.xp, 'level', p.level,
                                'referee_strikes', p.referee_strikes, 'banned_at', p.banned_at,
                                'created_at', p.created_at, 'updated_at', p.updated_at)
      from public.profiles p left join public.clusters c on c.id = p.school_id
      where p.id = v_uid
    ),
    'privacy', (
      select jsonb_build_object('student_email', pp.student_email,
                                'student_email_verified_at', pp.student_email_verified_at,
                                'leaderboard_hidden', pp.leaderboard_hidden)
      from public.profile_private pp where pp.user_id = v_uid
    ),
    'balances', (
      select jsonb_build_object('sp', b.sp_balance, 'ssp', b.ssp_balance, 'updated_at', b.updated_at)
      from public.balances b where b.user_id = v_uid
    ),
    'login_streak', (
      select jsonb_build_object('current', s.current_streak, 'longest', s.longest_streak, 'last_login_date', s.last_login_date)
      from public.login_streaks s where s.user_id = v_uid
    ),
    'memberships', coalesce((
      select jsonb_agg(jsonb_build_object('cluster', c.name, 'type', c.type, 'role', uc.role_in_cluster,
                                          'joined_at', uc.joined_at) order by uc.joined_at)
      from public.user_clusters uc join public.clusters c on c.id = uc.cluster_id
      where uc.user_id = v_uid
    ), '[]'::jsonb),
    'permissions', coalesce((
      select jsonb_agg(jsonb_build_object('cluster', c.name, 'permission', pm.permission_key,
                                          'granted_at', pm.granted_at) order by pm.granted_at)
      from public.permissions pm join public.clusters c on c.id = pm.cluster_id
      where pm.user_id = v_uid
    ), '[]'::jsonb),
    'ledger', coalesce((
      select jsonb_agg(jsonb_build_object('created_at', l.created_at, 'currency', l.currency, 'amount', l.amount,
                                          'balance_after', l.balance_after, 'reason', l.reason,
                                          'ref_type', l.ref_type, 'ref_id', l.ref_id, 'note', l.note) order by l.id)
      from public.ledger_entries l where l.user_id = v_uid
    ), '[]'::jsonb),
    'wagers', coalesce((
      select jsonb_agg(jsonb_build_object('created_at', w.created_at, 'bet_id', w.bet_id, 'bet', b.title,
                                          'bet_type', b.type, 'bet_status', b.status, 'option', o.label,
                                          'amount', w.amount, 'currency', w.currency, 'odds', w.odds,
                                          'payout', w.payout) order by w.created_at, w.id)
      from public.wagers w join public.bets b on b.id = w.bet_id join public.bet_options o on o.id = w.option_id
      where w.user_id = v_uid
    ), '[]'::jsonb),
    'bets_created', coalesce((
      select jsonb_agg(jsonb_build_object('created_at', b.created_at, 'bet_id', b.id, 'title', b.title,
                                          'description', b.description, 'type', b.type, 'status', b.status,
                                          'locks_at', b.locks_at, 'cancel_reason', b.cancel_reason)
                       order by b.created_at, b.id)
      from public.bets b where b.creator_id = v_uid
    ), '[]'::jsonb),
    'bets_refereed', coalesce((
      select jsonb_agg(jsonb_build_object('bet_id', b.id, 'title', b.title, 'status', b.status,
                                          'result_submitted_at', b.result_submitted_at) order by b.created_at, b.id)
      from public.bets b where b.referee_id = v_uid
    ), '[]'::jsonb),
    'disputes', coalesce((
      select jsonb_agg(jsonb_build_object('created_at', d.created_at, 'bet_id', d.bet_id, 'reason', d.reason,
                                          'status', d.status, 'decision', d.decision,
                                          'resolution_note', d.resolution_note, 'resolved_at', d.resolved_at)
                       order by d.created_at, d.id)
      from public.bet_disputes d where d.raised_by = v_uid
    ), '[]'::jsonb),
    'trivia_plays', coalesce((
      select jsonb_agg(jsonb_build_object('bet_id', t.bet_id, 'started_at', t.started_at,
                                          'submitted_at', t.submitted_at, 'answers', t.answers, 'score', t.score,
                                          'elapsed_ms', t.elapsed_ms) order by t.started_at, t.bet_id)
      from public.trivia_duel_plays t where t.player_id = v_uid
    ), '[]'::jsonb),
    'quest_rewards', coalesce((
      select jsonb_agg(jsonb_build_object('claimed_at', qc.claimed_at, 'quest', q.title,
                                          'period_start', qc.period_start, 'currency', qc.reward_currency,
                                          'amount', qc.reward_amount) order by qc.claimed_at)
      from public.quest_claims qc join public.quests q on q.id = qc.quest_id
      where qc.user_id = v_uid
    ), '[]'::jsonb),
    'inventory', coalesce((
      select jsonb_agg(jsonb_build_object('acquired_at', i.acquired_at, 'item', m.name, 'category', i.category,
                                          'equipped', i.equipped, 'price_paid', i.price_paid,
                                          'currency', i.currency) order by i.acquired_at)
      from public.user_inventory i join public.market_items m on m.id = i.item_id
      where i.user_id = v_uid
    ), '[]'::jsonb),
    'xp_events', coalesce((
      select jsonb_agg(jsonb_build_object('created_at', x.created_at, 'reason', x.reason, 'amount', x.amount,
                                          'xp_after', x.xp_after) order by x.id)
      from public.xp_events x where x.user_id = v_uid
    ), '[]'::jsonb),
    'leaderboard', coalesce((
      select jsonb_agg(jsonb_build_object('period', l.period, 'period_start', l.period_start, 'metric', l.metric,
                                          'rank', l.rank, 'value', l.value, 'sample', l.sample)
                       order by l.period, l.period_start, l.metric)
      from public.leaderboard_snapshots l where l.user_id = v_uid
    ), '[]'::jsonb),
    -- Düellolar: kişinin rolü; karşı tarafın kimliği girmez.
    'trivia_duels', coalesce((
      select jsonb_agg(jsonb_build_object('bet_id', d.bet_id, 'created_at', d.created_at,
                                          'role', case when d.challenger_id = v_uid then 'challenger'
                                                       when d.opponent_id = v_uid then 'opponent'
                                                       else 'invited' end,
                                          'stake', d.stake, 'bet_status', b.status) order by d.created_at, d.bet_id)
      from public.trivia_duels d join public.bets b on b.id = d.bet_id
      where v_uid in (d.challenger_id, d.opponent_id, d.invited_id)
    ), '[]'::jsonb),
    'achievements', coalesce((
      select jsonb_agg(jsonb_build_object('unlocked_at', u.unlocked_at, 'achievement', a.title, 'key', a.key,
                                          'reward_sp', u.reward_sp, 'reward_xp', u.reward_xp) order by u.unlocked_at)
      from public.achievement_unlocks u join public.achievements a on a.id = u.achievement_id
      where u.user_id = v_uid
    ), '[]'::jsonb),
    'notifications', coalesce((
      select jsonb_agg(jsonb_build_object('created_at', n.created_at, 'kind', n.kind, 'title', n.title,
                                          'body', n.body, 'link', n.link, 'read_at', n.read_at) order by n.id)
      from public.notifications n where n.user_id = v_uid
    ), '[]'::jsonb),
    -- Kampüs görevi gönderileri; fotoğraf dosyası depolamada (yolu verilir, sahibi indirebilir). İnceleyenin kimliği girmez.
    'campus_task_submissions', coalesce((
      select jsonb_agg(jsonb_build_object('created_at', s.created_at, 'task', t.title, 'method', s.method,
                                          'period_start', s.period_start, 'status', s.status,
                                          'photo_path', s.photo_path, 'photo_delete_after', s.photo_delete_after,
                                          'photo_deleted_at', s.photo_deleted_at, 'review_note', s.review_note,
                                          'reviewed_at', s.reviewed_at, 'reward_currency', s.reward_currency,
                                          'reward_amount', s.reward_amount, 'reward_xp', s.reward_xp)
                       order by s.created_at, s.id)
      from public.campus_task_submissions s join public.campus_tasks t on t.id = s.task_id
      where s.user_id = v_uid
    ), '[]'::jsonb),
    -- Yetkililerin kişi hakkındaki kayıtları (yasak, para düzeltmesi, ihtar sıfırlama...): yapanın kimliği girmez.
    'admin_records_about_me', coalesce((
      select jsonb_agg(jsonb_build_object('created_at', a.created_at, 'action', a.action, 'details', a.details)
                       order by a.id)
      from public.admin_audit_log a where a.target_user_id = v_uid and a.actor_id is distinct from v_uid
    ), '[]'::jsonb),
    -- Kişi yetkiliyse kendi yönetim işlemleri.
    'my_admin_actions', coalesce((
      select jsonb_agg(jsonb_build_object('created_at', a.created_at, 'action', a.action, 'details', a.details)
                       order by a.id)
      from public.admin_audit_log a where a.actor_id = v_uid
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;

revoke execute on function public.export_my_data() from public, anon;

-- ---------------------------------------------------------------------------
-- 2. Okul verisi yalnızca okul maili doğrulanmış öğrenciye ya da yetkiliye
-- ---------------------------------------------------------------------------

-- RLS'te "okulum": profil silinmemiş ve (okul maili doğrulanmış ya da öğrenci değil). Doğrulanmamış öğrenci yalnızca
-- kendi satırlarını görür (okul listesi, genel market / görevler, kampüs görevleri RPC'si açık kalır).
create or replace function private.current_school_id() returns uuid
language sql stable security definer set search_path = '' as $$
  select p.school_id from public.profiles p
  where p.id = (select auth.uid()) and p.deleted_at is null
    and (p.role <> 'student'
         or exists (select 1 from public.profile_private pp
                    where pp.user_id = p.id and pp.student_email_verified_at is not null));
$$;

-- Üye olunan kümeler (bahislerin görünürlüğü): aynı koşulla.
create or replace function private.my_cluster_ids() returns setof uuid
language sql stable security definer set search_path = '' as $$
  select uc.cluster_id from public.user_clusters uc
  where uc.user_id = (select auth.uid()) and private.current_school_id() is not null;
$$;

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
  v_own uuid := private.current_school_id();
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
  -- Kendi okulu yalnızca okul maili doğrulanmışsa (ya da yetkiliyse) görünür; başka okul `analitik_gor` ister.
  if v_school is distinct from v_own and not private.has_permission(v_school, 'analitik_gor') then
    if v_own is null and v_school = private.school_of_user(v_uid) then
      raise exception 'Sıralamayı görmek için okul mailini doğrulamalısın' using errcode = 'KB002';
    end if;
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
        and not exists (
          select 1 from public.profile_private pp where pp.user_id = l.user_id and pp.leaderboard_hidden
        )
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

-- ---------------------------------------------------------------------------
-- 3. Yasak bilgisi okul arkadaşlarına kapalı
-- ---------------------------------------------------------------------------

-- Profil okunurken `banned_at` dışındaki kolonlar. Profile yeni kolon eklenirse buraya da eklenmeli
-- (12_guvenlik testi listeyi denetler).
revoke select on public.profiles from authenticated;
grant select (id, school_id, first_name, last_name, department, role, xp, level, referee_strikes, deleted_at,
              created_at, updated_at)
  on public.profiles to authenticated;

-- Yönetim paneli: verilen kişilerden yasaklı olanlar; yalnızca süperadmin ve kişinin okulunda moderatör
-- (`kullanici_bahsi_denetle`) ya da kullanıcı yöneten görür, diğerleri için satır dönmez.
create function public.banned_users(p_user_ids uuid[])
returns table (user_id uuid, banned_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select p.id, p.banned_at
  from public.profiles p
  where p.id = any (coalesce(p_user_ids, '{}'::uuid[]))
    and p.banned_at is not null
    and (select auth.uid()) is not null
    and (private.has_permission(p.school_id, 'kullanici_bahsi_denetle')
         or private.has_permission(p.school_id, 'kullanici_yonet'));
$$;
revoke execute on function public.banned_users(uuid[]) from public, anon;
grant execute on function public.banned_users(uuid[]) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Resmi bahsi yöneten yatıramaz
-- ---------------------------------------------------------------------------

create or replace function public.place_wager(p_bet_id uuid, p_option_id uuid, p_amount bigint)
returns public.wagers
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_bet public.bets;
  v_odds numeric;
  v_wager_id uuid := gen_random_uuid();
  v_wager public.wagers;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  if not private.is_verified(v_uid) then
    raise exception 'Bahis için okul mailini doğrulamalısın' using errcode = 'KB002';
  end if;

  -- Bahis satırı kilitlenir: aynı bahse gelen yatırımlar ve sonuçlandırma sıraya girer.
  select * into v_bet from public.bets b where b.id = p_bet_id for update;
  if not found or not exists (select 1 from private.my_cluster_ids() c where c = v_bet.cluster_id) then
    raise exception 'Bahis bulunamadı' using errcode = 'P0002';
  end if;
  -- Kendi kendine sonuçlanan mini oyunlara (düello) yalnızca oyun ekranından katılınır.
  if v_bet.type = 'sp_minigame' and v_bet.settlement_mode = 'auto' then
    raise exception 'Bu oyuna yalnızca oyun ekranından katılınır' using errcode = '42501';
  end if;
  if v_bet.status <> 'open' or now() < v_bet.opens_at or now() >= v_bet.locks_at then
    raise exception 'Bahis yatırıma kapalı' using errcode = 'KB003';
  end if;
  -- Sonucu belirleyen (hakem, kapatma izni) ve bahsi yöneten (açan, oranı değiştirebilen) yatıramaz.
  if v_uid = v_bet.referee_id
     or (v_bet.settlement_mode = 'admin'
         and (v_uid = v_bet.creator_id or private.has_permission(v_bet.cluster_id, 'resmi_bahis_kapat')
              or private.has_permission(v_bet.cluster_id, 'resmi_bahis_ac'))) then
    raise exception 'Bahsi yöneten ya da sonucunu belirleyen kişi bu bahse yatırım yapamaz' using errcode = '42501';
  end if;
  select o.odds into v_odds from public.bet_options o where o.id = p_option_id and o.bet_id = p_bet_id;
  if not found then
    raise exception 'Seçenek bulunamadı' using errcode = 'P0002';
  end if;
  if p_amount is null or p_amount < v_bet.min_stake or (v_bet.max_stake is not null and p_amount > v_bet.max_stake) then
    raise exception 'Yatırım tutarı bu bahsin sınırları dışında' using errcode = '23514';
  end if;
  if exists (select 1 from public.wagers w where w.bet_id = p_bet_id and w.user_id = v_uid) then
    raise exception 'Bu bahse zaten yatırım yaptın' using errcode = 'KB004';
  end if;

  perform private.post_ledger(v_uid, v_bet.currency, -p_amount, 'bet_stake', 'wager', v_wager_id, v_uid);

  insert into public.wagers (id, bet_id, option_id, user_id, amount, currency, odds)
  values (v_wager_id, p_bet_id, p_option_id, v_uid, p_amount, v_bet.currency,
          case when v_bet.odds_mode = 'fixed' then v_odds end)
  returning * into v_wager;

  update public.bet_options set pool_amount = pool_amount + p_amount where id = p_option_id;
  update public.bets set pool_total = pool_total + p_amount where id = p_bet_id;

  return v_wager;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Kampüs görevi: ödül tavanı, günlük sınır, SSP yalnızca süperadmin, onay kenar durumları
-- ---------------------------------------------------------------------------

alter table public.economy_settings
  add column campus_task_staff_max_reward integer not null default 100
    check (campus_task_staff_max_reward between 1 and 1000),
  add column campus_task_staff_max_xp integer not null default 50 check (campus_task_staff_max_xp between 0 and 500),
  add column campus_task_daily_limit integer not null default 5 check (campus_task_daily_limit between 1 and 100);

-- Kişinin bugün (İstanbul) bekleyen ya da onaylı kampüs görevi gönderisi sınırı. Aynı kişinin eşzamanlı gönderileri
-- sıraya girer (danışma kilidi; görev satırı kilidinden sonra alınır, başka yerde alınmaz).
create function private.check_campus_daily_limit(p_user_id uuid) returns void
language plpgsql set search_path = '' as $$
declare
  v_limit integer;
begin
  perform pg_advisory_xact_lock(hashtextextended('campus_daily:' || p_user_id::text, 0));
  select s.campus_task_daily_limit into v_limit from public.economy_settings s where s.id;
  if (select count(*) from public.campus_task_submissions s
      where s.user_id = p_user_id and s.status in ('pending', 'approved')
        and s.created_at >= date_trunc('day', now() at time zone 'Europe/Istanbul') at time zone 'Europe/Istanbul')
     >= v_limit then
    raise exception 'Bugün en fazla % kampüs görevi yapabilirsin', v_limit using errcode = 'KB035';
  end if;
end;
$$;
revoke execute on function private.check_campus_daily_limit(uuid) from public;

create or replace function public.save_campus_task(
  p_id uuid,
  p_school_id uuid,
  p_title text,
  p_description text,
  p_icon text,
  p_verification public.campus_verification,
  p_period public.campus_period,
  p_reward_currency public.currency,
  p_reward_amount integer,
  p_reward_xp integer,
  p_quota integer,
  p_qr_rotation_seconds integer,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_active boolean
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_old public.campus_tasks;
  v_id uuid;
  v_cfg public.economy_settings;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  if p_school_id is null or p_title is null or p_verification is null or p_period is null
     or p_reward_currency is null or p_reward_amount is null or p_reward_xp is null
     or p_qr_rotation_seconds is null or p_active is null then
    raise exception 'Zorunlu alanlar doldurulmalı' using errcode = '23514';
  end if;
  if not exists (select 1 from public.clusters c where c.id = p_school_id and c.type = 'school') then
    raise exception 'Okul bulunamadı' using errcode = 'P0002';
  end if;
  if not private.has_permission(p_school_id, 'kampus_gorevi_yonet') then
    raise exception 'Bu okulda kampüs görevi yönetme iznin yok' using errcode = '42501';
  end if;
  -- SSP prestijlidir: yalnızca süperadminin açtığı (ya da düzenlediği) görev SSP verir.
  if p_reward_currency = 'SSP' and not private.is_superadmin() then
    raise exception 'SSP ödüllü görevi yalnızca süperadmin açar' using errcode = '42501';
  end if;
  -- Yetkilinin açtığı / düzenlediği görevde ödül tavanı (yetkili arkadaşlarına sınırsız SP / XP dağıtamasın).
  if not private.is_superadmin() then
    select * into v_cfg from public.economy_settings s where s.id;
    if p_reward_amount > v_cfg.campus_task_staff_max_reward or p_reward_xp > v_cfg.campus_task_staff_max_xp then
      raise exception 'Görev ödülü en fazla % SP ve % XP olabilir',
        v_cfg.campus_task_staff_max_reward, v_cfg.campus_task_staff_max_xp using errcode = '23514';
    end if;
  end if;

  if p_id is not null then
    select * into v_old from public.campus_tasks t where t.id = p_id for update;
    if not found or not private.has_permission(v_old.school_id, 'kampus_gorevi_yonet') then
      raise exception 'Görev bulunamadı' using errcode = 'P0002';
    end if;
    if v_old.school_id <> p_school_id or v_old.verification <> p_verification then
      raise exception 'Görevin okulu ve doğrulama yöntemi sonradan değiştirilemez' using errcode = '23514';
    end if;
    if v_old.reward_currency = 'SSP' and not private.is_superadmin() then
      raise exception 'SSP ödüllü görevi yalnızca süperadmin düzenler' using errcode = '42501';
    end if;
    update public.campus_tasks t
    set title = btrim(p_title), description = nullif(btrim(coalesce(p_description, '')), ''),
        icon = coalesce(nullif(btrim(coalesce(p_icon, '')), ''), '📍'), period = p_period,
        reward_currency = p_reward_currency, reward_amount = p_reward_amount, reward_xp = p_reward_xp,
        quota = p_quota, qr_rotation_seconds = p_qr_rotation_seconds, starts_at = p_starts_at, ends_at = p_ends_at,
        active = p_active, updated_at = now()
    where t.id = p_id;
    v_id := p_id;
  else
    insert into public.campus_tasks (school_id, title, description, icon, verification, period, reward_currency,
                                     reward_amount, reward_xp, quota, qr_rotation_seconds, starts_at, ends_at, active,
                                     created_by)
    values (p_school_id, btrim(p_title), nullif(btrim(coalesce(p_description, '')), ''),
            coalesce(nullif(btrim(coalesce(p_icon, '')), ''), '📍'), p_verification, p_period, p_reward_currency,
            p_reward_amount, p_reward_xp, p_quota, p_qr_rotation_seconds, p_starts_at, p_ends_at, p_active, v_uid)
    returning id into v_id;
    insert into private.campus_task_secrets (task_id) values (v_id);
  end if;

  insert into public.admin_audit_log (actor_id, action, cluster_id, details)
  values (v_uid, 'campus_task_save', p_school_id,
          jsonb_build_object('task_id', v_id, 'title', btrim(p_title), 'verification', p_verification,
                             'reward', p_reward_amount, 'currency', p_reward_currency, 'xp', p_reward_xp,
                             'active', p_active, 'new', p_id is null));
  return v_id;
end;
$$;

-- SSP ödüllü görevin QR'ını yalnızca süperadmin alır ve yeniler (SSP'yi kimin alacağına yetkili karar vermesin).
create or replace function public.reset_campus_task_qr(p_task_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_task public.campus_tasks;
begin
  select * into v_task from public.campus_tasks t where t.id = p_task_id;
  if v_uid is null or not found or not private.has_permission(v_task.school_id, 'kampus_gorevi_yonet')
     or (v_task.reward_currency = 'SSP' and not private.is_superadmin()) then
    raise exception 'Görev bulunamadı' using errcode = 'P0002';
  end if;
  update private.campus_task_secrets s set secret = extensions.gen_random_bytes(32), rotated_at = now()
  where s.task_id = p_task_id;
  insert into public.admin_audit_log (actor_id, action, cluster_id, details)
  values (v_uid, 'campus_task_qr_reset', v_task.school_id, jsonb_build_object('task_id', p_task_id));
end;
$$;

create or replace function public.campus_task_qr(p_task_id uuid)
returns table (code text, payload text, rotation_seconds integer, valid_until timestamptz)
language plpgsql security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_task public.campus_tasks;
  v_code text;
begin
  select * into v_task from public.campus_tasks t where t.id = p_task_id;
  if (select auth.uid()) is null or not found or v_task.verification <> 'qr'
     or not private.has_permission(v_task.school_id, 'kampus_gorevi_yonet')
     or (v_task.reward_currency = 'SSP' and not private.is_superadmin()) then
    raise exception 'Görev bulunamadı' using errcode = 'P0002';
  end if;
  v_code := private.campus_qr_code(p_task_id, now());
  return query select v_code,
    'com.kampusbet.kampusbet://kampus-gorev?t=' || p_task_id || '&c=' || v_code,
    v_task.qr_rotation_seconds,
    case when v_task.qr_rotation_seconds = 0 then null::timestamptz
         else to_timestamp((floor(extract(epoch from now()) / v_task.qr_rotation_seconds) + 1)
                           * v_task.qr_rotation_seconds) end;
end;
$$;

-- QR ve fotoğraf gönderisi: günlük sınır (KB035).
create or replace function public.submit_campus_task_qr(p_task_id uuid, p_code text)
returns table (reward_currency public.currency, reward_amount integer, reward_xp integer, balance bigint)
language plpgsql security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
  v_task public.campus_tasks;
  v_code text := upper(btrim(coalesce(p_code, '')));
  v_ps timestamptz;
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  if not exists (select 1 from public.profiles p where p.id = v_uid and p.deleted_at is null) then
    raise exception 'Profil bulunamadı' using errcode = 'P0002';
  end if;
  if not private.is_verified(v_uid) then
    raise exception 'Kampüs görevi için okul mailini doğrulamalısın' using errcode = 'KB002';
  end if;
  -- Kontenjan ve dönem kontrolü sırayla: görev satırı kilitlenir (FOR NO KEY UPDATE: gönderi eklemenin
  -- yabancı anahtar kilidiyle çakışmaz).
  select * into v_task from public.campus_tasks t
  where t.id = p_task_id and t.school_id = private.current_school_id()
  for no key update;
  if not found then
    raise exception 'Görev bulunamadı' using errcode = 'P0002';
  end if;
  if private.has_permission(v_task.school_id, 'kampus_gorevi_yonet') then
    raise exception 'Kampüs görevlerini yöneten ödül alamaz' using errcode = '42501';
  end if;
  if not v_task.active or v_task.verification <> 'qr'
     or (v_task.starts_at is not null and v_task.starts_at > now())
     or (v_task.ends_at is not null and v_task.ends_at <= now()) then
    raise exception 'Bu görev şu an açık değil' using errcode = 'KB032';
  end if;
  if v_code = '' or (v_code <> private.campus_qr_code(v_task.id, now())
                     and (v_task.qr_rotation_seconds = 0
                          or v_code <> private.campus_qr_code(v_task.id, now() - make_interval(secs => v_task.qr_rotation_seconds)))) then
    raise exception 'QR kodu geçersiz ya da süresi geçti' using errcode = 'KB029';
  end if;

  v_ps := private.campus_period_start(v_task.period, now());
  if exists (select 1 from public.campus_task_submissions s
             where s.task_id = v_task.id and s.user_id = v_uid and s.period_start = v_ps
               and s.status in ('pending', 'approved')) then
    raise exception 'Bu görevi bu dönem zaten yaptın' using errcode = 'KB030';
  end if;
  if v_task.quota is not null and (select count(*) from public.campus_task_submissions s
                                   where s.task_id = v_task.id and s.status = 'approved') >= v_task.quota then
    raise exception 'Görevin kontenjanı doldu' using errcode = 'KB031';
  end if;
  perform private.check_campus_daily_limit(v_uid);

  insert into public.campus_task_submissions (task_id, user_id, period_start, method, status, reward_currency,
                                              reward_amount, reward_xp)
  values (v_task.id, v_uid, v_ps, 'qr', 'approved', v_task.reward_currency, v_task.reward_amount, v_task.reward_xp)
  returning id into v_id;

  reward_currency := v_task.reward_currency;
  reward_amount := v_task.reward_amount;
  reward_xp := v_task.reward_xp;
  balance := private.pay_campus_submission(v_id);
  return next;
end;
$$;

create or replace function public.submit_campus_task_photo(p_task_id uuid, p_path text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_task public.campus_tasks;
  v_ps timestamptz;
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  if not exists (select 1 from public.profiles p where p.id = v_uid and p.deleted_at is null) then
    raise exception 'Profil bulunamadı' using errcode = 'P0002';
  end if;
  if not private.is_verified(v_uid) then
    raise exception 'Kampüs görevi için okul mailini doğrulamalısın' using errcode = 'KB002';
  end if;
  select * into v_task from public.campus_tasks t
  where t.id = p_task_id and t.school_id = private.current_school_id()
  for no key update;
  if not found then
    raise exception 'Görev bulunamadı' using errcode = 'P0002';
  end if;
  if private.has_permission(v_task.school_id, 'kampus_gorevi_yonet') then
    raise exception 'Kampüs görevlerini yöneten ödül alamaz' using errcode = '42501';
  end if;
  if not v_task.active or v_task.verification <> 'photo'
     or (v_task.starts_at is not null and v_task.starts_at > now())
     or (v_task.ends_at is not null and v_task.ends_at <= now()) then
    raise exception 'Bu görev şu an açık değil' using errcode = 'KB032';
  end if;
  if p_path is null or split_part(p_path, '/', 1) <> v_uid::text
     or not exists (select 1 from storage.objects o where o.bucket_id = 'campus-proofs' and o.name = p_path)
     or exists (select 1 from public.campus_task_submissions s where s.photo_path = p_path) then
    raise exception 'Fotoğraf bulunamadı ya da daha önce kullanıldı' using errcode = 'KB034';
  end if;

  v_ps := private.campus_period_start(v_task.period, now());
  if exists (select 1 from public.campus_task_submissions s
             where s.task_id = v_task.id and s.user_id = v_uid and s.period_start = v_ps
               and s.status in ('pending', 'approved')) then
    raise exception 'Bu görevi bu dönem zaten yaptın ya da onay bekliyor' using errcode = 'KB030';
  end if;
  if v_task.quota is not null and (select count(*) from public.campus_task_submissions s
                                   where s.task_id = v_task.id and s.status = 'approved') >= v_task.quota then
    raise exception 'Görevin kontenjanı doldu' using errcode = 'KB031';
  end if;
  perform private.check_campus_daily_limit(v_uid);

  insert into public.campus_task_submissions (task_id, user_id, period_start, method, status, photo_path,
                                              reward_currency, reward_amount, reward_xp)
  values (v_task.id, v_uid, v_ps, 'photo', 'pending', p_path, v_task.reward_currency, v_task.reward_amount,
          v_task.reward_xp)
  returning id into v_id;

  -- Okulun yetkililerine haber (görev başına günde bir).
  insert into public.notifications (user_id, kind, title, body, link, dedupe_key)
  select distinct pm.user_id, 'campus_review_new', 'Onay bekleyen fotoğraf',
         left('«' || v_task.title || '» için onay bekleyen gönderi var (yönetim paneli > Kampüs görevleri > Onay).', 400),
         null::text, 'campus_review:' || v_task.id || ':' || to_char(now() at time zone 'Europe/Istanbul', 'YYYYMMDD')
  from public.permissions pm join public.profiles p on p.id = pm.user_id and p.deleted_at is null
  where pm.cluster_id = v_task.school_id and pm.permission_key = 'kampus_gorevi_yonet'
  on conflict do nothing;
  return v_id;
end;
$$;

-- Onay: kendi gönderisi yok, SSP'li gönderi yalnızca süperadmin, yasaklı / silinmiş hesaba ödül yok (KB036).
create or replace function public.review_campus_submission(p_submission_id uuid, p_approve boolean, p_note text default null)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_s public.campus_task_submissions;
  v_task public.campus_tasks;
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  select * into v_s from public.campus_task_submissions s where s.id = p_submission_id;
  if not found then
    raise exception 'Gönderi bulunamadı' using errcode = 'P0002';
  end if;
  -- Kilit sırası gönderiyle aynı: önce görev satırı (kontenjan), sonra gönderi.
  select * into v_task from public.campus_tasks t where t.id = v_s.task_id for no key update;
  if not private.has_permission(v_task.school_id, 'kampus_gorevi_yonet') then
    raise exception 'Gönderi bulunamadı' using errcode = 'P0002';
  end if;
  if v_s.user_id = v_uid then
    raise exception 'Kendi gönderini onaylayamaz ya da reddedemezsin' using errcode = '42501';
  end if;
  if v_s.reward_currency = 'SSP' and not private.is_superadmin() then
    raise exception 'SSP ödüllü gönderiye yalnızca süperadmin karar verir' using errcode = '42501';
  end if;
  select * into v_s from public.campus_task_submissions s where s.id = p_submission_id for update;
  if v_s.status <> 'pending' then
    raise exception 'Bu gönderi zaten karara bağlandı' using errcode = 'KB033';
  end if;
  if p_approve is null or (not p_approve and (v_note is null or char_length(v_note) < 3)) then
    raise exception 'Reddederken gerekçe yaz (en az 3 karakter)' using errcode = '23514';
  end if;

  if p_approve then
    if exists (select 1 from public.profiles p
               where p.id = v_s.user_id and (p.deleted_at is not null or p.banned_at is not null)) then
      raise exception 'Gönderenin hesabı yasaklı ya da silinmiş; gönderi yalnızca reddedilebilir' using errcode = 'KB036';
    end if;
    if v_task.quota is not null and (select count(*) from public.campus_task_submissions s
                                     where s.task_id = v_task.id and s.status = 'approved') >= v_task.quota then
      raise exception 'Görevin kontenjanı doldu' using errcode = 'KB031';
    end if;
    update public.campus_task_submissions s
    set status = 'approved', reviewed_by = v_uid, reviewed_at = now(), review_note = v_note,
        photo_delete_after = now() + interval '30 days'
    where s.id = v_s.id;
    perform private.pay_campus_submission(v_s.id);
    insert into public.notifications (user_id, kind, title, body, link, dedupe_key)
    select v_s.user_id, 'campus_approved', 'Kampüs görevin onaylandı',
           left('«' || v_task.title || '»: +' || v_s.reward_amount || ' ' || v_s.reward_currency
                || case when v_s.reward_xp > 0 then ' · +' || v_s.reward_xp || ' XP' else '' end || ' hesabında.', 400),
           '/kampus-gorevleri', 'campus_review_done:' || v_s.id
    from public.profiles p where p.id = v_s.user_id and p.deleted_at is null
    on conflict do nothing;
  else
    update public.campus_task_submissions s
    set status = 'rejected', reviewed_by = v_uid, reviewed_at = now(), review_note = v_note,
        photo_delete_after = now() + interval '30 days'
    where s.id = v_s.id;
    insert into public.notifications (user_id, kind, title, body, link, dedupe_key)
    select v_s.user_id, 'campus_rejected', 'Kampüs görevin reddedildi',
           left('«' || v_task.title || '»: ' || v_note || ' Yeniden deneyebilirsin.', 400),
           '/kampus-gorevleri', 'campus_review_done:' || v_s.id
    from public.profiles p where p.id = v_s.user_id and p.deleted_at is null
    on conflict do nothing;
  end if;

  insert into public.admin_audit_log (actor_id, action, target_user_id, cluster_id, details)
  values (v_uid, 'campus_review', v_s.user_id, v_task.school_id,
          jsonb_build_object('submission_id', v_s.id, 'task_id', v_task.id, 'approved', p_approve, 'note', v_note));
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. Fotoğraf depolama
-- ---------------------------------------------------------------------------

-- Uygulama fotoğrafı ≤ 1280 piksel JPEG'e küçültür (tipik 50–400 KB).
update storage.buckets set file_size_limit = 1048576 where id = 'campus-proofs';

-- Yükleme: kendi klasörü, doğrulanmış, yasaklı değil; saatte 10, günde 30. Sayım danışma kilidinden sonra yapılır
-- (volatile: kilit beklenince eşzamanlı yüklemenin satırı görülür).
create or replace function private.campus_upload_allowed(p_name text) returns boolean
language plpgsql volatile security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null or p_name is null
     or p_name !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.jpg$'
     or split_part(p_name, '/', 1) <> v_uid::text
     or not private.is_verified(v_uid)
     or exists (select 1 from public.profiles p where p.id = v_uid and p.banned_at is not null) then
    return false;
  end if;
  perform pg_advisory_xact_lock(hashtextextended('campus_upload:' || v_uid::text, 0));
  return (select count(*) filter (where o.created_at > now() - interval '1 hour') < 10
                 and count(*) < 30
          from storage.objects o
          where o.bucket_id = 'campus-proofs' and o.name like v_uid::text || '/%'
            and o.created_at > now() - interval '1 day');
end;
$$;

-- Okuma: okuyan yasaklı ya da silinmiş değilse; fotoğrafın sahibi ya da sahibin okulunda kampüs görevi yöneten.
create or replace function private.campus_proof_readable(p_name text) returns boolean
language plpgsql stable security definer set search_path = '' as $$
declare
  v_owner uuid;
begin
  if (select auth.uid()) is null
     or exists (select 1 from public.profiles p
                where p.id = (select auth.uid()) and (p.deleted_at is not null or p.banned_at is not null)) then
    return false;
  end if;
  begin
    v_owner := split_part(p_name, '/', 1)::uuid;
  exception when invalid_text_representation then
    return false;
  end;
  return v_owner = (select auth.uid())
    or private.has_permission(private.school_of_user(v_owner), 'kampus_gorevi_yonet');
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. Düello cevapları yalnızca sonuçlanmış düelloda
-- ---------------------------------------------------------------------------

create or replace function public.trivia_duel_review(p_bet_id uuid)
returns table (
  question_no integer, question text, options text[], correct_index smallint,
  my_answer smallint, opponent_answer smallint
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
  v_duel public.trivia_duels;
  v_status public.bet_status;
  v_mine public.trivia_duel_plays;
  v_other public.trivia_duel_plays;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  select d.* into v_duel from public.trivia_duels d where d.bet_id = p_bet_id;
  select b.status into v_status from public.bets b where b.id = p_bet_id;
  select t.* into v_mine from public.trivia_duel_plays t where t.bet_id = p_bet_id and t.player_id = v_uid;
  -- Görünmeyen, sonuçlanmamış ya da iptal olmuş düello, düellonun oyuncusu olmayan ve hiç oynamayan için
  -- "bulunamadı". İptal (rakip çıkmadı, para iade) dahil değil: tek başına oynayıp bedava cevap anahtarı toplanmasın.
  if v_duel.bet_id is null
     or v_uid not in (v_duel.challenger_id, coalesce(v_duel.opponent_id, v_duel.challenger_id))
     or v_status <> 'settled'
     or v_mine.bet_id is null then
    raise exception 'Düello cevapları bulunamadı' using errcode = 'P0002';
  end if;
  select t.* into v_other from public.trivia_duel_plays t
  where t.bet_id = p_bet_id and t.player_id <> v_uid;

  return query
    select u.ord::integer, q.question, q.options, q.correct_index,
           v_mine.answers[u.ord::integer], v_other.answers[u.ord::integer]
    from unnest(v_duel.question_ids) with ordinality as u(question_id, ord)
    join public.trivia_questions q on q.id = u.question_id
    order by u.ord;
end;
$$;

-- ---------------------------------------------------------------------------
-- 8. Gizli başarım: açmayan göremez
-- ---------------------------------------------------------------------------

drop policy achievements_select on public.achievements;
create policy achievements_select on public.achievements
  for select to authenticated
  using (
    not hidden
    or exists (select 1 from public.achievement_unlocks u
               where u.achievement_id = achievements.id and u.user_id = (select auth.uid()))
    or (select private.is_superadmin())
  );
