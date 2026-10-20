import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase.dart';

class School {
  const School({required this.id, required this.name});

  final String id;
  final String name;

  factory School.fromJson(Map<String, dynamic> json) =>
      School(id: json['id'] as String, name: json['name'] as String);
}

class Profile {
  const Profile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.schoolName,
    this.department,
    this.level = 1,
    this.xp = 0,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String schoolName;
  final String? department;
  final int level;
  final int xp;

  String get fullName => '$firstName $lastName';

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    firstName: json['first_name'] as String,
    lastName: json['last_name'] as String,
    schoolName: (json['school'] as Map<String, dynamic>?)?['name'] as String? ?? '',
    department: json['department'] as String?,
    level: json['level'] as int,
    xp: json['xp'] as int,
  );
}

/// Profil sorgusunun sonucu, hangi kullanıcı için yapıldığıyla birlikte. Kullanıcı değişince
/// eski kullanıcının sonucu yönlendirmede kullanılmasın diye `userId` taşınır.
class ProfileStatus {
  const ProfileStatus({required this.userId, required this.profile});

  final String? userId;

  /// Profil henüz oluşturulmadıysa null.
  final Profile? profile;
}

// profiles ile clusters arasında birden çok ilişki var (school_id, user_clusters, permissions);
// "!school_id" olmadan PostgREST hangisini kullanacağını bilemez (PGRST201).
const _profileColumns = 'id, first_name, last_name, department, level, xp, school:clusters!school_id(name)';

final myProfileProvider = FutureProvider<ProfileStatus>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const ProfileStatus(userId: null, profile: null);
  final row = await ref
      .watch(supabaseProvider)
      .from('profiles')
      .select(_profileColumns)
      .eq('id', userId)
      .maybeSingle();
  return ProfileStatus(userId: userId, profile: row == null ? null : Profile.fromJson(row));
});

/// Kayıtta seçilebilen okullar (kök kümeler).
final schoolsProvider = FutureProvider<List<School>>((ref) async {
  final rows = await ref
      .watch(supabaseProvider)
      .from('clusters')
      .select('id, name')
      .eq('type', 'school')
      .order('name');
  return rows.map(School.fromJson).toList();
});

/// `public.create_profile`: profil, okul üyeliği, bakiye ve başlangıç SP'si sunucuda tek işlemde oluşur.
Future<void> createProfile(
  WidgetRef ref, {
  required String firstName,
  required String lastName,
  required String schoolId,
  String? department,
}) async {
  await ref.read(supabaseProvider).rpc(
    'create_profile',
    params: {
      'p_first_name': firstName,
      'p_last_name': lastName,
      'p_school_id': schoolId,
      'p_department': department,
    },
  );
  ref.invalidate(myProfileProvider);
}
