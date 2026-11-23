import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase.dart';

/// Sunucunun istek bekçisi silinmiş / yasaklı hesabın her isteğini `KB025` ile reddeder.
bool isAccountBlocked(Object error) => error is PostgrestException && error.code == 'KB025';

/// Bir veri sağlayıcısı `KB025` alırsa oturum bu cihazda kapatılır; yönlendirici giriş ekranına götürür.
/// (Yasaklamada sunucu oturumları zaten siler; elde kalan erişim anahtarı süresi dolana dek her isteği
/// reddedilir, bu da uygulamanın hatalarla dolu kalmasını önler.)
final class AccountGuard extends ProviderObserver {
  const AccountGuard();

  @override
  void providerDidFail(ProviderObserverContext context, Object error, StackTrace stackTrace) {
    if (!isAccountBlocked(error)) return;
    final auth = context.container.read(supabaseProvider).auth;
    if (auth.currentSession != null) auth.signOut(scope: SignOutScope.local);
  }
}

/// Şifre sıfırlama linkiyle açılan oturum: sekmeler açılınca "Şifreyi değiştir" ekranı gösterilir.
class PasswordRecovery extends Notifier<bool> {
  @override
  bool build() => false;

  void start() => state = true;

  void clear() => state = false;
}

final passwordRecoveryProvider = NotifierProvider<PasswordRecovery, bool>(PasswordRecovery.new);
