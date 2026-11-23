-- Adım 17: uygulama içi bildirimler (KARARLAR "Uygulama içi bildirimler").
--
-- Bildirimler veritabanında, olay anında tetikleyicilerle üretilir (istemci bildirim yazamaz). Uygulama okunmamış
-- sayısını düzenli aralıkla okur; Realtime ve telefon bildirimi (push, Firebase gerekir) yok.
-- Aynı olay iki kez bildirim üretmez (`dedupe_key`). Silinmiş hesaba bildirim yazılmaz, silinince bildirimleri
-- silinir. 90 günden eski bildirimler zamanlanmış işle temizlenir.

-- ---------------------------------------------------------------------------
-- Tablo
-- ---------------------------------------------------------------------------

create table public.notifications (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  kind text not null check (kind in (
    'bet_won', 'bet_lost', 'bet_refunded', 'bet_cancelled', 'social_result', 'dispute_received', 'dispute_new',
    'dispute_resolved', 'duel_invite', 'duel_accepted', 'level_up', 'referee_strike', 'referee_due', 'admin_grant'
  )),
  title text not null check (char_length(title) between 1 and 80),
  body text not null check (char_length(body) between 1 and 400),
  -- Uygulama içi yol (ör. /bahisler); null ise yalnızca okunur.
  link text check (link is null or link ~ '^/[a-z0-9/_-]*$'),
  dedupe_key text,
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create unique index notifications_dedupe on public.notifications (user_id, dedupe_key) where dedupe_key is not null;
create index notifications_user_created on public.notifications (user_id, created_at desc);
create index notifications_unread on public.notifications (user_id) where read_at is null;

revoke all on public.notifications from anon, authenticated;
grant select on public.notifications to authenticated;
alter table public.notifications enable row level security;

create policy notifications_select_own on public.notifications
  for select to authenticated using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- Üreticiler (tetikleyiciler)
-- ---------------------------------------------------------------------------

-- Bahis durumu: sonuçlandı (kazandın / iade / kaybettin), iptal, hakem sonucu girdi (itiraz süresiyle).
create function private.notify_bet_status() returns trigger
language plpgsql set search_path = '' as $$
declare
  v_link text := case new.type when 'sp_minigame' then '/oyunlar' else '/bahisler' end;
  v_duel boolean := new.type = 'sp_minigame' and new.settlement_mode = 'auto';
  v_winner text;
  v_option text;
begin
  if new.status = 'settled' then
    select o.label into v_winner from public.bet_options o where o.bet_id = new.id and o.is_winner limit 1;
    insert into public.notifications (user_id, kind, title, body, link, dedupe_key)
    select w.user_id,
           case when coalesce(w.payout, 0) > w.amount then 'bet_won'
                when coalesce(w.payout, 0) = w.amount then 'bet_refunded' else 'bet_lost' end,
           case when coalesce(w.payout, 0) > w.amount
                  then 'Kazandın! +' || (w.payout - w.amount) || ' ' || w.currency
                when coalesce(w.payout, 0) = w.amount then 'Yatırımın geri döndü'
                else 'Bu sefer olmadı' end,
           left('«' || new.title || '» sonuçlandı.'
                || case when v_winner is not null and not v_duel then ' Sonuç: ' || v_winner || '.' else '' end, 400),
           v_link, 'bet_settled:' || new.id
    from public.wagers w join public.profiles p on p.id = w.user_id and p.deleted_at is null
    where w.bet_id = new.id
    on conflict do nothing;
  elsif new.status = 'cancelled' then
    insert into public.notifications (user_id, kind, title, body, link, dedupe_key)
    select w.user_id, 'bet_cancelled', 'Bahis iptal edildi',
           left('«' || new.title || '» iptal edildi; yatırımın iade edildi.'
                || coalesce(' Gerekçe: ' || new.cancel_reason, ''), 400),
           v_link, 'bet_cancelled:' || new.id
    from public.wagers w join public.profiles p on p.id = w.user_id and p.deleted_at is null
    where w.bet_id = new.id
    on conflict do nothing;
  elsif new.status = 'settling' and new.type = 'sp_social' then
    select o.label into v_option from public.bet_options o where o.id = new.proposed_option_id;
    insert into public.notifications (user_id, kind, title, body, link, dedupe_key)
    select w.user_id, 'social_result', 'Hakem sonucu girdi',
           left('«' || new.title || '»: ' || coalesce(v_option, '?') || '. Sonuca katılmıyorsan itiraz edebilirsin; süre '
                || to_char(new.dispute_until at time zone 'Europe/Istanbul', 'DD.MM HH24:MI') || ' (İstanbul) bitiyor.', 400),
           v_link, 'social_result:' || new.id
    from public.wagers w join public.profiles p on p.id = w.user_id and p.deleted_at is null
    where w.bet_id = new.id
    on conflict do nothing;
  end if;
  return null;
end;
$$;

create trigger bets_notify_status
  after update of status on public.bets
  for each row when (old.status is distinct from new.status and new.status in ('settled', 'cancelled', 'settling'))
  execute function private.notify_bet_status();

-- İtiraz: hakeme ve okulun moderatörlerine (itiraz eden ve hakem hariç); sonuçlanınca itiraz edene.
create function private.notify_dispute() returns trigger
language plpgsql set search_path = '' as $$
declare
  v_bet public.bets;
  v_school uuid;
begin
  select * into v_bet from public.bets b where b.id = new.bet_id;
  if tg_op = 'INSERT' then
    select c.school_id into v_school from public.clusters c where c.id = v_bet.cluster_id;
    insert into public.notifications (user_id, kind, title, body, link, dedupe_key)
    select v_bet.referee_id, 'dispute_received', 'Sonucuna itiraz edildi',
           left('«' || v_bet.title || '» için girdiğin sonuca itiraz edildi; moderatör karar verecek.', 400),
           '/bahisler', 'dispute_received:' || new.id
    from public.profiles p
    where p.id = v_bet.referee_id and p.deleted_at is null and v_bet.referee_id <> new.raised_by
    on conflict do nothing;
    insert into public.notifications (user_id, kind, title, body, link, dedupe_key)
    select distinct pm.user_id, 'dispute_new', 'Yeni itiraz',
           left('«' || v_bet.title || '» için bir itiraz incelemeni bekliyor (yönetim paneli > İtirazlar).', 400),
           null::text, 'dispute_new:' || new.id
    from public.permissions pm join public.profiles p on p.id = pm.user_id and p.deleted_at is null
    where pm.cluster_id = v_school and pm.permission_key = 'kullanici_bahsi_denetle'
      and pm.user_id <> new.raised_by and pm.user_id is distinct from v_bet.referee_id
    on conflict do nothing;
  elsif new.status = 'resolved' and old.status is distinct from 'resolved' then
    insert into public.notifications (user_id, kind, title, body, link, dedupe_key)
    select new.raised_by, 'dispute_resolved', 'İtirazın sonuçlandı',
           left('«' || v_bet.title || '»: '
                || case new.decision when 'confirmed' then 'hakemin sonucu onaylandı.'
                                     when 'changed' then 'sonuç değiştirildi.'
                                     else 'bahis iptal edildi, yatırımlar iade edildi.' end
                || coalesce(' Not: ' || new.resolution_note, ''), 400),
           '/bahisler', 'dispute_resolved:' || new.id
    from public.profiles p where p.id = new.raised_by and p.deleted_at is null
    on conflict do nothing;
  end if;
  return null;
end;
$$;

create trigger bet_disputes_notify
  after insert or update of status on public.bet_disputes
  for each row execute function private.notify_dispute();

-- Düello: davet edilen kişiye; rakip kabul edince meydan okuyana.
create function private.notify_duel() returns trigger
language plpgsql set search_path = '' as $$
declare
  v_name text;
begin
  if tg_op = 'INSERT' and new.invited_id is not null then
    select p.first_name || ' ' || p.last_name into v_name from public.profiles p where p.id = new.challenger_id;
    insert into public.notifications (user_id, kind, title, body, link, dedupe_key)
    select new.invited_id, 'duel_invite', 'Sana meydan okundu!',
           left(coalesce(v_name, 'Biri') || ' seni ' || new.stake || ' SP''lik trivia düellosuna çağırdı.', 400),
           '/oyunlar', 'duel_invite:' || new.bet_id
    from public.profiles p where p.id = new.invited_id and p.deleted_at is null
    on conflict do nothing;
  elsif tg_op = 'UPDATE' and old.opponent_id is null and new.opponent_id is not null then
    select p.first_name || ' ' || p.last_name into v_name from public.profiles p where p.id = new.opponent_id;
    insert into public.notifications (user_id, kind, title, body, link, dedupe_key)
    select new.challenger_id, 'duel_accepted', 'Meydan okuman kabul edildi',
           left(coalesce(v_name, 'Biri') || ' düellonu kabul etti.'
                || case when exists (select 1 from public.trivia_duel_plays t
                                     where t.bet_id = new.bet_id and t.player_id = new.challenger_id
                                       and t.submitted_at is not null)
                        then '' else ' Sıra sende!' end, 400),
           '/oyunlar', 'duel_accepted:' || new.bet_id
    from public.profiles p where p.id = new.challenger_id and p.deleted_at is null
    on conflict do nothing;
  end if;
  return null;
end;
$$;

create trigger trivia_duels_notify
  after insert or update of opponent_id on public.trivia_duels
  for each row execute function private.notify_duel();

-- Profil: seviye atlama, hakem ihtarı; hesap silinince bildirimleri silinir.
create function private.notify_profile() returns trigger
language plpgsql set search_path = '' as $$
declare
  v_limit integer;
begin
  if new.deleted_at is not null then
    if old.deleted_at is null then
      delete from public.notifications n where n.user_id = new.id;
    end if;
    return null;
  end if;
  if new.level > old.level then
    insert into public.notifications (user_id, kind, title, body, link, dedupe_key)
    values (new.id, 'level_up', 'Seviye ' || new.level || '!',
            'Tebrikler, ' || new.level || '. seviyeye ulaştın. Markette seviyeyle açılan ürünlere göz at.',
            '/market', 'level:' || new.level)
    on conflict do nothing;
  end if;
  if new.referee_strikes > old.referee_strikes then
    select s.referee_strike_limit into v_limit from public.economy_settings s where s.id;
    insert into public.notifications (user_id, kind, title, body, link)
    values (new.id, 'referee_strike', 'Hakem ihtarı aldın',
            'Hakemi olduğun bir bahis yüzünden ihtar aldın (' || new.referee_strikes || '/' || v_limit
            || '). Sınıra ulaşınca hakemlik ve sosyal bahis açma kısıtlanır.', '/profil');
  end if;
  return null;
end;
$$;

create trigger profiles_notify
  after update of level, referee_strikes, deleted_at on public.profiles
  for each row execute function private.notify_profile();

-- Yönetici para işlemi: SSP / SP verildi ya da bakiye düzeltildi.
create function private.notify_admin_money() returns trigger
language plpgsql set search_path = '' as $$
begin
  insert into public.notifications (user_id, kind, title, body, link)
  select new.user_id, 'admin_grant',
         case when new.reason = 'admin_grant' then 'Hesabına ' || new.amount || ' ' || new.currency || ' eklendi'
              else 'Bakiyen düzeltildi (' || case when new.amount > 0 then '+' else '' end || new.amount || ' '
                   || new.currency || ')' end,
         left(coalesce(new.note, 'Yönetici işlemi.'), 400), '/profil'
  from public.profiles p where p.id = new.user_id and p.deleted_at is null;
  return null;
end;
$$;

create trigger ledger_entries_notify_admin
  after insert on public.ledger_entries
  for each row when (new.reason in ('admin_grant', 'admin_adjust'))
  execute function private.notify_admin_money();

-- Zamanlanmış: kapanışı geçmiş ve sonucu girilmemiş sosyal bahsin hakemine hatırlatma; 90 günden eski bildirimleri sil.
create function private.process_notifications() returns void
language plpgsql set search_path = '' as $$
begin
  insert into public.notifications (user_id, kind, title, body, link, dedupe_key)
  select b.referee_id, 'referee_due', 'Sonucu girme zamanı',
         left('«' || b.title || '» kapandı; hakem olarak sonucu gir.', 400), '/bahisler', 'referee_due:' || b.id
  from public.bets b join public.profiles p on p.id = b.referee_id and p.deleted_at is null
  where b.type = 'sp_social' and b.status in ('open', 'locked') and b.locks_at <= now()
    and b.result_submitted_at is null
  on conflict do nothing;

  delete from public.notifications n where n.created_at < now() - interval '90 days';
end;
$$;

revoke execute on function
  private.notify_bet_status(), private.notify_dispute(), private.notify_duel(), private.notify_profile(),
  private.notify_admin_money(), private.process_notifications()
from public;

select cron.schedule('kampusbet_bildirimler', '*/5 * * * *', 'select private.process_notifications()');

-- ---------------------------------------------------------------------------
-- İstemci
-- ---------------------------------------------------------------------------

-- Okundu işaretle: verilen bildirimler ya da (null) hepsi. İşaretlenen sayısını döner.
create function public.mark_notifications_read(p_ids bigint[] default null) returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_count integer;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  update public.notifications n set read_at = now()
  where n.user_id = v_uid and n.read_at is null and (p_ids is null or n.id = any (p_ids));
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke execute on function public.mark_notifications_read(bigint[]) from public, anon;
grant execute on function public.mark_notifications_read(bigint[]) to authenticated;
