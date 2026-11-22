-- create_social_bet: okul maili doğrulanmamış kişi bahis açmaya çalışınca önce bunu söyle (KB002).
-- Önceki sırada hakem varsayılan olarak kendisi olduğundan "hakemin maili doğrulanmalı" (23514) dönüyordu.
create or replace function public.create_social_bet(
  p_cluster_id uuid,
  p_title text,
  p_description text,
  p_options text[],
  p_locks_at timestamptz,
  p_referee_id uuid default null,
  p_max_stake bigint default null
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_referee uuid := coalesce(p_referee_id, (select auth.uid()));
  v_cluster_type public.cluster_type;
  v_cap bigint;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  if not private.is_verified(v_uid) then
    raise exception 'Bahis açmak için okul mailini doğrulamalısın' using errcode = 'KB002';
  end if;
  select c.type into v_cluster_type from public.clusters c
  where c.id = p_cluster_id and c.id in (select private.my_cluster_ids());
  if not found then
    raise exception 'Küme bulunamadı' using errcode = 'P0002';
  end if;
  if private.referee_restricted(v_uid) then
    raise exception 'Çok fazla itiraz kaybettiğin için şimdilik sosyal bahis açamazsın' using errcode = 'KB014';
  end if;
  if not exists (select 1 from public.user_clusters uc where uc.user_id = v_referee and uc.cluster_id = p_cluster_id)
     or not private.is_verified(v_referee) then
    raise exception 'Hakem bu kümenin üyesi olmalı ve okul maili doğrulanmış olmalı' using errcode = '23514';
  end if;
  if private.referee_restricted(v_referee) then
    raise exception 'Seçilen kişinin hakemlik hakkı kısıtlı' using errcode = 'KB014';
  end if;
  if p_locks_at > now() + interval '30 days' then
    raise exception 'Kapanış en fazla 30 gün sonrası olabilir' using errcode = '23514';
  end if;

  select s.social_max_stake_sp into v_cap from public.economy_settings s where s.id;
  if p_max_stake is not null and (p_max_stake < 1 or p_max_stake > v_cap) then
    raise exception 'Kişi başı en fazla yatırım 1 ile % arasında olmalı', v_cap using errcode = '23514';
  end if;

  return private.create_bet(
    v_uid, p_cluster_id, 'sp_social',
    case v_cluster_type when 'school' then 'school' else 'private' end::public.bet_scope,
    p_title, p_description, p_options, p_locks_at, v_referee, 1, coalesce(p_max_stake, v_cap)
  );
end;
$$;
