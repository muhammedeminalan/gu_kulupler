// T-11 · ConnectivityState: props / copyWith tüm alanlar (PLAN §12.16).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/core/connectivity/connectivity_state.dart';

void main() {
  group('T-11 · ConnectivityState', () {
    const a = ConnectivityState();

    test('props tüm alanları içerir (alan sayısı = 4)', () {
      expect(a.props.length, 4);
    });

    test('varsayılanlar: çevrimiçi', () {
      expect(a.isOffline, isFalse);
      expect(a.isFromCache, isFalse);
      expect(a.wasOffline, isFalse);
      expect(a.isSimulated, isFalse);
    });

    test('copyWith her alanı taşır ve eşitliği bozar', () {
      expect(a.copyWith(isOffline: true).isOffline, isTrue);
      expect(a.copyWith(isOffline: true), isNot(a));
      expect(a.copyWith(isFromCache: true).isFromCache, isTrue);
      expect(a.copyWith(isFromCache: true), isNot(a));
      expect(a.copyWith(wasOffline: true).wasOffline, isTrue);
      expect(a.copyWith(wasOffline: true), isNot(a));
      expect(a.copyWith(isSimulated: true).isSimulated, isTrue);
      expect(a.copyWith(isSimulated: true), isNot(a));
    });

    test('copyWith parametresiz aynı değeri verir', () {
      final b = a.copyWith(
        isOffline: true,
        isFromCache: true,
        wasOffline: true,
        isSimulated: true,
      );
      expect(b.copyWith(), b);
    });
  });
}
