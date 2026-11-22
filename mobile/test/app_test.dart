import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampusbet/app.dart';
import 'package:kampusbet/bets/bets_data.dart';
import 'package:kampusbet/bets/bets_tab.dart';
import 'package:kampusbet/core/app_info.dart';
import 'package:kampusbet/core/supabase.dart';
import 'package:kampusbet/profile/profile_data.dart';
import 'package:kampusbet/profile/student_email_data.dart';
import 'package:kampusbet/wallet/wallet_data.dart';

// Supabase'e bağlanmadan akışın ekranları: sağlayıcıların yerine sabit değerler konur.

const _profile = Profile(
  id: 'u1',
  firstName: 'Ada',
  lastName: 'Yılmaz',
  schoolName: 'Örnek Üniversitesi',
  schoolEmailDomains: ['ogr.ornek.edu.tr'],
);

Future<void> pumpApp(
  WidgetTester tester, {
  String? userId,
  Profile? profile,
  StudentEmail studentEmail = const StudentEmail(),
  List<Bet> bets = const [],
  Map<String, Wager> wagers = const {},
}) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        currentUserIdProvider.overrideWith((ref) => userId),
        myProfileProvider.overrideWith((ref) async => ProfileStatus(userId: userId, profile: profile)),
        studentEmailProvider.overrideWith((ref) async => studentEmail),
        officialBetsProvider.overrideWith((ref) async => bets),
        myWagersProvider.overrideWith((ref) async => wagers),
        schoolsProvider.overrideWith(
          (ref) async => const [School(id: 's1', name: 'Örnek Üniversitesi')],
        ),
        balanceProvider.overrideWith((ref) async => const Balance(sp: 1050, ssp: 0)),
        loginStreakProvider.overrideWith((ref) async => const LoginStreak(current: 1, longest: 3)),
        dailyRewardProvider.overrideWith(
          (ref) async => const DailyReward(claimed: true, amount: 50, streak: 1),
        ),
      ],
      child: const KampusBetApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('oturum yoksa giriş ekranı', (tester) async {
    await pumpApp(tester);

    expect(find.text(AppInfo.name), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Giriş yap'), findsOneWidget);

    await tester.tap(find.text('Kayıt ol').first);
    await tester.pumpAndSettle();
    expect(find.text('Şifre (tekrar)'), findsOneWidget);
  });

  testWidgets('giriş formu geçersiz e-postayı sunucuya göndermez', (tester) async {
    await pumpApp(tester);

    await tester.enterText(find.byType(TextFormField).first, 'gecersiz');
    await tester.tap(find.widgetWithText(FilledButton, 'Giriş yap'));
    await tester.pumpAndSettle();
    expect(find.text('Geçerli bir e-posta adresi yaz.'), findsOneWidget);
  });

  testWidgets('profili olmayan kullanıcı profil oluşturma ekranına gider', (tester) async {
    await pumpApp(tester, userId: 'u1');

    expect(find.text('Profilini oluştur'), findsOneWidget);
    expect(find.text('Okul'), findsOneWidget);

    await tester.tap(find.text('Profili oluştur'));
    await tester.pumpAndSettle();
    expect(find.text('Ad boş olamaz.'), findsOneWidget);
    expect(find.text('Okulunu seç.'), findsOneWidget);
  });

  testWidgets('profili olan kullanıcı sekmeleri, bakiyeyi ve günlük ödülü görür', (tester) async {
    await pumpApp(tester, userId: 'u1', profile: _profile);

    for (final label in ['Bahisler', 'Oyunlar', 'Market', 'Liderlik', 'Profil']) {
      expect(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)), findsOneWidget);
    }
    expect(find.text('1.050'), findsOneWidget);
    expect(find.text('Günlük giriş ödülü: +50 SP · Seri: 1 gün'), findsOneWidget);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Ada Yılmaz'), findsOneWidget);
    expect(find.text('1 gün'), findsOneWidget);
  });

  testWidgets('okul maili doğrulanmamışsa profil sekmesi doğrulama ekranına götürür', (tester) async {
    await pumpApp(tester, userId: 'u1', profile: _profile);
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Okul mailini doğrula'));
    await tester.pumpAndSettle();
    expect(find.text('Okul maili doğrulama'), findsOneWidget);
    expect(find.text('Okul mailin şununla bitmeli: @ogr.ornek.edu.tr'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'mail-degil');
    await tester.tap(find.widgetWithText(FilledButton, 'Kod gönder'));
    await tester.pumpAndSettle();
    expect(find.text('Geçerli bir mail adresi yaz.'), findsOneWidget);
  });

  testWidgets('doğrulanmış okul maili profilde görünür', (tester) async {
    await pumpApp(
      tester,
      userId: 'u1',
      profile: _profile,
      studentEmail: StudentEmail(email: 'ada@ogr.ornek.edu.tr', verifiedAt: DateTime(2026, 11, 22)),
    );
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();

    expect(find.text('Okul maili doğrulandı'), findsOneWidget);
    expect(find.text('ada@ogr.ornek.edu.tr'), findsOneWidget);
    expect(find.text('Okul mailini doğrula'), findsNothing);
  });

  Bet finalBet({String status = 'open', bool? redWins}) => Bet(
    id: 'b1',
    title: 'Bahar turnuvası finali',
    status: status,
    locksAt: DateTime.now().add(const Duration(days: 1)),
    currency: 'SSP',
    maxStake: 200,
    options: [
      BetOption(id: 'o1', label: 'Kırmızı', position: 1, odds: 1.8, isWinner: redWins),
      BetOption(id: 'o2', label: 'Mavi', position: 2, odds: 2.1, isWinner: redWins == null ? null : !redWins),
    ],
  );
  final verified = StudentEmail(email: 'ada@ogr.ornek.edu.tr', verifiedAt: DateTime(2026, 11, 22));

  testWidgets('açık resmi bahis oranlarıyla listelenir, seçeneğe dokununca yatırım ekranı açılır', (tester) async {
    await pumpApp(tester, userId: 'u1', profile: _profile, studentEmail: verified, bets: [finalBet()]);

    expect(find.text('Bahar turnuvası finali'), findsOneWidget);
    expect(find.text('1,80'), findsOneWidget);
    expect(find.text('2,10'), findsOneWidget);

    await tester.tap(find.text('Kırmızı'));
    await tester.pumpAndSettle();
    expect(find.text('Kırmızı · oran 1,80'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '100');
    await tester.pump();
    expect(find.text('Kazanırsan: 180 SSP'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '500');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('1 ile 200 SSP arasında bir tutar gir.'), findsOneWidget);
  });

  testWidgets('sonuçlanan bahiste kişinin kazancı görünür', (tester) async {
    await pumpApp(
      tester,
      userId: 'u1',
      profile: _profile,
      studentEmail: verified,
      bets: [finalBet(status: 'settled', redWins: true)],
      wagers: const {'b1': Wager(betId: 'b1', optionId: 'o1', amount: 100, odds: 1.8, payout: 180)},
    );

    expect(find.text('Sonuçlandı'), findsOneWidget);
    expect(find.text('Kazandın: +180 SSP (100 SSP · Kırmızı @ 1,80)'), findsOneWidget);
  });

  testWidgets('okul maili doğrulanmamışsa uyarı çıkar, seçenekler yatırım açmaz', (tester) async {
    await pumpApp(tester, userId: 'u1', profile: _profile, bets: [finalBet()]);

    expect(find.text('Bahis için okul mailini doğrula'), findsOneWidget);
    await tester.tap(find.text('Kırmızı'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Yatır'), findsNothing);
  });

  test('oran, olası kazanç ve İstanbul saati biçimi', () {
    expect(formatOdds(1.8), '1,80');
    expect(potentialPayout(100, 1.8), 180);
    expect(potentialPayout(7, 1.01), 7);
    expect(formatIstanbul(DateTime.utc(2026, 11, 22, 17, 30)), '22.11.2026 20:30');
  });

  test('tutarlar binlik ayraçla gösterilir', () {
    expect(formatAmount(0), '0');
    expect(formatAmount(999), '999');
    expect(formatAmount(1050), '1.050');
    expect(formatAmount(1234567), '1.234.567');
    expect(formatAmount(-1500), '-1.500');
  });
}
