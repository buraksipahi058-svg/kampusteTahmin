import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kampusbet/core/app_info.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  // Görünen ad tek yerde (AppInfo.name); platform dosyaları elle güncellenir, bu test unutulmasın diye.
  test('platform dosyalarındaki görünen ad AppInfo.name ile aynı', () {
    final name = AppInfo.name;
    expect(read('android/app/src/main/AndroidManifest.xml'), contains('android:label="$name"'));
    expect(
      read('ios/Runner/Info.plist'),
      matches(RegExp('<key>CFBundleDisplayName</key>\\s*<string>${RegExp.escape(name)}</string>')),
    );
    expect(read('web/index.html'), contains('<title>$name</title>'));
    expect(read('web/index.html'), contains('name="apple-mobile-web-app-title" content="$name"'));
    expect(read('web/manifest.json'), allOf(contains('"name": "$name"'), contains('"short_name": "$name"')));
  });

  // KVKK metni mobilde (asset) ve admin'in herkese açık /gizlilik sayfasında; iki kopya aynı kalmalı.
  test('KVKK metninin admin kopyası mobildekiyle aynı', () {
    expect(read('../admin/src/legal/kvkk_aydinlatma.txt'), read('assets/legal/kvkk_aydinlatma.txt'));
  });

  // Kullanım koşulları da admin'in herkese açık /kosullar sayfasında; kayıtta kabul edilen sürüm metindekiyle aynı.
  test('kullanım koşullarının admin kopyası aynı, sürümü AppInfo ile aynı', () {
    expect(read('../admin/src/legal/kullanim_kosullari.txt'), read('assets/legal/kullanim_kosullari.txt'));
    final [y, m, d] = AppInfo.termsVersion.split('-');
    expect(read('assets/legal/kullanim_kosullari.txt'), contains('Sürüm: $d.$m.$y'));
  });

  test('e-posta linklerinin şeması platform dosyalarında AppInfo ile aynı', () {
    expect(AppInfo.authRedirectUrl, '${AppInfo.authScheme}://${AppInfo.authCallbackHost}');
    expect(
      read('android/app/src/main/AndroidManifest.xml'),
      contains('<data android:scheme="${AppInfo.authScheme}" android:host="${AppInfo.authCallbackHost}"/>'),
    );
    expect(read('ios/Runner/Info.plist'), contains('<string>${AppInfo.authScheme}</string>'));
  });
}
