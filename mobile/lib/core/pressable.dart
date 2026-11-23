import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Dokunulabilir özel yüzey (kart, oyun kartı): parmak değdiği an %97'ye küçülür (120 ms, ease-out), bırakınca
/// ya da parmak dışarı kayınca geri döner. Material düğmelerinde dalga (ripple) yeter; bu yalnızca özel yüzeyler için.
/// "Animasyonları azalt" açıksa küçülmez.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, required this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  var _down = false;

  void _set(bool down) {
    if (_down != down && mounted) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final scale = _down && enabled && !Motion.reduced(context) ? Motion.pressedScale : 1.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(scale: scale, duration: Motion.press, curve: Motion.easeOut, child: widget.child),
    );
  }
}
