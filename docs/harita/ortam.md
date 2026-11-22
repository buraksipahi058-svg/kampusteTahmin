# Bölge: Ortam

Araçlar, komutlar ve tuzaklar. Her şey Windows'ta çalışır (eski 192.168.1.13 hostu bu projede kullanılmaz).

## Araçlar

| Araç | Yer / sürüm | Not |
|---|---|---|
| Flutter | 3.47.7, `C:\Users\burak\dev\flutter` (kullanıcı PATH'inde) | Analitik kapalı. `flutter config --jdk-dir` = Android Studio'nun `jbr`'si |
| Android Studio | `C:\Program Files\Android\Android Studio` | JDK: `...\jbr` (OpenJDK 25) |
| Android SDK | `%LOCALAPPDATA%\Android\Sdk` (`ANDROID_HOME`) | platform 36, build-tools 37, NDK 28.2.13676358 |
| Emülatör | AVD `kampusbet_pixel` (Android 36, Pixel 7) | WHPX hızlandırma çalışıyor. Bilgisayar klavyesi fiziksel klavye sayılır: ekran klavyesi yerine küçük araç çubuğu çıkar, doğrudan bilgisayardan yazılır |
| Node / npm | 24 / 11 | |
| Supabase CLI | 2.121, kökte npm devDependency | `npx supabase ...` kökten çalıştırılır |
| Docker Desktop | kurulu | Yalnızca `supabase test db` için açık olmalı |

## Supabase Cloud

- Proje ref: `uofbwsdkwwlznvtttkhj` — URL `https://uofbwsdkwwlznvtttkhj.supabase.co`, bölge Frankfurt.
- CLI'a kullanıcı giriş yaptı (`supabase login`) ve projeyi bağladı (`supabase link`); bağlantı `supabase/.temp/` içinde (git'e girmez).
- Tek proje var: geliştirme ve ileride canlı aynı proje. Canlıya geçmeden önce ayrı proje düşünülmeli.
- **Ücretsiz plan bir hafta işlem olmazsa projeyi duraklatır** (`npx supabase projects list` → `INACTIVE`; CLI "Database is possibly not accessible"). Açmak kullanıcının işi: Dashboard → proje → "Restore project" (birkaç dakika sürer, veri kaybolmaz).

## Gizli bilgiler (hiçbiri repoda değil)

| Dosya | İçerik | Kim okur |
|---|---|---|
| `admin/.env.local` | `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | admin paneli |
| `.env.local` (kök) | `SUPABASE_DB_PASSWORD` (kullanıcının veritabanı şifresi) | yalnızca eşzamanlılık testleri; **okunmaz, yazdırılmaz** |

Secret / service role key hiçbir yerde kullanılmıyor.

## Sık komutlar (proje kökünde)

```bash
npx supabase db push              # yeni migration'ları buluta gönder
npx supabase db push --include-seed
npm run db:test                   # pgTAP testleri (Docker Desktop açık olmalı)
npm run db:test:concurrency       # eşzamanlılık testleri (~5 dk, .env.local şifresi gerekir)
npx supabase db query --linked "select ..."   # tek SQL (Docker gerekmez, postgres rolüyle)
npx supabase db advisors --linked --type security
npx supabase migration new <ad>   # yeni migration dosyası
```

Mobil ve admin komutları kendi bölgelerinde: [mobil.md](mobil.md), [admin.md](admin.md).

## Tuzaklar

- **Şifresiz CLI paralel çalıştırılmaz.** Her çağrı geçici `cli_login_postgres` rolünün şifresini yeniler; paralel çağrılar birbirini bozar (28P01) ve ~165 sn takılır. Paralellik gerekiyorsa `SUPABASE_DB_PASSWORD` ortamda olmalı (eşzamanlılık testleri bunu yapar).
- **`cli_login_postgres` postgres yetkilerini devralmaz** (NOINHERIT). Test dosyaları `set local role postgres;` ile başlar.
- **`db query --linked`** açık transaction'ları destekler, son sonuç kümesini döner, `postgres` rolüyle çalışır. Hata çıktısında SQLSTATE `ERROR:  22012: ...` biçiminde gelir.
- **sdkmanager** paket adlarını eğik çizgiyle ister (`platforms/android-36`, `ndk/28.2.13676358`); noktalı virgüllü eski adları hata vermeden atlar.
- **Önizleme aracı** (`preview_start`) bu oturumun eski klasörüne bakabilir; admin sunucusu gerekirse `npm --prefix admin run dev` ile başlatılıp `http://localhost:3000` açılır. `.claude/launch.json`'da `admin` tanımı var.
- **`adb` Bash aracının PATH'inde yok:** `"$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"` ile çağır (Git Bash'te `MSYS_NO_PATHCONV=1`). APK: `flutter build apk --debug --dart-define-from-file=.env` + `adb install -r build/app/outputs/flutter-apk/app-debug.apk`.
- **Emülatörde klavye açıkken `adb shell input swipe`** klavyenin üstüne denk gelirse kaydırmalı yazım olarak harf yazar; önce `input keyevent KEYCODE_BACK` ile klavyeyi kapat.
- **`adb shell input text`** Türkçe harf (ı, ş, ğ...) yazamaz (Java hatası verir); pano paylaşımı da güvenilir değil. Test verisinde ASCII kullan.
- **Release APK / AAB:** `flutter build apk --release --dart-define-from-file=.env` (≈80 sn, 55 MB), `flutter build appbundle --release ...` (`build/app/outputs/bundle/release/`). `android/key.properties` yoksa debug anahtarıyla imzalanır; aynı anahtarla imzalı debug kurulumunun üstüne `adb install -r` ile kurulur. Release'te Flutter logu: `adb logcat --pid=$(adb shell pidof com.kampusbet.kampusbet)`.
- **Linki emülatörde açmak:** `adb shell am start -a android.intent.action.VIEW -d "com.kampusbet.kampusbet://giris-callback"`.
- **İlk Flutter Android derlemesi** CMake 3.22.1'i SDK'ya kendisi kurar (bir kez, ~2 dk).
- **Supabase advisors** `public.rls_auto_enable()` için uyarı verir: Supabase'in kendi tetikleyici fonksiyonu, doğrudan çağrılamaz; dokunulmaz.
