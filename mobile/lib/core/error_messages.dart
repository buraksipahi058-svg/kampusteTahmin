import 'package:flutter/foundation.dart';
import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sunucudan gelen hataları kullanıcı diline çeviren tek eşleme.
/// Veritabanı kodları: `docs/harita/veritabani.md` "Hata kodları"; yeni kod oraya ve buraya eklenir
/// (`test/error_messages_test.dart` ikisinin uyumunu denetler).
const databaseMessages = <String, String>{
  'KB001': 'Bakiyen yetersiz.',
  'KB002': 'Bu işlem için önce okul mailini doğrulaman gerekiyor.',
  'KB003': 'Bu bahis artık yatırıma kapalı.',
  'KB004': 'Bu bahse zaten yatırım yaptın.',
  'KB005': 'Bahis henüz kilitlenmedi, sonuçlandırılamaz.',
  'KB006': 'Bu bahis zaten sonuçlandı ya da iptal edildi.',
  'KB007': 'Bu mail adresi okulunun öğrenci maili değil.',
  'KB008': 'Bu okul maili başka bir hesaba bağlı.',
  'KB009': 'Okul mailin zaten doğrulanmış.',
  'KB010': 'Çok sık kod istedin. Bir dakika bekleyip tekrar dene (günde en fazla 5 kod).',
  'KB011': 'Kodun süresi doldu. Yeni kod iste.',
  'KB012': 'Çok fazla yanlış deneme yaptın. Yeni kod iste.',
  'KB013': 'Şu an mail gönderilemiyor. Daha sonra tekrar dene.',
  'KB014': 'Çok fazla itiraz kaybettiğin için şimdilik sosyal bahis açamaz ve hakem olamazsın.',
  'KB015': 'Bu bahsin sonucunu zaten girdin.',
  'KB016': 'Bu bahsin sonucuna artık itiraz edilemez.',
  'KB017': 'Bu bahiste çözülecek itiraz kalmadı.',
  'KB018': 'Bu düello artık katılıma ya da oynamaya açık değil.',
  'KB019': 'Görev henüz tamamlanmadı.',
  'KB020': 'Bu görevin ödülünü bu dönem zaten aldın.',
  'KB021': 'Bu ürün şu an satışta değil.',
  'KB022': 'Bu ürün zaten sende.',
  'KB023': 'Bu ürün için seviyen henüz yetmiyor.',
  'KB024': 'Sonuçlanmamış bahsin, düellon ya da hakemliğin varken hesabını silemezsin. Önce sonuçlanmalarını bekle.',
  '42501': 'Bu işlem için yetkin yok ya da oturumun kapanmış.',
  '23514': 'Girdiğin bilgilerden biri geçersiz. Kontrol edip tekrar dene.',
  '23505': 'Bu kayıt zaten var.',
  '23503': 'Seçtiğin kayıt artık yok. Sayfayı yenileyip tekrar dene.',
  'P0002': 'Aradığın kayıt bulunamadı.',
  '55000': 'Bu kayıt değiştirilemez.',
  '22003': 'İzin verilen üst sınır aşıldı.',
  // PostgREST: oturum anahtarı geçersiz / süresi dolmuş.
  'PGRST301': _sessionExpired,
  'PGRST303': _sessionExpired,
};

/// Supabase Auth hata kodları (`AuthException.code`).
const authMessages = <String, String>{
  'invalid_credentials': 'E-posta ya da şifre hatalı.',
  'email_not_confirmed': 'Önce e-postana gelen onay linkine tıklamalısın.',
  'user_already_exists': 'Bu e-postayla zaten bir hesap var. Giriş yapmayı dene.',
  'email_exists': 'Bu e-postayla zaten bir hesap var. Giriş yapmayı dene.',
  'weak_password': 'Şifre çok zayıf. Daha uzun ve tahmini zor bir şifre seç.',
  'email_address_invalid': 'Bu e-posta adresi geçersiz.',
  'email_address_not_authorized': 'Bu adrese şu an mail gönderilemiyor.',
  'over_email_send_rate_limit': 'Kısa sürede çok fazla mail istendi. Biraz bekleyip tekrar dene.',
  'over_request_rate_limit': 'Çok fazla deneme yapıldı. Biraz bekleyip tekrar dene.',
  'signup_disabled': 'Yeni kayıt şu an kapalı.',
  'validation_failed': 'Girdiğin bilgileri kontrol edip tekrar dene.',
  'session_not_found': _sessionExpired,
  'session_expired': _sessionExpired,
  'refresh_token_not_found': _sessionExpired,
};

const genericError = 'Bir şeyler ters gitti. Lütfen tekrar dene.';
const networkError = 'Sunucuya ulaşılamadı. İnternet bağlantını kontrol et.';
const _sessionExpired = 'Oturumunun süresi dolmuş. Lütfen tekrar giriş yap.';

String userMessage(Object error) {
  final message = switch (error) {
    PostgrestException(:final code) => databaseMessages[code],
    AuthRetryableFetchException() => networkError,
    AuthSessionMissingException() => _sessionExpired,
    AuthException(:final code) => authMessages[code],
    ClientException() => networkError,
    _ => null,
  };
  // Eşlenmemiş hata kullanıcıya genel mesajla gösterilir; ayrıntısı yalnızca geliştirmede günlüğe düşer.
  if (message == null && kDebugMode) debugPrint('Eşlenmemiş hata: $error');
  return message ?? genericError;
}
