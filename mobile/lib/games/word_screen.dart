import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/app_theme.dart';
import '../core/celebration.dart';
import '../core/design_tokens.dart';
import '../core/error_messages.dart';
import '../core/haptics.dart';
import '../core/icon_badge.dart';
import '../core/state_views.dart';
import '../core/supabase.dart';
import '../core/verify_email_card.dart';
import '../profile/student_email_data.dart';
import '../wallet/balance_bar.dart';
import 'word_data.dart';

/// Kampüs kelimesi (`/kampus-kelimesi`): günde bir kampüs kelimesi, sınırlı hakta bulunur. Her tahmin sunucuda
/// işaretlenir (kelime istemcide yok): yeşil doğru yerde, altın kelimede var ama başka yerde, gri yok.
/// Tahmin sözlükte olmalı. Bulana az hakta daha çok SP + XP.
class WordScreen extends ConsumerStatefulWidget {
  const WordScreen({super.key});

  @override
  ConsumerState<WordScreen> createState() => _WordScreenState();
}

class _WordScreenState extends ConsumerState<WordScreen> {
  /// Sunucudan gelen son durum (her tahminden sonra güncellenir).
  WordPuzzle? _puzzle;
  var _typing = '';
  var _busy = false;

  /// Klavyenin üstündeki kısa uyarı (kısa kelime, sözlükte yok...). Uyarı çubuğu klavyenin alt sırasını
  /// örttüğü için kullanılmaz; bir sonraki tuşta kalkar.
  String? _notice;

  WordPuzzle? _current(WordPuzzle? fromServer) {
    if (fromServer == null) return _puzzle;
    // Yeni gün (başka bulmaca) gelirse yereldeki atılır; aynı bulmacada daha çok tahmini olan güncel sayılır.
    if (_puzzle == null || _puzzle!.id != fromServer.id || fromServer.guesses.length > _puzzle!.guesses.length) {
      _puzzle = fromServer;
    }
    return _puzzle;
  }

  void _type(WordPuzzle puzzle, String letter) {
    if (_busy || puzzle.finished || _typing.length >= puzzle.length) return;
    Haptics.selection();
    setState(() {
      _typing += letter;
      _notice = null;
    });
  }

  void _erase() {
    if (_busy || _typing.isEmpty) return;
    Haptics.selection();
    setState(() {
      _typing = _typing.substring(0, _typing.length - 1);
      _notice = null;
    });
  }

  Future<void> _submit(WordPuzzle puzzle) async {
    if (_busy || puzzle.finished) return;
    if (_typing.length != puzzle.length) {
      Haptics.medium();
      setState(() => _notice = 'Kelime ${puzzle.length} harfli olmalı.');
      return;
    }
    final guess = _typing;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final result = await ref.read(wordApiProvider).guess(puzzle.id, guess);
      if (!mounted) return;
      final next = puzzle.withGuess(guess, result);
      setState(() {
        _puzzle = next;
        _typing = '';
      });
      if (!result.finished) {
        Haptics.light();
        return;
      }
      final c = containerOf(ref);
      c.invalidate(wordPuzzleProvider);
      if (result.rewardSp > 0) refreshAfterWordReward(c);
      if (result.solved) {
        await showCelebration(
          context,
          icon: Symbols.emoji_events_rounded,
          tone: BadgeTone.gold,
          title: 'Buldun!',
          message: result.rewardSp > 0
              ? '${next.guesses.length}. tahminde buldun: +${result.rewardSp} SP · +${result.rewardXp} XP'
              : '${next.guesses.length}. tahminde buldun.',
          actions: (dialogContext) => [
            FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Tamam')),
          ],
        );
      } else {
        Haptics.medium();
      }
    } catch (e) {
      if (!mounted) return;
      Haptics.medium();
      setState(() => _notice = userMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final verified = ref.watch(studentEmailProvider).value?.verified;
    final Widget body;
    if (verified == false) {
      body = ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: const [VerifyEmailCard('Kampüs kelimesini oynamak için okul mailini doğrula')],
      );
    } else {
      body = switch (ref.watch(wordPuzzleProvider)) {
        AsyncData(:final value) when _current(value) == null => ListView(
          padding: const EdgeInsets.all(Space.lg),
          children: const [
            EmptyView(
              text: 'Bugünün kelimesi henüz girilmedi. Okulunun yetkilisi girince burada olacak.',
              icon: Symbols.spellcheck_rounded,
            ),
          ],
        ),
        AsyncData(:final value) => _Game(
          puzzle: _current(value)!,
          typing: _typing,
          notice: _notice,
          busy: _busy,
          onLetter: (l) => _type(_current(value)!, l),
          onErase: _erase,
          onSubmit: () => _submit(_current(value)!),
        ),
        AsyncError(:final error) => ListView(
          padding: const EdgeInsets.all(Space.lg),
          children: [
            ErrorView(what: 'Kelime alınamadı.', error: error, onRetry: () => ref.invalidate(wordPuzzleProvider)),
          ],
        ),
        _ => const LoadingView(),
      };
    }
    return Scaffold(
      appBar: AppBar(title: const AppBarTitle('Kampüs kelimesi'), actions: const [BalanceBar(), SizedBox(width: 8)]),
      body: body,
    );
  }
}

class _Game extends StatelessWidget {
  const _Game({
    required this.puzzle,
    required this.typing,
    required this.notice,
    required this.busy,
    required this.onLetter,
    required this.onErase,
    required this.onSubmit,
  });

  final WordPuzzle puzzle;
  final String typing;
  final String? notice;
  final bool busy;
  final ValueChanged<String> onLetter;
  final VoidCallback onErase;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.lg),
            children: [
              Text(
                '${puzzle.length} harfli kampüs kelimesini ${puzzle.maxGuesses} hakta bul. '
                '${puzzle.canEarn ? rewardSummary(puzzle.rewardsSp, puzzle.rewardsXp) : 'Kelimeyi yönettiğin için ödül almazsın.'}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: Space.sm),
              const _Legend(),
              const SizedBox(height: Space.lg),
              _Board(puzzle: puzzle, typing: typing),
              if (puzzle.finished) ...[const SizedBox(height: Space.lg), _ResultCard(puzzle: puzzle)],
            ],
          ),
        ),
        if (!puzzle.finished && notice != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.sm),
            child: Semantics(
              liveRegion: true,
              child: Text(
                notice!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          ),
        if (!puzzle.finished)
          _Keyboard(marks: letterMarks(puzzle), busy: busy, onLetter: onLetter, onErase: onErase, onSubmit: onSubmit),
      ],
    );
  }
}

/// "1–2. tahminde 60 SP + 20 XP · 3–4. tahminde ..." (aynı ödüllü ardışık tahminler birleştirilir).
String rewardSummary(List<int> sp, List<int> xp) {
  if (sp.isEmpty) return '';
  final parts = <String>[];
  var start = 0;
  for (var i = 1; i <= sp.length; i++) {
    if (i == sp.length || sp[i] != sp[start] || xp[i] != xp[start]) {
      final range = i - 1 == start ? '${start + 1}.' : '${start + 1}–$i.';
      parts.add('$range tahminde ${sp[start]} SP${xp[start] > 0 ? ' + ${xp[start]} XP' : ''}');
      start = i;
    }
  }
  return 'Bulursan: ${parts.join(' · ')}.';
}

/// Klavyede her harfin bilinen en iyi işareti (doğru > var > yok).
Map<String, LetterMark> letterMarks(WordPuzzle puzzle) {
  final result = <String, LetterMark>{};
  for (var g = 0; g < puzzle.guesses.length; g++) {
    final letters = puzzle.guesses[g].split('');
    for (var i = 0; i < letters.length && i < puzzle.marks[g].length; i++) {
      final m = puzzle.marks[g][i];
      final old = result[letters[i]];
      if (old == null || m.index < old.index) result[letters[i]] = m;
    }
  }
  return result;
}

({Color background, Color foreground}) _markColors(BuildContext context, LetterMark? mark) {
  final scheme = Theme.of(context).colorScheme;
  final app = context.appColors;
  return switch (mark) {
    LetterMark.correct => (background: app.success, foreground: scheme.surface),
    LetterMark.present => (background: app.ssp, foreground: scheme.surface),
    LetterMark.absent => (background: scheme.surfaceContainerHighest, foreground: scheme.onSurfaceVariant),
    null => (background: Colors.transparent, foreground: scheme.onSurface),
  };
}

String _markName(LetterMark m) => switch (m) {
  LetterMark.correct => 'doğru yerde',
  LetterMark.present => 'başka yerde',
  LetterMark.absent => 'yok',
};

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget item(LetterMark m, String text) {
      final colors = _markColors(context, m);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: colors.background, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: Space.xs),
          Text(text, style: theme.textTheme.labelSmall),
        ],
      );
    }

    return Wrap(
      spacing: Space.md,
      runSpacing: Space.xs,
      children: [
        item(LetterMark.correct, 'Doğru yerde'),
        item(LetterMark.present, 'Kelimede var'),
        item(LetterMark.absent, 'Kelimede yok'),
      ],
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.puzzle, required this.typing});

  final WordPuzzle puzzle;
  final String typing;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        // Kare kutular: 4 harfte büyük, 8 harfte ekrana sığar.
        constraints: BoxConstraints(maxWidth: puzzle.length * 62.0),
        child: Column(
          children: [
            for (var row = 0; row < puzzle.maxGuesses; row++) ...[
              if (row < puzzle.guesses.length)
                _Row(
                  letters: puzzle.guesses[row].split(''),
                  marks: puzzle.marks[row],
                  index: row,
                  length: puzzle.length,
                )
              else if (row == puzzle.guesses.length && !puzzle.finished)
                _Row(letters: typing.split(''), length: puzzle.length, index: row, active: true)
              else
                _Row(letters: const [], length: puzzle.length, index: row),
              const SizedBox(height: Space.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.letters, required this.length, required this.index, this.marks, this.active = false});

  final List<String> letters;
  final List<LetterMark>? marks;
  final int length;
  final int index;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final label = marks == null
        ? (active ? 'Yazılan: ${letters.join()}' : '${index + 1}. tahmin boş')
        : '${index + 1}. tahmin ${letters.join()}: '
              '${[for (var i = 0; i < letters.length; i++) '${letters[i]} ${_markName(marks![i])}'].join(', ')}';
    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 0; i < length; i++) ...[
              if (i > 0) const SizedBox(width: Space.sm - 2),
              Expanded(
                child: _Tile(
                  letter: i < letters.length ? letters[i] : '',
                  mark: marks == null || i >= marks!.length ? null : marks![i],
                  active: active && i < letters.length,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.letter, required this.mark, required this.active});

  final String letter;
  final LetterMark? mark;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = _markColors(context, mark);
    return AspectRatio(
      aspectRatio: 1,
      child: AnimatedContainer(
        duration: Motion.reduced(context) ? Duration.zero : Motion.fast,
        curve: Motion.easeOut,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(Radii.sm),
          border: mark != null
              ? null
              : Border.all(color: active ? scheme.outline : scheme.outlineVariant, width: active ? 2 : 1.5),
        ),
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Text(
              letter,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800, color: colors.foreground),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.puzzle});

  final WordPuzzle puzzle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = context.appColors;
    final String detail;
    if (!puzzle.solved) {
      detail = 'Bu sefer olmadı. Yarın yeni kelime var.';
    } else if (puzzle.rewardSp > 0) {
      detail = '${puzzle.guesses.length}. tahminde buldun: +${puzzle.rewardSp} SP · +${puzzle.rewardXp} XP';
    } else {
      detail = '${puzzle.guesses.length}. tahminde buldun.';
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Row(
          children: [
            IconBadge(
              icon: puzzle.solved ? Symbols.emoji_events_rounded : Symbols.spellcheck_rounded,
              tone: puzzle.solved ? BadgeTone.gold : BadgeTone.neutral,
              size: 48,
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kelime: ${puzzle.answer ?? ''}', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(detail, style: theme.textTheme.bodyMedium?.copyWith(color: puzzle.solved ? app.success : null)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Türkçe Q klavye (Q, W, X yok). Harfler bilinen işaretin renginde.
class _Keyboard extends StatelessWidget {
  const _Keyboard({
    required this.marks,
    required this.busy,
    required this.onLetter,
    required this.onErase,
    required this.onSubmit,
  });

  final Map<String, LetterMark> marks;
  final bool busy;
  final ValueChanged<String> onLetter;
  final VoidCallback onErase;
  final VoidCallback onSubmit;

  static const _rows = ['ERTYUIOPĞÜ', 'ASDFGHJKLŞİ', 'ZCVBNMÖÇ'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget letterKey(String l) {
      final colors = _markColors(context, marks[l]);
      return _Key(
        label: l,
        background: marks[l] == null ? scheme.surfaceContainerHigh : colors.background,
        foreground: marks[l] == null ? scheme.onSurface : colors.foreground,
        onTap: () => onLetter(l),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        color: scheme.surfaceContainerLow,
        padding: const EdgeInsets.fromLTRB(Space.xs, Space.sm, Space.xs, Space.sm),
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Üst sıra 10 harf: kenarlarda yarım tuş boşluk, tuşlar alttakilerle aynı genişlikte.
              Row(children: [const Spacer(), for (final l in _rows[0].split('')) letterKey(l), const Spacer()]),
              Row(children: [for (final l in _rows[1].split('')) letterKey(l)]),
              Row(
                children: [
                  _Key(
                    label: 'Gönder',
                    flex: 3,
                    background: scheme.primary,
                    foreground: scheme.onPrimary,
                    onTap: busy ? null : onSubmit,
                  ),
                  for (final l in _rows[2].split('')) letterKey(l),
                  _Key(
                    icon: Symbols.backspace_rounded,
                    semanticLabel: 'Sil',
                    flex: 3,
                    background: scheme.surfaceContainerHigh,
                    foreground: scheme.onSurface,
                    onTap: onErase,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    this.label,
    this.icon,
    this.semanticLabel,
    this.flex = 2,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String? label;
  final IconData? icon;
  final String? semanticLabel;
  final int flex;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(Radii.sm - 2),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.sm - 2),
            onTap: onTap,
            child: SizedBox(
              height: 50,
              child: Center(
                child: icon != null
                    ? Icon(icon, color: foreground, size: 22, semanticLabel: semanticLabel)
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label!,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
