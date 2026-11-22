import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/error_messages.dart';
import '../core/routes.dart';
import '../profile/student_email_data.dart';
import '../wallet/wallet_data.dart';
import 'bets_data.dart';

/// Bahisler sekmesi: şimdilik okulun resmi SSP bahisleri (sosyal havuz Adım 7'de).
class BetsTab extends ConsumerWidget {
  const BetsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bets = ref.watch(officialBetsProvider);
    final wagers = ref.watch(myWagersProvider).value ?? const <String, Wager>{};
    final verified = ref.watch(studentEmailProvider).value?.verified;
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(officialBetsProvider);
        ref.invalidate(myWagersProvider);
        ref.invalidate(balanceProvider);
        await ref.read(officialBetsProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Resmi bahisler', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Okul etkinliklerine SSP ile oynanır. Oranlar sabittir: kazanırsan yatırdığın × oran kadar SSP alırsın.',
            style: theme.textTheme.bodySmall,
          ),
          if (verified == false) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.mark_email_unread_outlined),
                title: const Text('Bahis için okul mailini doğrula'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.verifyEmail),
              ),
            ),
          ],
          const SizedBox(height: 12),
          switch (bets) {
            AsyncData(value: final list) when list.isEmpty => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('Şu an resmi bahis yok.')),
            ),
            AsyncData(value: final list) => Column(
              children: [
                for (final bet in list) BetCard(bet: bet, wager: wagers[bet.id], canBet: verified == true),
              ],
            ),
            AsyncError(:final error) => Column(
              children: [
                Text('Bahisler alınamadı. ${userMessage(error)}'),
                TextButton(onPressed: () => ref.invalidate(officialBetsProvider), child: const Text('Tekrar dene')),
              ],
            ),
            _ => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
          },
        ],
      ),
    );
  }
}

class BetCard extends StatelessWidget {
  const BetCard({super.key, required this.bet, required this.wager, required this.canBet});

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
              title: Text(bet.title, style: theme.textTheme.titleMedium),
              subtitle: Text(_statusText(bet, open)),
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
                trailing: Text(
                  option.odds == null ? '' : formatOdds(option.odds!),
                  style: theme.textTheme.titleMedium,
                ),
                onTap: open && wager == null && canBet && option.odds != null
                    ? () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => WagerSheet(bet: bet, option: option),
                      )
                    : null,
              ),
            if (wager != null && chosen != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(_wagerText(bet, wager, chosen), style: theme.textTheme.bodyMedium),
              )
            else if (open && canBet)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text('Yatırım yapmak için bir seçeneğe dokun.', style: theme.textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }

  static String _statusText(Bet bet, bool open) => switch (bet.status) {
    _ when open => 'Kapanış: ${formatIstanbul(bet.locksAt)}',
    'open' || 'locked' || 'settling' => 'Yatırımlar kapandı, sonuç bekleniyor',
    'settled' => 'Sonuçlandı',
    'cancelled' => 'İptal edildi${bet.cancelReason == null ? '' : ': ${bet.cancelReason}'}',
    _ => '',
  };

  static String _wagerText(Bet bet, Wager wager, BetOption chosen) {
    final stake = '${formatAmount(wager.amount)} ${bet.currency} · ${chosen.label}'
        '${wager.odds == null ? '' : ' @ ${formatOdds(wager.odds!)}'}';
    return switch ((bet.status, wager.payout)) {
      ('cancelled', _) => 'Yatırımın ($stake) iade edildi.',
      ('settled', final payout?) when payout > 0 => 'Kazandın: +${formatAmount(payout)} ${bet.currency} ($stake)',
      ('settled', _) => 'Kaybettin ($stake).',
      _ when wager.odds != null =>
        'Yatırımın: $stake · Olası kazanç: ${formatAmount(potentialPayout(wager.amount, wager.odds!))} ${bet.currency}',
      _ => 'Yatırımın: $stake',
    };
  }
}

class WagerSheet extends ConsumerStatefulWidget {
  const WagerSheet({super.key, required this.bet, required this.option});

  final Bet bet;
  final BetOption option;

  @override
  ConsumerState<WagerSheet> createState() => _WagerSheetState();
}

class _WagerSheetState extends ConsumerState<WagerSheet> {
  final _amount = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  int? get _value => int.tryParse(_amount.text.trim());

  Future<void> _submit() async {
    final amount = _value;
    final bet = widget.bet;
    if (amount == null || amount < bet.minStake || (bet.maxStake != null && amount > bet.maxStake!)) {
      setState(() => _error = bet.maxStake == null
          ? 'En az ${bet.minStake} ${bet.currency} yatırabilirsin.'
          : '${bet.minStake} ile ${formatAmount(bet.maxStake!)} ${bet.currency} arasında bir tutar gir.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await placeWager(ref, betId: bet.id, optionId: widget.option.id, amount: amount);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text('Yatırım yapıldı: ${formatAmount(amount)} ${bet.currency}')));
    } catch (e) {
      if (mounted) setState(() => _error = userMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bet = widget.bet;
    final odds = widget.option.odds!;
    final amount = _value;
    final balance = ref.watch(balanceProvider).value;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(bet.title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('${widget.option.label} · oran ${formatOdds(odds)}'),
          if (balance != null)
            Text('SSP bakiyen: ${formatAmount(balance.ssp)}', style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            enabled: !_busy,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Yatırılacak ${bet.currency}',
              helperText: bet.maxStake == null ? null : 'En fazla ${formatAmount(bet.maxStake!)}',
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          Text(
            amount == null || amount <= 0
                ? ' '
                : 'Kazanırsan: ${formatAmount(potentialPayout(amount, odds))} ${bet.currency}',
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Yatır'),
          ),
        ],
      ),
    );
  }
}

/// 1.8 → "1,80"
String formatOdds(double odds) => odds.toStringAsFixed(2).replaceAll('.', ',');

/// Tarih İstanbul saatine göre (Türkiye yıl boyu UTC+3): "22.11.2026 20:30".
String formatIstanbul(DateTime time) {
  final t = time.toUtc().add(const Duration(hours: 3));
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(t.day)}.${two(t.month)}.${t.year} ${two(t.hour)}:${two(t.minute)}';
}
