import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Kanıt fotoğrafını göndermeye hazırlar: telefonun yön bilgisine göre döndürür, uzun kenarı en fazla 1280 piksele
/// küçültür, konum ve cihaz bilgisini (EXIF) tamamen siler, JPEG (kalite 80) olarak kodlar. Ağır iş: `compute` ile.
Uint8List prepareProofPhoto(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Fotoğraf okunamadı');
  var image = img.bakeOrientation(decoded);
  if (image.width > 1280 || image.height > 1280) {
    image = image.width >= image.height ? img.copyResize(image, width: 1280) : img.copyResize(image, height: 1280);
  }
  // Boş EXIF kodlanmaz: GPS, cihaz modeli, çekim zamanı gitmez.
  image.exif = img.ExifData();
  return img.encodeJpg(image, quality: 80);
}

/// Depolamadaki dosya adı için rastgele UUID v4.
String randomUuid([Random? random]) {
  final r = random ?? Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String hex(int from, int to) => b.sublist(from, to).map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
