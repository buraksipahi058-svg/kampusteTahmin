import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../bets/bets_data.dart';
import '../core/error_messages.dart';
import '../core/routes.dart';
import '../core/supabase.dart';
import '../profile/student_email_data.dart';
import '../wallet/wallet_data.dart';
import 'daily_prediction_card.dart';
import 'trivia_data.dart';

/// Oyunlar sekmesi: günün tahmini ve trivia düellosu.
/// Günün tahmini: okul yetkilisinin açtığı Evet / Hayır sorusu, SP havuzu kazananlara paylaşılır.
/// Düello: iki kişi eşit SP yatırır, aynı soruları çözer; çok doğru yapan (eşitlikte hızlı olan) havuzu
/// alır. Puanı ve süreyi sunucu hesaplar.
class GamesTab extends ConsumerWidget {
  const GamesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duels = ref.watch(triviaDuelsProvider);
    final predictions = ref.watch(dailyPredictionsProvider);
    final wagers = ref.watch(myWagersProvider).value ?? const <String, Wager>{};
    final verified = ref.watch(studentEmailProvider).value?.verified;
    final userId = ref.watch(currentUserIdProvider);
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(triviaDuelsProvider);
        ref.invalidate(dailyPredictionsProvider);
        ref.invalidate(myWagersProvider);
        ref.invalidate(balanceProvider);
        await ref.read(triviaDuelsProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Günün tahmini', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            "Evet ya da Hayır'a SP yatır; doğru tahmin edenler havuzu yatırdıkları oranda paylaşır. "
            'Sonucu okul yetkilisi girer.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          switch (predictions) {
            AsyncData(value: final list) when list.isEmpty => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text('Şu an tahmin sorusu yok.')),
            ),
            AsyncData(value: final list) => Column(
              children: [
                for (final bet in list) DailyPredictionCard(bet: bet, wager: wagers[bet.id], canBet: verified == true),
              ],
            ),
            AsyncError(:final error) => Column(
              children: [
                Text('Tahminler alınamadı. ${userMessage(error)}'),
                TextButton(onPressed: () => ref.invalidate(dailyPredictionsProvider), child: const Text('Tekrar dene')),
              ],
            ),
            _ => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
          },
          const SizedBox(height: 24),
          Text('Trivia düellosu', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Okulundan biriyle aynı soruları çöz. İkiniz de aynı SP\'yi yatırırsınız; çok doğru yapan, '
            'eşitlikte daha hızlı olan havuzu alır. Soru başına 15 saniye.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (verified == true)
            FilledButton.icon(
              onPressed: () => _challenge(context, ref),
              icon: const Icon(Icons.sports_kabaddi),
              label: const Text('Meydan oku'),
            )
          else if (verified == false)
            Card(
              child: ListTile(
                leading: const Icon(Icons.mark_email_unread_outlined),
                title: const Text('Düello için okul mailini doğrula'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.verifyEmail),
              ),
            ),
          const SizedBox(height: 12),
          switch (duels) {
            AsyncData(value: final list) when list.isEmpty => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('Henüz düello yok. İlk meydan okuyan sen ol.')),
            ),
            AsyncData(value: final list) => Column(
              children: [
                for (final duel in list) DuelCard(duel: duel, userId: userId, canJoin: verified == true),
              ],
            ),
            AsyncError(:final error) => Column(
              children: [
                Text('Düellolar alınamadı. ${userMessage(error)}'),
                TextButton(onPressed: () => ref.invalidate(triviaDuelsProvider), child: const Text('Tekrar dene')),
              ],
            ),
            _ => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
          },
        ],
      ),
    );
  }

  Future<void> _challenge(BuildContext context, WidgetRef ref) async {
    final stake = await showDialog<int>(context: context, builder: (_) => const _StakeDialog());
    if (stake == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final betId = await createDuel(ref, stake: stake);
      if (context.mounted) context.push(Routes.duelPlay(betId));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(userMessage(e))));
    }
  }
}

class DuelCard extends ConsumerWidget {
  const DuelCard({super.key, required this.duel, required this.userId, required this.canJoin});

  final TriviaDuel duel;
  final String? userId;
  final bool canJoin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final mine = duel.isPlayer(userId);
    final wager = ref.watch(myWagersProvider).value?[duel.betId];
    final opponent = duel.opponentName ?? (duel.invitedId == null ? 'herkese açık' : 'davetli bekleniyor');
    final myPlay = duel.playOf(userId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: const Icon(Icons.quiz_outlined),
              title: Text('${duel.challengerName} vs $opponent'),
              subtitle: Text('${formatAmount(duel.stake)} SP · ${_statusText(duel, userId, wager)}'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                children: [
                  if (canJoin && duel.canAccept(userId, now))
                    FilledButton(onPressed: () => _accept(context, ref), child: Text('Kabul et (${formatAmount(duel.stake)} SP)')),
                  if (mine && duel.canPlay(userId, now))
                    FilledButton.tonal(
                      onPressed: () => context.push(Routes.duelPlay(duel.betId)),
                      child: Text(myPlay == null ? 'Oyna' : 'Oyuna dön'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Kazanan istemcide hesaplanmaz: sunucunun kişinin yatırımına yazdığı ödemeden okunur.
  static String _statusText(TriviaDuel duel, String? userId, Wager? wager) {
    final me = duel.playOf(userId);
    final other = duel.plays.where((p) => p.playerId != userId).firstOrNull;
    switch (duel.status) {
      case 'cancelled':
        return duel.cancelReason ?? 'İptal edildi';
      case 'settled':
        if (!duel.isPlayer(userId)) return 'Sonuçlandı';
        final score = 'skor ${me?.score ?? 0} - ${other?.score ?? 0}';
        final payout = wager?.payout ?? 0;
        final stake = wager?.amount ?? duel.stake;
        return payout > 0 ? 'Kazandın: net +${formatAmount(payout - stake)} SP · $score' : 'Kaybettin · $score';
      default:
        if (me?.submitted ?? false) return 'Skorun ${me!.score}; rakibin oynaması bekleniyor';
        if (duel.opponentId == null) return duel.challengerId == userId ? 'Rakip bekleniyor' : 'Rakip aranıyor';
        return duel.isPlayer(userId) ? 'Sıra sende' : 'Oynanıyor';
    }
  }

  Future<void> _accept(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await acceptDuel(ref, duel.betId);
      if (context.mounted) context.push(Routes.duelPlay(duel.betId));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(userMessage(e))));
    }
  }
}

class _StakeDialog extends StatefulWidget {
  const _StakeDialog();

  @override
  State<_StakeDialog> createState() => _StakeDialogState();
}

class _StakeDialogState extends State<_StakeDialog> {
  final _stake = TextEditingController(text: '20');
  String? _error;

  @override
  void dispose() {
    _stake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Meydan oku'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Okulundaki herkes görür; kabul eden aynı tutarı yatırır. 24 saatte kimse kabul etmezse SP\'n iade edilir.'),
          const SizedBox(height: 12),
          TextField(
            controller: _stake,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: 'Yatırılacak SP (en fazla 100)', errorText: _error),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(
          onPressed: () {
            final value = int.tryParse(_stake.text.trim());
            if (value == null || value < 1 || value > 100) {
              setState(() => _error = '1 ile 100 arasında bir tutar gir.');
              return;
            }
            Navigator.pop(context, value);
          },
          child: const Text('Meydan oku ve oyna'),
        ),
      ],
    );
  }
}
