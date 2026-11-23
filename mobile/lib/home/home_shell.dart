import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../achievements/achievements_data.dart';
import '../bets/bets_tab.dart';
import '../core/account_guard.dart';
import '../core/routes.dart';
import '../core/supabase.dart';
import '../games/games_tab.dart';
import '../leaderboard/leaderboard_tab.dart';
import '../market/market_tab.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_tab.dart';
import '../progress/progress_data.dart';
import '../wallet/balance_bar.dart';
import '../wallet/daily_reward_sheet.dart';
import '../wallet/wallet_data.dart';
import 'placeholder_tab.dart';

class HomeTab {
  const HomeTab({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.page,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget? page;

  Widget get view => page ?? PlaceholderTab(tab: this);
}

// Sekmelerin sırası alt çubuktaki sıradır. Sayfası olmayanlar şimdilik "yakında" gösterir.
const homeTabs = [
  HomeTab(
    path: Routes.bets,
    label: 'Bahisler',
    icon: Icons.how_to_vote_outlined,
    selectedIcon: Icons.how_to_vote,
    page: BetsTab(),
  ),
  HomeTab(
    path: Routes.games,
    label: 'Oyunlar',
    icon: Icons.sports_esports_outlined,
    selectedIcon: Icons.sports_esports,
    page: GamesTab(),
  ),
  HomeTab(
    path: Routes.market,
    label: 'Market',
    icon: Icons.storefront_outlined,
    selectedIcon: Icons.storefront,
    page: MarketTab(),
  ),
  HomeTab(
    path: Routes.leaderboard,
    label: 'Liderlik',
    icon: Icons.leaderboard_outlined,
    selectedIcon: Icons.leaderboard,
    page: LeaderboardTab(),
  ),
  HomeTab(
    path: Routes.profile,
    label: 'Profil',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    page: ProfileTab(),
  ),
];

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Açılışta bugünün ödülü alınmadıysa günlük ödül takvimi kişi başına bir kez kendiliğinden açılır.
    ref.listen(dailyRewardReadyProvider, (_, ready) {
      final userId = ref.read(currentUserIdProvider);
      if (!ready || userId == null || ref.read(dailyRewardPromptedProvider) == userId) return;
      ref.read(dailyRewardPromptedProvider.notifier).mark(userId);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) showDailyReward(context);
      });
    });
    final rewardReady = ref.watch(dailyRewardReadyProvider);

    // Yeni başarım haberi: hedefe yeni ulaşılan başarım (ilerleme yeniden okununca) ya da açılışta bekleyen ödüller
    // (kişi başına bir kez). "Gör" başarımlar ekranını açar.
    ref.listen(achievementsProvider, (previous, next) {
      final now = next.value;
      final userId = ref.read(currentUserIdProvider);
      if (now == null || userId == null) return;
      final message = newAchievementMessage(
        previous?.value,
        now,
        firstLoadAnnounced: ref.read(achievementsAnnouncedProvider) == userId,
      );
      ref.read(achievementsAnnouncedProvider.notifier).mark(userId);
      if (message == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(label: 'Gör', onPressed: () => context.push(Routes.achievements)),
        ),
      );
    });

    // Seviye atlayınca kutlama (ilerleme sunucudan yeniden okununca seviye büyüdüyse).
    ref.listen(myProgressProvider, (previous, next) {
      final before = previous?.value?.level;
      final after = next.value?.level;
      if (before != null && after != null && after > before) showLevelUp(context, after);
    });

    // Şifre sıfırlama linkiyle gelindiyse şifre ekranı bir kez açılır (olay sekmelerden önce de gelmiş olabilir).
    if (ref.watch(passwordRecoveryProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted || !ref.read(passwordRecoveryProvider)) return;
        ref.read(passwordRecoveryProvider.notifier).clear();
        context.push(Routes.changePassword);
      });
    }

    final tab = homeTabs[shell.currentIndex];
    return Scaffold(
      appBar: AppBar(
        title: Text(tab.label),
        actions: [
          const NotificationBell(),
          IconButton(
            tooltip: 'Günlük ödül',
            onPressed: () => showDailyReward(context),
            icon: Badge(isLabelVisible: rewardReady, child: const Icon(Icons.card_giftcard)),
          ),
          const BalanceBar(),
          const SizedBox(width: 8),
        ],
      ),
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) =>
            shell.goBranch(index, initialLocation: index == shell.currentIndex),
        destinations: [
          for (final t in homeTabs)
            NavigationDestination(icon: Icon(t.icon), selectedIcon: Icon(t.selectedIcon), label: t.label),
        ],
      ),
    );
  }
}

/// Seviye atlama kutlaması: yeni seviye ve markette seviyeyle açılan ürünlere bağlantı.
Future<void> showLevelUp(BuildContext context, int level) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (dialogContext) => AlertDialog(
      icon: const Text('🎉', style: TextStyle(fontSize: 40)),
      title: Text('Seviye $level!'),
      content: Text('Tebrikler, $level. seviyeye ulaştın. Markette seviyeyle açılan ürünler olabilir.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Tamam')),
        FilledButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            context.go(Routes.market);
          },
          child: const Text('Markete git'),
        ),
      ],
    ),
  );
}

/// Günlük ödül penceresinin kendiliğinden açıldığı kişi (oturum başına bir kez; çıkış / girişte yeni kişi için yine).
class DailyRewardPrompted extends Notifier<String?> {
  @override
  String? build() => null;

  void mark(String userId) => state = userId;
}

final dailyRewardPromptedProvider = NotifierProvider<DailyRewardPrompted, String?>(DailyRewardPrompted.new);

/// Açılışta bekleyen başarım ödüllerinin duyurulduğu kişi (oturum başına bir kez).
class AchievementsAnnounced extends Notifier<String?> {
  @override
  String? build() => null;

  void mark(String userId) => state = userId;
}

final achievementsAnnouncedProvider = NotifierProvider<AchievementsAnnounced, String?>(AchievementsAnnounced.new);

/// Başarım haberi metni: önceki listede kazanılmamış olup şimdi ödülü hazır olanlar; ilk yüklemede (önceki yok)
/// henüz duyurulmadıysa bekleyen bütün hazır ödüller. Haber yoksa null.
String? newAchievementMessage(List<Achievement>? before, List<Achievement> now, {required bool firstLoadAnnounced}) {
  final List<Achievement> fresh;
  if (before == null) {
    if (firstLoadAnnounced) return null;
    fresh = now.where((a) => a.claimable).toList();
  } else {
    final known = {for (final a in before) if (a.claimable || a.unlocked) a.key};
    fresh = now.where((a) => a.claimable && !known.contains(a.key)).toList();
  }
  if (fresh.isEmpty) return null;
  if (fresh.length == 1) return '🏆 Yeni başarım: ${fresh.first.icon} ${fresh.first.title}. Ödülünü al!';
  return '🏆 ${fresh.length} başarımın ödülü hazır!';
}
