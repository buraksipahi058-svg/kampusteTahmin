import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase.dart';
import '../leaderboard/leaderboard_data.dart';
import '../notifications/notifications_data.dart';
import '../profile/profile_data.dart';
import '../progress/progress_data.dart';
import '../quests/quests_data.dart';
import '../wallet/wallet_data.dart';

class BetOption {
  const BetOption({required this.id, required this.label, required this.position, this.odds, this.poolAmount = 0, this.isWinner});

  final String id;
  final String label;
  final int position;

  /// Sabit oranlı bahiste seçeneğin oranı (ör. 1.80); havuz bahsinde null.
  final double? odds;
  final int poolAmount;

  /// Sonuçlanınca belirlenir; öncesinde null.
  final bool? isWinner;

  factory BetOption.fromJson(Map<String, dynamic> json) => BetOption(
    id: json['id'] as String,
    label: json['label'] as String,
    position: json['position'] as int,
    odds: (json['odds'] as num?)?.toDouble(),
    poolAmount: json['pool_amount'] as int,
    isWinner: json['is_winner'] as bool?,
  );
}

class Bet {
  const Bet({
    required this.id,
    required this.title,
    required this.status,
    required this.locksAt,
    required this.currency,
    required this.options,
    this.type = 'ssp_official',
    this.settlementMode = 'admin',
    this.description,
    this.minStake = 1,
    this.maxStake,
    this.poolTotal = 0,
    this.cancelReason,
    this.creatorId,
    this.creatorName,
    this.refereeId,
    this.refereeName,
    this.proposedOptionId,
    this.disputeUntil,
  });

  final String id;

  /// ssp_official, sp_social, sp_minigame
  final String type;

  /// admin (resmi, günün tahmini), auto (düello), referee (sosyal)
  final String settlementMode;
  final String title;
  final String? description;

  /// open, locked, settling, settled, cancelled
  final String status;
  final DateTime locksAt;
  final String currency;
  final int minStake;
  final int? maxStake;
  final int poolTotal;
  final String? cancelReason;
  final List<BetOption> options;

  // Sosyal bahis: hakem, hakemin girdiği sonuç ve itiraz süresi.
  final String? creatorId;
  final String? creatorName;
  final String? refereeId;
  final String? refereeName;
  final String? proposedOptionId;
  final DateTime? disputeUntil;

  /// Yatırım alıyor mu (sunucu da aynı kuralı denetler).
  bool acceptsWagers(DateTime now) => status == 'open' && now.isBefore(locksAt);

  /// Hakemin sonucuna şu an itiraz edilebilir mi.
  bool inDisputeWindow(DateTime now) => status == 'settling' && disputeUntil != null && now.isBefore(disputeUntil!);

  BetOption? get proposedOption => options.where((o) => o.id == proposedOptionId).firstOrNull;

  factory Bet.fromJson(Map<String, dynamic> json) {
    final referee = json['referee'] as Map<String, dynamic>?;
    final creator = json['creator'] as Map<String, dynamic>?;
    final disputeUntil = json['dispute_until'] as String?;
    return Bet(
      id: json['id'] as String,
      type: json['type'] as String,
      settlementMode: json['settlement_mode'] as String? ?? 'admin',
      title: json['title'] as String,
      description: json['description'] as String?,
      status: json['status'] as String,
      locksAt: DateTime.parse(json['locks_at'] as String),
      currency: json['currency'] as String,
      minStake: json['min_stake'] as int,
      maxStake: json['max_stake'] as int?,
      poolTotal: json['pool_total'] as int,
      cancelReason: json['cancel_reason'] as String?,
      creatorId: json['creator_id'] as String?,
      creatorName: creator == null ? null : '${creator['first_name']} ${creator['last_name']}',
      refereeId: json['referee_id'] as String?,
      refereeName: referee == null ? null : '${referee['first_name']} ${referee['last_name']}',
      proposedOptionId: json['proposed_option_id'] as String?,
      disputeUntil: disputeUntil == null ? null : DateTime.parse(disputeUntil),
      options: [for (final o in json['bet_options'] as List) BetOption.fromJson(o as Map<String, dynamic>)]
        ..sort((a, b) => a.position.compareTo(b.position)),
    );
  }
}

class Wager {
  const Wager({
    required this.betId,
    required this.optionId,
    required this.amount,
    this.odds,
    this.payout,
    this.createdAt,
  });

  final String betId;
  final String optionId;
  final int amount;
  final double? odds;

  /// Sonuçlanınca ya da iptalde yazılır (kaybeden 0, iade = yatırılan).
  final int? payout;

  /// Yatırım zamanı (yalnızca geçmiş sorgusu çeker).
  final DateTime? createdAt;

  factory Wager.fromJson(Map<String, dynamic> json) => Wager(
    betId: json['bet_id'] as String,
    optionId: json['option_id'] as String,
    amount: json['amount'] as int,
    odds: (json['odds'] as num?)?.toDouble(),
    payout: json['payout'] as int?,
    createdAt: json['created_at'] == null ? null : DateTime.parse(json['created_at'] as String),
  );
}

/// Sunucudaki sabit oran ödemesiyle aynı: floor(yatırım × oran). Yalnızca bilgi için gösterilir.
int potentialPayout(int amount, double odds) => (amount * odds).floor();

const _betColumns =
    'id, type, settlement_mode, title, description, status, locks_at, currency, min_stake, max_stake, pool_total, cancel_reason, '
    'creator_id, referee_id, proposed_option_id, dispute_until, referee:profiles!referee_id(first_name, last_name), '
    'creator:profiles!creator_id(first_name, last_name), '
    'bet_options(id, label, position, odds, pool_amount, is_winner)';

// RLS: yalnızca kişinin kümelerindeki bahisler görünür; ayrıca kişinin okulu (v1'de bahisler okul kümesinde).
Future<List<Bet>> _fetchBets(Ref ref, String type) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final schoolId = await mySchoolId(ref);
  var query = ref.watch(supabaseProvider).from('bets').select(_betColumns).eq('type', type);
  if (schoolId != null) query = query.eq('cluster_id', schoolId);
  final rows = await query
      .order('created_at', ascending: false)
      .limit(30);
  return rows.map(Bet.fromJson).toList();
}

final officialBetsProvider = FutureProvider<List<Bet>>((ref) => _fetchBets(ref, 'ssp_official'));
final socialBetsProvider = FutureProvider<List<Bet>>((ref) => _fetchBets(ref, 'sp_social'));

/// Günün tahmini: sonucunu okul yetkilisinin girdiği mini oyun (`sp_minigame` + `settlement_mode = admin`).
/// Yatırım genel `place_wager` ile; havuz sistemi, seçenekler Evet / Hayır.
final dailyPredictionsProvider = FutureProvider<List<Bet>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final schoolId = await mySchoolId(ref);
  var query = ref
      .watch(supabaseProvider)
      .from('bets')
      .select(_betColumns)
      .eq('type', 'sp_minigame')
      .eq('settlement_mode', 'admin');
  if (schoolId != null) query = query.eq('cluster_id', schoolId);
  final rows = await query
      .order('locks_at', ascending: false)
      .limit(10);
  return rows.map(Bet.fromJson).toList();
});

/// Kişinin kendi yatırımları, bahis kimliğine göre (RLS: yalnızca kendi yatırımları görünür).
final myWagersProvider = FutureProvider<Map<String, Wager>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const {};
  final rows = await ref
      .watch(supabaseProvider)
      .from('wagers')
      .select('bet_id, option_id, amount, odds, payout')
      .eq('user_id', userId);
  return {for (final w in rows.map(Wager.fromJson)) w.betId: w};
});

/// Kişinin itiraz ettiği bahisler.
final myDisputedBetIdsProvider = FutureProvider<Set<String>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const {};
  final rows = await ref.watch(supabaseProvider).from('bet_disputes').select('bet_id').eq('raised_by', userId);
  return {for (final r in rows) r['bet_id'] as String};
});

typedef WagerEntry = ({Bet bet, Wager wager});

/// Geçmişte gösterilecek yatırım sayısı; "Daha fazla göster" sayfa boyu kadar artırır.
class HistoryLimit extends Notifier<int> {
  static const pageSize = 30;

  @override
  int build() => pageSize;

  void more() => state += pageSize;
}

final historyLimitProvider = NotifierProvider<HistoryLimit, int>(HistoryLimit.new);

/// Kişinin yatırımları bahsiyle birlikte, en yeni önce (Profil > Geçmiş bahislerim). Sınırdan bir fazlası
/// istenir: liste sınırdan uzunsa "Daha fazla göster" çıkar.
final myWagerHistoryProvider = FutureProvider<List<WagerEntry>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final limit = ref.watch(historyLimitProvider);
  final rows = await ref
      .watch(supabaseProvider)
      .from('wagers')
      .select('bet_id, option_id, amount, odds, payout, created_at, bet:bets!bet_id($_betColumns)')
      .eq('user_id', userId)
      .order('created_at', ascending: false)
      .limit(limit + 1);
  return [
    for (final r in rows)
      if (r['bet'] != null) (bet: Bet.fromJson(r['bet'] as Map<String, dynamic>), wager: Wager.fromJson(r)),
  ];
});

/// Kişinin açtığı ya da hakemi olduğu sosyal bahisler, en yeni önce (geçmişte; yatırım yapmasa da).
final myOwnSocialBetsProvider = FutureProvider<List<Bet>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final rows = await ref
      .watch(supabaseProvider)
      .from('bets')
      .select(_betColumns)
      .eq('type', 'sp_social')
      .or('creator_id.eq.$userId,referee_id.eq.$userId')
      .order('created_at', ascending: false)
      .limit(50);
  return rows.map(Bet.fromJson).toList();
});

/// Bahis / düello işleminden sonra: bakiye, kartlar, geçmiş, istatistik, görev ilerlemesi, XP.
void refreshAfterBet(ProviderContainer c) {
  c.invalidate(officialBetsProvider);
  c.invalidate(socialBetsProvider);
  c.invalidate(dailyPredictionsProvider);
  c.invalidate(myWagersProvider);
  c.invalidate(myDisputedBetIdsProvider);
  c.invalidate(myWagerHistoryProvider);
  c.invalidate(myOwnSocialBetsProvider);
  // Sonuçlanma, itiraz, düello olayları bildirim üretir.
  c.invalidate(unreadNotificationsProvider);
  c.invalidate(myStatsProvider);
  c.invalidate(questsProvider);
  c.invalidate(balanceProvider);
  refreshProgress(c);
}

/// `public.place_wager`: bakiye, sınırlar ve kurallar sunucuda denetlenir.
Future<void> placeWager(WidgetRef ref, {required String betId, required String optionId, required int amount}) async {
  final c = containerOf(ref);
  await c.read(supabaseProvider).rpc(
    'place_wager',
    params: {'p_bet_id': betId, 'p_option_id': optionId, 'p_amount': amount},
  );
  refreshAfterBet(c);
}

/// `public.create_social_bet`: hakem sensin; kişi başı sınır ayardaki üst sınırı aşamaz.
Future<void> createSocialBet(
  WidgetRef ref, {
  required String clusterId,
  required String title,
  required String description,
  required List<String> options,
  required DateTime locksAt,
  int? maxStake,
  String? refereeId,
}) async {
  final c = containerOf(ref);
  await c.read(supabaseProvider).rpc(
    'create_social_bet',
    params: {
      'p_cluster_id': clusterId,
      'p_title': title,
      'p_description': description,
      'p_options': options,
      'p_locks_at': locksAt.toUtc().toIso8601String(),
      'p_max_stake': ?maxStake,
      'p_referee_id': ?refereeId,
    },
  );
  refreshAfterBet(c);
}

/// `public.submit_social_result`: yalnızca hakem; itiraz süresinin bitişini döner.
Future<DateTime> submitSocialResult(WidgetRef ref, {required String betId, required String optionId}) async {
  final c = containerOf(ref);
  final until = await c.read(supabaseProvider).rpc(
    'submit_social_result',
    params: {'p_bet_id': betId, 'p_option_id': optionId},
  );
  refreshAfterBet(c);
  return DateTime.parse(until as String);
}

/// `public.dispute_social_result`: yalnızca yatırım yapanlar, itiraz süresi içinde.
Future<void> disputeSocialResult(WidgetRef ref, {required String betId, required String reason}) async {
  final c = containerOf(ref);
  await c.read(supabaseProvider).rpc('dispute_social_result', params: {'p_bet_id': betId, 'p_reason': reason});
  refreshAfterBet(c);
}

/// `public.cancel_social_bet`: açan, henüz kimse yatırmamışken geri çekebilir.
Future<void> cancelSocialBet(WidgetRef ref, {required String betId, required String reason}) async {
  final c = containerOf(ref);
  await c.read(supabaseProvider).rpc('cancel_social_bet', params: {'p_bet_id': betId, 'p_reason': reason});
  refreshAfterBet(c);
}
