import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:kampusbet/achievements/achievements_data.dart';
import 'package:kampusbet/app.dart';
import 'package:kampusbet/bets/bets_data.dart';
import 'package:kampusbet/bets/bets_tab.dart';
import 'package:kampusbet/core/app_info.dart';
import 'package:kampusbet/core/supabase.dart';
import 'package:kampusbet/games/trivia_data.dart';
import 'package:kampusbet/home/home_shell.dart';
import 'package:kampusbet/leaderboard/leaderboard_data.dart';
import 'package:kampusbet/market/market_data.dart';
import 'package:kampusbet/core/account_guard.dart';
import 'package:kampusbet/people/people_data.dart';
import 'package:kampusbet/profile/privacy_data.dart';
import 'package:kampusbet/profile/profile_data.dart';
import 'package:kampusbet/profile/profile_tab.dart';
import 'package:kampusbet/profile/student_email_data.dart';
import 'package:kampusbet/progress/progress_data.dart';
import 'package:kampusbet/quests/quests_data.dart';
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
  List<Bet> socialBets = const [],
  Map<String, Wager> wagers = const {},
  Set<String> disputed = const {},
  List<TriviaDuel> duels = const [],
  List<Bet> predictions = const [],
  List<MarketItem> items = const [],
  List<OwnedItem> inventory = const [],
  List<Quest> quests = const [],
  List<LeaderboardRow> Function(LeaderboardQuery)? leaderboard,
  MyStats stats = const MyStats(),
  List<WagerEntry> history = const [],
  Progress progress = const Progress(xp: 110, level: 2, levelXp: 100, nextLevelXp: 300, pickXpToday: 15),
  List<XpEvent> xpEvents = const [],
  FakePrivacyApi? privacy,
  Map<String, Cosmetics> looks = const {},
  List<Person> people = const [],
  List<DuelReviewItem> review = const [],
  Map<String, PublicProfile> publicProfiles = const {},
  List<Bet> ownBets = const [],
  Progress Function()? progressNow,
  FakeDailyRewardApi? daily,
  List<Achievement> achievements = const [],
  List<Achievement> Function()? achievementsNow,
}) async {
  final dailyApi = daily ?? FakeDailyRewardApi(claimedToday: true);
  final privacyApi = privacy ?? FakePrivacyApi();
  // Gerçek telefon boyutu (Pixel 7); varsayılan 800×600 test ekranında düğmeler görünür alanın dışında kalıyor.
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        currentUserIdProvider.overrideWith((ref) => userId),
        myProfileProvider.overrideWith((ref) async => ProfileStatus(userId: userId, profile: profile)),
        studentEmailProvider.overrideWith((ref) async => studentEmail),
        officialBetsProvider.overrideWith((ref) async => bets),
        socialBetsProvider.overrideWith((ref) async => socialBets),
        myWagersProvider.overrideWith((ref) async => wagers),
        myDisputedBetIdsProvider.overrideWith((ref) async => disputed),
        triviaDuelsProvider.overrideWith((ref) async => duels),
        dailyPredictionsProvider.overrideWith((ref) async => predictions),
        marketItemsProvider.overrideWith((ref) async => items),
        myInventoryProvider.overrideWith((ref) async => inventory),
        questsProvider.overrideWith((ref) async => quests),
        leaderboardProvider.overrideWith(
          (ref) async => leaderboard?.call(ref.watch(leaderboardQueryProvider)) ?? const <LeaderboardRow>[],
        ),
        leaderboardMinimumsProvider.overrideWith((ref) async => (week: 5, allTime: 20)),
        myStatsProvider.overrideWith((ref) async => stats),
        privacyApiProvider.overrideWithValue(privacyApi),
        cosmeticsOfProvider.overrideWith((ref, key) async => {
          for (final id in key.split(','))
            if (looks[id] != null) id: looks[id]!,
        }),
        schoolmateSearchProvider.overrideWith(
          (ref, query) async => [
            for (final p in people)
              if (p.fullName.toLowerCase().contains(query.toLowerCase())) p,
          ],
        ),
        leaderboardHiddenProvider.overrideWith((ref) async => privacyApi.hidden),
        myWagerHistoryProvider.overrideWith((ref) async => history),
        myProgressProvider.overrideWith((ref) async => progressNow?.call() ?? progress),
        duelReviewProvider.overrideWith((ref, betId) async => review),
        publicProfileProvider.overrideWith((ref, id) async => publicProfiles[id]),
        myOwnSocialBetsProvider.overrideWith((ref) async => ownBets),
        xpRulesProvider.overrideWith((ref) async => (dailyLogin: 10, correctPick: 15, dailyPickCap: 60)),
        xpEventsProvider.overrideWith((ref) async => xpEvents),
        schoolsProvider.overrideWith((ref) async => const [School(id: 's1', name: 'Örnek Üniversitesi')]),
        balanceProvider.overrideWith((ref) async => const Balance(sp: 1050, ssp: 0)),
        loginStreakProvider.overrideWith((ref) async => const LoginStreak(current: 1, longest: 3)),
        dailyRewardApiProvider.overrideWithValue(dailyApi),
        achievementsProvider.overrideWith((ref) async => achievementsNow?.call() ?? achievements),
      ],
      child: const KampusBetApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Günlük ödülün sahtesi: 7 günlük takvim (bugün 1. gün), ödül alınınca bugün işaretlenir.
class FakeDailyRewardApi implements DailyRewardApi {
  FakeDailyRewardApi({this.claimedToday = false});

  bool claimedToday;
  var claims = 0;

  @override
  Future<List<CalendarDay>> calendar() async => [
    for (var d = 1; d <= 7; d++)
      CalendarDay(day: d, amount: 40 + d * 10, bonus: d == 7 ? 200 : 0, claimed: d == 1 && claimedToday, isToday: d == 1),
  ];

  @override
  Future<DailyReward> claim() async {
    claims++;
    final first = !claimedToday;
    claimedToday = true;
    return DailyReward(claimed: first, amount: first ? 50 : 0, streak: 1);
  }
}

/// Gizlilik işlemlerinin sahtesi: tercih bellekte tutulur, dışa aktarma sabit veri döner, paylaşım kaydedilir.
class FakePrivacyApi implements PrivacyApi {
  FakePrivacyApi({this.hidden = false});

  bool hidden;
  final shared = <(String, String)>[];

  @override
  Future<void> setLeaderboardHidden(bool hidden) async => this.hidden = hidden;

  @override
  Future<Object?> exportMyData() async => {
    'format': 'kampusbet-verilerim-1',
    'profile': {'first_name': 'Ada'},
  };

  @override
  Future<void> shareFile(String name, Uint8List bytes) async => shared.add((name, utf8.decode(bytes)));
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

  testWidgets('kayıt ekranından KVKK aydınlatma metni açılır', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Kayıt ol').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kişisel verilerin nasıl işlenir: KVKK Aydınlatma Metni'));
    await tester.pumpAndSettle();

    expect(find.text('Gizlilik ve KVKK'), findsOneWidget);
    expect(find.text('KVKK Aydınlatma Metni'), findsOneWidget);
    expect(find.text('1. Veri sorumlusu'), findsOneWidget);
  });

  testWidgets('şifremi unuttum önce e-posta ister', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Şifremi unuttum'));
    await tester.pumpAndSettle();
    expect(find.text('Şifre sıfırlama linki için önce e-posta adresini yaz.'), findsOneWidget);
  });

  testWidgets('şifre değiştirme kısa ve uyuşmayan şifreyi göndermez', (tester) async {
    await pumpApp(tester, userId: 'u1', profile: _profile);
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    final profileList = find.descendant(of: find.byType(ProfileTab), matching: find.byType(Scrollable)).first;
    await tester.drag(profileList, const Offset(0, -3000));
    tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).clearSnackBars();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Şifreyi değiştir'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Yeni şifre'), 'kisa');
    await tester.enterText(find.widgetWithText(TextFormField, 'Yeni şifre (tekrar)'), 'baska');
    await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
    await tester.pumpAndSettle();
    expect(find.text('Şifre en az 8 karakter olmalı.'), findsOneWidget);
    expect(find.text('Şifreler aynı değil.'), findsOneWidget);
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
    final daily = FakeDailyRewardApi();
    await pumpApp(tester, userId: 'u1', profile: _profile, daily: daily);

    // Bugünün ödülü alınmadığı için takvim kendiliğinden açılır.
    expect(find.text('🎁 Günlük ödül'), findsOneWidget);
    expect(find.text('7. gün'), findsOneWidget);
    expect(find.text('+200 bonus'), findsOneWidget);
    await tester.tap(find.text('Ödülü al (+50 SP · +10 XP)'));
    await tester.pumpAndSettle();
    expect(daily.claims, 1);
    expect(find.text('+50 SP · +10 XP aldın! Seri: 1 gün. Yarın yine gel.'), findsOneWidget);
    await tester.tap(find.text('Kapat'));
    await tester.pumpAndSettle();
    expect(find.text('🎁 Günlük ödül'), findsNothing);

    for (final label in ['Bahisler', 'Oyunlar', 'Market', 'Liderlik', 'Profil']) {
      expect(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)), findsOneWidget);
    }
    expect(find.text('1.050'), findsOneWidget);

    // Hediye simgesiyle yeniden açılır; ödül alındığı için düğme yok.
    await tester.tap(find.byTooltip('Günlük ödül'));
    await tester.pumpAndSettle();
    expect(find.text('Bugünün ödülü alındı. Yarın yine gel.'), findsOneWidget);
    await tester.tap(find.text('Kapat'));
    await tester.pumpAndSettle();

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
    expect(find.text('Kazandın: net +80 SSP · 180 SSP aldın (100 SSP · Kırmızı @ 1,80)'), findsOneWidget);
  });

  testWidgets('okul maili doğrulanmamışsa uyarı çıkar, seçenekler yatırım açmaz', (tester) async {
    await pumpApp(tester, userId: 'u1', profile: _profile, bets: [finalBet()]);

    expect(find.text('Bahis için okul mailini doğrula'), findsOneWidget);
    await tester.tap(find.text('Kırmızı'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Yatır'), findsNothing);
  });

  Bet socialBet({String status = 'open', String refereeId = 'u2', DateTime? locksAt, DateTime? disputeUntil}) => Bet(
    id: 'b2',
    type: 'sp_social',
    title: 'Yarın yemekhanede pilav çıkar mı?',
    status: status,
    locksAt: locksAt ?? DateTime.now().add(const Duration(hours: 2)),
    currency: 'SP',
    maxStake: 100,
    poolTotal: 150,
    creatorId: refereeId,
    refereeId: refereeId,
    refereeName: 'Veli Demir',
    proposedOptionId: status == 'settling' ? 'so1' : null,
    disputeUntil: disputeUntil,
    options: const [
      BetOption(id: 'so1', label: 'Evet', position: 1, poolAmount: 100),
      BetOption(id: 'so2', label: 'Hayır', position: 2, poolAmount: 50),
    ],
  );

  Future<void> openSocial(WidgetTester tester) async {
    await tester.tap(find.text('Sosyal'));
    await tester.pumpAndSettle();
  }

  testWidgets('sosyal bahiste hakem kapanıştan sonra sonucu girme düğmesini görür', (tester) async {
    await pumpApp(
      tester,
      userId: 'u1',
      profile: _profile,
      studentEmail: verified,
      socialBets: [socialBet(refereeId: 'u1', locksAt: DateTime.now().subtract(const Duration(minutes: 5)))],
    );
    await openSocial(tester);

    expect(find.text('Yarın yemekhanede pilav çıkar mı?'), findsOneWidget);
    expect(find.textContaining('Hakem: sen'), findsOneWidget);
    expect(find.textContaining('hakemin sonucu bekleniyor'), findsOneWidget);
    expect(find.text('100 SP'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sonucu gir'), findsOneWidget);
  });

  testWidgets('yatırım yapan katılımcı itiraz süresinde gerekçeyle itiraz eder', (tester) async {
    await pumpApp(
      tester,
      userId: 'u1',
      profile: _profile,
      studentEmail: verified,
      socialBets: [socialBet(status: 'settling', disputeUntil: DateTime.now().add(const Duration(hours: 5)))],
      wagers: const {'b2': Wager(betId: 'b2', optionId: 'so2', amount: 50)},
    );
    await openSocial(tester);

    expect(find.textContaining('Hakemin sonucu: Evet'), findsOneWidget);
    // Hakem adı dokunulabilir kişi etiketi (profiline gider).
    expect(find.text('Hakem:'), findsOneWidget);
    expect(find.text('Veli Demir'), findsOneWidget);
    expect(find.text('Yatırımın: 50 SP · Hayır'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'İtiraz et'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'İtiraz et'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ab');
    await tester.tap(find.widgetWithText(FilledButton, 'İtiraz et'));
    await tester.pumpAndSettle();
    expect(find.text('En az 3 karakter yaz.'), findsOneWidget);
  });

  testWidgets('itiraz eden kişi itirazının iletildiğini görür, tekrar itiraz düğmesi çıkmaz', (tester) async {
    await pumpApp(
      tester,
      userId: 'u1',
      profile: _profile,
      studentEmail: verified,
      socialBets: [socialBet(status: 'settling', disputeUntil: DateTime.now().add(const Duration(hours: 5)))],
      wagers: const {'b2': Wager(betId: 'b2', optionId: 'so2', amount: 50)},
      disputed: const {'b2'},
    );
    await openSocial(tester);

    expect(find.textContaining('İtirazın moderatöre iletildi'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'İtiraz et'), findsNothing);
  });

  testWidgets('sosyal bahis açma formu boş soruyu ve zamansız kapanışı göndermez', (tester) async {
    await pumpApp(tester, userId: 'u1', profile: _profile, studentEmail: verified);
    await openSocial(tester);

    await tester.tap(find.text('Sosyal bahis aç'));
    await tester.pumpAndSettle();
    expect(find.text('Kapanış zamanı seç'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Bahsi aç'));
    await tester.tap(find.widgetWithText(FilledButton, 'Bahsi aç'));
    await tester.pumpAndSettle();
    expect(find.text('Soru boş olamaz.'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(TextFormField, 'Soru'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Soru'), 'Maçı kim kazanır?');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Bahsi aç'));
    await tester.tap(find.widgetWithText(FilledButton, 'Bahsi aç'));
    await tester.pumpAndSettle();
    expect(find.text('İleride bir kapanış zamanı seç.'), findsOneWidget);
  });

  testWidgets('başkasının açık meydan okuması kabul edilebilir görünür', (tester) async {
    await pumpApp(
      tester,
      userId: 'u1',
      profile: _profile,
      studentEmail: verified,
      duels: [
        TriviaDuel(
          betId: 'd1',
          challengerId: 'u2',
          challengerName: 'Veli Demir',
          stake: 20,
          status: 'open',
          acceptDeadline: DateTime.now().add(const Duration(hours: 20)),
        ),
      ],
    );
    await tester.tap(find.text('Oyunlar'));
    await tester.pumpAndSettle();

    expect(find.text('Veli Demir'), findsOneWidget);
    expect(find.text('herkese açık'), findsOneWidget);
    expect(find.text('20 SP · Rakip aranıyor'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Kabul et (20 SP)'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Meydan oku'), findsOneWidget);
  });

  testWidgets('biten düelloda sonuç sunucunun ödemesinden gösterilir', (tester) async {
    await pumpApp(
      tester,
      userId: 'u1',
      profile: _profile,
      studentEmail: verified,
      duels: [
        TriviaDuel(
          betId: 'd2',
          challengerId: 'u1',
          challengerName: 'Ada Yılmaz',
          opponentId: 'u2',
          opponentName: 'Veli Demir',
          stake: 20,
          status: 'settled',
          acceptDeadline: DateTime.now(),
          plays: const [
            DuelPlay(playerId: 'u1', submitted: true, score: 5),
            DuelPlay(playerId: 'u2', submitted: true, score: 3),
          ],
        ),
      ],
      wagers: const {'d2': Wager(betId: 'd2', optionId: 'x', amount: 20, payout: 40)},
    );
    await tester.tap(find.text('Oyunlar'));
    await tester.pumpAndSettle();

    expect(find.text('Ada Yılmaz'), findsOneWidget);
    expect(find.text('Veli Demir'), findsOneWidget);
    expect(find.text('20 SP · Kazandın: net +20 SP · skor 5 - 3'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Kabul et (20 SP)'), findsNothing);
  });

  Bet prediction({String status = 'open', bool? yesWins}) => Bet(
    id: 'p1',
    type: 'sp_minigame',
    title: 'Bugün yemekhanede mercimek çorbası çıkar mı?',
    status: status,
    locksAt: DateTime.now().add(Duration(hours: status == 'open' ? 3 : -3)),
    currency: 'SP',
    maxStake: 100,
    poolTotal: 150,
    options: [
      BetOption(id: 'y', label: 'Evet', position: 1, poolAmount: 120, isWinner: yesWins),
      BetOption(id: 'n', label: 'Hayır', position: 2, poolAmount: 30, isWinner: yesWins == null ? null : !yesWins),
    ],
  );

  testWidgets('günün tahmini havuzlarıyla görünür, seçeneğe dokununca havuzlu yatırım ekranı açılır', (tester) async {
    await pumpApp(tester, userId: 'u1', profile: _profile, studentEmail: verified, predictions: [prediction()]);
    await tester.tap(find.text('Oyunlar'));
    await tester.pumpAndSettle();

    expect(find.text('Bugün yemekhanede mercimek çorbası çıkar mı?'), findsOneWidget);
    expect(find.text('120 SP'), findsOneWidget);
    expect(find.text('Toplam havuz: 150 SP'), findsOneWidget);

    await tester.tap(find.text('Evet'));
    await tester.pumpAndSettle();
    expect(find.text('Havuz sistemi: kazananlar toplam havuzu yatırdıkları oranda paylaşır.'), findsOneWidget);
    expect(find.text('En fazla 100'), findsOneWidget);
  });

  testWidgets('sonuçlanan günün tahmininde kişinin kazancı görünür, yatırım açılmaz', (tester) async {
    await pumpApp(
      tester,
      userId: 'u1',
      profile: _profile,
      studentEmail: verified,
      predictions: [prediction(status: 'settled', yesWins: true)],
      wagers: const {'p1': Wager(betId: 'p1', optionId: 'y', amount: 30, payout: 37)},
    );
    await tester.tap(find.text('Oyunlar'));
    await tester.pumpAndSettle();

    expect(find.text('Sonuçlandı'), findsOneWidget);
    expect(find.text('Kazandın: net +7 SP · 37 SP aldın (30 SP · Evet)'), findsOneWidget);
    await tester.tap(find.text('Hayır'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Havuz sistemi'), findsNothing);
  });

  const oracle = MarketItem(id: 'm1', name: 'Kehanet Ustası', category: 'title', icon: '🔮', price: 600, currency: 'SP');
  const gold = MarketItem(id: 'm2', name: 'Altın çerçeve', category: 'frame', color: '#D4AF37', price: 400, currency: 'SP');
  const legend = MarketItem(id: 'm3', name: 'Kampüs Efsanesi', category: 'title', icon: '👑', price: 150, currency: 'SSP');
  const streak = MarketItem(id: 'm4', name: 'Seri Avcısı', category: 'badge', icon: '🔥', price: 250, currency: 'SP');
  const crown = MarketItem(id: 'm5', name: 'Taç', category: 'badge', icon: '👑', price: 100, currency: 'SP', minLevel: 3);

  testWidgets('market vitrinleri: fiyatla satın alma onay ister, sahip olunan ürün kuşanılır', (tester) async {
    await pumpApp(
      tester,
      userId: 'u1',
      profile: _profile,
      items: const [crown, gold, oracle, legend],
      inventory: const [OwnedItem(item: gold, equipped: false)],
    );
    await tester.tap(find.text('Market'));
    await tester.pumpAndSettle();

    expect(find.text('Kehanet Ustası'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '600 SP'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Kuşan'), findsOneWidget);
    expect(find.text('Kampüs Efsanesi'), findsNothing);
    // Seviye 2'deki kişi 3. seviye ürününü alamaz: düğme kilitli.
    expect(find.textContaining('3. seviyede açılır'), findsOneWidget);
    final locked = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Seviye 3'));
    expect(locked.onPressed, isNull);
    expect(find.widgetWithText(FilledButton, '100 SP'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, '600 SP'));
    await tester.pumpAndSettle();
    expect(find.textContaining('600 SP karşılığında satın alınsın mı?'), findsOneWidget);
    expect(find.textContaining('SP bakiyen: 1.050'), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('SSP özel'));
    await tester.pumpAndSettle();
    expect(find.text('Kampüs Efsanesi'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '150 SSP'), findsOneWidget);
    expect(find.text('Kehanet Ustası'), findsNothing);
  });

  testWidgets('satış tarihi geçen ürün "Satış bitti", başlamayan "Yakında"', (tester) async {
    final ended = MarketItem(
      id: 'm6',
      name: 'Bahar rozeti',
      category: 'badge',
      icon: '🌸',
      price: 100,
      currency: 'SP',
      availableUntil: DateTime.utc(2020, 1, 1),
    );
    final upcoming = MarketItem(
      id: 'm7',
      name: 'Yaz rozeti',
      category: 'badge',
      icon: '☀',
      price: 100,
      currency: 'SP',
      availableFrom: DateTime.utc(2100, 1, 1),
    );
    await pumpApp(tester, userId: 'u1', profile: _profile, items: [ended, upcoming]);
    await tester.tap(find.text('Market'));
    await tester.pumpAndSettle();
    expect(find.text('Satış bitti'), findsOneWidget);
    expect(find.text('Yakında'), findsOneWidget);
  });

  testWidgets('profilde kuşanılmış unvan ve rozet görünür', (tester) async {
    await pumpApp(
      tester,
      userId: 'u1',
      profile: _profile,
      inventory: const [OwnedItem(item: oracle, equipped: true), OwnedItem(item: streak, equipped: true)],
    );
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();

    expect(find.text('🔮 Kehanet Ustası'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'Seri Avcısı'), findsOneWidget);
    expect(find.text('AY'), findsOneWidget);
  });

  Quest quest(
    String id, {
    required int progress,
    required int target,
    bool claimed = false,
    String period = 'daily',
    int rewardXp = 0,
  }) =>
      Quest(
        id: id,
        title: 'Görev $id',
        period: period,
        action: 'wager',
        target: target,
        rewardCurrency: 'SP',
        rewardAmount: 30,
        progress: progress,
        claimed: claimed,
        periodEndsAt: DateTime.utc(2026, 11, 22, 21),
        rewardXp: rewardXp,
      );

  testWidgets('görevler: profilde hazır ödül sayısı, ekranda ilerleme ve ödül durumu', (tester) async {
    await pumpApp(
      tester,
      userId: 'u1',
      profile: _profile,
      quests: [
        quest('a', progress: 2, target: 2, rewardXp: 20),
        quest('b', progress: 0, target: 1),
        quest('c', progress: 1, target: 1, claimed: true, period: 'weekly'),
      ],
    );
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('1 ödül alınmayı bekliyor'), findsOneWidget);

    await tester.tap(find.text('Görevler'));
    await tester.pumpAndSettle();
    expect(find.text('Günlük'), findsOneWidget);
    expect(find.text('Haftalık'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Ödülü al'), findsOneWidget);
    expect(find.text('Alındı'), findsOneWidget);
    expect(find.text('0/1'), findsOneWidget);
    expect(find.text('+30 SP · +20 XP'), findsOneWidget);
    expect(find.text('+30 SP'), findsNWidgets(2));
    expect(find.text('Yenilenir: 23.11.2026 00:00'), findsNWidgets(3));
  });

  testWidgets('liderlik: madalya, kozmetik, listede olmayan kendi satırı, ölçüt ve dönem değişimi', (tester) async {
    List<LeaderboardRow> rows(LeaderboardQuery q) => switch (q.metric) {
      LeaderboardMetric.hitRate => [
        LeaderboardRow(
          rank: 1,
          userId: 'u2',
          firstName: 'Mert',
          lastName: 'Kaya',
          value: 0.8,
          sample: 5,
          title: 'Kehanet Ustası',
          titleIcon: '🔮',
          badge: '⭐',
          level: 7,
          nameColor: const Color(0xFF7B1FA2),
          computedAt: DateTime.utc(2026, 11, 22, 10, 30),
        ),
        const LeaderboardRow(rank: 2, userId: 'u3', firstName: 'Ece', lastName: 'Demir', value: 0.6, sample: 5),
        const LeaderboardRow(
          rank: 9,
          userId: 'u1',
          firstName: 'Ada',
          lastName: 'Yılmaz',
          value: 0.5,
          sample: 6,
          isMe: true,
        ),
      ],
      LeaderboardMetric.spProfit => const [
        LeaderboardRow(rank: 1, userId: 'u1', firstName: 'Ada', lastName: 'Yılmaz', value: 240, sample: 7, isMe: true),
      ],
      _ => const [],
    };
    await pumpApp(tester, userId: 'u1', profile: _profile, leaderboard: rows);
    await tester.tap(find.text('Liderlik'));
    await tester.pumpAndSettle();

    expect(find.text('🥇'), findsOneWidget);
    expect(find.text('Mert K. ⭐'), findsOneWidget);
    expect(find.text('Sv. 7 · 🔮 Kehanet Ustası · 4/5 doğru'), findsOneWidget);
    expect(find.text('%80'), findsOneWidget);
    expect(find.text('⋯'), findsOneWidget);
    expect(find.text('9.'), findsOneWidget);
    expect(find.text('Ada Y. (sen)'), findsOneWidget);
    expect(find.textContaining('en az 5 tahmin gerekir'), findsOneWidget);
    expect(find.text('Son hesaplama: 22.11.2026 13:30 · 10 dakikada bir yenilenir'), findsOneWidget);

    await tester.tap(find.text('Kazanç'));
    await tester.pumpAndSettle();
    expect(find.text('+240 SP'), findsOneWidget);
    expect(find.text('Mert K. ⭐'), findsNothing);

    await tester.tap(find.text('Seri'));
    await tester.pumpAndSettle();
    expect(find.text('Bu dönemde henüz sıralamaya giren yok.'), findsOneWidget);

    await tester.tap(find.text('İsabet'));
    await tester.tap(find.text('Tüm zamanlar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('en az 20 tahmin gerekir'), findsOneWidget);
  });

  testWidgets('profilde seviye ilerlemesi; dokununca XP kuralları ve son kazançlar', (tester) async {
    await pumpApp(
      tester,
      userId: 'u1',
      profile: _profile,
      progress: const Progress(xp: 150, level: 2, levelXp: 100, nextLevelXp: 300, pickXpToday: 30),
      xpEvents: [XpEvent(reason: 'correct_pick', amount: 15, createdAt: DateTime.utc(2026, 11, 22, 9))],
    );
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Seviye 2'), findsOneWidget);
    expect(find.text('150 XP'), findsOneWidget);
    expect(find.text('Sonraki seviyeye 150 XP'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(bar.value, 0.25);

    await tester.ensureVisible(find.text('Seviye 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seviye 2'));
    await tester.pumpAndSettle();
    expect(find.text('XP nasıl kazanılır'), findsOneWidget);
    expect(find.text('+10 XP'), findsOneWidget);
    expect(find.text('Günde en fazla 60 XP · bugün 30/60'), findsOneWidget);
    expect(find.text('Doğru tahmin'), findsOneWidget);
    expect(find.text('22.11.2026 12:00'), findsOneWidget);
  });

  testWidgets('profilde istatistikler; geçmiş bahisler ekranında sonuçlar', (tester) async {
    await pumpApp(
      tester,
      userId: 'u1',
      profile: _profile,
      stats: const MyStats(
        predictions: 5,
        correct: 4,
        spProfit: 120,
        currentStreak: 2,
        bestStreak: 3,
        duelsPlayed: 2,
        duelsWon: 1,
        weekRankHitRate: 1,
      ),
      history: [
        (
          bet: prediction(status: 'settled', yesWins: true),
          wager: const Wager(betId: 'p1', optionId: 'y', amount: 30, payout: 37),
        ),
      ],
    );
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    final profileList = find.descendant(of: find.byType(ProfileTab), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('2 oyun · 1 galibiyet'), 200, scrollable: profileList);
    expect(find.text('Bu hafta isabette 1.'), findsOneWidget);
    expect(find.text('%80 · 4/5'), findsOneWidget);
    expect(find.text('En iyi: 3'), findsOneWidget);
    expect(find.text('+120 SP'), findsOneWidget);
    // Alttaki düğmeye kadar kaydır: üstündeki "Geçmiş bahislerim" alt menünün arkasında kalmasın.
    await tester.scrollUntilVisible(find.text('Çıkış yap'), 200, scrollable: profileList);
    await tester.ensureVisible(find.text('Geçmiş bahislerim'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Geçmiş bahislerim'));
    await tester.pumpAndSettle();
    expect(find.text('Bugün yemekhanede mercimek çorbası çıkar mı?'), findsOneWidget);
    expect(find.textContaining('Günün tahmini · Sonuçlandı'), findsOneWidget);
    expect(find.textContaining('Kazandın: net +7 SP'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('hesap silme onay ister: kutu işaretlenmeden silme düğmesi kapalı', (tester) async {
    await pumpApp(tester, userId: 'u1', profile: _profile);
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    final profileList = find.descendant(of: find.byType(ProfileTab), matching: find.byType(Scrollable)).first;
    // En alta kaydır; günlük ödül bildirimi en alttaki düğmeyi örtmesin.
    await tester.drag(profileList, const Offset(0, -3000));
    tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).clearSnackBars();
    await tester.pumpAndSettle();
    expect(find.text('Gizlilik ve KVKK'), findsOneWidget);

    await tester.tap(find.text('Hesabımı sil'));
    await tester.pumpAndSettle();
    expect(find.text('Hesabını sil'), findsOneWidget);
    FilledButton deleteButton() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Hesabı sil'));
    expect(deleteButton().onPressed, isNull);

    await tester.tap(find.text('Anladım, hesabım silinsin'));
    await tester.pump();
    expect(deleteButton().onPressed, isNotNull);

    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(find.text('Hesabını sil'), findsNothing);
  });

  testWidgets('kayıt: koşullar kabul edilmeden gönderilmez; kullanım koşulları açılır', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Kayıt ol').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'E-posta'), 'ada@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Şifre'), 'uzun-sifre-1');
    await tester.enterText(find.widgetWithText(TextFormField, 'Şifre (tekrar)'), 'uzun-sifre-1');
    await tester.tap(find.widgetWithText(FilledButton, 'Kayıt ol'));
    await tester.pumpAndSettle();
    expect(find.text('Kayıt olmak için kullanım koşullarını kabul etmelisin.'), findsOneWidget);

    await tester.tap(find.text("18 yaşını doldurdum; Kullanım Koşulları'nı okudum ve kabul ediyorum."));
    await tester.pump();
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value, isTrue);

    await tester.tap(find.widgetWithText(TextButton, 'Kullanım Koşulları'));
    await tester.pumpAndSettle();
    expect(find.text('Kullanım koşulları'), findsOneWidget);
    expect(find.text('1. Hizmet'), findsOneWidget);
  });

  testWidgets('profilde gizlilik: liderlikte görünme kapatılır, veriler dosya olarak paylaşılır', (tester) async {
    final privacy = FakePrivacyApi();
    await pumpApp(tester, userId: 'u1', profile: _profile, privacy: privacy);
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    final profileList = find.descendant(of: find.byType(ProfileTab), matching: find.byType(Scrollable)).first;
    await tester.drag(profileList, const Offset(0, -3000));
    tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).clearSnackBars();
    await tester.pumpAndSettle();

    SwitchListTile visibility() => tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Liderlikte görün'));
    expect(visibility().value, isTrue);
    await tester.tap(find.text('Liderlikte görün'));
    await tester.pumpAndSettle();
    expect(privacy.hidden, isTrue);
    expect(visibility().value, isFalse);
    expect(find.text('Artık sıralamalarda görünmüyorsun.'), findsOneWidget);
    tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).clearSnackBars();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Verilerimi indir'));
    await tester.pumpAndSettle();
    expect(privacy.shared, hasLength(1));
    final (name, json) = privacy.shared.single;
    expect(name, matches(RegExp(r'^kampusbet-verilerim-\d{8}\.json$')));
    expect(jsonDecode(json), containsPair('format', 'kampusbet-verilerim-1'));

    await tester.tap(find.text('Liderlik'));
    await tester.pumpAndSettle();
    expect(find.text('Sıralamalarda gizlisin'), findsOneWidget);
  });

  test('veri dosyasının adı tarihli', () {
    expect(dataExportFileName(DateTime(2026, 3, 7)), 'kampusbet-verilerim-20260307.json');
  });

  testWidgets('belirli birine meydan okuma: kişi seçmeden gönderilmez, aranan kişi seçilir', (tester) async {
    await pumpApp(
      tester,
      userId: 'u1',
      profile: _profile,
      studentEmail: verified,
      people: const [
        Person(id: 'u2', firstName: 'Veli', lastName: 'Demir', department: 'Fizik', level: 3),
        Person(id: 'u3', firstName: 'Ece', lastName: 'Kaya'),
      ],
    );
    await tester.tap(find.text('Oyunlar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Meydan oku'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Birine'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Meydan oku ve oyna'));
    await tester.pumpAndSettle();
    expect(find.text('Önce meydan okuyacağın kişiyi seç.'), findsOneWidget);

    await tester.tap(find.text('Kişi seç'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Ad ya da soyad'), 'vel');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Fizik · Sv. 3'), findsOneWidget);
    expect(find.text('Ece Kaya'), findsNothing);
    await tester.tap(find.text('Veli Demir'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(OutlinedButton, 'Veli Demir'), findsOneWidget);
  });

  testWidgets('biten düelloda cevaplar: doğru şık, kendi ve rakibin cevabı', (tester) async {
    await pumpApp(
      tester,
      userId: 'u1',
      profile: _profile,
      studentEmail: verified,
      duels: [
        TriviaDuel(
          betId: 'd2',
          challengerId: 'u1',
          challengerName: 'Ada Yılmaz',
          opponentId: 'u2',
          opponentName: 'Veli Demir',
          stake: 20,
          status: 'settled',
          acceptDeadline: DateTime.now(),
          plays: const [
            DuelPlay(playerId: 'u1', submitted: true, score: 1),
            DuelPlay(playerId: 'u2', submitted: true, score: 0),
          ],
        ),
      ],
      review: const [
        DuelReviewItem(no: 1, question: 'Başkent?', options: ['Ankara', 'İzmir'], correctIndex: 0, myAnswer: 0, opponentAnswer: 1),
        DuelReviewItem(no: 2, question: 'En büyük gezegen?', options: ['Mars', 'Jüpiter'], correctIndex: 1),
      ],
    );
    await tester.tap(find.text('Oyunlar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cevapları gör'));
    await tester.tap(find.text('Cevapları gör'));
    await tester.pumpAndSettle();

    expect(find.text('Düello cevapları'), findsOneWidget);
    expect(find.text('1/2 doğru'), findsOneWidget);
    expect(find.text('1. Başkent?'), findsOneWidget);
    expect(find.text('Sen'), findsOneWidget);
    expect(find.text('Rakip'), findsOneWidget);
    expect(find.text('Bu soruyu cevaplamadın.'), findsOneWidget);
  });

  testWidgets('liderlikten başkasının profili: kozmetik ve sıralamalar', (tester) async {
    final frame = MarketItem(
      id: 'f',
      name: 'Altın çerçeve',
      category: 'frame',
      color: '#FFC107',
      price: 300,
      currency: 'SP',
      active: true,
    );
    await pumpApp(
      tester,
      userId: 'u1',
      profile: _profile,
      leaderboard: (_) => const [
        LeaderboardRow(rank: 1, userId: 'u2', firstName: 'Mert', lastName: 'Kaya', value: 0.8, sample: 5),
      ],
      publicProfiles: {
        'u2': PublicProfile(
          id: 'u2',
          firstName: 'Mert',
          lastName: 'Kaya',
          department: 'Fizik',
          schoolName: 'Örnek Üniversitesi',
          level: 7,
          deleted: false,
          cosmetics: Cosmetics(frame: frame),
          standings: const [
            Standing(metric: LeaderboardMetric.hitRate, allTime: false, rank: 1, value: 0.8, sample: 5),
          ],
        ),
      },
    );
    await tester.tap(find.text('Liderlik'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Mert K.'));
    await tester.pumpAndSettle();

    expect(find.text('Mert Kaya'), findsOneWidget);
    expect(find.text('Örnek Üniversitesi · Fizik · Seviye 7'), findsOneWidget);
    expect(find.text('İsabet · Bu hafta'), findsOneWidget);
    expect(find.text('1. · %80'), findsOneWidget);
  });

  testWidgets('sosyal bahis açarken başka hakem seçilir', (tester) async {
    await pumpApp(
      tester,
      userId: 'u1',
      profile: _profile,
      studentEmail: verified,
      people: const [
        Person(id: 'u2', firstName: 'Veli', lastName: 'Demir'),
        Person(id: 'u3', firstName: 'Can', lastName: 'Demir', canReferee: false),
      ],
    );
    await tester.tap(find.text('Sosyal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sosyal bahis aç'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Hakem: ben'));
    await tester.tap(find.text('Hakem: ben'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Ad ya da soyad'), 'demir');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.textContaining('ihtar sınırında'), findsOneWidget);
    expect(tester.widget<ListTile>(find.widgetWithText(ListTile, 'Can Demir')).enabled, isFalse);
    await tester.tap(find.text('Veli Demir'));
    await tester.pumpAndSettle();
    expect(find.text('Hakem: Veli Demir'), findsOneWidget);
  });

  testWidgets('geçmiş: açtığı ve hakemi olduğu bahisler, uzun listede daha fazla göster', (tester) async {
    final entry = (
      bet: prediction(status: 'settled', yesWins: true),
      wager: const Wager(betId: 'p1', optionId: 'y', amount: 30, payout: 37),
    );
    await pumpApp(
      tester,
      userId: 'u1',
      profile: _profile,
      history: List.filled(HistoryLimit.pageSize + 1, entry),
      ownBets: [socialBet(status: 'cancelled', refereeId: 'u1')],
    );
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    final profileList = find.descendant(of: find.byType(ProfileTab), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Çıkış yap'), 200, scrollable: profileList);
    await tester.tap(find.text('Geçmiş bahislerim'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Daha fazla göster'), 400);
    expect(find.text('Daha fazla göster'), findsOneWidget);

    await tester.tap(find.text('Açtıklarım'));
    await tester.pumpAndSettle();
    expect(find.text('Yarın yemekhanede pilav çıkar mı?'), findsOneWidget);
    expect(find.textContaining('Açtın, Hakemsin · İptal'), findsOneWidget);
  });

  testWidgets('seviye atlayınca kutlama çıkar', (tester) async {
    var progress = const Progress(xp: 190, level: 2, levelXp: 100, nextLevelXp: 300, pickXpToday: 0);
    await pumpApp(tester, userId: 'u1', profile: _profile, progressNow: () => progress);
    expect(find.text('Seviye 3!'), findsNothing);

    progress = const Progress(xp: 310, level: 3, levelXp: 300, nextLevelXp: 600, pickXpToday: 15);
    ProviderScope.containerOf(tester.element(find.byType(NavigationBar))).invalidate(myProgressProvider);
    await tester.pumpAndSettle();
    expect(find.text('Seviye 3!'), findsOneWidget);
    await tester.tap(find.text('Tamam'));
    await tester.pumpAndSettle();
    expect(find.text('Seviye 3!'), findsNothing);
  });

  testWidgets('başarımlar: profilde sayı, ekranda hazır ödül, kademe, gizli başarım ve nadirlik', (tester) async {
    await pumpApp(
      tester,
      userId: 'u1',
      profile: _profile,
      achievements: [
        Achievement(
          key: 'kampuslu',
          category: 'progress',
          title: 'Kampüslü',
          description: 'Okul mailini doğrula.',
          icon: '🎓',
          tier: 1,
          target: 1,
          progress: 1,
          rewardSp: 20,
          rewardXp: 10,
          unlockedAt: DateTime.utc(2026, 11, 22, 9),
          schoolRate: 0.25,
        ),
        const Achievement(
          key: 'ilk_tahmin',
          category: 'prediction',
          title: 'İlk Adım',
          description: 'İlk tahminin sonuçlansın.',
          icon: '🎯',
          tier: 1,
          target: 1,
          progress: 1,
          rewardSp: 20,
          rewardXp: 10,
          claimable: true,
        ),
        const Achievement(
          key: 'muneccim',
          category: 'prediction',
          title: 'Müneccim',
          description: '150 tahmini doğru bil.',
          icon: '🔮',
          tier: 3,
          target: 150,
          progress: 12,
          rewardSp: 300,
          rewardXp: 120,
        ),
        const Achievement(
          key: 'ters_kose',
          category: 'secret',
          title: 'Gizli başarım',
          description: 'Kazanınca ne olduğu açılır.',
          icon: '❓',
          tier: 2,
          target: 1,
          progress: 0,
          rewardSp: 100,
          rewardXp: 50,
          hidden: true,
        ),
      ],
    );
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    final profileList = find.descendant(of: find.byType(ProfileTab), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Başarımlar'), 200, scrollable: profileList);
    expect(find.text('1 / 4 kazanıldı · 1 ödül hazır'), findsOneWidget);
    await tester.ensureVisible(find.text('Başarımlar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Başarımlar'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 4 başarım'), findsOneWidget);
    expect(find.text('Ödülün hazır'), findsOneWidget);
    expect(find.text('İlk Adım'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Ödülü al'), findsOneWidget);
    expect(find.text('Altın'), findsOneWidget);
    expect(find.textContaining('12 / 150'), findsOneWidget);
    expect(find.textContaining('okulda kazanan %25'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Gizli başarım'), 200);
    expect(find.text('Kazanınca ne olduğu açılır.'), findsOneWidget);
    expect(find.textContaining('0 / 1'), findsNothing);
  });

  testWidgets('yeni başarım haberi: açılışta bekleyen ödül, sonra yeni kazanılan', (tester) async {
    Achievement ach(String key, String title, {bool claimable = false}) => Achievement(
      key: key,
      category: 'prediction',
      title: title,
      description: 'Açıklama.',
      icon: '🎯',
      tier: 1,
      target: 1,
      progress: claimable ? 1 : 0,
      rewardSp: 20,
      rewardXp: 10,
      claimable: claimable,
    );
    var list = [ach('ilk_tahmin', 'İlk Adım', claimable: true), ach('keskin_goz', 'Keskin Göz')];
    await pumpApp(tester, userId: 'u1', profile: _profile, achievementsNow: () => list);
    expect(find.text('🏆 Yeni başarım: 🎯 İlk Adım. Ödülünü al!'), findsOneWidget);
    tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).clearSnackBars();
    await tester.pumpAndSettle();

    // İlerleme yeniden okununca yalnızca yeni kazanılan duyurulur.
    list = [ach('ilk_tahmin', 'İlk Adım', claimable: true), ach('keskin_goz', 'Keskin Göz', claimable: true)];
    ProviderScope.containerOf(tester.element(find.byType(NavigationBar))).invalidate(achievementsProvider);
    await tester.pumpAndSettle();
    expect(find.text('🏆 Yeni başarım: 🎯 Keskin Göz. Ödülünü al!'), findsOneWidget);

    await tester.tap(find.text('Gör'));
    await tester.pumpAndSettle();
    expect(find.text('Ödülün hazır'), findsOneWidget);
  });

  test('başarım haberi metni', () {
    const a = Achievement(
      key: 'a', category: 'duel', title: 'A', description: 'd', icon: '⚔️', tier: 1, target: 1, progress: 1,
      rewardSp: 1, rewardXp: 0, claimable: true,
    );
    const b = Achievement(
      key: 'b', category: 'duel', title: 'B', description: 'd', icon: '🤺', tier: 1, target: 1, progress: 1,
      rewardSp: 1, rewardXp: 0, claimable: true,
    );
    expect(newAchievementMessage(null, [a, b], firstLoadAnnounced: false), '🏆 2 başarımın ödülü hazır!');
    expect(newAchievementMessage(null, [a, b], firstLoadAnnounced: true), isNull);
    expect(newAchievementMessage([a, b], [a, b], firstLoadAnnounced: true), isNull);
  });

  test('yardımcılar: hesap engeli, kozmetik anahtarı, İstanbul haftası', () {
    expect(isAccountBlocked(const PostgrestException(message: 'x', code: 'KB025')), isTrue);
    expect(isAccountBlocked(const PostgrestException(message: 'x', code: 'KB001')), isFalse);
    expect(isAccountBlocked(Exception('x')), isFalse);
    expect(cosmeticsKey(['b', null, 'a', 'b']), 'a,b');
    // Pazar 23:30 UTC = pazartesi 02:30 İstanbul: yeni hafta.
    expect(istanbulWeekStart(DateTime.utc(2026, 11, 22, 23, 30)), DateTime.utc(2026, 11, 23));
    expect(istanbulWeekStart(DateTime.utc(2026, 11, 22, 12)), DateTime.utc(2026, 11, 16));
  });

  test('sonuç metni: kazanç, kazançsız doğru tahmin, kazanan çıkmayınca iade, kayıp', () {
    final yes = prediction(status: 'settled', yesWins: true);
    const evet = BetOption(id: 'y', label: 'Evet', position: 1, isWinner: true);
    const hayir = BetOption(id: 'n', label: 'Hayır', position: 2, isWinner: false);
    expect(wagerText(yes, const Wager(betId: 'p1', optionId: 'y', amount: 30, payout: 37), evet),
        'Kazandın: net +7 SP · 37 SP aldın (30 SP · Evet)');
    expect(wagerText(yes, const Wager(betId: 'p1', optionId: 'y', amount: 30, payout: 30), evet),
        'Doğru bildin ama kazanç çıkmadı: yatırımın (30 SP · Evet) geri döndü.');
    expect(wagerText(yes, const Wager(betId: 'p1', optionId: 'n', amount: 30, payout: 30), hayir),
        'Kazanan tarafa kimse yatırmadığı için yatırımın (30 SP · Hayır) iade edildi.');
    expect(wagerText(yes, const Wager(betId: 'p1', optionId: 'n', amount: 30, payout: 0), hayir), 'Kaybettin (30 SP · Hayır).');
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
