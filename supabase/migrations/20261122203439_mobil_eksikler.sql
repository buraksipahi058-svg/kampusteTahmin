-- Adım 15: mobil eksikler için iki okuma fonksiyonu (docs/harita/acik-isler.md; KARARLAR "Mobil eksikler").
--
-- 1. Kişi arama: belirli birine meydan okumak ve sosyal bahse hakem seçmek için okulun okul maili doğrulanmış
--    öğrencileri (ikisinde de sunucu doğrulanmış okul arkadaşı ister). Kendisi, silinmiş ve yasaklı gelmez.
-- 2. Düello cevapları: düello bitince oynamış oyuncu soruları, doğru şıkkı, kendi ve rakibin cevabını görür.
--    Oynamayan (soruları hiç görmeyen) göremez; doğru şıklar başka yerde öğrenciye hiç açılmaz.

-- ---------------------------------------------------------------------------
-- 1. Kişi arama
-- ---------------------------------------------------------------------------

create function public.search_schoolmates(p_query text)
returns table (user_id uuid, first_name text, last_name text, department text, level integer, can_referee boolean)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
  v_school uuid;
  v_query text := btrim(coalesce(p_query, ''));
  v_pattern text;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  v_school := private.current_school_id();
  if v_school is null then
    raise exception 'Profil bulunamadı' using errcode = 'P0002';
  end if;
  if char_length(v_query) not between 2 and 50 then
    raise exception 'Aramak için 2-50 karakter yaz' using errcode = '23514';
  end if;
  -- LIKE özel karakterleri (\ % _) düz karakter olarak aranır.
  v_pattern := '%' || replace(replace(replace(v_query, '\', '\\'), '%', '\%'), '_', '\_') || '%';

  return query
    select p.id, p.first_name, p.last_name, p.department, p.level, not private.referee_restricted(p.id)
    from public.profiles p
    where p.school_id = v_school
      and p.id <> v_uid
      and p.deleted_at is null
      and p.banned_at is null
      and private.is_verified(p.id)
      and (p.first_name || ' ' || p.last_name) ilike v_pattern
    order by p.first_name, p.last_name, p.id
    limit 20;
end;
$$;

revoke execute on function public.search_schoolmates(text) from public, anon;
grant execute on function public.search_schoolmates(text) to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Düello cevapları
-- ---------------------------------------------------------------------------

create function public.trivia_duel_review(p_bet_id uuid)
returns table (
  question_no integer, question text, options text[], correct_index smallint,
  my_answer smallint, opponent_answer smallint
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
  v_duel public.trivia_duels;
  v_status public.bet_status;
  v_mine public.trivia_duel_plays;
  v_other public.trivia_duel_plays;
begin
  if v_uid is null then
    raise exception 'Bu işlem için giriş yapmış olmak gerekir' using errcode = '42501';
  end if;
  select d.* into v_duel from public.trivia_duels d where d.bet_id = p_bet_id;
  select b.status into v_status from public.bets b where b.id = p_bet_id;
  select t.* into v_mine from public.trivia_duel_plays t where t.bet_id = p_bet_id and t.player_id = v_uid;
  -- Görünmeyen ya da henüz bitmemiş düello, düellonun oyuncusu olmayan ve hiç oynamayan için "bulunamadı".
  if v_duel.bet_id is null
     or v_uid not in (v_duel.challenger_id, coalesce(v_duel.opponent_id, v_duel.challenger_id))
     or v_status not in ('settled', 'cancelled')
     or v_mine.bet_id is null then
    raise exception 'Düello cevapları bulunamadı' using errcode = 'P0002';
  end if;
  select t.* into v_other from public.trivia_duel_plays t
  where t.bet_id = p_bet_id and t.player_id <> v_uid;

  return query
    select u.ord::integer, q.question, q.options, q.correct_index,
           v_mine.answers[u.ord::integer], v_other.answers[u.ord::integer]
    from unnest(v_duel.question_ids) with ordinality as u(question_id, ord)
    join public.trivia_questions q on q.id = u.question_id
    order by u.ord;
end;
$$;

revoke execute on function public.trivia_duel_review(uuid) from public, anon;
grant execute on function public.trivia_duel_review(uuid) to authenticated;
