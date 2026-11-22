import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/routes.dart';
import '../core/supabase.dart';
import '../leaderboard/leaderboard_data.dart';
import '../leaderboard/my_stats_card.dart';
import '../market/cosmetic_preview.dart';
import '../market/market_data.dart';
import '../progress/level_card.dart';
import '../progress/progress_data.dart';
import 'delete_account.dart';
import 'privacy_card.dart';
import '../quests/quests_data.dart';
import '../wallet/wallet_data.dart';
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
        padding: const EdgeInsets.all(16),
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
                      style: theme.textTheme.headlineSmall?.copyWith(color: cosmetics.nameColor?.colorValue),
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
                        avatar: Text(cosmetics.badge!.icon ?? '★'),
                        label: Text(cosmetics.badge!.name),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: switch (studentEmail) {
              null => const ListTile(leading: Icon(Icons.school_outlined), title: Text('Okul maili')),
              StudentEmail(verified: true, :final email) => ListTile(
                leading: Icon(Icons.verified, color: theme.colorScheme.primary),
                title: const Text('Okul maili doğrulandı'),
                subtitle: Text(email ?? ''),
              ),
              _ => ListTile(
                leading: const Icon(Icons.mark_email_unread_outlined),
                title: const Text('Okul mailini doğrula'),
                subtitle: const Text('Bahis açmak ve bahse katılmak için gerekli'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.verifyEmail),
              ),
            },
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Görevler'),
              subtitle: Text(readyRewards > 0 ? '$readyRewards ödül alınmayı bekliyor' : 'Günlük ve haftalık görevler'),
              trailing: readyRewards > 0
                  ? Badge(label: Text('$readyRewards'), child: const Icon(Icons.chevron_right))
                  : const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.quests),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.toll),
                  title: const Text('SP'),
                  subtitle: const Text('Günlük ödül ve oyunlarla kazanılır'),
                  trailing: Text(balance == null ? '…' : formatAmount(balance.sp), style: theme.textTheme.titleMedium),
                ),
                ListTile(
                  leading: const Icon(Icons.workspace_premium),
                  title: const Text('SSP'),
                  subtitle: const Text('Resmi etkinlik ve görevlerle kazanılır'),
                  trailing: Text(balance == null ? '…' : formatAmount(balance.ssp), style: theme.textTheme.titleMedium),
                ),
                ListTile(
                  leading: const Icon(Icons.local_fire_department_outlined),
                  title: const Text('Giriş serisi'),
                  subtitle: Text(streak == null ? '' : 'En uzun: ${streak.longest} gün'),
                  trailing: Text(streak == null ? '…' : '${streak.current} gün', style: theme.textTheme.titleMedium),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const LevelCard(),
          const SizedBox(height: 8),
          const MyStatsCard(),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Geçmiş bahislerim'),
              subtitle: const Text('Katıldığın bahisler ve sonuçları'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.history),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.password),
              title: const Text('Şifreyi değiştir'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.changePassword),
            ),
          ),
          const SizedBox(height: 8),
          const PrivacyCard(),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => ref.read(supabaseProvider).auth.signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Çıkış yap'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => confirmDeleteAccount(context, ref),
            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Hesabımı sil'),
          ),
        ],
      ),
    );
  }
}
