// T-10 · RetryPolicy: hangi hatalar yeniden denenir, deneme sayısı, bekleme
// süreleri ve varsayılanlar (PLAN §10.1). Bekleme enjekte edilir; testler
// gerçek zaman geçirmez.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

/// Betikteki sonuçları sırayla döndüren ve çağrıları sayan işlem.
final class _Scripted<T> {
  _Scripted(this._results);

  final List<FirestoreResult<T>> _results;

  /// Şimdiye kadarki çağrı sayısı.
  int calls = 0;

  Future<FirestoreResult<T>> call() async =>
      _results[calls++ < _results.length ? calls - 1 : _results.length - 1];
}

FirestoreResult<int> _fail(FirestoreError error) => FirebaseFailure(error);

void main() {
  late List<Duration> waits;
  late RetryPolicy policy;

  setUp(() {
    waits = [];
    policy = RetryPolicy(wait: (delay) async => waits.add(delay));
  });

  group('T-10 · RetryPolicy · varsayılanlar', () {
    test('3 deneme (= Limits.retryBackoff uzunluğu), bekleme '
        'Limits.retryBackoff', () {
      const defaults = RetryPolicy();

      expect(defaults.maxAttempts, 3);
      expect(defaults.maxAttempts, Limits.retryBackoff.length);
      expect(RetryPolicy.defaultMaxAttempts, 3);
      expect(defaults.backoff, same(Limits.retryBackoff));
    });

    test('yalnızca aborted ve unavailable yeniden denenir', () {
      expect(
        FirestoreError.values.where(RetryPolicy.shouldRetry),
        [FirestoreError.aborted, FirestoreError.unavailable],
      );
    });
  });

  group('T-10 · RetryPolicy · run', () {
    test('ilk denemede başarı: tek çağrı, bekleme yok', () async {
      final action = _Scripted<int>([const FirebaseSuccess(7)]);

      final result = await policy.run(action.call);

      expect(result.dataOrNull, 7);
      expect(action.calls, 1);
      expect(waits, isEmpty);
    });

    test('geçici hata sonrası başarı: 250 ms ve 500 ms bekleyip üçüncü '
        'denemede döner', () async {
      final action = _Scripted<int>([
        _fail(FirestoreError.aborted),
        _fail(FirestoreError.unavailable),
        const FirebaseSuccess(7),
      ]);

      final result = await policy.run(action.call);

      expect(result.dataOrNull, 7);
      expect(action.calls, 3);
      expect(waits, const [
        Duration(milliseconds: 250),
        Duration(milliseconds: 500),
      ]);
    });

    test('hata sürerse tam 3 deneme yapılır, son hata döner; son denemeden '
        'sonra beklenmez', () async {
      for (final error in [
        FirestoreError.aborted,
        FirestoreError.unavailable,
      ]) {
        waits.clear();
        final action = _Scripted<int>([_fail(error)]);

        final result = await policy.run(action.call);

        expect(result.errorOrNull, error);
        expect(action.calls, 3, reason: error.name);
        expect(waits, hasLength(2), reason: error.name);
      }
    });

    test(
      'diğer hiçbir hata yeniden denenmez (tek çağrı, bekleme yok)',
      () async {
        final notRetried = FirestoreError.values.toSet()
          ..removeAll([FirestoreError.aborted, FirestoreError.unavailable]);

        expect(notRetried, hasLength(14));
        for (final error in notRetried) {
          final action = _Scripted<int>([
            _fail(error),
            const FirebaseSuccess(7),
          ]);

          final result = await policy.run(action.call);

          expect(result.errorOrNull, error, reason: error.name);
          expect(action.calls, 1, reason: error.name);
        }
        expect(waits, isEmpty);
      },
    );

    test('yeniden denenemeyen hata gelince deneme zinciri kesilir', () async {
      final action = _Scripted<int>([
        _fail(FirestoreError.unavailable),
        _fail(FirestoreError.permissionDenied),
        const FirebaseSuccess(7),
      ]);

      final result = await policy.run(action.call);

      expect(result.errorOrNull, FirestoreError.permissionDenied);
      expect(action.calls, 2);
      expect(waits, hasLength(1));
    });

    test('başarısızlığın mesajı ve ek bilgisi olduğu gibi taşınır', () async {
      final action = _Scripted<int>([
        const FirebaseFailure(
          FirestoreError.conflict,
          message: 'ham',
          detail: 'ek',
        ),
      ]);

      final result = await policy.run(action.call) as FirebaseFailure;

      expect(result.message, 'ham');
      expect(result.detail, 'ek');
    });

    test('deneme sayısı bekleme listesinden uzunsa son süre tekrarlanır; '
        'liste boşsa beklenmeden denenir', () async {
      final action = _Scripted<int>([_fail(FirestoreError.aborted)]);
      final long = RetryPolicy(
        maxAttempts: 5,
        wait: (delay) async => waits.add(delay),
      );
      final immediate = RetryPolicy(
        backoff: const [],
        wait: (delay) async => waits.add(delay),
      );

      await long.run(action.call);
      final longWaits = [...waits];
      waits.clear();
      await immediate.run(action.call);

      expect(action.calls, 5 + 3);
      expect(longWaits, const [
        Duration(milliseconds: 250),
        Duration(milliseconds: 500),
        Duration(milliseconds: 1000),
        Duration(milliseconds: 1000),
      ]);
      expect(waits, [Duration.zero, Duration.zero]);
    });

    // Gövdede `pump` dışında `await` yok (sahte zaman bölgesi).
    testWidgets('varsayılan bekleme gerçek zamanlayıcıdır: süre dolmadan '
        'ikinci deneme yapılmaz', (tester) async {
      final action = _Scripted<int>([
        _fail(FirestoreError.aborted),
        const FirebaseSuccess(7),
      ]);
      FirestoreResult<int>? result;
      unawaited(const RetryPolicy().run(action.call).then((r) => result = r));

      await tester.pump(const Duration(milliseconds: 249));
      expect(action.calls, 1);
      expect(result, isNull);
      await tester.pump(const Duration(milliseconds: 1));

      expect(action.calls, 2);
      expect(result!.dataOrNull, 7);
    });
  });
}
