import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Yasal metinler tek yerde: `assets/legal/*.txt` (admin'in herkese açık sayfalarında aynı kopyalar; test denetler).
enum LegalDocument {
  privacy('Gizlilik ve KVKK', 'assets/legal/kvkk_aydinlatma.txt'),
  terms('Kullanım koşulları', 'assets/legal/kullanim_kosullari.txt');

  const LegalDocument(this.title, this.asset);

  final String title;
  final String asset;
}

final legalTextProvider = FutureProvider.family<String, LegalDocument>((ref, doc) => rootBundle.loadString(doc.asset));

/// `/kvkk` ve `/kosullar`: girişten önce de açılır (kayıt ekranındaki bağlantılar).
class LegalScreen extends ConsumerWidget {
  const LegalScreen(this.document, {super.key});

  final LegalDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(document.title)),
      body: switch (ref.watch(legalTextProvider(document))) {
        AsyncData(:final value) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: legalTextBlocks(value, Theme.of(context)),
        ),
        AsyncError() => const Center(child: Text('Metin açılamadı.')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// Basit biçim: "# " başlık, "## " ara başlık, "- " madde; boş satır paragrafları ayırır.
List<Widget> legalTextBlocks(String text, ThemeData theme) {
  final blocks = <Widget>[];
  for (final raw in text.split('\n')) {
    final line = raw.trimRight();
    if (line.isEmpty) continue;
    if (line.startsWith('# ')) {
      blocks.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(line.substring(2), style: theme.textTheme.headlineSmall),
        ),
      );
    } else if (line.startsWith('## ')) {
      blocks.add(
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: Text(line.substring(3), style: theme.textTheme.titleMedium),
        ),
      );
    } else if (line.startsWith('- ')) {
      blocks.add(
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  '),
              Expanded(child: Text(line.substring(2))),
            ],
          ),
        ),
      );
    } else {
      blocks.add(Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(line)));
    }
  }
  return blocks;
}
