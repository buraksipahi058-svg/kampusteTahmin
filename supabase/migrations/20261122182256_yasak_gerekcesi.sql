-- Yasak gerekçesi profil tablosunda okul arkadaşlarına görünüyordu (profiles okula açık). Gerekçe yalnızca
-- süperadminin okuduğu denetim kaydında tutulur; profilde yalnızca yasak zamanı kalır.

alter table public.profiles drop column banned_reason;

create or replace function public.set_user_ban(p_user_id uuid, p_banned boolean, p_reason text default null) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_target public.profiles;
  v_reason text := btrim(coalesce(p_reason, ''));
begin
  if v_uid is null or not private.is_superadmin() then
    raise exception 'Bu işlem yalnızca süperadmin içindir' using errcode = '42501';
  end if;
  if p_user_id = v_uid then
    raise exception 'Kendini yasaklayamazsın' using errcode = '42501';
  end if;
  select * into v_target from public.profiles p where p.id = p_user_id for no key update;
  if not found or v_target.deleted_at is not null then
    raise exception 'Kullanıcı bulunamadı' using errcode = 'P0002';
  end if;
  if v_target.role = 'superadmin' then
    raise exception 'Süperadmin yasaklanamaz' using errcode = '42501';
  end if;

  if coalesce(p_banned, false) then
    if char_length(v_reason) < 3 then
      raise exception 'Yasak gerekçesi yazılmalı (en az 3 karakter)' using errcode = '23514';
    end if;
    update public.profiles set banned_at = now() where id = p_user_id;
    update auth.users set banned_until = now() + interval '100 years', updated_at = now() where id = p_user_id;
    delete from auth.sessions where user_id = p_user_id;
    delete from auth.refresh_tokens where user_id = p_user_id::text;
  else
    update public.profiles set banned_at = null where id = p_user_id;
    update auth.users set banned_until = null, updated_at = now() where id = p_user_id;
  end if;

  insert into public.admin_audit_log (actor_id, action, target_user_id, cluster_id, details)
  values (v_uid, case when coalesce(p_banned, false) then 'user_ban' else 'user_unban' end, p_user_id,
          v_target.school_id, jsonb_build_object('reason', nullif(left(v_reason, 300), '')));
end;
$$;
