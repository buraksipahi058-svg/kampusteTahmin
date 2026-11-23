import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../achievements/achievements_data.dart';
import '../core/supabase.dart';
import '../profile/profile_data.dart';
import '../wallet/wallet_data.dart';

// Market yalnızca kozmetiktir: hiçbir ürün bahis şansını, oranı ya da ödemeyi etkilemez (MIMARI §2).
// Fiyat, bakiye ve sahiplik sunucuda denetlenir (`purchase_market_item`).

const marketCategoryLabels = {
  'title': 'Unvan',
  'badge': 'Rozet',
  'frame': 'Profil çerçevesi',
  'name_color': 'İsim rengi',
};

/// Sunucudaki `#RRGGBB` renk metni (çerçeve, isim rengi).
Color? hexColor(String? hex) {
  if (hex == null || hex.length != 7) return null;
  final value = int.tryParse(hex.substring(1), radix: 16);
  return value == null ? null : Color(0xFF000000 | value);
}

class MarketItem {
  const MarketItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.currency,
    this.description,
    this.icon,
    this.color,
    this.availableFrom,
    this.availableUntil,
    this.active = true,
    this.minLevel = 1,
  });

  final String id;
  final String name;
  final String? description;

  /// title, badge, frame, name_color
  final String category;

  /// Unvan / rozet simgesi (emoji).
  final String? icon;

  /// Çerçeve / isim rengi, "#RRGGBB".
  final String? color;
  final int price;
  final String currency;
  final DateTime? availableFrom;
  final DateTime? availableUntil;
  final bool active;

  /// Satın almak için gereken en az seviye.
  final int minLevel;

  Color? get colorValue => hexColor(color);

  /// Şu an satın alınabilir mi (sunucu da aynı kuralı denetler).
  bool onSale(DateTime now) =>
      active &&
      (availableFrom == null || !now.isBefore(availableFrom!)) &&
      (availableUntil == null || now.isBefore(availableUntil!));

  factory MarketItem.fromJson(Map<String, dynamic> json) {
    DateTime? time(String key) => json[key] == null ? null : DateTime.parse(json[key] as String);
    return MarketItem(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      price: json['price'] as int,
      currency: json['currency'] as String,
      availableFrom: time('available_from'),
      availableUntil: time('available_until'),
      active: json['active'] as bool? ?? true,
      minLevel: json['min_level'] as int? ?? 1,
    );
  }
}

class OwnedItem {
  const OwnedItem({required this.item, required this.equipped});

  final MarketItem item;
  final bool equipped;
}

/// Kuşanılmış kozmetikler (türe göre en fazla biri).
class Cosmetics {
  const Cosmetics({this.title, this.badge, this.frame, this.nameColor});

  final MarketItem? title;
  final MarketItem? badge;
  final MarketItem? frame;
  final MarketItem? nameColor;
}

const marketItemColumns =
    'id, name, description, category, icon, color, price, currency, available_from, available_until, active, min_level';

/// Satıştaki ürünler (RLS: okulun ve genel ürünler). Satıştan kalkmış ama sahip olunanlar envanterden gelir.
final marketItemsProvider = FutureProvider<List<MarketItem>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final schoolId = await mySchoolId(ref);
  var query = ref.watch(supabaseProvider).from('market_items').select(marketItemColumns).eq('active', true);
  if (schoolId != null) query = query.or('school_id.is.null,school_id.eq.$schoolId');
  final rows = await query.order('price', ascending: true);
  return rows.map(MarketItem.fromJson).toList();
});

final myInventoryProvider = FutureProvider<List<OwnedItem>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final rows = await ref
      .watch(supabaseProvider)
      .from('user_inventory')
      .select('equipped, item:market_items($marketItemColumns)')
      .eq('user_id', userId)
      .order('acquired_at');
  return [
    for (final r in rows)
      if (r['item'] != null)
        OwnedItem(item: MarketItem.fromJson(r['item'] as Map<String, dynamic>), equipped: r['equipped'] as bool),
  ];
});

final myCosmeticsProvider = Provider<Cosmetics>((ref) {
  final owned = ref.watch(myInventoryProvider).value ?? const <OwnedItem>[];
  MarketItem? equipped(String category) =>
      owned.where((o) => o.equipped && o.item.category == category).firstOrNull?.item;
  return Cosmetics(
    title: equipped('title'),
    badge: equipped('badge'),
    frame: equipped('frame'),
    nameColor: equipped('name_color'),
  );
});

/// `public.purchase_market_item`: yeni bakiyeyi döner.
Future<int> purchaseItem(WidgetRef ref, String itemId) async {
  final c = containerOf(ref);
  final balance = await c.read(supabaseProvider).rpc('purchase_market_item', params: {'p_item_id': itemId});
  c.invalidate(myInventoryProvider);
  c.invalidate(balanceProvider);
  c.invalidate(achievementsProvider);
  return balance as int;
}

/// `public.set_item_equipped`: kuşanınca aynı türdeki diğer ürün çıkarılır.
Future<void> setItemEquipped(WidgetRef ref, String itemId, bool equipped) async {
  final c = containerOf(ref);
  await c.read(supabaseProvider).rpc('set_item_equipped', params: {'p_item_id': itemId, 'p_equipped': equipped});
  c.invalidate(myInventoryProvider);
}
