import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bets/bets_tab.dart' show formatIstanbul;
import '../wallet/wallet_data.dart';
import 'progress_data.dart';

/// Profil'de seviye ve sonraki seviyeye ilerleme; dokununca XP kuralları ve son kazançlar.
class LevelCard extends ConsumerWidget {
  const LevelCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(myProgressProvider).value;
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        leading: const Icon(Icons.military_tech_outlined),
        title: Text(progress == null ? 'Seviye' : 'Seviye ${progress.level}'),
        subtitle: progress == null
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: progress.fraction),
                  const SizedBox(height: 4),
                  Text('Sonraki seviyeye ${formatAmount(progress.toNextLevel)} XP'),
                ],
              ),
        trailing: Text(progress == null ? '…' : '${formatAmount(progress.xp)} XP', style: theme.textTheme.titleMedium),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          // Kök navigator: sayfa alt menünün arkasında kalmasın.
          useRootNavigator: true,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => const XpInfoSheet(),
        ),
      ),
    );
  }
}

class XpInfoSheet extends ConsumerWidget {
  const XpInfoSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(xpRulesProvider).value;
    final progress = ref.watch(myProgressProvider).value;
    final events = ref.watch(xpEventsProvider).value ?? const <XpEvent>[];
    final theme = Theme.of(context);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text('XP nasıl kazanılır', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.today_outlined),
              title: const Text('Günlük giriş'),
              trailing: Text(rules == null ? '' : '+${rules.dailyLogin} XP'),
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.flag_outlined),
              title: Text('Görev ödülü'),
              trailing: Text('görevde yazar'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Doğru tahmin ya da kazanılan düello'),
              subtitle: rules == null
                  ? null
                  : Text(
                      'Günde en fazla ${rules.dailyPickCap} XP'
                      '${progress == null ? '' : ' · bugün ${progress.pickXpToday}/${rules.dailyPickCap}'}',
                    ),
              trailing: Text(rules == null ? '' : '+${rules.correctPick} XP'),
            ),
            const SizedBox(height: 4),
            Text(
              'XP satın alınmaz ve harcanmaz; yatırdığın miktarla artmaz. Bazı market ürünleri belli bir '
              'seviyeden sonra açılır.',
              style: theme.textTheme.bodySmall,
            ),
            if (events.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Son kazandıkların', style: theme.textTheme.titleMedium),
              for (final e in events)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(e.label),
                  subtitle: Text(formatIstanbul(e.createdAt)),
                  trailing: Text('+${e.amount} XP'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
