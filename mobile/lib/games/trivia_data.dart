import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bets/bets_data.dart';
import '../core/supabase.dart';
import '../profile/profile_data.dart';

/// Bir oyuncunun düello oyunu. Düello bitmeden yalnızca kişinin kendi oyunu görünür (RLS).
class DuelPlay {
  const DuelPlay({required this.playerId, required this.submitted, this.score});

  final String playerId;
  final bool submitted;
  final int? score;

  factory DuelPlay.fromJson(Map<String, dynamic> json) => DuelPlay(
    playerId: json['player_id'] as String,
    submitted: json['submitted_at'] != null,
    score: json['score'] as int?,
  );
}

class TriviaDuel {
  const TriviaDuel({
    required this.betId,
    required this.challengerId,
    required this.challengerName,
    required this.stake,
    required this.status,
    required this.acceptDeadline,
    this.opponentId,
    this.opponentName,
    this.invitedId,
    this.invitedName,
    this.playDeadline,
    this.cancelReason,
    this.plays = const [],
  });

  final String betId;
  final String challengerId;
  final String challengerName;
  final String? opponentId;
  final String? opponentName;

  /// Belirli birine meydan okunduysa o kişi; null ise okula açık.
  final String? invitedId;
  final String? invitedName;
  final int stake;

  /// Düellonun bahsinin durumu: open (rakip bekleniyor), locked (oynanıyor), settled, cancelled.
  final String status;
  final DateTime acceptDeadline;
  final DateTime? playDeadline;
  final String? cancelReason;
  final List<DuelPlay> plays;

  DuelPlay? playOf(String? userId) => plays.where((p) => p.playerId == userId).firstOrNull;

  bool isPlayer(String? userId) => userId == challengerId || userId == opponentId;

  bool get finished => status == 'settled' || status == 'cancelled';

  /// Cevaplar yalnızca sonuçlanmış düelloda görünür (iptal olanda değil; sunucu da denetler).
  bool get reviewable => status == 'settled';

  /// Kişi rakip olarak katılabilir mi (sunucu da denetler).
  bool canAccept(String? userId, DateTime now) =>
      userId != null &&
      status == 'open' &&
      opponentId == null &&
      userId != challengerId &&
      (invitedId == null || invitedId == userId) &&
      now.isBefore(acceptDeadline);

  /// Kişi oyunu başlatabilir / sürdürebilir mi.
  bool canPlay(String? userId, DateTime now) {
    if (!isPlayer(userId) || finished || (playOf(userId)?.submitted ?? false)) return false;
    final deadline = playDeadline ?? acceptDeadline;
    return now.isBefore(deadline) || playOf(userId) != null;
  }

  factory TriviaDuel.fromJson(Map<String, dynamic> json) {
    String name(Object? p) => p == null ? '' : '${(p as Map)['first_name']} ${p['last_name']}';
    final bet = json['bet'] as Map<String, dynamic>;
    final playDeadline = json['play_deadline'] as String?;
    return TriviaDuel(
      betId: json['bet_id'] as String,
      challengerId: json['challenger_id'] as String,
      challengerName: name(json['challenger']),
      opponentId: json['opponent_id'] as String?,
      opponentName: json['opponent'] == null ? null : name(json['opponent']),
      invitedId: json['invited_id'] as String?,
      invitedName: json['invited'] == null ? null : name(json['invited']),
      stake: json['stake'] as int,
      status: bet['status'] as String,
      cancelReason: bet['cancel_reason'] as String?,
      acceptDeadline: DateTime.parse(json['accept_deadline'] as String),
      playDeadline: playDeadline == null ? null : DateTime.parse(playDeadline),
      plays: [for (final p in json['trivia_duel_plays'] as List) DuelPlay.fromJson(p as Map<String, dynamic>)],
    );
  }
}

class TriviaQuestion {
  const TriviaQuestion({required this.no, required this.question, required this.options});

  final int no;
  final String question;
  final List<String> options;
}

/// Sunucudan gelen oyun: sorular (doğru cevap yok) ve kalan süre.
class DuelGame {
  const DuelGame({required this.questions, required this.secondsLeft});

  final List<TriviaQuestion> questions;
  final int secondsLeft;
}

/// Okulun düelloları (RLS: kendi okulu).
final triviaDuelsProvider = FutureProvider<List<TriviaDuel>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final schoolId = await mySchoolId(ref);
  var query = ref
      .watch(supabaseProvider)
      .from('trivia_duels')
      .select(
        'bet_id, challenger_id, opponent_id, invited_id, stake, accept_deadline, play_deadline, '
        'bet:bets(status, cancel_reason), challenger:profiles!challenger_id(first_name, last_name), '
        'opponent:profiles!opponent_id(first_name, last_name), invited:profiles!invited_id(first_name, last_name), '
        'trivia_duel_plays(player_id, submitted_at, score)',
      );
  if (schoolId != null) query = query.eq('school_id', schoolId);
  final rows = await query.order('created_at', ascending: false).limit(30);
  return rows.map(TriviaDuel.fromJson).toList();
});

/// `public.start_trivia_duel`: ilk çağrıda süre başlar; tekrar çağrılınca aynı sorular ve kalan süre gelir.
final duelGameProvider = FutureProvider.autoDispose.family<DuelGame, String>((ref, betId) async {
  final rows = await ref.read(supabaseProvider).rpc('start_trivia_duel', params: {'p_bet_id': betId}) as List;
  final questions = [
    for (final r in rows.cast<Map<String, dynamic>>())
      TriviaQuestion(
        no: r['question_no'] as int,
        question: r['question'] as String,
        options: (r['options'] as List).cast<String>(),
      ),
  ];
  return DuelGame(
    questions: questions,
    secondsLeft: rows.isEmpty ? 0 : (rows.first as Map<String, dynamic>)['seconds_left'] as int,
  );
});

/// Düello işleminden sonra: düello listesi ve bahsin etkiledikleri (bakiye, geçmiş, istatistik, görev, XP).
void _refresh(ProviderContainer c) {
  c.invalidate(triviaDuelsProvider);
  refreshAfterBet(c);
}

/// `public.create_trivia_duel`: payın hemen düşer; okula açık ya da [invitedId] verilirse yalnızca o kişiye.
Future<String> createDuel(WidgetRef ref, {required int stake, String? invitedId}) async {
  final c = containerOf(ref);
  final betId = await c
      .read(supabaseProvider)
      .rpc('create_trivia_duel', params: {'p_stake': stake, 'p_invited_id': ?invitedId});
  _refresh(c);
  return betId as String;
}

/// `public.accept_trivia_duel`: aynı tutar yatırılır.
Future<void> acceptDuel(WidgetRef ref, String betId) async {
  final c = containerOf(ref);
  await c.read(supabaseProvider).rpc('accept_trivia_duel', params: {'p_bet_id': betId});
  _refresh(c);
}

/// `public.submit_trivia_answers`: puanı sunucu hesaplar. (puan, geç kaldı mı)
Future<(int, bool)> submitAnswers(WidgetRef ref, String betId, List<int?> answers) async {
  final c = containerOf(ref);
  final row = await c
      .read(supabaseProvider)
      .rpc('submit_trivia_answers', params: {'p_bet_id': betId, 'p_answers': answers})
      .single();
  _refresh(c);
  return (row['score'] as int, row['late'] as bool);
}

/// Bitmiş düellonun bir sorusu: doğru şık, kişinin ve rakibin cevabı (cevapsız: null).
class DuelReviewItem {
  const DuelReviewItem({
    required this.no,
    required this.question,
    required this.options,
    required this.correctIndex,
    this.myAnswer,
    this.opponentAnswer,
  });

  final int no;
  final String question;
  final List<String> options;
  final int correctIndex;
  final int? myAnswer;
  final int? opponentAnswer;

  factory DuelReviewItem.fromJson(Map<String, dynamic> json) => DuelReviewItem(
    no: json['question_no'] as int,
    question: json['question'] as String,
    options: (json['options'] as List).cast<String>(),
    correctIndex: json['correct_index'] as int,
    myAnswer: json['my_answer'] as int?,
    opponentAnswer: json['opponent_answer'] as int?,
  );
}

/// `public.trivia_duel_review`: düello bitince, oynamış oyuncuya sorular ve doğru cevaplar.
final duelReviewProvider = FutureProvider.autoDispose.family<List<DuelReviewItem>, String>((ref, betId) async {
  final rows = await ref.watch(supabaseProvider).rpc('trivia_duel_review', params: {'p_bet_id': betId}) as List;
  return [for (final r in rows) DuelReviewItem.fromJson(r as Map<String, dynamic>)];
});
