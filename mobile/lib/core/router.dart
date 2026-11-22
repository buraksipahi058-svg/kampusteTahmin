import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_screen.dart';
import '../bets/create_social_bet_screen.dart';
import '../games/duel_play_screen.dart';
import '../home/home_shell.dart';
import '../legal/legal_screen.dart';
import '../profile/change_password_screen.dart';
import '../profile/create_profile_screen.dart';
import '../profile/history_screen.dart';
import '../profile/profile_data.dart';
import '../profile/verify_email_screen.dart';
import '../quests/quests_screen.dart';
import 'loading_screen.dart';
import 'routes.dart';
import 'supabase.dart';

/// Akış: oturum yok → giriş; profil sorgusu bitmedi → yükleniyor; profil yok → profil oluşturma;
/// profil var → sekmeler. KVKK metni ve kullanım koşulları her durumda açılır (kayıttan önce de). Yönlendirme gerekmiyorsa null.
@visibleForTesting
String? redirectFor({
  required String location,
  required String? userId,
  required AsyncValue<ProfileStatus> profile,
}) {
  if (location == Routes.privacy || location == Routes.terms) return null;
  if (userId == null) return location == Routes.auth ? null : Routes.auth;

  // Sonuç yoksa ya da önceki kullanıcıya aitse henüz bilinmiyor demektir.
  final status = profile.value;
  if (status == null || status.userId != userId) {
    return location == Routes.loading ? null : Routes.loading;
  }
  if (status.profile == null) {
    return location == Routes.createProfile ? null : Routes.createProfile;
  }
  const entryRoutes = {Routes.auth, Routes.loading, Routes.createProfile};
  return entryRoutes.contains(location) ? Routes.bets : null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(currentUserIdProvider, (_, _) => refresh.value++);
  ref.listen(myProfileProvider, (_, _) => refresh.value++);

  final router = GoRouter(
    initialLocation: Routes.loading,
    refreshListenable: refresh,
    redirect: (context, state) => redirectFor(
      location: state.matchedLocation,
      userId: ref.read(currentUserIdProvider),
      profile: ref.read(myProfileProvider),
    ),
    routes: [
      GoRoute(path: Routes.auth, builder: (_, _) => const AuthScreen()),
      GoRoute(path: Routes.loading, builder: (_, _) => const LoadingScreen()),
      GoRoute(path: Routes.createProfile, builder: (_, _) => const CreateProfileScreen()),
      GoRoute(path: Routes.verifyEmail, builder: (_, _) => const VerifyEmailScreen()),
      GoRoute(path: Routes.createSocialBet, builder: (_, _) => const CreateSocialBetScreen()),
      GoRoute(path: Routes.quests, builder: (_, _) => const QuestsScreen()),
      GoRoute(path: Routes.history, builder: (_, _) => const HistoryScreen()),
      GoRoute(path: Routes.privacy, builder: (_, _) => const LegalScreen(LegalDocument.privacy)),
      GoRoute(path: Routes.terms, builder: (_, _) => const LegalScreen(LegalDocument.terms)),
      GoRoute(path: Routes.changePassword, builder: (_, _) => const ChangePasswordScreen()),
      GoRoute(
        path: Routes.duelPlayPattern,
        builder: (_, state) => DuelPlayScreen(betId: state.pathParameters['id']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => HomeShell(shell: shell),
        branches: [
          for (final tab in homeTabs)
            StatefulShellBranch(routes: [GoRoute(path: tab.path, builder: (_, _) => tab.view)]),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
