-- Güvenlik kontrolü 3 (kampüs kelimesi düzeltmeleri) ve ipucu (KARARLAR "Kampüs kelimesi").
--
-- Düzeltmeler (docs/harita/guvenlik.md "Genel güvenlik kontrolü 3"):
--   1. Sözlükte olmayan cevap bedava denemeyle bulunabiliyordu (sözlük dışı tahmin cevap değilse hak gitmeden KB038):
--      girilen kelime sözlüğe eklenir, cevap istisnası kalkar; "bitti" (KB039) sözlük kontrolünden önce.
--   2. Gün içinde okula kelime eklenince ikinci oyun / ikinci ödül: kişi günde tek bulmaca oynar (o gün başladığı);
--      bugün genel kelime varken okula bugün için kelime girilemez (KB041).
--   3. Kelimeyi bir kez görmüş (giren, yönetim listesinde gören) izni kalksa da o kelimeden ödül almaz.
--   4. Düzenleme ile ilk tahmin yarışı: tahmin, kelimeyi okumadan bulmaca satırını FOR SHARE kilitler.
--   5. `word_puzzles.created_by` öğrencilere kapalı (kolon bazlı okuma).
-- İpucu: kelimeyi giren isteğe bağlı kısa ipucu yazar; `word_hint_after` (3) tahminden sonra ya da oyun bitince döner.

-- ---------------------------------------------------------------------------
-- Ayar, ipucu kolonu, kelimeyi görenler
-- ---------------------------------------------------------------------------

alter table public.economy_settings
  add column word_hint_after integer not null default 3,
  add constraint economy_settings_word_hint_after check (word_hint_after between 1 and word_max_guesses - 1);

alter table private.word_answers
  add column hint text check (hint is null or (char_length(hint) between 3 and 140 and hint = btrim(hint)
                                               and hint !~ '[[:cntrl:]]'));

-- Kelimeyi görmüş kişiler (giren, yönetim listesinde gören): o kelimeden ödül alamaz.
create table private.word_puzzle_viewers (
  puzzle_id uuid not null references public.word_puzzles (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete restrict,
  seen_at timestamptz not null default now(),
  primary key (puzzle_id, user_id)
);
alter table private.word_puzzle_viewers enable row level security;
revoke all on private.word_puzzle_viewers from anon, authenticated;

insert into private.word_puzzle_viewers (puzzle_id, user_id)
select w.id, w.created_by from public.word_puzzles w
on conflict do nothing;

-- Girilmiş kelimeler sözlükte olsun (cevap istisnası kalkıyor).
insert into private.word_dictionary (word)
select x.word from private.word_answers x
on conflict do nothing;

-- Kelimeyi gireni öğrenci görmesin.
revoke select on public.word_puzzles from authenticated;
grant select (id, school_id, puzzle_date, word_length, created_at, updated_at) on public.word_puzzles to authenticated;

-- ---------------------------------------------------------------------------
-- Yardımcılar
-- ---------------------------------------------------------------------------

drop function private.word_reward_blocked(uuid);
create function private.word_reward_blocked(p_puzzle_id uuid, p_school_id uuid) returns boolean
language sql stable set search_path = '' as $$
  select private.is_superadmin()
      or (p_school_id is not null and private.has_permission(p_school_id, 'kelime_yonet'))
      or exists (select 1 from private.word_puzzle_viewers v
                 where v.puzzle_id = p_puzzle_id and v.user_id = (select auth.uid()));
$$;

-- Kişinin o günkü bulmacası: o gün başladığı varsa o (sonradan eklenen kelime ikinci oyun açmaz), yoksa okulunki.
create function private.word_puzzle_for_user(p_user_id uuid, p_school_id uuid, p_date date) returns uuid
language sql stable set search_path = '' as $$
  select coalesce(
    (select a.puzzle_id from public.word_attempts a join public.word_puzzles w on w.id = a.puzzle_id
     where a.user_id = p_user_id and w.puzzle_date = p_date
     order by a.created_at limit 1),
    private.word_puzzle_for(p_school_id, p_date)
  );
$$;

-- İpucu görünür mü: varsa ve yeterince tahmin yapıldıysa ya da oyun bittiyse.
create function private.word_hint_visible(p_guesses integer, p_finished boolean) returns boolean
language sql stable set search_path = '' as $$
  select p_finished or p_guesses >= (select s.word_hint_after from public.economy_settings s where s.id);
$$;

revoke execute on function
  private.word_reward_blocked(uuid, uuid), private.word_puzzle_for_user(uuid, uuid, date),
  private.word_hint_visible(integer, boolean)
from public;

-- ---------------------------------------------------------------------------
-- Oyun (dönüş tipleri değiştiği için yeniden oluşturulur)
-- ---------------------------------------------------------------------------

drop function public.my_word_puzzle();
create function public.my_word_puzzle()
returns table (
  puzzle_id uuid, puzzle_date date, word_length integer, max_guesses integer,
  guesses text[], marks text[], solved boolean, finished boolean,
  reward_sp integer, reward_xp integer, answer text,
  rewards_sp integer[], rewards_xp integer[], can_earn boolean,
  has_hint boolean, hint_after integer, hint text
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
  v_school uuid;
  v_puzzle public.word_puzzles;
  v_attempt public.word_attempts;
  v_cfg public.economy_settings;
  v_answer private.word_answers;
  v_done boolean;
  v_count integer;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  v_school := private.current_school_id();
  if v_school is null then
    raise exception 'Okul mailini doğrulamadan oynanamaz' using errcode = 'KB002';
  end if;
  select * into v_puzzle from public.word_puzzles w
  where w.id = private.word_puzzle_for_user(v_uid, v_school, private.word_today());
  if not found then
    return;
  end if;
  select * into v_cfg from public.economy_settings s where s.id;
  select * into v_attempt from public.word_attempts a where a.puzzle_id = v_puzzle.id and a.user_id = v_uid;
  select * into v_answer from private.word_answers x where x.puzzle_id = v_puzzle.id;
  v_done := v_attempt.finished_at is not null;
  v_count := coalesce(cardinality(v_attempt.guesses), 0);

  return query select
    v_puzzle.id, v_puzzle.puzzle_date, v_puzzle.word_length, v_cfg.word_max_guesses,
    coalesce(v_attempt.guesses, '{}'::text[]), coalesce(v_attempt.marks, '{}'::text[]),
    coalesce(v_attempt.solved, false), v_done,
    coalesce(v_attempt.reward_sp, 0), coalesce(v_attempt.reward_xp, 0),
    case when v_done then v_answer.word end,
    v_cfg.word_reward_sp, v_cfg.word_reward_xp, not private.word_reward_blocked(v_puzzle.id, v_puzzle.school_id),
    v_answer.hint is not null, v_cfg.word_hint_after,
    case when private.word_hint_visible(v_count, v_done) then v_answer.hint end;
end;
$$;

drop function public.submit_word_guess(uuid, text);
create function public.submit_word_guess(p_puzzle_id uuid, p_guess text)
returns table (
  marks text, solved boolean, finished boolean, guesses_left integer,
  reward_sp integer, reward_xp integer, answer text, hint text
)
language plpgsql security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
  v_school uuid;
  v_puzzle public.word_puzzles;
  v_answer private.word_answers;
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
  -- Yalnızca kişinin bugünkü bulmacası (o gün başladığı ya da okulunun bugünkü kelimesi).
  if p_puzzle_id is null
     or p_puzzle_id is distinct from private.word_puzzle_for_user(v_uid, v_school, private.word_today()) then
    raise exception 'Bugünün kelimesi bulunamadı' using errcode = 'P0002';
  end if;

  -- Kilit sırası: bulmaca (FOR SHARE: kelime düzenlemesi bitene kadar bekler) → deneme → bakiye → profil (XP).
  select * into v_puzzle from public.word_puzzles w where w.id = p_puzzle_id for share;
  select * into v_answer from private.word_answers x where x.puzzle_id = p_puzzle_id;

  -- Bitmiş oyunda hiçbir tahmin denetlenmez (sözlük sorgusu olarak kullanılmasın).
  select * into v_attempt from public.word_attempts a
  where a.puzzle_id = p_puzzle_id and a.user_id = v_uid
  for update;
  if found and v_attempt.finished_at is not null then
    raise exception 'Bugünün kelimesi bitti' using errcode = 'KB039';
  end if;

  if v_guess is null or v_guess !~ '^[ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ]+$' then
    raise exception 'Tahmin yalnızca Türkçe harflerden oluşmalı' using errcode = '23514';
  end if;
  if char_length(v_guess) <> v_puzzle.word_length then
    raise exception 'Tahmin % harfli olmalı', v_puzzle.word_length using errcode = 'KB037';
  end if;
  -- Girilen kelimeler de sözlükte: cevap için ayrı istisna yok (KB038 cevap hakkında bilgi vermez).
  if not exists (select 1 from private.word_dictionary d where d.word = v_guess) then
    raise exception 'Bu kelime sözlükte yok' using errcode = 'KB038';
  end if;

  if v_attempt.puzzle_id is null then
    insert into public.word_attempts (puzzle_id, user_id) values (p_puzzle_id, v_uid) on conflict do nothing;
    select * into v_attempt from public.word_attempts a
    where a.puzzle_id = p_puzzle_id and a.user_id = v_uid
    for update;
    if v_attempt.finished_at is not null then
      raise exception 'Bugünün kelimesi bitti' using errcode = 'KB039';
    end if;
  end if;

  select * into v_cfg from public.economy_settings s where s.id;
  v_marks := private.word_marks(v_guess, v_answer.word);
  v_n := cardinality(v_attempt.guesses) + 1;
  v_solved := v_guess = v_answer.word;
  v_finished := v_solved or v_n >= v_cfg.word_max_guesses;
  if v_solved and not private.word_reward_blocked(p_puzzle_id, v_puzzle.school_id) then
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
    case when v_finished then v_answer.word end,
    case when private.word_hint_visible(v_n, v_finished) then v_answer.hint end;
end;
$$;

-- ---------------------------------------------------------------------------
-- Yönetim
-- ---------------------------------------------------------------------------

drop function public.save_word_puzzle(uuid, uuid, date, text);
create function public.save_word_puzzle(
  p_id uuid, p_school_id uuid, p_puzzle_date date, p_word text, p_hint text default null
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_word text := private.normalize_word(p_word);
  v_hint text := nullif(btrim(p_hint), '');
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
  if v_hint is not null and (char_length(v_hint) not between 3 and 140 or v_hint ~ '[[:cntrl:]]') then
    raise exception 'İpucu 3–140 karakter olmalı' using errcode = '23514';
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
  -- Bugün genel kelime oynanırken okula bugün için yeni kelime girilirse (ya da bugüne taşınırsa) oyun gün ortasında
  -- değişirdi. Zaten bugün olan (oynanmamış) okul kelimesinin düzenlenmesi serbest.
  if p_school_id is not null and p_puzzle_date = private.word_today()
     and (p_id is null or v_old.puzzle_date <> p_puzzle_date)
     and exists (select 1 from public.word_puzzles w where w.school_id is null and w.puzzle_date = p_puzzle_date) then
    raise exception 'Bugün bütün okullar için kelime oynanıyor; okula yarından itibaren kelime girilebilir'
      using errcode = 'KB041';
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
  insert into private.word_answers (puzzle_id, word, hint) values (v_id, v_word, v_hint)
  on conflict (puzzle_id) do update set word = excluded.word, hint = excluded.hint;
  -- Cevap da tahmin olarak kabul edilsin (sözlük dışı kampüs kelimesi); giren o kelimeden ödül almaz.
  insert into private.word_dictionary (word) values (v_word) on conflict do nothing;
  insert into private.word_puzzle_viewers (puzzle_id, user_id) values (v_id, v_uid) on conflict do nothing;

  insert into public.admin_audit_log (actor_id, action, cluster_id, details)
  values (v_uid, 'word_puzzle_save', p_school_id,
          jsonb_build_object('puzzle_id', v_id, 'date', p_puzzle_date, 'word', v_word, 'hint', v_hint,
                             'new', p_id is null));
  return v_id;
end;
$$;

-- Yönetim listesi: listede kelimeyi gören kayda geçer (izni kalksa da o kelimelerden ödül almaz).
drop function public.list_word_puzzles();
create function public.list_word_puzzles()
returns table (
  id uuid, school_id uuid, school_name text, puzzle_date date, word text, hint text,
  players integer, solvers integer, first_try integer
)
language plpgsql security definer set search_path = '' as $$
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

  -- Veri değiştiren CTE (görenler kaydı) ana sorgu okumasa da bir kez çalışır.
  return query
  with listed as (
    select w.id from public.word_puzzles w
    where w.puzzle_date >= private.word_today() - 30
      and (private.is_superadmin() or (w.school_id is not null and private.has_permission(w.school_id, 'kelime_yonet')))
  ), seen as (
    insert into private.word_puzzle_viewers (puzzle_id, user_id)
    select l.id, v_uid from listed l
    on conflict do nothing
    returning 1
  )
  select w.id, w.school_id, c.name, w.puzzle_date, x.word, x.hint,
         (select count(*)::integer from public.word_attempts a where a.puzzle_id = w.id),
         (select count(*)::integer from public.word_attempts a where a.puzzle_id = w.id and a.solved),
         (select count(*)::integer from public.word_attempts a
          where a.puzzle_id = w.id and a.solved and cardinality(a.guesses) = 1)
  from listed l
  join public.word_puzzles w on w.id = l.id
  join private.word_answers x on x.puzzle_id = w.id
  left join public.clusters c on c.id = w.school_id
  order by w.puzzle_date desc, c.name nulls first;
end;
$$;

revoke execute on function
  public.my_word_puzzle(), public.submit_word_guess(uuid, text),
  public.save_word_puzzle(uuid, uuid, date, text, text), public.list_word_puzzles()
from public, anon;
grant execute on function
  public.my_word_puzzle(), public.submit_word_guess(uuid, text),
  public.save_word_puzzle(uuid, uuid, date, text, text), public.list_word_puzzles()
to authenticated;
