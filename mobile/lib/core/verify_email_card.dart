import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'routes.dart';

/// Okul maili doğrulanmamış kişiye: okulun bahisleri, düelloları, sıralaması ve kişileri yalnızca okul maili
/// doğrulanınca görünür (sunucu kuralı). Dokununca doğrulama ekranı açılır.
class VerifyEmailCard extends StatelessWidget {
  const VerifyEmailCard(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Symbols.mark_email_unread_rounded),
      title: Text(text),
      trailing: const Icon(Symbols.chevron_right_rounded),
      onTap: () => context.push(Routes.verifyEmail),
    ),
  );
}
