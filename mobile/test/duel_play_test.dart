import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampusbet/games/duel_play_screen.dart';
import 'package:kampusbet/games/trivia_data.dart';

// Oyun ekranı Supabase'e bağlanmadan: sunucudan gelen sorular sabit değerle verilir.
// Son soru cevaplanınca gönderim sunucuya gideceği için test son soruya kadar ilerler.

void main() {
  testWidgets('sorular sırayla gelir, şık seçilince sonrakine geçilir, geri sayım görünür', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          duelGameProvider('b1').overrideWith(
            (ref) async => const DuelGame(
              secondsLeft: 30,
              questions: [
                TriviaQuestion(no: 1, question: 'Türkiye\'nin başkenti neresidir?', options: ['İstanbul', 'Ankara']),
                TriviaQuestion(no: 2, question: 'Bir günde kaç saat vardır?', options: ['12', '24']),
              ],
            ),
          ),
        ],
        child: const MaterialApp(home: DuelPlayScreen(betId: 'b1')),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Soru 1 / 2'), findsOneWidget);
    expect(find.text('30 sn'), findsOneWidget);
    expect(find.text('Türkiye\'nin başkenti neresidir?'), findsOneWidget);

    await tester.tap(find.text('Ankara'));
    await tester.pump();
    expect(find.text('Soru 2 / 2'), findsOneWidget);
    expect(find.text('Bir günde kaç saat vardır?'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('28 sn'), findsOneWidget);
  });
}
