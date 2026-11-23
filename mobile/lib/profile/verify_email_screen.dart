import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/error_messages.dart';
import 'profile_data.dart';
import 'student_email_data.dart';

/// Okul maili doğrulama: önce mail adresi (kod istenir), sonra maile gelen 6 haneli kod.
/// Sınırları (alan adı, süre, deneme, istek sıklığı) sunucu denetler; burada yalnızca biçim kontrolü var.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _emailForm = GlobalKey<FormState>();
  final _codeForm = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();

  /// Kod gönderildiyse adres; null ise mail adımındayız.
  String? _sentTo;
  var _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = userMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() async {
    if (_sentTo == null && !_emailForm.currentState!.validate()) return;
    await _run(() async {
      final sentTo = await requestStudentEmailCode(ref, _sentTo ?? _email.text);
      if (!mounted) return;
      setState(() {
        _sentTo = sentTo;
        _code.clear();
        _info = 'Kodu $sentTo adresine gönderdik. 10 dakika geçerli.';
      });
    });
  }

  Future<void> _confirm() async {
    if (!_codeForm.currentState!.validate()) return;
    await _run(() async {
      final result = await confirmStudentEmail(ref, _code.text.trim());
      if (!mounted) return;
      if (result.verified) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Okul mailin doğrulandı.')));
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _error = result.attemptsLeft > 0
            ? 'Kod yanlış. ${result.attemptsLeft} deneme hakkın kaldı.'
            : 'Kod yanlış ve deneme hakkın bitti. Yeni kod iste.';
      });
    });
  }

  String? _validateEmail(String? v) {
    final value = (v ?? '').trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) return 'Geçerli bir mail adresi yaz.';
    return null;
  }

  String? _validateCode(String? v) => RegExp(r'^[0-9]{6}$').hasMatch((v ?? '').trim()) ? null : 'Kod 6 haneli olmalı.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final domains = ref.watch(myProfileProvider).value?.profile?.schoolEmailDomains ?? const <String>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Okul maili doğrulama')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Bahis açmak ve bahse katılmak için okul mailini doğrulaman gerekiyor. '
                'Mailine 6 haneli bir kod göndereceğiz.',
                style: theme.textTheme.bodyMedium,
              ),
              if (domains.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Okul mailin şununla bitmeli: ${domains.map((d) => '@$d').join(' ya da ')}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 24),
              if (_sentTo == null)
                Form(
                  key: _emailForm,
                  child: TextFormField(
                    controller: _email,
                    enabled: !_busy,
                    decoration: const InputDecoration(labelText: 'Okul mailin', border: OutlineInputBorder()),
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.send,
                    onFieldSubmitted: (_) => _sendCode(),
                    validator: _validateEmail,
                  ),
                )
              else
                Form(
                  key: _codeForm,
                  child: TextFormField(
                    controller: _code,
                    enabled: !_busy,
                    decoration: const InputDecoration(labelText: 'Doğrulama kodu', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _confirm(),
                    validator: _validateCode,
                  ),
                ),
              const SizedBox(height: 16),
              if (_info != null) Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(_info!)),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                ),
              FilledButton(
                onPressed: _busy ? null : (_sentTo == null ? _sendCode : _confirm),
                child: _busy
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_sentTo == null ? 'Kod gönder' : 'Doğrula'),
              ),
              if (_sentTo != null) ...[
                const SizedBox(height: 8),
                TextButton(onPressed: _busy ? null : _sendCode, child: const Text('Kodu tekrar gönder')),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _sentTo = null;
                          _error = null;
                          _info = null;
                        }),
                  child: const Text('Mail adresini değiştir'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
