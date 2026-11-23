import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/app_theme.dart';
import '../core/design_tokens.dart';
import '../core/haptics.dart';

/// Bahis seçeneği: tam genişlikte dokunulabilir yüzey; solda seçenek, sağda kalın ve hizalı değer (oran ya da havuz).
/// Havuzlu bahiste [share] (0-1) arkada ince bir pay çubuğu olarak görünür. Kazanan yeşil ve kupalı, kişinin seçtiği
/// çerçeveli, hakemin önerdiği tokmaklı. Dokunulamıyorsa ([onTap] null) yüzey aynı kalır, dalga çıkmaz.
class BetOptionButton extends StatelessWidget {
  const BetOptionButton({
    super.key,
    required this.label,
    required this.value,
    this.share,
    this.winner = false,
    this.chosen = false,
    this.proposed = false,
    this.onTap,
  });

  final String label;
  final String value;
  final double? share;
  final bool winner;
  final bool chosen;
  final bool proposed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final app = context.appColors;
    final background = winner ? app.successContainer : scheme.surfaceContainerHigh;
    final foreground = winner ? app.onSuccessContainer : scheme.onSurface;
    final icon = winner
        ? Symbols.emoji_events_rounded
        : proposed
        ? Symbols.gavel_rounded
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Material(
        color: background,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: chosen ? BorderSide(color: scheme.primary, width: 1.5) : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  Haptics.selection();
                  onTap!();
                },
          child: Stack(
            children: [
              if (share != null && share! > 0)
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: share!.clamp(0.0, 1.0),
                    child: ColoredBox(color: scheme.primary.withValues(alpha: 0.10)),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20, fill: winner ? 1 : 0, color: winner ? app.success : scheme.onSurfaceVariant),
                      const SizedBox(width: Space.sm),
                    ],
                    Expanded(
                      child: Text(
                        label,
                        style: theme.textTheme.titleSmall?.copyWith(color: foreground),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Text(value, style: tabular(theme.textTheme.titleMedium?.copyWith(color: foreground))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
