import 'package:flutter/material.dart';

import 'market_data.dart';

/// Ürünün küçük önizlemesi: unvan / rozet simgesi, çerçeve rengi ya da isim rengi.
class CosmeticPreview extends StatelessWidget {
  const CosmeticPreview({super.key, required this.item, this.size = 40});

  final MarketItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = item.colorValue;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.surfaceContainerHighest,
        border: item.category == 'frame' && color != null ? Border.all(color: color, width: 3) : null,
      ),
      child: switch (item.category) {
        'name_color' => Text('Aa', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        'frame' => Icon(Icons.person, color: theme.colorScheme.onSurfaceVariant),
        _ => Text(item.icon ?? '★', style: TextStyle(fontSize: size * 0.45)),
      },
    );
  }
}

/// Profil resmi yerine baş harfler; kuşanılmış çerçeve varsa onun renginde kenar.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.initials, this.frame, this.frameColor, this.radius = 32});

  final String initials;
  final MarketItem? frame;

  /// Çerçeve ürünü yerine yalnızca rengi biliniyorsa (liderlik).
  final Color? frameColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = frameColor ?? frame?.colorValue;
    final textStyle = radius < 24 ? theme.textTheme.labelLarge : theme.textTheme.titleLarge;
    return Container(
      padding: EdgeInsets.all(radius < 24 ? 2 : 3),
      decoration: BoxDecoration(shape: BoxShape.circle, color: color ?? Colors.transparent),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(initials, style: textStyle?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
      ),
    );
  }
}
