import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../bets/bets_tab.dart' show formatIstanbul;
import '../core/error_messages.dart';
import '../core/routes.dart';
import '../wallet/wallet_data.dart';
import 'campus_data.dart';

/// `/kampus-gorevleri`: okulun kampüs görevleri. QR görevinde "QR okut", fotoğraflı görevde "Fotoğraf çek".
class CampusTasksScreen extends ConsumerWidget {
  const CampusTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Kampüs görevleri')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(campusTasksProvider);
          await ref.read(campusTasksProvider.future);
        },
        child: switch (ref.watch(campusTasksProvider)) {
          AsyncData(:final value) when value.isEmpty => ListView(
            padding: const EdgeInsets.all(32),
            children: const [Center(child: Text('Okulunda şu an açık kampüs görevi yok.'))],
          ),
          AsyncData(:final value) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Kampüste görevleri yap, ödülü kap. QR görevinde mekândaki kodu okut; fotoğraflı görevde okulunun '
                'yetkilisi onaylar.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              for (final t in value) CampusTaskCard(task: t),
            ],
          ),
          AsyncError(:final error) => ListView(
            padding: const EdgeInsets.all(32),
            children: [
              Text('Görevler alınamadı. ${userMessage(error)}', textAlign: TextAlign.center),
              TextButton(onPressed: () => ref.invalidate(campusTasksProvider), child: const Text('Tekrar dene')),
            ],
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class CampusTaskCard extends StatelessWidget {
  const CampusTaskCard({super.key, required this.task});

  final CampusTask task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = task;
    final status = switch (t.myStatus) {
      'approved' => ('Yaptın, ödülü aldın', theme.colorScheme.primary),
      'pending' => ('Onay bekliyor', theme.colorScheme.tertiary),
      'rejected' => ('Reddedildi${t.myNote == null ? '' : ': ${t.myNote}'} · yeniden deneyebilirsin', theme.colorScheme.error),
      'expired' => ('Onaylanmadan süresi doldu · yeniden deneyebilirsin', theme.colorScheme.error),
      _ => null,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.icon, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.title, style: theme.textTheme.titleMedium),
                      if (t.description != null) Text(t.description!, style: theme.textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text(
                        [
                          '+${formatAmount(t.rewardAmount)} ${t.rewardCurrency}${t.rewardXp > 0 ? ' · +${t.rewardXp} XP' : ''}',
                          campusPeriodLabel(t.period),
                          t.verification == 'qr' ? 'QR' : 'Fotoğraf',
                        ].join(' · '),
                        style: theme.textTheme.labelMedium,
                      ),
                      Text(
                        [
                          '${t.period == 'once' ? 'Şimdiye dek' : t.period == 'daily' ? 'Bugün' : 'Bu hafta'} '
                              '${t.doneThisPeriod} kişi yaptı',
                          if (t.remaining != null) 'kalan kontenjan ${t.remaining}',
                          if (t.endsAt != null) 'bitiş ${formatIstanbul(t.endsAt!)}',
                        ].join(' · '),
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (status != null) ...[
              const SizedBox(height: 8),
              Text(status.$1, style: theme.textTheme.bodySmall?.copyWith(color: status.$2)),
            ],
            if (t.notStarted) ...[
              const SizedBox(height: 8),
              Text('Başlangıç: ${formatIstanbul(t.startsAt!)}', style: theme.textTheme.bodySmall),
            ] else if (t.canSubmit) ...[
              const SizedBox(height: 8),
              if (t.verification == 'qr')
                FilledButton.icon(
                  onPressed: () => context.push(Routes.campusScan(t.id)),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('QR okut'),
                )
              else
                FilledButton.icon(
                  onPressed: () => context.push(Routes.campusPhoto(t.id)),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Fotoğraf çek'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
