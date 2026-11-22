import 'package:flutter/material.dart';

import '../bets/bets_data.dart';
import '../bets/bets_tab.dart';
import '../wallet/wallet_data.dart';

/// Günün tahmini kartı: Evet / Hayır havuzları; açıkken seçeneğe dokununca yatırım alt sayfası açılır.
/// Sonucu okul yetkilisi girer; ödeme ve sonuç sunucudan okunur.
class DailyPredictionCard extends StatelessWidget {
  const DailyPredictionCard({super.key, required this.bet, required this.wager, required this.canBet});

  final Bet bet;
  final Wager? wager;
  final bool canBet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final open = bet.acceptsWagers(DateTime.now());
    final wager = this.wager;
    final chosen = wager == null ? null : bet.options.where((o) => o.id == wager.optionId).firstOrNull;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: const Icon(Icons.lightbulb_outline),
              title: Text(bet.title, style: theme.textTheme.titleMedium),
              subtitle: Text(betStatusText(bet, open)),
            ),
            if (bet.description != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(bet.description!, style: theme.textTheme.bodySmall),
              ),
            for (final option in bet.options)
              ListTile(
                dense: true,
                leading: option.isWinner == true ? Icon(Icons.emoji_events, color: theme.colorScheme.primary) : null,
                title: Text(option.label),
                trailing: Text('${formatAmount(option.poolAmount)} SP', style: theme.textTheme.titleSmall),
                onTap: open && wager == null && canBet ? () => showWagerSheet(context, bet, option) : null,
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Toplam havuz: ${formatAmount(bet.poolTotal)} SP', style: theme.textTheme.bodySmall),
            ),
            if (wager != null && chosen != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(wagerText(bet, wager, chosen), style: theme.textTheme.bodyMedium),
              )
            else if (open && canBet)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text('Tahminin için Evet ya da Hayır\'a dokun.', style: theme.textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}
