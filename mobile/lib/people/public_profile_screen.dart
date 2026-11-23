import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../achievements/achievement_badge.dart';
import '../achievements/achievements_data.dart';
import '../core/app_theme.dart';
import '../core/error_messages.dart';
import '../core/routes.dart';
import '../leaderboard/leaderboard_data.dart';
import '../market/cosmetic_preview.dart';
import '../market/market_data.dart';
import 'people_data.dart';

/// Kartlarda ve listelerde kişi: çerçeveli küçük avatar, isim rengi, rozet; dokununca kişinin profili açılır.
class PersonLabel extends StatelessWidget {
  const PersonLabel({super.key, required this.userId, required this.name, this.cosmetics, this.style});

  final String userId;
  final String name;
  final Cosmetics? cosmetics;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final initials = name.split(' ').where((s) => s.isNotEmpty).take(2).map((s) => s.substring(0, 1)).join();
    final base = style ?? Theme.of(context).textTheme.bodyMedium;
    return InkWell(
      onTap: () => context.push(Routes.person(userId)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ProfileAvatar(initials: initials, frame: cosmetics?.frame, radius: 10),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              [name, ?cosmetics?.badge?.icon].join(' '),
              style: base?.copyWith(color: readableNameColor(context, cosmetics?.nameColor?.colorValue)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// `/kisi/:id`: okul arkadaşının profili (liderlikten, bahis ve düello kartlarından açılır).
class PublicProfileScreen extends ConsumerWidget {
  const PublicProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: switch (ref.watch(publicProfileProvider(userId))) {
        AsyncData(value: null) => const Center(child: Text('Kişi bulunamadı.')),
        AsyncData(value: final p?) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: ProfileAvatar(initials: p.initials, frame: p.cosmetics.frame, radius: 40),
            ),
            const SizedBox(height: 12),
            Text(
              [p.fullName, ?p.cosmetics.badge?.icon].join(' '),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: readableNameColor(context, p.cosmetics.nameColor?.colorValue),
              ),
            ),
            if (p.cosmetics.title != null)
              Text(
                [?p.cosmetics.title!.icon, p.cosmetics.title!.name].join(' '),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall,
              ),
            const SizedBox(height: 4),
            Text(
              [?p.schoolName, ?p.department, 'Seviye ${p.level}'].join(' · '),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (p.badges.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Başarımlar (${p.badges.length})', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final b in p.badges)
                    Tooltip(
                      message: '${b.title} (${tierLabel(b.tier)})',
                      child: AchievementBadge(tier: b.tier, achievementKey: b.key, category: b.category, size: 40),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Text('Sıralamalar', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (p.deleted)
              const Text('Bu hesap silinmiş.')
            else if (p.standings.isEmpty)
              const Text('Bu hafta ve tüm zamanlarda sıralamada görünmüyor.')
            else
              Card(
                child: Column(
                  children: [
                    for (final s in p.standings)
                      ListTile(
                        title: Text('${s.metric.label} · ${s.allTime ? 'Tüm zamanlar' : 'Bu hafta'}'),
                        subtitle: Text(metricDetailText(s.metric, s.value, s.sample)),
                        trailing: Text(
                          '${s.rank}. · ${metricValueText(s.metric, s.value)}',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
        AsyncError(:final error) => Center(child: Text('Profil açılamadı. ${userMessage(error)}')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
