import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase.dart';
import '../wallet/wallet_data.dart';
import 'profile_data.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).value?.profile;
    final balance = ref.watch(balanceProvider).value;
    final streak = ref.watch(loginStreakProvider).value;
    final theme = Theme.of(context);

    if (profile == null) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myProfileProvider);
        ref.invalidate(balanceProvider);
        ref.invalidate(loginStreakProvider);
        await ref.read(balanceProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(profile.fullName, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            [profile.schoolName, ?profile.department].join(' · '),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
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
                ListTile(
                  leading: const Icon(Icons.military_tech_outlined),
                  title: const Text('Seviye'),
                  trailing: Text('${profile.level} · ${formatAmount(profile.xp)} XP', style: theme.textTheme.titleMedium),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => ref.read(supabaseProvider).auth.signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Çıkış yap'),
          ),
        ],
      ),
    );
  }
}
