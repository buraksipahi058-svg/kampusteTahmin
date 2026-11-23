import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../profile/profile_data.dart';
import 'brand_logo.dart';
import 'error_messages.dart';
import 'supabase.dart';

/// Oturum açıkken profil sorgusu sürerken (ya da hata verdiyse) gösterilir.
class LoadingScreen extends ConsumerWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandLogo(width: 180),
              const SizedBox(height: 24),
              if (profile.hasError && !profile.isLoading) ...[
                Text(userMessage(profile.error!), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => ref.invalidate(myProfileProvider), child: const Text('Tekrar dene')),
                TextButton(onPressed: () => ref.read(supabaseProvider).auth.signOut(), child: const Text('Çıkış yap')),
              ] else
                const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
