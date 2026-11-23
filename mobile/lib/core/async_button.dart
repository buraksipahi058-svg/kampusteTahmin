import 'package:flutter/material.dart';

enum AsyncButtonKind { filled, tonal, outlined, text }

/// Çift dokunma korumalı düğme: işlem sürerken kapalıdır (soluk görünür).
/// İkinci dokunuş sunucuya ikinci istek göndermez (ödül al, kuşan, kabul et...).
class AsyncButton extends StatefulWidget {
  const AsyncButton({super.key, required this.onPressed, required this.child, this.kind = AsyncButtonKind.filled});

  final Future<void> Function()? onPressed;
  final Widget child;
  final AsyncButtonKind kind;

  @override
  State<AsyncButton> createState() => _AsyncButtonState();
}

class _AsyncButtonState extends State<AsyncButton> {
  var _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      await widget.onPressed!();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onPressed = widget.onPressed == null || _busy ? null : _run;
    final child = widget.child;
    return switch (widget.kind) {
      AsyncButtonKind.filled => FilledButton(onPressed: onPressed, child: child),
      AsyncButtonKind.tonal => FilledButton.tonal(onPressed: onPressed, child: child),
      AsyncButtonKind.outlined => OutlinedButton(onPressed: onPressed, child: child),
      AsyncButtonKind.text => TextButton(onPressed: onPressed, child: child),
    };
  }
}
