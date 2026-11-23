import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase.dart';
import '../market/market_data.dart';
import '../wallet/wallet_data.dart';

/// Sıralama ölçütleri (sunucudaki `leaderboard_metric`). Bahis sayısı bilerek yok (MIMARI §11).
enum LeaderboardMetric {
  hitRate('hit_rate', 'İsabet'),
  spProfit('sp_profit', 'Kazanç'),
  bestStreak('best_streak', 'Seri'),
  sspProfit('ssp_profit', 'SSP');

  const LeaderboardMetric(this.key, this.label);

  final String key;
  final String label;
}

enum LeaderboardPeriod {
  thisWeek('week', 0, 'Bu hafta'),
  lastWeek('week', 1, 'Geçen hafta'),
  allTime('all_time', 0, 'Tüm zamanlar');

  const LeaderboardPeriod(this.key, this.weeksAgo, this.label);

  final String key;
  final int weeksAgo;
  final String label;
}

typedef LeaderboardQuery = ({LeaderboardMetric metric, LeaderboardPeriod period});

class LeaderboardRow {
  const LeaderboardRow({
    required this.rank,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.value,
    required this.sample,
    this.isMe = false,
    this.title,
    this.titleIcon,
    this.badge,
    this.frameColor,
    this.nameColor,
    this.computedAt,
    this.level = 1,
  });

  final int rank;
  final String userId;
  final String firstName;
  final String lastName;

  /// İsabette 0–1 oran, kazançta net tutar, seride art arda doğru sayısı.
  final double value;

  /// Sonuçlanmış tahmin (isabet, seri) ya da yatırım (kazanç) sayısı.
  final int sample;
  final bool isMe;
  final String? title;
  final String? titleIcon;
  final String? badge;
  final Color? frameColor;
  final Color? nameColor;
  final DateTime? computedAt;
  final int level;

  /// Sıralamada soyadının yalnızca baş harfi gösterilir.
  String get displayName => lastName.isEmpty ? firstName : '$firstName ${lastName.substring(0, 1)}.';

  String get initials => [firstName, lastName].where((s) => s.isNotEmpty).map((s) => s.substring(0, 1)).join();

  factory LeaderboardRow.fromJson(Map<String, dynamic> json) {
    final computedAt = json['computed_at'] as String?;
    return LeaderboardRow(
      rank: json['rank'] as int,
      userId: json['user_id'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      value: (json['value'] as num).toDouble(),
      sample: json['sample'] as int,
      isMe: json['is_me'] as bool? ?? false,
      title: json['title'] as String?,
      titleIcon: json['title_icon'] as String?,
      badge: json['badge'] as String?,
      frameColor: hexColor(json['frame_color'] as String?),
      nameColor: hexColor(json['name_color'] as String?),
      computedAt: computedAt == null ? null : DateTime.parse(computedAt),
      level: json['level'] as int? ?? 1,
    );
  }
}

/// Seçili ölçüt ve dönem (sekmeler arasında gezinince korunur).
class LeaderboardQueryNotifier extends Notifier<LeaderboardQuery> {
  @override
  LeaderboardQuery build() => (metric: LeaderboardMetric.hitRate, period: LeaderboardPeriod.thisWeek);

  void select({LeaderboardMetric? metric, LeaderboardPeriod? period}) =>
      state = (metric: metric ?? state.metric, period: period ?? state.period);
}

final leaderboardQueryProvider = NotifierProvider<LeaderboardQueryNotifier, LeaderboardQuery>(
  LeaderboardQueryNotifier.new,
);

/// `public.get_leaderboard`: kendi okulun; ilk 50 + (listede değilsen) kendi satırın.
final leaderboardProvider = FutureProvider<List<LeaderboardRow>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final query = ref.watch(leaderboardQueryProvider);
  final rows =
      await ref
              .watch(supabaseProvider)
              .rpc(
                'get_leaderboard',
                params: {
                  'p_metric': query.metric.key,
                  'p_period': query.period.key,
                  'p_weeks_ago': query.period.weeksAgo,
                },
              )
          as List;
  return rows.cast<Map<String, dynamic>>().map(LeaderboardRow.fromJson).toList();
});

/// İsabet sıralamasına girmek için gereken en az tahmin (ekonomi ayarları herkese açık).
final leaderboardMinimumsProvider = FutureProvider<({int week, int allTime})>((ref) async {
  final row = await ref
      .watch(supabaseProvider)
      .from('economy_settings')
      .select('leaderboard_min_predictions_week, leaderboard_min_predictions_all')
      .single();
  return (week: row['leaderboard_min_predictions_week'] as int, allTime: row['leaderboard_min_predictions_all'] as int);
});

String formatPercent(double rate) => '%${(rate * 100).round()}';

/// Sıralamadaki değerin metni.
String leaderboardValueText(LeaderboardMetric metric, LeaderboardRow row) => metricValueText(metric, row.value);

/// Ölçüt değeri (liderlik satırı ve başkasının profili ortak).
String metricValueText(LeaderboardMetric metric, double value) => switch (metric) {
  LeaderboardMetric.hitRate => formatPercent(value),
  LeaderboardMetric.spProfit => '+${formatAmount(value.round())} SP',
  LeaderboardMetric.sspProfit => '+${formatAmount(value.round())} SSP',
  LeaderboardMetric.bestStreak => '${value.round()} üst üste',
};

/// Değerin altındaki ayrıntı.
String leaderboardDetailText(LeaderboardMetric metric, LeaderboardRow row) =>
    metricDetailText(metric, row.value, row.sample);

String metricDetailText(LeaderboardMetric metric, double value, int sample) => switch (metric) {
  LeaderboardMetric.hitRate => '${(value * sample).round()}/$sample doğru',
  LeaderboardMetric.bestStreak => '$sample tahmin',
  _ => '$sample bahis',
};

/// Kişinin kendi istatistikleri (`public.my_stats`, tüm zamanlar; sıralar bu haftanın son hesaplamasından).
class MyStats {
  const MyStats({
    this.predictions = 0,
    this.correct = 0,
    this.spProfit = 0,
    this.sspProfit = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.duelsPlayed = 0,
    this.duelsWon = 0,
    this.openWagers = 0,
    this.weekRankHitRate,
    this.weekRankSpProfit,
    this.weekRankBestStreak,
  });

  final int predictions;
  final int correct;
  final int spProfit;
  final int sspProfit;
  final int currentStreak;
  final int bestStreak;
  final int duelsPlayed;
  final int duelsWon;
  final int openWagers;
  final int? weekRankHitRate;
  final int? weekRankSpProfit;
  final int? weekRankBestStreak;

  double? get hitRate => predictions == 0 ? null : correct / predictions;

  factory MyStats.fromJson(Map<String, dynamic> json) => MyStats(
    predictions: json['predictions'] as int,
    correct: json['correct'] as int,
    spProfit: json['sp_profit'] as int,
    sspProfit: json['ssp_profit'] as int,
    currentStreak: json['current_streak'] as int,
    bestStreak: json['best_streak'] as int,
    duelsPlayed: json['duels_played'] as int,
    duelsWon: json['duels_won'] as int,
    openWagers: json['open_wagers'] as int,
    weekRankHitRate: json['week_rank_hit_rate'] as int?,
    weekRankSpProfit: json['week_rank_sp_profit'] as int?,
    weekRankBestStreak: json['week_rank_best_streak'] as int?,
  );
}

final myStatsProvider = FutureProvider<MyStats?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  final rows = await ref.watch(supabaseProvider).rpc('my_stats') as List;
  return rows.isEmpty ? null : MyStats.fromJson(rows.first as Map<String, dynamic>);
});

/// Artı / eksi işaretli tutar.
String signedAmount(int value) => value > 0 ? '+${formatAmount(value)}' : formatAmount(value);
