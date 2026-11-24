import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase.dart';
import '../progress/progress_data.dart';
import '../wallet/wallet_data.dart';

/// Harf işareti: kelimede doğru yerde, başka yerde var, yok.
enum LetterMark { correct, present, absent }

LetterMark _mark(String c) => switch (c) {
  '2' => LetterMark.correct,
  '1' => LetterMark.present,
  _ => LetterMark.absent,
};

List<LetterMark> parseMarks(String marks) => [for (final c in marks.split('')) _mark(c)];

/// Türkçe harfler (oyunun klavyesi ve sunucunun kabul ettiği harfler; büyük harf).
const turkishLetters = 'ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ';

/// Günün kampüs kelimesi ve kişinin durumu (`public.my_word_puzzle`). Kelime yalnızca oyun bitince gelir.
class WordPuzzle {
  const WordPuzzle({
    required this.id,
    required this.length,
    required this.maxGuesses,
    this.guesses = const [],
    this.marks = const [],
    this.solved = false,
    this.finished = false,
    this.rewardSp = 0,
    this.rewardXp = 0,
    this.answer,
    this.rewardsSp = const [],
    this.rewardsXp = const [],
    this.canEarn = true,
  });

  final String id;
  final int length;
  final int maxGuesses;
  final List<String> guesses;
  final List<List<LetterMark>> marks;
  final bool solved;
  final bool finished;
  final int rewardSp;
  final int rewardXp;
  final String? answer;

  /// Kaçıncı tahminde bulunursa verilecek SP / XP (1. tahmin ilk eleman).
  final List<int> rewardsSp;
  final List<int> rewardsXp;

  /// Kelimeyi yöneten (görebilen) ödül alamaz.
  final bool canEarn;

  int get guessesLeft => maxGuesses - guesses.length;

  factory WordPuzzle.fromJson(Map<String, dynamic> json) {
    List<int> ints(String key) => [for (final v in (json[key] as List? ?? const [])) v as int];
    return WordPuzzle(
      id: json['puzzle_id'] as String,
      length: json['word_length'] as int,
      maxGuesses: json['max_guesses'] as int,
      guesses: [for (final g in (json['guesses'] as List? ?? const [])) g as String],
      marks: [for (final m in (json['marks'] as List? ?? const [])) parseMarks(m as String)],
      solved: json['solved'] as bool,
      finished: json['finished'] as bool,
      rewardSp: json['reward_sp'] as int,
      rewardXp: json['reward_xp'] as int,
      answer: json['answer'] as String?,
      rewardsSp: ints('rewards_sp'),
      rewardsXp: ints('rewards_xp'),
      canEarn: json['can_earn'] as bool,
    );
  }

  /// Tahmin işlendikten sonraki durum.
  WordPuzzle withGuess(String guess, WordGuessResult r) => WordPuzzle(
    id: id,
    length: length,
    maxGuesses: maxGuesses,
    guesses: [...guesses, guess],
    marks: [...marks, r.marks],
    solved: r.solved,
    finished: r.finished,
    rewardSp: r.rewardSp,
    rewardXp: r.rewardXp,
    answer: r.answer,
    rewardsSp: rewardsSp,
    rewardsXp: rewardsXp,
    canEarn: canEarn,
  );
}

class WordGuessResult {
  const WordGuessResult({
    required this.marks,
    required this.solved,
    required this.finished,
    this.rewardSp = 0,
    this.rewardXp = 0,
    this.answer,
  });

  final List<LetterMark> marks;
  final bool solved;
  final bool finished;
  final int rewardSp;
  final int rewardXp;
  final String? answer;
}

/// Kampüs kelimesinin sunucu tarafı (testte sahtesiyle değiştirilir).
class WordApi {
  const WordApi(this._client);

  final SupabaseClient _client;

  /// Bugün kelime yoksa null.
  Future<WordPuzzle?> today() async {
    final rows = await _client.rpc('my_word_puzzle') as List;
    return rows.isEmpty ? null : WordPuzzle.fromJson(rows.first as Map<String, dynamic>);
  }

  /// `public.submit_word_guess`: işaretler sunucuda hesaplanır (kelime istemcide yok).
  Future<WordGuessResult> guess(String puzzleId, String guess) async {
    final row = await _client.rpc('submit_word_guess', params: {'p_puzzle_id': puzzleId, 'p_guess': guess}).single();
    return WordGuessResult(
      marks: parseMarks(row['marks'] as String),
      solved: row['solved'] as bool,
      finished: row['finished'] as bool,
      rewardSp: row['reward_sp'] as int,
      rewardXp: row['reward_xp'] as int,
      answer: row['answer'] as String?,
    );
  }
}

final wordApiProvider = Provider<WordApi>((ref) => WordApi(ref.watch(supabaseProvider)));

final wordPuzzleProvider = FutureProvider<WordPuzzle?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.watch(wordApiProvider).today();
});

/// Ödül alınınca bakiye ve XP yeniden okunur.
void refreshAfterWordReward(ProviderContainer c) {
  c.invalidate(balanceProvider);
  refreshProgress(c);
}
