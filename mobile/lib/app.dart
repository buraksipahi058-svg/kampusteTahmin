import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_info.dart';
import 'core/app_theme.dart';
import 'core/router.dart';

// Fütüristik görünüm koyu temada: uygulama telefonun ayarından bağımsız koyu açılır (açık tema tanımlı kalır).
final _theme = buildAppTheme(Brightness.light);
final _darkTheme = buildAppTheme(Brightness.dark);

class KampusBetApp extends ConsumerWidget {
  const KampusBetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AppInfo.name,
      theme: _theme,
      darkTheme: _darkTheme,
      themeMode: ThemeMode.dark,
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
      darkTheme: _darkTheme,
      themeMode: ThemeMode.dark,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(problem, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
