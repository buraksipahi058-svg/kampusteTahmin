import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/error_messages.dart';
import 'wallet_data.dart';

/// Üst çubuktaki SP / SSP göstergesi. Dokununca bakiye sunucudan yeniden okunur.
class BalanceBar extends ConsumerWidget {
  const BalanceBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(balanceProvider);
    final value = balance.value;

    final Widget content;
    if (value != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Amount(icon: Icons.toll, amount: value.sp, unit: 'SP'),
          const SizedBox(width: 12),
          _Amount(icon: Icons.workspace_premium, amount: value.ssp, unit: 'SSP'),
        ],
      );
    } else if (balance.hasError) {
      content = const Icon(Icons.sync_problem);
    } else {
      content = const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2));
    }

    return Tooltip(
      message: balance.hasError ? userMessage(balance.error!) : 'Bakiyeyi yenile',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => ref.invalidate(balanceProvider),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: content),
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({required this.icon, required this.amount, required this.unit});

  final IconData icon;
  final int amount;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${formatAmount(amount)} $unit',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 4),
          Text(formatAmount(amount), style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 2),
          Text(unit, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
