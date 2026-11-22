import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_screen.dart';
import '../home/home_shell.dart';
import '../profile/create_profile_screen.dart';
import '../profile/profile_data.dart';
import '../profile/verify_email_screen.dart';
import 'loading_screen.dart';
import 'routes.dart';
import 'supabase.dart';

/// Akış: oturum yok → giriş; profil sorgusu bitmedi → yükleniyor; profil yok → profil oluşturma;
/// profil var → sekmeler. Yönlendirme gerekmiyorsa null.
@visibleForTesting
String? redirectFor({
  required String location,
  required String? userId,
  required AsyncValue<ProfileStatus> profile,
}) {
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
