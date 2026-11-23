import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Rozet tonu: yeşil (genel / başarı), altın (ödül, SSP, kutlama), nötr.
enum BadgeTone { primary, gold, neutral }

/// Renkli daire içinde dolu ikon: kutlama penceresi, başlık simgesi, oyun kartı. Emoji yerine kullanılır;
/// bütün uygulamada aynı ikon ailesi (Material Symbols Rounded) ve aynı daire.
class IconBadge extends StatelessWidget {
  const IconBadge({super.key, required this.icon, this.size = 48, this.tone = BadgeTone.primary});

  final IconData icon;
  final double size;
  final BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final app = context.appColors;
    final (background, foreground) = switch (tone) {
      BadgeTone.primary => (scheme.primaryContainer, scheme.onPrimaryContainer),
      BadgeTone.gold => (app.sspContainer, app.onSspContainer),
      BadgeTone.neutral => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    // Ana ton fütüristik: mor → camgöbeği degrade, beyaz ikon, hafif ışıltı.
    final gradient = tone == BadgeTone.primary;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: gradient ? null : background,
        shape: BoxShape.circle,
        gradient: gradient
            ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: app.brandGradient)
            : null,
        boxShadow: gradient ? [BoxShadow(color: app.glow, blurRadius: size * 0.35)] : null,
      ),
      child: Icon(icon, size: size * 0.5, fill: 1, color: gradient ? Colors.white : foreground),
    );
  }
}

/// İçerikten gelen emoji (kampüs görevi simgesi, market rozeti / unvanı): aynı boyutta yumuşak zeminli jeton içinde,
/// böylece farklı emojiler bir set gibi durur. [size] jetonun kenarı.
class EmojiToken extends StatelessWidget {
  const EmojiToken({super.key, required this.emoji, this.size = 44, this.background});

  final String emoji;
  final double size;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(emoji, style: TextStyle(fontSize: size * 0.5, height: 1)),
    );
  }
}
