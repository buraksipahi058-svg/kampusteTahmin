import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bets/bets_data.dart';
import '../bets/bets_tab.dart' show formatIstanbul, wagerText;
import '../core/state_views.dart';
import '../core/supabase.dart';
import '../wallet/wallet_data.dart';

/// `/gecmis`: "Yatırımlarım" (en yeni önce, 30'ar sayfa; sonuç metni bahis kartlarıyla aynı) ve
/// "Açtıklarım" (kişinin açtığı ya da hakemi olduğu sosyal bahisler, yatırım yapmasa da).
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  var _own = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Geçmiş bahislerim')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Yatırımlarım')),
                ButtonSegment(value: true, label: Text('Açtıklarım')),
              ],
              selected: {_own},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _own = s.first),
            ),
          ),
          Expanded(child: _own ? const _OwnBets() : const _Wagers()),
        ],
      ),
    );
  }
}

class _Wagers extends ConsumerWidget {
  const _Wagers();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(myWagerHistoryProvider);
    final limit = ref.watch(historyLimitProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myWagerHistoryProvider);
        await ref.read(myWagerHistoryProvider.future);
      },
      child: switch (history) {
        AsyncData(:final value) when value.isEmpty => ListView(
          children: const [EmptyView(text: 'Henüz bir bahse katılmadın.', icon: Icons.history)],
        ),
        AsyncData(:final value) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final entry in value.take(limit)) _EntryCard(entry: entry),
            if (value.length > limit)
              TextButton(
                onPressed: () => ref.read(historyLimitProvider.notifier).more(),
                child: const Text('Daha fazla göster'),
              ),
          ],
        ),
        AsyncError(:final error) => ListView(
          children: [
            ErrorView(what: 'Geçmiş alınamadı.', error: error, onRetry: () => ref.invalidate(myWagerHistoryProvider)),
          ],
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _OwnBets extends ConsumerWidget {
  const _OwnBets();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myOwnSocialBetsProvider);
        await ref.read(myOwnSocialBetsProvider.future);
      },
      child: switch (ref.watch(myOwnSocialBetsProvider)) {
        AsyncData(:final value) when value.isEmpty => ListView(
          children: const [
            EmptyView(text: 'Açtığın ya da hakemi olduğun sosyal bahis yok.', icon: Icons.groups_outlined),
          ],
        ),
        AsyncData(:final value) => ListView(
          padding: const EdgeInsets.all(16),
          children: [for (final bet in value) _OwnBetCard(bet: bet, userId: userId)],
        ),
        AsyncError(:final error) => ListView(
          children: [
            ErrorView(
              what: 'Bahisler alınamadı.',
              error: error,
              onRetry: () => ref.invalidate(myOwnSocialBetsProvider),
            ),
          ],
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// Açılan / hakemlik yapılan sosyal bahis: rol, durum, sonuç (kazanan seçenek ya da iptal gerekçesi), havuz.
class _OwnBetCard extends StatelessWidget {
  const _OwnBetCard({required this.bet, required this.userId});

  final Bet bet;
  final String? userId;

  @override
  Widget build(BuildContext context) {
    final roles = [if (bet.creatorId == userId) 'Açtın', if (bet.refereeId == userId) 'Hakemsin'].join(', ');
    final winner = bet.options.where((o) => o.isWinner == true).firstOrNull;
    final result = switch (bet.status) {
      'settled' when winner != null => 'Sonuç: ${winner.label}',
      'cancelled' => 'İptal: ${bet.cancelReason ?? '-'}',
      _ => null,
    };
    return Card(
      child: ListTile(
        title: Text(bet.title),
        subtitle: Text(
          [
            [roles, _statusLabel(bet), 'Havuz ${formatAmount(bet.poolTotal)} SP'].join(' · '),
            ?result,
          ].join('\n'),
        ),
        isThreeLine: result != null,
      ),
    );
  }
}

/// Bahsin türü (kısa etiket).
String betKindLabel(Bet bet) => switch (bet.type) {
  'ssp_official' => 'Resmi',
  'sp_social' => 'Sosyal',
  _ => bet.settlementMode == 'auto' ? 'Düello' : 'Günün tahmini',
};

String _statusLabel(Bet bet) => switch (bet.status) {
  'settled' => 'Sonuçlandı',
  'cancelled' => 'İptal',
  'settling' => 'Sonuç girildi, itiraz süresi',
  'locked' => 'Kapandı, sonuç bekleniyor',
  // Durum "open" kalsa da kapanış geçtiyse yatırıma kapalıdır.
  _ when !DateTime.now().isBefore(bet.locksAt) => 'Kapandı, sonuç bekleniyor',
  _ => 'Açık',
};

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final WagerEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bet = entry.bet;
    final chosen = bet.options.where((o) => o.id == entry.wager.optionId).firstOrNull;
    return Card(
      child: ListTile(
        title: Text(bet.title),
        subtitle: Text(
          [
            [
              betKindLabel(bet),
              _statusLabel(bet),
              if (entry.wager.createdAt != null) formatIstanbul(entry.wager.createdAt!),
            ].join(' · '),
            if (chosen != null) wagerText(bet, entry.wager, chosen),
          ].join('\n'),
        ),
        isThreeLine: chosen != null,
        trailing: switch ((bet.status, chosen?.isWinner)) {
          ('settled', true) => Icon(Icons.check_circle, color: theme.colorScheme.primary),
          ('settled', _) => Icon(Icons.cancel_outlined, color: theme.colorScheme.error),
          _ => null,
        },
      ),
    );
  }
}
