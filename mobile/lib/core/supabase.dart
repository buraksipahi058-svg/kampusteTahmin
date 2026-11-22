import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// İşlemden (await) önce alınır: işlem sürerken ekran kapanırsa WidgetRef artık kullanılamaz (Riverpod
/// StateError verir ve başarılı işlem hata gibi görünür); container ekrandan bağımsızdır.
ProviderContainer containerOf(WidgetRef ref) => ProviderScope.containerOf(ref.context, listen: false);

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
