import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../achievements/achievements_data.dart';
import '../core/supabase.dart';

// XP ve seviye sunucuda verilir ve hesaplanır (günlük giriş, görev, doğru tahmin; `my_progress`).
// XP paradan ayrıdır: satın alınmaz, harcanmaz, yatırılan miktarla artmaz. İstemci yalnızca gösterir.

class Progress {
  const Progress({
    required this.xp,
    required this.level,
    required this.levelXp,
    required this.nextLevelXp,
    required this.pickXpToday,
  });

  final int xp;
  final int level;

  /// Bu seviyenin başladığı toplam XP.
  final int levelXp;

  /// Sonraki seviyenin başladığı toplam XP.
  final int nextLevelXp;

  /// Bugün doğru tahminden alınan XP (günlük sınıra sayılır).
  final int pickXpToday;

  int get toNextLevel => nextLevelXp - xp;

  /// Seviye içindeki ilerleme (0–1).
  double get fraction => nextLevelXp <= levelXp ? 1 : ((xp - levelXp) / (nextLevelXp - levelXp)).clamp(0, 1).toDouble();

  factory Progress.fromJson(Map<String, dynamic> json) => Progress(
    xp: json['xp'] as int,
    level: json['level'] as int,
    levelXp: json['level_xp'] as int,
    nextLevelXp: json['next_level_xp'] as int,
    pickXpToday: json['pick_xp_today'] as int,
  );
}

/// `public.my_progress`: XP, seviye, seviye aralığı.
final myProgressProvider = FutureProvider<Progress?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  final rows = await ref.watch(supabaseProvider).rpc('my_progress') as List;
  return rows.isEmpty ? null : Progress.fromJson(rows.first as Map<String, dynamic>);
});

/// XP kuralları (ekonomi ayarları, herkes okur).
typedef XpRules = ({int dailyLogin, int correctPick, int dailyPickCap});

final xpRulesProvider = FutureProvider<XpRules>((ref) async {
  final row = await ref
      .watch(supabaseProvider)
      .from('economy_settings')
      .select('xp_daily_login, xp_correct_pick, xp_daily_pick_cap')
      .single();
  return (
    dailyLogin: row['xp_daily_login'] as int,
    correctPick: row['xp_correct_pick'] as int,
    dailyPickCap: row['xp_daily_pick_cap'] as int,
  );
});

const xpReasonLabels = {'daily_login': 'Günlük giriş', 'quest': 'Görev ödülü', 'correct_pick': 'Doğru tahmin'};

class XpEvent {
  const XpEvent({required this.reason, required this.amount, required this.createdAt});

  /// daily_login, quest, correct_pick
  final String reason;
  final int amount;
  final DateTime createdAt;

  String get label => xpReasonLabels[reason] ?? reason;

  factory XpEvent.fromJson(Map<String, dynamic> json) => XpEvent(
    reason: json['reason'] as String,
    amount: json['amount'] as int,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

/// Son XP kazançları (RLS: yalnızca kişinin kendisi).
final xpEventsProvider = FutureProvider<List<XpEvent>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final rows = await ref
      .watch(supabaseProvider)
      .from('xp_events')
      .select('reason, amount, created_at')
      .eq('user_id', userId)
      .order('id')
      .limit(20);
  return rows.map(XpEvent.fromJson).toList();
});

/// XP değişmiş olabilecek her işlemden sonra (giriş ödülü, görev, bahis sonucu) çağrılır.
void refreshProgress(ProviderContainer c) {
  c.invalidate(myProgressProvider);
  c.invalidate(xpEventsProvider);
  // Başarım ilerlemesi de aynı olaylardan (giriş, görev, bahis, satın alma) değişir.
  c.invalidate(achievementsProvider);
}
