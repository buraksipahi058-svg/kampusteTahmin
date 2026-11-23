import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase.dart';
import '../leaderboard/leaderboard_data.dart';
import '../market/market_data.dart';

/// Okul arkadaşı (kişi arama sonucu).
class Person {
  const Person({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.department,
    this.level = 1,
    this.canReferee = true,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String? department;
  final int level;

  /// İhtar sınırında değil: sosyal bahse hakem seçilebilir.
  final bool canReferee;

  String get fullName => '$firstName $lastName';

  String get initials => [firstName, lastName].where((s) => s.isNotEmpty).map((s) => s.substring(0, 1)).join();

  factory Person.fromJson(Map<String, dynamic> json) => Person(
    id: json['user_id'] as String,
    firstName: json['first_name'] as String,
    lastName: json['last_name'] as String,
    department: json['department'] as String?,
    level: json['level'] as int? ?? 1,
    canReferee: json['can_referee'] as bool? ?? true,
  );
}

/// `public.search_schoolmates`: okulun okul maili doğrulanmış öğrencileri (kendisi hariç), en fazla 20.
/// Meydan okuma ve hakem seçimi için; sunucu da ikisinde doğrulanmış okul arkadaşı ister.
final schoolmateSearchProvider = FutureProvider.autoDispose.family<List<Person>, String>((ref, query) async {
  final q = query.trim();
  if (q.length < 2) return const [];
  final rows = await ref.watch(supabaseProvider).rpc('search_schoolmates', params: {'p_query': q}) as List;
  return [for (final r in rows) Person.fromJson(r as Map<String, dynamic>)];
});

/// Kozmetik isteği için anahtar: tekrarsız, sıralı kişi kimlikleri (aynı kümeye aynı sorgu).
String cosmeticsKey(Iterable<String?> ids) => (ids.whereType<String>().toSet().toList()..sort()).join(',');

/// Kişilerin kuşandığı kozmetikler (RLS: okul arkadaşlarının kuşanılmış ürünleri görünür).
/// Anahtar [cosmeticsKey]; kuşanılmış ürünü olmayan kişi haritada yoktur.
final cosmeticsOfProvider = FutureProvider.autoDispose.family<Map<String, Cosmetics>, String>((ref, key) async {
  if (key.isEmpty) return const {};
  final rows = await ref
      .watch(supabaseProvider)
      .from('user_inventory')
      .select('user_id, item:market_items($marketItemColumns)')
      .eq('equipped', true)
      .inFilter('user_id', key.split(','));
  final byUser = <String, List<MarketItem>>{};
  for (final r in rows) {
    byUser.putIfAbsent(r['user_id'] as String, () => []).add(MarketItem.fromJson(r['item'] as Map<String, dynamic>));
  }
  return {for (final e in byUser.entries) e.key: cosmeticsFrom(e.value)};
});

/// Kuşanılmış ürünlerden türe göre kozmetikler.
Cosmetics cosmeticsFrom(Iterable<MarketItem> equipped) {
  MarketItem? of(String category) => equipped.where((i) => i.category == category).firstOrNull;
  return Cosmetics(title: of('title'), badge: of('badge'), frame: of('frame'), nameColor: of('name_color'));
}

/// Başkasının profilinde bir sıralama satırı.
class Standing {
  const Standing({
    required this.metric,
    required this.allTime,
    required this.rank,
    required this.value,
    required this.sample,
  });

  final LeaderboardMetric metric;
  final bool allTime;
  final int rank;
  final double value;
  final int sample;
}

/// Okul arkadaşının herkese açık profili: profil (okula zaten açık), kuşanılmış kozmetikler, bu haftaki ve
/// tüm zamanlar sıralama satırları (sıralamadan çıkan kişinin satırı yoktur). Bireysel yatırımlar görünmez.
class PublicProfile {
  const PublicProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.level,
    required this.deleted,
    required this.cosmetics,
    required this.standings,
    this.department,
    this.schoolName,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String? department;
  final String? schoolName;
  final int level;
  final bool deleted;
  final Cosmetics cosmetics;
  final List<Standing> standings;

  String get fullName => '$firstName $lastName';

  String get initials => [firstName, lastName].where((s) => s.isNotEmpty).map((s) => s.substring(0, 1)).join();
}

/// İstanbul'da (UTC+3, yaz saati yok) bu haftanın pazartesisi: sıralamadaki `period_start`.
DateTime istanbulWeekStart(DateTime now) {
  final local = now.toUtc().add(const Duration(hours: 3));
  final day = DateTime.utc(local.year, local.month, local.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

final publicProfileProvider = FutureProvider.autoDispose.family<PublicProfile?, String>((ref, userId) async {
  final client = ref.watch(supabaseProvider);
  final row = await client
      .from('profiles')
      .select('id, first_name, last_name, department, level, deleted_at, school:clusters!school_id(name)')
      .eq('id', userId)
      .maybeSingle();
  if (row == null) return null;
  final weekStart = istanbulWeekStart(DateTime.now());
  final weekDay =
      '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
  final snapshots = await client
      .from('leaderboard_snapshots')
      .select('period, period_start, metric, rank, value, sample')
      .eq('user_id', userId)
      .or('period.eq.all_time,period_start.eq.$weekDay');
  final cosmetics = await ref.watch(cosmeticsOfProvider(userId).future);
  final standings = [
    for (final s in snapshots)
      for (final metric in LeaderboardMetric.values)
        if (metric.key == s['metric'])
          Standing(
            metric: metric,
            allTime: s['period'] == 'all_time',
            rank: s['rank'] as int,
            value: (s['value'] as num).toDouble(),
            sample: s['sample'] as int,
          ),
  ]..sort((a, b) => a.allTime == b.allTime ? a.metric.index - b.metric.index : (a.allTime ? 1 : -1));
  return PublicProfile(
    id: row['id'] as String,
    firstName: row['first_name'] as String,
    lastName: row['last_name'] as String,
    department: row['department'] as String?,
    schoolName: (row['school'] as Map<String, dynamic>?)?['name'] as String?,
    level: row['level'] as int? ?? 1,
    deleted: row['deleted_at'] != null,
    cosmetics: cosmetics[userId] ?? const Cosmetics(),
    standings: standings,
  );
});
