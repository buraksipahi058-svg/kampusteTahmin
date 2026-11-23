import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/async_button.dart';
import '../core/error_messages.dart';
import '../core/state_views.dart';
import '../core/supabase.dart';
import '../progress/progress_data.dart';
import 'wallet_data.dart';

/// Günlük ödül penceresi: serinin 7 günlük dilimi (alınanlar işaretli, bugün vurgulu, kilometre taşı bonusu)
/// ve "Ödülü al". Açılışta bugünün ödülü alınmadıysa bir kez kendiliğinden, üst çubuktaki hediye simgesiyle
/// her zaman açılır.
Future<void> showDailyReward(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => const _DailyRewardSheet(),
  );
}

class _DailyRewardSheet extends ConsumerStatefulWidget {
  const _DailyRewardSheet();

  @override
  ConsumerState<_DailyRewardSheet> createState() => _DailyRewardSheetState();
}

class _DailyRewardSheetState extends ConsumerState<_DailyRewardSheet> {
  DailyReward? _result;
  String? _error;

  Future<void> _claim() async {
    final c = containerOf(ref);
    try {
      final reward = await claimDailyReward(c);
      refreshProgress(c);
      if (mounted) setState(() => _result = reward);
    } catch (e) {
      if (mounted) setState(() => _error = userMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = ref.watch(dailyCalendarProvider);
    final today = days.value?.where((d) => d.isToday).firstOrNull;
    final result = _result;
    final xp = ref.watch(xpRulesProvider).value?.dailyLogin ?? 0;
    final xpText = xp > 0 ? ' · +$xp XP' : '';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('🎁 Günlük ödül', style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              today == null
                  ? 'Her gün gir, ödülün büyüsün. 7, 14 ve 30. günlerde bonus var.'
                  : 'Seri: ${today.claimed ? today.day : today.day - 1} gün · Her gün gir, ödülün büyüsün; '
                        '7, 14 ve 30. günlerde bonus var.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            switch (days) {
              AsyncData(:final value) => Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [for (final d in value) _DayTile(day: d)],
              ),
              AsyncError(:final error) => ErrorView(
                what: 'Takvim alınamadı.',
                error: error,
                onRetry: () => ref.invalidate(dailyCalendarProvider),
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
            const SizedBox(height: 16),
            if (result != null)
              Text(
                result.claimed
                    ? '+${formatAmount(result.amount)} SP$xpText aldın! Seri: ${result.streak} gün. Yarın yine gel.'
                    : 'Bugünün ödülünü zaten aldın. Yarın yine gel.',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              )
            else if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              )
            else if (today != null && !today.claimed)
              AsyncButton(
                onPressed: _claim,
                child: Text('Ödülü al (+${formatAmount(today.amount + today.bonus)} SP$xpText)'),
              )
            else if (today != null)
              const Text('Bugünün ödülü alındı. Yarın yine gel.', textAlign: TextAlign.center),
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
          ],
        ),
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.day});

  final CalendarDay day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = day.isToday
        ? scheme.primaryContainer
        : day.claimed
        ? scheme.surfaceContainerHighest
        : scheme.surfaceContainerLow;
    return Container(
      width: 76,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: day.isToday ? scheme.primary : scheme.outlineVariant, width: day.isToday ? 2 : 1),
      ),
      child: Column(
        children: [
          Text('${day.day}. gün', style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          day.claimed
              ? Icon(Icons.check_circle, color: scheme.primary, size: 24)
              : Text(day.bonus > 0 ? '🎉' : '🪙', style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text('+${formatAmount(day.amount)}', style: theme.textTheme.labelLarge),
          if (day.bonus > 0)
            Text(
              '+${formatAmount(day.bonus)} bonus',
              style: theme.textTheme.labelSmall?.copyWith(color: scheme.primary),
            ),
        ],
      ),
    );
  }
}
