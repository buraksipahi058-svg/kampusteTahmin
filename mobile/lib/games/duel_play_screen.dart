import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/app_theme.dart';
import '../core/design_tokens.dart';
import '../core/error_messages.dart';
import '../core/haptics.dart';
import '../core/state_views.dart';
import 'trivia_data.dart';

/// Düello oyunu: sorular sırayla gelir, şık seçilince sonrakine geçilir. Geri sayım sunucunun verdiği
/// kalan süreden başlar; süre bitince verilen cevaplar gönderilir. Puanı ve süreyi sunucu hesaplar.
/// Doğru cevap istemcide yok (cevaplar en sonda gönderilir): seçilen şık yalnızca "seçildi" olarak vurgulanır,
/// doğru / yanlış rengi gösterilmez (cevap anahtarı sızmasın).
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
        AsyncError(:final error) => ErrorView(
          what: 'Oyun açılamadı.',
          error: error,
          onRetry: () => ref.invalidate(duelGameProvider(betId)),
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

  /// Bu soruda seçilen şık (bir kare vurgulanır, sonra sonraki soruya geçilir); seçim sırasında ikinci dokunuş yok.
  int? _picked;
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

  /// [question]: dokunulan şıkkın ait olduğu soru. Solmakta olan eski sorunun şıkları ya da yeni soru çizilmeden
  /// gelen dokunuş yok sayılır (cevap yanlış soruya yazılmasın).
  void _choose(int question, int option) {
    if (_picked != null || question != _index) return;
    Haptics.selection();
    setState(() {
      _answers[_index] = option;
      _picked = option;
    });
    // Seçim bir kare vurgulu çizilir; eski soru bu hâliyle solarken yenisi gelir.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_index < widget.game.questions.length - 1) {
        setState(() {
          _index++;
          _picked = null;
        });
      } else {
        _submit();
      }
    });
  }

  Future<void> _submit() async {
    if (_sending || _result != null) return;
    _timer?.cancel();
    setState(() => _sending = true);
    try {
      final (score, late) = await submitAnswers(ref, widget.betId, _answers);
      if (!mounted) return;
      if (!late) Haptics.light();
      setState(
        () => _result = late
            ? 'Süre doldu, cevapların sayılmadı (0 puan).'
            : '${widget.game.questions.length} sorudan $score doğru. Sonucu Oyunlar sekmesindeki düello kartında '
                  'görürsün (rakip henüz oynamadıysa o oynayınca belli olur).',
      );
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
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_sending)
              const LoadingView()
            else ...[
              Icon(Symbols.sports_score_rounded, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: Space.lg),
              Text(_result!, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            ],
            const SizedBox(height: Space.xl),
            if (!_sending)
              FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Düellolara dön')),
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
      child: AnimatedSwitcher(
        duration: Motion.enter,
        reverseDuration: Motion.exit,
        switchInCurve: Motion.easeOut,
        switchOutCurve: Motion.easeOut,
        transitionBuilder: (child, animation) {
          final fade = FadeTransition(opacity: animation, child: child);
          if (Motion.reduced(context)) return fade;
          return SlideTransition(
            position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(animation),
            child: fade,
          );
        },
        child: KeyedSubtree(key: ValueKey(_index), child: _question(theme, q)),
      ),
    );
  }

  Widget _question(ThemeData theme, TriviaQuestion q) {
    final questions = widget.game.questions;
    final scheme = theme.colorScheme;
    final urgent = _secondsLeft <= 10;
    final qi = _index;
    return Padding(
      padding: const EdgeInsets.all(Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Soru ${_index + 1} / ${questions.length}', style: theme.textTheme.labelLarge),
              const Spacer(),
              Icon(Symbols.timer_rounded, color: urgent ? scheme.error : null),
              const SizedBox(width: Space.xs),
              Text(
                '$_secondsLeft sn',
                style: tabular(theme.textTheme.labelLarge?.copyWith(color: urgent ? scheme.error : null)),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          // Çubuk soru değişince yumuşak ilerler (sıçramaz).
          TweenAnimationBuilder<double>(
            tween: Tween(end: _index / questions.length),
            duration: Motion.enter,
            curve: Motion.easeInOut,
            builder: (_, value, _) => LinearProgressIndicator(value: value),
          ),
          const SizedBox(height: Space.xl),
          Text(q.question, style: theme.textTheme.titleLarge),
          const SizedBox(height: Space.xl),
          for (var i = 0; i < q.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.md),
              child: OutlinedButton(
                onPressed: () => _choose(qi, i),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(Space.lg),
                  alignment: Alignment.centerLeft,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
                  backgroundColor: _picked == i ? scheme.primaryContainer : null,
                  foregroundColor: _picked == i ? scheme.onPrimaryContainer : null,
                  side: _picked == i ? BorderSide(color: scheme.primary, width: 2) : null,
                ),
                child: Text(
                  q.options[i],
                  style: theme.textTheme.titleSmall?.copyWith(color: _picked == i ? scheme.onPrimaryContainer : null),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
