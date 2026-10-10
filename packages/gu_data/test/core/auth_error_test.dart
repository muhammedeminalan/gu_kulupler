// T-08 · AuthError: üye listesi, hata kodu eşleme tablosu ve PLAN paritesi
// (PLAN §4.2, §10.1).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/plan_error_tables.dart';

/// PLAN §4.2 ağaç satırındaki sırayla 16 üye.
const List<String> _members = [
  'invalidEmail',
  'userDisabled',
  'invalidCredentials',
  'emailAlreadyInUse',
  'weakPassword',
  'tooManyRequests',
  'network',
  'requiresRecentLogin',
  'sessionExpired',
  'invalidActionCode',
  'operationNotAllowed',
  'unknown',
  'domainNotAllowed',
  'lockedOut',
  'resendCooldown',
  'emailNotVerified',
];

/// `FirebaseAuthException.code` → beklenen üye (PLAN §10.1 tablosunun SDK
/// satırları).
const Map<String, AuthError> _sdkCodes = {
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
  'requires-recent-login': AuthError.requiresRecentLogin,
  'user-token-expired': AuthError.sessionExpired,
  'user-mismatch': AuthError.sessionExpired,
  'invalid-user-token': AuthError.sessionExpired,
  'invalid-action-code': AuthError.invalidActionCode,
  'expired-action-code': AuthError.invalidActionCode,
  'operation-not-allowed': AuthError.operationNotAllowed,
};

/// SDK'nın üretmediği, yalnızca uygulama kodunun kurduğu üyeler.
const Set<AuthError> _appOnly = {
  AuthError.domainNotAllowed,
  AuthError.lockedOut,
  AuthError.resendCooldown,
  AuthError.emailNotVerified,
};

void main() {
  group('T-08 · AuthError · üyeler', () {
    test('16 üye, PLAN sırasıyla', () {
      expect([for (final e in AuthError.values) e.name], _members);
      expect(AuthError.values, hasLength(16));
    });

    test('her üye SDK eşlemesinde, uygulama kümesinde ya da unknown', () {
      final fromSdk = _sdkCodes.values.toSet();

      expect(fromSdk.intersection(_appOnly), isEmpty);
      expect(fromSdk, isNot(contains(AuthError.unknown)));
      expect({
        ...fromSdk,
        ..._appOnly,
        AuthError.unknown,
      }, AuthError.values.toSet());
    });
  });

  group('T-08 · AuthError.fromCode · tablo', () {
    _sdkCodes.forEach((code, expected) {
      test('$code → ${expected.name}', () {
        expect(AuthError.fromCode(code), expected);
      });
    });

    test('kullanıcı yok ve yanlış şifre ayırt edilmez (hesap sızdırmaz)', () {
      expect(
        {
          AuthError.fromCode('user-not-found'),
          AuthError.fromCode('wrong-password'),
          AuthError.fromCode('invalid-credential'),
          AuthError.fromCode('INVALID_LOGIN_CREDENTIALS'),
        },
        {AuthError.invalidCredentials},
      );
    });

    test('üç oturum kodu da sessionExpired', () {
      expect(
        {
          AuthError.fromCode('user-token-expired'),
          AuthError.fromCode('user-mismatch'),
          AuthError.fromCode('invalid-user-token'),
        },
        {AuthError.sessionExpired},
      );
    });

    test('geçersiz ve süresi dolmuş eylem kodu aynı üye', () {
      expect(
        AuthError.fromCode('expired-action-code'),
        AuthError.fromCode('invalid-action-code'),
      );
    });

    test('too-many-requests SDK kısıtıdır; lockedOut ile karışmaz', () {
      expect(
        AuthError.fromCode('too-many-requests'),
        isNot(AuthError.lockedOut),
      );
    });
  });

  group('T-08 · AuthError.fromCode · eşleşmeyen', () {
    for (final code in const [
      '',
      ' ',
      'x',
      'INVALID-EMAIL',
      'Invalid-Email',
      'invalid_email',
      'invalidEmail',
      ' invalid-email',
      'invalid-email ',
      'firebase_auth/invalid-email',
      '[firebase_auth/wrong-password]',
      'invalid_login_credentials',
      'invalid-login-credentials',
      'INVALID_LOGIN_CREDENTIAL',
      'user-not-found.',
      'account-exists-with-different-credential',
      'credential-already-in-use',
      'provider-already-linked',
      'missing-email',
      'missing-password',
      'channel-error',
      'internal-error',
      'captcha-check-failed',
      'quota-exceeded',
      'unknown',
      'permission-denied',
    ]) {
      test('"$code" → unknown', () {
        expect(AuthError.fromCode(code), AuthError.unknown);
      });
    }

    test('uygulama üyelerinin adları SDK kodu sayılmaz', () {
      for (final code in const [
        'domainNotAllowed',
        'domain-not-allowed',
        'lockedOut',
        'locked-out',
        'resendCooldown',
        'resend-cooldown',
        'emailNotVerified',
        'email-not-verified',
      ]) {
        expect(AuthError.fromCode(code), AuthError.unknown, reason: code);
      }
    });

    test('fromCode hiçbir girdide uygulama üyesi döndürmez', () {
      final candidates = [
        ..._sdkCodes.keys,
        for (final error in AuthError.values) error.name,
      ];

      for (final code in candidates) {
        expect(_appOnly, isNot(contains(AuthError.fromCode(code))));
      }
    });
  });

  group('T-08 · AuthError · PLAN paritesi', () {
    test('§10.1 tablosundaki her SDK kodu aynı üyeye eşlenir', () {
      final plan = readPlanErrorTable('AuthError');

      expect(plan.sdkCodes, isNotEmpty);
      plan.sdkCodes.forEach((code, member) {
        expect(AuthError.fromCode(code).name, member, reason: code);
      });
    });

    test('§10.1 tablosundaki SDK kodları = testteki tablo', () {
      final plan = readPlanErrorTable('AuthError');

      expect(plan.sdkCodes, {
        for (final entry in _sdkCodes.entries) entry.key: entry.value.name,
      });
    });

    test('§10.1 "diğer" satırı unknown', () {
      expect(readPlanErrorTable('AuthError').fallbackMember, 'unknown');
    });

    test('§10.1 uygulama satırları = uygulama üyeleri (sırayla)', () {
      expect(readPlanErrorTable('AuthError').appMembers, [
        'domainNotAllowed',
        'lockedOut',
        'resendCooldown',
        'emailNotVerified',
      ]);
    });

    test('§10.1 tablosunda adı geçen üyeler = enum üyeleri', () {
      expect(readPlanErrorTable('AuthError').members, {
        for (final error in AuthError.values) error.name,
      });
    });

    test('§4.2 ağaç satırı: 16 üye, aynı ad ve sıra', () {
      final tree = readPlanTreeEnum(
        file: 'auth_error.dart',
        enumName: 'AuthError',
      );

      expect(tree.count, 16);
      expect(tree.members, [for (final e in AuthError.values) e.name]);
    });
  });
}
