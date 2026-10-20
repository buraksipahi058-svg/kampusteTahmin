import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Uygulama açılınca (ve her girişte) bir kez `public.claim_daily_login()` çağrılır.
/// Ödül alındıysa bakiye ve seri sunucudan yeniden okunur.
final dailyRewardProvider = FutureProvider<DailyReward?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  final row = await ref.watch(supabaseProvider).rpc('claim_daily_login').single();
  final reward = DailyReward(
    claimed: row['claimed'] as bool,
    amount: row['amount'] as int,
    streak: row['current_streak'] as int,
  );
  if (reward.claimed) {
    ref.invalidate(balanceProvider);
    ref.invalidate(loginStreakProvider);
  }
  return reward;
});

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
