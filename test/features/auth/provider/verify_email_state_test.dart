// AUT-03 · VerifyEmailState: varsayılanlar, `props` / `copyWith` tüm alanlar,
// beklemenin kalan süresi (PLAN §12.5).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/features/auth/provider/verify_email_state.dart';

void main() {
  final now = DateTime.utc(2026, 10, 12, 16, 30);
  final full = VerifyEmailState(
    email: 'ayse.demir@ogr.gumushane.edu.tr',
    isChecking: true,
    isResending: true,
    resendAvailableAt: now.add(const Duration(seconds: 60)),
    lastCheckWasUnverified: true,
    isVerified: true,
    isError: true,
  );

  group('AUT-03 · VerifyEmailState', () {
    test('varsayılan: adres boş, bekleme yok, bayraklar kapalı', () {
      const state = VerifyEmailState();
      expect(state.email, '');
      expect(state.isChecking, isFalse);
      expect(state.isResending, isFalse);
      expect(state.resendAvailableAt, isNull);
      expect(state.lastCheckWasUnverified, isFalse);
      expect(state.isVerified, isFalse);
      expect(state.isError, isFalse);
    });

    test('props tüm alanları içerir (7 alan)', () {
      expect(full.props, [
        'ayse.demir@ogr.gumushane.edu.tr',
        true,
        true,
        now.add(const Duration(seconds: 60)),
        true,
        true,
        true,
      ]);
      expect(const VerifyEmailState(), const VerifyEmailState());
    });

    test('copyWith: her alan tek başına değişir, diğerleri korunur', () {
      const base = VerifyEmailState();
      final until = now.add(const Duration(seconds: 42));
      final variants = <VerifyEmailState>[
        base.copyWith(email: 'a@ogr.gumushane.edu.tr'),
        base.copyWith(isChecking: true),
        base.copyWith(isResending: true),
        base.copyWith(resendAvailableAt: until),
        base.copyWith(lastCheckWasUnverified: true),
        base.copyWith(isVerified: true),
        base.copyWith(isError: true),
      ];
      expect(variants[0].email, 'a@ogr.gumushane.edu.tr');
      expect(variants[1].isChecking, isTrue);
      expect(variants[2].isResending, isTrue);
      expect(variants[3].resendAvailableAt, until);
      expect(variants[4].lastCheckWasUnverified, isTrue);
      expect(variants[5].isVerified, isTrue);
      expect(variants[6].isError, isTrue);
      // Her kopya tabandan ve diğerlerinden farklıdır (tek alan değişti).
      expect({base, ...variants}, hasLength(variants.length + 1));
    });

    test('copyWith: argümansız kopya eşittir; bayraklar geri kapanabilir', () {
      expect(full.copyWith(), full);
      final cleared = full.copyWith(
        isChecking: false,
        isResending: false,
        lastCheckWasUnverified: false,
        isVerified: false,
        isError: false,
      );
      expect(
        cleared,
        VerifyEmailState(
          email: full.email,
          resendAvailableAt: full.resendAvailableAt,
        ),
      );
    });

    test('copyWith: clearResendAvailableAt beklemeyi kaldırır ve verilen '
        'değere üstün gelir', () {
      expect(
        full.copyWith(clearResendAvailableAt: true).resendAvailableAt,
        isNull,
      );
      expect(
        full
            .copyWith(resendAvailableAt: now, clearResendAvailableAt: true)
            .resendAvailableAt,
        isNull,
      );
      // `null` değer "değiştirme" demektir.
      expect(full.copyWith().resendAvailableAt, full.resendAvailableAt);
    });

    test('remainingResend: bekleme yoksa sıfır; sürerken kalan; dolunca sıfır '
        '(eksi olmaz)', () {
      expect(const VerifyEmailState().remainingResend(now), Duration.zero);
      expect(full.remainingResend(now), const Duration(seconds: 60));
      expect(
        full.remainingResend(now.add(const Duration(seconds: 18))),
        const Duration(seconds: 42),
      );
      expect(
        full.remainingResend(now.add(const Duration(seconds: 60))),
        Duration.zero,
      );
      expect(
        full.remainingResend(now.add(const Duration(minutes: 5))),
        Duration.zero,
      );
    });
  });
}
