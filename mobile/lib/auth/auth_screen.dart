import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_info.dart';
import '../core/error_messages.dart';
import '../core/routes.dart';
import '../core/supabase.dart';

enum _Mode { signIn, signUp }

/// E-posta + şifre ile giriş ve kayıt. Supabase'de mail onayı açık: kayıttan sonra kullanıcı
/// mailindeki linke tıklar, sonra giriş yapar. Başarılı girişten sonrasını yönlendirici yapar.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordAgain = TextEditingController();

  var _mode = _Mode.signIn;
  var _busy = false;
  String? _error;

  /// Onay maili beklenen adres (kayıttan sonra ya da onaysız girişte); yeniden gönderme için.
  String? _awaitingConfirmation;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordAgain.dispose();
    super.dispose();
  }

  String get _emailValue => _email.text.trim().toLowerCase();

  Future<void> _run(Future<void> Function(GoTrueClient auth) action) async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await action(ref.read(supabaseProvider).auth);
    } on AuthException catch (e) {
      if (e.code == 'email_not_confirmed') _awaitingConfirmation = _emailValue;
      _error = userMessage(e);
    } catch (e) {
      _error = userMessage(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailValue;
    final password = _password.text;
    if (_mode == _Mode.signIn) {
      await _run((auth) => auth.signInWithPassword(email: email, password: password));
      return;
    }
    await _run((auth) async {
      final response = await auth.signUp(email: email, password: password, emailRedirectTo: AppInfo.authRedirectUrl);
      // Mail onayı açıkken oturum gelmez; açık oturum geldiyse yönlendirici devralır.
      if (response.session == null) {
        _awaitingConfirmation = email;
        _notice = '$email adresine bir onay linki gönderdik. Linke tıkladıktan sonra buradan giriş yap.';
        _mode = _Mode.signIn;
        _password.clear();
        _passwordAgain.clear();
      }
    });
  }

  Future<void> _resend() async {
    final email = _awaitingConfirmation;
    if (email == null) return;
    await _run((auth) async {
      await auth.resend(type: OtpType.signup, email: email, emailRedirectTo: AppInfo.authRedirectUrl);
      _notice = 'Onay linkini $email adresine yeniden gönderdik.';
    });
  }

  /// Şifre sıfırlama linki telefonda açılınca uygulamada oturum açılır; yeni şifre Profil'den belirlenir.
  Future<void> _forgotPassword() async {
    final email = _emailValue;
    if (!email.contains('@') || email.startsWith('@') || email.endsWith('@')) {
      setState(() {
        _notice = null;
        _error = 'Şifre sıfırlama linki için önce e-posta adresini yaz.';
      });
      return;
    }
    await _run((auth) async {
      await auth.resetPasswordForEmail(email, redirectTo: AppInfo.authRedirectUrl);
      _notice =
          '$email adresine bir şifre sıfırlama linki gönderdik. Linki bu telefonda aç: uygulamada oturumun açılır, '
          'sonra Profil > Şifreyi değiştir\'den yeni şifreni belirle.';
    });
  }

  void _switchMode(_Mode mode) => setState(() {
    _mode = mode;
    _error = null;
    _notice = null;
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final signUp = _mode == _Mode.signUp;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(AppInfo.name, textAlign: TextAlign.center, style: theme.textTheme.headlineLarge),
                    const SizedBox(height: 8),
                    Text(
                      'Kampüsünde tahmin yap, sanal puan kazan.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 32),
                    SegmentedButton<_Mode>(
                      segments: const [
                        ButtonSegment(value: _Mode.signIn, label: Text('Giriş yap')),
                        ButtonSegment(value: _Mode.signUp, label: Text('Kayıt ol')),
                      ],
                      selected: {_mode},
                      onSelectionChanged: _busy ? null : (s) => _switchMode(s.first),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _email,
                      decoration: const InputDecoration(labelText: 'E-posta', border: OutlineInputBorder()),
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        final value = (v ?? '').trim();
                        return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)
                            ? null
                            : 'Geçerli bir e-posta adresi yaz.';
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      decoration: const InputDecoration(labelText: 'Şifre', border: OutlineInputBorder()),
                      obscureText: true,
                      autofillHints: [signUp ? AutofillHints.newPassword : AutofillHints.password],
                      textInputAction: signUp ? TextInputAction.next : TextInputAction.done,
                      onFieldSubmitted: signUp ? null : (_) => _submit(),
                      validator: (v) {
                        final value = v ?? '';
                        if (value.isEmpty) return 'Şifreni yaz.';
                        if (signUp && value.length < 8) return 'Şifre en az 8 karakter olmalı.';
                        return null;
                      },
                    ),
                    if (signUp) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordAgain,
                        decoration: const InputDecoration(
                          labelText: 'Şifre (tekrar)',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        validator: (v) => v == _password.text ? null : 'Şifreler aynı değil.',
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (_error != null) _Message(text: _error!, isError: true),
                    if (_notice != null) _Message(text: _notice!, isError: false),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(signUp ? 'Kayıt ol' : 'Giriş yap'),
                    ),
                    if (signUp)
                      TextButton(
                        onPressed: () => context.push(Routes.privacy),
                        child: const Text('Kişisel verilerin nasıl işlenir: KVKK Aydınlatma Metni', textAlign: TextAlign.center),
                      ),
                    if (!signUp)
                      TextButton(
                        onPressed: _busy ? null : _forgotPassword,
                        child: const Text('Şifremi unuttum'),
                      ),
                    if (_awaitingConfirmation != null && !signUp)
                      TextButton(
                        onPressed: _busy ? null : _resend,
                        child: const Text('Onay mailini yeniden gönder'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? colors.errorContainer : colors.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(color: isError ? colors.onErrorContainer : colors.onSecondaryContainer),
      ),
    );
  }
}
