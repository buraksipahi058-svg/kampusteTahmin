# Bölge: Mobil (Flutter)

Öğrenci uygulaması. Adım 4'te temel kuruldu: giriş/kayıt, profil oluşturma, 5 sekme, bakiye, günlük ödül.

Kod: `mobile/`. Uygulama kimliği `com.kampusbet.kampusbet` (yayından önce değiştirilebilir).
Platformlar: android, ios, web (web yalnızca hızlı önizleme için). iOS derlemesi Mac ister; v1 Android öncelikli (öneri, onay bekliyor).
Paketler: `supabase_flutter` 2.18, `flutter_riverpod` 3.4, `go_router` 18, `http` (yalnızca ağ hatasını tanımak için).

## Çalıştırma (`mobile/` klasöründe)

```bash
flutter run -d emulator-5554 --dart-define-from-file=.env   # önce emülatör: Android Studio > Device Manager > kampusbet_pixel
flutter build apk --debug --dart-define-from-file=.env
flutter analyze
flutter test
```

`.env` git'e girmez: `SUPABASE_URL` + `SUPABASE_PUBLISHABLE_KEY` (örnek `.env.example`, değerler `admin/.env.local` ile aynı).
Bayrak unutulursa uygulama "Supabase ayarları eksik" ekranı açar; secret key (`sb_secret_`) verilirse çalışmayı reddeder.

Emülatörü komut satırından açmak: `%LOCALAPPDATA%\Android\Sdk\emulator\emulator.exe -avd kampusbet_pixel`.
Ekran görüntüsü: `adb shell screencap -p /sdcard/x.png` + `adb pull`.

## Dosyalar (`mobile/lib/`)

| Dosya | Ne yapar |
|---|---|
| `main.dart`, `app.dart` | Yapılandırma denetimi, `Supabase.initialize`, `ProviderScope` (Riverpod'un kendiliğinden yeniden denemesi kapalı), tema |
| `core/app_info.dart` | **Görünen ad tek yerde** (`AppInfo.name`). Android/iOS/web dosyalarındaki ad `test/app_info_test.dart` ile denetlenir |
| `core/env.dart` | `--dart-define-from-file` değerleri |
| `core/error_messages.dart` | **Tek hata eşlemesi**: `userMessage(hata)`; veritabanı kodları (KB001-006, 42501...) + Auth kodları + ağ hatası. Yeni SQLSTATE önce [veritabani.md](veritabani.md) tablosuna, sonra buraya; test ikisini karşılaştırır |
| `core/supabase.dart` | `supabaseProvider`, `currentUserIdProvider` (oturum değişince yenilenir) |
| `core/router.dart`, `routes.dart` | go_router; yönlendirme kuralı `redirectFor` (saf fonksiyon, testli) |
| `auth/auth_screen.dart` | E-posta + şifre giriş/kayıt, onay mailini yeniden gönderme |
| `profile/profile_data.dart` | `myProfileProvider`, `schoolsProvider`, `createProfile` (`public.create_profile`) |
| `profile/create_profile_screen.dart`, `profile_tab.dart` | Profil oluşturma; Profil sekmesi (kuşanılmış kozmetikler: çerçeve, isim rengi, unvan, rozet; okul maili; Görevler kartı + hazır ödül sayısı; bakiye, seri; seviye kartı; İstatistiklerim; Geçmiş bahislerim; Gizlilik ve KVKK; çıkış; Hesabımı sil) |
| `profile/student_email_data.dart` | `studentEmailProvider` (`profile_private`), `requestStudentEmailCode`, `confirmStudentEmail` |
| `profile/verify_email_screen.dart` | `/okul-maili`: mail → kod; okulun alan adını ipucu gösterir (profil sorgusu `school_email_domains`'i de çeker) |
| `wallet/wallet_data.dart` | `balanceProvider`, `loginStreakProvider`, `dailyRewardProvider` (`claim_daily_login`), `formatAmount` |
| `wallet/balance_bar.dart` | Üst çubukta SP / SSP; dokununca yenilenir |
| `home/home_shell.dart` | Alt sekmeler (`homeTabs`), günlük ödül bildirimi; boş sekmeler `placeholder_tab.dart` |
| `bets/bets_data.dart` | `Bet` (`settlementMode`: günün tahmini / düello ayrımı), `BetOption`, `Wager`; `officialBetsProvider`, `socialBetsProvider`, `dailyPredictionsProvider`, `myWagersProvider`, `placeWager` (`place_wager`), `potentialPayout` (bilgi için) |
| `bets/bets_tab.dart` | Bahisler sekmesi: "Resmi / Sosyal" seçici; resmi bahis kartı (oran, kapanış İstanbul saati, kişinin yatırımı / sonucu), yatırım alt sayfası (oranlı ya da havuz); doğrulanmamışsa uyarı |
| `bets/social_bet_card.dart` | Sosyal bahis kartı: havuz miktarları, hakem; duruma göre "Sonucu gir" (hakem), "İtiraz et" (katılımcı, pencere içinde), "Geri çek" (açan, yatırım yokken) |
| `games/trivia_data.dart` | `TriviaDuel`, `DuelPlay`, `triviaDuelsProvider`, `duelGameProvider(betId)` (`start_trivia_duel`), `createDuel`, `acceptDuel`, `submitAnswers` |
| `games/games_tab.dart` | Oyunlar sekmesi: üstte günün tahmini kartları (`dailyPredictionsProvider`, `bets_data.dart`'ta), altta "Meydan oku" (tutar) ve düello kartları ("Kabul et", "Oyna", sonuç — kazanan kişinin yatırımının ödemesinden okunur) |
| `games/daily_prediction_card.dart` | Günün tahmini kartı: Evet / Hayır havuzları, dokununca `WagerSheet` (havuz kipi, `place_wager`), sonuç metni `wagerText` (bets_tab ile ortak) |
| `games/duel_play_screen.dart` | `/duello/:id`: sorular sırayla, geri sayım (sunucunun kalan süresi), süre bitince ya da son soruda gönderir |
| `market/market_data.dart` | `MarketItem`, `OwnedItem`, `Cosmetics`; `marketItemsProvider` (satıştakiler, ucuzdan pahalıya), `myInventoryProvider`, `myCosmeticsProvider` (kuşanılmışlar), `purchaseItem`, `setItemEquipped` |
| `market/market_tab.dart` | Market sekmesi: "SP vitrini / SSP özel"; ürün kartı (önizleme, fiyat düğmesi → onay penceresi; sahipse "Kuşan" / "Çıkar"; satış başlamadıysa "Yakında"; seviye yetmiyorsa kilitli "Seviye N") |
| `market/cosmetic_preview.dart` | `CosmeticPreview` (simge / çerçeve / isim rengi), `ProfileAvatar` (baş harfler + çerçeve ürünü ya da yalnızca rengi `frameColor`; `hexColor` `market_data.dart`'ta) |
| `quests/quests_data.dart` | `Quest`, `questsProvider` (`my_quests`), `claimQuest` (`claim_quest_reward`) |
| `quests/quests_screen.dart` | `/gorevler`: Günlük / Haftalık / Sezonluk; ödül ("+30 SP · +20 XP"), ilerleme çubuğu, "Ödülü al", "Alındı", yenilenme zamanı |
| `leaderboard/leaderboard_data.dart` | `LeaderboardMetric` / `LeaderboardPeriod`, `leaderboardQueryProvider` (seçili ölçüt + dönem, Notifier), `leaderboardProvider` (`get_leaderboard`), `leaderboardMinimumsProvider` (isabet eşiği, ekonomi ayarı), `MyStats` + `myStatsProvider` (`my_stats`) |
| `leaderboard/leaderboard_tab.dart` | Liderlik sekmesi: "Bu hafta / Geçen hafta / Tüm zamanlar", ölçüt çipleri (İsabet, Kazanç, Seri, SSP), satırda madalya, çerçeveli avatar, isim rengi + rozet, seviye ("Sv. N"), unvan; kişinin satırı vurgulu, ilk 50 dışındaysa "⋯" ile sonda; son hesaplama zamanı |
| `leaderboard/my_stats_card.dart` | Profil'de "İstatistiklerim": bu haftaki sıralar, isabet, doğru tahmin serisi, net kazanç, düello, sonucu bekleyen yatırım |
| `profile/history_screen.dart` | `/gecmis`: son 100 yatırım (`myWagerHistoryProvider`, `bets_data.dart`; `wagers` + `bets!bet_id` gömmesi), tür, durum, `wagerText` sonucu |
| `progress/progress_data.dart` | `Progress` + `myProgressProvider` (`my_progress`), `xpRulesProvider` (ekonomi ayarları), `xpEventsProvider` (son 20 XP olayı), `refreshProgress` (giriş ödülü, görev, bahis sonrası) |
| `progress/level_card.dart` | Profil'de "Seviye N", ilerleme çubuğu, sonraki seviyeye kalan XP; dokununca kök navigator'da XP kuralları ve son kazançlar sayfası |
| `legal/privacy_screen.dart` | `/kvkk`: KVKK aydınlatma metni, `assets/legal/kvkk_aydinlatma.txt`'ten (tek kaynak; `# ` / `## ` / `- ` biçimi). Girişten önce de açılır (`redirectFor`), kayıt ekranında ve Profil'de bağlantısı var |
| `profile/delete_account.dart` | "Hesabımı sil": onay penceresi (kutu işaretlenmeden düğme kapalı), `delete_my_account`, yerel çıkış |
| `bets/create_social_bet_screen.dart` | `/sosyal-bahis-ac`: soru, 2–4 seçenek, kapanış (tarih + saat seçici), kişi başı en fazla (≤ 100); okul kümesinde açar (`Profile.schoolId`) |

## Akış

Oturum yok → `/giris`. Oturum var, profil sorgusu sürüyor → `/yukleniyor` (hata olursa "Tekrar dene").
Profil yok → `/profil-olustur` (okullar `clusters where type = 'school'`). Profil var → `/bahisler` ve diğer sekmeler.
Kabuk açılınca `claim_daily_login()` bir kez çağrılır; ödül alındıysa bildirim + bakiye/seri sunucudan yeniden okunur.
Sağlayıcılar `currentUserIdProvider`'a bağlı: çıkış/giriş olunca kendiliğinden yeniden çalışır.

## Testler (`mobile/test/`, 41)

`app_test.dart` `pumpApp` test ekranını telefon boyutuna (1080×2400, dpr 2.625) ayarlar; varsayılan 800×600'de
düğmeler görünür alanın dışında kalır, ayrıca alttaki günlük ödül bildirimi düğmeleri örtebilir.
Profil uzun: alttaki öğeye dokunmadan önce `scrollUntilVisible` ile en alttaki "Çıkış yap"a kadar kaydır
(yoksa öğe alt menünün arkasında kalır, dokunuş boşa gider). Liderlik sağlayıcısı testte seçili sorguyu izleyen
bir fonksiyonla değiştirilir (`pumpApp(leaderboard: ...)`).


`error_messages_test` (eşleme + veritabani.md uyumu), `app_info_test` (platform adları), `router_test`
(yönlendirme kuralları), `app_test` (sağlayıcılar sabit değerle değiştirilerek ekranlar; Supabase'e bağlanmaz).

## Dikkat

- **Toplu `dart format` çalıştırma:** bu SDK'nın biçimlendiricisi mevcut kodu (elle ~120 sütun) farklı biçimliyor, ilgisiz dosyalarda gürültü çıkar. Yalnızca yeni dosyaları biçimle.
- Alt sayfa (`showModalBottomSheet`) sekme içinden açılınca alt menünün arkasında kalır; `useRootNavigator: true` ver.
- Para mantığı istemcide **hesaplanmaz**; bakiye, seri, ödül ve sonuçlar her zaman sunucudan okunur.
- Sonuç metni `wagerText` (bets_tab) üç durumu ayırır: kazanç, ödeme = yatırım ("kazanç çıkmadı"), seçilen taraf kaybettiği halde ödeme var (kazanan tarafa kimse yatırmadı → iade).
- Dart istemcisinde (postgrest-dart) `.order()` varsayılanı **azalan** (JS'tekinin tersi); artan sıra için `ascending: true` yaz.
- Supabase Auth'ta "Confirm email" açık (bulut varsayılanı): kayıttan sonra oturum gelmez, kullanıcı mailindeki linke tıklayıp giriş yapar.
- Onay linki şimdilik Supabase'in Site URL'sine gider (uygulamayı açmaz); deep link ileride (Redirect URLs + Android intent filter).
- Günlük ödül yalnızca açılışta/girişte istenir; uygulama arka planda gece yarısını geçerse ertesi açılışta alınır.
- Yeni sekme sayfası: `homeTabs`'ta ilgili sekmeye `page:` ver.
- Sorguda `clusters` gömülürken ilişki belirtilmeli: `profiles` ile `clusters` arasında üç yol var (`school_id`, `user_clusters`, `permissions`); `clusters(name)` yerine `clusters!school_id(name)`, yoksa PostgREST `PGRST201` verir.
- Eşlenmemiş hatalar kullanıcıya "Bir şeyler ters gitti" olarak görünür; ayrıntısı debug derlemede `adb logcat -s flutter` içinde "Eşlenmemiş hata:" satırında.
- Emülatörde test hesabı: kullanıcının kendi e-postası, profil "Test Test" / Örnek Üniversitesi (1000 başlangıç + 50 günlük SP).
