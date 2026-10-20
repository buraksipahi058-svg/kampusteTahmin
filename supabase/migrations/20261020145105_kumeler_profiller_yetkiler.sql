-- Adım 1: kümeler, profiller, küme üyelikleri, yetkiler ve RLS.
--
-- İlkeler:
-- * İstemci (anon / authenticated) hiçbir tabloya doğrudan satır ekleyemez veya silemez.
--   Profil oluşturma ve yetki dağıtımı aşağıdaki security definer fonksiyonlarla yapılır.
-- * Kullanıcı kendi profilinde yalnızca ad, soyad ve bölümü değiştirebilir (kolon yetkisiyle).
-- * Okul maili gizli tabloda (profile_private) durur; okul arkadaşları göremez.
-- * RLS'in kullandığı yardımcı fonksiyonlar API'ye açık olmayan "private" şemasındadır.

-- ---------------------------------------------------------------------------
-- Şema ve türler
-- ---------------------------------------------------------------------------

create schema private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create type public.cluster_type as enum ('school', 'department', 'club', 'group');
create type public.user_role as enum ('student', 'yetkili', 'superadmin');
create type public.membership_role as enum ('member', 'owner');
create type public.permission_key as enum (
  'resmi_bahis_ac',
  'resmi_bahis_kapat',
  'kullanici_bahsi_denetle',
  'market_yonet',
  'gorev_yonet',
  'kullanici_yonet',
  'analitik_gor'
);

-- ---------------------------------------------------------------------------
-- Tablolar
-- ---------------------------------------------------------------------------

-- Kümeler: okul (kök) ve okula bağlı alt kümeler. school_id her satırda kök okulu gösterir
-- (okulun kendisinde school_id = id); RLS'te "aynı okul" kontrolünü tek kolona indirger.
create table public.clusters (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 100 and name = btrim(name) and name !~ '[[:cntrl:]]'),
  type public.cluster_type not null,
  parent_cluster_id uuid references public.clusters (id) on delete restrict,
  school_id uuid not null references public.clusters (id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint clusters_school_has_no_parent check ((type = 'school') = (parent_cluster_id is null)),
  constraint clusters_school_is_self check (type <> 'school' or school_id = id)
);
create index clusters_school_id_idx on public.clusters (school_id);
create index clusters_parent_cluster_id_idx on public.clusters (parent_cluster_id);

-- Bir okulun birden fazla öğrenci mail alan adı olabilir (ör. ogr.x.edu.tr ve x.edu.tr).
create table public.school_email_domains (
  domain text primary key check (
    domain = lower(domain)
    and domain ~ '^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$'
  ),
  school_id uuid not null references public.clusters (id) on delete cascade,
  created_at timestamptz not null default now()
);
create index school_email_domains_school_id_idx on public.school_email_domains (school_id);

-- Profil, auth.users satırına bağlıdır. Ledger kayıtları profile bağlanacağı için auth kullanıcısı
-- silinemez (restrict); hesap silme ileride soft delete + anonimleştirme ile yapılır.
create table public.profiles (
  id uuid primary key references auth.users (id) on delete restrict,
  first_name text not null check (char_length(first_name) between 1 and 50 and first_name = btrim(first_name) and first_name !~ '[[:cntrl:]]'),
  last_name text not null check (char_length(last_name) between 1 and 50 and last_name = btrim(last_name) and last_name !~ '[[:cntrl:]]'),
  school_id uuid not null references public.clusters (id) on delete restrict,
  department text check (department is null or (char_length(department) between 1 and 100 and department = btrim(department) and department !~ '[[:cntrl:]]')),
  role public.user_role not null default 'student',
  xp integer not null default 0 check (xp >= 0),
  level integer not null default 1 check (level >= 1),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index profiles_school_id_idx on public.profiles (school_id);

-- Yalnızca kişinin kendisinin (ve kullanıcı yönetimi yetkisi olanların) görebildiği bilgiler.
-- Bir okul maili yalnızca bir hesaba bağlanabilir.
create table public.profile_private (
  user_id uuid primary key references public.profiles (id) on delete restrict,
  student_email text unique check (student_email = lower(student_email)),
  student_email_verified_at timestamptz,
  constraint profile_private_verified_needs_email check (student_email_verified_at is null or student_email is not null)
);

create table public.user_clusters (
  user_id uuid not null references public.profiles (id) on delete restrict,
  cluster_id uuid not null references public.clusters (id) on delete cascade,
  role_in_cluster public.membership_role not null default 'member',
  joined_at timestamptz not null default now(),
  primary key (user_id, cluster_id)
);
create index user_clusters_cluster_id_idx on public.user_clusters (cluster_id);

-- Yetkili izin bayrakları. Okul kümesine verilir ve o okulun tüm alt kümelerinde geçerlidir.
-- Tehlikeli işlemler (SSP verme, bakiye düzeltme) bayrak değildir; yalnızca süperadmin yapar.
create table public.permissions (
  user_id uuid not null references public.profiles (id) on delete restrict,
  cluster_id uuid not null references public.clusters (id) on delete cascade,
  permission_key public.permission_key not null,
  granted_by uuid not null references public.profiles (id) on delete restrict,
  granted_at timestamptz not null default now(),
  primary key (user_id, cluster_id, permission_key)
);
create index permissions_cluster_id_idx on public.permissions (cluster_id);

-- Para dışı yönetim işlemlerinin denetim kaydı. Yalnızca eklenir.
create table public.admin_audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid not null references public.profiles (id) on delete restrict,
  action text not null,
  target_user_id uuid references public.profiles (id) on delete restrict,
  cluster_id uuid references public.clusters (id) on delete restrict,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index admin_audit_log_created_at_idx on public.admin_audit_log (created_at desc);

-- ---------------------------------------------------------------------------
-- Tetikleyiciler
-- ---------------------------------------------------------------------------

-- school_id'yi doldurur; küme türü ve üst kümesi sonradan değiştirilemez.
create function private.clusters_set_school() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_op = 'UPDATE' then
    if new.type is distinct from old.type
       or new.parent_cluster_id is distinct from old.parent_cluster_id
       or new.school_id is distinct from old.school_id then
      raise exception 'Küme türü ve üst kümesi değiştirilemez' using errcode = '23514';
    end if;
    return new;
  end if;

  if new.type = 'school' then
    new.school_id := new.id;
  else
    select c.school_id into new.school_id from public.clusters c where c.id = new.parent_cluster_id;
  end if;
  return new;
end;
$$;

create trigger clusters_set_school
  before insert or update on public.clusters
  for each row execute function private.clusters_set_school();

-- tg_argv[0] ile verilen kolonun bir okul kümesini gösterdiğini doğrular.
create function private.require_school() returns trigger
language plpgsql set search_path = '' as $$
declare
  v_cluster_id uuid := (to_jsonb(new) ->> tg_argv[0])::uuid;
begin
  if not exists (select 1 from public.clusters c where c.id = v_cluster_id and c.type = 'school') then
    raise exception 'Küme bir okul değil: %', v_cluster_id using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger school_email_domains_require_school
  before insert or update of school_id on public.school_email_domains
  for each row execute function private.require_school('school_id');

create trigger profiles_require_school
  before insert or update of school_id on public.profiles
  for each row execute function private.require_school('school_id');

create trigger permissions_require_school
  before insert or update of cluster_id on public.permissions
  for each row execute function private.require_school('cluster_id');

-- Kullanıcı yalnızca kendi okulunun kümelerine üye olabilir (okullar arası kapsam v2'de).
create function private.user_clusters_same_school() returns trigger
language plpgsql set search_path = '' as $$
begin
  if not exists (
    select 1
    from public.profiles p
    join public.clusters c on c.school_id = p.school_id
    where p.id = new.user_id and c.id = new.cluster_id
  ) then
    raise exception 'Kullanıcı yalnızca kendi okulunun kümelerine katılabilir' using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger user_clusters_same_school
  before insert or update on public.user_clusters
  for each row execute function private.user_clusters_same_school();

create function private.set_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function private.set_updated_at();

-- Yalnızca eklenebilen tablolar için: güncelleme ve silmeyi her rolde engeller.
create function private.forbid_change() returns trigger
language plpgsql set search_path = '' as $$
begin
  raise exception '% tablosu yalnızca eklenebilir', tg_table_name using errcode = '55000';
end;
$$;

create trigger admin_audit_log_append_only
  before update or delete on public.admin_audit_log
  for each row execute function private.forbid_change();

create trigger admin_audit_log_no_truncate
  before truncate on public.admin_audit_log
  for each statement execute function private.forbid_change();

-- ---------------------------------------------------------------------------
-- RLS yardımcıları (security definer: RLS'i atlar, özyinelemeyi önler)
-- ---------------------------------------------------------------------------

create function private.current_school_id() returns uuid
language sql stable security definer set search_path = '' as $$
  select p.school_id from public.profiles p where p.id = (select auth.uid());
$$;

create function private.is_superadmin() returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce(
    (select p.role = 'superadmin' from public.profiles p where p.id = (select auth.uid())),
    false
  );
$$;

create function private.my_cluster_ids() returns setof uuid
language sql stable security definer set search_path = '' as $$
  select uc.cluster_id from public.user_clusters uc where uc.user_id = (select auth.uid());
$$;

create function private.school_of_user(p_user_id uuid) returns uuid
language sql stable security definer set search_path = '' as $$
  select p.school_id from public.profiles p where p.id = p_user_id;
$$;

-- Oturumdaki kullanıcının, verilen kümenin okulunda bu izne sahip olup olmadığı.
create function private.has_permission(p_cluster_id uuid, p_key public.permission_key) returns boolean
language sql stable security definer set search_path = '' as $$
  select private.is_superadmin() or exists (
    select 1
    from public.clusters c
    join public.permissions pm on pm.cluster_id = c.school_id
    where c.id = p_cluster_id
      and pm.user_id = (select auth.uid())
      and pm.permission_key = p_key
  );
$$;

revoke execute on all functions in schema private from public;
grant execute on function
  private.current_school_id(),
  private.is_superadmin(),
  private.my_cluster_ids(),
  private.school_of_user(uuid),
  private.has_permission(uuid, public.permission_key)
to authenticated;

-- ---------------------------------------------------------------------------
-- Tablo yetkileri ve RLS
-- ---------------------------------------------------------------------------

revoke all on
  public.clusters,
  public.school_email_domains,
  public.profiles,
  public.profile_private,
  public.user_clusters,
  public.permissions,
  public.admin_audit_log
from anon, authenticated;

grant select on
  public.clusters,
  public.school_email_domains,
  public.profiles,
  public.profile_private,
  public.user_clusters,
  public.permissions,
  public.admin_audit_log
to authenticated;

grant update (first_name, last_name, department) on public.profiles to authenticated;

alter table public.clusters enable row level security;
alter table public.school_email_domains enable row level security;
alter table public.profiles enable row level security;
alter table public.profile_private enable row level security;
alter table public.user_clusters enable row level security;
alter table public.permissions enable row level security;
alter table public.admin_audit_log enable row level security;

-- Okul listesi herkese açık (kayıtta okul seçilir). Alt kümeler okul içine,
-- özel gruplar yalnızca üyelerine görünür.
create policy clusters_select on public.clusters
  for select to authenticated
  using (
    type = 'school'
    or (school_id = (select private.current_school_id()) and type <> 'group')
    or id in (select private.my_cluster_ids())
    or (select private.is_superadmin())
  );

create policy school_email_domains_select on public.school_email_domains
  for select to authenticated
  using (true);

create policy profiles_select on public.profiles
  for select to authenticated
  using (
    id = (select auth.uid())
    or school_id = (select private.current_school_id())
    or (select private.is_superadmin())
  );

create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

create policy profile_private_select on public.profile_private
  for select to authenticated
  using (
    user_id = (select auth.uid())
    or private.has_permission(private.school_of_user(user_id), 'kullanici_yonet')
  );

create policy user_clusters_select on public.user_clusters
  for select to authenticated
  using (
    user_id = (select auth.uid())
    or cluster_id in (select private.my_cluster_ids())
    or (select private.is_superadmin())
  );

create policy permissions_select on public.permissions
  for select to authenticated
  using (
    user_id = (select auth.uid())
    or (select private.is_superadmin())
  );

create policy admin_audit_log_select on public.admin_audit_log
  for select to authenticated
  using ((select private.is_superadmin()));

-- ---------------------------------------------------------------------------
-- RPC'ler
-- ---------------------------------------------------------------------------

-- Giriş yapmış kullanıcının profilini oluşturur ve okul kümesine üye yapar.
-- (Başlangıç SP'si Adım 2'de ledger ile buraya eklenecek.)
create function public.create_profile(
  p_first_name text,
  p_last_name text,
  p_school_id uuid,
  p_department text default null
) returns public.profiles
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_profile public.profiles;
begin
  if v_uid is null or coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  if exists (select 1 from public.profiles p where p.id = v_uid) then
    raise exception 'Profil zaten oluşturulmuş' using errcode = '23505';
  end if;

  insert into public.profiles (id, first_name, last_name, school_id, department)
  values (v_uid, btrim(p_first_name), btrim(p_last_name), p_school_id, nullif(btrim(p_department), ''))
  returning * into v_profile;

  insert into public.profile_private (user_id) values (v_uid);
  insert into public.user_clusters (user_id, cluster_id, role_in_cluster) values (v_uid, p_school_id, 'member');

  return v_profile;
end;
$$;

-- Süperadmin, bir kullanıcıya kendi okulunda izin bayrağı verir.
create function public.grant_permission(
  p_user_id uuid,
  p_school_id uuid,
  p_key public.permission_key
) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_actor uuid := (select auth.uid());
begin
  if not private.is_superadmin() then
    raise exception 'Bu işlem yalnızca süperadmin içindir' using errcode = '42501';
  end if;
  if not exists (select 1 from public.profiles p where p.id = p_user_id and p.school_id = p_school_id) then
    raise exception 'Kullanıcı bu okula kayıtlı değil' using errcode = '23514';
  end if;

  insert into public.permissions (user_id, cluster_id, permission_key, granted_by)
  values (p_user_id, p_school_id, p_key, v_actor)
  on conflict do nothing;
  if not found then
    return;
  end if;

  update public.profiles set role = 'yetkili' where id = p_user_id and role = 'student';

  insert into public.admin_audit_log (actor_id, action, target_user_id, cluster_id, details)
  values (v_actor, 'permission_grant', p_user_id, p_school_id, jsonb_build_object('permission', p_key));
end;
$$;

-- Süperadmin izni geri alır; hiç izni kalmayan yetkili öğrenciye döner.
create function public.revoke_permission(
  p_user_id uuid,
  p_school_id uuid,
  p_key public.permission_key
) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_actor uuid := (select auth.uid());
begin
  if not private.is_superadmin() then
    raise exception 'Bu işlem yalnızca süperadmin içindir' using errcode = '42501';
  end if;

  delete from public.permissions
  where user_id = p_user_id and cluster_id = p_school_id and permission_key = p_key;
  if not found then
    return;
  end if;

  update public.profiles p set role = 'student'
  where p.id = p_user_id
    and p.role = 'yetkili'
    and not exists (select 1 from public.permissions pm where pm.user_id = p_user_id);

  insert into public.admin_audit_log (actor_id, action, target_user_id, cluster_id, details)
  values (v_actor, 'permission_revoke', p_user_id, p_school_id, jsonb_build_object('permission', p_key));
end;
$$;

revoke execute on function
  public.create_profile(text, text, uuid, text),
  public.grant_permission(uuid, uuid, public.permission_key),
  public.revoke_permission(uuid, uuid, public.permission_key)
from public, anon;

grant execute on function
  public.create_profile(text, text, uuid, text),
  public.grant_permission(uuid, uuid, public.permission_key),
  public.revoke_permission(uuid, uuid, public.permission_key)
to authenticated;
