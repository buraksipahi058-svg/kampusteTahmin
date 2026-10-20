import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final problem = Env.problem;
  if (problem != null) {
    runApp(ConfigErrorApp(problem: problem));
    return;
  }

  await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabasePublishableKey);
  // Riverpod'un kendiliğinden yeniden deneme özelliği kapalı: hata kullanıcıya gösterilir,
  // yeniden deneme kullanıcının elinde (aynı RPC'nin habersiz tekrarlanmaması için).
  runApp(ProviderScope(retry: (_, _) => null, child: const KampusBetApp()));
}
