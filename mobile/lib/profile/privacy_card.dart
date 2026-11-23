import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/error_messages.dart';
import '../core/routes.dart';
import 'privacy_data.dart';

/// Profil'de "Gizlilik": liderlikte görünme tercihi, verilerimi indir, KVKK metni, kullanım koşulları.
class PrivacyCard extends ConsumerStatefulWidget {
  const PrivacyCard({super.key});

  @override
  ConsumerState<PrivacyCard> createState() => _PrivacyCardState();
}

class _PrivacyCardState extends ConsumerState<PrivacyCard> {
  bool _savingVisibility = false;
  bool _exporting = false;

  Future<void> _setVisible(bool visible) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _savingVisibility = true);
    try {
      await setLeaderboardHidden(ref, !visible);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            visible
                ? 'Bir sonraki hesaplamada (en geç 10 dakika) sıralamada görünürsün.'
                : 'Artık sıralamalarda görünmüyorsun.',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(userMessage(e))));
    } finally {
      if (mounted) setState(() => _savingVisibility = false);
    }
  }

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _exporting = true);
    try {
      await exportMyData(ref);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Veriler hazırlanamadı. ${userMessage(e)}')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hidden = ref.watch(leaderboardHiddenProvider).value;
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Symbols.leaderboard_rounded),
            title: const Text('Liderlikte görün'),
            subtitle: Text(
              hidden == true
                  ? 'Kapalı: okul arkadaşların seni sıralamalarda görmez'
                  : 'Okul arkadaşların seni sıralamalarda görür',
            ),
            value: hidden != true,
            onChanged: hidden == null || _savingVisibility ? null : _setVisible,
          ),
          ListTile(
            leading: const Icon(Symbols.download_rounded),
            title: const Text('Verilerimi indir'),
            subtitle: const Text('Hesabındaki bütün kayıtlar, JSON dosyası olarak'),
            trailing: _exporting
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Symbols.chevron_right_rounded),
            onTap: _exporting ? null : _export,
          ),
          ListTile(
            leading: const Icon(Symbols.privacy_tip_rounded),
            title: const Text('Gizlilik ve KVKK'),
            subtitle: const Text('Hangi verilerin neden işlendiği, hakların'),
            trailing: const Icon(Symbols.chevron_right_rounded),
            onTap: () => context.push(Routes.privacy),
          ),
          ListTile(
            leading: const Icon(Symbols.gavel_rounded),
            title: const Text('Kullanım koşulları'),
            trailing: const Icon(Symbols.chevron_right_rounded),
            onTap: () => context.push(Routes.terms),
          ),
        ],
      ),
    );
  }
}
