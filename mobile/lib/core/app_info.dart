/// Uygulamanın görünen adı yalnızca burada tutulur (KARARLAR öneri 6: ad değişebilir).
///
/// Platformların başlatıcı etiketleri Dart'tan okunamadığı için aynı ad şu dosyalara da
/// yazılıdır; `test/app_info_test.dart` hepsinin buradaki adla aynı kaldığını denetler:
/// - `android/app/src/main/AndroidManifest.xml` (`android:label`)
/// - `ios/Runner/Info.plist` (`CFBundleDisplayName`)
/// - `web/index.html` (`<title>`, `apple-mobile-web-app-title`), `web/manifest.json` (`name`, `short_name`)
abstract final class AppInfo {
  static const name = 'KampüsBet';
}
