import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase.dart';
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
    this.description,
    this.minStake = 1,
    this.maxStake,
    this.cancelReason,
  });

  final String id;
  final String title;
  final String? description;

  /// open, locked, settling, settled, cancelled
  final String status;
  final DateTime locksAt;
  final String currency;
  final int minStake;
  final int? maxStake;
  final String? cancelReason;
  final List<BetOption> options;

  /// Yatırım alıyor mu (sunucu da aynı kuralı denetler).
  bool acceptsWagers(DateTime now) => status == 'open' && now.isBefore(locksAt);

  factory Bet.fromJson(Map<String, dynamic> json) => Bet(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    status: json['status'] as String,
    locksAt: DateTime.parse(json['locks_at'] as String),
    currency: json['currency'] as String,
    minStake: json['min_stake'] as int,
    maxStake: json['max_stake'] as int?,
    cancelReason: json['cancel_reason'] as String?,
    options: [for (final o in json['bet_options'] as List) BetOption.fromJson(o as Map<String, dynamic>)]
      ..sort((a, b) => a.position.compareTo(b.position)),
  );
}

class Wager {
  const Wager({required this.betId, required this.optionId, required this.amount, this.odds, this.payout});

  final String betId;
  final String optionId;
  final int amount;
  final double? odds;

  /// Sonuçlanınca ya da iptalde yazılır (kaybeden 0, iade = yatırılan).
  final int? payout;

  factory Wager.fromJson(Map<String, dynamic> json) => Wager(
    betId: json['bet_id'] as String,
    optionId: json['option_id'] as String,
    amount: json['amount'] as int,
    odds: (json['odds'] as num?)?.toDouble(),
    payout: json['payout'] as int?,
  );
}

/// Sunucudaki sabit oran ödemesiyle aynı: floor(yatırım × oran). Yalnızca bilgi için gösterilir.
int potentialPayout(int amount, double odds) => (amount * odds).floor();

/// Okulun resmi bahisleri (RLS: yalnızca kişinin kümelerindeki bahisler görünür).
final officialBetsProvider = FutureProvider<List<Bet>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final rows = await ref
      .watch(supabaseProvider)
      .from('bets')
      .select(
        'id, title, description, status, locks_at, currency, min_stake, max_stake, cancel_reason, '
        'bet_options(id, label, position, odds, pool_amount, is_winner)',
      )
      .eq('type', 'ssp_official')
      .order('created_at', ascending: false)
      .limit(30);
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

/// `public.place_wager`: bakiye, sınırlar ve kurallar sunucuda denetlenir.
Future<void> placeWager(WidgetRef ref, {required String betId, required String optionId, required int amount}) async {
  await ref.read(supabaseProvider).rpc(
    'place_wager',
    params: {'p_bet_id': betId, 'p_option_id': optionId, 'p_amount': amount},
  );
  ref.invalidate(officialBetsProvider);
  ref.invalidate(myWagersProvider);
  ref.invalidate(balanceProvider);
}
