-- Adım 3: bahis çekirdeği. Bahis, seçenek, yatırım; pari-mutuel sonuçlandırma; iptal + iade.
--
-- Bu adım türlerden bağımsız çekirdektir. Bahis açma / sonuçlandırma / iptal iç fonksiyonlardır
-- (private); türe özel ve yetki kontrollü RPC'ler sonraki adımlarda bunları çağırır
-- (resmi SSP: Adım 6, sosyal havuz: Adım 7, mini oyun: Adım 8). İstemciye açık tek yazma
-- işlemi place_wager'dır.
--
-- Kurallar:
-- * Bahis açmak da yatırım yapmak da doğrulanmış okul maili ister (KB002).
-- * Kişi bir bahse bir kez yatırım yapar. Sonucu belirleyen kişi (hakem; resmi bahiste açan) yatırım yapamaz.
-- * Pari-mutuel: kazananlar tüm havuzu yatırımları oranında paylaşır, kesinti yok. Tam sayı
--   bölmeden kalan SP'ler kesirli payı en büyük olandan başlayarak 1'er dağıtılır.
--   Kazanan seçeneğe kimse yatırmadıysa herkese iade edilir.
-- * Kilit sırası: önce bahis satırı, sonra bakiyeler user_id sırasıyla.

-- ---------------------------------------------------------------------------
-- Türler
-- ---------------------------------------------------------------------------

create type public.bet_type as enum ('ssp_official', 'sp_minigame', 'sp_social');
create type public.bet_scope as enum ('private', 'school', 'cross_school', 'global');
create type public.bet_status as enum ('open', 'locked', 'settling', 'settled', 'cancelled');
create type public.settlement_mode as enum ('auto', 'admin', 'referee');

-- ---------------------------------------------------------------------------
-- Tablolar
-- ---------------------------------------------------------------------------

create table public.bets (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references public.profiles (id) on delete restrict,
  -- Bahsin görünür olduğu küme: okul kapsamında okul, özel kapsamda grup/kulüp/bölüm.
  cluster_id uuid not null references public.clusters (id) on delete restrict,
  type public.bet_type not null,
  currency public.currency not null,
  scope public.bet_scope not null,
  title text not null check (char_length(title) between 3 and 140 and title = btrim(title) and title !~ '[[:cntrl:]]'),
  description text check (description is null or (char_length(description) between 1 and 2000 and description = btrim(description))),
  status public.bet_status not null default 'open',
  settlement_mode public.settlement_mode not null,
  referee_id uuid references public.profiles (id) on delete restrict,
  pool_total bigint not null default 0 check (pool_total >= 0),
  min_stake bigint not null default 1 check (min_stake > 0),
  max_stake bigint check (max_stake is null or max_stake >= min_stake),
  opens_at timestamptz not null default now(),
  locks_at timestamptz not null,
  settled_at timestamptz,
  settled_by uuid references public.profiles (id) on delete restrict,
  cancelled_at timestamptz,
  cancelled_by uuid references public.profiles (id) on delete restrict,
  cancel_reason text check (cancel_reason is null or (char_length(cancel_reason) between 3 and 500 and cancel_reason = btrim(cancel_reason))),
  created_at timestamptz not null default now(),
  constraint bets_lock_after_open check (locks_at > opens_at),
  -- Resmi bahis SSP ile, diğerleri SP ile oynanır.
  constraint bets_currency_by_type check ((type = 'ssp_official') = (currency = 'SSP')),
  constraint bets_settlement_by_type check (
    case type
      when 'ssp_official' then settlement_mode = 'admin'
      when 'sp_minigame' then settlement_mode = 'auto'
      else settlement_mode = 'referee'
    end
  ),
  constraint bets_referee_only_social check ((type = 'sp_social') = (referee_id is not null)),
  -- Okullar arası ve genel kapsam v2'de.
  constraint bets_scope_v1 check (scope in ('private', 'school')),
  constraint bets_settled_fields check ((status = 'settled') = (settled_at is not null)),
  constraint bets_cancelled_fields check ((status = 'cancelled') = (cancelled_at is not null and cancel_reason is not null))
);
create index bets_cluster_status_idx on public.bets (cluster_id, status);
create index bets_open_locks_at_idx on public.bets (locks_at) where status = 'open';
create index bets_creator_idx on public.bets (creator_id);
create index bets_referee_idx on public.bets (referee_id) where referee_id is not null;

create table public.bet_options (
  id uuid primary key default gen_random_uuid(),
  bet_id uuid not null references public.bets (id) on delete restrict,
  label text not null check (char_length(label) between 1 and 100 and label = btrim(label) and label !~ '[[:cntrl:]]'),
  position smallint not null check (position > 0),
  pool_amount bigint not null default 0 check (pool_amount >= 0),
  -- Sonuçlanınca belirlenir.
  is_winner boolean,
  unique (bet_id, position),
  unique (bet_id, label),
  unique (id, bet_id)
);

create table public.wagers (
  id uuid primary key default gen_random_uuid(),
  bet_id uuid not null references public.bets (id) on delete restrict,
  option_id uuid not null,
  user_id uuid not null references public.profiles (id) on delete restrict,
  amount bigint not null check (amount > 0),
  currency public.currency not null,
  -- Sonuçlanınca ya da iptalde yazılır (kaybeden: 0, iade: yatırılan tutar).
  payout bigint check (payout is null or payout >= 0),
  created_at timestamptz not null default now(),
  -- Seçenek aynı bahsin seçeneği olmalı.
  foreign key (option_id, bet_id) references public.bet_options (id, bet_id) on delete restrict,
  -- Kişi bir bahse bir kez yatırım yapar.
  unique (bet_id, user_id)
);
create index wagers_user_idx on public.wagers (user_id, created_at desc);
create index wagers_option_idx on public.wagers (option_id);

-- Okul kapsamı okul kümesinde, özel kapsam okul dışı bir kümede açılır.
create function private.bets_check_scope() returns trigger
language plpgsql set search_path = '' as $$
declare
  v_cluster_type public.cluster_type;
begin
  select c.type into v_cluster_type from public.clusters c where c.id = new.cluster_id;
  if (new.scope = 'school') <> (v_cluster_type = 'school') then
    raise exception 'Okul kapsamlı bahis okul kümesinde, özel bahis okul dışı bir kümede açılır' using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger bets_check_scope
  before insert on public.bets
  for each row execute function private.bets_check_scope();

-- Ledger'daki bahis kayıtları yatırıma (wager) bağlanır; her yatırımın tek yatırma ve
-- tek ödeme/iade kaydı olabilir. Çift ödemeye karşı son savunma hattı.
alter table public.ledger_entries
  add constraint ledger_bet_refs_wager check (
    reason not in ('bet_stake', 'bet_payout', 'bet_refund') or ref_type = 'wager'
  );
create unique index ledger_entries_one_stake_per_wager
  on public.ledger_entries (ref_id) where reason = 'bet_stake';
create unique index ledger_entries_one_settlement_per_wager
  on public.ledger_entries (ref_id) where reason in ('bet_payout', 'bet_refund');

-- ---------------------------------------------------------------------------
-- İç fonksiyonlar
-- ---------------------------------------------------------------------------

create function private.is_verified(p_user_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profile_private pp
    where pp.user_id = p_user_id and pp.student_email_verified_at is not null
  );
$$;

-- Bahis ve seçeneklerini açar. Yetki ve tür kuralları çağıran RPC'dedir.
create function private.create_bet(
  p_creator_id uuid,
  p_cluster_id uuid,
  p_type public.bet_type,
  p_scope public.bet_scope,
  p_title text,
  p_description text,
  p_options text[],
  p_locks_at timestamptz,
  p_referee_id uuid default null,
  p_min_stake bigint default 1,
  p_max_stake bigint default null
) returns uuid
language plpgsql set search_path = '' as $$
declare
  v_bet_id uuid;
  v_label text;
  v_position smallint := 0;
begin
  if not private.is_verified(p_creator_id) then
    raise exception 'Bahis açmak için okul mailini doğrulamalısın' using errcode = 'KB002';
  end if;
  if p_options is null or cardinality(p_options) not between 2 and 10 then
    raise exception 'Bahsin 2 ile 10 arasında seçeneği olmalı' using errcode = '23514';
  end if;
  if p_locks_at is null or p_locks_at <= now() then
    raise exception 'Kapanış zamanı ileride olmalı' using errcode = '23514';
  end if;

  insert into public.bets (
    creator_id, cluster_id, type, currency, scope, title, description,
    settlement_mode, referee_id, min_stake, max_stake, locks_at
  ) values (
    p_creator_id, p_cluster_id, p_type,
    case p_type when 'ssp_official' then 'SSP' else 'SP' end::public.currency,
    p_scope, btrim(p_title), nullif(btrim(p_description), ''),
    case p_type when 'ssp_official' then 'admin' when 'sp_minigame' then 'auto' else 'referee' end::public.settlement_mode,
    p_referee_id, p_min_stake, p_max_stake, p_locks_at
  )
  returning id into v_bet_id;

  foreach v_label in array p_options loop
    v_position := v_position + 1;
    insert into public.bet_options (bet_id, label, position) values (v_bet_id, btrim(v_label), v_position);
  end loop;

  return v_bet_id;
end;
$$;

-- Yatırımları erken kapatır (ör. maç planlanandan önce başladı).
create function private.lock_bet(p_bet_id uuid) returns void
language plpgsql set search_path = '' as $$
begin
  update public.bets set status = 'locked' where id = p_bet_id and status = 'open';
  if not found then
    raise exception 'Bahis açık değil' using errcode = 'KB003';
  end if;
end;
$$;

-- Kazanan seçeneği belirler ve havuzu dağıtır.
create function private.settle_bet(p_bet_id uuid, p_winning_option_id uuid, p_actor_id uuid)
returns void
language plpgsql set search_path = '' as $$
declare
  v_bet public.bets;
  v_win_pool bigint;
  v_w record;
begin
  select * into v_bet from public.bets b where b.id = p_bet_id for update;
  if not found then
    raise exception 'Bahis bulunamadı' using errcode = 'P0002';
  end if;
  if v_bet.status in ('settled', 'cancelled') then
    raise exception 'Bahis zaten sonuçlandı ya da iptal edildi' using errcode = 'KB006';
  end if;
  if v_bet.status = 'open' and now() < v_bet.locks_at then
    raise exception 'Bahis yatırıma açıkken sonuçlandırılamaz' using errcode = 'KB005';
  end if;

  select o.pool_amount into v_win_pool
  from public.bet_options o where o.id = p_winning_option_id and o.bet_id = p_bet_id;
  if not found then
    raise exception 'Seçenek bu bahse ait değil' using errcode = 'P0002';
  end if;

  update public.bet_options o set is_winner = (o.id = p_winning_option_id) where o.bet_id = p_bet_id;

  if v_win_pool = 0 then
    -- Kazanan seçeneğe kimse yatırmadı: herkese iade.
    for v_w in
      select w.id, w.user_id, w.amount from public.wagers w where w.bet_id = p_bet_id order by w.user_id
    loop
      perform private.post_ledger(v_w.user_id, v_bet.currency, v_w.amount, 'bet_refund', 'wager', v_w.id, p_actor_id);
      update public.wagers set payout = v_w.amount where id = v_w.id;
    end loop;
  else
    update public.wagers set payout = 0 where bet_id = p_bet_id and option_id <> p_winning_option_id;

    for v_w in
      with shares as (
        select w.id, w.user_id, w.created_at,
               floor(w.amount::numeric * v_bet.pool_total / v_win_pool)::bigint as base_payout,
               (w.amount::numeric * v_bet.pool_total) % v_win_pool as remainder
        from public.wagers w
        where w.bet_id = p_bet_id and w.option_id = p_winning_option_id
      ),
      ranked as (
        select s.*, row_number() over (order by s.remainder desc, s.created_at, s.id) as rn
        from shares s
      )
      select r.id, r.user_id,
             r.base_payout
               + case when r.rn <= v_bet.pool_total - (select sum(s.base_payout) from shares s) then 1 else 0 end
               as payout
      from ranked r
      order by r.user_id
    loop
      perform private.post_ledger(v_w.user_id, v_bet.currency, v_w.payout, 'bet_payout', 'wager', v_w.id, p_actor_id);
      update public.wagers set payout = v_w.payout where id = v_w.id;
    end loop;
  end if;

  update public.bets
  set status = 'settled', settled_at = now(), settled_by = p_actor_id
  where id = p_bet_id;
end;
$$;

-- Bahsi iptal eder, tüm yatırımları iade eder.
create function private.cancel_bet(p_bet_id uuid, p_reason text, p_actor_id uuid)
returns void
language plpgsql set search_path = '' as $$
declare
  v_bet public.bets;
  v_w record;
begin
  select * into v_bet from public.bets b where b.id = p_bet_id for update;
  if not found then
    raise exception 'Bahis bulunamadı' using errcode = 'P0002';
  end if;
  if v_bet.status in ('settled', 'cancelled') then
    raise exception 'Bahis zaten sonuçlandı ya da iptal edildi' using errcode = 'KB006';
  end if;
  if p_reason is null or char_length(btrim(p_reason)) < 3 then
    raise exception 'İptal gerekçesi yazılmalı (en az 3 karakter)' using errcode = '23514';
  end if;

  for v_w in
    select w.id, w.user_id, w.amount from public.wagers w where w.bet_id = p_bet_id order by w.user_id
  loop
    perform private.post_ledger(v_w.user_id, v_bet.currency, v_w.amount, 'bet_refund', 'wager', v_w.id, p_actor_id);
    update public.wagers set payout = v_w.amount where id = v_w.id;
  end loop;

  update public.bets
  set status = 'cancelled', cancelled_at = now(), cancelled_by = p_actor_id, cancel_reason = btrim(p_reason)
  where id = p_bet_id;
end;
$$;

revoke execute on function
  private.is_verified(uuid),
  private.create_bet(uuid, uuid, public.bet_type, public.bet_scope, text, text, text[], timestamptz, uuid, bigint, bigint),
  private.lock_bet(uuid),
  private.settle_bet(uuid, uuid, uuid),
  private.cancel_bet(uuid, text, uuid)
from public;

-- ---------------------------------------------------------------------------
-- Yatırım (istemciye açık)
-- ---------------------------------------------------------------------------

create function public.place_wager(p_bet_id uuid, p_option_id uuid, p_amount bigint)
returns public.wagers
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_bet public.bets;
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
  if v_bet.status <> 'open' or now() < v_bet.opens_at or now() >= v_bet.locks_at then
    raise exception 'Bahis yatırıma kapalı' using errcode = 'KB003';
  end if;
  if v_uid = v_bet.referee_id or (v_bet.type = 'ssp_official' and v_uid = v_bet.creator_id) then
    raise exception 'Sonucu belirleyen kişi bu bahse yatırım yapamaz' using errcode = '42501';
  end if;
  if not exists (select 1 from public.bet_options o where o.id = p_option_id and o.bet_id = p_bet_id) then
    raise exception 'Seçenek bulunamadı' using errcode = 'P0002';
  end if;
  if p_amount is null or p_amount < v_bet.min_stake or (v_bet.max_stake is not null and p_amount > v_bet.max_stake) then
    raise exception 'Yatırım tutarı bu bahsin sınırları dışında' using errcode = '23514';
  end if;
  if exists (select 1 from public.wagers w where w.bet_id = p_bet_id and w.user_id = v_uid) then
    raise exception 'Bu bahse zaten yatırım yaptın' using errcode = 'KB004';
  end if;

  perform private.post_ledger(v_uid, v_bet.currency, -p_amount, 'bet_stake', 'wager', v_wager_id, v_uid);

  insert into public.wagers (id, bet_id, option_id, user_id, amount, currency)
  values (v_wager_id, p_bet_id, p_option_id, v_uid, p_amount, v_bet.currency)
  returning * into v_wager;

  update public.bet_options set pool_amount = pool_amount + p_amount where id = p_option_id;
  update public.bets set pool_total = pool_total + p_amount where id = p_bet_id;

  return v_wager;
end;
$$;

revoke execute on function public.place_wager(uuid, uuid, bigint) from public, anon;
grant execute on function public.place_wager(uuid, uuid, bigint) to authenticated;

-- ---------------------------------------------------------------------------
-- Tablo yetkileri ve RLS
-- ---------------------------------------------------------------------------

revoke all on public.bets, public.bet_options, public.wagers from anon, authenticated;
grant select on public.bets, public.bet_options, public.wagers to authenticated;

alter table public.bets enable row level security;
alter table public.bet_options enable row level security;
alter table public.wagers enable row level security;

-- Bahsi, kümesinin üyeleri görür (okul kapsamında okulun tüm öğrencileri).
create policy bets_select on public.bets
  for select to authenticated
  using (
    cluster_id in (select private.my_cluster_ids())
    or (select private.is_superadmin())
  );

-- Seçenekler bahisle birlikte görünür (alt sorgu bets RLS'ine tabidir).
create policy bet_options_select on public.bet_options
  for select to authenticated
  using (bet_id in (select b.id from public.bets b));

-- Bireysel yatırımlar gizli; havuz toplamları bet_options.pool_amount'ta görünür.
create policy wagers_select on public.wagers
  for select to authenticated
  using (user_id = (select auth.uid()) or (select private.is_superadmin()));
