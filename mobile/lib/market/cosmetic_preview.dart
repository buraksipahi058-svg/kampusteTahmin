import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/app_theme.dart';
import 'market_data.dart';

/// Ürünün küçük önizlemesi: unvan / rozet simgesi ve isim rengi yuvarlatılmış kare jetonda (koleksiyon parçası gibi),
/// çerçeve ise profil resmi gibi daire içinde kendi renginde kenarla.
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
        shape: item.category == 'frame' ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: item.category == 'frame' ? null : BorderRadius.circular(size * 0.3),
        color: theme.colorScheme.surfaceContainerHigh,
        border: item.category == 'frame' && color != null ? Border.all(color: color, width: 3) : null,
      ),
      child: switch (item.category) {
        'name_color' => Text(
          'Aa',
          style: TextStyle(
            color: readableNameColor(context, color),
            fontWeight: FontWeight.w800,
            fontSize: size * 0.38,
          ),
        ),
        'frame' => Icon(Symbols.person_rounded, color: theme.colorScheme.onSurfaceVariant),
        _ when item.icon == null => Icon(Symbols.star_rounded, fill: 1, size: size * 0.5),
        _ => Text(item.icon!, style: TextStyle(fontSize: size * 0.5, height: 1)),
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
