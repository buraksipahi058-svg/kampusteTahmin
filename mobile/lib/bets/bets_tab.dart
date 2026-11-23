import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/app_theme.dart';
import '../core/design_tokens.dart';
import '../core/error_messages.dart';
import '../core/haptics.dart';
import '../core/routes.dart';
import '../core/state_views.dart';
import '../core/supabase.dart';
import '../core/verify_email_card.dart';
import '../market/market_data.dart';
import '../people/people_data.dart';
import '../profile/student_email_data.dart';
import '../wallet/wallet_data.dart';
import 'bet_option_button.dart';
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
              ButtonSegment(value: false, label: Text('Resmi'), icon: Icon(Symbols.emoji_events_rounded)),
              ButtonSegment(value: true, label: Text('Sosyal'), icon: Icon(Symbols.groups_rounded)),
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
              icon: const Icon(Symbols.add_rounded),
              label: const Text('Sosyal bahis aç'),
            ),
          ],
          const SizedBox(height: 12),
          switch (bets) {
            // Doğrulanmamış kişiye okulun bahisleri gelmez: "bahis yok" denmez, üstteki kart yeter.
            AsyncData(value: final list) when list.isEmpty && verified == false => const SizedBox.shrink(),
            AsyncData(value: final list) when list.isEmpty => EmptyView(
              text: _social ? 'Henüz sosyal bahis yok.' : 'Şu an resmi bahis yok.',
              icon: _social ? Symbols.groups_rounded : Symbols.emoji_events_rounded,
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
      margin: const EdgeInsets.only(bottom: Space.md),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BetCardHeader(title: bet.title, status: betStatusText(bet, open), open: open),
            if (bet.description != null) ...[
              const SizedBox(height: Space.sm),
              Text(bet.description!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: Space.md),
            for (final option in bet.options)
              BetOptionButton(
                label: option.label,
                value: option.odds == null ? '' : formatOdds(option.odds!),
                winner: option.isWinner == true,
                chosen: chosen?.id == option.id,
                onTap: open && wager == null && canBet && option.odds != null
                    ? () => showWagerSheet(context, bet, option)
                    : null,
              ),
            if (wager != null && chosen != null)
              BetResultText(text: wagerText(bet, wager, chosen), won: (wager.payout ?? 0) > wager.amount)
            else if (open && canBet)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: Text('Yatırım yapmak için bir seçeneğe dokun.', style: theme.textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bahis kartı başlığı: başlık, altında durum (açıkken vurgulu renkte, saat simgeli).
class BetCardHeader extends StatelessWidget {
  const BetCardHeader({super.key, required this.title, required this.status, required this.open, this.icon});

  final String title;
  final String status;
  final bool open;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = open ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[Icon(icon, color: theme.colorScheme.primary), const SizedBox(width: Space.md)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              if (status.isNotEmpty) ...[
                const SizedBox(height: Space.xs),
                Row(
                  children: [
                    Icon(open ? Symbols.schedule_rounded : Symbols.lock_clock_rounded, size: 14, color: statusColor),
                    const SizedBox(width: Space.xs),
                    Flexible(
                      child: Text(status, style: theme.textTheme.bodySmall?.copyWith(color: statusColor)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Kişinin yatırımının sonucu / durumu; kazandıysa yeşil ve kalın.
class BetResultText extends StatelessWidget {
  const BetResultText({super.key, required this.text, this.won = false});

  final String text;
  final bool won;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Space.xs, bottom: Space.sm),
      child: Text(
        text,
        style: won
            ? theme.textTheme.bodyMedium?.copyWith(color: context.appColors.success, fontWeight: FontWeight.w600)
            : theme.textTheme.bodyMedium,
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
      Haptics.light();
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
    final current = balance == null ? null : (bet.currency == 'SSP' ? balance.ssp : balance.sp);
    // Hızlı tutarlar: en az / en fazla tutar ve bakiye içinde kalanlar.
    final quick = [10, 25, 50, 100]
        .where(
          (v) => v >= bet.minStake && (bet.maxStake == null || v <= bet.maxStake!) && (current == null || v <= current),
        )
        .toList();

    return Padding(
      // Üstte tema tutamağı var; üst boşluk ona bırakılır.
      padding: EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(bet.title, style: theme.textTheme.titleMedium),
          const SizedBox(height: Space.xs),
          Text(
            odds == null ? widget.option.label : '${widget.option.label} · oran ${formatOdds(odds)}',
            style: tabular(
              theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
            ),
          ),
          if (current != null)
            Text('${bet.currency} bakiyen: ${formatAmount(current)}', style: tabular(theme.textTheme.bodySmall)),
          const SizedBox(height: Space.lg),
          TextField(
            controller: _amount,
            enabled: !_busy,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Yatırılacak ${bet.currency}',
              helperText: bet.maxStake == null ? null : 'En fazla ${formatAmount(bet.maxStake!)}',
            ),
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _submit(),
          ),
          if (quick.isNotEmpty) ...[
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.sm,
              children: [
                for (final v in quick)
                  ActionChip(
                    label: Text('$v ${bet.currency}'),
                    onPressed: _busy
                        ? null
                        : () {
                            Haptics.selection();
                            _amount.text = '$v';
                            _amount.selection = TextSelection.collapsed(offset: _amount.text.length);
                            setState(() => _error = null);
                          },
                  ),
              ],
            ),
          ],
          const SizedBox(height: Space.md),
          Text(
            odds == null
                ? 'Havuz sistemi: kazananlar toplam havuzu yatırdıkları oranda paylaşır.'
                : amount == null || amount <= 0
                ? ' '
                : 'Kazanırsan: ${formatAmount(potentialPayout(amount, odds))} ${bet.currency}',
            style: odds == null
                ? theme.textTheme.bodySmall
                : tabular(theme.textTheme.titleSmall?.copyWith(color: context.appColors.success)),
          ),
          if (_error != null) ...[
            const SizedBox(height: Space.sm),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: Space.lg),
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
