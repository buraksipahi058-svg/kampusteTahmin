import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bets/bets_data.dart';
import '../bets/bets_tab.dart' show wagerText;
import '../core/error_messages.dart';

/// `/gecmis`: kişinin yatırımları (son 100), en yeni önce; sonuç metni bahis kartlarıyla aynı.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(myWagerHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Geçmiş bahislerim')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myWagerHistoryProvider);
          await ref.read(myWagerHistoryProvider.future);
        },
        child: switch (history) {
          AsyncData(:final value) when value.isEmpty => ListView(
            children: const [
              Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('Henüz bir bahse katılmadın.')),
              ),
            ],
          ),
          AsyncData(:final value) => ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: value.length,
            itemBuilder: (_, i) => _EntryCard(entry: value[i]),
          ),
          AsyncError(:final error) => ListView(
            padding: const EdgeInsets.all(32),
            children: [
              Text('Geçmiş alınamadı. ${userMessage(error)}', textAlign: TextAlign.center),
              TextButton(onPressed: () => ref.invalidate(myWagerHistoryProvider), child: const Text('Tekrar dene')),
            ],
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
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
            '${betKindLabel(bet)} · ${_statusLabel(bet)}',
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
