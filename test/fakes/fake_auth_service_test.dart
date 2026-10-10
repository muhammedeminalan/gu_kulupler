// T-10 · FakeAuthService sözleşmesi (PLAN §16.3).
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';

import 'fake_auth_service.dart';
import 'register_fakes.dart';

const String _email = 'ayse@ogr.gumushane.edu.tr';
const String _password = 'Parola123';

Matcher _failsWith(AuthError error) =>
    isA<FirebaseFailure<Object?, AuthError>>().having(
      (r) => r.error,
      'error',
      error,
    );

void main() {
  group('T-10 · FakeAuthService', () {
    test('AuthService arayüzünü uygular; registerDefaultFakes kaydeder', () {
      addTearDown(GetIt.I.reset);
      registerDefaultFakes();
      expect(GetIt.I<AuthService>(), isA<FakeAuthService>());
    });

    test('authStateChanges: önce güncel durum, sonra '
        'signIn / signOut / authStateController olayları', () async {
      final fake = FakeAuthService()..uid = 'u1';
      final events = <AuthUserInfo?>[];
      final subscription = fake.authStateChanges().listen(events.add);
      addTearDown(subscription.cancel);

      await fake.signIn(email: _email, password: _password);
      await fake.signOut();
      const outside = AuthUserInfo(uid: 'u2', email: null, emailVerified: true);
      fake.authStateController.add(outside);
      await Future<void>.delayed(Duration.zero);

      const signedIn = AuthUserInfo(
        uid: 'u1',
        email: _email,
        emailVerified: false,
      );
      expect(events, [null, signedIn, null, outside]);
      expect(fake.currentUser, isNull);
    });

    test('register doğrulanmamış açar; emailVerified reload ile '
        'currentUser alanına yansır', () async {
      final fake = FakeAuthService()..emailVerified = true;

      final registered = await fake.register(
        email: _email,
        password: _password,
      );
      expect(
        registered,
        isA<FirebaseSuccess<AuthUserInfo, AuthError>>().having(
          (r) => r.data.emailVerified,
          'emailVerified',
          isFalse,
        ),
      );
      expect(fake.currentUser?.emailVerified, isFalse);

      await fake.reload();
      expect(fake.currentUser?.emailVerified, isTrue);

      await fake.signOut();
      await fake.signIn(email: _email, password: _password);
      expect(fake.currentUser?.emailVerified, isTrue);
    });

    test(
      'oturum gerektiren çağrılar oturum yokken sessionExpired döner',
      () async {
        final fake = FakeAuthService();

        expect(
          await fake.sendEmailVerification(),
          _failsWith(AuthError.sessionExpired),
        );
        expect(await fake.reload(), _failsWith(AuthError.sessionExpired));
        expect(
          await fake.reauthenticate(password: _password),
          _failsWith(AuthError.sessionExpired),
        );
        expect(
          await fake.updatePassword(newPassword: _password),
          _failsWith(AuthError.sessionExpired),
        );
        expect(
          await fake.idTokenClaims(),
          _failsWith(AuthError.sessionExpired),
        );
        // Oturum gerektirmeyen çağrı etkilenmez.
        expect(
          await fake.sendPasswordReset(email: _email),
          isA<FirebaseSuccess<void, AuthError>>(),
        );
      },
    );

    test('failNext tek seferlik: hata döner, oturum açılmaz', () async {
      final fake = FakeAuthService()..failNext(AuthError.invalidCredentials);

      expect(
        await fake.signIn(email: _email, password: _password),
        _failsWith(AuthError.invalidCredentials),
      );
      expect(fake.currentUser, isNull);

      fake.failNext();
      expect(
        await fake.register(email: _email, password: _password),
        _failsWith(AuthError.unknown),
      );
      expect(
        await fake.signIn(email: _email, password: _password),
        isA<FirebaseSuccess<AuthUserInfo, AuthError>>(),
      );
      expect(fake.callsTo('signIn'), hasLength(2));
    });

    test('idTokenClaims claims kopyasını döner; tokenErrors denetleyiciden '
        'yayınlanır', () async {
      final fake = FakeAuthService()..claims = {'superadmin': true};
      await fake.signIn(email: _email, password: _password);
      final errors = <AuthError>[];
      final subscription = fake.tokenErrors.listen(errors.add);
      addTearDown(subscription.cancel);

      final result = await fake.idTokenClaims(forceRefresh: true);
      fake.tokenErrorController.add(AuthError.userDisabled);
      await Future<void>.delayed(Duration.zero);

      expect(
        result,
        isA<FirebaseSuccess<Map<String, Object?>, AuthError>>().having(
          (r) => r.data,
          'data',
          {'superadmin': true},
        ),
      );
      expect(fake.calls.last.args, [true]);
      expect(errors, [AuthError.userDisabled]);
    });
  });
}
