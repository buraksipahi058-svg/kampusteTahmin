import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase.dart';
import '../progress/progress_data.dart';
import '../wallet/wallet_data.dart';

// Görev ilerlemesi ve ödül sunucuda hesaplanır (`my_quests`, `claim_quest_reward`); istemci yalnızca gösterir.

const questPeriodLabels = {'daily': 'Günlük', 'weekly': 'Haftalık', 'seasonal': 'Sezonluk'};

class Quest {
  const Quest({
    required this.id,
    required this.title,
    required this.period,
    required this.action,
    required this.target,
    required this.rewardCurrency,
    required this.rewardAmount,
    required this.progress,
    required this.claimed,
    required this.periodEndsAt,
    this.description,
    this.rewardXp = 0,
  });

  final String id;
  final String title;
  final String? description;

  /// daily, weekly, seasonal
  final String period;

  /// wager, prediction, duel, social_bet, win
  final String action;
  final int target;
  final String rewardCurrency;
  final int rewardAmount;

  /// Ödülle birlikte verilen XP (0 olabilir).
  final int rewardXp;

  /// Bu dönemdeki ilerleme (hedefle sınırlı).
  final int progress;

  /// Bu dönemin ödülü alındı mı.
  final bool claimed;
  final DateTime periodEndsAt;

  bool get claimable => !claimed && progress >= target;

  factory Quest.fromJson(Map<String, dynamic> json) => Quest(
    id: json['quest_id'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    period: json['period'] as String,
    action: json['action'] as String,
    target: json['target'] as int,
    rewardCurrency: json['reward_currency'] as String,
    rewardAmount: json['reward_amount'] as int,
    rewardXp: json['reward_xp'] as int? ?? 0,
    progress: json['progress'] as int,
    claimed: json['claimed'] as bool,
    periodEndsAt: DateTime.parse(json['period_ends_at'] as String),
  );
}

final questsProvider = FutureProvider<List<Quest>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final rows = await ref.watch(supabaseProvider).rpc('my_quests') as List;
  return [for (final r in rows) Quest.fromJson(r as Map<String, dynamic>)];
});

/// `public.claim_quest_reward`: tamamlanan görevin ödülü (dönem başına bir kez).
Future<({String currency, int amount})> claimQuest(WidgetRef ref, String questId) async {
  final c = containerOf(ref);
  final rows = await c.read(supabaseProvider).rpc('claim_quest_reward', params: {'p_quest_id': questId}) as List;
  c.invalidate(questsProvider);
  c.invalidate(balanceProvider);
  refreshProgress(c);
  final row = rows.first as Map<String, dynamic>;
  return (currency: row['reward_currency'] as String, amount: row['reward_amount'] as int);
}
