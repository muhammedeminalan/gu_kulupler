// T-12 · FakeAuthRepository sözleşmesi (PLAN §16.3): gerçek repository
// kurallarını (giriş kilidi, yeniden gönderme beklemesi, alan adı) izler ve
// test yüzeyini (`registered`, `signInAttempts`, `resetSent`,
// `watchAuthStateController`, `isSuperAdminResult`) açar.
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/fake_app_clock.dart';
import 'fake_auth_repository.dart';
import 'fake_auth_service.dart';
import 'register_fakes.dart';

const String _email = 'ayse@ogr.gumushane.edu.tr';
const String _password = 'Parola123';

void main() {
  late FakeAppClock clock;
  late FakeAuthRepository fake;

  setUp(() {
    clock = FakeAppClock(kDefaultFakeNowUtc);
    fake = FakeAuthRepository(clock);
  });

  group('T-12 · FakeAuthRepository', () {
    test('AuthRepository arayüzünü uygular; registerDefaultFakes kayıtlı '
        'FakeAuthService ile aynı oturumu görecek biçimde kaydeder', () {
      addTearDown(GetIt.I.reset);
      registerDefaultFakes();
      final registered = GetIt.I<AuthRepository>();
      expect(registered, isA<FakeAuthRepository>());
      expect(
        (registered as FakeAuthRepository).service,
        same(GetIt.I<AuthService>()),
      );
      expect(GetIt.I<AuthService>(), isA<FakeAuthService>());
    });

    test('watchAuthState: önce güncel durum, sonra giriş / çıkış / '
        'watchAuthStateController olayları', () async {
      fake.service
        ..uid = 'u1'
        ..emailVerified = true;
      final events = <AuthUserInfo?>[];
      final subscription = fake.watchAuthState().listen(events.add);
      addTearDown(subscription.cancel);

      await fake.signIn(email: _email, password: _password);
      await fake.signOut();
      const outside = AuthUserInfo(uid: 'u2', email: null, emailVerified: true);
      fake.watchAuthStateController.add(outside);
      await pumpEventQueue();

      const signedIn = AuthUserInfo(
        uid: 'u1',
        email: _email,
        emailVerified: true,
      );
      expect(events, [null, signedIn, null, outside]);
    });

    test('register: doğrulanmamış oturum açar, `registered`e yazar ve '
        'yeniden gönderme beklemesini başlatır (gerçek kural)', () async {
      final result = await fake.register(email: _email, password: _password);

      expect(result.dataOrNull?.emailVerified, isFalse);
      expect(fake.registered, [(email: _email, password: _password)]);
      expect(fake.currentUser, result.dataOrNull);
      expect(fake.resendCooldownRemaining, Limits.verificationResendCooldown);
      expect(
        (await fake.sendEmailVerification()).errorOrNull,
        AuthError.resendCooldown,
      );

      clock.advance(Limits.verificationResendCooldown);
      expect(fake.resendCooldownRemaining, isNull);
      expect((await fake.sendEmailVerification()).isSuccess, isTrue);
    });

    test('register: izinli olmayan alan adı reddedilir, `registered` '
        'değişmez', () async {
      final result = await fake.register(
        email: 'ayse@gmail.com',
        password: _password,
      );
      expect(result.errorOrNull, AuthError.domainNotAllowed);
      expect(fake.registered, isEmpty);
      expect(fake.currentUser, isNull);
    });

    test('signIn: beşinci hatalı deneme adresi kilitler; kilit dolunca '
        'açılır; her deneme `signInAttempts`e yazılır', () async {
      for (var i = 0; i < Limits.loginMaxFailedAttempts; i++) {
        // SDK cevabı olarak sayılan hata servis fake'ine kurulur.
        fake.service.failNext(AuthError.invalidCredentials);
        final attempt = await fake.signIn(email: _email, password: 'yanlış');
        expect(attempt.errorOrNull, AuthError.invalidCredentials);
      }
      expect(fake.loginLockRemaining(_email), Limits.loginLockout);

      final locked = await fake.signIn(email: _email, password: _password);
      expect(locked.errorOrNull, AuthError.lockedOut);
      expect(
        (locked as FirebaseFailure).detail,
        AuthFailureDetail(
          retryAfter: clock.nowUtc().add(Limits.loginLockout),
          remaining: Limits.loginLockout,
        ),
      );
      expect(fake.signInAttempts, hasLength(6));
      expect(fake.service.callsTo('signIn'), hasLength(5));

      clock.advance(Limits.loginLockout);
      expect(fake.loginLockRemaining(_email), isNull);
      expect(
        (await fake.signIn(email: _email, password: _password)).isSuccess,
        isTrue,
      );
    });

    test('reloadUser: doğrulanmadıysa emailNotVerified; doğrulandıysa '
        'güncel kullanıcı', () async {
      await fake.register(email: _email, password: _password);
      expect((await fake.reloadUser()).errorOrNull, AuthError.emailNotVerified);

      fake.service.emailVerified = true;
      final reloaded = await fake.reloadUser();
      expect(reloaded.dataOrNull?.emailVerified, isTrue);
      expect(fake.currentUser?.emailVerified, isTrue);
    });

    test('isSuperAdminResult claim’i belirler; oturum yoksa '
        'sessionExpired', () async {
      expect(
        (await fake.isSuperAdmin()).errorOrNull,
        AuthError.sessionExpired,
      );

      fake.currentUser = const AuthUserInfo(
        uid: 'u1',
        email: _email,
        emailVerified: true,
      );
      expect((await fake.isSuperAdmin()).dataOrNull, isFalse);
      fake.isSuperAdminResult = true;
      expect(fake.isSuperAdminResult, isTrue);
      expect((await fake.isSuperAdmin(forceRefresh: true)).dataOrNull, isTrue);
      expect(fake.callsTo('isSuperAdmin').map((call) => call.args), [
        [false],
        [false],
        [true],
      ]);
    });

    test('sendPasswordReset başarıda `resetSent`e yazar', () async {
      expect((await fake.sendPasswordReset(email: _email)).isSuccess, isTrue);
      expect(fake.resetSent, [_email]);
    });

    test('failNext: sıradaki çağrı servise gitmeden o hatayla döner (tek '
        'seferlik)', () async {
      fake.failNext(AuthError.network);
      final failed = await fake.signIn(email: _email, password: _password);
      expect(failed.errorOrNull, AuthError.network);
      expect(fake.service.calls, isEmpty);
      // Repository düzeyindeki hata giriş kilidine sayılmaz.
      expect(fake.loginLockRemaining(_email), isNull);

      expect(
        (await fake.signIn(email: _email, password: _password)).isSuccess,
        isTrue,
      );
    });

    test('tokenErrors, tokenErrorController olaylarını yayınlar', () async {
      final errors = <AuthError>[];
      final subscription = fake.tokenErrors.listen(errors.add);
      addTearDown(subscription.cancel);
      fake.tokenErrorController.add(AuthError.sessionExpired);
      await pumpEventQueue();
      expect(errors, [AuthError.sessionExpired]);
    });
  });
}
