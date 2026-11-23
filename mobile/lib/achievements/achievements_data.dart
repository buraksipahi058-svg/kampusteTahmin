import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase.dart';
import '../progress/progress_data.dart';
import '../wallet/wallet_data.dart';

/// Başarım (`public.my_achievements`): ilerleme sunucuda kayıtlardan hesaplanır. Gizli başarımın adı ve
/// açıklaması kazanılana dek sunucudan gelmez ("Gizli başarım").
class Achievement {
  const Achievement({
    required this.key,
    required this.category,
    required this.title,
    required this.description,
    required this.icon,
    required this.tier,
    required this.target,
    required this.progress,
    required this.rewardSp,
    required this.rewardXp,
    this.hidden = false,
    this.unlockedAt,
    this.claimable = false,
    this.schoolRate = 0,
  });

  final String key;
  final String category;
  final String title;
  final String description;
  final String icon;

  /// 1 bronz, 2 gümüş, 3 altın.
  final int tier;
  final int target;
  final int progress;
  final int rewardSp;
  final int rewardXp;
  final bool hidden;
  final DateTime? unlockedAt;

  /// Hedefe ulaşıldı, ödül alınmadı.
  final bool claimable;

  /// Okulunda bu başarımı açanların oranı (0–1).
  final double schoolRate;

  bool get unlocked => unlockedAt != null;

  /// Gizli ve henüz kazanılmadı: ilerleme gösterilmez.
  bool get masked => hidden && !unlocked && !claimable;

  factory Achievement.fromJson(Map<String, dynamic> json) {
    final unlockedAt = json['unlocked_at'] as String?;
    return Achievement(
      key: json['key'] as String,
      category: json['category'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String,
      tier: json['tier'] as int,
      target: json['target'] as int,
      progress: json['progress'] as int,
      rewardSp: json['reward_sp'] as int,
      rewardXp: json['reward_xp'] as int,
      hidden: json['hidden'] as bool,
      unlockedAt: unlockedAt == null ? null : DateTime.parse(unlockedAt),
      claimable: json['claimable'] as bool,
      schoolRate: (json['school_rate'] as num).toDouble(),
    );
  }
}

/// Kademe adı ve rengi (bronz / gümüş / altın).
String tierLabel(int tier) => switch (tier) {
  3 => 'Altın',
  2 => 'Gümüş',
  _ => 'Bronz',
};

Color tierColor(int tier) => switch (tier) {
  3 => const Color(0xFFD4A017),
  2 => const Color(0xFF9E9E9E),
  _ => const Color(0xFFB0703C),
};

/// Kategori başlıkları, ekrandaki sırayla.
const achievementCategories = {
  'progress': 'Başlangıç ve ilerleme',
  'prediction': 'Tahmin',
  'streak': 'Seri',
  'duel': 'Düello',
  'social': 'Sosyal',
  'loyalty': 'Sadakat',
  'secret': 'Gizli',
};

final achievementsProvider = FutureProvider<List<Achievement>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final rows = await ref.watch(supabaseProvider).rpc('my_achievements') as List;
  return [for (final r in rows) Achievement.fromJson(r as Map<String, dynamic>)];
});

/// `public.claim_achievement`: ödül SP + XP (XP ledger kaydından gelir). (SP, XP) döner.
Future<({int sp, int xp})> claimAchievement(WidgetRef ref, String key) async {
  final c = containerOf(ref);
  final row = await c.read(supabaseProvider).rpc('claim_achievement', params: {'p_key': key}).single();
  c.invalidate(balanceProvider);
  refreshProgress(c);
  return (sp: row['reward_sp'] as int, xp: row['reward_xp'] as int);
}
