import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../bets/bets_tab.dart' show formatIstanbul;
import '../core/error_messages.dart';
import '../core/routes.dart';
import '../core/verify_email_card.dart';
import '../market/cosmetic_preview.dart';
import '../profile/privacy_data.dart';
import 'leaderboard_data.dart';

/// Liderlik sekmesi: okulun haftalık ve tüm zamanlar sıralaması. Beceri ölçütleri öne çıkar
/// (isabet, net kazanç, doğru tahmin serisi); "en çok bahis yapan" sıralaması yok (MIMARI §11).
class LeaderboardTab extends ConsumerWidget {
  const LeaderboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(leaderboardQueryProvider);
    final rows = ref.watch(leaderboardProvider);
    final minimums = ref.watch(leaderboardMinimumsProvider).value;
    final hidden = ref.watch(leaderboardHiddenProvider).value ?? false;
    final notifier = ref.read(leaderboardQueryProvider.notifier);
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(leaderboardProvider);
        await ref.read(leaderboardProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<LeaderboardPeriod>(
            segments: [for (final p in LeaderboardPeriod.values) ButtonSegment(value: p, label: Text(p.label))],
            selected: {query.period},
            showSelectedIcon: false,
            onSelectionChanged: (s) => notifier.select(period: s.first),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final m in LeaderboardMetric.values)
                ChoiceChip(
                  label: Text(m.label),
                  selected: query.metric == m,
                  onSelected: (_) => notifier.select(metric: m),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(_explanation(query, minimums), style: theme.textTheme.bodySmall),
          if (hidden)
            Card(
              margin: const EdgeInsets.only(top: 8),
              child: ListTile(
                leading: const Icon(Icons.visibility_off_outlined),
                title: const Text('Sıralamalarda gizlisin'),
                subtitle: const Text("Okul arkadaşların seni görmez. Profil > Gizlilik'ten açabilirsin."),
              ),
            ),
          const SizedBox(height: 8),
          switch (rows) {
            AsyncData(:final value) when value.isEmpty => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('Bu dönemde henüz sıralamaya giren yok.')),
            ),
            AsyncData(:final value) => _Board(rows: value, metric: query.metric),
            AsyncError(:final error) when error is PostgrestException && error.code == 'KB002' =>
              const VerifyEmailCard('Okulundaki sıralamayı görmek için okul mailini doğrula'),
            AsyncError(:final error) => Column(
              children: [
                Text('Sıralama alınamadı. ${userMessage(error)}'),
                TextButton(onPressed: () => ref.invalidate(leaderboardProvider), child: const Text('Tekrar dene')),
              ],
            ),
            _ => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          },
        ],
      ),
    );
  }

  static String _explanation(LeaderboardQuery query, ({int week, int allTime})? minimums) {
    final min = minimums == null
        ? null
        : (query.period == LeaderboardPeriod.allTime ? minimums.allTime : minimums.week);
    return switch (query.metric) {
      LeaderboardMetric.hitRate =>
        'Sonuçlanan tahminlerinde doğru bilme oranı${min == null ? '' : '; en az $min tahmin gerekir'}. '
            'Düellolar sayılmaz.',
      LeaderboardMetric.spProfit => 'Sonuçlanan bahis ve düellolardaki net SP kazancı (kazanılan − yatırılan).',
      LeaderboardMetric.bestStreak => 'Art arda doğru bildiğin en uzun tahmin serisi. Düellolar sayılmaz.',
      LeaderboardMetric.sspProfit => 'Resmi bahislerdeki net SSP kazancı.',
    };
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.rows, required this.metric});

  final List<LeaderboardRow> rows;
  final LeaderboardMetric metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final computedAt = rows.first.computedAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          // Kendi satırın ilk 50'nin dışındaysa listenin sonuna eklenir.
          if (i > 0 && rows[i].rank > rows[i - 1].rank + 1 && rows[i].isMe)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Center(child: Text('⋯')),
            ),
          _RowTile(row: rows[i], metric: metric),
        ],
        if (computedAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Son hesaplama: ${formatIstanbul(computedAt)} · 10 dakikada bir yenilenir',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.row, required this.metric});

  final LeaderboardRow row;
  final LeaderboardMetric metric;

  static const _medals = {1: '🥇', 2: '🥈', 3: '🥉'};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = [
      'Sv. ${row.level}',
      if (row.title != null) [?row.titleIcon, row.title!].join(' '),
      leaderboardDetailText(metric, row),
    ].join(' · ');
    return Card(
      color: row.isMe ? theme.colorScheme.secondaryContainer : null,
      child: ListTile(
        onTap: () => context.push(Routes.person(row.userId)),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              child: Text(
                _medals[row.rank] ?? '${row.rank}.',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),
            ProfileAvatar(initials: row.initials, frameColor: row.frameColor, radius: 18),
          ],
        ),
        title: Text(
          [row.displayName, ?row.badge, if (row.isMe) '(sen)'].join(' '),
          style: theme.textTheme.titleMedium?.copyWith(color: row.nameColor),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(subtitle, overflow: TextOverflow.ellipsis),
        trailing: Text(leaderboardValueText(metric, row), style: theme.textTheme.titleMedium),
      ),
    );
  }
}
