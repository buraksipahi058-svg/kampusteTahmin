/// Uygulamanın görünen adı yalnızca burada tutulur (KARARLAR öneri 6: ad değişebilir).
///
/// Platformların başlatıcı etiketleri Dart'tan okunamadığı için aynı ad şu dosyalara da
/// yazılıdır; `test/app_info_test.dart` hepsinin buradaki adla aynı kaldığını denetler:
/// - `android/app/src/main/AndroidManifest.xml` (`android:label`)
/// - `ios/Runner/Info.plist` (`CFBundleDisplayName`)
/// - `web/index.html` (`<title>`, `apple-mobile-web-app-title`), `web/manifest.json` (`name`, `short_name`)
///
/// E-posta linklerinin (kayıt onayı, şifre sıfırlama) uygulamayı açtığı adres de burada; şeması
/// `AndroidManifest.xml` (intent-filter) ve `Info.plist`'te (CFBundleURLSchemes) yazılı, aynı test denetler.
/// Supabase Auth'ta "Redirect URLs" listesinde `$authScheme://**` olmalı (docs/harita/yayin.md).
abstract final class AppInfo {
  static const name = 'KampüsBet';
  static const authScheme = 'com.kampusbet.kampusbet';
  static const authCallbackHost = 'giris-callback';
  static const authRedirectUrl = '$authScheme://$authCallbackHost';

  /// Kayıtta kabul edilen kullanım koşullarının sürümü (`assets/legal/kullanim_kosullari.txt` "Sürüm:" satırı;
  /// test denetler). Supabase Auth kullanıcı metadatasına `terms_version` olarak yazılır.
  static const termsVersion = '2026-11-23';

  /// "Nasıl oynanır" öğreticisinin sürümü. Supabase Auth kullanıcı metadatasına `tutorial_version` olarak yazılır;
  /// öğreticinin içeriği belirgin değişirse artırılır, herkese bir kez daha kendiliğinden gösterilir.
  static const tutorialVersion = 1;
}
