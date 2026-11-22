# Bölge: Yayın (canlıya geçiş)

Adım 12'de hazırlandı: e-posta linklerinin uygulamayı açması, şifre sıfırlama, Android yayın derlemesi ve imza
ayarı, mağaza için herkese açık gizlilik / hesap silme sayfaları, Türkçe e-posta şablonları ve bu rehber.
Kurallar: KARARLAR "Yayına hazırlık". Kullanıcının yapacakları [acik-isler](acik-isler.md)'de.

## Uygulamada hazır olanlar

| Konu | Nerede |
|---|---|
| E-posta linkleri uygulamayı açar: `com.kampusbet.kampusbet://giris-callback` (PKCE; Supabase oturumu kendisi alır) | `AppInfo.authRedirectUrl`; Android intent-filter, iOS `CFBundleURLTypes`; Flutter'ın kendi derin bağlantısı kapalı (go_router'a gitmez) |
| Kayıt ve "onay mailini yeniden gönder" linki bu adrese döner | `auth_screen.dart` (`emailRedirectTo`) |
| "Şifremi unuttum": link telefonda açılınca oturum başlar, yeni şifre Profil > "Şifreyi değiştir" (`/sifre`) | `auth_screen.dart`, `profile/change_password_screen.dart` |
| Yayın imzası: `android/key.properties` varsa onunla, yoksa debug anahtarıyla (uyarı basar; mağazaya yüklenemez) | `android/app/build.gradle.kts`, örnek `android/key.properties.example` |
| R8 kuralları (release'te açılışta takılmayı önler) | `android/app/proguard-rules.pro` |
| Gizlilik ve hesap silme sayfaları, oturumsuz | admin `/gizlilik`, `/hesap-silme` (`proxy.ts` `PUBLIC_PATHS`) |
| Türkçe e-posta şablonları | `supabase/templates/onay.html`, `sifre_sifirlama.html` |

## Canlıya geçiş sırası

1. **Kararlar:** uygulama adı ve kimliği (`com.kampusbet.kampusbet` mağazaya ilk yüklemeden sonra değişmez; KARARLAR
   öneri 6-7), ikon, gerçek okul adı + öğrenci mail alan adı, KVKK metnindeki boşluklar, ekonomi / XP rakamları.
2. **Canlı Supabase projesi** (geliştirme projesinden ayrı; bölge Frankfurt):
   - `npx supabase link --project-ref <canlı-ref>` → `npx supabase db push` (tüm migration'lar). Seed yerine gerçek okul
     ve alan adı SQL ile (seed'deki "Örnek Üniversitesi" ve deneme verisi canlıya girmez).
   - `private.mail_settings`'i `brevo` yap, anahtarı Vault'a koy ([kimlik](kimlik.md)).
   - İlk süperadmin: KARARLAR "İlk süperadmini atama".
   - `npm run db:test` canlıya karşı **çalıştırılmaz** (test verisi geri alınsa da); geliştirme projesinde çalışır.
     Yalnızca `npx supabase db advisors --linked --type security` bakılır.
   - Geliştirme projesine dönmek: `npx supabase link --project-ref uofbwsdkwwlznvtttkhj`.
3. **Supabase Auth ayarları** (Dashboard → Authentication):
   - URL Configuration: Site URL = admin'in adresi (`https://<admin-alan-adı>`); Redirect URLs'e
     `com.kampusbet.kampusbet://**` ekle (yoksa linkler Site URL'ye gider, uygulama açılmaz).
   - Email: "Confirm email" açık; şablonlar `supabase/templates/` (Confirm signup, Reset password), konular dosyaların
     ilk satırında.
   - **Özel SMTP şart:** Supabase'in yerleşik maili saatte çok az mail gönderir. Brevo SMTP bilgileri girilir
     (aynı Brevo hesabı okul maili kodları için de kullanılır).
   - Leaked password protection açık (planda varsa), en az şifre uzunluğu 8.
4. **Admin paneli yayını** (ör. Vercel, kök klasör `admin/`): ortam değişkenleri `NEXT_PUBLIC_SUPABASE_URL`,
   `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` (canlı projenin). Secret key **verilmez**. Alan adı → mağaza bağlantıları:
   `https://<admin-alan-adı>/gizlilik`, `https://<admin-alan-adı>/hesap-silme`.
5. **Android yükleme anahtarı** (bir kez; anahtar ve şifreler repoya girmez, kaybedilmemeli):
   ```bash
   keytool -genkey -v -keystore C:/Users/<kullanıcı>/kampusbet-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
   `android/key.properties.example`'ı `android/key.properties` olarak kopyalayıp doldur. Play Console'da "Play App
   Signing" açık kalsın (Google asıl imzayı tutar; yükleme anahtarı kaybolursa sıfırlanabilir).
6. **Mobil derleme** (`mobile/` içinde, canlı projenin değerleriyle `.env.prod`):
   ```bash
   flutter build appbundle --release --dart-define-from-file=.env.prod   # build/app/outputs/bundle/release/app-release.aab
   flutter build apk --release --dart-define-from-file=.env.prod         # cihazda denemek için
   ```
   Her yüklemede `pubspec.yaml` `version: x.y.z+n`'de `n` artar. Release APK emülatörde açılıp denenir
   (R8 sorunları yalnızca release'te çıkar).
7. **Play Console** (geliştirici hesabı kullanıcının):
   - Gizlilik politikası ve hesap silme bağlantıları (4. madde).
   - Veri güvenliği formu (taslak): toplanan — ad, e-posta, kullanıcı kimliği, uygulama içi etkileşimler; paylaşılan —
     yok (Supabase ve mail sağlayıcısı veri işleyen); aktarımda şifreli — evet; silme — uygulama içinden ve bağlantıyla.
   - İçerik derecelendirmesi: sanal (simüle) bahis içerir, gerçek para yok → anket buna göre doldurulur; hedef kitle
     yetişkin üniversite öğrencileri.
   - Uygulama erişimi: inceleme ekibi okul maili doğrulayamaz → doğrulanmış bir **demo hesap** (e-posta + şifre)
     verilmeli.
8. **iOS:** Mac ve Apple geliştirici hesabı gerekir; URL şeması `Info.plist`'te hazır.

## Denenen (2026-11-22, geliştirme projesi)

- Release APK (debug anahtarıyla) emülatörde: link şemasıyla açıldı, oturum geldi, veriler yüklendi.
- AAB derlemesi tamam (53 MB).
- `/gizlilik`, `/hesap-silme` oturumsuz açılıyor; panel sayfaları girişe yönleniyor.
