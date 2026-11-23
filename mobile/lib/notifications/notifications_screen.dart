import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/state_views.dart';
import '../core/error_messages.dart';
import '../core/routes.dart';
import '../core/supabase.dart';
import 'notifications_data.dart';

/// Üst çubuktaki zil: okunmamış sayısı rozetle. Sayı uygulama açıkken dakikada bir ve uygulamaya dönülünce
/// sunucudan yeniden okunur (Realtime yok).
class NotificationBell extends ConsumerStatefulWidget {
  const NotificationBell({super.key});

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell> {
  Timer? _timer;
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
    _lifecycle = AppLifecycleListener(onResume: _refresh);
  }

  void _refresh() {
    if (mounted) ref.invalidate(unreadNotificationsProvider);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(unreadNotificationsProvider).value ?? 0;
    return IconButton(
      tooltip: 'Bildirimler',
      onPressed: () => context.push(Routes.notifications),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

/// Bildirim türünün simgesi.
IconData notificationIcon(String kind) => switch (kind) {
  'bet_won' => Icons.emoji_events_outlined,
  'bet_lost' => Icons.sentiment_dissatisfied_outlined,
  'bet_refunded' || 'bet_cancelled' => Icons.undo,
  'social_result' => Icons.gavel_outlined,
  'dispute_received' || 'dispute_new' || 'dispute_resolved' => Icons.report_outlined,
  'duel_invite' || 'duel_accepted' => Icons.sports_kabaddi,
  'level_up' => Icons.military_tech_outlined,
  'referee_strike' => Icons.warning_amber_outlined,
  'referee_due' => Icons.schedule,
  'admin_grant' => Icons.account_balance_wallet_outlined,
  _ => Icons.notifications_outlined,
};

/// `/bildirimler`: son 50 bildirim, okunmamışlar vurgulu. Dokununca okundu olur ve ilgili ekran açılır.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, AppNotification n) async {
    final c = containerOf(ref);
    final router = GoRouter.of(context);
    if (n.unread) {
      try {
        await markNotificationsRead(c, [n.id]);
      } catch (_) {
        // Okundu işareti başarısız olsa da bildirimin gösterdiği yere gidilir.
      }
    }
    final link = n.link;
    if (link == null || !link.startsWith('/')) return;
    // Düello daveti / kabulü sunucuda Oyunlar sekmesine bağlı; doğrudan düello ekranı açılır (geri: Oyunlar).
    if (link == Routes.games && n.kind.startsWith('duel_')) {
      router.go(Routes.games);
      router.push(Routes.duels);
      return;
    }
    // Sekmeler yerine geçer, diğer ekranlar üstüne açılır.
    if (Routes.tabs.contains(link)) {
      router.go(link);
    } else {
      router.push(link);
    }
  }

  Future<void> _markAll(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await markNotificationsRead(containerOf(ref));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(userMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final list = ref.watch(notificationsProvider);
    final hasUnread = list.value?.any((n) => n.unread) ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
        actions: [
          if (hasUnread) TextButton(onPressed: () => _markAll(context, ref), child: const Text('Tümünü okundu say')),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(notificationsProvider);
          ref.invalidate(unreadNotificationsProvider);
          await ref.read(notificationsProvider.future);
        },
        child: switch (list) {
          AsyncData(:final value) when value.isEmpty => ListView(
            children: const [EmptyView(text: 'Henüz bildirimin yok.', icon: Icons.notifications_none)],
          ),
          AsyncData(:final value) => ListView.separated(
            itemCount: value.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final n = value[i];
              return ListTile(
                tileColor: n.unread ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.4) : null,
                leading: Icon(notificationIcon(n.kind)),
                title: Text(n.title, style: n.unread ? const TextStyle(fontWeight: FontWeight.w600) : null),
                subtitle: Text(n.body),
                trailing: Text(timeAgo(n.createdAt, DateTime.now()), style: theme.textTheme.labelSmall),
                onTap: () => _open(context, ref, n),
              );
            },
          ),
          AsyncError(:final error) => ListView(
            children: [
              ErrorView(
                what: 'Bildirimler alınamadı.',
                error: error,
                onRetry: () => ref.invalidate(notificationsProvider),
              ),
            ],
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}
