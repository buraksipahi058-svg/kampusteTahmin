-- Adım 14: gizlilik (docs/harita/acik-isler.md; KARARLAR "Gizlilik ve istek sınırı").
--
-- 1. Sıralamadan çıkma: kişi isterse liderlikte görünmez. Tercih gizli profilde (okul arkadaşları görmez);
--    gizli kişi sıralama hesabına hiç girmez (sıra numaralarında boşluk olmaz), açınca bir sonraki hesaplamada döner.
-- 2. Veri dışa aktarma (KVKK m. 11): kişi hesabındaki bütün kayıtları tek JSON olarak alır.
-- 3. İstek sınırı: istek bekçisi, giriş yapmış kişinin yazma isteklerini dakikada sayar (`KB026`).
--    Okuma istekleri (salt okunur transaction) sayılmaz. Başarısız istekler transaction'la geri alındığı
--    için sayılmaz (bilinen sınır; docs/harita/guvenlik.md).

-- ---------------------------------------------------------------------------
-- 1. Sıralamadan çıkma
-- ---------------------------------------------------------------------------

alter table public.profile_private add column leaderboard_hidden boolean not null default false;

create function public.set_leaderboard_hidden(p_hidden boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  if p_hidden is null then
    raise exception 'Geçersiz tercih' using errcode = '23514';
  end if;
  update public.profile_private pp set leaderboard_hidden = p_hidden
  from public.profiles p
  where pp.user_id = v_uid and p.id = pp.user_id and p.deleted_at is null;
  if not found then
    raise exception 'Profil bulunamadı' using errcode = 'P0002';
  end if;
  -- Gizlenince eski sıralama satırları da hemen silinir (donmuş geçmiş haftalar dahil).
  if p_hidden then
    delete from public.leaderboard_snapshots l where l.user_id = v_uid;
  end if;
end;
$$;

revoke execute on function public.set_leaderboard_hidden(boolean) from public, anon;
grant execute on function public.set_leaderboard_hidden(boolean) to authenticated;

-- Hesaplama: gizli kişi sıralamaya hiç girmez (yalnızca `sw` süzgeci yeni).
create or replace function private.store_leaderboard(
  p_school_id uuid, p_period public.leaderboard_period, p_day date, p_from timestamptz, p_to timestamptz
) returns void
language plpgsql set search_path = '' as $$
declare
  v_min integer;
begin
  select case p_period when 'week' then s.leaderboard_min_predictions_week else s.leaderboard_min_predictions_all end
    into v_min
  from public.economy_settings s where s.id;

  delete from public.leaderboard_snapshots l
  where l.school_id = p_school_id and l.period = p_period and l.period_start is not distinct from p_day;

  insert into public.leaderboard_snapshots (school_id, period, period_start, metric, user_id, rank, value, sample, computed_at)
  with sw as (
    select w.* from private.settled_wagers(p_school_id, null, p_from, p_to) w
    where not exists (
      select 1 from public.profile_private pp where pp.user_id = w.user_id and pp.leaderboard_hidden
    )
  ),
  preds as (
    -- grp: art arda aynı sonuçtaki tahminler aynı değeri alır (boşluk-ada yöntemi).
    select sw.user_id, sw.correct,
           row_number() over (partition by sw.user_id order by sw.settled_at, sw.bet_id)
             - row_number() over (partition by sw.user_id, sw.correct order by sw.settled_at, sw.bet_id) as grp
    from sw where sw.is_prediction
  ),
  totals as (
    select p.user_id, count(*)::integer as n, count(*) filter (where p.correct)::integer as hits
    from preds p group by p.user_id
  ),
  runs as (
    select p.user_id, count(*)::integer as len from preds p where p.correct group by p.user_id, p.grp
  ),
  profit as (
    select sw.user_id, sw.currency, sum(sw.net) as total, count(*)::integer as n
    from sw group by sw.user_id, sw.currency
    having sum(sw.net) > 0
  ),
  scored as (
    select 'hit_rate'::public.leaderboard_metric as metric, t.user_id, t.hits::numeric / t.n as value, t.n as sample,
           rank() over (order by t.hits::numeric / t.n desc, t.n desc) as rnk
    from totals t where t.n >= v_min
    union all
    select 'best_streak', r.user_id, max(r.len)::numeric, t.n,
           rank() over (order by max(r.len) desc)
    from runs r join totals t on t.user_id = r.user_id
    group by r.user_id, t.n
    union all
    select case pr.currency when 'SP' then 'sp_profit'::public.leaderboard_metric else 'ssp_profit' end,
           pr.user_id, pr.total, pr.n,
           rank() over (partition by pr.currency order by pr.total desc)
    from profit pr
  )
  select p_school_id, p_period, p_day, sc.metric, sc.user_id, sc.rnk::integer, sc.value, sc.sample, now()
  from scored sc;

  delete from private.leaderboard_runs r
  where r.school_id = p_school_id and r.period = p_period and r.period_start is not distinct from p_day;
  insert into private.leaderboard_runs (school_id, period, period_start, computed_at)
  values (p_school_id, p_period, p_day, now());
end;
$$;

revoke execute on function
  private.store_leaderboard(uuid, public.leaderboard_period, date, timestamptz, timestamptz)
from public;

-- Okuma: gizli kişi gösterilmez (eşzamanlı hesaplamada yazılmış olsa da). Yalnızca `s` süzgeci yeni.
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
-- 2. Veri dışa aktarma
-- ---------------------------------------------------------------------------

-- Kişinin kendi verileri, tek JSON. Başkalarının kişisel verisi girmez (karşı taraf adı, yetkili kimliği yok).
-- Salt okunur değil (volatile): istek sınırına sayılsın.
create function public.export_my_data() returns jsonb
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
    'format', 'kampusbet-verilerim-1',
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
grant execute on function public.export_my_data() to authenticated;

-- ---------------------------------------------------------------------------
-- 3. İstek sınırı
-- ---------------------------------------------------------------------------

alter table public.economy_settings
  add column api_write_limit_per_minute integer not null default 60
    check (api_write_limit_per_minute between 10 and 10000);

-- Sayaç: kalıcı olması gerekmez (unlogged: WAL'a yazılmaz, çökmede boşalır). Yalnızca bekçi yazar.
create unlogged table private.request_log (
  user_id uuid not null,
  at timestamptz not null default now()
);
create index request_log_user_at on private.request_log (user_id, at);
alter table private.request_log enable row level security;
revoke all on private.request_log from public, anon, authenticated;

-- Bekçi artık yazma isteklerini de sayar (volatile). Salt okunur transaction'lar (GET, stable RPC) sayılmaz.
create or replace function guard.check_request() returns void
language plpgsql volatile security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_limit integer;
  v_count integer;
begin
  if v_uid is null then
    return;
  end if;
  if exists (
    select 1 from public.profiles p
    where p.id = v_uid and (p.deleted_at is not null or p.banned_at is not null)
  ) then
    raise exception 'Bu hesap kullanılamıyor' using errcode = 'KB025';
  end if;

  if current_setting('transaction_read_only') = 'on' then
    return;
  end if;
  select s.api_write_limit_per_minute into v_limit from public.economy_settings s where s.id;
  select count(*) into v_count from private.request_log r
  where r.user_id = v_uid and r.at > now() - interval '1 minute';
  if v_count >= coalesce(v_limit, 60) then
    raise exception 'Çok fazla istek gönderildi; biraz bekleyip tekrar dene' using errcode = 'KB026';
  end if;
  insert into private.request_log (user_id) values (v_uid);
end;
$$;

revoke execute on function guard.check_request() from public;
grant execute on function guard.check_request() to anon, authenticated;

create function private.prune_request_log() returns void
language sql set search_path = '' as $$
  delete from private.request_log r where r.at < now() - interval '5 minutes';
$$;
revoke execute on function private.prune_request_log() from public;

select cron.schedule('kampusbet_istek_sayaci', '*/10 * * * *', 'select private.prune_request_log()');

notify pgrst, 'reload schema';
