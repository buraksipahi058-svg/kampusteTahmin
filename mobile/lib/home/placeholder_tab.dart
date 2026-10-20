import 'package:flutter/material.dart';

import 'home_shell.dart';

/// Henüz yapılmamış sekmeler için boş sayfa.
class PlaceholderTab extends StatelessWidget {
  const PlaceholderTab({super.key, required this.tab});

  final HomeTab tab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tab.icon, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(tab.label, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Yakında burada olacak.', style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
