import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../achievements/achievements_data.dart';
import '../bets/bets_tab.dart' show formatIstanbul;
import '../core/app_theme.dart';
import '../core/design_tokens.dart';
import '../core/routes.dart';
import '../core/state_views.dart';
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
                leading: const Icon(Symbols.visibility_off_rounded),
                title: const Text('Sıralamalarda gizlisin'),
                subtitle: const Text("Okul arkadaşların seni görmez. Profil > Gizlilik'ten açabilirsin."),
              ),
            ),
          const SizedBox(height: 8),
          switch (rows) {
            AsyncData(:final value) when value.isEmpty => const EmptyView(
              text: 'Bu dönemde henüz sıralamaya giren yok.',
              icon: Symbols.leaderboard_rounded,
            ),
            AsyncData(:final value) => _Board(rows: value, metric: query.metric),
            AsyncError(:final error) when error is PostgrestException && error.code == 'KB002' => const VerifyEmailCard(
              'Okulundaki sıralamayı görmek için okul mailini doğrula',
            ),
            AsyncError(:final error) => ErrorView(
              what: 'Sıralama alınamadı.',
              error: error,
              onRetry: () => ref.invalidate(leaderboardProvider),
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
              child: Center(child: Icon(Symbols.more_horiz_rounded)),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = [
      'Sv. ${row.level}',
      if (row.title != null) [?row.titleIcon, row.title!].join(' '),
      leaderboardDetailText(metric, row),
    ].join(' · ');
    return Card(
      // Kendi satırın: renkli zemin + çerçeve; ilk üç altın / gümüş / bronz sıra rozetli.
      color: row.isMe ? theme.colorScheme.secondaryContainer : null,
      shape: row.isMe
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.lg),
              side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
            )
          : null,
      child: ListTile(
        onTap: () => context.push(Routes.person(row.userId)),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RankBadge(rank: row.rank),
            const SizedBox(width: 8),
            ProfileAvatar(initials: row.initials, frameColor: row.frameColor, radius: 18),
          ],
        ),
        title: Text(
          [row.displayName, ?row.badge, if (row.isMe) '(sen)'].join(' '),
          style: theme.textTheme.titleMedium?.copyWith(color: readableNameColor(context, row.nameColor)),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(subtitle, overflow: TextOverflow.ellipsis),
        trailing: Text(
          leaderboardValueText(metric, row),
          style: tabular(theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

/// Sıra: ilk üç altın / gümüş / bronz dolu daire içinde numara, diğerleri sade numara (sabit genişlik).
class RankBadge extends StatelessWidget {
  const RankBadge({super.key, required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (rank) {
      1 => tierColor(3),
      2 => tierColor(2),
      3 => tierColor(1),
      _ => null,
    };
    if (color == null) {
      return SizedBox(
        width: 32,
        child: Text('$rank.', style: tabular(theme.textTheme.titleMedium), textAlign: TextAlign.center),
      );
    }
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(color, Colors.white, 0.25)!, color],
        ),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Text(
        '$rank',
        style: tabular(theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
    );
  }
}
