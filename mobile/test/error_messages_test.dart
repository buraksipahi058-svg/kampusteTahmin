import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:kampusbet/core/error_messages.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException db(String code) => PostgrestException(message: 'sunucu metni', code: code);

void main() {
  test('uygulama hata kodları kullanıcı diline çevrilir', () {
    expect(userMessage(db('KB001')), 'Bakiyen yetersiz.');
    expect(userMessage(db('KB002')), contains('okul mailini doğrula'));
    expect(userMessage(db('KB004')), 'Bu bahse zaten yatırım yaptın.');
  });

  test('bilinmeyen kod sunucu metnini değil genel mesajı gösterir', () {
    expect(userMessage(db('XX999')), genericError);
    expect(userMessage(StateError('beklenmedik')), genericError);
  });

  test('Auth hataları koda göre çevrilir', () {
    expect(
      userMessage(const AuthApiException('Invalid login credentials', code: 'invalid_credentials')),
      'E-posta ya da şifre hatalı.',
    );
    expect(userMessage(const AuthException('?', code: 'email_not_confirmed')), contains('onay linkine'));
    expect(userMessage(const AuthException('?', code: 'bilinmeyen')), genericError);
  });

  test('bağlantı hataları ağ mesajını gösterir', () {
    expect(userMessage(AuthRetryableFetchException(message: 'Failed host lookup')), networkError);
    expect(userMessage(ClientException('Connection refused')), networkError);
  });

  test('veritabani.md hata tablosundaki her kodun mesajı var', () {
    final doc = File('../docs/harita/veritabani.md').readAsStringSync();
    final section = doc.split('## Hata kodları').last.split('\n## ').first;
    final codes = RegExp(r'^\| `([A-Z0-9]{5})` \|', multiLine: true)
        .allMatches(section)
        .map((m) => m.group(1)!)
        .toList();

    expect(codes, containsAll(['KB001', 'KB002', 'KB003', 'KB004', 'KB005', 'KB006']));
    for (final code in codes) {
      expect(databaseMessages, contains(code), reason: '$code için mesaj yok (lib/core/error_messages.dart)');
    }
  });
}
