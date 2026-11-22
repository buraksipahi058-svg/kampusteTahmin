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
| `profile/create_profile_screen.dart`, `profile_tab.dart` | Profil oluşturma; Profil sekmesi (okul maili durumu, bakiye, seri, seviye, çıkış) |
| `profile/student_email_data.dart` | `studentEmailProvider` (`profile_private`), `requestStudentEmailCode`, `confirmStudentEmail` |
| `profile/verify_email_screen.dart` | `/okul-maili`: mail → kod; okulun alan adını ipucu gösterir (profil sorgusu `school_email_domains`'i de çeker) |
| `wallet/wallet_data.dart` | `balanceProvider`, `loginStreakProvider`, `dailyRewardProvider` (`claim_daily_login`), `formatAmount` |
| `wallet/balance_bar.dart` | Üst çubukta SP / SSP; dokununca yenilenir |
| `home/home_shell.dart` | Alt sekmeler (`homeTabs`), günlük ödül bildirimi; boş sekmeler `placeholder_tab.dart` |
| `bets/bets_data.dart` | `Bet`, `BetOption`, `Wager`; `officialBetsProvider`, `myWagersProvider`, `placeWager` (`place_wager`), `potentialPayout` (bilgi için) |
| `bets/bets_tab.dart` | Bahisler sekmesi: resmi bahisler (oran, kapanış İstanbul saati, kişinin yatırımı / sonucu), yatırım alt sayfası; doğrulanmamışsa uyarı |

## Akış

Oturum yok → `/giris`. Oturum var, profil sorgusu sürüyor → `/yukleniyor` (hata olursa "Tekrar dene").
Profil yok → `/profil-olustur` (okullar `clusters where type = 'school'`). Profil var → `/bahisler` ve diğer sekmeler.
Kabuk açılınca `claim_daily_login()` bir kez çağrılır; ödül alındıysa bildirim + bakiye/seri sunucudan yeniden okunur.
Sağlayıcılar `currentUserIdProvider`'a bağlı: çıkış/giriş olunca kendiliğinden yeniden çalışır.

## Testler (`mobile/test/`, 22)

`error_messages_test` (eşleme + veritabani.md uyumu), `app_info_test` (platform adları), `router_test`
(yönlendirme kuralları), `app_test` (sağlayıcılar sabit değerle değiştirilerek ekranlar; Supabase'e bağlanmaz).

## Dikkat

- Para mantığı istemcide **hesaplanmaz**; bakiye, seri, ödül ve sonuçlar her zaman sunucudan okunur.
- Supabase Auth'ta "Confirm email" açık (bulut varsayılanı): kayıttan sonra oturum gelmez, kullanıcı mailindeki linke tıklayıp giriş yapar.
- Onay linki şimdilik Supabase'in Site URL'sine gider (uygulamayı açmaz); deep link ileride (Redirect URLs + Android intent filter).
- Günlük ödül yalnızca açılışta/girişte istenir; uygulama arka planda gece yarısını geçerse ertesi açılışta alınır.
- Yeni sekme sayfası: `homeTabs`'ta ilgili sekmeye `page:` ver.
- Sorguda `clusters` gömülürken ilişki belirtilmeli: `profiles` ile `clusters` arasında üç yol var (`school_id`, `user_clusters`, `permissions`); `clusters(name)` yerine `clusters!school_id(name)`, yoksa PostgREST `PGRST201` verir.
- Eşlenmemiş hatalar kullanıcıya "Bir şeyler ters gitti" olarak görünür; ayrıntısı debug derlemede `adb logcat -s flutter` içinde "Eşlenmemiş hata:" satırında.
- Emülatörde test hesabı: kullanıcının kendi e-postası, profil "Test Test" / Örnek Üniversitesi (1000 başlangıç + 50 günlük SP).
