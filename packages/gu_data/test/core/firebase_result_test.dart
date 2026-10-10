// T-08 · FirebaseResult: sealed sonuç tipi, desen eşleme, fold / map ve
// typedef'ler (PLAN §10.1, D-34).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

/// CLAUDE.md §2 kalıbı: `default` dalı olmayan, iki alt tipi de ele alan
/// `switch`. Üçüncü bir alt tip eklenirse bu fonksiyon **derlenmez**.
String _describe(FirestoreResult<int> result) => switch (result) {
  FirebaseSuccess(:final data) => 'ok:$data',
  FirebaseFailure(:final error) => 'fail:${error.name}',
};

FirestoreResult<int> _firestoreOk(int value) => FirebaseSuccess(value);

FirestoreResult<int> _firestoreFail(
  FirestoreError error, {
  String? message,
  Object? detail,
}) => FirebaseFailure(error, message: message, detail: detail);

StorageResult<String> _storageOk(String path) => FirebaseSuccess(path);

AuthResult<String> _authFail(AuthError error) => FirebaseFailure(error);

void main() {
  group('T-08 · FirebaseResult · FirebaseSuccess', () {
    test('veriyi taşır; isSuccess true, errorOrNull null', () {
      final result = _firestoreOk(42);

      expect(result, isA<FirebaseSuccess<int, FirestoreError>>());
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, 42);
      expect(result.errorOrNull, isNull);
    });

    test('const kurucu: aynı değerli iki sabit özdeş', () {
      const a = FirebaseSuccess<int, FirestoreError>(1);
      const b = FirebaseSuccess<int, FirestoreError>(1);

      expect(identical(a, b), isTrue);
      expect(a.data, 1);
    });

    test('null olabilen T: Success(null) başarıdır, dataOrNull null', () {
      const FirebaseResult<String?, FirestoreError> result = FirebaseSuccess(
        null,
      );

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, isNull);
      expect(result.errorOrNull, isNull);
      expect(result.fold((data) => 'ok:$data', (_, _) => 'fail'), 'ok:null');
    });

    test('void sonuç: Success(null) başarıdır', () {
      const FirebaseResult<void, FirestoreError> result = FirebaseSuccess(null);

      expect(result.isSuccess, isTrue);
      expect(result.errorOrNull, isNull);
    });

    test('toString veriyi içerir', () {
      expect(_firestoreOk(7).toString(), 'FirebaseSuccess(7)');
    });
  });

  group('T-08 · FirebaseResult · FirebaseFailure', () {
    test('hatayı taşır; isSuccess false, dataOrNull null', () {
      final result = _firestoreFail(FirestoreError.notFound);

      expect(result, isA<FirebaseFailure<int, FirestoreError>>());
      expect(result.isSuccess, isFalse);
      expect(result.dataOrNull, isNull);
      expect(result.errorOrNull, FirestoreError.notFound);
    });

    test('message ve detail varsayılanı null', () {
      const failure = FirebaseFailure<int, FirestoreError>(
        FirestoreError.unknown,
      );

      expect(failure.error, FirestoreError.unknown);
      expect(failure.message, isNull);
      expect(failure.detail, isNull);
    });

    test('message (ham SDK mesajı) ve detail ayrı alanlarda taşınır', () {
      final retryAfter = DateTime.utc(2026, 10, 17, 9);
      final detail = FirestoreFailureDetail(
        FirestoreRuleCode.retryCooldown,
        retryAfter: retryAfter,
      );
      final failure = FirebaseFailure<int, FirestoreError>(
        FirestoreError.ruleViolation,
        message: 'PERMISSION_DENIED: Missing or insufficient permissions.',
        detail: detail,
      );

      expect(failure.error, FirestoreError.ruleViolation);
      expect(
        failure.message,
        'PERMISSION_DENIED: Missing or insufficient permissions.',
      );
      expect(failure.detail, same(detail));
      expect(
        (failure.detail! as FirestoreFailureDetail).retryAfter,
        retryAfter,
      );
    });

    test('const kurucu: aynı değerli iki sabit özdeş', () {
      const a = FirebaseFailure<int, FirestoreError>(
        FirestoreError.timeout,
        message: 'm',
      );
      const b = FirebaseFailure<int, FirestoreError>(
        FirestoreError.timeout,
        message: 'm',
      );

      expect(identical(a, b), isTrue);
    });

    test('toString hata, mesaj ve ek bilgiyi içerir', () {
      expect(
        _firestoreFail(FirestoreError.notFound).toString(),
        'FirebaseFailure(FirestoreError.notFound)',
      );
      expect(
        _firestoreFail(
          FirestoreError.conflict,
          message: 'm',
          detail: 3,
        ).toString(),
        'FirebaseFailure(FirestoreError.conflict, message: m, detail: 3)',
      );
    });
  });

  group('T-08 · FirebaseResult · desen eşleme', () {
    test('default dalı olmayan switch iki alt tipi de ele alır', () {
      expect(_describe(_firestoreOk(3)), 'ok:3');
      expect(
        _describe(_firestoreFail(FirestoreError.permissionDenied)),
        'fail:permissionDenied',
      );
    });

    test('her FirestoreError değeri Failure dalına düşer', () {
      for (final error in FirestoreError.values) {
        expect(_describe(_firestoreFail(error)), 'fail:${error.name}');
      }
    });

    test('Failure deseni error, message ve detail alanlarını açar', () {
      final result = _firestoreFail(
        FirestoreError.ruleViolation,
        message: 'ham',
        detail: const FirestoreFailureDetail(FirestoreRuleCode.capacityFull),
      );

      final opened = switch (result) {
        FirebaseSuccess() => null,
        FirebaseFailure(:final error, :final message, :final detail) => (
          error,
          message,
          detail,
        ),
      };

      expect(opened, (
        FirestoreError.ruleViolation,
        'ham',
        const FirestoreFailureDetail(FirestoreRuleCode.capacityFull),
      ));
    });

    test('iç içe desen: belirli hata ve iş kuralı kodu ayrıştırılır', () {
      String route(FirestoreResult<int> result) => switch (result) {
        FirebaseSuccess() => 'ok',
        FirebaseFailure(
          error: FirestoreError.ruleViolation,
          detail: FirestoreFailureDetail(code: FirestoreRuleCode.capacityFull),
        ) =>
          'DLG-15',
        FirebaseFailure(error: FirestoreError.notFound) => 'SYS-04',
        FirebaseFailure() => 'SYS-02',
      };

      expect(route(_firestoreOk(1)), 'ok');
      expect(
        route(
          _firestoreFail(
            FirestoreError.ruleViolation,
            detail: const FirestoreFailureDetail(
              FirestoreRuleCode.capacityFull,
            ),
          ),
        ),
        'DLG-15',
      );
      expect(route(_firestoreFail(FirestoreError.notFound)), 'SYS-04');
      expect(
        route(
          _firestoreFail(
            FirestoreError.ruleViolation,
            detail: const FirestoreFailureDetail(FirestoreRuleCode.eventEnded),
          ),
        ),
        'SYS-02',
      );
      expect(route(_firestoreFail(FirestoreError.ruleViolation)), 'SYS-02');
    });

    test('is denetimi sonrası alt tipe yükseltilir', () {
      final result = _firestoreOk(9);

      if (result is! FirebaseSuccess<int, FirestoreError>) {
        fail('başarı bekleniyordu');
      }
      expect(result.data, 9);
    });
  });

  group('T-08 · FirebaseResult · fold', () {
    test('başarıda yalnızca onSuccess çağrılır', () {
      var failureCalls = 0;

      final folded = _firestoreOk(5).fold((data) => data * 2, (_, _) {
        failureCalls++;
        return -1;
      });

      expect(folded, 10);
      expect(failureCalls, 0);
    });

    test('başarısızlıkta yalnızca onFailure çağrılır; hata ve mesaj gelir', () {
      var successCalls = 0;

      final folded =
          _firestoreFail(
            FirestoreError.unavailable,
            message: 'UNAVAILABLE',
          ).fold((data) {
            successCalls++;
            return 'ok';
          }, (error, message) => '${error.name}|$message');

      expect(folded, 'unavailable|UNAVAILABLE');
      expect(successCalls, 0);
    });

    test('mesajsız başarısızlıkta onFailure null mesaj alır', () {
      final folded = _firestoreFail(
        FirestoreError.timeout,
      ).fold<Object?>((_) => 'ok', (_, message) => message);

      expect(folded, isNull);
    });

    test('dönüş tipi çağıranın seçtiği R tipidir', () {
      final asBool = _firestoreOk(1).fold((_) => true, (_, _) => false);
      final asList = _firestoreFail(
        FirestoreError.parse,
      ).fold((data) => [data], (_, _) => <int>[]);

      expect(asBool, isTrue);
      expect(asList, isEmpty);
    });
  });

  group('T-08 · FirebaseResult · map', () {
    test('başarı verisini dönüştürür ve veri tipini değiştirir', () {
      final mapped = _firestoreOk(21).map((data) => 'n=${data * 2}');

      expect(mapped, isA<FirebaseSuccess<String, FirestoreError>>());
      expect(mapped.dataOrNull, 'n=42');
      expect(mapped.errorOrNull, isNull);
    });

    test('başarısızlığı hata, mesaj ve detail ile olduğu gibi taşır', () {
      const detail = FirestoreFailureDetail(
        FirestoreRuleCode.capacityFull,
        position: 4,
      );
      var calls = 0;

      final mapped =
          _firestoreFail(
            FirestoreError.ruleViolation,
            message: 'ham mesaj',
            detail: detail,
          ).map((data) {
            calls++;
            return '$data';
          });

      expect(calls, 0, reason: 'başarısızlıkta dönüştürücü çağrılmaz');
      expect(mapped, isA<FirebaseFailure<String, FirestoreError>>());
      final failure = mapped as FirebaseFailure<String, FirestoreError>;
      expect(failure.error, FirestoreError.ruleViolation);
      expect(failure.message, 'ham mesaj');
      expect(failure.detail, same(detail));
      expect(failure.dataOrNull, isNull);
    });

    test('zincirlenebilir', () {
      final mapped = _firestoreOk(
        2,
      ).map((data) => data + 1).map((data) => data * 10).map((data) => '$data');

      expect(mapped.dataOrNull, '30');
    });

    test('başarısızlık zincir boyunca aynı hatayla kalır', () {
      final mapped = _firestoreFail(
        FirestoreError.offline,
      ).map((data) => data + 1).map((data) => '$data');

      expect(mapped.isSuccess, isFalse);
      expect(mapped.errorOrNull, FirestoreError.offline);
    });

    test('liste → model listesi dönüşümü (repository kullanımı)', () {
      const FirestoreResult<List<int>> raw = FirebaseSuccess([1, 2, 3]);

      final mapped = raw.map((items) => [for (final item in items) 'p$item']);

      expect(mapped.dataOrNull, ['p1', 'p2', 'p3']);
    });

    test('dönüştürücünün fırlattığı istisna yutulmaz', () {
      expect(
        () => _firestoreOk(1).map<int>((_) => throw StateError('boom')),
        throwsStateError,
      );
    });
  });

  group('T-08 · FirebaseResult · typedef', () {
    test('FirestoreResult<T> = FirebaseResult<T, FirestoreError>', () {
      final result = _firestoreOk(1);

      expect(result, isA<FirebaseResult<int, FirestoreError>>());
      expect(result, isNot(isA<FirebaseResult<int, StorageError>>()));
      expect(result, isNot(isA<FirebaseResult<int, AuthError>>()));
    });

    test('StorageResult<T> = FirebaseResult<T, StorageError>', () {
      final result = _storageOk('users/u1/a.jpg');

      expect(result, isA<FirebaseResult<String, StorageError>>());
      expect(result, isNot(isA<FirebaseResult<String, FirestoreError>>()));
      expect(result.dataOrNull, 'users/u1/a.jpg');
    });

    test('AuthResult<T> = FirebaseResult<T, AuthError>', () {
      final result = _authFail(AuthError.invalidCredentials);

      expect(result, isA<FirebaseResult<String, AuthError>>());
      expect(result, isNot(isA<FirebaseResult<String, FirestoreError>>()));
      expect(result.errorOrNull, AuthError.invalidCredentials);
    });

    test('hata sözlükleri karışmaz: her typedef kendi enum tipini taşır', () {
      expect(
        _firestoreFail(FirestoreError.notFound).errorOrNull,
        isA<FirestoreError>(),
      );
      expect(_authFail(AuthError.network).errorOrNull, isA<AuthError>());
      expect(
        const FirebaseFailure<String, StorageError>(
          StorageError.sizeLimit,
        ).errorOrNull,
        isA<StorageError>(),
      );
    });

    test('her sonuç FirebaseResult<Object?, Object> üst tipine atanır', () {
      final results = <FirebaseResult<Object?, Object>>[
        _firestoreOk(1),
        _firestoreFail(FirestoreError.notFound),
        _storageOk('p'),
        _authFail(AuthError.unknown),
      ];

      expect(
        [for (final result in results) result.isSuccess],
        [true, false, true, false],
      );
    });
  });
}
