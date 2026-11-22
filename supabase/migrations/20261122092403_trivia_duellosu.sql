-- Adım 8: mini oyun — trivia düellosu (MIMARI §4.2; KARARLAR "Mini oyun: trivia düellosu").
--
-- İki kişi eşit SP yatırır, aynı soruları çözer; çok doğru yapan, eşitlikte sunucu saatine göre daha
-- hızlı olan havuzu alır; tam beraberlikte iade. Para akışı bahis altyapısındadır: düello bir
-- `sp_minigame` bahsidir, seçenekleri "Meydan okuyan" (1) / "Rakip" (2); her oyuncu kendi seçeneğine
-- yatırır, kazananın seçeneği kazanır (havuz kazananın).
--
-- Hile önlemleri: doğru cevaplar (`trivia_questions.correct_index`) istemciye hiç gitmez, öğrenciler
-- soru tablosunu okuyamaz; sorular yalnızca oyun başlayınca start_trivia_duel ile verilir; süre
-- sunucu saatiyle ölçülür. Soru yönetebilen (trivia_yonet, süperadmin) düello oynayamaz.
-- Genel bahis yatırma (place_wager) mini oyunlara kapalıdır.

-- ---------------------------------------------------------------------------
-- Ayarlar ve tablolar
-- ---------------------------------------------------------------------------

alter table public.economy_settings
  add column trivia_question_count integer not null default 5 check (trivia_question_count between 3 and 10),
  add column trivia_seconds_per_question integer not null default 15 check (trivia_seconds_per_question between 5 and 60),
  add column duel_max_stake_sp integer not null default 100 check (duel_max_stake_sp > 0),
  add column duel_accept_hours integer not null default 24 check (duel_accept_hours between 1 and 168),
  add column duel_play_hours integer not null default 24 check (duel_play_hours between 1 and 168);

create table public.trivia_questions (
  id uuid primary key default gen_random_uuid(),
  -- null: tüm okullar (yalnızca süperadmin yönetir)
  school_id uuid references public.clusters (id) on delete restrict,
  question text not null check (char_length(question) between 5 and 300 and question = btrim(question)),
  options text[] not null check (cardinality(options) between 2 and 4 and array_position(options, null) is null and array_position(options, '') is null),
  correct_index smallint not null check (correct_index >= 0 and correct_index < cardinality(options)),
  category text check (category is null or (char_length(category) between 2 and 50 and category = btrim(category))),
  active boolean not null default true,
  created_by uuid references public.profiles (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index trivia_questions_school_active_idx on public.trivia_questions (school_id) where active;

create trigger trivia_questions_require_school
  before insert or update of school_id on public.trivia_questions
  for each row when (new.school_id is not null) execute function private.require_school('school_id');

create trigger trivia_questions_set_updated_at
  before update on public.trivia_questions
  for each row execute function private.set_updated_at();

create table public.trivia_duels (
  bet_id uuid primary key references public.bets (id) on delete restrict,
  school_id uuid not null references public.clusters (id) on delete restrict,
  challenger_id uuid not null references public.profiles (id) on delete restrict,
  opponent_id uuid references public.profiles (id) on delete restrict,
  -- Belirli kişiye meydan okuma; null ise okula açık.
  invited_id uuid references public.profiles (id) on delete restrict,
  stake bigint not null check (stake > 0),
  question_ids uuid[] not null,
  accept_deadline timestamptz not null,
  play_deadline timestamptz,
  created_at timestamptz not null default now(),
  constraint trivia_duels_two_players check (opponent_id is null or opponent_id <> challenger_id),
  constraint trivia_duels_play_deadline check ((opponent_id is null) = (play_deadline is null))
);
create index trivia_duels_school_idx on public.trivia_duels (school_id, created_at desc);
create index trivia_duels_challenger_idx on public.trivia_duels (challenger_id);
create index trivia_duels_opponent_idx on public.trivia_duels (opponent_id) where opponent_id is not null;
create index trivia_duels_invited_idx on public.trivia_duels (invited_id) where invited_id is not null;

create table public.trivia_duel_plays (
  bet_id uuid not null references public.trivia_duels (bet_id) on delete restrict,
  player_id uuid not null references public.profiles (id) on delete restrict,
  started_at timestamptz not null default now(),
  submitted_at timestamptz,
  answers smallint[],
  score integer check (score >= 0),
  elapsed_ms integer check (elapsed_ms >= 0),
  primary key (bet_id, player_id),
  constraint trivia_duel_plays_submitted check ((submitted_at is null) = (score is null))
);
create index trivia_duel_plays_player_idx on public.trivia_duel_plays (player_id);

-- ---------------------------------------------------------------------------
-- Görünürlük
-- ---------------------------------------------------------------------------

revoke all on public.trivia_questions, public.trivia_duels, public.trivia_duel_plays from anon, authenticated;
grant select on public.trivia_questions, public.trivia_duels, public.trivia_duel_plays to authenticated;
alter table public.trivia_questions enable row level security;
alter table public.trivia_duels enable row level security;
alter table public.trivia_duel_plays enable row level security;

-- Öğrenci soruları göremez (sorular yalnızca oyunda, cevapsız verilir). Yönetenler görür.
create policy trivia_questions_select on public.trivia_questions
  for select to authenticated
  using (
    (school_id is null and (select private.is_superadmin()))
    or (school_id is not null and private.has_permission(school_id, 'trivia_yonet'))
  );

-- Okuldaki düellolar okulun öğrencilerine görünür (açık meydan okumalar, sonuçlar).
create policy trivia_duels_select on public.trivia_duels
  for select to authenticated
  using (school_id = (select private.current_school_id()) or (select private.is_superadmin()));

-- Kişi kendi oyununu görür; düello bitince iki oyuncu birbirininkini de görür.
create policy trivia_duel_plays_select on public.trivia_duel_plays
  for select to authenticated
  using (
    player_id = (select auth.uid())
    or exists (
      select 1 from public.trivia_duels d join public.bets b on b.id = d.bet_id
      where d.bet_id = trivia_duel_plays.bet_id
        and b.status in ('settled', 'cancelled')
        and (select auth.uid()) in (d.challenger_id, d.opponent_id)
    )
  );

-- ---------------------------------------------------------------------------
-- İç yardımcılar
-- ---------------------------------------------------------------------------

-- Bahsi kilitlemiş çağıran içindir: SP'yi düşer, yatırımı yazar, havuzu artırır.
create function private.stake_wager(p_bet_id uuid, p_option_id uuid, p_user_id uuid, p_amount bigint) returns uuid
language plpgsql set search_path = '' as $$
declare
  v_wager_id uuid := gen_random_uuid();
  v_currency public.currency;
begin
  select b.currency into v_currency from public.bets b where b.id = p_bet_id;
  perform private.post_ledger(p_user_id, v_currency, -p_amount, 'bet_stake', 'wager', v_wager_id, p_user_id);
  insert into public.wagers (id, bet_id, option_id, user_id, amount, currency)
  values (v_wager_id, p_bet_id, p_option_id, p_user_id, p_amount, v_currency);
  update public.bet_options set pool_amount = pool_amount + p_amount where id = p_option_id;
  update public.bets set pool_total = pool_total + p_amount where id = p_bet_id;
  return v_wager_id;
end;
$$;

-- Düelloyu sonuçlandırır. p_force: süre doldu, oynamayan 0 puan sayılır / kabul edilmediyse iptal.
-- Sonuçlandırdıysa true.
create function private.finalize_trivia_duel(p_bet_id uuid, p_force boolean default false) returns boolean
language plpgsql set search_path = '' as $$
declare
  v_bet public.bets;
  v_duel public.trivia_duels;
  v_limit_ms integer;
  v_c record;
  v_o record;
  v_winner_position smallint;
begin
  select * into v_bet from public.bets b where b.id = p_bet_id for update;
  select * into v_duel from public.trivia_duels d where d.bet_id = p_bet_id;
  if not found or v_bet.status in ('settled', 'cancelled') then
    return false;
  end if;

  if v_duel.opponent_id is null then
    if p_force then
      perform private.cancel_bet(p_bet_id, 'Rakip çıkmadı, yatırım iade edildi', null);
      return true;
    end if;
    return false;
  end if;

  -- Oynamayan ya da göndermeyen: 0 puan ve en kötü süre (geç gönderen bile ondan önde sayılır).
  v_limit_ms := 2147483647;
  select coalesce(p.score, 0) as score, coalesce(p.elapsed_ms, v_limit_ms) as elapsed, p.submitted_at is not null as done
  into v_c from (select 1) x left join public.trivia_duel_plays p on p.bet_id = p_bet_id and p.player_id = v_duel.challenger_id;
  select coalesce(p.score, 0) as score, coalesce(p.elapsed_ms, v_limit_ms) as elapsed, p.submitted_at is not null as done
  into v_o from (select 1) x left join public.trivia_duel_plays p on p.bet_id = p_bet_id and p.player_id = v_duel.opponent_id;

  if not p_force and not (v_c.done and v_o.done) then
    return false;
  end if;

  v_winner_position := case
    when v_c.score > v_o.score then 1
    when v_o.score > v_c.score then 2
    when v_c.elapsed < v_o.elapsed then 1
    when v_o.elapsed < v_c.elapsed then 2
  end;

  if v_winner_position is null then
    perform private.cancel_bet(p_bet_id, 'Berabere, yatırımlar iade edildi', null);
  else
    perform private.settle_bet(
      p_bet_id,
      (select o.id from public.bet_options o where o.bet_id = p_bet_id and o.position = v_winner_position),
      null
    );
  end if;
  return true;
end;
$$;

-- Zamanlanmış iş: kabul süresi dolan açık meydan okumaları iade eder, oynama süresi dolanları sonuçlandırır.
create function private.process_trivia_duels() returns integer
language plpgsql set search_path = '' as $$
declare
  v_duel record;
  v_count integer := 0;
begin
  for v_duel in
    select d.bet_id from public.trivia_duels d join public.bets b on b.id = d.bet_id
    where b.status in ('open', 'locked')
      and ((d.opponent_id is null and d.accept_deadline <= now()) or d.play_deadline <= now())
    order by d.bet_id
  loop
    begin
      if private.finalize_trivia_duel(v_duel.bet_id, true) then
        v_count := v_count + 1;
      end if;
    exception when others then
      raise warning 'Trivia düellosu % sonuçlandırılamadı: %', v_duel.bet_id, sqlerrm;
    end;
  end loop;
  return v_count;
end;
$$;

revoke execute on function
  private.stake_wager(uuid, uuid, uuid, bigint),
  private.finalize_trivia_duel(uuid, boolean),
  private.process_trivia_duels()
from public;

-- ---------------------------------------------------------------------------
-- Genel yatırım mini oyunlara kapalı
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
  if v_bet.type = 'sp_minigame' then
    raise exception 'Bu oyuna yalnızca oyun ekranından katılınır' using errcode = '42501';
  end if;
  if v_bet.status <> 'open' or now() < v_bet.opens_at or now() >= v_bet.locks_at then
    raise exception 'Bahis yatırıma kapalı' using errcode = 'KB003';
  end if;
  if v_uid = v_bet.referee_id
     or (v_bet.type = 'ssp_official'
         and (v_uid = v_bet.creator_id or private.has_permission(v_bet.cluster_id, 'resmi_bahis_kapat'))) then
    raise exception 'Sonucu belirleyen kişi bu bahse yatırım yapamaz' using errcode = '42501';
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
-- Düello (öğrenci)
-- ---------------------------------------------------------------------------

-- Meydan okur ve kendi payını yatırır. p_invited_id verilirse yalnızca o kişi kabul edebilir.
create function public.create_trivia_duel(p_stake bigint, p_invited_id uuid default null) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_profile public.profiles;
  v_cfg public.economy_settings;
  v_questions uuid[];
  v_bet_id uuid;
begin
  if v_uid is null or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  select * into v_profile from public.profiles p where p.id = v_uid;
  if not found then
    raise exception 'Önce profil oluşturulmalı' using errcode = 'P0002';
  end if;
  if private.has_permission(v_profile.school_id, 'trivia_yonet') then
    raise exception 'Soruları yönetebilenler düello oynayamaz' using errcode = '42501';
  end if;
  select * into v_cfg from public.economy_settings s where s.id;
  if p_stake is null or p_stake < 1 or p_stake > v_cfg.duel_max_stake_sp then
    raise exception 'Düello tutarı 1 ile % SP arasında olmalı', v_cfg.duel_max_stake_sp using errcode = '23514';
  end if;
  if p_invited_id is not null and (
       p_invited_id = v_uid
       or not exists (select 1 from public.profiles p where p.id = p_invited_id and p.school_id = v_profile.school_id)
       or not private.is_verified(p_invited_id)) then
    raise exception 'Davet edilen kişi okulundan, okul maili doğrulanmış biri olmalı' using errcode = '23514';
  end if;

  select array_agg(q.id) into v_questions from (
    select tq.id from public.trivia_questions tq
    where tq.active and (tq.school_id is null or tq.school_id = v_profile.school_id)
    order by random()
    limit v_cfg.trivia_question_count
  ) q;
  if coalesce(cardinality(v_questions), 0) < v_cfg.trivia_question_count then
    raise exception 'Düello için yeterli soru yok' using errcode = 'P0002';
  end if;

  v_bet_id := private.create_bet(
    v_uid, v_profile.school_id, 'sp_minigame', 'school', 'Trivia düellosu: ' || v_profile.first_name, null,
    array['Meydan okuyan', 'Rakip'], now() + make_interval(hours => v_cfg.duel_accept_hours), null, p_stake, p_stake
  );
  perform 1 from public.bets b where b.id = v_bet_id for update;
  perform private.stake_wager(
    v_bet_id, (select o.id from public.bet_options o where o.bet_id = v_bet_id and o.position = 1), v_uid, p_stake
  );

  insert into public.trivia_duels (bet_id, school_id, challenger_id, invited_id, stake, question_ids, accept_deadline)
  values (v_bet_id, v_profile.school_id, v_uid, p_invited_id, p_stake, v_questions,
          now() + make_interval(hours => v_cfg.duel_accept_hours));
  return v_bet_id;
end;
$$;

-- Meydan okumayı kabul eder ve aynı tutarı yatırır.
create function public.accept_trivia_duel(p_bet_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_bet public.bets;
  v_duel public.trivia_duels;
  v_cfg public.economy_settings;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  select * into v_bet from public.bets b where b.id = p_bet_id for update;
  select * into v_duel from public.trivia_duels d where d.bet_id = p_bet_id;
  if not found or v_duel.school_id is distinct from private.current_school_id() then
    raise exception 'Düello bulunamadı' using errcode = 'P0002';
  end if;
  if v_duel.challenger_id = v_uid then
    raise exception 'Kendi düellona rakip olamazsın' using errcode = '42501';
  end if;
  if v_duel.opponent_id is not null or v_bet.status <> 'open' or v_duel.accept_deadline <= now() then
    raise exception 'Bu düello artık katılıma açık değil' using errcode = 'KB018';
  end if;
  if v_duel.invited_id is not null and v_duel.invited_id <> v_uid then
    raise exception 'Bu meydan okuma başka birine' using errcode = '42501';
  end if;
  if not private.is_verified(v_uid) then
    raise exception 'Düello için okul mailini doğrulamalısın' using errcode = 'KB002';
  end if;
  if private.has_permission(v_duel.school_id, 'trivia_yonet') then
    raise exception 'Soruları yönetebilenler düello oynayamaz' using errcode = '42501';
  end if;

  perform private.stake_wager(
    p_bet_id, (select o.id from public.bet_options o where o.bet_id = p_bet_id and o.position = 2), v_uid, v_duel.stake
  );
  select * into v_cfg from public.economy_settings s where s.id;
  update public.trivia_duels
  set opponent_id = v_uid, play_deadline = now() + make_interval(hours => v_cfg.duel_play_hours)
  where bet_id = p_bet_id;
  update public.bets set status = 'locked' where id = p_bet_id;
end;
$$;

-- Oyunu başlatır (ilk çağrıda süre başlar) ve soruları cevapsız verir. Tekrar çağrılırsa aynı
-- sorular ve kalan süre döner.
create function public.start_trivia_duel(p_bet_id uuid)
returns table (question_no integer, question text, options text[], seconds_left integer)
language plpgsql security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
  v_bet public.bets;
  v_duel public.trivia_duels;
  v_play public.trivia_duel_plays;
  v_limit_s integer;
begin
  select * into v_duel from public.trivia_duels d where d.bet_id = p_bet_id;
  if not found or v_uid is null or v_uid not in (v_duel.challenger_id, coalesce(v_duel.opponent_id, v_duel.challenger_id)) then
    raise exception 'Düello bulunamadı' using errcode = 'P0002';
  end if;
  select * into v_bet from public.bets b where b.id = p_bet_id;
  select * into v_play from public.trivia_duel_plays p where p.bet_id = p_bet_id and p.player_id = v_uid;
  if v_bet.status in ('settled', 'cancelled') or v_play.submitted_at is not null then
    raise exception 'Bu düelloda artık oynanamaz' using errcode = 'KB018';
  end if;
  if v_play.player_id is null then
    if now() >= coalesce(v_duel.play_deadline, v_duel.accept_deadline) then
      raise exception 'Bu düelloda artık oynanamaz' using errcode = 'KB018';
    end if;
    insert into public.trivia_duel_plays (bet_id, player_id) values (p_bet_id, v_uid) returning * into v_play;
  end if;

  select s.trivia_question_count * s.trivia_seconds_per_question into v_limit_s from public.economy_settings s where s.id;
  return query
    select u.ord::integer, q.question, q.options,
           greatest(0, v_limit_s - floor(extract(epoch from now() - v_play.started_at))::integer)
    from unnest(v_duel.question_ids) with ordinality as u(qid, ord)
    join public.trivia_questions q on q.id = u.qid
    order by u.ord;
end;
$$;

-- Cevapları gönderir (her soru için seçilen şıkkın sırası, 0'dan; boş için null). Puanı sunucu
-- hesaplar; süre (+10 sn pay) aşıldıysa 0 puan. İki oyuncu da gönderince düello sonuçlanır.
create function public.submit_trivia_answers(p_bet_id uuid, p_answers smallint[])
returns table (score integer, late boolean)
language plpgsql security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
  v_duel public.trivia_duels;
  v_play public.trivia_duel_plays;
  v_limit_ms integer;
  v_elapsed_ms integer;
  v_late boolean;
  v_score integer;
begin
  perform 1 from public.bets b where b.id = p_bet_id for update;
  select * into v_duel from public.trivia_duels d where d.bet_id = p_bet_id;
  select * into v_play from public.trivia_duel_plays p where p.bet_id = p_bet_id and p.player_id = v_uid for update;
  if v_duel.bet_id is null or v_play.player_id is null or v_play.submitted_at is not null then
    raise exception 'Bu düelloda cevap gönderilemez' using errcode = 'KB018';
  end if;

  select s.trivia_question_count * s.trivia_seconds_per_question * 1000 + 10000 into v_limit_ms
  from public.economy_settings s where s.id;
  v_elapsed_ms := floor(extract(epoch from now() - v_play.started_at) * 1000)::integer;
  v_late := v_elapsed_ms > v_limit_ms;

  if not v_late and coalesce(cardinality(p_answers), 0) <> cardinality(v_duel.question_ids) then
    raise exception 'Her soru için bir cevap gönderilmeli' using errcode = '23514';
  end if;

  select case when v_late then 0 else count(*) filter (where p_answers[u.ord::integer] = q.correct_index) end
  into v_score
  from unnest(v_duel.question_ids) with ordinality as u(qid, ord)
  join public.trivia_questions q on q.id = u.qid;

  update public.trivia_duel_plays
  set submitted_at = now(), answers = case when v_late then null else p_answers end,
      score = v_score, elapsed_ms = least(v_elapsed_ms, v_limit_ms)
  where bet_id = p_bet_id and player_id = v_uid;

  perform private.finalize_trivia_duel(p_bet_id);
  return query select v_score, v_late;
end;
$$;

-- ---------------------------------------------------------------------------
-- Soru yönetimi (admin paneli)
-- ---------------------------------------------------------------------------

-- p_id null ise ekler, değilse günceller. Okula özel soru trivia_yonet ister; genel soru (okul null) süperadmin.
create function public.save_trivia_question(
  p_id uuid,
  p_school_id uuid,
  p_question text,
  p_options text[],
  p_correct_index smallint,
  p_category text default null,
  p_active boolean default true
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_options text[];
  v_existing public.trivia_questions;
  v_id uuid;
begin
  if not (case when p_school_id is null then private.is_superadmin()
               else private.has_permission(p_school_id, 'trivia_yonet') end) then
    raise exception 'Bu işlem için yetkin yok' using errcode = '42501';
  end if;
  select array_agg(btrim(o) order by ord) into v_options from unnest(p_options) with ordinality as t(o, ord);

  if p_id is null then
    insert into public.trivia_questions (school_id, question, options, correct_index, category, active, created_by)
    values (p_school_id, btrim(p_question), v_options, p_correct_index, nullif(btrim(p_category), ''), p_active, v_uid)
    returning id into v_id;
    return v_id;
  end if;

  select * into v_existing from public.trivia_questions q where q.id = p_id for update;
  if not found or not (case when v_existing.school_id is null then private.is_superadmin()
                            else private.has_permission(v_existing.school_id, 'trivia_yonet') end) then
    raise exception 'Soru bulunamadı' using errcode = 'P0002';
  end if;
  update public.trivia_questions
  set school_id = p_school_id, question = btrim(p_question), options = v_options, correct_index = p_correct_index,
      category = nullif(btrim(p_category), ''), active = p_active
  where id = p_id;
  return p_id;
end;
$$;

revoke execute on function
  public.create_trivia_duel(bigint, uuid),
  public.accept_trivia_duel(uuid),
  public.start_trivia_duel(uuid),
  public.submit_trivia_answers(uuid, smallint[]),
  public.save_trivia_question(uuid, uuid, text, text[], smallint, text, boolean)
from public, anon;

grant execute on function
  public.create_trivia_duel(bigint, uuid),
  public.accept_trivia_duel(uuid),
  public.start_trivia_duel(uuid),
  public.submit_trivia_answers(uuid, smallint[]),
  public.save_trivia_question(uuid, uuid, text, text[], smallint, text, boolean)
to authenticated;

-- ---------------------------------------------------------------------------
-- Zamanlanmış iş: 5 dakikada bir
-- ---------------------------------------------------------------------------

select cron.schedule('kampusbet_trivia_duellolari', '*/5 * * * *', 'select private.process_trivia_duels()');
