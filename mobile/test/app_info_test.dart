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
}
