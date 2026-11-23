import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/error_messages.dart';
import '../people/people_data.dart';
import '../people/person_picker.dart';
import '../profile/profile_data.dart';
import 'bets_data.dart';
import 'bets_tab.dart';

/// Okul geneli sosyal bahis açma. Hakem varsayılan olarak açan kişidir, okulundan doğrulanmış biri seçilebilir;
/// kişi başı sınır sunucudaki üst sınırı (100 SP) aşamaz.
class CreateSocialBetScreen extends ConsumerStatefulWidget {
  const CreateSocialBetScreen({super.key});

  @override
  ConsumerState<CreateSocialBetScreen> createState() => _CreateSocialBetScreenState();
}

class _CreateSocialBetScreenState extends ConsumerState<CreateSocialBetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _maxStake = TextEditingController(text: '100');
  final _options = [TextEditingController(text: 'Evet'), TextEditingController(text: 'Hayır')];
  DateTime? _locksAt;

  /// Seçilen hakem; null ise açan kişi.
  Person? _referee;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_title, _description, _maxStake, ..._options]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLocksAt() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      initialDate: _locksAt ?? now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null) return;
    setState(() => _locksAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _pickReferee() async {
    final person = await pickPerson(context, title: 'Hakemi seç', forReferee: true);
    if (person != null && mounted) setState(() => _referee = person);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final locksAt = _locksAt;
    if (locksAt == null || !locksAt.isAfter(DateTime.now())) {
      setState(() => _error = 'İleride bir kapanış zamanı seç.');
      return;
    }
    final schoolId = ref.read(myProfileProvider).value?.profile?.schoolId;
    if (schoolId == null || schoolId.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await createSocialBet(
        ref,
        clusterId: schoolId,
        title: _title.text.trim(),
        description: _description.text.trim(),
        options: [for (final c in _options) c.text.trim()],
        locksAt: locksAt,
        maxStake: int.tryParse(_maxStake.text.trim()),
        refereeId: _referee?.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sosyal bahis açıldı.')));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = userMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _required(String? v, String label, int max) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return '$label boş olamaz.';
    if (value.runes.length > max) return '$label en fazla $max karakter olabilir.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Sosyal bahis aç')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Okulundaki herkes görür ve SP ile katılır. Hakem kapanıştan sonra sonucu girer, katılanlar itiraz '
                'ederse moderatör karar verir. Hakem varsayılan olarak sensin; başka birini seçersen o yatıramaz.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Soru', border: OutlineInputBorder()),
                validator: (v) {
                  final error = _required(v, 'Soru', 140);
                  if (error != null) return error;
                  return v!.trim().runes.length < 3 ? 'Soru en az 3 karakter olmalı.' : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Açıklama (isteğe bağlı)', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < _options.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _options[i],
                          decoration: InputDecoration(
                            labelText: 'Seçenek ${i + 1}',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => _required(v, 'Seçenek', 100),
                        ),
                      ),
                      if (_options.length > 2)
                        IconButton(
                          onPressed: () => setState(() => _options.removeAt(i).dispose()),
                          icon: const Icon(Symbols.remove_circle_rounded),
                        ),
                    ],
                  ),
                ),
              if (_options.length < 4)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _options.add(TextEditingController())),
                    icon: const Icon(Symbols.add_rounded),
                    label: const Text('Seçenek ekle'),
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickLocksAt,
                icon: const Icon(Symbols.schedule_rounded),
                label: Text(_locksAt == null ? 'Kapanış zamanı seç' : 'Kapanış: ${formatIstanbul(_locksAt!)}'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _pickReferee,
                      icon: const Icon(Symbols.gavel_rounded),
                      label: Text('Hakem: ${_referee?.fullName ?? 'ben'}'),
                    ),
                  ),
                  if (_referee != null)
                    IconButton(
                      tooltip: 'Hakem ben olayım',
                      onPressed: _busy ? null : () => setState(() => _referee = null),
                      icon: const Icon(Symbols.close_rounded),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _maxStake,
                decoration: const InputDecoration(
                  labelText: 'Kişi başı en fazla SP',
                  helperText: 'En fazla 100',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  return n == null || n < 1 || n > 100 ? '1 ile 100 arasında bir sayı gir.' : null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Bahsi aç'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
