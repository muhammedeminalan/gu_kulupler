// T-12 · AuthRepository: kayıt (alan adı kısıtı, şifre politikası, doğrulama
// e-postası), giriş (5 hatalı deneme → 30 sn kilit), doğrulama e-postası
// (60 sn bekleme), "Doğruladım" (jeton yenileme), şifre sıfırlama /
// değiştirme, çıkış, süper admin claim'i, oturum ve tokenErrors köprüleri
// (PLAN §10.1, §10.4; Q-04, D-27, D-28, CD-76).

import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/fake_app_clock.dart';
import '../fakes/scripted_auth_service.dart';
import '../helpers/plan_repository_table.dart';
import '../helpers/plan_service_table.dart';

const String _interface =
    'packages/gu_data/lib/src/repositories/auth_repository.dart';
const String _implementation =
    'packages/gu_data/lib/src/repositories/firebase_auth_repository.dart';
const String _email = 'ayse@ogr.gumushane.edu.tr';
const String _name = 'Ayşe Yılmaz';
const String _password = 'Sifre1234';
const String _wrongPassword = 'Yanlis1234';

void main() {
  final start = DateTime.utc(2026, 10, 10, 9);
  late FakeAppClock clock;
  late ScriptedAuthService auth;
  late AuthRepository repository;

  setUp(() {
    clock = FakeAppClock(start);
    auth = ScriptedAuthService();
    repository = FirebaseAuthRepository(auth, clock);
  });

  tearDown(() => auth.dispose());

  /// [email] ile [times] kez hatalı giriş dener; sonuçların hatalarını döner.
  Future<List<AuthError?>> failSignIn(
    int times, {
    String email = _email,
  }) async {
    auth.failNext('signIn', AuthError.invalidCredentials, times: times);
    return [
      for (var i = 0; i < times; i++)
        (await repository.signIn(
          email: email,
          password: _wrongPassword,
        )).errorOrNull,
    ];
  }

  group('T-12 · AuthRepository · sözleşme', () {
    test('PLAN §10.4 tablosundaki her üye arayüzde aynı imzayla var; tablo '
        'dışı tek üye tokenErrors köprüsü', () {
      final members = interfaceMembers(_interface, '$AuthRepository');
      final plan = readPlanRepositoryMembers('$AuthRepository');

      expect(plan, hasLength(13));
      for (final row in plan) {
        expect(
          members,
          contains(normalizeDartSource(row.signature)),
          reason: row.member,
        );
      }
      expect(
        members.toSet().difference({
          for (final row in plan) normalizeDartSource(row.signature),
        }),
        {'Stream<AuthError>gettokenErrors'},
      );
    });

    test('arayüzde ve uygulamada silme üyesi yok (D-10, Q-11)', () {
      expect(deleteIdentifiersIn(_interface), isEmpty);
      expect(deleteIdentifiersIn(_implementation), isEmpty);
    });
  });

  group('T-12 · AuthRepository · register', () {
    for (final email in [
      'ayse@ogr.gumushane.edu.tr',
      'hoca@gumushane.edu.tr',
      'Ayse@OGR.Gumushane.Edu.TR',
    ]) {
      test('izinli alan adı hesap açar ve doğrulama e-postası gönderir: '
          '$email', () async {
        final result = await repository.register(
          email: '  $email ',
          password: _password,
          name: _name,
        );

        expect(
          result.dataOrNull,
          AuthUserInfo(
            uid: 'u_ayse',
            email: email,
            emailVerified: false,
            displayName: _name,
          ),
        );
        expect(
          auth.calls,
          ['register:$email', 'sendEmailVerification'],
          reason: 'adres kırpılarak servise gider',
        );
        expect(auth.registeredNames, [_name]);
        expect(
          repository.resendCooldownRemaining,
          Limits.verificationResendCooldown,
        );
      });
    }

    for (final email in [
      'ayse@gmail.com',
      'ayse@x.gumushane.edu.tr',
      'ayse@mail.ogr.gumushane.edu.tr',
      'ayse@evilgumushane.edu.tr',
      'ayse@gumushane.edu.tr.evil.com',
      'ayse@gumushane.edu',
    ]) {
      test('izinli olmayan alan adı servise gitmeden domainNotAllowed: '
          '$email', () async {
        final result = await repository.register(
          email: email,
          password: _password,
          name: _name,
        );

        expect(result.errorOrNull, AuthError.domainNotAllowed);
        expect(auth.calls, isEmpty);
        expect(auth.currentUser, isNull);
      });
    }

    for (final email in [
      '',
      'ayse',
      '@gumushane.edu.tr',
      'a@b@gumushane.edu.tr',
      'ay şe@gumushane.edu.tr',
    ]) {
      test(
        'biçimi bozuk adres servise gitmeden invalidEmail: "$email"',
        () async {
          final result = await repository.register(
            email: email,
            password: _password,
            name: _name,
          );

          expect(result.errorOrNull, AuthError.invalidEmail);
          expect(auth.calls, isEmpty);
        },
      );
    }

    for (final password in ['Sifre12', 'sifre1234', 'SifreSifre', '']) {
      test('politikaya uymayan şifre servise gitmeden weakPassword: '
          '"$password"', () async {
        final result = await repository.register(
          email: _email,
          password: password,
          name: _name,
        );

        expect(result.errorOrNull, AuthError.weakPassword);
        expect(auth.calls, isEmpty);
      });
    }

    test('Türkçe büyük harfli şifre politikayı geçer', () async {
      final result = await repository.register(
        email: _email,
        password: 'şifre1234Ş',
        name: _name,
      );

      expect(result.isSuccess, isTrue);
    });

    test('ad kırpılarak kimlik hesabının görünen adı olur ve oturumda '
        'taşınır (CD-134)', () async {
      final result = await repository.register(
        email: _email,
        password: _password,
        name: '  Ayşe Yılmaz  ',
      );

      expect(auth.registeredNames, ['Ayşe Yılmaz']);
      expect(result.dataOrNull?.displayName, 'Ayşe Yılmaz');
      expect(repository.currentUser?.displayName, 'Ayşe Yılmaz');
    });

    test('ad doğrulama sonrasında da okunur: reloadUser görünen adı korur '
        '(profil belgesi o zaman oluşturulur — W-56)', () async {
      await repository.register(
        email: _email,
        password: _password,
        name: _name,
      );
      auth.emailVerified = true;

      final reloaded = await repository.reloadUser();

      expect(
        reloaded.dataOrNull,
        const AuthUserInfo(
          uid: 'u_ayse',
          email: _email,
          emailVerified: true,
          displayName: _name,
        ),
      );
    });

    test('ad başka cihazdaki girişte de gelir: signIn görünen adı '
        'taşır', () async {
      await repository.register(
        email: _email,
        password: _password,
        name: _name,
      );
      await repository.signOut();

      final signedIn = await repository.signIn(
        email: _email,
        password: _password,
      );

      expect(signedIn.dataOrNull?.displayName, _name);
    });

    test(
      'servis hatası aynen döner; doğrulama e-postası gönderilmez',
      () async {
        auth.failNext('register', AuthError.emailAlreadyInUse);

        final result = await repository.register(
          email: _email,
          password: _password,
          name: _name,
        );

        expect(result.errorOrNull, AuthError.emailAlreadyInUse);
        expect(auth.calls, ['register:$_email']);
        expect(repository.resendCooldownRemaining, isNull);
      },
    );

    test('doğrulama e-postası gönderilemezse kayıt yine başarıdır ve bekleme '
        'başlamaz', () async {
      auth.failNext('sendEmailVerification', AuthError.network);

      final result = await repository.register(
        email: _email,
        password: _password,
        name: _name,
      );

      expect(result.dataOrNull?.uid, 'u_ayse');
      expect(repository.resendCooldownRemaining, isNull);
      expect((await repository.sendEmailVerification()).isSuccess, isTrue);
    });
  });

  group('T-12 · AuthRepository · signIn ve giriş kilidi', () {
    test(
      'başarı: kullanıcıyı döndürür, adres kırpılarak servise gider',
      () async {
        auth.emailVerified = true;

        final result = await repository.signIn(
          email: ' $_email ',
          password: _password,
        );

        expect(
          result.dataOrNull,
          const AuthUserInfo(uid: 'u_ayse', email: _email, emailVerified: true),
        );
        expect(auth.calls, ['signIn:$_email']);
      },
    );

    test('4 hatalı deneme kilitlemez; 5. deneme kendi hatasıyla döner ve '
        'adresi 30 sn kilitler', () async {
      expect(await failSignIn(4), everyElement(AuthError.invalidCredentials));
      expect(repository.loginLockRemaining(_email), isNull);

      expect(await failSignIn(1), [AuthError.invalidCredentials]);

      expect(auth.count('signIn'), Limits.loginMaxFailedAttempts);
      expect(repository.loginLockRemaining(_email), Limits.loginLockout);
    });

    test(
      'kilitliyken doğru şifre de servise gitmez: lockedOut + kalan süre',
      () async {
        await failSignIn(5);
        clock.advance(const Duration(seconds: 12));

        final result = await repository.signIn(
          email: _email,
          password: _password,
        );

        expect(result.errorOrNull, AuthError.lockedOut);
        expect(
          (result as FirebaseFailure).detail,
          AuthFailureDetail(
            retryAfter: start.add(Limits.loginLockout),
            remaining: const Duration(seconds: 18),
          ),
        );
        expect(auth.count('signIn'), 5, reason: 'servise gidilmedi');
        expect(auth.currentUser, isNull);
      },
    );

    test('kilit 30. saniyede açılır ve sayaç sıfırdan başlar', () async {
      await failSignIn(5);
      clock.advance(Limits.loginLockout - const Duration(milliseconds: 1));
      expect(
        (await repository.signIn(
          email: _email,
          password: _password,
        )).errorOrNull,
        AuthError.lockedOut,
      );

      clock.advance(const Duration(milliseconds: 1));
      expect(repository.loginLockRemaining(_email), isNull);
      expect(await failSignIn(4), everyElement(AuthError.invalidCredentials));
      expect(repository.loginLockRemaining(_email), isNull);

      final result = await repository.signIn(
        email: _email,
        password: _password,
      );
      expect(result.isSuccess, isTrue);
    });

    test('başarılı giriş sayacı sıfırlar', () async {
      await failSignIn(4);
      await repository.signIn(email: _email, password: _password);

      await failSignIn(4);

      expect(repository.loginLockRemaining(_email), isNull);
    });

    test(
      'yalnızca hatalı kimlik bilgisi sayılır (ağ hatası kilitlemez)',
      () async {
        auth.failNext('signIn', AuthError.network, times: 6);

        for (var i = 0; i < 6; i++) {
          final result = await repository.signIn(
            email: _email,
            password: _password,
          );
          expect(result.errorOrNull, AuthError.network);
        }

        expect(repository.loginLockRemaining(_email), isNull);
      },
    );

    test(
      'sayaç e-posta başınadır; büyük/küçük harf ve boşluk aynı adrestir',
      () async {
        await failSignIn(3);
        await failSignIn(2, email: ' AYSE@ogr.gumushane.edu.tr ');

        expect(repository.loginLockRemaining(_email), Limits.loginLockout);
        expect(
          repository.loginLockRemaining('mehmet@ogr.gumushane.edu.tr'),
          isNull,
        );
        final other = await repository.signIn(
          email: 'mehmet@ogr.gumushane.edu.tr',
          password: _password,
        );
        expect(other.isSuccess, isTrue);
      },
    );

    test(
      'izinli olmayan ya da bozuk adres servise gitmez ve sayılmaz',
      () async {
        for (var i = 0; i < 6; i++) {
          expect(
            (await repository.signIn(
              email: 'ayse@gmail.com',
              password: _password,
            )).errorOrNull,
            AuthError.domainNotAllowed,
          );
        }
        expect(
          (await repository.signIn(
            email: 'ayse',
            password: _password,
          )).errorOrNull,
          AuthError.invalidEmail,
        );

        expect(auth.calls, isEmpty);
        expect(repository.loginLockRemaining('ayse@gmail.com'), isNull);
      },
    );
  });

  group('T-12 · AuthRepository · sendEmailVerification (60 sn bekleme)', () {
    setUp(() => repository.signIn(email: _email, password: _password));

    test('ilk gönderim başarılıdır; 60 sn dolmadan ikincisi servise gitmeden '
        'resendCooldown + kalan süre döner', () async {
      expect((await repository.sendEmailVerification()).isSuccess, isTrue);
      clock.advance(const Duration(seconds: 59));

      final result = await repository.sendEmailVerification();

      expect(result.errorOrNull, AuthError.resendCooldown);
      expect(
        (result as FirebaseFailure).detail,
        AuthFailureDetail(
          retryAfter: start.add(Limits.verificationResendCooldown),
          remaining: const Duration(seconds: 1),
        ),
      );
      expect(auth.count('sendEmailVerification'), 1);
    });

    test('60. saniyede yeniden gönderilir ve bekleme yeniden başlar', () async {
      await repository.sendEmailVerification();
      clock.advance(Limits.verificationResendCooldown);

      expect((await repository.sendEmailVerification()).isSuccess, isTrue);

      expect(auth.count('sendEmailVerification'), 2);
      expect(
        repository.resendCooldownRemaining,
        Limits.verificationResendCooldown,
      );
    });

    test('resendCooldownRemaining: yok → 60 sn → azalır → yok', () async {
      expect(repository.resendCooldownRemaining, isNull);

      await repository.sendEmailVerification();
      expect(
        repository.resendCooldownRemaining,
        Limits.verificationResendCooldown,
      );

      clock.advance(const Duration(seconds: 40));
      expect(repository.resendCooldownRemaining, const Duration(seconds: 20));

      clock.advance(const Duration(seconds: 20));
      expect(repository.resendCooldownRemaining, isNull);
    });

    test('gönderim hatası aynen döner ve bekleme başlatmaz', () async {
      auth.failNext('sendEmailVerification', AuthError.tooManyRequests);

      final result = await repository.sendEmailVerification();

      expect(result.errorOrNull, AuthError.tooManyRequests);
      expect(repository.resendCooldownRemaining, isNull);
    });

    test('oturum yokken sessionExpired; bekleme başlamaz', () async {
      await repository.signOut();

      final result = await repository.sendEmailVerification();

      expect(result.errorOrNull, AuthError.sessionExpired);
      expect(repository.resendCooldownRemaining, isNull);
    });

    test('bekleme hesaba özgüdür: başka hesap hemen gönderebilir', () async {
      await repository.sendEmailVerification();
      await repository.signOut();
      auth.uid = 'u_mehmet';
      await repository.signIn(
        email: 'mehmet@ogr.gumushane.edu.tr',
        password: _password,
      );

      expect(repository.resendCooldownRemaining, isNull);
      expect((await repository.sendEmailVerification()).isSuccess, isTrue);
    });
  });

  group('T-12 · AuthRepository · reloadUser', () {
    setUp(() => repository.signIn(email: _email, password: _password));

    test(
      'e-posta doğrulanmamışsa emailNotVerified; jeton yenilenmez',
      () async {
        final result = await repository.reloadUser();

        expect(result.errorOrNull, AuthError.emailNotVerified);
        expect(auth.count('idTokenClaims'), 0);
      },
    );

    test('doğrulanmışsa güncel kullanıcıyı döndürür ve kimlik jetonunu '
        'yeniler (Rules email_verified jetondan okunur)', () async {
      auth.emailVerified = true;

      final result = await repository.reloadUser();

      expect(
        result.dataOrNull,
        const AuthUserInfo(uid: 'u_ayse', email: _email, emailVerified: true),
      );
      expect(auth.calls.skip(1), ['reload', 'idTokenClaims:true']);
    });

    test('jeton yenilenemezse o hata döner (doğrulandı sayılmaz)', () async {
      auth
        ..emailVerified = true
        ..failNext('idTokenClaims', AuthError.network);

      final result = await repository.reloadUser();

      expect(result.errorOrNull, AuthError.network);
    });

    test('yenileme hatası aynen döner', () async {
      auth.failNext('reload', AuthError.userDisabled);

      final result = await repository.reloadUser();

      expect(result.errorOrNull, AuthError.userDisabled);
      expect(auth.count('idTokenClaims'), 0);
    });
  });

  group('T-12 · AuthRepository · şifre sıfırlama ve değiştirme', () {
    test('sendPasswordReset: başarı; adres kırpılır', () async {
      final result = await repository.sendPasswordReset(email: ' $_email ');

      expect(result.isSuccess, isTrue);
      expect(auth.calls, ['sendPasswordReset:$_email']);
    });

    test(
      'sendPasswordReset: hesap yoksa da başarı döner (bilgi sızdırmaz)',
      () async {
        auth.failNext('sendPasswordReset', AuthError.invalidCredentials);

        final result = await repository.sendPasswordReset(email: _email);

        expect(result.isSuccess, isTrue);
      },
    );

    test('sendPasswordReset: diğer hatalar aynen döner', () async {
      auth.failNext('sendPasswordReset', AuthError.network);

      final result = await repository.sendPasswordReset(email: _email);

      expect(result.errorOrNull, AuthError.network);
    });

    test('reauthenticate: servise delege eder; hata aynen döner', () async {
      await repository.signIn(email: _email, password: _password);

      expect(
        (await repository.reauthenticate(password: _password)).isSuccess,
        isTrue,
      );
      auth.failNext('reauthenticate', AuthError.invalidCredentials);
      expect(
        (await repository.reauthenticate(password: _wrongPassword)).errorOrNull,
        AuthError.invalidCredentials,
      );
    });

    test(
      'changePassword: önce yeniden doğrular, sonra yeni şifreyi yazar',
      () async {
        await repository.signIn(email: _email, password: _password);

        final result = await repository.changePassword(
          currentPassword: _password,
          newPassword: 'YeniSifre99',
        );

        expect(result.isSuccess, isTrue);
        expect(auth.calls.skip(1), [
          'reauthenticate:$_password',
          'updatePassword:YeniSifre99',
        ]);
      },
    );

    test(
      'changePassword: mevcut şifre hatalıysa yeni şifre yazılmaz',
      () async {
        await repository.signIn(email: _email, password: _password);
        auth.failNext('reauthenticate', AuthError.invalidCredentials);

        final result = await repository.changePassword(
          currentPassword: _wrongPassword,
          newPassword: 'YeniSifre99',
        );

        expect(result.errorOrNull, AuthError.invalidCredentials);
        expect(auth.count('updatePassword'), 0);
      },
    );

    test(
      'changePassword: zayıf yeni şifre servise gitmeden weakPassword',
      () async {
        await repository.signIn(email: _email, password: _password);

        final result = await repository.changePassword(
          currentPassword: _password,
          newPassword: 'zayif',
        );

        expect(result.errorOrNull, AuthError.weakPassword);
        expect(auth.count('reauthenticate'), 0);
      },
    );

    test('changePassword: şifre yazma hatası aynen döner', () async {
      await repository.signIn(email: _email, password: _password);
      auth.failNext('updatePassword', AuthError.requiresRecentLogin);

      final result = await repository.changePassword(
        currentPassword: _password,
        newPassword: 'YeniSifre99',
      );

      expect(result.errorOrNull, AuthError.requiresRecentLogin);
    });
  });

  group('T-12 · AuthRepository · oturum ve claim', () {
    test('signOut: oturumu kapatır; hata aynen döner', () async {
      await repository.signIn(email: _email, password: _password);

      expect((await repository.signOut()).isSuccess, isTrue);
      expect(repository.currentUser, isNull);

      auth.failNext('signOut', AuthError.unknown);
      expect((await repository.signOut()).errorOrNull, AuthError.unknown);
    });

    test('currentUser ve watchAuthState servisin oturumunu yansıtır', () async {
      const user = AuthUserInfo(uid: 'u1', email: _email, emailVerified: true);
      final events = <AuthUserInfo?>[];
      final subscription = repository.watchAuthState().listen(events.add);

      auth.stateEvents
        ..add(user)
        ..add(null);
      await pumpEventQueue();
      await subscription.cancel();

      expect(events, [user, null]);
      expect(repository.currentUser, isNull);
      await repository.signIn(email: _email, password: _password);
      expect(repository.currentUser?.uid, 'u_ayse');
    });

    test('tokenErrors servisin akışını aynen iletir', () async {
      final errors = <AuthError>[];
      final subscription = repository.tokenErrors.listen(errors.add);

      auth.tokenErrorEvents
        ..add(AuthError.sessionExpired)
        ..add(AuthError.userDisabled);
      await pumpEventQueue();
      await subscription.cancel();

      expect(errors, [AuthError.sessionExpired, AuthError.userDisabled]);
    });

    for (final (claims, expected) in <(Map<String, Object?>, bool)>[
      ({'superadmin': true}, true),
      ({'superadmin': false}, false),
      ({'superadmin': 'true'}, false),
      ({'superadmin': 1}, false),
      ({'admin': true}, false),
      (const {}, false),
    ]) {
      test('isSuperAdmin: claim $claims → $expected', () async {
        await repository.signIn(email: _email, password: _password);
        auth.claims = claims;

        expect((await repository.isSuperAdmin()).dataOrNull, expected);
      });
    }

    test(
      'isSuperAdmin: forceRefresh servise iletilir; hata aynen döner',
      () async {
        await repository.signIn(email: _email, password: _password);

        await repository.isSuperAdmin();
        await repository.isSuperAdmin(forceRefresh: true);
        auth.failNext('idTokenClaims', AuthError.network);
        final failed = await repository.isSuperAdmin();

        expect(auth.calls.skip(1).take(2), [
          'idTokenClaims:false',
          'idTokenClaims:true',
        ]);
        expect(failed.errorOrNull, AuthError.network);
      },
    );

    test('isSuperAdmin: oturum yokken sessionExpired', () async {
      expect(
        (await repository.isSuperAdmin()).errorOrNull,
        AuthError.sessionExpired,
      );
    });
  });
}
