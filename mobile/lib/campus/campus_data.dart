import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_info.dart';
import '../core/supabase.dart';
import '../notifications/notifications_data.dart';
import '../progress/progress_data.dart';
import '../wallet/wallet_data.dart';

/// Kampüs görevi (`public.my_campus_tasks`): okulun yetkilisinin açtığı, QR ya da fotoğrafla doğrulanan görev.
class CampusTask {
  const CampusTask({
    required this.id,
    required this.title,
    required this.icon,
    required this.verification,
    required this.period,
    required this.rewardCurrency,
    required this.rewardAmount,
    required this.rewardXp,
    this.description,
    this.quota,
    this.remaining,
    this.doneThisPeriod = 0,
    this.startsAt,
    this.endsAt,
    this.myStatus,
    this.myNote,
    this.canSubmit = false,
  });

  final String id;
  final String title;
  final String? description;
  final String icon;

  /// `qr` ya da `photo`.
  final String verification;

  /// `once`, `daily`, `weekly`.
  final String period;
  final String rewardCurrency;
  final int rewardAmount;
  final int rewardXp;
  final int? quota;
  final int? remaining;

  /// Okulda bu dönem yapan sayısı.
  final int doneThisPeriod;
  final DateTime? startsAt;
  final DateTime? endsAt;

  /// Kişinin bu dönemdeki gönderisi: `approved`, `pending`, `rejected`, `expired` ya da null.
  final String? myStatus;
  final String? myNote;
  final bool canSubmit;

  bool get notStarted => startsAt != null && startsAt!.isAfter(DateTime.now());

  factory CampusTask.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) => json[key] == null ? null : DateTime.parse(json[key] as String);
    return CampusTask(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String,
      verification: json['verification'] as String,
      period: json['period'] as String,
      rewardCurrency: json['reward_currency'] as String,
      rewardAmount: json['reward_amount'] as int,
      rewardXp: json['reward_xp'] as int,
      quota: json['quota'] as int?,
      remaining: json['remaining'] as int?,
      doneThisPeriod: json['done_this_period'] as int,
      startsAt: date('starts_at'),
      endsAt: date('ends_at'),
      myStatus: json['my_status'] as String?,
      myNote: json['my_note'] as String?,
      canSubmit: json['can_submit'] as bool,
    );
  }
}

String campusPeriodLabel(String period) => switch (period) {
  'daily' => 'Her gün',
  'weekly' => 'Her hafta',
  _ => 'Bir kez',
};

/// QR içeriği: `com.kampusbet.kampusbet://kampus-gorev?t=<görev>&c=<kod>`. Bizim QR'ımız değilse null.
({String taskId, String code})? parseCampusQr(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.scheme != AppInfo.authScheme || uri.host != 'kampus-gorev') return null;
  final taskId = uri.queryParameters['t'];
  final code = uri.queryParameters['c'];
  if (taskId == null || code == null || taskId.isEmpty || code.isEmpty) return null;
  return (taskId: taskId, code: code);
}

/// Kampüs görevlerinin sunucu tarafı (testte sahtesiyle değiştirilir).
class CampusApi {
  const CampusApi(this._client);

  final SupabaseClient _client;

  Future<List<CampusTask>> tasks() async {
    final rows = await _client.rpc('my_campus_tasks') as List;
    return [for (final r in rows) CampusTask.fromJson(r as Map<String, dynamic>)];
  }

  /// `public.submit_campus_task_qr`: kod doğruysa ödül hemen verilir. (para birimi, tutar, XP)
  Future<({String currency, int amount, int xp})> submitQr(String taskId, String code) async {
    final row = await _client
        .rpc('submit_campus_task_qr', params: {'p_task_id': taskId, 'p_code': code})
        .single();
    return (
      currency: row['reward_currency'] as String,
      amount: row['reward_amount'] as int,
      xp: row['reward_xp'] as int,
    );
  }
}

final campusApiProvider = Provider<CampusApi>((ref) => CampusApi(ref.watch(supabaseProvider)));

final campusTasksProvider = FutureProvider<List<CampusTask>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  return ref.watch(campusApiProvider).tasks();
});

/// Görev yapılınca: liste, bakiye, XP, başarımlar, bildirimler yeniden okunur.
void refreshAfterCampusTask(ProviderContainer c) {
  c.invalidate(campusTasksProvider);
  c.invalidate(balanceProvider);
  c.invalidate(unreadNotificationsProvider);
  refreshProgress(c);
}
