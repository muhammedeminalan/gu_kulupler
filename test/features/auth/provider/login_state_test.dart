// AUT-01 · LoginState: props / copyWith tüm alanlar, temizleme bayrakları,
// kilit türetimi (PLAN §12.5, §12.16).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/features/auth/provider/login_state.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';

void main() {
  group('AUT-01 · LoginState', () {
    const a = LoginState();
    final until = DateTime.utc(2026, 10, 12, 16, 30, 30);
    const errors = {LoginField.email: FormFieldError.required};

    test('props tüm alanları içerir (alan sayısı = 9)', () {
      expect(a.props.length, 9);
    });

    test('varsayılanlar: boş form, hata ve kilit yok', () {
      expect(a.email, isEmpty);
      expect(a.password, isEmpty);
      expect(a.isPasswordVisible, isFalse);
      expect(a.errors, isEmpty);
      expect(a.isDirty, isFalse);
      expect(a.isSubmitting, isFalse);
      expect(a.failedAttempts, 0);
      expect(a.lockedUntil, isNull);
      expect(a.submitError, isNull);
    });

    test('copyWith her alanı taşır ve eşitliği bozar', () {
      expect(a.copyWith(email: 'a@b.c').email, 'a@b.c');
      expect(a.copyWith(email: 'a@b.c'), isNot(a));
      expect(a.copyWith(password: 'Sifre123').password, 'Sifre123');
      expect(a.copyWith(password: 'Sifre123'), isNot(a));
      expect(a.copyWith(isPasswordVisible: true).isPasswordVisible, isTrue);
      expect(a.copyWith(isPasswordVisible: true), isNot(a));
      expect(a.copyWith(errors: errors).errors, errors);
      expect(a.copyWith(errors: errors), isNot(a));
      expect(a.copyWith(isDirty: true).isDirty, isTrue);
      expect(a.copyWith(isDirty: true), isNot(a));
      expect(a.copyWith(isSubmitting: true).isSubmitting, isTrue);
      expect(a.copyWith(isSubmitting: true), isNot(a));
      expect(a.copyWith(failedAttempts: 3).failedAttempts, 3);
      expect(a.copyWith(failedAttempts: 3), isNot(a));
      expect(a.copyWith(lockedUntil: until).lockedUntil, until);
      expect(a.copyWith(lockedUntil: until), isNot(a));
      expect(
        a.copyWith(submitError: LoginError.network).submitError,
        LoginError.network,
      );
      expect(a.copyWith(submitError: LoginError.network), isNot(a));
    });

    test('copyWith parametresiz aynı değeri verir', () {
      final b = a.copyWith(
        email: 'a@b.c',
        password: 'Sifre123',
        isPasswordVisible: true,
        errors: errors,
        isDirty: true,
        isSubmitting: true,
        failedAttempts: 2,
        lockedUntil: until,
        submitError: LoginError.unknown,
      );
      expect(b.copyWith(), b);
    });

    test('clearLockedUntil / clearSubmitError alanı null yapar ve verilen '
        'değere üstün gelir', () {
      final b = a.copyWith(
        lockedUntil: until,
        submitError: LoginError.suspended,
      );
      expect(b.copyWith(clearLockedUntil: true).lockedUntil, isNull);
      expect(b.copyWith(clearLockedUntil: true).submitError, b.submitError);
      expect(b.copyWith(clearSubmitError: true).submitError, isNull);
      expect(b.copyWith(clearSubmitError: true).lockedUntil, until);
      expect(
        b.copyWith(lockedUntil: until, clearLockedUntil: true).lockedUntil,
        isNull,
      );
      expect(
        b
            .copyWith(submitError: LoginError.network, clearSubmitError: true)
            .submitError,
        isNull,
      );
    });

    test('isLockedAt: hedef andan önce kilitli; hedef anda ve sonrasında '
        'değil; kilit yoksa değil', () {
      final locked = a.copyWith(lockedUntil: until);
      expect(
        locked.isLockedAt(until.subtract(const Duration(microseconds: 1))),
        isTrue,
      );
      expect(locked.isLockedAt(until), isFalse);
      expect(
        locked.isLockedAt(until.add(const Duration(seconds: 1))),
        isFalse,
      );
      expect(a.isLockedAt(until), isFalse);
    });

    test('enum sözlükleri PLAN §12.5 ile aynı', () {
      expect(LoginField.values.map((v) => v.name), ['email', 'password']);
      expect(LoginError.values.map((v) => v.name), [
        'invalidCredential',
        'suspended',
        'network',
        'unknown',
      ]);
      expect(LoginOutcome.values.map((v) => v.name), [
        'success',
        'locked',
        'invalid',
        'suspended',
        'failed',
      ]);
    });
  });
}
