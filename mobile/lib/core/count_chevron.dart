import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'app_theme.dart';

/// Liste satırının sonundaki ok; bekleyen iş varsa okun solunda sayı rozeti (oka binmez).
/// Rozet büyük yazı ayarında en çok 1,3 kat büyür (kart kenarından taşmasın).
class CountChevron extends StatelessWidget {
  const CountChevron({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    const chevron = Icon(Symbols.chevron_right_rounded);
    if (count <= 0) return chevron;
    final theme = Theme.of(context);
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 20),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: theme.colorScheme.error, borderRadius: BorderRadius.circular(999)),
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: tabular(
                theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onError, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 4),
          chevron,
        ],
      ),
    );
  }
}
