import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Ana sekmelerin arka planı: gece moru zemin, sol üstte mor, sağ altta camgöbeği çok hafif ışık hüzmesi (fütüristik
/// derinlik). Durağan (animasyonsuz); üstündeki paneller opak kalır, okunurluk etkilenmez.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final app = context.appColors;
    return ColoredBox(
      color: scheme.surface,
      child: Stack(
        children: [
          Positioned(top: -140, left: -120, child: _Glow(color: scheme.primary.withValues(alpha: 0.20), size: 380)),
          Positioned(bottom: -160, right: -140, child: _Glow(color: app.accent.withValues(alpha: 0.12), size: 420)),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    ),
  );
}
