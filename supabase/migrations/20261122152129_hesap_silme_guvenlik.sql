-- Adım 11: güvenlik sıkılaştırması ve hesap silme (KARARLAR "Hesap silme", "Güvenlik denetimi").
--
-- Hesap silme = soft delete + anonimleştirme. Ledger, yatırım, XP ve görev kayıtları kalır (bütünlük ve
-- başkalarının bahis sonuçları için); kişiyi tanıtan her şey silinir ya da boşaltılır:
--   profil adı "Silinmiş Kullanıcı", bölüm boş, rol öğrenci; okul maili ve kod kayıtları; izinler ve üyelikler;
--   liderlik satırları; Supabase Auth'ta e-posta, telefon, şifre, kimlikler ve oturumlar. Auth satırı kalır
--   (profil ona bağlı) ama süresiz engellenir: aynı e-postayla yeniden kayıt olunabilir, eski hesaba girilemez.
-- Sonuçlanmamış bahsi, düellosu ya da hakemliği olan kişi önce onların bitmesini bekler (KB024).

-- ---------------------------------------------------------------------------
-- Güvenlik sıkılaştırması (denetim bulguları)
-- ---------------------------------------------------------------------------

-- Tetikleyici fonksiyonu herkese açık kalmıştı (doğrudan çağrılamaz, yine de kapatılır).
revoke execute on function private.bets_check_scope() from public, anon, authenticated;

-- Kimlik kolonlarının dizileri istemcilere açıktı (Supabase varsayılanı); istemci hiçbir tabloya yazmadığı için gereksiz.
revoke all on all sequences in schema public from anon, authenticated;
revoke all on all sequences in schema private from anon, authenticated;

-- Bundan sonra oluşturulan nesneler istemcilere kendiliğinden açılmaz: her tablo / fonksiyon izni açıkça verilir.
alter default privileges for role postgres in schema public revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public revoke all on sequences from anon, authenticated;
alter default privileges for role postgres in schema public revoke all on functions from anon, authenticated;
alter default privileges for role postgres revoke execute on functions from public;

-- ---------------------------------------------------------------------------
-- Silinmiş profil
-- ---------------------------------------------------------------------------

alter table public.profiles add column deleted_at timestamptz;

-- Silinen kişi, elindeki erişim anahtarının süresi dolana kadar da adını geri yazamaz.
drop policy profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = (select auth.uid()) and deleted_at is null)
  with check (id = (select auth.uid()) and deleted_at is null);

-- Sıralamalar silinmiş kişiyi saymaz (kişisel istatistik zaten yalnızca kişinin kendisi için).
create or replace function private.settled_wagers(p_school_id uuid, p_user_id uuid, p_from timestamptz, p_to timestamptz)
returns table (
  user_id uuid, bet_id uuid, settled_at timestamptz, currency public.currency,
  is_prediction boolean, correct boolean, net bigint
)
language sql stable set search_path = '' as $$
  select w.user_id, b.id, b.settled_at, b.currency,
         not (b.type = 'sp_minigame' and b.settlement_mode = 'auto'),
         coalesce(o.is_winner, false),
         coalesce(w.payout, 0) - w.amount
  from public.wagers w
  join public.profiles p on p.id = w.user_id
  join public.bets b on b.id = w.bet_id
  join public.bet_options o on o.id = w.option_id
  where b.status = 'settled'
    and b.settled_at >= p_from and b.settled_at < p_to
    and (p_school_id is null or p.school_id = p_school_id)
    and (p_user_id is null or w.user_id = p_user_id)
    and (p_user_id is not null or p.deleted_at is null);
$$;

-- Okul özeti: üye sayısı silinmişleri saymaz; etkinlik sayıları (yatırım, görev, market) geçmişi olduğu gibi sayar.
create or replace function public.school_stats(p_school_id uuid)
returns table (
  members integer, verified_members integer, active_this_week integer, wagers_this_week integer,
  sp_staked_this_week bigint, ssp_staked_this_week bigint, open_bets integer, open_disputes integer,
  quest_claims_this_week integer, market_purchases_this_week integer, week_start date
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
  v_week record;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  if not exists (select 1 from public.clusters c where c.id = p_school_id and c.type = 'school') then
    raise exception 'Okul bulunamadı' using errcode = 'P0002';
  end if;
  if not private.has_permission(p_school_id, 'analitik_gor') then
    raise exception 'Bu işlem için yetkin yok' using errcode = '42501';
  end if;
  select * into v_week from private.week_bounds(0);

  return query
    with mem as (
      select p.id, p.deleted_at is not null as deleted from public.profiles p where p.school_id = p_school_id
    ),
    week_wagers as (
      select w.user_id, w.amount, w.currency from public.wagers w
      where w.user_id in (select m.id from mem m)
        and w.created_at >= v_week.o_start and w.created_at < v_week.o_end
    ),
    school_bets as (
      select b.id, b.status from public.bets b
      join public.clusters c on c.id = b.cluster_id
      where c.school_id = p_school_id
    )
    select
      (select count(*) from mem where not mem.deleted)::integer,
      (select count(*) from public.profile_private pp
       where pp.user_id in (select m.id from mem m) and pp.student_email_verified_at is not null)::integer,
      (select count(distinct ww.user_id) from week_wagers ww)::integer,
      (select count(*) from week_wagers)::integer,
      coalesce((select sum(ww.amount) from week_wagers ww where ww.currency = 'SP'), 0)::bigint,
      coalesce((select sum(ww.amount) from week_wagers ww where ww.currency = 'SSP'), 0)::bigint,
      (select count(*) from school_bets sb where sb.status in ('open', 'locked', 'settling'))::integer,
      (select count(*) from public.bet_disputes d
       where d.status = 'open' and d.bet_id in (select sb.id from school_bets sb))::integer,
      (select count(*) from public.quest_claims q
       where q.user_id in (select m.id from mem m)
         and q.claimed_at >= v_week.o_start and q.claimed_at < v_week.o_end)::integer,
      (select count(*) from public.user_inventory i
       where i.user_id in (select m.id from mem m)
         and i.acquired_at >= v_week.o_start and i.acquired_at < v_week.o_end)::integer,
      v_week.o_day;
end;
$$;

-- ---------------------------------------------------------------------------
-- Hesap silme
-- ---------------------------------------------------------------------------

create function public.delete_my_account() returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_profile public.profiles;
  v_emails text[];
  v_permissions integer;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  select * into v_profile from public.profiles p where p.id = v_uid for update;
  if not found or v_profile.deleted_at is not null then
    raise exception 'Profil bulunamadı' using errcode = 'P0002';
  end if;
  if v_profile.role = 'superadmin' then
    raise exception 'Süperadmin hesabı uygulamadan silinemez' using errcode = '42501';
  end if;
  if exists (select 1 from public.wagers w join public.bets b on b.id = w.bet_id
             where w.user_id = v_uid and b.status in ('open', 'locked', 'settling'))
     or exists (select 1 from public.bets b
                where b.referee_id = v_uid and b.status in ('open', 'locked', 'settling')) then
    raise exception 'Sonuçlanmamış bahsin, düellon ya da hakemliğin varken hesap silinemez' using errcode = 'KB024';
  end if;

  -- Uygulama verisi: kişiyi tanıtan alanlar.
  select array_remove(array[pp.student_email] || coalesce((select array_agg(c.email) from private.student_email_challenges c
                                                           where c.user_id = v_uid), '{}'), null)
    into v_emails
  from public.profile_private pp where pp.user_id = v_uid;

  update public.profiles
  set first_name = 'Silinmiş', last_name = 'Kullanıcı', department = null, role = 'student', deleted_at = now()
  where id = v_uid;
  update public.profile_private set student_email = null, student_email_verified_at = null where user_id = v_uid;
  delete from private.student_email_challenges where user_id = v_uid;
  delete from private.dev_outbox where to_email = any (coalesce(v_emails, '{}'));
  delete from public.permissions where user_id = v_uid;
  get diagnostics v_permissions = row_count;
  delete from public.user_clusters where user_id = v_uid;
  update public.user_inventory set equipped = false where user_id = v_uid and equipped;
  delete from public.leaderboard_snapshots where user_id = v_uid;

  -- Supabase Auth: giriş bilgileri silinir, oturumlar kapanır, hesap süresiz engellenir.
  delete from auth.identities where user_id = v_uid;
  delete from auth.sessions where user_id = v_uid;
  delete from auth.refresh_tokens where user_id = v_uid::text;
  delete from auth.mfa_factors where user_id = v_uid;
  delete from auth.one_time_tokens where user_id = v_uid;
  update auth.users
  set email = null, phone = null, encrypted_password = '', raw_user_meta_data = '{}'::jsonb,
      confirmation_token = '', recovery_token = '', email_change = '', email_change_token_new = '',
      email_change_token_current = '', phone_change = '', phone_change_token = '', reauthentication_token = '',
      banned_until = 'infinity', deleted_at = now(), updated_at = now()
  where id = v_uid;

  insert into public.admin_audit_log (actor_id, action, target_user_id, cluster_id, details)
  values (v_uid, 'account_delete', v_uid, v_profile.school_id, jsonb_build_object('permissions_removed', v_permissions));
end;
$$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
