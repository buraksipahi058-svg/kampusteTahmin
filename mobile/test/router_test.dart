import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kampusbet/core/router.dart';
import 'package:kampusbet/core/routes.dart';
import 'package:kampusbet/profile/profile_data.dart';

const _profile = Profile(id: 'u1', firstName: 'Ada', lastName: 'Yılmaz', schoolName: 'Örnek Üniversitesi');

AsyncValue<ProfileStatus> found(String userId) =>
    AsyncData(ProfileStatus(userId: userId, profile: _profile));
AsyncValue<ProfileStatus> missing(String userId) =>
    AsyncData(ProfileStatus(userId: userId, profile: null));

void main() {
  test('oturum yoksa her yer girişe gider', () {
    final none = missing('u1');
    expect(redirectFor(location: Routes.bets, userId: null, profile: none), Routes.auth);
    expect(redirectFor(location: Routes.createProfile, userId: null, profile: none), Routes.auth);
    expect(redirectFor(location: Routes.auth, userId: null, profile: none), isNull);
  });

  test('KVKK metni ve kullanım koşulları her durumda açılır', () {
    for (final location in [Routes.privacy, Routes.terms]) {
      expect(redirectFor(location: location, userId: null, profile: missing('u1')), isNull);
      expect(redirectFor(location: location, userId: 'u1', profile: const AsyncLoading()), isNull);
      expect(redirectFor(location: location, userId: 'u1', profile: missing('u1')), isNull);
      expect(redirectFor(location: location, userId: 'u1', profile: found('u1')), isNull);
    }
  });

  test('profil sorgusu sürerken yükleniyor ekranı', () {
    expect(redirectFor(location: Routes.auth, userId: 'u1', profile: const AsyncLoading()), Routes.loading);
    expect(redirectFor(location: Routes.loading, userId: 'u1', profile: const AsyncLoading()), isNull);
    expect(
      redirectFor(location: Routes.auth, userId: 'u1', profile: AsyncError(Exception(), StackTrace.empty)),
      Routes.loading,
    );
  });

  test('önceki kullanıcının sonucu yeni kullanıcı için kullanılmaz', () {
    expect(redirectFor(location: Routes.auth, userId: 'u2', profile: found('u1')), Routes.loading);
    expect(redirectFor(location: Routes.auth, userId: 'u2', profile: missing('u1')), Routes.loading);
  });

  test('profili yoksa profil oluşturmaya, varsa sekmelere', () {
    expect(redirectFor(location: Routes.loading, userId: 'u1', profile: missing('u1')), Routes.createProfile);
    expect(redirectFor(location: Routes.bets, userId: 'u1', profile: missing('u1')), Routes.createProfile);
    expect(redirectFor(location: Routes.createProfile, userId: 'u1', profile: missing('u1')), isNull);

    expect(redirectFor(location: Routes.createProfile, userId: 'u1', profile: found('u1')), Routes.bets);
    expect(redirectFor(location: Routes.auth, userId: 'u1', profile: found('u1')), Routes.bets);
    expect(redirectFor(location: Routes.market, userId: 'u1', profile: found('u1')), isNull);
  });

  test('okul maili doğrulama sayfası yalnızca profili olana açık', () {
    expect(redirectFor(location: Routes.verifyEmail, userId: 'u1', profile: found('u1')), isNull);
    expect(redirectFor(location: Routes.verifyEmail, userId: 'u1', profile: missing('u1')), Routes.createProfile);
    expect(redirectFor(location: Routes.verifyEmail, userId: null, profile: missing('u1')), Routes.auth);
  });
}
