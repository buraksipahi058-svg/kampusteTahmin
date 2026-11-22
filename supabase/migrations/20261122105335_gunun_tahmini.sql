-- Adım 8 (devam): mini oyun — günün tahmini (MIMARI §4.2; KARARLAR "Mini oyun: günün tahmini").
--
-- Okulun öğrencilerine açık evet / hayır sorusu; SP havuzu pari-mutuel paylaşılır. Soruyu resmi bahis
-- yetkilisi açar (resmi_bahis_ac), sonucu girer ya da iptal eder (resmi_bahis_kapat). Bu bir
-- `sp_minigame` bahsidir ama sonucu admin girer: settlement_mode = 'admin'. Mini oyunlar içinde bunu
-- düellodan (auto) ayıran budur. Sonucu girebilecek olan ve soruyu açan yatırım yapamaz (resmi
-- bahisteki kural, artık settlement_mode = 'admin' olan her bahiste).

-- ---------------------------------------------------------------------------
-- Ayarlar ve kısıt
-- ---------------------------------------------------------------------------

alter table public.economy_settings
  add column daily_max_stake_sp integer not null default 100 check (daily_max_stake_sp > 0),
  add column daily_result_deadline_days integer not null default 3 check (daily_result_deadline_days between 1 and 30);

-- Mini oyun artık admin sonuçlandırmalı da olabilir (günün tahmini).
alter table public.bets drop constraint bets_settlement_by_type;
alter table public.bets add constraint bets_settlement_by_type check (
  case type
    when 'ssp_official' then settlement_mode = 'admin'
    when 'sp_minigame' then settlement_mode in ('auto', 'admin')
    else settlement_mode = 'referee'
  end
);

-- ---------------------------------------------------------------------------
-- Genel yatırım: günün tahminine açık, düelloya kapalı
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
  if v_uid = v_bet.referee_id
     or (v_bet.settlement_mode = 'admin'
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
-- Günün tahmini yönetimi (admin paneli)
-- ---------------------------------------------------------------------------

-- Günün tahminini bulur ve oturumdaki kişinin o okulda izni olduğunu doğrular.
create function private.daily_prediction_for(p_bet_id uuid, p_key public.permission_key) returns public.bets
language plpgsql stable set search_path = '' as $$
declare
  v_bet public.bets;
begin
  select * into v_bet from public.bets b where b.id = p_bet_id;
  if not found or v_bet.type <> 'sp_minigame' or v_bet.settlement_mode <> 'admin' then
    raise exception 'Günün tahmini bulunamadı' using errcode = 'P0002';
  end if;
  if not private.has_permission(v_bet.cluster_id, p_key) then
    raise exception 'Bu işlem için yetkin yok' using errcode = '42501';
  end if;
  return v_bet;
end;
$$;

-- Evet / Hayır sorusu açar. Kapanış en geç 7 gün sonra; kişi başı üst sınır ayardan.
create function public.create_daily_prediction(
  p_school_id uuid,
  p_question text,
  p_locks_at timestamptz,
  p_description text default null
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_max bigint;
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
  if p_locks_at > now() + interval '7 days' then
    raise exception 'Günün tahmini en geç 7 gün içinde kapanmalı' using errcode = '23514';
  end if;

  select s.daily_max_stake_sp into v_max from public.economy_settings s where s.id;

  v_bet_id := private.create_bet(v_uid, p_school_id, 'sp_minigame', 'school', p_question, p_description,
                                 array['Evet', 'Hayır'], p_locks_at, null, 1, v_max, null);
  -- create_bet mini oyunu 'auto' açar; günün tahmininin sonucunu admin girer.
  update public.bets set settlement_mode = 'admin' where id = v_bet_id;

  insert into public.admin_audit_log (actor_id, action, cluster_id, details)
  values (v_uid, 'daily_prediction_create', p_school_id, jsonb_build_object('bet_id', v_bet_id, 'title', btrim(p_question)));
  return v_bet_id;
end;
$$;

create function public.settle_daily_prediction(p_bet_id uuid, p_winning_option_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_bet public.bets := private.daily_prediction_for(p_bet_id, 'resmi_bahis_kapat');
begin
  perform private.settle_bet(p_bet_id, p_winning_option_id, (select auth.uid()));
  insert into public.admin_audit_log (actor_id, action, cluster_id, details)
  values ((select auth.uid()), 'daily_prediction_settle', v_bet.cluster_id,
          jsonb_build_object('bet_id', p_bet_id, 'winning_option_id', p_winning_option_id));
end;
$$;

create function public.cancel_daily_prediction(p_bet_id uuid, p_reason text) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_bet public.bets := private.daily_prediction_for(p_bet_id, 'resmi_bahis_kapat');
begin
  perform private.cancel_bet(p_bet_id, p_reason, (select auth.uid()));
  insert into public.admin_audit_log (actor_id, action, cluster_id, details)
  values ((select auth.uid()), 'daily_prediction_cancel', v_bet.cluster_id,
          jsonb_build_object('bet_id', p_bet_id, 'reason', btrim(p_reason)));
end;
$$;

-- Kapanıştan sonra süresinde sonucu girilmeyen tahminler iptal edilir, yatırımlar iade.
create function private.process_daily_predictions() returns integer
language plpgsql set search_path = '' as $$
declare
  v_days integer;
  v_bet record;
  v_count integer := 0;
begin
  select s.daily_result_deadline_days into v_days from public.economy_settings s where s.id;

  for v_bet in
    select b.id from public.bets b
    where b.type = 'sp_minigame' and b.settlement_mode = 'admin' and b.status in ('open', 'locked')
      and b.locks_at + make_interval(days => v_days) <= now()
    order by b.id
  loop
    begin
      perform private.cancel_bet(v_bet.id, 'Sonuç süresi içinde girilmedi', null);
      v_count := v_count + 1;
    exception when others then
      raise warning 'Günün tahmini % iptal edilemedi: %', v_bet.id, sqlerrm;
    end;
  end loop;
  return v_count;
end;
$$;

revoke execute on function
  private.daily_prediction_for(uuid, public.permission_key),
  private.process_daily_predictions()
from public;

revoke execute on function
  public.create_daily_prediction(uuid, text, timestamptz, text),
  public.settle_daily_prediction(uuid, uuid),
  public.cancel_daily_prediction(uuid, text)
from public, anon;

grant execute on function
  public.create_daily_prediction(uuid, text, timestamptz, text),
  public.settle_daily_prediction(uuid, uuid),
  public.cancel_daily_prediction(uuid, text)
to authenticated;

-- ---------------------------------------------------------------------------
-- Zamanlanmış iş: saatte bir
-- ---------------------------------------------------------------------------

select cron.schedule('kampusbet_gunun_tahmini', '0 * * * *', 'select private.process_daily_predictions()');
