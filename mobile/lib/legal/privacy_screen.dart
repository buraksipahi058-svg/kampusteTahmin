import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// KVKK aydınlatma metni tek yerde: `assets/legal/kvkk_aydinlatma.txt` (docs/ bu dosyayı gösterir).
const privacyNoticeAsset = 'assets/legal/kvkk_aydinlatma.txt';

final privacyNoticeProvider = FutureProvider<String>((ref) => rootBundle.loadString(privacyNoticeAsset));

/// `/kvkk`: girişten önce de açılır (kayıt ekranındaki bağlantı).
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gizlilik ve KVKK')),
      body: switch (ref.watch(privacyNoticeProvider)) {
        AsyncData(:final value) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: privacyNoticeBlocks(value, Theme.of(context)),
        ),
        AsyncError() => const Center(child: Text('Metin açılamadı.')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// Basit biçim: "# " başlık, "## " ara başlık, "- " madde; boş satır paragrafları ayırır.
List<Widget> privacyNoticeBlocks(String text, ThemeData theme) {
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
