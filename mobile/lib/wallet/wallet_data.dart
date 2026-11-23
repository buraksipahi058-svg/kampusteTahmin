import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase.dart';

// Para mantığı istemcide hesaplanmaz: bakiye, seri ve ödül her zaman sunucudan okunur.

class Balance {
  const Balance({required this.sp, required this.ssp});

  final int sp;
  final int ssp;
}

class LoginStreak {
  const LoginStreak({required this.current, required this.longest});

  final int current;
  final int longest;
}

class DailyReward {
  const DailyReward({required this.claimed, required this.amount, required this.streak});

  /// Bugünün ödülü bu çağrıda mı alındı (aynı gün tekrar çağrılınca false).
  final bool claimed;
  final int amount;
  final int streak;
}

final balanceProvider = FutureProvider<Balance?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  final row = await ref
      .watch(supabaseProvider)
      .from('balances')
      .select('sp_balance, ssp_balance')
      .eq('user_id', userId)
      .maybeSingle();
  if (row == null) return null;
  return Balance(sp: row['sp_balance'] as int, ssp: row['ssp_balance'] as int);
});

final loginStreakProvider = FutureProvider<LoginStreak?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  final row = await ref
      .watch(supabaseProvider)
      .from('login_streaks')
      .select('current_streak, longest_streak')
      .eq('user_id', userId)
      .maybeSingle();
  if (row == null) return null;
  return LoginStreak(current: row['current_streak'] as int, longest: row['longest_streak'] as int);
});

/// Günlük ödül takviminin bir günü (`public.daily_login_calendar`): serinin kaçıncı günü, ödül, kilometre taşı
/// bonusu, alındı mı, bugün mü.
class CalendarDay {
  const CalendarDay({required this.day, required this.amount, this.bonus = 0, this.claimed = false, this.isToday = false});

  final int day;
  final int amount;
  final int bonus;
  final bool claimed;
  final bool isToday;

  factory CalendarDay.fromJson(Map<String, dynamic> json) => CalendarDay(
    day: json['day'] as int,
    amount: json['amount'] as int,
    bonus: json['bonus'] as int,
    claimed: json['claimed'] as bool,
    isToday: json['is_today'] as bool,
  );
}

/// Günlük ödülün sunucu tarafı (testte sahtesiyle değiştirilir). Tutarı hep sunucu hesaplar.
class DailyRewardApi {
  const DailyRewardApi(this._client);

  final SupabaseClient _client;

  Future<List<CalendarDay>> calendar() async {
    final rows = await _client.rpc('daily_login_calendar') as List;
    return [for (final r in rows) CalendarDay.fromJson(r as Map<String, dynamic>)];
  }

  /// `public.claim_daily_login`: aynı gün ikinci çağrı ödül vermez (`claimed: false`).
  Future<DailyReward> claim() async {
    final row = await _client.rpc('claim_daily_login').single();
    return DailyReward(
      claimed: row['claimed'] as bool,
      amount: row['amount'] as int,
      streak: row['current_streak'] as int,
    );
  }
}

final dailyRewardApiProvider = Provider<DailyRewardApi>((ref) => DailyRewardApi(ref.watch(supabaseProvider)));

/// Serinin içinde bulunulan 7 günlük dilim.
final dailyCalendarProvider = FutureProvider<List<CalendarDay>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  return ref.watch(dailyRewardApiProvider).calendar();
});

/// Bugünün ödülü alınabilir mi (takvim yüklendiyse).
final dailyRewardReadyProvider = Provider<bool>((ref) {
  final days = ref.watch(dailyCalendarProvider).value ?? const <CalendarDay>[];
  return days.any((d) => d.isToday && !d.claimed);
});

/// Günlük ödülü alır; bakiye, seri, takvim ve XP sunucudan yeniden okunur.
Future<DailyReward> claimDailyReward(ProviderContainer c) async {
  final reward = await c.read(dailyRewardApiProvider).claim();
  c.invalidate(balanceProvider);
  c.invalidate(loginStreakProvider);
  c.invalidate(dailyCalendarProvider);
  return reward;
}

/// Görüntüleme için binlik ayraç: 1050 → "1.050".
String formatAmount(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
