import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampusbet/app.dart';
import 'package:kampusbet/core/app_info.dart';
import 'package:kampusbet/core/supabase.dart';
import 'package:kampusbet/profile/profile_data.dart';
import 'package:kampusbet/wallet/wallet_data.dart';

// Supabase'e bağlanmadan akışın ekranları: sağlayıcıların yerine sabit değerler konur.

const _profile = Profile(id: 'u1', firstName: 'Ada', lastName: 'Yılmaz', schoolName: 'Örnek Üniversitesi');

Future<void> pumpApp(WidgetTester tester, {String? userId, Profile? profile}) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        currentUserIdProvider.overrideWith((ref) => userId),
        myProfileProvider.overrideWith((ref) async => ProfileStatus(userId: userId, profile: profile)),
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

  test('tutarlar binlik ayraçla gösterilir', () {
    expect(formatAmount(0), '0');
    expect(formatAmount(999), '999');
    expect(formatAmount(1050), '1.050');
    expect(formatAmount(1234567), '1.234.567');
    expect(formatAmount(-1500), '-1.500');
  });
}
