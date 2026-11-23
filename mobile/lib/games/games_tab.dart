import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../bets/bets_data.dart';
import '../campus/campus_data.dart';
import '../core/routes.dart';
import '../core/supabase.dart';
import '../core/verify_email_card.dart';
import '../profile/student_email_data.dart';
import '../wallet/wallet_data.dart';
import 'trivia_data.dart';

/// Oyunlar sekmesi: her oyunun kartı kendi ekranını açar (günün tahmini, kampüs görevleri, trivia düellosu).
/// Kartta, kişiyi bekleyen iş varsa sayısı rozet olarak görünür: yatırım yapmadığı açık soru, yapabileceği
/// kampüs görevi, sırası gelen ya da kendisine gelen düello.
class GamesTab extends ConsumerWidget {
  const GamesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verified = ref.watch(studentEmailProvider).value?.verified;
    final userId = ref.watch(currentUserIdProvider);
    final wagers = ref.watch(myWagersProvider).value ?? const <String, Wager>{};
    final now = DateTime.now();
    final ready = verified == true;

    final openPredictions = ready
        ? (ref.watch(dailyPredictionsProvider).value ?? const <Bet>[])
              .where((b) => b.status == 'open' && b.locksAt.isAfter(now) && !wagers.containsKey(b.id))
              .length
        : 0;
    final doableTasks = ready
        ? (ref.watch(campusTasksProvider).value ?? const <CampusTask>[]).where((t) => t.canSubmit && !t.notStarted).length
        : 0;
    final myDuels = ready
        ? (ref.watch(triviaDuelsProvider).value ?? const <TriviaDuel>[])
              .where((d) => d.canPlay(userId, now) || (d.invitedId == userId && d.canAccept(userId, now)))
              .length
        : 0;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dailyPredictionsProvider);
        ref.invalidate(campusTasksProvider);
        ref.invalidate(triviaDuelsProvider);
        ref.invalidate(myWagersProvider);
        ref.invalidate(balanceProvider);
        await ref.read(triviaDuelsProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (verified == false) ...[
            const VerifyEmailCard(
              'Okulundaki tahminleri, kampüs görevlerini ve düelloları görmek, oynamak için okul mailini doğrula',
            ),
            const SizedBox(height: 16),
          ],
          _GameCard(
            icon: Icons.lightbulb_outline,
            title: 'Günün tahmini',
            subtitle: "Evet ya da Hayır'a SP yatır, doğru bilenler havuzu paylaşır",
            count: openPredictions,
            countText: '$openPredictions soru tahminini bekliyor',
            route: Routes.dailyPredictions,
          ),
          _GameCard(
            icon: Icons.qr_code_2,
            title: 'Kampüs görevleri',
            subtitle: 'Yemekhane, kütüphane, etkinlik: QR okut ya da fotoğraf çek, ödül kazan',
            count: doableTasks,
            countText: '$doableTasks görev yapılabilir',
            route: Routes.campus,
          ),
          _GameCard(
            icon: Icons.quiz_outlined,
            title: 'Trivia düellosu',
            subtitle: 'Okulundan biriyle aynı soruları çöz, kazanan havuzu alır',
            count: myDuels,
            countText: '$myDuels düelloda sıra sende',
            route: Routes.duels,
          ),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.countText,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int count;
  final String countText;
  final String route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
          child: Icon(icon),
        ),
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle),
            if (count > 0)
              Text(countText, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
          ],
        ),
        trailing: count > 0
            ? Badge(label: Text('$count'), child: const Icon(Icons.chevron_right))
            : const Icon(Icons.chevron_right),
        onTap: () => context.push(route),
      ),
    );
  }
}
