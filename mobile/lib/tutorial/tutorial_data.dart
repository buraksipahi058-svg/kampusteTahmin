import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_info.dart';
import '../core/supabase.dart';

/// "Nasıl oynanır" öğreticisinin hesapta görülüp görülmediği. Hesaba bağlıdır (Supabase Auth kullanıcı metadatası
/// `tutorial_version`, kayıttaki `terms_version` gibi): başka telefonda yeniden çıkmaz, veritabanı tablosu gerekmez.
/// Yalnızca arayüz tercihidir; kişi kendisi değiştirebilir, güvenlikle ilgisi yoktur.
abstract class TutorialStore {
  bool get seen;

  /// Görüldü olarak kaydeder. Bağlantı yoksa sessizce vazgeçer (öğretici sonraki açılışta bir kez daha çıkar).
  Future<void> markSeen();
}

class SupabaseTutorialStore implements TutorialStore {
  SupabaseTutorialStore(this._client);

  final SupabaseClient _client;

  @override
  bool get seen {
    final version = _client.auth.currentUser?.userMetadata?['tutorial_version'];
    return version is num && version >= AppInfo.tutorialVersion;
  }

  @override
  Future<void> markSeen() async {
    try {
      await _client.auth.updateUser(UserAttributes(data: {'tutorial_version': AppInfo.tutorialVersion}));
    } catch (_) {
      // Kaydedilemedi: bu oturumda yine açılmaz (TutorialSession), sonraki açılışta bir kez daha gösterilir.
    }
  }
}

final tutorialStoreProvider = Provider<TutorialStore>((ref) => SupabaseTutorialStore(ref.watch(supabaseProvider)));

/// Öğreticinin bu oturumdaki durumu: kime kendiliğinden açıldı ve şu an açık mı (açıkken günlük ödül penceresi
/// üstüne binmesin diye beklenir).
class TutorialSession extends Notifier<({String? promptedFor, bool open})> {
  @override
  ({String? promptedFor, bool open}) build() => (promptedFor: null, open: false);

  void opened(String userId) => state = (promptedFor: userId, open: true);

  void closed() => state = (promptedFor: state.promptedFor, open: false);
}

final tutorialSessionProvider = NotifierProvider<TutorialSession, ({String? promptedFor, bool open})>(
  TutorialSession.new,
);
