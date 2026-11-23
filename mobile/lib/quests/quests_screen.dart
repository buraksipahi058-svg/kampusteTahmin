import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../bets/bets_tab.dart';
import '../core/async_button.dart';
import '../core/error_messages.dart';
import '../core/state_views.dart';
import '../wallet/wallet_data.dart';
import 'quests_data.dart';

/// `/gorevler`: günlük, haftalık ve sezonluk görevler; ilerleme ve ödül sunucudan.
class QuestsScreen extends ConsumerWidget {
  const QuestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quests = ref.watch(questsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Görevler')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(questsProvider);
          await ref.read(questsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Görevi tamamlayınca ödülünü buradan al. Günlük görevler her gece yarısı, haftalık görevler '
              'pazartesi yenilenir.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            switch (quests) {
              AsyncData(value: final list) when list.isEmpty => const EmptyView(
                text: 'Şu an görev yok.',
                icon: Symbols.flag_rounded,
              ),
              AsyncData(value: final list) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final period in questPeriodLabels.keys)
                    if (list.any((q) => q.period == period)) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Text(questPeriodLabels[period]!, style: theme.textTheme.titleMedium),
                      ),
                      for (final quest in list.where((q) => q.period == period)) QuestCard(quest: quest),
                    ],
                ],
              ),
              AsyncError(:final error) => ErrorView(
                what: 'Görevler alınamadı.',
                error: error,
                onRetry: () => ref.invalidate(questsProvider),
              ),
              _ => const LoadingView(),
            },
          ],
        ),
      ),
    );
  }
}

class QuestCard extends ConsumerWidget {
  const QuestCard({super.key, required this.quest});

  final Quest quest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reward = [
      '+${formatAmount(quest.rewardAmount)} ${quest.rewardCurrency}',
      if (quest.rewardXp > 0) '+${quest.rewardXp} XP',
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(quest.title, style: theme.textTheme.titleSmall)),
                Text(reward, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
              ],
            ),
            if (quest.description != null) ...[
              const SizedBox(height: 2),
              Text(quest.description!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: LinearProgressIndicator(value: quest.progress / quest.target)),
                const SizedBox(width: 12),
                Text('${quest.progress}/${quest.target}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    quest.period == 'seasonal'
                        ? 'Bitiş: ${formatIstanbul(quest.periodEndsAt)}'
                        : 'Yenilenir: ${formatIstanbul(quest.periodEndsAt)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                if (quest.claimed)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Symbols.check_circle_rounded, size: 18, fill: 1, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      const Text('Alındı'),
                    ],
                  )
                else if (quest.claimable)
                  AsyncButton(onPressed: () => _claim(context, ref), child: const Text('Ödülü al')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _claim(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = await claimQuest(ref, quest.id);
      final xp = quest.rewardXp > 0 ? ' · +${quest.rewardXp} XP' : '';
      messenger.showSnackBar(SnackBar(content: Text('Ödül alındı: +${formatAmount(r.amount)} ${r.currency}$xp')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(userMessage(e))));
    }
  }
}
