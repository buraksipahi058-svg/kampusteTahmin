import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase.dart';

/// Okul maili durumu (`profile_private`; yalnızca kişinin kendisi görür).
/// Mail yalnızca doğrulanınca yazılır, doğrulanmamışsa ikisi de null'dır.
class StudentEmail {
  const StudentEmail({this.email, this.verifiedAt});

  final String? email;
  final DateTime? verifiedAt;

  bool get verified => verifiedAt != null;
}

final studentEmailProvider = FutureProvider<StudentEmail>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const StudentEmail();
  final row = await ref
      .watch(supabaseProvider)
      .from('profile_private')
      .select('student_email, student_email_verified_at')
      .eq('user_id', userId)
      .maybeSingle();
  final verifiedAt = row?['student_email_verified_at'] as String?;
  return StudentEmail(
    email: row?['student_email'] as String?,
    verifiedAt: verifiedAt == null ? null : DateTime.parse(verifiedAt),
  );
});

/// `public.request_student_email_code`: kod sunucuda üretilir ve maile gönderilir; istemci kodu hiç görmez.
/// Sunucunun düzenlediği (küçük harf, boşluksuz) adresi döner.
Future<String> requestStudentEmailCode(WidgetRef ref, String email) async {
  final rows = await ref.read(supabaseProvider).rpc('request_student_email_code', params: {'p_email': email}) as List;
  return (rows.first as Map<String, dynamic>)['email'] as String;
}

class ConfirmResult {
  const ConfirmResult({required this.verified, required this.attemptsLeft});

  final bool verified;
  final int attemptsLeft;
}

/// `public.confirm_student_email`: yanlış kod hata değil, kalan hakla döner.
Future<ConfirmResult> confirmStudentEmail(WidgetRef ref, String code) async {
  final c = containerOf(ref);
  final rows = await c.read(supabaseProvider).rpc('confirm_student_email', params: {'p_code': code}) as List;
  final row = rows.first as Map<String, dynamic>;
  final result = ConfirmResult(verified: row['verified'] as bool, attemptsLeft: row['attempts_left'] as int);
  if (result.verified) c.invalidate(studentEmailProvider);
  return result;
}
