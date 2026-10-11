// AUT-02 · RegisterState: props / copyWith tüm alanlar (PLAN §12.16) ve
// türetilmiş değerler (şifre kuralları, güç, ilk hatalı alan).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/auth/provider/register_state.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';

RegisterState _withPassword(String password) =>
    RegisterState(password: password);

void main() {
  group('AUT-02 · RegisterState', () {
    const a = RegisterState();
    const errors = {RegisterField.name: FormFieldError.required};

    test('props tüm alanları içerir (alan sayısı = 10)', () {
      expect(a.props.length, 10);
    });

    test('varsayılanlar: boş form', () {
      expect(a.name, isEmpty);
      expect(a.email, isEmpty);
      expect(a.password, isEmpty);
      expect(a.passwordConfirm, isEmpty);
      expect(a.isPasswordVisible, isFalse);
      expect(a.acceptedLegal, isFalse);
      expect(a.errors, isEmpty);
      expect(a.isDirty, isFalse);
      expect(a.isSubmitting, isFalse);
      expect(a.submitError, isNull);
    });

    test('copyWith her alanı taşır ve eşitliği bozar', () {
      expect(a.copyWith(name: 'Ayşe').name, 'Ayşe');
      expect(a.copyWith(name: 'Ayşe'), isNot(a));
      expect(a.copyWith(email: 'a@b.c').email, 'a@b.c');
      expect(a.copyWith(email: 'a@b.c'), isNot(a));
      expect(a.copyWith(password: 'p').password, 'p');
      expect(a.copyWith(password: 'p'), isNot(a));
      expect(a.copyWith(passwordConfirm: 'p').passwordConfirm, 'p');
      expect(a.copyWith(passwordConfirm: 'p'), isNot(a));
      expect(a.copyWith(isPasswordVisible: true).isPasswordVisible, isTrue);
      expect(a.copyWith(isPasswordVisible: true), isNot(a));
      expect(a.copyWith(acceptedLegal: true).acceptedLegal, isTrue);
      expect(a.copyWith(acceptedLegal: true), isNot(a));
      expect(a.copyWith(errors: errors).errors, errors);
      expect(a.copyWith(errors: errors), isNot(a));
      expect(a.copyWith(isDirty: true).isDirty, isTrue);
      expect(a.copyWith(isDirty: true), isNot(a));
      expect(a.copyWith(isSubmitting: true).isSubmitting, isTrue);
      expect(a.copyWith(isSubmitting: true), isNot(a));
      expect(
        a.copyWith(submitError: RegisterError.network).submitError,
        RegisterError.network,
      );
      expect(a.copyWith(submitError: RegisterError.network), isNot(a));
    });

    test('copyWith parametresiz aynı değeri verir', () {
      final b = a.copyWith(
        name: 'Ayşe Yılmaz',
        email: 'ayse@ogr.gumushane.edu.tr',
        password: 'Parola123',
        passwordConfirm: 'Parola123',
        isPasswordVisible: true,
        acceptedLegal: true,
        errors: errors,
        isDirty: true,
        isSubmitting: true,
        submitError: RegisterError.emailInUse,
      );
      expect(b.copyWith(), b);
    });

    test('clearSubmitError hatayı siler; verilmezse hata korunur', () {
      final b = a.copyWith(submitError: RegisterError.unknown);
      expect(b.copyWith(name: 'x').submitError, RegisterError.unknown);
      expect(b.copyWith(clearSubmitError: true).submitError, isNull);
      expect(
        b
            .copyWith(
              clearSubmitError: true,
              submitError: RegisterError.network,
            )
            .submitError,
        isNull,
      );
    });

    test('errors içeriğe göre karşılaştırılır', () {
      expect(
        a.copyWith(errors: {RegisterField.name: FormFieldError.required}),
        a.copyWith(errors: {RegisterField.name: FormFieldError.required}),
      );
      expect(
        a.copyWith(errors: {RegisterField.name: FormFieldError.required}),
        isNot(
          a.copyWith(errors: {RegisterField.name: FormFieldError.tooShort}),
        ),
      );
    });
  });

  group('AUT-02 · RegisterState · şifre kuralları', () {
    test('hasMinLength: en az 8 karakter (kod noktası)', () {
      expect(_withPassword('').hasMinLength, isFalse);
      expect(_withPassword('1234567').hasMinLength, isFalse);
      expect(_withPassword('12345678').hasMinLength, isTrue);
      // UTF-16'da 2 birim tutan karakter tek karakter sayılır.
      expect(_withPassword('😀😀😀😀').hasMinLength, isFalse);
    });

    test('hasUppercase: Türkçe büyük harfler dahil', () {
      expect(_withPassword('abc1!').hasUppercase, isFalse);
      expect(_withPassword('abC').hasUppercase, isTrue);
      for (final letter in ['Ğ', 'Ü', 'Ş', 'İ', 'Ö', 'Ç']) {
        expect(_withPassword(letter).hasUppercase, isTrue, reason: letter);
      }
      expect(_withPassword('ğüşiöçı').hasUppercase, isFalse);
    });

    test('hasDigit', () {
      expect(_withPassword('abcDEF').hasDigit, isFalse);
      expect(_withPassword('abc4').hasDigit, isTrue);
    });

    test('passwordStrength: karşılanan ölçüt sayısı (0 – 4)', () {
      expect(_withPassword('').passwordStrength, 0);
      expect(_withPassword('abc').passwordStrength, 0);
      expect(_withPassword('abcdefgh').passwordStrength, 1);
      expect(_withPassword('Abcdefgh').passwordStrength, 2);
      expect(_withPassword('Abcdefg1').passwordStrength, 3);
      expect(_withPassword('Abcdef1!').passwordStrength, 4);
      expect(
        _withPassword('Abcdef1!').passwordStrength,
        RegisterState.passwordStrengthMax,
      );
      // Harf ve rakam dışı karakter tek başına bir ölçüttür.
      expect(_withPassword('!').passwordStrength, 1);
      // Türkçe küçük harf "özel karakter" sayılmaz.
      expect(_withPassword('ğş').passwordStrength, 0);
    });

    test('üç kural birlikte = Limits.passwordPattern', () {
      final policy = RegExp(Limits.passwordPattern, unicode: true);
      for (final password in [
        '',
        'abcdefgh',
        'Abcdefgh',
        'abcdefg1',
        'Abcdefg1',
        'ABC1',
        'Şifrem12',
        'şifrem123',
        'Abcdef1!',
        '12345678',
      ]) {
        final state = _withPassword(password);
        expect(
          state.hasMinLength && state.hasUppercase && state.hasDigit,
          policy.hasMatch(password),
          reason: password,
        );
      }
    });
  });

  group('AUT-02 · RegisterState · firstInvalidField', () {
    const a = RegisterState();

    test('hata yoksa null', () {
      expect(a.firstInvalidField, isNull);
      expect(
        a.copyWith(submitError: RegisterError.network).firstInvalidField,
        isNull,
      );
    });

    test('form sırasıyla ilk hatalı alan', () {
      expect(
        a
            .copyWith(
              errors: {
                RegisterField.legal: FormFieldError.consentMissing,
                RegisterField.passwordConfirm: FormFieldError.passwordMismatch,
                RegisterField.email: FormFieldError.invalidEmail,
              },
            )
            .firstInvalidField,
        RegisterField.email,
      );
      expect(
        a
            .copyWith(
              errors: {RegisterField.legal: FormFieldError.consentMissing},
            )
            .firstInvalidField,
        RegisterField.legal,
      );
    });

    test('kayıtlı e-posta hatası e-posta alanına aittir', () {
      expect(
        a.copyWith(submitError: RegisterError.emailInUse).firstInvalidField,
        RegisterField.email,
      );
      expect(
        a
            .copyWith(
              submitError: RegisterError.emailInUse,
              errors: {RegisterField.name: FormFieldError.required},
            )
            .firstInvalidField,
        RegisterField.name,
      );
      expect(
        a
            .copyWith(
              submitError: RegisterError.emailInUse,
              errors: {RegisterField.password: FormFieldError.passwordWeak},
            )
            .firstInvalidField,
        RegisterField.email,
      );
    });
  });
}
