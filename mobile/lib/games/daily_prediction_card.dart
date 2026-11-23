import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../bets/bet_option_button.dart';
import '../bets/bets_data.dart';
import '../bets/bets_tab.dart';
import '../core/app_theme.dart';
import '../core/design_tokens.dart';
import '../wallet/wallet_data.dart';

/// Günün tahmini kartı: Evet / Hayır havuzları (arkada pay çubuğu); açıkken seçeneğe dokununca yatırım alt sayfası
/// açılır. Sonucu okul yetkilisi girer; ödeme ve sonuç sunucudan okunur.
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
      margin: const EdgeInsets.only(bottom: Space.md),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BetCardHeader(
              title: bet.title,
              status: betStatusText(bet, open),
              open: open,
              icon: Symbols.lightbulb_rounded,
            ),
            if (bet.description != null) ...[
              const SizedBox(height: Space.sm),
              Text(bet.description!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: Space.md),
            for (final option in bet.options)
              BetOptionButton(
                label: option.label,
                value: '${formatAmount(option.poolAmount)} SP',
                share: bet.poolTotal > 0 ? option.poolAmount / bet.poolTotal : null,
                winner: option.isWinner == true,
                chosen: chosen?.id == option.id,
                onTap: open && wager == null && canBet ? () => showWagerSheet(context, bet, option) : null,
              ),
            Text('Toplam havuz: ${formatAmount(bet.poolTotal)} SP', style: tabular(theme.textTheme.bodySmall)),
            if (wager != null && chosen != null)
              BetResultText(text: wagerText(bet, wager, chosen), won: (wager.payout ?? 0) > wager.amount)
            else if (open && canBet)
              Padding(
                padding: const EdgeInsets.only(top: Space.xs, bottom: Space.sm),
                child: Text('Tahminin için Evet ya da Hayır\'a dokun.', style: theme.textTheme.bodySmall),
              )
            else
              const SizedBox(height: Space.sm),
          ],
        ),
      ),
    );
  }
}
