import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/error_messages.dart';
import '../core/state_views.dart';
import '../core/supabase.dart';
import 'profile_data.dart';

/// Girişten sonra profili olmayan kullanıcıya bir kez gösterilir (`public.create_profile`).
/// Profil oluşunca yönlendirici sekmelere geçirir.
class CreateProfileScreen extends ConsumerStatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  ConsumerState<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends ConsumerState<CreateProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _department = TextEditingController();
  String? _schoolId;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _department.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final department = _department.text.trim();
      await createProfile(
        ref,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        schoolId: _schoolId!,
        department: department.isEmpty ? null : department,
      );
    } catch (e) {
      if (mounted) setState(() => _error = userMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Sunucudaki kısıtın aynısı: 1-50 karakter (bölüm 1-100), kontrol karakteri yok.
  static String? Function(String?) _text(String label, {int max = 50, bool required = true}) {
    return (v) {
      final value = (v ?? '').trim();
      if (value.isEmpty) return required ? '$label boş olamaz.' : null;
      if (value.runes.length > max) return '$label en fazla $max karakter olabilir.';
      if (RegExp(r'[\x00-\x1F\x7F]').hasMatch(value)) return '$label geçersiz karakter içeriyor.';
      return null;
    };
  }

  @override
  Widget build(BuildContext context) {
    final schools = ref.watch(schoolsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilini oluştur'),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => ref.read(supabaseProvider).auth.signOut(),
            child: const Text('Çıkış yap'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Seni kampüste tanısınlar diye birkaç bilgi. Okulunu sonradan değiştiremezsin.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _firstName,
                  decoration: const InputDecoration(labelText: 'Ad', border: OutlineInputBorder()),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: _text('Ad'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _lastName,
                  decoration: const InputDecoration(labelText: 'Soyad', border: OutlineInputBorder()),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: _text('Soyad'),
                ),
                const SizedBox(height: 16),
                switch (schools) {
                  AsyncData(:final value) => DropdownButtonFormField<String>(
                    initialValue: _schoolId,
                    decoration: const InputDecoration(labelText: 'Okul', border: OutlineInputBorder()),
                    isExpanded: true,
                    items: [for (final s in value) DropdownMenuItem(value: s.id, child: Text(s.name))],
                    onChanged: _busy ? null : (id) => setState(() => _schoolId = id),
                    validator: (id) => id == null ? 'Okulunu seç.' : null,
                  ),
                  AsyncError(:final error) => ErrorView(
                    what: 'Okul listesi alınamadı.',
                    error: error,
                    onRetry: () => ref.invalidate(schoolsProvider),
                  ),
                  _ => const Center(child: CircularProgressIndicator()),
                },
                const SizedBox(height: 16),
                TextFormField(
                  controller: _department,
                  decoration: const InputDecoration(labelText: 'Bölüm (isteğe bağlı)', border: OutlineInputBorder()),
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  validator: _text('Bölüm', max: 100, required: false),
                ),
                const SizedBox(height: 24),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                  ),
                FilledButton(
                  onPressed: _busy || !schools.hasValue ? null : _submit,
                  child: _busy
                      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Profili oluştur'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
