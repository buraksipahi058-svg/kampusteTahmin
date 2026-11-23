-- Adım 16 eksiği: başarımları admin panelinden ekleme / düzenleme (yalnızca süperadmin; başarımlar okuldan bağımsız).
-- Anahtar sonradan değişmez (istemci ve kayıtlar anahtarla eşleşir); silme yok, kapatılır (`active = false`).
-- Kazanılmış başarım, hedef ya da ödül sonradan değişse de kazanılmış kalır (o anki ödül `achievement_unlocks`'ta).

create function public.save_achievement(
  p_id uuid,
  p_key text,
  p_category public.achievement_category,
  p_title text,
  p_description text,
  p_icon text,
  p_metric text,
  p_target integer,
  p_tier smallint,
  p_reward_sp integer,
  p_reward_xp integer,
  p_hidden boolean,
  p_sort integer,
  p_active boolean
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_old public.achievements;
  v_id uuid;
begin
  if v_uid is null or not private.is_superadmin() then
    raise exception 'Başarımları yalnızca süperadmin yönetir' using errcode = '42501';
  end if;
  if p_key is null or p_category is null or p_title is null or p_description is null or p_icon is null
     or p_metric is null or p_target is null or p_tier is null or p_reward_sp is null or p_reward_xp is null
     or p_hidden is null or p_sort is null or p_active is null then
    raise exception 'Bütün alanlar doldurulmalı' using errcode = '23514';
  end if;

  if p_id is not null then
    select * into v_old from public.achievements a where a.id = p_id for update;
    if not found then
      raise exception 'Başarım bulunamadı' using errcode = 'P0002';
    end if;
    if v_old.key <> p_key then
      raise exception 'Başarımın anahtarı değiştirilemez' using errcode = '23514';
    end if;
    update public.achievements a
    set category = p_category, title = btrim(p_title), description = btrim(p_description), icon = btrim(p_icon),
        metric = p_metric, target = p_target, tier = p_tier, reward_sp = p_reward_sp, reward_xp = p_reward_xp,
        hidden = p_hidden, sort = p_sort, active = p_active
    where a.id = p_id;
    v_id := p_id;
  else
    insert into public.achievements (key, category, title, description, icon, metric, target, tier, reward_sp,
                                     reward_xp, hidden, sort, active)
    values (btrim(p_key), p_category, btrim(p_title), btrim(p_description), btrim(p_icon), p_metric, p_target,
            p_tier, p_reward_sp, p_reward_xp, p_hidden, p_sort, p_active)
    returning id into v_id;
  end if;

  insert into public.admin_audit_log (actor_id, action, details)
  values (v_uid, 'achievement_save',
          jsonb_build_object('achievement_id', v_id, 'key', btrim(p_key), 'title', btrim(p_title),
                             'metric', p_metric, 'target', p_target, 'reward_sp', p_reward_sp,
                             'reward_xp', p_reward_xp, 'active', p_active, 'new', p_id is null));
  return v_id;
end;
$$;

revoke execute on function public.save_achievement(uuid, text, public.achievement_category, text, text, text, text,
  integer, smallint, integer, integer, boolean, integer, boolean) from public, anon;
grant execute on function public.save_achievement(uuid, text, public.achievement_category, text, text, text, text,
  integer, smallint, integer, integer, boolean, integer, boolean) to authenticated;
