// T-12 · LoginThrottle: e-posta başına 5 hatalı deneme → 30 sn kilit, kilit
// dolunca / başarılı girişte sıfırlanma, adres anahtarlama; zaman yalnızca
// AppClock'tan (PLAN §9.8, §10.3, §10.4; AUT-01, DLG-02).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/fake_app_clock.dart';
import '../helpers/repo_sources.dart';

const String _email = 'ayse@ogr.gumushane.edu.tr';

void main() {
  final start = DateTime.utc(2026, 10, 10, 9);
  late FakeAppClock clock;
  late LoginThrottle throttle;

  void fail(int times, {String email = _email}) {
    for (var i = 0; i < times; i++) {
      throttle.recordFailure(email);
    }
  }

  setUp(() {
    clock = FakeAppClock(start);
    throttle = LoginThrottle(clock);
  });

  group('T-12 · LoginThrottle', () {
    test('varsayılan sınırlar Limits değerleridir (5 deneme, 30 sn)', () {
      expect(throttle.maxFailedAttempts, Limits.loginMaxFailedAttempts);
      expect(throttle.maxFailedAttempts, 5);
      expect(throttle.lockout, Limits.loginLockout);
      expect(throttle.lockout, const Duration(seconds: 30));
    });

    test('hiç deneme yokken ve 4 hatalı denemeden sonra açıktır', () {
      expect(throttle.check(_email), isNull);

      fail(4);

      expect(throttle.check(_email), isNull);
      expect(throttle.remaining(_email), isNull);
    });

    test('5. hatalı deneme adresi şimdi + 30 sn anına kadar kilitler', () {
      fail(4);
      clock.advance(const Duration(seconds: 7));

      fail(1);

      final lockedUntil = start.add(const Duration(seconds: 37));
      expect(throttle.check(_email), lockedUntil);
      expect(throttle.check(_email)!.isUtc, isTrue);
      expect(throttle.remaining(_email), Limits.loginLockout);
    });

    test('kalan süre saatle birlikte azalır; 30. saniyede kilit açılır', () {
      fail(5);

      clock.advance(const Duration(seconds: 10));
      expect(throttle.remaining(_email), const Duration(seconds: 20));

      clock.advance(const Duration(seconds: 19, milliseconds: 999));
      expect(throttle.remaining(_email), const Duration(milliseconds: 1));

      clock.advance(const Duration(milliseconds: 1));
      expect(throttle.check(_email), isNull);
      expect(throttle.remaining(_email), isNull);
    });

    test('kilit dolunca sayaç sıfırdan başlar', () {
      fail(5);
      clock.advance(Limits.loginLockout);

      fail(4);
      expect(throttle.check(_email), isNull);

      fail(1);
      expect(throttle.remaining(_email), Limits.loginLockout);
    });

    test('kilitliyken sayılan deneme kilidi uzatmaz', () {
      fail(5);
      clock.advance(const Duration(seconds: 20));

      fail(3);

      expect(throttle.check(_email), start.add(Limits.loginLockout));
    });

    test('reset sayacı ve kilidi sıfırlar', () {
      fail(4);
      throttle.reset(_email);
      fail(4);
      expect(throttle.check(_email), isNull);

      fail(1);
      throttle.reset(_email);
      expect(throttle.check(_email), isNull);
    });

    test('sayaç e-posta başınadır', () {
      fail(5);

      expect(throttle.check('mehmet@ogr.gumushane.edu.tr'), isNull);
    });

    test('adres kırpılıp küçültülerek anahtarlanır', () {
      fail(2);
      fail(2, email: ' AYSE@OGR.GUMUSHANE.EDU.TR ');
      fail(1, email: 'Ayse@ogr.gumushane.edu.tr');

      expect(throttle.check(_email), isNotNull);
      expect(throttle.check('  Ayse@Ogr.Gumushane.Edu.Tr'), isNotNull);

      throttle.reset(' AYSE@ogr.gumushane.edu.tr');
      expect(throttle.check(_email), isNull);
    });

    test('özel sınırlar uygulanır', () {
      throttle = LoginThrottle(
        clock,
        maxFailedAttempts: 2,
        lockout: const Duration(minutes: 1),
      );

      fail(2);

      expect(throttle.remaining(_email), const Duration(minutes: 1));
    });

    test('kaynak sistem saatini doğrudan okumaz (yalnızca AppClock)', () {
      final source = readRepoFile(
        'packages/gu_data/lib/src/utils/login_throttle.dart',
      );

      expect(source, isNot(contains('DateTime.now')));
      expect(source, contains('_clock.nowUtc()'));
    });
  });
}
