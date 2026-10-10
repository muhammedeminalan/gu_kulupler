// T-08 · FirestoreFailureDetail: alanlar, varsayılanlar, eşitlik ve
// FirebaseFailure.detail üzerinden taşınma (PLAN §4.2, §10.1).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

void main() {
  final retryAfter = DateTime.utc(2026, 10, 17, 9, 30);

  group('T-08 · FirestoreFailureDetail · alanlar', () {
    test('yalnızca kod: retryAfter ve position null', () {
      const detail = FirestoreFailureDetail(
        FirestoreRuleCode.applicationsClosed,
      );

      expect(detail.code, FirestoreRuleCode.applicationsClosed);
      expect(detail.retryAfter, isNull);
      expect(detail.position, isNull);
    });

    test('retryAfter bekleme süreli redde taşınır', () {
      final detail = FirestoreFailureDetail(
        FirestoreRuleCode.retryCooldown,
        retryAfter: retryAfter,
      );

      expect(detail.code, FirestoreRuleCode.retryCooldown);
      expect(detail.retryAfter, retryAfter);
      expect(detail.retryAfter!.isUtc, isTrue);
      expect(detail.position, isNull);
    });

    test('position sıra bilgisini taşır', () {
      const detail = FirestoreFailureDetail(
        FirestoreRuleCode.capacityFull,
        position: 3,
      );

      expect(detail.position, 3);
      expect(detail.retryAfter, isNull);
    });

    test('her iş kuralı koduyla kurulabilir', () {
      for (final code in FirestoreRuleCode.values) {
        expect(FirestoreFailureDetail(code).code, code);
      }
    });

    test('const kurucu: aynı değerli iki sabit özdeş', () {
      const a = FirestoreFailureDetail(FirestoreRuleCode.eventEnded);
      const b = FirestoreFailureDetail(FirestoreRuleCode.eventEnded);

      expect(identical(a, b), isTrue);
    });
  });

  group('T-08 · FirestoreFailureDetail · eşitlik', () {
    FirestoreFailureDetail build({
      FirestoreRuleCode code = FirestoreRuleCode.retryCooldown,
      DateTime? retry,
      int? position = 2,
    }) => FirestoreFailureDetail(
      code,
      retryAfter: retry ?? retryAfter,
      position: position,
    );

    test('tüm alanlar eşitse eşit ve aynı hashCode', () {
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
    });

    test('code farkı eşitliği bozar', () {
      expect(build(), isNot(build(code: FirestoreRuleCode.capacityFull)));
    });

    test('retryAfter farkı eşitliği bozar', () {
      expect(
        build(),
        isNot(build(retry: retryAfter.add(const Duration(seconds: 1)))),
      );
    });

    test('position farkı eşitliği bozar', () {
      expect(build(), isNot(build(position: 3)));
      expect(build(), isNot(build(position: null)));
    });

    test('props üç alanı da içerir', () {
      expect(build().props, [FirestoreRuleCode.retryCooldown, retryAfter, 2]);
    });

    test('toString alan değerlerini gösterir', () {
      expect(
        const FirestoreFailureDetail(
          FirestoreRuleCode.capacityFull,
          position: 4,
        ).toString(),
        'FirestoreFailureDetail(FirestoreRuleCode.capacityFull, null, 4)',
      );
    });
  });

  group('T-08 · FirestoreFailureDetail · FirebaseFailure.detail', () {
    test('ruleViolation başarısızlığından desenle geri okunur', () {
      final FirestoreResult<void> result = FirebaseFailure(
        FirestoreError.ruleViolation,
        detail: FirestoreFailureDetail(
          FirestoreRuleCode.retryCooldown,
          retryAfter: retryAfter,
        ),
      );

      final read = switch (result) {
        FirebaseFailure(
          error: FirestoreError.ruleViolation,
          detail: FirestoreFailureDetail(:final code, :final retryAfter),
        ) =>
          (code, retryAfter),
        _ => null,
      };

      expect(read, (FirestoreRuleCode.retryCooldown, retryAfter));
    });

    test('detail başka tipteyse desen eşleşmez (Object? alan)', () {
      const FirestoreResult<void> result = FirebaseFailure(
        FirestoreError.ruleViolation,
        detail: 'serbest metin',
      );

      final matched = switch (result) {
        FirebaseFailure(detail: FirestoreFailureDetail()) => true,
        _ => false,
      };

      expect(matched, isFalse);
    });
  });
}
