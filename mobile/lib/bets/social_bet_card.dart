import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/error_messages.dart';
import '../wallet/wallet_data.dart';
import 'bets_data.dart';
import 'bets_tab.dart';

/// Sosyal havuz bahsi: havuz miktarları, hakem; duruma göre yatır / sonucu gir / itiraz et / geri çek.
/// Kuralların hepsini sunucu denetler; burada yalnızca uygun düğme gösterilir.
class SocialBetCard extends ConsumerWidget {
  const SocialBetCard({
    super.key,
    required this.bet,
    required this.wager,
    required this.userId,
    required this.canBet,
    required this.disputed,
  });

  final Bet bet;
  final Wager? wager;
  final String? userId;
  final bool canBet;

  /// Kişi bu bahsin sonucuna itiraz etti mi.
  final bool disputed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final open = bet.acceptsWagers(now);
    final isReferee = bet.refereeId == userId;
    final wager = this.wager;
    final chosen = wager == null ? null : bet.options.where((o) => o.id == wager.optionId).firstOrNull;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: Text(bet.title, style: theme.textTheme.titleMedium),
              subtitle: Text(
                '${betStatusText(bet, open)}\n'
                'Hakem: ${isReferee ? 'sen' : (bet.refereeName ?? '?')} · Havuz: ${formatAmount(bet.poolTotal)} SP',
              ),
              isThreeLine: true,
            ),
            if (bet.description != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(bet.description!, style: theme.textTheme.bodySmall),
              ),
            for (final option in bet.options)
              ListTile(
                dense: true,
                leading: option.isWinner == true
                    ? Icon(Icons.emoji_events, color: theme.colorScheme.primary)
                    : bet.status == 'settling' && option.id == bet.proposedOptionId
                    ? const Icon(Icons.gavel)
                    : null,
                title: Text(option.label),
                trailing: Text('${formatAmount(option.poolAmount)} SP'),
                onTap: open && wager == null && canBet && !isReferee ? () => showWagerSheet(context, bet, option) : null,
              ),
            if (wager != null && chosen != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Text(wagerText(bet, wager, chosen)),
              )
            else if (open && canBet && !isReferee)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text('Yatırım yapmak için bir seçeneğe dokun.', style: theme.textTheme.bodySmall),
              ),
            if (disputed && bet.status == 'settling')
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Text('İtirazın moderatöre iletildi; karar verilene kadar ödeme yapılmaz.'),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                children: [
                  if (isReferee && (bet.status == 'open' || bet.status == 'locked'))
                    FilledButton(onPressed: () => _submitResult(context, ref), child: const Text('Sonucu gir')),
                  if (wager != null && !disputed && bet.inDisputeWindow(now))
                    OutlinedButton(onPressed: () => _dispute(context, ref), child: const Text('İtiraz et')),
                  if (bet.creatorId == userId && bet.status == 'open' && bet.poolTotal == 0)
                    TextButton(onPressed: () => _withdraw(context, ref), child: const Text('Geri çek')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _run(BuildContext context, Future<void> Function() action, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(userMessage(e))));
    }
  }

  Future<void> _submitResult(BuildContext context, WidgetRef ref) async {
    final optionId = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Sonuç ne oldu?'),
        children: [
          for (final o in bet.options)
            SimpleDialogOption(onPressed: () => Navigator.pop(context, o.id), child: Text(o.label)),
        ],
      ),
    );
    if (optionId == null || !context.mounted) return;
    await _run(
      context,
      () => submitSocialResult(ref, betId: bet.id, optionId: optionId),
      'Sonuç girildi. İtiraz gelmezse süre bitince kesinleşir.',
    );
  }

  Future<void> _dispute(BuildContext context, WidgetRef ref) async {
    final reason = await showDialog<String>(context: context, builder: (_) => const _ReasonDialog());
    if (reason == null || !context.mounted) return;
    await _run(context, () => disputeSocialResult(ref, betId: bet.id, reason: reason), 'İtirazın iletildi.');
  }

  Future<void> _withdraw(BuildContext context, WidgetRef ref) async {
    await _run(context, () => cancelSocialBet(ref, betId: bet.id, reason: 'Açan geri çekti'), 'Bahis geri çekildi.');
  }
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog();

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hakemin sonucuna itiraz'),
      content: TextField(
        controller: _reason,
        autofocus: true,
        maxLength: 500,
        maxLines: 3,
        decoration: InputDecoration(labelText: 'Neden yanlış?', errorText: _error),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(
          onPressed: () {
            final text = _reason.text.trim();
            if (text.length < 3) {
              setState(() => _error = 'En az 3 karakter yaz.');
              return;
            }
            Navigator.pop(context, text);
          },
          child: const Text('İtiraz et'),
        ),
      ],
    );
  }
}
