// SYS-01 · SplashState: props / copyWith tüm alanlar (PLAN §12.16).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/features/system/provider/splash_state.dart';

void main() {
  group('SYS-01 · SplashState', () {
    const a = SplashState();
    final at = DateTime.utc(2026, 10, 12, 16, 30);

    test('props tüm alanları içerir (alan sayısı = 4)', () {
      expect(a.props.length, 4);
    });

    test('varsayılanlar: animasyon sürüyor, zaman aşımı yok', () {
      expect(a.isAnimationDone, isFalse);
      expect(a.isTimedOut, isFalse);
      expect(a.startedAt, isNull);
      expect(a.version, isEmpty);
    });

    test('copyWith her alanı taşır ve eşitliği bozar', () {
      expect(a.copyWith(isAnimationDone: true).isAnimationDone, isTrue);
      expect(a.copyWith(isAnimationDone: true), isNot(a));
      expect(a.copyWith(isTimedOut: true).isTimedOut, isTrue);
      expect(a.copyWith(isTimedOut: true), isNot(a));
      expect(a.copyWith(startedAt: at).startedAt, at);
      expect(a.copyWith(startedAt: at), isNot(a));
      expect(a.copyWith(version: '1.2.3').version, '1.2.3');
      expect(a.copyWith(version: '1.2.3'), isNot(a));
    });

    test('copyWith parametresiz aynı değeri verir', () {
      final b = a.copyWith(
        isAnimationDone: true,
        isTimedOut: true,
        startedAt: at,
        version: '1.2.3',
      );
      expect(b.copyWith(), b);
    });
  });
}
