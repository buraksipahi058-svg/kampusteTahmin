import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/celebration.dart';
import '../core/error_messages.dart';
import '../core/supabase.dart';
import '../wallet/wallet_data.dart';
import 'campus_data.dart';

/// Kamera görüntüsü: okunan her metni `onCode`'a verir. Testte kamerasız sahtesiyle değiştirilir.
typedef ScannerViewBuilder = Widget Function(void Function(String raw) onCode);

final scannerViewProvider = Provider<ScannerViewBuilder>(
  (ref) =>
      (onCode) => MobileScanner(
        onDetect: (capture) {
          for (final b in capture.barcodes) {
            final raw = b.rawValue;
            if (raw != null) onCode(raw);
          }
        },
      ),
);

/// `/kampus-gorevleri/:id/okut`: görevin QR'ını okut. Kod doğruysa ödül hemen gelir. Kamera açılmazsa kod
/// QR'ın altında yazılıdır, elle girilebilir.
class QrScanScreen extends ConsumerStatefulWidget {
  const QrScanScreen({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen> {
  // _busy: yeni kod kabul edilmez (gönderi sürüyor ya da tamamlandı); _requesting: sunucu yanıtı bekleniyor.
  var _busy = false;
  var _requesting = false;
  String? _hint;

  Future<void> _onCode(String raw) async {
    if (_busy) return;
    final parsed = parseCampusQr(raw);
    if (parsed == null) {
      setState(() => _hint = 'Bu bir KampüsBet görev QR\'ı değil.');
      return;
    }
    if (parsed.taskId != widget.taskId) {
      setState(() => _hint = 'Bu QR başka bir görevin. Doğru görevi seçip yeniden okut.');
      return;
    }
    await _submit(parsed.code);
  }

  Future<void> _submit(String code) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _requesting = true;
      _hint = null;
    });
    final c = containerOf(ref);
    final navigator = Navigator.of(context);
    try {
      final r = await c.read(campusApiProvider).submitQr(widget.taskId, code);
      refreshAfterCampusTask(c);
      if (!mounted) return;
      setState(() => _requesting = false);
      await showCelebration(
        context,
        icon: Symbols.task_alt_rounded,
        title: 'Görev tamam!',
        message: '+${formatAmount(r.amount)} ${r.currency}${r.xp > 0 ? ' · +${r.xp} XP' : ''} kazandın.',
        actions: (dialogContext) => [
          FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Harika')),
        ],
      );
      navigator.pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _requesting = false;
          _hint = userMessage(e);
        });
      }
    }
  }

  Future<void> _manual() async {
    final code = await showDialog<String>(context: context, builder: (_) => const _ManualCodeDialog());
    if (code != null && code.isNotEmpty) await _submit(code);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('QR okut')),
      body: Column(
        children: [
          Expanded(child: ref.watch(scannerViewProvider)(_onCode)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_requesting) const LinearProgressIndicator(),
                Text(
                  _hint ?? 'Mekândaki QR\'ı çerçeveye getir.',
                  textAlign: TextAlign.center,
                  style: _hint == null ? null : TextStyle(color: theme.colorScheme.error),
                ),
                TextButton(onPressed: _busy ? null : _manual, child: const Text('Kodu elle gir')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Kodu elle girme penceresi; metin denetleyicisi pencereyle birlikte (kapanış animasyonundan sonra) atılır.
class _ManualCodeDialog extends StatefulWidget {
  const _ManualCodeDialog();

  @override
  State<_ManualCodeDialog> createState() => _ManualCodeDialogState();
}

class _ManualCodeDialogState extends State<_ManualCodeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kodu elle gir'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        maxLength: 12,
        decoration: const InputDecoration(labelText: "QR'ın altındaki 12 karakter"),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(context, _controller.text.trim()), child: const Text('Gönder')),
      ],
    );
  }
}
