// T-08 · ConflictException: transaction gövdesinden atılan beklenen-durum
// istisnası — iş kuralı reddi (ruleViolation) ve saf çakışma (conflict)
// ayrımı (PLAN §4.2, §10.1, §10.2, §10.3).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/repo_sources.dart';

/// Örnek sarmalayıcı: gövde [ConflictException] atarsa sonuç başarısızlığa
/// döner, istisna dışarı sızmaz. Çeviri kuralı istisnanın kendisindedir
/// ([ConflictException.error]); `FirestoreService.runTransaction` (T-10) aynı
/// alanı okur.
Future<FirestoreResult<T>> _guard<T>(Future<T> Function() body) async {
  try {
    return FirebaseSuccess(await body());
  } on ConflictException catch (e) {
    final code = e.code;
    return FirebaseFailure(
      e.error,
      detail: e.detail ?? (code == null ? null : FirestoreFailureDetail(code)),
    );
  }
}

void main() {
  group('T-08 · ConflictException', () {
    test('Exception arayüzünü uygular', () {
      expect(
        const ConflictException(FirestoreRuleCode.capacityFull),
        isA<Exception>(),
      );
    });

    test('kodu taşır; detail varsayılanı null', () {
      const exception = ConflictException(FirestoreRuleCode.capacityFull);

      expect(exception.code, FirestoreRuleCode.capacityFull);
      expect(exception.detail, isNull);
    });

    test('detail ek bilgiyi olduğu gibi taşır', () {
      final detail = FirestoreFailureDetail(
        FirestoreRuleCode.retryCooldown,
        retryAfter: DateTime.utc(2026, 10, 17),
      );
      final exception = ConflictException(
        FirestoreRuleCode.retryCooldown,
        detail: detail,
      );

      expect(exception.detail, same(detail));
    });

    test('her iş kuralı koduyla kurulabilir', () {
      for (final code in FirestoreRuleCode.values) {
        expect(ConflictException(code).code, code);
      }
    });

    test('const kurucu: aynı değerli iki sabit özdeş', () {
      const a = ConflictException(FirestoreRuleCode.eventEnded);
      const b = ConflictException(FirestoreRuleCode.eventEnded);

      expect(identical(a, b), isTrue);
    });

    test('toString kodu (ve varsa detail bilgisini) içerir', () {
      expect(
        const ConflictException(FirestoreRuleCode.notMember).toString(),
        'ConflictException(notMember)',
      );
      expect(
        const ConflictException(
          FirestoreRuleCode.capacityFull,
          detail: 7,
        ).toString(),
        'ConflictException(capacityFull, 7)',
      );
    });
  });

  group('T-08 · ConflictException · atma ve yakalama', () {
    test('throw ile atılır ve tipiyle yakalanır', () {
      expect(
        () => throw const ConflictException(FirestoreRuleCode.eventEnded),
        throwsA(
          isA<ConflictException>().having(
            (e) => e.code,
            'code',
            FirestoreRuleCode.eventEnded,
          ),
        ),
      );
    });

    test('on Exception dalı da yakalar (genel hata yolunda kaybolmaz)', () {
      Object? caught;
      try {
        throw const ConflictException(FirestoreRuleCode.announcementLimit);
      } on Exception catch (e) {
        caught = e;
      }

      expect(caught, isA<ConflictException>());
    });

    test(
      'gövde atarsa sarmalayıcı başarısızlığa çevirir; kod korunur',
      () async {
        final result = await _guard<int>(
          () async =>
              throw const ConflictException(FirestoreRuleCode.capacityFull),
        );

        expect(result.isSuccess, isFalse);
        expect(result.errorOrNull, FirestoreError.ruleViolation);
        expect(
          (result as FirebaseFailure<int, FirestoreError>).detail,
          const FirestoreFailureDetail(FirestoreRuleCode.capacityFull),
        );
      },
    );

    test('istisnadaki detail başarısızlığa aynen aktarılır', () async {
      final detail = FirestoreFailureDetail(
        FirestoreRuleCode.retryCooldown,
        retryAfter: DateTime.utc(2026, 10, 17, 12),
      );

      final result = await _guard<void>(
        () async => throw ConflictException(
          FirestoreRuleCode.retryCooldown,
          detail: detail,
        ),
      );

      expect(
        (result as FirebaseFailure<void, FirestoreError>).detail,
        same(detail),
      );
    });

    test('gövde atmazsa sonuç başarıdır', () async {
      final result = await _guard(() async => 5);

      expect(result.dataOrNull, 5);
    });
  });

  group('T-08 · ConflictException · conflict / ruleViolation ayrımı', () {
    test('varsayılan kurucu: her iş kuralı kodu ruleViolation hatasına '
        'çevrilir', () {
      for (final code in FirestoreRuleCode.values) {
        final exception = ConflictException(code);

        expect(exception.error, FirestoreError.ruleViolation, reason: '$code');
        expect(exception.code, code);
      }
    });

    test('ConflictException.conflict: kod taşımaz, conflict hatasına '
        'çevrilir', () {
      const exception = ConflictException.conflict();

      expect(exception, isA<Exception>());
      expect(exception.code, isNull);
      expect(exception.detail, isNull);
      expect(exception.error, FirestoreError.conflict);
    });

    test('ConflictException.conflict detail bilgisini olduğu gibi taşır', () {
      const exception = ConflictException.conflict(
        detail: 'pending bekleniyordu',
      );

      expect(exception.detail, 'pending bekleniyordu');
      expect(exception.error, FirestoreError.conflict);
    });

    test(
      'iki tür yalnızca bu iki hatayı üretir (başka FirestoreError yok)',
      () {
        final errors = {
          const ConflictException.conflict().error,
          for (final code in FirestoreRuleCode.values)
            ConflictException(code).error,
        };

        expect(errors, {FirestoreError.conflict, FirestoreError.ruleViolation});
      },
    );

    test('const kurucu: iki saf çakışma sabiti özdeş', () {
      const a = ConflictException.conflict();
      const b = ConflictException.conflict();

      expect(identical(a, b), isTrue);
    });

    test('toString saf çakışmada "conflict" etiketini (ve varsa detail '
        'bilgisini) içerir', () {
      expect(
        const ConflictException.conflict().toString(),
        'ConflictException(conflict)',
      );
      expect(
        const ConflictException.conflict(detail: 7).toString(),
        'ConflictException(conflict, 7)',
      );
    });

    test('saf çakışma sarmalayıcıda conflict başarısızlığına döner; detail '
        'üretilmez', () async {
      final result = await _guard<int>(
        () async => throw const ConflictException.conflict(),
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorOrNull, FirestoreError.conflict);
      expect((result as FirebaseFailure<int, FirestoreError>).detail, isNull);
    });

    test('iş kuralı reddi sarmalayıcıda ruleViolation başarısızlığına döner '
        '(saf çakışmayla karışmaz)', () async {
      final result = await _guard<int>(
        () async =>
            throw const ConflictException(FirestoreRuleCode.registrationClosed),
      );

      expect(result.errorOrNull, FirestoreError.ruleViolation);
      expect(
        (result as FirebaseFailure<int, FirestoreError>).detail,
        const FirestoreFailureDetail(FirestoreRuleCode.registrationClosed),
      );
    });

    test('ne conflict ne ruleViolation yeniden denenir: ikisi de SDK kodu '
        'değildir (fromCode üretmez)', () {
      for (final code in ['conflict', 'rule-violation', 'ruleViolation']) {
        expect(FirestoreError.fromCode(code), FirestoreError.unknown);
      }
    });

    test('PLAN §10.3 sözleşme satırı iki kurucuyu ve çeviri kuralını '
        'tanımlar', () {
      final row = readRepoFile('docs/PLAN.md')
          .split('\n')
          .singleWhere((line) => line.startsWith('| Transaction çakışması |'));

      expect(row, contains('`final FirestoreRuleCode? code;`'));
      expect(
        row,
        contains('`const ConflictException.conflict({this.detail})`'),
      );
      expect(row, contains('`FirestoreError get error`'));
      expect(row, contains('CD-129'));
    });
  });
}
