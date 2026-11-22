/// Derleme anında `--dart-define-from-file=.env` ile gelen yapılandırma.
/// `.env` git'e girmez; örneği `.env.example`.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// Eksik ya da yanlış yapılandırmada kullanıcıya gösterilecek sorun; sorun yoksa null.
  static String? get problem {
    if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
      return 'Supabase ayarları eksik. Uygulamayı "flutter run --dart-define-from-file=.env" ile başlat.';
    }
    // Secret key uygulamaya asla girmez; yanlışlıkla konduysa çalışmayı reddet. Eski tip anahtarlar (JWT;
    // service_role da bu biçimde) ayırt edilmeden reddedilir: yalnızca publishable key kabul edilir.
    if (!supabasePublishableKey.startsWith('sb_publishable_')) {
      return 'Uygulamaya publishable key dışında bir anahtar verilmiş. .env dosyasında yalnızca publishable key '
          '(sb_publishable_...) olmalı.';
    }
    return null;
  }
}
