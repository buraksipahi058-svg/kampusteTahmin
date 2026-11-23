import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/error_messages.dart';
import '../wallet/wallet_data.dart';
import 'leaderboard_data.dart';

/// Profil'deki istatistik kartı (sunucudan; tüm zamanlar, bu haftanın sırasıyla).
class MyStatsCard extends ConsumerWidget {
  const MyStatsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(myStatsProvider);
    final theme = Theme.of(context);
    final valueStyle = theme.textTheme.titleMedium;

    return Card(
      child: switch (stats) {
        AsyncData(value: final s?) => Column(
          children: [
            ListTile(
              leading: const Icon(Symbols.insights_rounded),
              title: const Text('İstatistiklerim'),
              subtitle: Text(_weekRanks(s)),
            ),
            ListTile(
              dense: true,
              title: const Text('İsabet'),
              subtitle: const Text('Sonuçlanan tahminler (düellolar hariç)'),
              trailing: Text(
                s.hitRate == null ? '–' : '${formatPercent(s.hitRate!)} · ${s.correct}/${s.predictions}',
                style: valueStyle,
              ),
            ),
            ListTile(
              dense: true,
              title: const Text('Doğru tahmin serisi'),
              subtitle: Text('En iyi: ${s.bestStreak}'),
              trailing: Text('${s.currentStreak}', style: valueStyle),
            ),
            ListTile(
              dense: true,
              title: const Text('Net kazanç'),
              subtitle: const Text('Kazanılan − yatırılan'),
              trailing: Text(
                [
                  '${signedAmount(s.spProfit)} SP',
                  if (s.sspProfit != 0) '${signedAmount(s.sspProfit)} SSP',
                ].join(' · '),
                style: valueStyle,
              ),
            ),
            ListTile(
              dense: true,
              title: const Text('Düello'),
              trailing: Text('${s.duelsPlayed} oyun · ${s.duelsWon} galibiyet', style: valueStyle),
            ),
            if (s.openWagers > 0)
              ListTile(
                dense: true,
                title: const Text('Sonucu bekleyen yatırım'),
                trailing: Text(formatAmount(s.openWagers), style: valueStyle),
              ),
          ],
        ),
        AsyncError(:final error) => ListTile(
          leading: const Icon(Symbols.insights_rounded),
          title: const Text('İstatistikler alınamadı'),
          subtitle: Text(userMessage(error)),
          trailing: IconButton(
            icon: const Icon(Symbols.refresh_rounded),
            onPressed: () => ref.invalidate(myStatsProvider),
          ),
        ),
        _ => const ListTile(leading: Icon(Symbols.insights_rounded), title: Text('İstatistiklerim')),
      },
    );
  }

  static String _weekRanks(MyStats s) {
    final ranks = [
      if (s.weekRankHitRate != null) 'isabette ${s.weekRankHitRate}.',
      if (s.weekRankSpProfit != null) 'kazançta ${s.weekRankSpProfit}.',
      if (s.weekRankBestStreak != null) 'seride ${s.weekRankBestStreak}.',
    ];
    return ranks.isEmpty ? 'Bu hafta henüz sıralamada değilsin' : 'Bu hafta ${ranks.join(', ')}';
  }
}
