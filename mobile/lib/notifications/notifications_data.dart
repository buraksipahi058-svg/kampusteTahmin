import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase.dart';

/// Uygulama içi bildirim (`public.notifications`). Sunucu olay anında yazar; uygulama okur ve okundu işaretler.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.link,
    this.readAt,
  });

  final int id;
  final String kind;
  final String title;
  final String body;
  final String? link;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get unread => readAt == null;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final readAt = json['read_at'] as String?;
    return AppNotification(
      id: json['id'] as int,
      kind: json['kind'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      link: json['link'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      readAt: readAt == null ? null : DateTime.parse(readAt),
    );
  }
}

/// Bildirimlerin sunucu tarafı (testte sahtesiyle değiştirilir). RLS: kişi yalnızca kendi bildirimlerini görür.
class NotificationsApi {
  const NotificationsApi(this._client);

  final SupabaseClient _client;

  Future<List<AppNotification>> latest() async {
    final rows = await _client
        .from('notifications')
        .select('id, kind, title, body, link, created_at, read_at')
        .order('created_at', ascending: false)
        .limit(50);
    return rows.map(AppNotification.fromJson).toList();
  }

  Future<int> unreadCount() async {
    final res = await _client.from('notifications').select('id').isFilter('read_at', null).count(CountOption.exact);
    return res.count;
  }

  /// `public.mark_notifications_read`: null ise hepsi.
  Future<void> markRead([List<int>? ids]) async {
    await _client.rpc('mark_notifications_read', params: {'p_ids': ids});
  }
}

final notificationsApiProvider = Provider<NotificationsApi>((ref) => NotificationsApi(ref.watch(supabaseProvider)));

final notificationsProvider = FutureProvider<List<AppNotification>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  return ref.watch(notificationsApiProvider).latest();
});

final unreadNotificationsProvider = FutureProvider<int>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return 0;
  return ref.watch(notificationsApiProvider).unreadCount();
});

/// Okundu işaretler ve listeyi / sayıyı yeniden okur.
Future<void> markNotificationsRead(ProviderContainer c, [List<int>? ids]) async {
  await c.read(notificationsApiProvider).markRead(ids);
  c.invalidate(notificationsProvider);
  c.invalidate(unreadNotificationsProvider);
}

/// "5 dk önce", "3 sa önce", "dün", "21.11." gibi kısa zaman.
String timeAgo(DateTime at, DateTime now) {
  final diff = now.difference(at);
  if (diff.inMinutes < 1) return 'şimdi';
  if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
  if (diff.inHours < 24) return '${diff.inHours} sa önce';
  if (diff.inDays < 2) return 'dün';
  if (diff.inDays < 7) return '${diff.inDays} gün önce';
  final local = at.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.';
}
