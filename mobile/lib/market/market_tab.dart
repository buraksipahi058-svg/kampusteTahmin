import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/async_button.dart';
import '../core/error_messages.dart';
import '../progress/progress_data.dart';
import '../wallet/wallet_data.dart';
import 'cosmetic_preview.dart';
import 'market_data.dart';

/// Market sekmesi: SP vitrini ve yalnızca SSP ile alınan özel vitrin. Ürünler yalnızca görünümdür.
class MarketTab extends ConsumerStatefulWidget {
  const MarketTab({super.key});

  @override
  ConsumerState<MarketTab> createState() => _MarketTabState();
}

class _MarketTabState extends ConsumerState<MarketTab> {
  var _ssp = false;

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(marketItemsProvider);
    final owned = {for (final o in ref.watch(myInventoryProvider).value ?? const <OwnedItem>[]) o.item.id: o};
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(marketItemsProvider);
        ref.invalidate(myInventoryProvider);
        ref.invalidate(balanceProvider);
        await ref.read(marketItemsProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('SP vitrini'), icon: Icon(Icons.storefront_outlined)),
              ButtonSegment(value: true, label: Text('SSP özel'), icon: Icon(Icons.workspace_premium_outlined)),
            ],
            selected: {_ssp},
            onSelectionChanged: (s) => setState(() => _ssp = s.first),
          ),
          const SizedBox(height: 12),
          Text(
            _ssp
                ? 'Yalnızca SSP ile alınan özel ürünler. SSP resmi etkinlik ve görevlerle kazanılır.'
                : 'Unvan, rozet, çerçeve ve isim rengi. Ürünler yalnızca görünümdür; bahis şansını etkilemez.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          switch (items) {
            AsyncData(:final value) => _ItemList(
              items: value.where((i) => i.currency == (_ssp ? 'SSP' : 'SP')).toList(),
              owned: owned,
            ),
            AsyncError(:final error) => Column(
              children: [
                Text('Ürünler alınamadı. ${userMessage(error)}'),
                TextButton(onPressed: () => ref.invalidate(marketItemsProvider), child: const Text('Tekrar dene')),
              ],
            ),
            _ => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
          },
        ],
      ),
    );
  }
}

class _ItemList extends StatelessWidget {
  const _ItemList({required this.items, required this.owned});

  final List<MarketItem> items;
  final Map<String, OwnedItem> owned;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text('Bu vitrinde şu an ürün yok.')),
      );
    }
    return Column(children: [for (final item in items) MarketItemCard(item: item, owned: owned[item.id])]);
  }
}

class MarketItemCard extends ConsumerWidget {
  const MarketItemCard({super.key, required this.item, required this.owned});

  final MarketItem item;
  final OwnedItem? owned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owned = this.owned;
    final onSale = item.onSale(DateTime.now());
    final level = ref.watch(myProgressProvider).value?.level;
    final locked = level != null && level < item.minLevel;
    final subtitle = [
      marketCategoryLabels[item.category] ?? item.category,
      ?item.description,
      // Bölünmez boşluk: "5." satır sonunda tek kalmasın.
      if (item.minLevel > 1) '${item.minLevel}.\u00A0seviyede açılır',
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        leading: CosmeticPreview(item: item),
        title: Text(item.name),
        subtitle: Text(subtitle),
        trailing: switch (owned) {
          OwnedItem(equipped: true) => AsyncButton(
            kind: AsyncButtonKind.outlined,
            onPressed: () => _equip(context, ref, false),
            child: const Text('Çıkar'),
          ),
          OwnedItem() => AsyncButton(
            kind: AsyncButtonKind.tonal,
            onPressed: () => _equip(context, ref, true),
            child: const Text('Kuşan'),
          ),
          // Satış tarihi geçmişse "Satış bitti", başlamamışsa ya da kapalıysa "Yakında".
          null when !onSale =>
            Text(item.availableUntil != null && !DateTime.now().isBefore(item.availableUntil!) ? 'Satış bitti' : 'Yakında'),
          null when locked => OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.lock_outline, size: 18),
            label: Text('Seviye ${item.minLevel}'),
          ),
          null => AsyncButton(
            onPressed: () => _buy(context, ref),
            child: Text('${formatAmount(item.price)} ${item.currency}'),
          ),
        },
      ),
    );
  }

  Future<void> _buy(BuildContext context, WidgetRef ref) async {
    final balance = ref.read(balanceProvider).value;
    final have = balance == null ? null : (item.currency == 'SSP' ? balance.ssp : balance.sp);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.name),
        content: Text(
          '${formatAmount(item.price)} ${item.currency} karşılığında satın alınsın mı?'
          '${have == null ? '' : '\n${item.currency} bakiyen: ${formatAmount(have)}'}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Satın al')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await purchaseItem(ref, item.id);
      messenger.showSnackBar(SnackBar(content: Text('${item.name} artık sende. Kuşanmak için "Kuşan"a dokun.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(userMessage(e))));
    }
  }

  Future<void> _equip(BuildContext context, WidgetRef ref, bool equipped) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await setItemEquipped(ref, item.id, equipped);
      messenger.showSnackBar(SnackBar(content: Text(equipped ? '${item.name} kuşanıldı.' : '${item.name} çıkarıldı.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(userMessage(e))));
    }
  }
}
