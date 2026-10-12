// AUT-04 · ResetPasswordState: props / copyWith tüm alanlar, temizleme
// bayrağı, gönderilen adres ve yeniden gönderim beklemesi türetimi (PLAN
// §12.5, §12.16).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/features/auth/provider/reset_password_state.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';

void main() {
  group('AUT-04 · ResetPasswordState', () {
    const a = ResetPasswordState();
    final at = DateTime.utc(2026, 10, 12, 16, 31);
    const errors = {ResetField.email: FormFieldError.required};

    test('props tüm alanları içerir (alan sayısı = 6)', () {
      expect(a.props.length, 6);
    });

    test('varsayılanlar: boş form, gönderilmemiş, hata ve bekleme yok', () {
      expect(a.email, isEmpty);
      expect(a.errors, isEmpty);
      expect(a.isSubmitting, isFalse);
      expect(a.isSent, isFalse);
      expect(a.resendAvailableAt, isNull);
      expect(a.submitError, isNull);
    });

    test('copyWith her alanı taşır ve eşitliği bozar', () {
      expect(a.copyWith(email: 'a@b.c').email, 'a@b.c');
      expect(a.copyWith(email: 'a@b.c'), isNot(a));
      expect(a.copyWith(errors: errors).errors, errors);
      expect(a.copyWith(errors: errors), isNot(a));
      expect(a.copyWith(isSubmitting: true).isSubmitting, isTrue);
      expect(a.copyWith(isSubmitting: true), isNot(a));
      expect(a.copyWith(isSent: true).isSent, isTrue);
      expect(a.copyWith(isSent: true), isNot(a));
      expect(a.copyWith(resendAvailableAt: at).resendAvailableAt, at);
      expect(a.copyWith(resendAvailableAt: at), isNot(a));
      expect(
        a.copyWith(submitError: SubmitError.network).submitError,
        SubmitError.network,
      );
      expect(a.copyWith(submitError: SubmitError.network), isNot(a));
    });

    test('copyWith parametresiz aynı değeri verir', () {
      final b = a.copyWith(
        email: 'a@b.c',
        errors: errors,
        isSubmitting: true,
        isSent: true,
        resendAvailableAt: at,
        submitError: SubmitError.unknown,
      );
      expect(b.copyWith(), b);
      expect(b.copyWith().props, [
        'a@b.c',
        errors,
        true,
        true,
        at,
        SubmitError.unknown,
      ]);
    });

    test('clearSubmitError hatayı siler ve verilen değere üstün gelir', () {
      final b = a.copyWith(submitError: SubmitError.unknown);
      expect(b.copyWith(clearSubmitError: true).submitError, isNull);
      expect(
        b
            .copyWith(submitError: SubmitError.network, clearSubmitError: true)
            .submitError,
        isNull,
      );
      // Diğer alanlara dokunmaz.
      final c = b.copyWith(email: 'a@b.c', isSent: true);
      expect(
        c.copyWith(clearSubmitError: true),
        a.copyWith(email: 'a@b.c', isSent: true),
      );
    });

    test('eşit alanlar eşit state verir', () {
      expect(
        a.copyWith(email: 'a@b.c', resendAvailableAt: at),
        a.copyWith(email: 'a@b.c', resendAvailableAt: at),
      );
    });

    test('sentEmail: adres kırpılır', () {
      expect(a.sentEmail, isEmpty);
      expect(a.copyWith(email: '  a@b.c \n').sentEmail, 'a@b.c');
    });

    test('remainingResend: bekleme yokken ve dolunca sıfır; sürerken kalan '
        'süre', () {
      expect(a.remainingResend(at), Duration.zero);
      final b = a.copyWith(resendAvailableAt: at);
      expect(
        b.remainingResend(at.subtract(const Duration(seconds: 60))),
        const Duration(seconds: 60),
      );
      expect(
        b.remainingResend(at.subtract(const Duration(milliseconds: 1))),
        const Duration(milliseconds: 1),
      );
      expect(b.remainingResend(at), Duration.zero);
      expect(
        b.remainingResend(at.add(const Duration(minutes: 5))),
        Duration.zero,
      );
    });
  });
}
