import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../achievements/achievements_data.dart';
import '../core/app_theme.dart';
import '../core/count_chevron.dart';
import '../core/design_tokens.dart';
import '../core/routes.dart';
import '../core/supabase.dart';
import '../leaderboard/leaderboard_data.dart';
import '../leaderboard/my_stats_card.dart';
import '../market/cosmetic_preview.dart';
import '../market/market_data.dart';
import '../progress/level_card.dart';
import '../progress/progress_data.dart';
import '../quests/quests_data.dart';
import '../wallet/wallet_data.dart';
import 'delete_account.dart';
import 'privacy_card.dart';
import 'profile_data.dart';
import 'student_email_data.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).value?.profile;
    final balance = ref.watch(balanceProvider).value;
    final streak = ref.watch(loginStreakProvider).value;
    final studentEmail = ref.watch(studentEmailProvider).value;
    final cosmetics = ref.watch(myCosmeticsProvider);
    final readyRewards = (ref.watch(questsProvider).value ?? const <Quest>[]).where((q) => q.claimable).length;
    final achievements = ref.watch(achievementsProvider).value ?? const <Achievement>[];
    final readyAchievements = achievements.where((a) => a.claimable).length;
    final theme = Theme.of(context);

    if (profile == null) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myProfileProvider);
        ref.invalidate(balanceProvider);
        ref.invalidate(loginStreakProvider);
        ref.invalidate(studentEmailProvider);
        ref.invalidate(myInventoryProvider);
        ref.invalidate(questsProvider);
        ref.invalidate(myStatsProvider);
        refreshProgress(containerOf(ref));
        await ref.read(balanceProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(Space.lg),
        children: [
          // Kuşanılmış kozmetikler: çerçeve, isim rengi, unvan, rozet (yalnızca görünüm).
          Row(
            children: [
              ProfileAvatar(initials: profile.initials, frame: cosmetics.frame),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.fullName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: readableNameColor(context, cosmetics.nameColor?.colorValue),
                      ),
                    ),
                    if (cosmetics.title != null)
                      Text(
                        [?cosmetics.title!.icon, cosmetics.title!.name].join(' '),
                        style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
                      ),
                    const SizedBox(height: 4),
                    Text([profile.schoolName, ?profile.department].join(' · '), style: theme.textTheme.bodyMedium),
                    if (cosmetics.badge != null) ...[
                      const SizedBox(height: 6),
                      Chip(
                        avatar: cosmetics.badge!.icon == null
                            ? const Icon(Symbols.star_rounded, fill: 1)
                            : Text(cosmetics.badge!.icon!),
                        label: Text(cosmetics.badge!.name),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (studentEmail != null && !studentEmail.verified) ...[
            const SizedBox(height: Space.lg),
            Card(
              child: ListTile(
                leading: const Icon(Symbols.mark_email_unread_rounded),
                title: const Text('Okul mailini doğrula'),
                subtitle: const Text('Bahis açmak ve bahse katılmak için gerekli'),
                trailing: const Icon(Symbols.chevron_right_rounded),
                onTap: () => context.push(Routes.verifyEmail),
              ),
            ),
          ],
          const SizedBox(height: Space.lg),
          // Bakiye ve seri tek bakışta: büyük, hizalı rakamlar.
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.lg, horizontal: Space.sm),
              child: Row(
                children: [
                  _Stat(
                    icon: Symbols.toll_rounded,
                    value: balance == null ? '…' : formatAmount(balance.sp),
                    label: 'SP',
                  ),
                  _Stat(
                    icon: Symbols.workspace_premium_rounded,
                    iconColor: context.appColors.ssp,
                    value: balance == null ? '…' : formatAmount(balance.ssp),
                    label: 'SSP',
                  ),
                  _Stat(
                    icon: Symbols.local_fire_department_rounded,
                    value: streak == null ? '…' : '${streak.current} gün',
                    label: streak == null ? 'Giriş serisi' : 'Seri · en uzun ${streak.longest}',
                  ),
                ],
              ),
            ),
          ),
          const _SectionTitle('İlerleme'),
          const LevelCard(),
          const SizedBox(height: Space.sm),
          Card(
            child: ListTile(
              leading: const Icon(Symbols.flag_rounded),
              title: const Text('Görevler'),
              subtitle: Text(readyRewards > 0 ? '$readyRewards ödül alınmayı bekliyor' : 'Günlük ve haftalık görevler'),
              trailing: CountChevron(count: readyRewards),
              onTap: () => context.push(Routes.quests),
            ),
          ),
          const SizedBox(height: Space.sm),
          Card(
            child: ListTile(
              leading: const Icon(Symbols.emoji_events_rounded),
              title: const Text('Başarımlar'),
              subtitle: Text(
                achievements.isEmpty
                    ? 'Tahmin, seri, düello ve daha fazlası'
                    : '${achievements.where((a) => a.unlocked).length} / ${achievements.length} kazanıldı'
                          '${readyAchievements > 0 ? ' · $readyAchievements ödül hazır' : ''}',
              ),
              trailing: CountChevron(count: readyAchievements),
              onTap: () => context.push(Routes.achievements),
            ),
          ),
          const _SectionTitle('İstatistik'),
          const MyStatsCard(),
          const SizedBox(height: Space.sm),
          Card(
            child: ListTile(
              leading: const Icon(Symbols.history_rounded),
              title: const Text('Geçmiş bahislerim'),
              subtitle: const Text('Katıldığın bahisler ve sonuçları'),
              trailing: const Icon(Symbols.chevron_right_rounded),
              onTap: () => context.push(Routes.history),
            ),
          ),
          const _SectionTitle('Hesap'),
          Card(
            child: Column(
              children: [
                if (studentEmail case StudentEmail(verified: true, :final email)) ...[
                  ListTile(
                    leading: Icon(Symbols.verified_rounded, fill: 1, color: theme.colorScheme.primary),
                    title: const Text('Okul maili doğrulandı'),
                    subtitle: Text(email ?? ''),
                  ),
                  const Divider(indent: Space.lg, endIndent: Space.lg),
                ],
                ListTile(
                  leading: const Icon(Symbols.password_rounded),
                  title: const Text('Şifreyi değiştir'),
                  trailing: const Icon(Symbols.chevron_right_rounded),
                  onTap: () => context.push(Routes.changePassword),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.sm),
          const PrivacyCard(),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => ref.read(supabaseProvider).auth.signOut(),
            icon: const Icon(Symbols.logout_rounded),
            label: const Text('Çıkış yap'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => confirmDeleteAccount(context, ref),
            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
            icon: const Icon(Symbols.delete_forever_rounded),
            label: const Text('Hesabımı sil'),
          ),
        ],
      ),
    );
  }
}

/// Profil grubu başlığı (İlerleme, İstatistik, Hesap).
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xs, Space.xl, Space.xs, Space.sm),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 1.6,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Bakiye şeridinde bir değer: simge, büyük sabit genişlikli sayı, altında açıklama.
class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label, this.iconColor});

  final IconData icon;
  final String value;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: iconColor ?? theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: Space.xs),
          Text(value, style: tabular(theme.textTheme.titleLarge), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}
