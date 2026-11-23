import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../achievements/achievements_data.dart';
import '../bets/bets_tab.dart';
import '../core/account_guard.dart';
import '../core/app_theme.dart';
import '../core/celebration.dart';
import '../core/design_tokens.dart';
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
  const HomeTab({required this.path, required this.label, required this.icon, required this.selectedIcon, this.page});

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
    icon: Symbols.how_to_vote_rounded,
    selectedIcon: Symbols.how_to_vote_rounded,
    page: BetsTab(),
  ),
  HomeTab(
    path: Routes.games,
    label: 'Oyunlar',
    icon: Symbols.sports_esports_rounded,
    selectedIcon: Symbols.sports_esports_rounded,
    page: GamesTab(),
  ),
  HomeTab(
    path: Routes.market,
    label: 'Market',
    icon: Symbols.storefront_rounded,
    selectedIcon: Symbols.storefront_rounded,
    page: MarketTab(),
  ),
  HomeTab(
    path: Routes.leaderboard,
    label: 'Liderlik',
    icon: Symbols.leaderboard_rounded,
    selectedIcon: Symbols.leaderboard_rounded,
    page: LeaderboardTab(),
  ),
  HomeTab(
    path: Routes.profile,
    label: 'Profil',
    icon: Symbols.person_rounded,
    selectedIcon: Symbols.person_rounded,
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
          content: Row(
            children: [
              Icon(Symbols.emoji_events_rounded, fill: 1, color: context.appColors.ssp),
              const SizedBox(width: Space.md),
              Expanded(child: Text(message)),
            ],
          ),
          action: SnackBarAction(label: 'Gör', onPressed: () => context.push(Routes.achievements)),
          // Düğmeli çubuk bu Flutter sürümünde varsayılan olarak kalıcı; alttaki düğmeleri örtmesin, kendiliğinden kapansın.
          persist: false,
          duration: const Duration(seconds: 6),
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
          // Büyük yazı ayarında zil rozeti en çok 1,3 kat büyür (üst çubukta ekran başlığına yer kalsın).
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const NotificationBell(),
                IconButton(
                  tooltip: 'Günlük ödül',
                  onPressed: () => showDailyReward(context),
                  icon: Badge(isLabelVisible: rewardReady, child: const Icon(Symbols.card_giftcard_rounded)),
                ),
              ],
            ),
          ),
          const BalanceBar(),
          const SizedBox(width: 8),
        ],
      ),
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) => shell.goBranch(index, initialLocation: index == shell.currentIndex),
        destinations: [
          for (final t in homeTabs)
            // Seçili sekmenin ikonu dolu, diğerleri çizgi.
            NavigationDestination(icon: Icon(t.icon), selectedIcon: Icon(t.selectedIcon, fill: 1), label: t.label),
        ],
      ),
    );
  }
}

/// Seviye atlama kutlaması: yeni seviye ve markette seviyeyle açılan ürünlere bağlantı.
Future<void> showLevelUp(BuildContext context, int level) {
  return showCelebration(
    context,
    useRootNavigator: true,
    icon: Symbols.military_tech_rounded,
    title: 'Seviye $level!',
    message: 'Tebrikler, $level. seviyeye ulaştın. Markette seviyeyle açılan ürünler olabilir.',
    actions: (dialogContext) => [
      TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Tamam')),
      FilledButton(
        onPressed: () {
          Navigator.pop(dialogContext);
          context.go(Routes.market);
        },
        child: const Text('Markete git'),
      ),
    ],
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
    final known = {
      for (final a in before)
        if (a.claimable || a.unlocked) a.key,
    };
    fresh = now.where((a) => a.claimable && !known.contains(a.key)).toList();
  }
  if (fresh.isEmpty) return null;
  if (fresh.length == 1) return 'Yeni başarım: ${fresh.first.title}. Ödülünü al!';
  return '${fresh.length} başarımın ödülü hazır!';
}
