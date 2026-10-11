// T-12 · AuthFailureDetail: alanlar, eşitlik ve FirebaseFailure.detail
// üzerinden taşınma (PLAN §10.1 `lockedOut` / `resendCooldown` + retryAfter).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

void main() {
  final retryAfter = DateTime.utc(2026, 10, 10, 9, 0, 30);

  group('T-12 · AuthFailureDetail', () {
    test('hedef anı ve kalan süreyi taşır', () {
      final detail = AuthFailureDetail(
        retryAfter: retryAfter,
        remaining: const Duration(seconds: 30),
      );

      expect(detail.retryAfter, retryAfter);
      expect(detail.retryAfter.isUtc, isTrue);
      expect(detail.remaining, const Duration(seconds: 30));
    });

    test('her alan eşitliğe girer; props 2 alan taşır', () {
      final detail = AuthFailureDetail(
        retryAfter: retryAfter,
        remaining: const Duration(seconds: 30),
      );

      expect(
        detail,
        AuthFailureDetail(
          retryAfter: retryAfter,
          remaining: const Duration(seconds: 30),
        ),
      );
      expect(detail.props, hasLength(2));
      expect(
        detail,
        isNot(
          AuthFailureDetail(
            retryAfter: retryAfter.add(const Duration(seconds: 1)),
            remaining: const Duration(seconds: 30),
          ),
        ),
      );
      expect(
        detail,
        isNot(
          AuthFailureDetail(
            retryAfter: retryAfter,
            remaining: const Duration(seconds: 29),
          ),
        ),
      );
    });

    test('FirebaseFailure.detail üzerinden taşınır ve metne yansır', () {
      final detail = AuthFailureDetail(
        retryAfter: retryAfter,
        remaining: const Duration(seconds: 30),
      );

      final AuthResult<void> failure = FirebaseFailure(
        AuthError.lockedOut,
        detail: detail,
      );

      expect((failure as FirebaseFailure).detail, detail);
      expect('$failure', contains('AuthFailureDetail'));
    });
  });
}
