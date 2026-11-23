import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../bets/bets_tab.dart' show formatIstanbul;
import '../core/async_button.dart';
import '../core/error_messages.dart';
import '../core/haptics.dart';
import '../core/state_views.dart';
import '../wallet/wallet_data.dart';
import 'achievement_badge.dart';
import 'achievements_data.dart';

/// `/basarimlar`: kazanılan / toplam, hazır ödüller üstte, sonra kategoriler. Her kartta kademe (bronz /
/// gümüş / altın), ilerleme, ödül ve okulunda kazananların oranı; gizli başarım kazanılana dek "???".
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Başarımlar')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(achievementsProvider);
          await ref.read(achievementsProvider.future);
        },
        child: switch (ref.watch(achievementsProvider)) {
          AsyncData(:final value) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Summary(list: value),
              const SizedBox(height: 16),
              if (value.any((a) => a.claimable)) ...[
                Text('Ödülün hazır', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final a in value.where((a) => a.claimable)) AchievementCard(achievement: a),
                const SizedBox(height: 8),
              ],
              for (final category in achievementCategories.entries)
                if (value.any((a) => a.category == category.key && !a.claimable)) ...[
                  Text(category.value, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final a in value.where((a) => a.category == category.key && !a.claimable))
                    AchievementCard(achievement: a),
                  const SizedBox(height: 8),
                ],
            ],
          ),
          AsyncError(:final error) => ListView(
            children: [
              ErrorView(
                what: 'Başarımlar alınamadı.',
                error: error,
                onRetry: () => ref.invalidate(achievementsProvider),
              ),
            ],
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.list});

  final List<Achievement> list;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = list.where((a) => a.unlocked).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$done / ${list.length} başarım', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: list.isEmpty ? 0 : done / list.length, minHeight: 8),
            const SizedBox(height: 8),
            Text(
              [
                for (final t in [3, 2, 1]) '${tierLabel(t)} ${list.where((a) => a.unlocked && a.tier == t).length}',
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class AchievementCard extends ConsumerWidget {
  const AchievementCard({super.key, required this.achievement});

  final Achievement achievement;

  Future<void> _claim(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = await claimAchievement(ref, achievement.key);
      Haptics.success();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${achievement.icon} ${achievement.title} açıldı: +${formatAmount(r.sp)} SP'
            '${r.xp > 0 ? ' · +${r.xp} XP' : ''}',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(userMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final a = achievement;
    final faded = !a.unlocked && !a.claimable;
    final rate = (a.schoolRate * 100).round();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AchievementBadge(
              tier: a.tier,
              achievementKey: a.key,
              category: a.category,
              earned: !faded,
              masked: a.masked,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(a.title, style: theme.textTheme.titleSmall)),
                      const SizedBox(width: 6),
                      Text(
                        tierLabel(a.tier),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: tierColor(a.tier),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Text(a.description, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 6),
                  if (!a.unlocked && !a.masked) ...[
                    LinearProgressIndicator(value: a.target == 0 ? 0 : a.progress / a.target, minHeight: 6),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    [
                      if (!a.unlocked && !a.masked) '${formatAmount(a.progress)} / ${formatAmount(a.target)}',
                      '+${formatAmount(a.rewardSp)} SP${a.rewardXp > 0 ? ' · +${a.rewardXp} XP' : ''}',
                      'okulda kazanan %$rate',
                      if (a.unlockedAt != null) formatIstanbul(a.unlockedAt!),
                    ].join(' · '),
                    style: theme.textTheme.labelSmall,
                  ),
                  if (a.claimable) ...[
                    const SizedBox(height: 8),
                    AsyncButton(onPressed: () => _claim(context, ref), child: const Text('Ödülü al')),
                  ],
                ],
              ),
            ),
            if (a.unlocked) Icon(Symbols.verified_rounded, fill: 1, color: tierColor(a.tier)),
          ],
        ),
      ),
    );
  }
}
