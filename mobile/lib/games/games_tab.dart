import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../bets/bets_data.dart';
import '../core/async_button.dart';
import '../core/error_messages.dart';
import '../core/routes.dart';
import '../core/supabase.dart';
import '../core/verify_email_card.dart';
import '../market/market_data.dart';
import '../people/people_data.dart';
import '../people/person_picker.dart';
import '../people/public_profile_screen.dart';
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
    final players = cosmeticsKey([for (final d in duels.value ?? const <TriviaDuel>[]) ...[d.challengerId, d.opponentId]]);
    final looks = ref.watch(cosmeticsOfProvider(players)).value ?? const <String, Cosmetics>{};
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
          if (verified == false) ...[
            const VerifyEmailCard('Okulundaki tahminleri ve düelloları görmek, oynamak için okul mailini doğrula'),
            const SizedBox(height: 16),
          ],
          Text('Günün tahmini', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            "Evet ya da Hayır'a SP yatır; doğru tahmin edenler havuzu yatırdıkları oranda paylaşır. "
            'Sonucu okul yetkilisi girer.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          switch (predictions) {
            AsyncData(value: final list) when list.isEmpty && verified == false => const SizedBox.shrink(),
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
            'eşitlikte daha hızlı olan havuzu alır. Soru başına 15 saniye. Herkese açık ya da belirli birine '
            'meydan okuyabilirsin.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (verified == true)
            FilledButton.icon(
              onPressed: () => _challenge(context, ref),
              icon: const Icon(Icons.sports_kabaddi),
              label: const Text('Meydan oku'),
            ),
          const SizedBox(height: 12),
          switch (duels) {
            AsyncData(value: final list) when list.isEmpty && verified == false => const SizedBox.shrink(),
            AsyncData(value: final list) when list.isEmpty => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('Henüz düello yok. İlk meydan okuyan sen ol.')),
            ),
            AsyncData(value: final list) => Column(
              children: [
                for (final duel in list) DuelCard(duel: duel, userId: userId, canJoin: verified == true, looks: looks),
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
    final choice = await showDialog<_Challenge>(context: context, builder: (_) => const _StakeDialog());
    if (choice == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final betId = await createDuel(ref, stake: choice.stake, invitedId: choice.invited?.id);
      if (context.mounted) context.push(Routes.duelPlay(betId));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(userMessage(e))));
    }
  }
}

class DuelCard extends ConsumerWidget {
  const DuelCard({
    super.key,
    required this.duel,
    required this.userId,
    required this.canJoin,
    this.looks = const {},
  });

  final TriviaDuel duel;
  final String? userId;
  final bool canJoin;

  /// Oyuncuların kuşandığı kozmetikler (isim rengi, çerçeve, rozet).
  final Map<String, Cosmetics> looks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final mine = duel.isPlayer(userId);
    final wager = ref.watch(myWagersProvider).value?[duel.betId];
    final waiting = duel.invitedId == null ? 'herkese açık' : '${duel.invitedName ?? 'davetli'} bekleniyor';
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
              title: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  PersonLabel(userId: duel.challengerId, name: duel.challengerName, cosmetics: looks[duel.challengerId]),
                  const Text('vs'),
                  if (duel.opponentId != null)
                    PersonLabel(userId: duel.opponentId!, name: duel.opponentName ?? '', cosmetics: looks[duel.opponentId])
                  else
                    Text(waiting),
                ],
              ),
              subtitle: Text('${formatAmount(duel.stake)} SP · ${_statusText(duel, userId, wager)}'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                children: [
                  if (canJoin && duel.canAccept(userId, now))
                    AsyncButton(
                      onPressed: () => _accept(context, ref),
                      child: Text('Kabul et (${formatAmount(duel.stake)} SP)'),
                    ),
                  if (mine && duel.canPlay(userId, now))
                    FilledButton.tonal(
                      onPressed: () => context.push(Routes.duelPlay(duel.betId)),
                      child: Text(myPlay == null ? 'Oyna' : 'Oyuna dön'),
                    ),
                  if (mine && duel.reviewable && myPlay != null)
                    OutlinedButton(
                      onPressed: () => context.push(Routes.duelReview(duel.betId)),
                      child: const Text('Cevapları gör'),
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

/// Meydan okuma seçimi: tutar ve (belirli birine ise) davet edilen kişi.
typedef _Challenge = ({int stake, Person? invited});

class _StakeDialog extends StatefulWidget {
  const _StakeDialog();

  @override
  State<_StakeDialog> createState() => _StakeDialogState();
}

class _StakeDialogState extends State<_StakeDialog> {
  final _stake = TextEditingController(text: '20');
  String? _error;
  var _toPerson = false;
  Person? _invited;

  @override
  void dispose() {
    _stake.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final person = await pickPerson(context, title: 'Kime meydan okuyorsun?');
    if (person != null && mounted) setState(() => _invited = person);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Meydan oku'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Herkese açık')),
                ButtonSegment(value: true, label: Text('Birine')),
              ],
              selected: {_toPerson},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _toPerson = s.first),
            ),
            const SizedBox(height: 12),
            if (_toPerson)
              OutlinedButton.icon(
                onPressed: _pick,
                icon: const Icon(Icons.person_search),
                label: Text(_invited == null ? 'Kişi seç' : _invited!.fullName),
              ),
            const SizedBox(height: 8),
            Text(
              _toPerson
                  ? 'Yalnızca seçtiğin kişi kabul edebilir ve aynı tutarı yatırır. 24 saatte kabul etmezse SP\'n iade edilir.'
                  : 'Okulundaki herkes görür; kabul eden aynı tutarı yatırır. 24 saatte kimse kabul etmezse SP\'n iade edilir.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _stake,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: 'Yatırılacak SP (en fazla 100)', errorText: _error),
            ),
          ],
        ),
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
            if (_toPerson && _invited == null) {
              setState(() => _error = 'Önce meydan okuyacağın kişiyi seç.');
              return;
            }
            Navigator.pop<_Challenge>(context, (stake: value, invited: _toPerson ? _invited : null));
          },
          child: const Text('Meydan oku ve oyna'),
        ),
      ],
    );
  }
}
