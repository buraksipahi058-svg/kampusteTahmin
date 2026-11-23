import 'package:flutter/material.dart';

import 'design_tokens.dart';
import 'error_messages.dart';

/// Liste yüklenirken: ortada dönen gösterge (içeriği kaydırmaz).
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.padding = Space.xxl});

  final double padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.all(padding),
    child: const Center(child: CircularProgressIndicator()),
  );
}

/// Boş liste: simge, açıklama, istenirse bir eylem. Her liste boş durumunu böyle gösterir.
class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.text, this.icon = Icons.inbox_outlined, this.action});

  final String text;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xxl, horizontal: Space.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: theme.colorScheme.outline),
          const SizedBox(height: Space.md),
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (action != null) ...[const SizedBox(height: Space.md), action!],
        ],
      ),
    );
  }
}

/// Yükleme hatası: "(ne) alınamadı. (anlaşılır sebep)" ve "Tekrar dene". Ham hata metni gösterilmez (userMessage).
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.what, required this.error, this.onRetry});

  /// Ör. "Bahisler alınamadı."
  final String what;
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xl, horizontal: Space.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, size: 40, color: theme.colorScheme.outline),
          const SizedBox(height: Space.md),
          Text('$what ${userMessage(error)}', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
          if (onRetry != null) ...[
            const SizedBox(height: Space.sm),
            TextButton(onPressed: onRetry, child: const Text('Tekrar dene')),
          ],
        ],
      ),
    );
  }
}
