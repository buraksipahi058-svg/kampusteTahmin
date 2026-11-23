import 'package:flutter/material.dart';

import 'design_tokens.dart';
import 'haptics.dart';
import 'icon_badge.dart';

/// Nadir kutlama penceresi (seviye atlandı, görev tamam, gönderildi): ortada, %92'den ölçeklenip solarak girer
/// (250 ms, ease-out; "animasyonları azalt" açıksa yalnızca solar). Başarı titreşimi pencereyle aynı anda.
Future<void> showCelebration(
  BuildContext context, {
  required IconData icon,
  BadgeTone tone = BadgeTone.gold,
  required String title,
  required String message,
  required List<Widget> Function(BuildContext dialogContext) actions,
  bool useRootNavigator = false,
  bool haptic = true,
}) {
  if (haptic) Haptics.success();
  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: Motion.enter,
    pageBuilder: (dialogContext, _, _) =>
        _CelebrationDialog(icon: icon, tone: tone, title: title, message: message, actions: actions(dialogContext)),
    transitionBuilder: (transitionContext, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Motion.easeOut);
      final fade = FadeTransition(opacity: curved, child: child);
      if (Motion.reduced(transitionContext)) return fade;
      return ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(curved), child: fade);
    },
  );
}

class _CelebrationDialog extends StatelessWidget {
  const _CelebrationDialog({
    required this.icon,
    required this.tone,
    required this.title,
    required this.message,
    required this.actions,
  });

  final IconData icon;
  final BadgeTone tone;
  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: IconBadge(icon: icon, tone: tone, size: 72),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: actions,
    );
  }
}
