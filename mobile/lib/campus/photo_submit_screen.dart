import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/async_button.dart';
import '../core/celebration.dart';
import '../core/error_messages.dart';
import '../core/haptics.dart';
import '../core/icon_badge.dart';
import '../core/state_views.dart';
import '../core/supabase.dart';
import '../wallet/wallet_data.dart';
import 'campus_data.dart';
import 'photo_proof.dart';

/// Kameradan fotoğraf çeker (galeri yok). Testte sahtesiyle değiştirilir. Vazgeçilirse null.
final photoCaptureProvider = Provider<Future<Uint8List?> Function()>(
  (ref) => () async {
    final file = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 2560, imageQuality: 92);
    return file?.readAsBytes();
  },
);

/// `/kampus-gorevleri/:id/foto`: kanıt fotoğrafını çek, önizle, gönder. Fotoğraf göndermeden önce küçültülür ve
/// konum / cihaz bilgisi silinir; yalnızca sen ve okulunun yetkilisi görür, karardan 30 gün sonra silinir.
class PhotoSubmitScreen extends ConsumerStatefulWidget {
  const PhotoSubmitScreen({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<PhotoSubmitScreen> createState() => _PhotoSubmitScreenState();
}

class _PhotoSubmitScreenState extends ConsumerState<PhotoSubmitScreen> {
  Uint8List? _photo;
  var _preparing = false;
  String? _error;

  Future<void> _capture() async {
    setState(() {
      _error = null;
      _preparing = true;
    });
    try {
      final raw = await ref.read(photoCaptureProvider)();
      if (raw == null) return;
      final jpeg = await compute(prepareProofPhoto, raw);
      if (mounted) setState(() => _photo = jpeg);
    } catch (e) {
      if (mounted) setState(() => _error = 'Fotoğraf hazırlanamadı. ${userMessage(e)}');
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  Future<void> _submit() async {
    final photo = _photo;
    if (photo == null) return;
    final c = containerOf(ref);
    final navigator = Navigator.of(context);
    setState(() => _error = null);
    try {
      await c.read(campusApiProvider).submitPhoto(widget.taskId, photo);
      refreshAfterCampusTask(c);
      if (!mounted) return;
      // Henüz ödül yok (onay bekler): kutlama titreşimi yerine hafif "gönderildi" titreşimi.
      Haptics.light();
      await showCelebration(
        context,
        haptic: false,
        icon: Symbols.photo_camera_rounded,
        tone: BadgeTone.primary,
        title: 'Gönderildi',
        message: 'Okulunun yetkilisi onaylayınca ödülün hesabına geçer; sonucu bildirimlerde görürsün.',
        actions: (dialogContext) => [
          FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Tamam')),
        ],
      );
      navigator.pop();
    } catch (e) {
      if (mounted) setState(() => _error = userMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final task = ref.watch(campusTasksProvider).value?.where((t) => t.id == widget.taskId).firstOrNull;
    final photo = _photo;
    return Scaffold(
      appBar: AppBar(title: Text(task?.title ?? 'Fotoğraf çek')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (task != null) ...[
            if (task.description != null) Text(task.description!, style: theme.textTheme.bodyMedium),
            Text(
              'Ödül: +${formatAmount(task.rewardAmount)} ${task.rewardCurrency}'
              '${task.rewardXp > 0 ? ' · +${task.rewardXp} XP' : ''} (onaylanınca)',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'Görevi yaparken fotoğrafını çek. Başkalarının yüzü görünmesin. Fotoğrafı yalnızca sen ve okulunun yetkilisi '
            'görür; konum ve cihaz bilgisi gönderilmeden silinir, fotoğraf karardan 30 gün sonra silinir.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          if (_preparing)
            const LoadingView()
          else if (photo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(photo, fit: BoxFit.contain),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 16),
          if (photo == null)
            FilledButton.icon(
              onPressed: _preparing ? null : _capture,
              icon: const Icon(Symbols.photo_camera_rounded),
              label: const Text('Fotoğraf çek'),
            )
          else ...[
            AsyncButton(onPressed: _submit, child: const Text('Gönder')),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _capture, child: const Text('Yeniden çek')),
          ],
        ],
      ),
    );
  }
}
