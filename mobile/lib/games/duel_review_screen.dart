import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/error_messages.dart';
import 'trivia_data.dart';

/// `/duello/:id/cevaplar`: bitmiş düelloda sorular, doğru şık, kişinin ve rakibin cevabı.
class DuelReviewScreen extends ConsumerWidget {
  const DuelReviewScreen({super.key, required this.betId});

  final String betId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Düello cevapları')),
      body: switch (ref.watch(duelReviewProvider(betId))) {
        AsyncData(:final value) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${value.where((q) => q.myAnswer == q.correctIndex).length}/${value.length} doğru',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final q in value) _QuestionCard(item: q),
          ],
        ),
        AsyncError(:final error) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Cevaplar açılamadı. ${userMessage(error)}'),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.item});

  final DuelReviewItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${item.no}. ${item.question}', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (var i = 0; i < item.options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      i == item.correctIndex ? Symbols.check_circle_rounded : Symbols.circle_rounded,
                      fill: i == item.correctIndex ? 1 : 0,
                      size: 18,
                      color: i == item.correctIndex ? scheme.primary : scheme.outline,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.options[i],
                        style: i == item.correctIndex ? const TextStyle(fontWeight: FontWeight.w600) : null,
                      ),
                    ),
                    if (i == item.myAnswer) _Tag(text: 'Sen', correct: i == item.correctIndex),
                    if (i == item.opponentAnswer) _Tag(text: 'Rakip', correct: i == item.correctIndex),
                  ],
                ),
              ),
            if (item.myAnswer == null) Text('Bu soruyu cevaplamadın.', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.correct});

  final String text;
  final bool correct;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: correct ? scheme.primaryContainer : scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(color: correct ? scheme.onPrimaryContainer : scheme.onErrorContainer, fontSize: 12),
      ),
    );
  }
}
