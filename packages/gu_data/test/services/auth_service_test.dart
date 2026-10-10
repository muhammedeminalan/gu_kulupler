// T-10 · AuthService: oturum açma/kapama, kayıt, doğrulama, yeniden doğrulama,
// şifre, claim okuma, oturum akışı, tokenErrors, hata → FirebaseFailure
// eşlemesi, zaman aşımı ve "hesap silme yok" sözleşmesi (PLAN §10.1–§10.2;
// D-10, D-28, D-34, Q-11).
//
// Mutlu yollar `firebase_auth_mocks` ile (Q-06); hata ve zaman aşımı yolları
// el yazımı SDK çiftleriyle (`test/fakes/sdk_auth_stubs.dart`).
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/sdk_auth_stubs.dart';
import '../helpers/plan_service_table.dart';
import '../helpers/repo_sources.dart';

const String _source = 'packages/gu_data/lib/src/services/auth_service.dart';
const String _email = 'ayse@ogr.gumushane.edu.tr';
const String _password = 'Sifre1234';

/// Oturum gerektiren beş çağrı (ad → çağrı).
Map<String, Future<AuthResult<Object?>> Function()> _sessionCalls(
  AuthService service,
) => {
  'sendEmailVerification': service.sendEmailVerification,
  'reload': service.reload,
  'reauthenticate': () => service.reauthenticate(password: _password),
  'updatePassword': () => service.updatePassword(newPassword: _password),
  'idTokenClaims': service.idTokenClaims,
};

void main() {
  late MockFirebaseAuth auth;
  late FirebaseAuthService service;

  /// [mockUser] ile oturum açılmış servis.
  Future<FirebaseAuthService> signedIn(MockUser mockUser) async {
    auth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);
    return service = FirebaseAuthService(auth);
  }

  setUp(() {
    auth = MockFirebaseAuth(
      mockUser: MockUser(uid: 'u_ayse', email: _email, isEmailVerified: false),
    );
    service = FirebaseAuthService(auth);
  });

  tearDown(() => service.dispose());

  group('T-10 · AuthService · oturum', () {
    test('signIn: kullanıcı bilgisini döndürür ve oturumu açar', () async {
      expect(service.currentUser, isNull);

      final result = await service.signIn(email: _email, password: _password);

      const expected = AuthUserInfo(
        uid: 'u_ayse',
        email: _email,
        emailVerified: false,
      );
      expect(result.dataOrNull, expected);
      expect(service.currentUser, expected);
    });

    test(
      'register: verilen e-postayla hesap açar, oturum açık döner',
      () async {
        auth = MockFirebaseAuth(verifyEmailAutomatically: false);
        service = FirebaseAuthService(auth);

        final info = (await service.register(
          email: _email,
          password: _password,
        )).dataOrNull!;

        expect(info.email, _email);
        expect(info.emailVerified, isFalse);
        expect(info.uid, isNotEmpty);
        expect(service.currentUser, info);
      },
    );

    test('signOut: oturumu kapatır', () async {
      await service.signIn(email: _email, password: _password);

      final result = await service.signOut();

      expect(result.isSuccess, isTrue);
      expect(service.currentUser, isNull);
    });

    test(
      'authStateChanges: açılış/kapanışları AuthUserInfo olarak yayınlar',
      () async {
        final events = <AuthUserInfo?>[];
        final subscription = service.authStateChanges().listen(events.add);
        await pumpEventQueue();

        await service.signIn(email: _email, password: _password);
        await service.signOut();
        await pumpEventQueue();
        await subscription.cancel();

        expect(events.map((info) => info?.uid), [null, 'u_ayse', null]);
      },
    );

    test('sendPasswordReset: başarı döner', () async {
      final result = await service.sendPasswordReset(email: _email);

      expect(result.isSuccess, isTrue);
    });
  });

  group('T-10 · AuthService · oturum gerektiren çağrılar', () {
    test('oturum açıkken beşi de başarı döner', () async {
      await signedIn(MockUser(uid: 'u_ayse', email: _email));

      for (final MapEntry(key: name, value: call) in _sessionCalls(
        service,
      ).entries) {
        expect((await call()).isSuccess, isTrue, reason: name);
      }
    });

    test('reload: güncel kullanıcı bilgisini döndürür', () async {
      await signedIn(MockUser(uid: 'u_ayse', email: _email));

      final result = await service.reload();

      expect(
        result.dataOrNull,
        const AuthUserInfo(uid: 'u_ayse', email: _email, emailVerified: true),
      );
    });

    test('idTokenClaims: claim eşlemesini döndürür (superadmin); sonuç '
        'değiştirilemez', () async {
      await signedIn(
        MockUser(
          uid: 'u_admin',
          email: _email,
          customClaim: {'superadmin': true},
        ),
      );

      final claims = (await service.idTokenClaims(
        forceRefresh: true,
      )).dataOrNull!;

      expect(claims['superadmin'], isTrue);
      expect(() => claims['superadmin'] = false, throwsUnsupportedError);
    });

    test('reauthenticate: oturumdaki e-posta + verilen şifreyle kimlik '
        'bilgisi kurar', () async {
      final user = StubUser(error: authException('wrong-password'));
      service = FirebaseAuthService(StubFirebaseAuth(currentUser: user));

      final result = await service.reauthenticate(password: _password);

      expect(result.errorOrNull, AuthError.invalidCredentials);
      expect(
        user.lastCredential,
        isA<EmailAuthCredential>()
            .having((c) => c.email, 'email', _email)
            .having((c) => c.password, 'password', _password),
      );
    });

    test('reauthenticate: kullanıcının e-postası yoksa SDK çağrılmaz, '
        'operationNotAllowed', () async {
      final user = StubUser(email: null);
      service = FirebaseAuthService(StubFirebaseAuth(currentUser: user));

      final result = await service.reauthenticate(password: _password);

      expect(result.errorOrNull, AuthError.operationNotAllowed);
      expect(user.lastCredential, isNull);
    });

    test('oturum yokken beşi de sessionExpired döner (fırlatmaz)', () async {
      final tokenErrors = <AuthError>[];
      final subscription = service.tokenErrors.listen(tokenErrors.add);

      for (final MapEntry(key: name, value: call) in _sessionCalls(
        service,
      ).entries) {
        expect(
          (await call()).errorOrNull,
          AuthError.sessionExpired,
          reason: name,
        );
      }
      await pumpEventQueue();
      await subscription.cancel();

      expect(tokenErrors, isEmpty, reason: 'oturum akışı zaten null yayınlar');
    });
  });

  group('T-10 · AuthService · hata eşlemesi', () {
    const codes = {
      'invalid-email': AuthError.invalidEmail,
      'user-disabled': AuthError.userDisabled,
      'user-not-found': AuthError.invalidCredentials,
      'wrong-password': AuthError.invalidCredentials,
      'invalid-credential': AuthError.invalidCredentials,
      'INVALID_LOGIN_CREDENTIALS': AuthError.invalidCredentials,
      'email-already-in-use': AuthError.emailAlreadyInUse,
      'weak-password': AuthError.weakPassword,
      'too-many-requests': AuthError.tooManyRequests,
      'network-request-failed': AuthError.network,
      'operation-not-allowed': AuthError.operationNotAllowed,
      'bilinmeyen-kod': AuthError.unknown,
    };

    test(
      'SDK kodu AuthError.fromCode ile çevrilir; ham mesaj taşınır',
      () async {
        for (final MapEntry(key: code, value: expected) in codes.entries) {
          service = FirebaseAuthService(
            StubFirebaseAuth(error: authException(code, message: 'ham $code')),
          );

          final signIn = await service.signIn(
            email: _email,
            password: _password,
          );
          final register = await service.register(
            email: _email,
            password: _password,
          );

          expect(signIn.errorOrNull, expected, reason: code);
          expect(register.errorOrNull, expected, reason: code);
          expect(
            (signIn as FirebaseFailure).message,
            'ham $code',
            reason: code,
          );
        }
      },
    );

    test(
      'sonuç döndüren her metot SDK hatasını FirebaseFailure olarak verir',
      () async {
        final error = authException('too-many-requests');
        service = FirebaseAuthService(
          StubFirebaseAuth(
            error: error,
            currentUser: StubUser(error: error),
          ),
        );

        final results = <String, AuthResult<Object?>>{
          'signIn': await service.signIn(email: _email, password: _password),
          'register': await service.register(
            email: _email,
            password: _password,
          ),
          'signOut': await service.signOut(),
          'sendPasswordReset': await service.sendPasswordReset(email: _email),
          for (final MapEntry(key: name, value: call) in _sessionCalls(
            service,
          ).entries)
            name: await call(),
        };

        expect(results, hasLength(9));
        for (final MapEntry(key: method, value: result) in results.entries) {
          expect(result.errorOrNull, AuthError.tooManyRequests, reason: method);
        }
      },
    );

    test(
      'updatePassword: requires-recent-login → requiresRecentLogin',
      () async {
        service = FirebaseAuthService(
          StubFirebaseAuth(
            currentUser: StubUser(
              error: authException('requires-recent-login'),
            ),
          ),
        );

        final result = await service.updatePassword(newPassword: _password);

        expect(result.errorOrNull, AuthError.requiresRecentLogin);
      },
    );

    test('SDK dışı istisna → unknown (fırlatılmaz)', () async {
      service = FirebaseAuthService(StubFirebaseAuth(error: StateError('x')));

      final result = await service.signIn(email: _email, password: _password);

      expect(result.errorOrNull, AuthError.unknown);
      expect((result as FirebaseFailure).message, contains('x'));
    });
  });

  group('T-10 · AuthService · tokenErrors', () {
    /// Oturumdaki kullanıcının her çağrısı [code] ile biten servis.
    FirebaseAuthService failingSession(String code) =>
        service = FirebaseAuthService(
          StubFirebaseAuth(
            error: authException(code),
            currentUser: StubUser(error: authException(code)),
          ),
        );

    test(
      'oturumu geçersiz kılan hata hem sonuç olarak döner hem yayınlanır',
      () async {
        const fatal = {
          'user-token-expired': AuthError.sessionExpired,
          'invalid-user-token': AuthError.sessionExpired,
          'user-mismatch': AuthError.sessionExpired,
          'user-disabled': AuthError.userDisabled,
          // Oturum çağrısında "kullanıcı yok" = hesap artık yok.
          'user-not-found': AuthError.sessionExpired,
        };

        for (final MapEntry(key: code, value: expected) in fatal.entries) {
          final emitted = <AuthError>[];
          final subscription = failingSession(code).tokenErrors.listen(
            emitted.add,
          );

          final result = await service.reload();
          await pumpEventQueue();
          await subscription.cancel();

          expect(result.errorOrNull, expected, reason: code);
          expect(emitted, [expected], reason: code);
        }
      },
    );

    test('oturumu bozmayan hata yayınlanmaz', () async {
      final emitted = <AuthError>[];
      final subscription = failingSession(
        'requires-recent-login',
      ).tokenErrors.listen(emitted.add);

      await service.updatePassword(newPassword: _password);
      await pumpEventQueue();
      await subscription.cancel();

      expect(emitted, isEmpty);
    });

    test(
      'giriş hatası (askıdaki hesap) yayınlanmaz: sonucu giriş akışı işler',
      () async {
        final emitted = <AuthError>[];
        final subscription = failingSession(
          'user-disabled',
        ).tokenErrors.listen(emitted.add);

        final result = await service.signIn(email: _email, password: _password);
        await pumpEventQueue();
        await subscription.cancel();

        expect(result.errorOrNull, AuthError.userDisabled);
        expect(emitted, isEmpty);
      },
    );

    test('oturum akışının hatası tokenErrors akışına düşer; oturum akışı '
        'hata taşımaz ve sürer', () async {
      final stub = StubFirebaseAuth();
      service = FirebaseAuthService(stub);
      final states = <AuthUserInfo?>[];
      final emitted = <AuthError>[];
      final stateSubscription = service.authStateChanges().listen(states.add);
      final errorSubscription = service.tokenErrors.listen(emitted.add);

      stub.stateEvents
        ..addError(authException('user-token-expired'))
        ..add(StubUser());
      await pumpEventQueue();
      await stateSubscription.cancel();
      await errorSubscription.cancel();

      expect(emitted, [AuthError.sessionExpired]);
      expect(states.single!.uid, 'u_ayse');
    });

    test('dispose sonrası hata fırlatmaz (akış kapalı)', () async {
      failingSession('user-token-expired');
      await service.dispose();

      final result = await service.reload();

      expect(result.errorOrNull, AuthError.sessionExpired);
    });
  });

  group('T-10 · AuthService · zaman aşımı', () {
    // Gövdede `pump` dışında `await` yok: sahte zaman bölgesinde gerçek
    // mikro görev kuyruğuna düşen bir bekleme testi askıda bırakır.
    testWidgets('varsayılan süre Limits.authTimeout: dolunca network', (
      tester,
    ) async {
      final stubbed = FirebaseAuthService(
        StubFirebaseAuth(currentUser: StubUser()),
      );
      AuthResult<AuthUserInfo>? signIn;
      AuthResult<AuthUserInfo>? reload;
      unawaited(
        stubbed
            .signIn(email: _email, password: _password)
            .then((r) => signIn = r),
      );
      unawaited(stubbed.reload().then((r) => reload = r));

      await tester.pump(Limits.authTimeout - const Duration(milliseconds: 1));
      expect(signIn, isNull);
      expect(reload, isNull);
      await tester.pump(const Duration(milliseconds: 1));

      expect(signIn!.errorOrNull, AuthError.network);
      expect(reload!.errorOrNull, AuthError.network);
    });
  });

  group('T-10 · AuthService · hesap silme yok (D-10, Q-11)', () {
    test('servis kaynağında delete ile başlayan hiçbir tanımlayıcı yok', () {
      expect(deleteIdentifiersIn(_source), isEmpty);
    });

    test(
      'PLAN §10.2 "YOK" satırı: arayüzde user.delete karşılığı bulunmaz',
      () {
        expect(readPlanAbsentMembers('AuthService'), ['user.delete']);
      },
    );

    test('PLAN §10.2 tablosundaki her üye arayüzde aynı imzayla var; ağaç '
        'satırındaki (§4.2) her ad arayüzde var', () {
      final raw = readRepoFile(_source);
      final source = normalizeDartSource(raw);
      final treeLine = readRepoFile('docs/PLAN.md')
          .split('\n')
          .singleWhere((line) => line.contains('── auth_service.dart'));
      final treeNames = RegExp(
        r'AuthService \(([^)]+)\)',
      ).firstMatch(treeLine)!.group(1)!.split(',').map((name) => name.trim());

      for (final member in readPlanServiceMembers('AuthService')) {
        expect(
          source,
          contains('${normalizeDartSource(member.signature)};'),
          reason: member.member,
        );
      }
      expect(treeNames, hasLength(11));
      for (final name in treeNames) {
        expect(raw, matches(RegExp('\\b$name\\b[(;<{ ]')), reason: name);
      }
      expect(
        readPlanServiceImplementation('AuthService'),
        '$FirebaseAuthService',
      );
    });
  });
}
