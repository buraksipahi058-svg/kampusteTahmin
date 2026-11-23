import 'package:flutter/services.dart';

/// Dokunsal geri bildirim: görüntüyle aynı karede, olay başına bir kez, hiçbir zaman tek geri bildirim olarak değil.
abstract final class Haptics {
  /// Seçim değişti (çip, şık, sekme içi seçim).
  static Future<void> selection() => HapticFeedback.selectionClick();

  /// Bir şey yerine oturdu / gönderildi (yatırım, kabul, QR okundu).
  static Future<void> light() => HapticFeedback.lightImpact();

  /// Önemli ya da geri alınamaz işlem (hesap silme onayı, yanlış cevap).
  static Future<void> medium() => HapticFeedback.mediumImpact();

  /// Kazanç / kutlama (ödül alındı, seviye atlandı, doğru cevap).
  static Future<void> success() => HapticFeedback.heavyImpact();
}
