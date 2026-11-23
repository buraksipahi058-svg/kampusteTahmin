import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/error_messages.dart';
import '../core/routes.dart';
import '../core/state_views.dart';
import '../core/supabase.dart';
import '../core/verify_email_card.dart';
import '../market/market_data.dart';
import '../people/people_data.dart';
import '../profile/student_email_data.dart';
import '../wallet/wallet_data.dart';
import 'bets_data.dart';
import 'social_bet_card.dart';

/// Bahisler sekmesi: resmi SSP bahisleri ve öğrencilerin açtığı sosyal havuzlar.
class BetsTab extends ConsumerStatefulWidget {
  const BetsTab({super.key});

  @override
  ConsumerState<BetsTab> createState() => _BetsTabState();
}

class _BetsTabState extends ConsumerState<BetsTab> {
  var _social = false;

  @override
  Widget build(BuildContext context) {
    final bets = ref.watch(_social ? socialBetsProvider : officialBetsProvider);
    final wagers = ref.watch(myWagersProvider).value ?? const <String, Wager>{};
    final disputed = ref.watch(myDisputedBetIdsProvider).value ?? const <String>{};
    final people = _social
        ? cosmeticsKey([
            for (final b in bets.value ?? const <Bet>[]) ...[b.creatorId, b.refereeId],
          ])
        : '';
    final looks = ref.watch(cosmeticsOfProvider(people)).value ?? const <String, Cosmetics>{};
    final verified = ref.watch(studentEmailProvider).value?.verified;
    final userId = ref.watch(currentUserIdProvider);
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(officialBetsProvider);
        ref.invalidate(socialBetsProvider);
        ref.invalidate(myWagersProvider);
        ref.invalidate(myDisputedBetIdsProvider);
        ref.invalidate(balanceProvider);
        await ref.read((_social ? socialBetsProvider : officialBetsProvider).future);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Resmi'), icon: Icon(Icons.emoji_events_outlined)),
              ButtonSegment(value: true, label: Text('Sosyal'), icon: Icon(Icons.groups_outlined)),
            ],
            selected: {_social},
            onSelectionChanged: (s) => setState(() => _social = s.first),
          ),
          const SizedBox(height: 12),
          Text(
            _social
                ? 'Okul arkadaşlarınla SP ile oynanır, oran yoktur: kazananlar havuzu paylaşır. Hakem sonucu girer; '
                      'itiraz edilmezse sonuç kendiliğinden kesinleşir.'
                : 'Okul etkinliklerine SSP ile oynanır. Oranlar sabittir: kazanırsan yatırdığın × oran kadar SSP alırsın.',
            style: theme.textTheme.bodySmall,
          ),
          if (verified == false) ...[
            const SizedBox(height: 12),
            const VerifyEmailCard('Okulundaki bahisleri görmek ve oynamak için okul mailini doğrula'),
          ],
          if (_social && verified == true) ...[
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => context.push(Routes.createSocialBet),
              icon: const Icon(Icons.add),
              label: const Text('Sosyal bahis aç'),
            ),
          ],
          const SizedBox(height: 12),
          switch (bets) {
            // Doğrulanmamış kişiye okulun bahisleri gelmez: "bahis yok" denmez, üstteki kart yeter.
            AsyncData(value: final list) when list.isEmpty && verified == false => const SizedBox.shrink(),
            AsyncData(value: final list) when list.isEmpty => EmptyView(
              text: _social ? 'Henüz sosyal bahis yok.' : 'Şu an resmi bahis yok.',
              icon: _social ? Icons.groups_outlined : Icons.emoji_events_outlined,
            ),
            AsyncData(value: final list) => Column(
              children: [
                for (final bet in list)
                  _social
                      ? SocialBetCard(
                          bet: bet,
                          wager: wagers[bet.id],
                          userId: userId,
                          canBet: verified == true,
                          disputed: disputed.contains(bet.id),
                          looks: looks,
                        )
                      : BetCard(bet: bet, wager: wagers[bet.id], canBet: verified == true),
              ],
            ),
            AsyncError(:final error) => ErrorView(
              what: 'Bahisler alınamadı.',
              error: error,
              onRetry: () => ref.invalidate(_social ? socialBetsProvider : officialBetsProvider),
            ),
            _ => const LoadingView(),
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
                trailing: Text(option.odds == null ? '' : formatOdds(option.odds!), style: theme.textTheme.titleMedium),
                onTap: open && wager == null && canBet && option.odds != null
                    ? () => showWagerSheet(context, bet, option)
                    : null,
              ),
            if (wager != null && chosen != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(wagerText(bet, wager, chosen), style: theme.textTheme.bodyMedium),
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
}

String betStatusText(Bet bet, bool open) => switch (bet.status) {
  _ when open => 'Kapanış: ${formatIstanbul(bet.locksAt)}',
  'settling' =>
    'Hakemin sonucu: ${bet.proposedOption?.label ?? '?'}'
        '${bet.disputeUntil == null ? '' : ' · itiraz süresi sonu: ${formatIstanbul(bet.disputeUntil!)}'}',
  'open' || 'locked' =>
    bet.type == 'sp_social' ? 'Yatırımlar kapandı, hakemin sonucu bekleniyor' : 'Yatırımlar kapandı, sonuç bekleniyor',
  'settled' => 'Sonuçlandı',
  'cancelled' => 'İptal edildi${bet.cancelReason == null ? '' : ': ${bet.cancelReason}'}',
  _ => '',
};

String wagerText(Bet bet, Wager wager, BetOption chosen) {
  final stake =
      '${formatAmount(wager.amount)} ${bet.currency} · ${chosen.label}'
      '${wager.odds == null ? '' : ' @ ${formatOdds(wager.odds!)}'}';
  return switch ((bet.status, wager.payout)) {
    ('cancelled', _) => 'Yatırımın ($stake) iade edildi.',
    // Havuzda kazanan tarafa kimse yatırmadıysa herkese iade yapılır; seçtiğin taraf kazanmadı.
    ('settled', final payout?) when payout > 0 && chosen.isWinner != true =>
      'Kazanan tarafa kimse yatırmadığı için yatırımın ($stake) iade edildi.',
    // Doğru taraf ama kazanç yok (karşı tarafta para yoktu ya da yuvarlama).
    ('settled', final payout?) when payout == wager.amount =>
      'Doğru bildin ama kazanç çıkmadı: yatırımın ($stake) geri döndü.',
    ('settled', final payout?) when payout > 0 =>
      'Kazandın: net +${formatAmount(payout - wager.amount)} ${bet.currency} · '
          '${formatAmount(payout)} ${bet.currency} aldın ($stake)',
    ('settled', _) => 'Kaybettin ($stake).',
    _ when wager.odds != null =>
      'Yatırımın: $stake · Olası kazanç: ${formatAmount(potentialPayout(wager.amount, wager.odds!))} ${bet.currency}',
    _ => 'Yatırımın: $stake',
  };
}

Future<void> showWagerSheet(BuildContext context, Bet bet, BetOption option) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  builder: (_) => WagerSheet(bet: bet, option: option),
);

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
      setState(
        () => _error = bet.maxStake == null
            ? 'En az ${bet.minStake} ${bet.currency} yatırabilirsin.'
            : '${bet.minStake} ile ${formatAmount(bet.maxStake!)} ${bet.currency} arasında bir tutar gir.',
      );
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
    final odds = widget.option.odds;
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
          Text(odds == null ? widget.option.label : '${widget.option.label} · oran ${formatOdds(odds)}'),
          if (balance != null)
            Text(
              '${bet.currency} bakiyen: ${formatAmount(bet.currency == 'SSP' ? balance.ssp : balance.sp)}',
              style: theme.textTheme.bodySmall,
            ),
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
            odds == null
                ? 'Havuz sistemi: kazananlar toplam havuzu yatırdıkları oranda paylaşır.'
                : amount == null || amount <= 0
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
