import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_info.dart';
import 'core/router.dart';

final _theme = ThemeData(colorSchemeSeed: const Color(0xFF1B5E20), useMaterial3: true);

class KampusBetApp extends ConsumerWidget {
  const KampusBetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AppInfo.name,
      theme: _theme,
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Yapılandırma eksik ya da yanlışsa uygulama yerine bu gösterilir.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, required this.problem});

  final String problem;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppInfo.name,
      theme: _theme,
      home: Scaffold(
        body: Center(
          child: Padding(padding: const EdgeInsets.all(32), child: Text(problem, textAlign: TextAlign.center)),
        ),
      ),
    );
  }
}
