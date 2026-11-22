import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase.dart';
import '../leaderboard/leaderboard_data.dart';

/// Gizlilik işlemlerinin sunucu ve paylaşım tarafı (testte sahtesiyle değiştirilir).
class PrivacyApi {
  const PrivacyApi(this._client);

  final SupabaseClient _client;

  /// `public.set_leaderboard_hidden`: gizlenince sıralama satırları hemen silinir.
  Future<void> setLeaderboardHidden(bool hidden) async {
    await _client.rpc('set_leaderboard_hidden', params: {'p_hidden': hidden});
  }

  /// `public.export_my_data`: kişinin bütün kayıtları, tek JSON nesnesi.
  Future<Object?> exportMyData() async => await _client.rpc('export_my_data');

  /// Telefonun paylaş menüsü (e-posta, Drive, Dosyalar...). Dosya önce uygulamanın geçici klasörüne yazılır.
  Future<void> shareFile(String name, Uint8List bytes) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'application/json')],
        fileNameOverrides: [name],
        subject: 'KampüsBet verilerim',
      ),
    );
  }
}

final privacyApiProvider = Provider<PrivacyApi>((ref) => PrivacyApi(ref.watch(supabaseProvider)));

/// Sıralamada gizli mi (`profile_private.leaderboard_hidden`; yalnızca kişinin kendisi görür).
final leaderboardHiddenProvider = FutureProvider<bool>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return false;
  final row = await ref
      .watch(supabaseProvider)
      .from('profile_private')
      .select('leaderboard_hidden')
      .eq('user_id', userId)
      .maybeSingle();
  return row?['leaderboard_hidden'] as bool? ?? false;
});

Future<void> setLeaderboardHidden(WidgetRef ref, bool hidden) async {
  final c = containerOf(ref);
  await c.read(privacyApiProvider).setLeaderboardHidden(hidden);
  c.invalidate(leaderboardHiddenProvider);
  c.invalidate(leaderboardProvider);
  c.invalidate(myStatsProvider);
}

/// Dışa aktarılan dosyanın adı: `kampusbet-verilerim-YYYYAAGG.json`.
String dataExportFileName(DateTime now) {
  String two(int n) => n.toString().padLeft(2, '0');
  return 'kampusbet-verilerim-${now.year}${two(now.month)}${two(now.day)}.json';
}

/// Verileri sunucudan alır, okunur JSON dosyası yapar ve paylaş menüsünü açar. Dosya adını döner.
Future<String> exportMyData(WidgetRef ref) async {
  final api = ref.read(privacyApiProvider);
  final data = await api.exportMyData();
  final name = dataExportFileName(DateTime.now());
  final json = const JsonEncoder.withIndent('  ').convert(data);
  await api.shareFile(name, Uint8List.fromList(utf8.encode(json)));
  return name;
}
