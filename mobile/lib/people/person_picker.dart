import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/error_messages.dart';
import '../market/cosmetic_preview.dart';
import 'people_data.dart';

/// Okul arkadaşı seçme penceresi (ad ya da soyadla arama). Seçilen kişiyi, vazgeçilirse null döner.
/// [forReferee]: ihtar sınırındaki kişiler seçilemez.
Future<Person?> pickPerson(BuildContext context, {required String title, bool forReferee = false}) {
  return showModalBottomSheet<Person>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    builder: (_) => _PersonPickerSheet(title: title, forReferee: forReferee),
  );
}

class _PersonPickerSheet extends ConsumerStatefulWidget {
  const _PersonPickerSheet({required this.title, required this.forReferee});

  final String title;
  final bool forReferee;

  @override
  ConsumerState<_PersonPickerSheet> createState() => _PersonPickerSheetState();
}

class _PersonPickerSheetState extends ConsumerState<_PersonPickerSheet> {
  final _search = TextEditingController();
  Timer? _debounce;
  var _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = _query.length < 2 ? null : ref.watch(schoolmateSearchProvider(_query));
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('Okulunun okul maili doğrulanmış öğrencileri.', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _search,
                    autofocus: true,
                    onChanged: _onChanged,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      labelText: 'Ad ya da soyad',
                      prefixIcon: Icon(Symbols.search_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: switch (results) {
                null => const Center(child: Text('Aramak için en az 2 harf yaz.')),
                AsyncData(value: final list) when list.isEmpty => const Center(child: Text('Kimse bulunamadı.')),
                AsyncData(value: final list) => ListView(
                  children: [
                    for (final p in list)
                      ListTile(
                        enabled: !widget.forReferee || p.canReferee,
                        leading: ProfileAvatar(initials: p.initials, radius: 18),
                        title: Text(p.fullName),
                        subtitle: Text(
                          [
                            ?p.department,
                            'Sv. ${p.level}',
                            if (widget.forReferee && !p.canReferee) 'ihtar sınırında, hakem olamaz',
                          ].join(' · '),
                        ),
                        onTap: () => Navigator.pop(context, p),
                      ),
                  ],
                ),
                AsyncError(:final error) => Center(child: Text('Arama yapılamadı. ${userMessage(error)}')),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ],
        ),
      ),
    );
  }
}
