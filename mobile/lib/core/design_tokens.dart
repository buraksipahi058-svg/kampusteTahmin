import 'package:flutter/widgets.dart';

/// Boşluk ölçeği (dp). Ekranlarda sayı yerine bunlar kullanılır.
abstract final class Space {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// Köşe yarıçapları.
abstract final class Radii {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
}

/// Hareket: süreler ve eğriler (docs/harita/tasarim.md).
/// Kural: günde çok görülen şey (sekme, liste satırı) animasyonsuz; basma 100-160 ms; arayüz animasyonu 300 ms'yi
/// geçmez; çıkış girişten hızlı; giriş / çıkış ease-out, ekranda yer değiştirme ease-in-out, ease-in hiç.
abstract final class Motion {
  /// Basınca küçülme / bırakınca dönme.
  static const press = Duration(milliseconds: 120);

  /// Küçük durum değişimi (renk, seçim, çip).
  static const fast = Duration(milliseconds: 160);

  /// Giriş (pencere, kutlama, içerik değişimi).
  static const enter = Duration(milliseconds: 250);

  /// Çıkış: girişten hızlı.
  static const exit = Duration(milliseconds: 200);

  /// Güçlü ease-out: cubic-bezier(0.23, 1, 0.32, 1).
  static const easeOut = Cubic(0.23, 1, 0.32, 1);

  /// Ekranda yer değiştirme: cubic-bezier(0.77, 0, 0.175, 1).
  static const easeInOut = Cubic(0.77, 0, 0.175, 1);

  /// Basılan öğenin küçüldüğü oran.
  static const pressedScale = 0.97;

  /// "Animasyonları azalt" açıksa yer değiştirme / ölçek animasyonu yapılmaz (opaklık ve renk kalır).
  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}
