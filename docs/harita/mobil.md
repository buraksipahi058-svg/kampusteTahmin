# Bölge: Mobil (Flutter)

Öğrenci uygulaması. Şu an yalnızca `flutter create` iskeleti var (demo sayaç ekranı). Sıradaki adım (4) burada.

Kod: `mobile/`. Uygulama kimliği `com.kampusbet.kampusbet` (yayından önce değiştirilebilir).
Platformlar: android, ios, web (web yalnızca hızlı önizleme için). iOS derlemesi Mac ister; v1 Android öncelikli (öneri, onay bekliyor).

## Çalıştırma

```bash
cd mobile
flutter run -d emulator-5554          # önce emülatör: Android Studio > Device Manager > kampusbet_pixel
flutter build apk --debug
flutter analyze
flutter test
```

Emülatörü komut satırından açmak: `%LOCALAPPDATA%\Android\Sdk\emulator\emulator.exe -avd kampusbet_pixel`.
Ekran görüntüsü: `adb shell screencap -p /sdcard/x.png` + `adb pull`.

## Adım 4 planı (henüz başlanmadı)

- Paketler: `supabase_flutter`, Riverpod (MIMARI §9 önerisi), yönlendirme için `go_router`.
- Yapılandırma: Supabase URL + publishable key, git'e girmeyen bir dosyadan (`--dart-define-from-file`); secret key asla.
- Akış: e-posta ile kayıt/giriş (Supabase Auth, mail onayı açık) → profili yoksa profil oluşturma ekranı (okul listesi `clusters where type = 'school'`, `create_profile`) → sekmeler (Bahisler, Oyunlar, Market, Liderlik, Profil — çoğu şimdilik boş) → bakiye göstergesi (`balances`) → açılışta `claim_daily_login()`.
- Hata kodlarını kullanıcı diline çeviren tek bir eşleme (kodlar: [veritabani.md](veritabani.md)).
- Görünen uygulama adı tek bir yerde tutulmalı ("bahis" adı riski, KARARLAR öneri 6).

## Dikkat

- Para mantığı istemcide **hesaplanmaz**; bakiye, havuz ve sonuçlar her zaman sunucudan okunur.
- Supabase Auth'ta "Confirm email" açık olmalı (bulut varsayılanı); `create_profile` onaysız oturumu reddeder.
