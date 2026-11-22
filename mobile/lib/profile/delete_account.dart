import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/error_messages.dart';
import '../core/supabase.dart';

/// `public.delete_my_account`: profil anonimleşir, giriş bilgileri silinir (KVKK). Sonra cihazdaki oturum kapanır;
/// sunucudaki oturumlar zaten silindiği için çıkış yalnızca yerel yapılır.
Future<void> deleteMyAccount(WidgetRef ref) async {
  final client = containerOf(ref).read(supabaseProvider);
  await client.rpc('delete_my_account');
  await client.auth.signOut(scope: SignOutScope.local);
}

/// Onay penceresi: sonuçlar anlatılır, kutu işaretlenmeden silme düğmesi açılmaz.
Future<void> confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(context: context, builder: (_) => const DeleteAccountDialog());
  if (ok != true || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await deleteMyAccount(ref);
    messenger.showSnackBar(const SnackBar(content: Text('Hesabın silindi.')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(userMessage(e))));
  }
}

class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key});

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  bool _understood = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Hesabını sil'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Adın, bölümün, okul mailin, giriş e-postan, şifren ve oturumların silinir; profilin okul '
              'arkadaşlarına "Silinmiş Kullanıcı" olarak görünür.\n\n'
              'SP, SSP, XP ve market ürünlerin geri gelmez. Puan ve bahis kayıtları kimliğinle bağı koparılarak '
              'saklanır.\n\n'
              'Sonuçlanmamış bahsin, düellon ya da hakemliğin varken silinemez. Bu işlem geri alınamaz.',
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _understood,
              onChanged: (v) => setState(() => _understood = v ?? false),
              title: const Text('Anladım, hesabım silinsin'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Vazgeç')),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed: _understood ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Hesabı sil'),
        ),
      ],
    );
  }
}
