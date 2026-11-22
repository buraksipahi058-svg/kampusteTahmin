import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/error_messages.dart';
import 'trivia_data.dart';

/// Düello oyunu: sorular sırayla gelir, şık seçilince sonrakine geçilir. Geri sayım sunucunun verdiği
/// kalan süreden başlar; süre bitince verilen cevaplar gönderilir. Puanı ve süreyi sunucu hesaplar.
class DuelPlayScreen extends ConsumerWidget {
  const DuelPlayScreen({super.key, required this.betId});

  final String betId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(duelGameProvider(betId));
    return Scaffold(
      appBar: AppBar(title: const Text('Trivia düellosu')),
      body: switch (game) {
        AsyncData(:final value) => _Quiz(betId: betId, game: value),
        AsyncError(:final error) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Oyun açılamadı. ${userMessage(error)}'),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Quiz extends ConsumerStatefulWidget {
  const _Quiz({required this.betId, required this.game});

  final String betId;
  final DuelGame game;

  @override
  ConsumerState<_Quiz> createState() => _QuizState();
}

class _QuizState extends ConsumerState<_Quiz> {
  late final List<int?> _answers = List.filled(widget.game.questions.length, null);
  late int _secondsLeft = widget.game.secondsLeft;
  var _index = 0;
  var _sending = false;
  String? _result;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft = _secondsLeft > 0 ? _secondsLeft - 1 : 0);
      if (_secondsLeft == 0) _submit();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _choose(int option) {
    setState(() => _answers[_index] = option);
    if (_index < widget.game.questions.length - 1) {
      setState(() => _index++);
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    if (_sending || _result != null) return;
    _timer?.cancel();
    setState(() => _sending = true);
    try {
      final (score, late) = await submitAnswers(ref, widget.betId, _answers);
      if (!mounted) return;
      setState(() => _result = late
          ? 'Süre doldu, cevapların sayılmadı (0 puan).'
          : '${widget.game.questions.length} sorudan $score doğru. Sonucu Oyunlar sekmesindeki düello kartında '
                'görürsün (rakip henüz oynamadıysa o oynayınca belli olur).');
    } catch (e) {
      if (mounted) setState(() => _result = userMessage(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final questions = widget.game.questions;

    if (_result != null || _sending) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_sending) const Center(child: CircularProgressIndicator()) else Text(_result!, style: theme.textTheme.titleMedium),
            const SizedBox(height: 24),
            if (!_sending) FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Düellolara dön')),
          ],
        ),
      );
    }

    final q = questions[_index];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Düellodan çıkılsın mı?'),
            content: const Text('Şimdiye kadar verdiğin cevaplar gönderilir; boş bıraktıkların yanlış sayılır.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Devam et')),
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Gönder ve çık')),
            ],
          ),
        );
        if (leave != true || !mounted) return;
        await _submit();
        if (mounted) Navigator.of(this.context).pop();
      },
      child: _question(theme, q),
    );
  }

  Widget _question(ThemeData theme, TriviaQuestion q) {
    final questions = widget.game.questions;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Soru ${_index + 1} / ${questions.length}', style: theme.textTheme.labelLarge),
              const Spacer(),
              Icon(Icons.timer_outlined, color: _secondsLeft <= 10 ? theme.colorScheme.error : null),
              const SizedBox(width: 4),
              Text('$_secondsLeft sn', style: theme.textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: (_index) / questions.length),
          const SizedBox(height: 24),
          Text(q.question, style: theme.textTheme.titleLarge),
          const SizedBox(height: 24),
          for (var i = 0; i < q.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton(
                onPressed: () => _choose(i),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
                child: Text(q.options[i]),
              ),
            ),
        ],
      ),
    );
  }
}
