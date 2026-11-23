import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bets/bets_data.dart';
import '../core/error_messages.dart';
import '../core/verify_email_card.dart';
import '../profile/student_email_data.dart';
import '../wallet/balance_bar.dart';
import '../wallet/wallet_data.dart';
import 'daily_prediction_card.dart';

/// `/gunun-tahmini` (Oyunlar sekmesindeki karttan): okul yetkilisinin açtığı Evet / Hayır soruları; SP havuzu
/// doğru tahmin edenlere yatırdıkları oranda paylaşılır.
class DailyPredictionsScreen extends ConsumerWidget {
  const DailyPredictionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final predictions = ref.watch(dailyPredictionsProvider);
    final wagers = ref.watch(myWagersProvider).value ?? const <String, Wager>{};
    final verified = ref.watch(studentEmailProvider).value?.verified;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Günün tahmini'),
        actions: const [BalanceBar(), SizedBox(width: 8)],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dailyPredictionsProvider);
          ref.invalidate(myWagersProvider);
          ref.invalidate(balanceProvider);
          await ref.read(dailyPredictionsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (verified == false) ...[
              const VerifyEmailCard('Okulundaki tahminleri görmek ve oynamak için okul mailini doğrula'),
              const SizedBox(height: 16),
            ],
            Text(
              "Evet ya da Hayır'a SP yatır; doğru tahmin edenler havuzu yatırdıkları oranda paylaşır. "
              'Sonucu okul yetkilisi girer.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            switch (predictions) {
              AsyncData(value: final list) when list.isEmpty && verified == false => const SizedBox.shrink(),
              AsyncData(value: final list) when list.isEmpty => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
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
              _ => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
            },
          ],
        ),
      ),
    );
  }
}
