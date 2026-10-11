// T-13 · FormValidationMixin: form ViewModel'lerinin ortak doğrulama parçası
// (PLAN §12.1; design-analysis §G) — kural tablosu, `FieldError` eşlemesi, ilk
// hatalı alan ve gönderim kilidi.
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/mixin/form_validation_mixin.dart';

enum _Field { name, email, password, confirm }

final class _Form with ProjectDependencyMixin, FormValidationMixin<_Field> {
  bool isSubmitting = false;
  final List<bool> lockChanges = <bool>[];

  void setSubmitting({required bool isSubmitting}) {
    this.isSubmitting = isSubmitting;
    lockChanges.add(isSubmitting);
  }
}

void main() {
  late _Form form;

  setUp(() => form = _Form());

  group('T-13 · FormValidationMixin · kurallar', () {
    test('emailError: zorunlu → biçim → izinli alan adı (kırpılarak)', () {
      expect(form.emailError(''), FormFieldError.required);
      expect(form.emailError('   '), FormFieldError.required);
      expect(form.emailError('a@b'), FormFieldError.invalidEmail);
      expect(form.emailError('ayse@'), FormFieldError.invalidEmail);
      expect(form.emailError('x@gmail.com'), FormFieldError.domainNotAllowed);
      for (final domain in EmailDomainPolicy.allowedDomains) {
        expect(form.emailError('ad.soyad@$domain'), isNull, reason: domain);
        expect(form.emailError('  ad.soyad@$domain '), isNull, reason: domain);
      }
    });

    test('passwordError: Limits.passwordPattern (8 karakter + büyük harf + '
        'rakam); boş şifre de zayıftır', () {
      expect(form.passwordError(''), FormFieldError.passwordWeak);
      expect(form.passwordError('sifre1234'), FormFieldError.passwordWeak);
      expect(form.passwordError('SifreSifre'), FormFieldError.passwordWeak);
      expect(form.passwordError('Sifre12'), FormFieldError.passwordWeak);
      expect(form.passwordError('Sifre123'), isNull);
      // Türkçe büyük harf de sayılır.
      expect(form.passwordError('şifreŞ123'), isNull);
    });

    test('confirmError: tekrar şifreyle aynı olmalı', () {
      expect(form.confirmError('Sifre123', 'Sifre123'), isNull);
      expect(
        form.confirmError('Sifre123', 'Sifre124'),
        FormFieldError.passwordMismatch,
      );
      expect(
        form.confirmError('Sifre123', ''),
        FormFieldError.passwordMismatch,
      );
      expect(form.confirmError('', ''), isNull);
    });

    test('lengthError: boş → zorunlu (alt sınır varsa), kısa, uzun; kırpılmış '
        'metin ölçülür', () {
      expect(form.lengthError('', min: 2, max: 60), FormFieldError.required);
      expect(form.lengthError('   ', min: 2, max: 60), FormFieldError.required);
      expect(form.lengthError('', min: 0, max: 140), isNull);
      expect(form.lengthError(' a ', min: 2, max: 60), FormFieldError.tooShort);
      expect(form.lengthError('ab', min: 2, max: 60), isNull);
      expect(form.lengthError('a' * 140, min: 0, max: 140), isNull);
      expect(
        form.lengthError('a' * 141, min: 0, max: 140),
        FormFieldError.tooLong,
      );
      // Uzunluk kod birimiyle değil karakterle ölçülür.
      expect(form.lengthError('😀😀', min: 2, max: 2), isNull);
    });

    test('fromFieldError: gu_data alan hatasının form karşılığı', () {
      expect(form.fromFieldError(null), isNull);
      expect(form.fromFieldError(FieldError.empty), FormFieldError.required);
      expect(form.fromFieldError(FieldError.tooShort), FormFieldError.tooShort);
      expect(form.fromFieldError(FieldError.tooLong), FormFieldError.tooLong);
      expect(
        form.fromFieldError(FieldError.invalidFormat),
        FormFieldError.invalidFormat,
      );
      expect(
        form.fromFieldError(FieldError.outOfRange),
        FormFieldError.limitExceeded,
      );
      expect(FieldError.values, hasLength(5));
    });
  });

  group('T-13 · FormValidationMixin · hata haritası', () {
    test('validateFields yalnızca hata dönen alanları, kural sırasıyla toplar; '
        'her kural bir kez çalışır', () {
      final ran = <_Field>[];
      FormFieldError? Function() rule(_Field field, FormFieldError? result) =>
          () {
            ran.add(field);
            return result;
          };

      final errors = form.validateFields({
        _Field.name: rule(_Field.name, null),
        _Field.email: rule(_Field.email, FormFieldError.invalidEmail),
        _Field.password: rule(_Field.password, null),
        _Field.confirm: rule(_Field.confirm, FormFieldError.passwordMismatch),
      });

      expect(errors, {
        _Field.email: FormFieldError.invalidEmail,
        _Field.confirm: FormFieldError.passwordMismatch,
      });
      expect(errors.keys.toList(), [_Field.email, _Field.confirm]);
      expect(ran, _Field.values);
      expect(form.validateFields({}), isEmpty);
    });

    test('firstErrorField verilen sıradaki ilk hatalı alandır', () {
      const errors = {
        _Field.confirm: FormFieldError.passwordMismatch,
        _Field.email: FormFieldError.required,
      };
      expect(form.firstErrorField(errors, _Field.values), _Field.email);
      expect(
        form.firstErrorField(errors, const [_Field.confirm, _Field.email]),
        _Field.confirm,
      );
      expect(form.firstErrorField(errors, const [_Field.name]), isNull);
      expect(form.firstErrorField(const {}, _Field.values), isNull);
    });
  });

  group('T-13 · FormValidationMixin · gönderim kilidi', () {
    test('gövde çalışırken kilit kurulur, bitince kalkar', () async {
      var ran = 0;
      await form.guardedSubmit(
        isSubmitting: form.isSubmitting,
        setSubmitting: form.setSubmitting,
        body: () async {
          expect(form.isSubmitting, isTrue);
          ran++;
        },
      );
      expect(ran, 1);
      expect(form.lockChanges, [true, false]);
      expect(form.isSubmitting, isFalse);
    });

    test(
      'süren gönderim varken gelen çağrı yok sayılır (çift dokunma)',
      () async {
        var ran = 0;
        Future<void> submit() => form.guardedSubmit(
          isSubmitting: form.isSubmitting,
          setSubmitting: form.setSubmitting,
          body: () async {
            ran++;
            await Future<void>.delayed(Duration.zero);
          },
        );

        await Future.wait([submit(), submit()]);
        expect(ran, 1);
        expect(form.lockChanges, [true, false]);
      },
    );

    test(
      'gövde fırlatırsa kilit yine kalkar ve hata çağırana ulaşır',
      () async {
        await expectLater(
          form.guardedSubmit(
            isSubmitting: form.isSubmitting,
            setSubmitting: form.setSubmitting,
            body: () async => throw StateError('gönderilemedi'),
          ),
          throwsStateError,
        );
        expect(form.isSubmitting, isFalse);
        expect(form.lockChanges, [true, false]);
      },
    );
  });
}
