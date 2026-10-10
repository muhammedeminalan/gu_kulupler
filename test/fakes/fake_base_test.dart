import 'package:flutter_test/flutter_test.dart';

import 'fake_base.dart';

/// Örnek fake: tek metot, kayıt + tek seferlik hata.
final class _FakeCounter extends FakeBase {
  int _value = 0;

  Future<int> next({int step = 1}) async {
    record('next', [step]);
    if (takeFailure() case final error?) return Future.error(error);
    return _value += step;
  }

  void reset() => record('reset');
}

void main() {
  group('T-02 · FakeBase', () {
    test('çağrı günlüğü: sıra, argümanlar, callsTo', () async {
      final fake = _FakeCounter();
      await fake.next();
      fake.reset();
      await fake.next(step: 3);
      expect(fake.calls, const [
        FakeCall('next', [1]),
        FakeCall('reset'),
        FakeCall('next', [3]),
      ]);
      expect(fake.callsTo('next'), hasLength(2));
      expect(fake.callsTo('yok'), isEmpty);
      expect(fake.calls.first.toString(), 'next(1)');
    });

    test('failNext tek seferlik (varsayılan FakeFailure)', () async {
      final fake = _FakeCounter()..failNext();
      expect(fake.hasPendingFailure, isTrue);
      await expectLater(fake.next(), throwsA(isA<FakeFailure>()));
      expect(fake.hasPendingFailure, isFalse);
      expect(await fake.next(), 1);
      expect(fake.calls, hasLength(2));
    });

    test('failNext özel hata; takeFailure temizler', () async {
      final fake = _FakeCounter()..failNext(StateError('ağ yok'));
      await expectLater(fake.next(), throwsStateError);
      fake.failNext();
      expect(fake.takeFailure(), isA<FakeFailure>());
      expect(fake.takeFailure(), isNull);
    });

    test('resetFake günlüğü ve bekleyen hatayı siler', () async {
      final fake = _FakeCounter();
      await fake.next();
      fake
        ..failNext()
        ..resetFake();
      expect(fake.calls, isEmpty);
      expect(fake.hasPendingFailure, isFalse);
    });
  });
}
