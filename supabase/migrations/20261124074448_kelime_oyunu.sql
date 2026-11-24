-- Adım 19: Kampüs kelimesi (KARARLAR "Kampüs kelimesi").
--
-- Günde bir kelime: okulun yetkilisi (`kelime_yonet`) kendi okulu için, süperadmin bütün okullar için (genel) ya da
-- bir okul için kelime girer. Öğrencinin günün kelimesi okuluna özel olan, yoksa genel olandır. 4–8 harf, en çok
-- `word_max_guesses` (6) tahmin; her tahminde harf işaretleri: 2 doğru yerde, 1 kelimede var ama başka yerde, 0 yok.
--
-- Kelime istemciye hiç açılmaz (`private.word_answers`); tahmin sunucuda işaretlenir, kelime yalnızca oyun bitince
-- (bulunca ya da haklar bitince) döner. Tahmin Türkçe sözlükte olmalı (`private.word_dictionary`, zemberek-nlp
-- sözlüğünden; veri `kelime_sozlugu` migration'ında) ya da günün kelimesinin kendisi olmalı.
-- Bulana ödül: kaçıncı tahminde bulduysa `word_reward_sp[n]` SP + `word_reward_xp[n]` XP (XP ledger kaydından
-- tetiklenir). Kelimeyi görebilen (süperadmin; okul kelimesinde o okulda `kelime_yonet` olan) oynar ama ödül almaz.

-- ---------------------------------------------------------------------------
-- Ayarlar
-- ---------------------------------------------------------------------------

alter table public.economy_settings
  add column word_max_guesses integer not null default 6 check (word_max_guesses between 3 and 10),
  add column word_reward_sp integer[] not null default '{60,60,40,40,20,20}',
  add column word_reward_xp integer[] not null default '{20,20,15,15,10,10}',
  add constraint economy_settings_word_rewards check (
    cardinality(word_reward_sp) = word_max_guesses and cardinality(word_reward_xp) = word_max_guesses
    and array_position(word_reward_sp, null) is null and array_position(word_reward_xp, null) is null
    and 0 < all (word_reward_sp) and 0 <= all (word_reward_xp)
  );

-- ---------------------------------------------------------------------------
-- Tablolar
-- ---------------------------------------------------------------------------

create table public.word_puzzles (
  id uuid primary key default gen_random_uuid(),
  -- Boş: genel (bütün okullar; yalnızca süperadmin girer).
  school_id uuid references public.clusters (id) on delete restrict,
  puzzle_date date not null,
  word_length integer not null check (word_length between 4 and 8),
  created_by uuid not null references public.profiles (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
-- Bir gün için okul başına bir kelime, genel de bir tane.
create unique index word_puzzles_day_key
  on public.word_puzzles (coalesce(school_id, '00000000-0000-0000-0000-000000000000'::uuid), puzzle_date);
create trigger word_puzzles_updated_at before update on public.word_puzzles
  for each row execute function private.set_updated_at();

create table private.word_answers (
  puzzle_id uuid primary key references public.word_puzzles (id) on delete cascade,
  word text not null check (word ~ '^[ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ]{4,8}$')
);

create table private.word_dictionary (
  word text primary key check (word ~ '^[ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ]{4,8}$')
);

create table public.word_attempts (
  puzzle_id uuid not null references public.word_puzzles (id) on delete restrict,
  user_id uuid not null references public.profiles (id) on delete restrict,
  guesses text[] not null default '{}',
  -- Her tahminin işaretleri, harf başına: 2 doğru yerde, 1 başka yerde var, 0 yok (ör. '20100').
  marks text[] not null default '{}',
  solved boolean not null default false,
  finished_at timestamptz,
  reward_sp integer not null default 0 check (reward_sp >= 0),
  reward_xp integer not null default 0 check (reward_xp >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (puzzle_id, user_id),
  constraint word_attempts_marks check (cardinality(guesses) = cardinality(marks)),
  constraint word_attempts_solved_finished check (not solved or finished_at is not null)
);
create index word_attempts_user_idx on public.word_attempts (user_id, created_at desc);
create trigger word_attempts_updated_at before update on public.word_attempts
  for each row execute function private.set_updated_at();

alter table public.word_puzzles enable row level security;
alter table public.word_attempts enable row level security;
alter table private.word_answers enable row level security;
alter table private.word_dictionary enable row level security;
revoke all on public.word_puzzles, public.word_attempts from anon, authenticated;
revoke all on private.word_answers, private.word_dictionary from anon, authenticated;
grant select on public.word_puzzles, public.word_attempts to authenticated;

-- Bulmaca (kelimesiz: yalnızca gün ve uzunluk): yöneten gelecektekileri de görür; okul maili doğrulanmış öğrenci
-- kendi okulunun ve genel bulmacanın bugüne kadar olanlarını.
create policy word_puzzles_select on public.word_puzzles for select to authenticated using (
  (select private.is_superadmin())
  or (school_id is not null and private.has_permission(school_id, 'kelime_yonet'))
  or (
    (school_id = (select private.current_school_id())
     or (school_id is null and (select private.current_school_id()) is not null))
    and puzzle_date <= (select (now() at time zone s.day_timezone)::date from public.economy_settings s where s.id)
  )
);

-- Denemeler (tahminler cevaba ipucu olduğu için) yalnızca kişinin kendisine ve süperadmine.
create policy word_attempts_select on public.word_attempts for select to authenticated
  using (user_id = (select auth.uid()) or (select private.is_superadmin()));

-- ---------------------------------------------------------------------------
-- Yardımcılar
-- ---------------------------------------------------------------------------

-- Bugün (ekonomi ayarındaki saat diliminde, İstanbul).
create function private.word_today() returns date
language sql stable set search_path = '' as $$
  select (now() at time zone s.day_timezone)::date from public.economy_settings s where s.id;
$$;

-- Türkçe büyük harf (i → İ, ı → I), şapkalı harfler düz (â → A).
create function private.normalize_word(p_word text) returns text
language sql immutable set search_path = '' as $$
  select translate(btrim(p_word), 'abcçdefgğhıijklmnoöprsştuüvyzâîûÂÎÛ', 'ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZAİUAİU');
$$;

-- Okulun o günkü bulmacası: okula özel olan, yoksa genel olan.
create function private.word_puzzle_for(p_school_id uuid, p_date date) returns uuid
language sql stable set search_path = '' as $$
  select w.id from public.word_puzzles w
  where w.puzzle_date = p_date and (w.school_id = p_school_id or w.school_id is null)
  order by (w.school_id is null)
  limit 1;
$$;

-- Tahminin işaretleri. Önce doğru yerdekiler (2); kalan harfler, kelimede kalan sayısı kadar 1 alır
-- (ör. kelimede bir A varken iki A tahmin edilirse yalnızca biri işaretlenir).
create function private.word_marks(p_guess text, p_answer text) returns text
language plpgsql immutable set search_path = '' as $$
declare
  v_g text[] := regexp_split_to_array(p_guess, '');
  v_a text[] := regexp_split_to_array(p_answer, '');
  v_marks text[] := array_fill('0'::text, array[cardinality(v_g)]);
  v_rest text[] := '{}';
  v_pos integer;
begin
  for i in 1 .. cardinality(v_g) loop
    if v_g[i] = v_a[i] then
      v_marks[i] := '2';
    else
      v_rest := v_rest || v_a[i];
    end if;
  end loop;
  for i in 1 .. cardinality(v_g) loop
    if v_marks[i] <> '2' then
      v_pos := array_position(v_rest, v_g[i]);
      if v_pos is not null then
        v_marks[i] := '1';
        v_rest := v_rest[1:v_pos - 1] || v_rest[v_pos + 1:cardinality(v_rest)];
      end if;
    end if;
  end loop;
  return array_to_string(v_marks, '');
end;
$$;

-- Kelimeyi görebilen ödül almaz: süperadmin; okul kelimesinde o okulda kelime yöneten.
create function private.word_reward_blocked(p_school_id uuid) returns boolean
language sql stable set search_path = '' as $$
  select private.is_superadmin() or (p_school_id is not null and private.has_permission(p_school_id, 'kelime_yonet'));
$$;

revoke execute on function
  private.word_today(), private.normalize_word(text), private.word_puzzle_for(uuid, date),
  private.word_marks(text, text), private.word_reward_blocked(uuid)
from public;

-- ---------------------------------------------------------------------------
-- Ledger ve XP: kelime ödülü yalnızca SP; XP ledger kaydından tetiklenir
-- ---------------------------------------------------------------------------

alter table public.ledger_entries drop constraint ledger_sp_only_rewards;
alter table public.ledger_entries add constraint ledger_sp_only_rewards
  check (reason not in ('signup_bonus', 'daily_login', 'achievement_reward', 'word_reward') or currency = 'SP');

alter table public.xp_events drop constraint xp_events_source;
alter table public.xp_events add constraint xp_events_source check (
  (reason in ('daily_login', 'quest', 'achievement', 'campus_task', 'word_puzzle')) = (ledger_entry_id is not null)
  and (reason = 'correct_pick') = (wager_id is not null)
);

create or replace function private.xp_on_ledger_entry() returns trigger
language plpgsql set search_path = '' as $$
declare
  v_amount integer;
begin
  if new.reason = 'daily_login' then
    select s.xp_daily_login into v_amount from public.economy_settings s where s.id;
    perform private.award_xp(new.user_id, 'daily_login', v_amount, new.id, null);
  elsif new.reason = 'quest_reward' and new.ref_type = 'quest' then
    select q.reward_xp into v_amount from public.quests q where q.id = new.ref_id;
    perform private.award_xp(new.user_id, 'quest', v_amount, new.id, null);
  elsif new.reason = 'achievement_reward' and new.ref_type = 'achievement' then
    select a.reward_xp into v_amount from public.achievements a where a.id = new.ref_id;
    perform private.award_xp(new.user_id, 'achievement', v_amount, new.id, null);
  elsif new.reason = 'campus_task_reward' and new.ref_type = 'campus_task' then
    -- Görevin XP'si gönderiye o anki haliyle yazılır (sonradan değişse de kişinin aldığı kadar).
    select s.reward_xp into v_amount from public.campus_task_submissions s
    where s.task_id = new.ref_id and s.user_id = new.user_id and s.status = 'approved'
    order by s.created_at desc limit 1;
    perform private.award_xp(new.user_id, 'campus_task', v_amount, new.id, null);
  elsif new.reason = 'word_reward' and new.ref_type = 'word_puzzle' then
    -- Denemeye ödülle birlikte yazılan XP.
    select a.reward_xp into v_amount from public.word_attempts a
    where a.puzzle_id = new.ref_id and a.user_id = new.user_id;
    perform private.award_xp(new.user_id, 'word_puzzle', v_amount, new.id, null);
  end if;
  return null;
end;
$$;
revoke execute on function private.xp_on_ledger_entry() from public;

drop trigger ledger_entries_award_xp on public.ledger_entries;
create trigger ledger_entries_award_xp
  after insert on public.ledger_entries
  for each row when (new.reason in ('daily_login', 'quest_reward', 'achievement_reward', 'campus_task_reward',
                                    'word_reward'))
  execute function private.xp_on_ledger_entry();

-- ---------------------------------------------------------------------------
-- Oyun
-- ---------------------------------------------------------------------------

-- Günün bulmacası ve kişinin durumu. Bulmaca yoksa satır dönmez. Kelime yalnızca oyun bitince döner.
create function public.my_word_puzzle()
returns table (
  puzzle_id uuid, puzzle_date date, word_length integer, max_guesses integer,
  guesses text[], marks text[], solved boolean, finished boolean,
  reward_sp integer, reward_xp integer, answer text,
  rewards_sp integer[], rewards_xp integer[], can_earn boolean
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
  v_school uuid;
  v_puzzle public.word_puzzles;
  v_attempt public.word_attempts;
  v_cfg public.economy_settings;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  v_school := private.current_school_id();
  if v_school is null then
    raise exception 'Okul mailini doğrulamadan oynanamaz' using errcode = 'KB002';
  end if;
  select * into v_puzzle from public.word_puzzles w
  where w.id = private.word_puzzle_for(v_school, private.word_today());
  if not found then
    return;
  end if;
  select * into v_cfg from public.economy_settings s where s.id;
  select * into v_attempt from public.word_attempts a where a.puzzle_id = v_puzzle.id and a.user_id = v_uid;

  return query select
    v_puzzle.id, v_puzzle.puzzle_date, v_puzzle.word_length, v_cfg.word_max_guesses,
    coalesce(v_attempt.guesses, '{}'::text[]), coalesce(v_attempt.marks, '{}'::text[]),
    coalesce(v_attempt.solved, false), v_attempt.finished_at is not null,
    coalesce(v_attempt.reward_sp, 0), coalesce(v_attempt.reward_xp, 0),
    case when v_attempt.finished_at is not null
      then (select x.word from private.word_answers x where x.puzzle_id = v_puzzle.id) end,
    v_cfg.word_reward_sp, v_cfg.word_reward_xp, not private.word_reward_blocked(v_puzzle.school_id);
end;
$$;

-- Tahmin gönderir: işaretleri, bitti mi, kalan hak, ödül ve (bittiyse) kelimeyi döner.
create function public.submit_word_guess(p_puzzle_id uuid, p_guess text)
returns table (
  marks text, solved boolean, finished boolean, guesses_left integer,
  reward_sp integer, reward_xp integer, answer text
)
language plpgsql security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
  v_school uuid;
  v_puzzle public.word_puzzles;
  v_answer text;
  v_guess text := private.normalize_word(p_guess);
  v_attempt public.word_attempts;
  v_cfg public.economy_settings;
  v_marks text;
  v_n integer;
  v_solved boolean;
  v_finished boolean;
  v_sp integer := 0;
  v_xp integer := 0;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  v_school := private.current_school_id();
  if v_school is null then
    raise exception 'Okul mailini doğrulamadan oynanamaz' using errcode = 'KB002';
  end if;
  -- Yalnızca kişinin bugünkü bulmacası (dünkü, yarınki ya da başka okulunki "bulunamadı").
  if p_puzzle_id is null or p_puzzle_id is distinct from private.word_puzzle_for(v_school, private.word_today()) then
    raise exception 'Bugünün kelimesi bulunamadı' using errcode = 'P0002';
  end if;
  select * into v_puzzle from public.word_puzzles w where w.id = p_puzzle_id;
  select x.word into v_answer from private.word_answers x where x.puzzle_id = p_puzzle_id;

  if v_guess is null or v_guess !~ '^[ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ]+$' then
    raise exception 'Tahmin yalnızca Türkçe harflerden oluşmalı' using errcode = '23514';
  end if;
  if char_length(v_guess) <> v_puzzle.word_length then
    raise exception 'Tahmin % harfli olmalı', v_puzzle.word_length using errcode = 'KB037';
  end if;
  if v_guess <> v_answer and not exists (select 1 from private.word_dictionary d where d.word = v_guess) then
    raise exception 'Bu kelime sözlükte yok' using errcode = 'KB038';
  end if;

  -- Deneme satırı kilitlenir: aynı anda gönderilen tahminler sırayla işlenir (hak ve ödül kesin kalır).
  -- Kilit sırası: deneme → bakiye (post_ledger) → profil (XP).
  insert into public.word_attempts (puzzle_id, user_id) values (p_puzzle_id, v_uid) on conflict do nothing;
  select * into v_attempt from public.word_attempts a
  where a.puzzle_id = p_puzzle_id and a.user_id = v_uid
  for update;
  if v_attempt.finished_at is not null then
    raise exception 'Bugünün kelimesi bitti' using errcode = 'KB039';
  end if;

  select * into v_cfg from public.economy_settings s where s.id;
  v_marks := private.word_marks(v_guess, v_answer);
  v_n := cardinality(v_attempt.guesses) + 1;
  v_solved := v_guess = v_answer;
  v_finished := v_solved or v_n >= v_cfg.word_max_guesses;
  if v_solved and not private.word_reward_blocked(v_puzzle.school_id) then
    v_sp := coalesce(v_cfg.word_reward_sp[least(v_n, v_cfg.word_max_guesses)], 0);
    v_xp := coalesce(v_cfg.word_reward_xp[least(v_n, v_cfg.word_max_guesses)], 0);
  end if;

  update public.word_attempts a
  set guesses = a.guesses || v_guess, marks = a.marks || v_marks, solved = v_solved,
      finished_at = case when v_finished then now() end, reward_sp = v_sp, reward_xp = v_xp
  where a.puzzle_id = p_puzzle_id and a.user_id = v_uid;

  if v_sp > 0 then
    perform private.post_ledger(v_uid, 'SP', v_sp, 'word_reward', 'word_puzzle', p_puzzle_id, null, null);
  end if;

  return query select v_marks, v_solved, v_finished, greatest(v_cfg.word_max_guesses - v_n, 0), v_sp, v_xp,
    case when v_finished then v_answer end;
end;
$$;

-- ---------------------------------------------------------------------------
-- Yönetim
-- ---------------------------------------------------------------------------

-- Kelime ekler ya da düzenler (okulu değişmez). Geçmiş güne girilmez; oynanmaya başlanan kelime değişmez.
create function public.save_word_puzzle(p_id uuid, p_school_id uuid, p_puzzle_date date, p_word text)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_word text := private.normalize_word(p_word);
  v_old public.word_puzzles;
  v_id uuid;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  if p_school_id is null then
    if not private.is_superadmin() then
      raise exception 'Bütün okullara kelimeyi yalnızca süperadmin girer' using errcode = '42501';
    end if;
  else
    if not exists (select 1 from public.clusters c where c.id = p_school_id and c.type = 'school') then
      raise exception 'Okul bulunamadı' using errcode = 'P0002';
    end if;
    if not private.has_permission(p_school_id, 'kelime_yonet') then
      raise exception 'Bu okulda kelime yönetme iznin yok' using errcode = '42501';
    end if;
  end if;
  if p_puzzle_date is null or v_word is null or v_word !~ '^[ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ]{4,8}$' then
    raise exception 'Kelime 4–8 Türkçe harf olmalı, gün seçilmeli' using errcode = '23514';
  end if;
  if p_puzzle_date < private.word_today() then
    raise exception 'Geçmiş bir güne kelime girilemez' using errcode = '23514';
  end if;

  if p_id is not null then
    select * into v_old from public.word_puzzles w
    where w.id = p_id and w.school_id is not distinct from p_school_id
    for update;
    if not found then
      raise exception 'Kelime bulunamadı' using errcode = 'P0002';
    end if;
    if exists (select 1 from public.word_attempts a where a.puzzle_id = p_id) then
      raise exception 'Oynanmaya başlanan kelime değiştirilemez' using errcode = 'KB040';
    end if;
  end if;
  if exists (select 1 from public.word_puzzles w
             where w.school_id is not distinct from p_school_id and w.puzzle_date = p_puzzle_date
               and w.id is distinct from p_id) then
    raise exception 'Bu güne zaten kelime girildi' using errcode = '23505';
  end if;

  if p_id is null then
    insert into public.word_puzzles (school_id, puzzle_date, word_length, created_by)
    values (p_school_id, p_puzzle_date, char_length(v_word), v_uid)
    returning id into v_id;
  else
    update public.word_puzzles w set puzzle_date = p_puzzle_date, word_length = char_length(v_word)
    where w.id = p_id;
    v_id := p_id;
  end if;
  insert into private.word_answers (puzzle_id, word) values (v_id, v_word)
  on conflict (puzzle_id) do update set word = excluded.word;

  insert into public.admin_audit_log (actor_id, action, cluster_id, details)
  values (v_uid, 'word_puzzle_save', p_school_id,
          jsonb_build_object('puzzle_id', v_id, 'date', p_puzzle_date, 'word', v_word, 'new', p_id is null));
  return v_id;
end;
$$;

-- Henüz oynanmamış kelimeyi siler.
create function public.delete_word_puzzle(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_puzzle public.word_puzzles;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  select * into v_puzzle from public.word_puzzles w where w.id = p_id for update;
  if not found or not (private.is_superadmin()
                       or (v_puzzle.school_id is not null and private.has_permission(v_puzzle.school_id, 'kelime_yonet'))) then
    raise exception 'Kelime bulunamadı' using errcode = 'P0002';
  end if;
  if exists (select 1 from public.word_attempts a where a.puzzle_id = p_id) then
    raise exception 'Oynanmaya başlanan kelime silinemez' using errcode = 'KB040';
  end if;
  delete from public.word_puzzles w where w.id = p_id;
  insert into public.admin_audit_log (actor_id, action, cluster_id, details)
  values (v_uid, 'word_puzzle_delete', v_puzzle.school_id,
          jsonb_build_object('puzzle_id', p_id, 'date', v_puzzle.puzzle_date));
end;
$$;

-- Yönetim listesi (kelimelerle): son 30 gün ve ileri tarihliler; süperadmin hepsini, yetkili kendi okullarınınkini
-- (genel kelimeyi görmez: oynayıp ödül alabilir).
create function public.list_word_puzzles()
returns table (
  id uuid, school_id uuid, school_name text, puzzle_date date, word text, in_dictionary boolean,
  players integer, solvers integer
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  if not private.is_superadmin()
     and not exists (select 1 from public.permissions pm where pm.user_id = v_uid and pm.permission_key = 'kelime_yonet') then
    raise exception 'Kelime yönetme iznin yok' using errcode = '42501';
  end if;
  return query
  select w.id, w.school_id, c.name, w.puzzle_date, x.word,
         exists (select 1 from private.word_dictionary d where d.word = x.word),
         (select count(*)::integer from public.word_attempts a where a.puzzle_id = w.id),
         (select count(*)::integer from public.word_attempts a where a.puzzle_id = w.id and a.solved)
  from public.word_puzzles w
  join private.word_answers x on x.puzzle_id = w.id
  left join public.clusters c on c.id = w.school_id
  where w.puzzle_date >= private.word_today() - 30
    and (private.is_superadmin() or (w.school_id is not null and private.has_permission(w.school_id, 'kelime_yonet')))
  order by w.puzzle_date desc, c.name nulls first;
end;
$$;

revoke execute on function
  public.my_word_puzzle(), public.submit_word_guess(uuid, text),
  public.save_word_puzzle(uuid, uuid, date, text), public.delete_word_puzzle(uuid), public.list_word_puzzles()
from public, anon;
grant execute on function
  public.my_word_puzzle(), public.submit_word_guess(uuid, text),
  public.save_word_puzzle(uuid, uuid, date, text), public.delete_word_puzzle(uuid), public.list_word_puzzles()
to authenticated;

-- ---------------------------------------------------------------------------
-- Verilerim: kelime oyunu denemeleri de dışa aktarılır (biçim 2'ye `word_puzzles` bölümü eklenir)
-- ---------------------------------------------------------------------------

alter function public.export_my_data() set schema private;
alter function private.export_my_data() rename to export_my_data_base;
revoke execute on function private.export_my_data_base() from public, anon, authenticated;

create function public.export_my_data() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
begin
  return private.export_my_data_base() || jsonb_build_object(
    'word_puzzles', coalesce((
      select jsonb_agg(jsonb_build_object('date', w.puzzle_date, 'guesses', a.guesses, 'solved', a.solved,
                                          'finished_at', a.finished_at, 'reward_sp', a.reward_sp,
                                          'reward_xp', a.reward_xp)
                       order by w.puzzle_date)
      from public.word_attempts a join public.word_puzzles w on w.id = a.puzzle_id
      where a.user_id = v_uid
    ), '[]'::jsonb)
  );
end;
$$;
revoke execute on function public.export_my_data() from public, anon;
grant execute on function public.export_my_data() to authenticated;
