-- Adım 6: resmi SSP bahisleri. Sabit oran ve yetki kontrollü bahis yönetimi.
--
-- * Sabit oran (bets.odds_mode = 'fixed'): admin her seçeneğe oran verir (1,01–20,00). Yatırım
--   anındaki oran wagers.odds'a yazılır. Kazanan floor(yatırım × oran) alır, kaybeden 0. Ödeme
--   havuzdan değil yeni SSP'den gelir (sistem kasa gibidir); kaybedilen SSP yok olur.
--   Resmi bahis 'fixed' ya da 'pool' olabilir (kullanıcı kararı: şimdilik sabit oran, sonra
--   yeniden bakılacak); sosyal havuz ve mini oyun her zaman 'pool'.
-- * Yetki: açmak resmi_bahis_ac, kilitlemek / sonuçlandırmak / iptal resmi_bahis_kapat ister
--   (okul kümesinde; süperadmin her zaman). Her işlem admin_audit_log'a yazılır.
-- * Çıkar çatışması: resmi bahsi açan ve onu sonuçlandırabilecek olan (resmi_bahis_kapat izni,
--   süperadmin) o bahse yatırım yapamaz.

create type public.odds_mode as enum ('pool', 'fixed');

alter table public.bets add column odds_mode public.odds_mode not null default 'pool';
alter table public.bets add constraint bets_fixed_only_official check (odds_mode = 'pool' or type = 'ssp_official');

alter table public.bet_options add column odds numeric(5, 2) check (odds is null or odds between 1.01 and 20.00);
alter table public.wagers add column odds numeric(5, 2);

-- ---------------------------------------------------------------------------
-- Bahis açma: oran desteği (p_odds verilirse sabit oran)
-- ---------------------------------------------------------------------------

drop function private.create_bet(uuid, uuid, public.bet_type, public.bet_scope, text, text, text[], timestamptz, uuid, bigint, bigint);

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
  p_max_stake bigint default null,
  p_odds numeric[] default null
) returns uuid
language plpgsql set search_path = '' as $$
declare
  v_bet_id uuid;
  v_position smallint;
begin
  if not private.is_verified(p_creator_id) then
    raise exception 'Bahis açmak için okul mailini doğrulamalısın' using errcode = 'KB002';
  end if;
  if p_options is null or cardinality(p_options) not between 2 and 10 then
    raise exception 'Bahsin 2 ile 10 arasında seçeneği olmalı' using errcode = '23514';
  end if;
  if p_odds is not null and cardinality(p_odds) <> cardinality(p_options) then
    raise exception 'Her seçeneğin bir oranı olmalı' using errcode = '23514';
  end if;
  if p_locks_at is null or p_locks_at <= now() then
    raise exception 'Kapanış zamanı ileride olmalı' using errcode = '23514';
  end if;

  insert into public.bets (
    creator_id, cluster_id, type, currency, scope, title, description,
    settlement_mode, referee_id, min_stake, max_stake, locks_at, odds_mode
  ) values (
    p_creator_id, p_cluster_id, p_type,
    case p_type when 'ssp_official' then 'SSP' else 'SP' end::public.currency,
    p_scope, btrim(p_title), nullif(btrim(p_description), ''),
    case p_type when 'ssp_official' then 'admin' when 'sp_minigame' then 'auto' else 'referee' end::public.settlement_mode,
    p_referee_id, p_min_stake, p_max_stake, p_locks_at,
    case when p_odds is null then 'pool' else 'fixed' end::public.odds_mode
  )
  returning id into v_bet_id;

  for v_position in 1 .. cardinality(p_options) loop
    insert into public.bet_options (bet_id, label, position, odds)
    values (v_bet_id, btrim(p_options[v_position]), v_position, p_odds[v_position]);
  end loop;

  return v_bet_id;
end;
$$;

revoke execute on function
  private.create_bet(uuid, uuid, public.bet_type, public.bet_scope, text, text, text[], timestamptz, uuid, bigint, bigint, numeric[])
from public;

-- ---------------------------------------------------------------------------
-- Sonuçlandırma: sabit oranda floor(yatırım × oran), havuzda pari-mutuel
-- ---------------------------------------------------------------------------

create or replace function private.settle_bet(p_bet_id uuid, p_winning_option_id uuid, p_actor_id uuid)
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
  update public.wagers set payout = 0 where bet_id = p_bet_id and option_id <> p_winning_option_id;

  if v_bet.odds_mode = 'fixed' then
    -- Sabit oran: her kazanana yatırdığı anki oranla; kazanan yoksa ödeme de yok.
    for v_w in
      select w.id, w.user_id, floor(w.amount * w.odds)::bigint as payout
      from public.wagers w
      where w.bet_id = p_bet_id and w.option_id = p_winning_option_id
      order by w.user_id
    loop
      perform private.post_ledger(v_w.user_id, v_bet.currency, v_w.payout, 'bet_payout', 'wager', v_w.id, p_actor_id);
      update public.wagers set payout = v_w.payout where id = v_w.id;
    end loop;
  elsif v_win_pool = 0 then
    -- Havuz: kazanan seçeneğe kimse yatırmadı, herkese iade.
    for v_w in
      select w.id, w.user_id, w.amount from public.wagers w where w.bet_id = p_bet_id order by w.user_id
    loop
      perform private.post_ledger(v_w.user_id, v_bet.currency, v_w.amount, 'bet_refund', 'wager', v_w.id, p_actor_id);
      update public.wagers set payout = v_w.amount where id = v_w.id;
    end loop;
  else
    -- Havuz: pari-mutuel, küsurat kesirli payı en büyük olandan 1'er.
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

-- ---------------------------------------------------------------------------
-- Yatırım: oranı kaydet, resmi bahiste sonuçlandırabilecek olanı engelle
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
-- Resmi bahis yönetimi (admin paneli bunları çağırır)
-- ---------------------------------------------------------------------------

-- Resmi bahsi bulur ve oturumdaki kişinin o okulda izni olduğunu doğrular.
create function private.official_bet_for(p_bet_id uuid, p_key public.permission_key) returns public.bets
language plpgsql stable set search_path = '' as $$
declare
  v_bet public.bets;
begin
  select * into v_bet from public.bets b where b.id = p_bet_id;
  if not found or v_bet.type <> 'ssp_official' then
    raise exception 'Resmi bahis bulunamadı' using errcode = 'P0002';
  end if;
  if not private.has_permission(v_bet.cluster_id, p_key) then
    raise exception 'Bu işlem için yetkin yok' using errcode = '42501';
  end if;
  return v_bet;
end;
$$;

revoke execute on function private.official_bet_for(uuid, public.permission_key) from public;

create function public.create_official_bet(
  p_school_id uuid,
  p_title text,
  p_description text,
  p_options text[],
  p_odds numeric[],
  p_locks_at timestamptz,
  p_max_stake bigint default null
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_bet_id uuid;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  if not exists (select 1 from public.clusters c where c.id = p_school_id and c.type = 'school') then
    raise exception 'Okul bulunamadı' using errcode = 'P0002';
  end if;
  if not private.has_permission(p_school_id, 'resmi_bahis_ac') then
    raise exception 'Bu işlem için yetkin yok' using errcode = '42501';
  end if;
  if p_odds is null then
    raise exception 'Resmi bahiste her seçeneğin oranı olmalı' using errcode = '23514';
  end if;

  v_bet_id := private.create_bet(v_uid, p_school_id, 'ssp_official', 'school', p_title, p_description,
                                 p_options, p_locks_at, null, 1, p_max_stake, p_odds);

  insert into public.admin_audit_log (actor_id, action, cluster_id, details)
  values (v_uid, 'official_bet_create', p_school_id, jsonb_build_object('bet_id', v_bet_id, 'title', btrim(p_title)));
  return v_bet_id;
end;
$$;

create function public.lock_official_bet(p_bet_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_bet public.bets := private.official_bet_for(p_bet_id, 'resmi_bahis_kapat');
begin
  perform private.lock_bet(p_bet_id);
  insert into public.admin_audit_log (actor_id, action, cluster_id, details)
  values ((select auth.uid()), 'official_bet_lock', v_bet.cluster_id, jsonb_build_object('bet_id', p_bet_id));
end;
$$;

create function public.settle_official_bet(p_bet_id uuid, p_winning_option_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_bet public.bets := private.official_bet_for(p_bet_id, 'resmi_bahis_kapat');
begin
  perform private.settle_bet(p_bet_id, p_winning_option_id, (select auth.uid()));
  insert into public.admin_audit_log (actor_id, action, cluster_id, details)
  values ((select auth.uid()), 'official_bet_settle', v_bet.cluster_id,
          jsonb_build_object('bet_id', p_bet_id, 'winning_option_id', p_winning_option_id));
end;
$$;

create function public.cancel_official_bet(p_bet_id uuid, p_reason text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_bet public.bets := private.official_bet_for(p_bet_id, 'resmi_bahis_kapat');
begin
  perform private.cancel_bet(p_bet_id, p_reason, (select auth.uid()));
  insert into public.admin_audit_log (actor_id, action, cluster_id, details)
  values ((select auth.uid()), 'official_bet_cancel', v_bet.cluster_id,
          jsonb_build_object('bet_id', p_bet_id, 'reason', btrim(p_reason)));
end;
$$;

revoke execute on function
  public.create_official_bet(uuid, text, text, text[], numeric[], timestamptz, bigint),
  public.lock_official_bet(uuid),
  public.settle_official_bet(uuid, uuid),
  public.cancel_official_bet(uuid, text)
from public, anon;

grant execute on function
  public.create_official_bet(uuid, text, text, text[], numeric[], timestamptz, bigint),
  public.lock_official_bet(uuid),
  public.settle_official_bet(uuid, uuid),
  public.cancel_official_bet(uuid, text)
to authenticated;
