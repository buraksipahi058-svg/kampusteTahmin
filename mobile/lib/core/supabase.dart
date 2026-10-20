import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tek Supabase istemcisi. Testlerde yerine sahte değerler konur (override).
final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

final _authChangesProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(supabaseProvider).auth.onAuthStateChange,
);

/// Giriş yapmış kullanıcının id'si; oturum yoksa null. Oturum açılınca / kapanınca yeniden hesaplanır.
final currentUserIdProvider = Provider<String?>((ref) {
  ref.watch(_authChangesProvider);
  return ref.watch(supabaseProvider).auth.currentUser?.id;
});
