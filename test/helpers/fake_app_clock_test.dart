// T-08 · FakeAppClock (kök test kopyası): kurma / ilerletme, UTC
// normalizasyonu, Istanbul günü (UTC+3, gece yarısı kenarları) ve gu_data
// test çiftiyle kod eşliği (PLAN §4.7, §9.1, §10.3, §16.2).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import 'design_files.dart';
import 'fake_app_clock.dart';

/// Yorum ve içe aktarma satırları atılmış, boşlukları sadeleştirilmiş kod.
String _code(String source) => source
    .split('\n')
    .map((line) => line.trim())
    .where(
      (line) =>
          line.isNotEmpty &&
          !line.startsWith('//') &&
          !line.startsWith('import '),
    )
    .join('\n');

void main() {
  group('T-08 · FakeAppClock · şu an', () {
    test('kurulan anı döndürür (UTC)', () {
      final clock = FakeAppClock(DateTime.utc(2026, 10, 8, 20, 15, 1));

      expect(clock.nowUtc(), DateTime.utc(2026, 10, 8, 20, 15, 1));
      expect(clock.nowUtc().isUtc, isTrue);
    });

    test('kendiliğinden ilerlemez', () {
      final clock = FakeAppClock(DateTime.utc(2026, 10, 8, 12));

      expect(clock.nowUtc(), clock.nowUtc());
      expect(clock.nowUtc(), DateTime.utc(2026, 10, 8, 12));
    });

    test('UTC olmayan an aynı anın UTC karşılığına çevrilir', () {
      final local = DateTime(2026, 10, 8, 12, 30);
      final clock = FakeAppClock(local);

      expect(clock.nowUtc().isUtc, isTrue);
      expect(clock.nowUtc().isAtSameMomentAs(local), isTrue);
    });

    test('advance süre kadar ilerletir; negatif süre geri alır', () {
      final clock = FakeAppClock(DateTime.utc(2026, 10, 8, 12))
        ..advance(const Duration(hours: 1, minutes: 30));
      expect(clock.nowUtc(), DateTime.utc(2026, 10, 8, 13, 30));

      clock.advance(const Duration(days: 7));
      expect(clock.nowUtc(), DateTime.utc(2026, 10, 15, 13, 30));

      clock.advance(const Duration(minutes: -30));
      expect(clock.nowUtc(), DateTime.utc(2026, 10, 15, 13));
      expect(clock.nowUtc().isUtc, isTrue);
    });

    test('advance(Duration.zero) anı değiştirmez', () {
      final clock = FakeAppClock(DateTime.utc(2026, 10, 8, 12))
        ..advance(Duration.zero);

      expect(clock.nowUtc(), DateTime.utc(2026, 10, 8, 12));
    });

    test('set anı değiştirir (ileri ve geri) ve UTC karşılığına çevirir', () {
      final clock = FakeAppClock(DateTime.utc(2026, 10, 8, 12))
        ..set(DateTime.utc(2027));
      expect(clock.nowUtc(), DateTime.utc(2027));

      clock.set(DateTime.utc(2020, 2, 29, 23, 59));
      expect(clock.nowUtc(), DateTime.utc(2020, 2, 29, 23, 59));

      final local = DateTime(2026, 6, 1, 9);
      clock.set(local);
      expect(clock.nowUtc().isUtc, isTrue);
      expect(clock.nowUtc().isAtSameMomentAs(local), isTrue);
    });

    test('örnekler birbirinden bağımsızdır', () {
      final a = FakeAppClock(DateTime.utc(2026));
      final b = FakeAppClock(DateTime.utc(2026))
        ..advance(const Duration(days: 1));

      expect(a.nowUtc(), DateTime.utc(2026));
      expect(b.nowUtc(), DateTime.utc(2026, 1, 2));
    });
  });

  group('T-08 · FakeAppClock · AppClock sözleşmesi', () {
    test('AppClock olarak kullanılır (Limits.foundedMax yılı ondan okur)', () {
      final AppClock clock = FakeAppClock(DateTime.utc(2026, 10, 8));

      expect(Limits.foundedMax(clock), 2026);
    });

    test('yıl sınırında ilerleyince foundedMax değişir', () {
      final clock = FakeAppClock(DateTime.utc(2026, 12, 31, 23, 59, 59));
      expect(Limits.foundedMax(clock), 2026);

      clock.advance(const Duration(seconds: 1));
      expect(Limits.foundedMax(clock), 2027);
    });
  });

  group('T-08 · FakeAppClock · Istanbul günü (UTC+3, DST yok)', () {
    final clock = FakeAppClock(DateTime.utc(2000));

    test('gün içi: UTC 12:00 → aynı takvim günü', () {
      final noon = DateTime.utc(2026, 10, 8, 12);

      expect(clock.istanbulDay(noon), '2026-10-08');
      expect(clock.istanbulDayKey(noon), '20261008');
      expect(clock.istanbulStartOfDay(noon), DateTime.utc(2026, 10, 7, 21));
    });

    test('gece yarısından bir an önce: UTC 20:59:59.999 → aynı gün', () {
      final before = DateTime.utc(2026, 10, 8, 20, 59, 59, 999);

      expect(clock.istanbulDay(before), '2026-10-08');
      expect(clock.istanbulDayKey(before), '20261008');
      expect(clock.istanbulStartOfDay(before), DateTime.utc(2026, 10, 7, 21));
    });

    test('Istanbul gece yarısı: UTC 21:00 → ertesi gün başlar', () {
      final midnight = DateTime.utc(2026, 10, 8, 21);

      expect(clock.istanbulDay(midnight), '2026-10-09');
      expect(clock.istanbulDayKey(midnight), '20261009');
      expect(clock.istanbulStartOfDay(midnight), midnight);
    });

    test('UTC gece yarısı Istanbul saatiyle 03:00 — gün değişmez', () {
      final utcMidnight = DateTime.utc(2026, 10, 9);

      expect(clock.istanbulDay(utcMidnight), '2026-10-09');
      expect(
        clock.istanbulStartOfDay(utcMidnight),
        DateTime.utc(2026, 10, 8, 21),
      );
    });

    test('yıl sınırı: 31 Aralık UTC 21:00 → 1 Ocak', () {
      expect(
        clock.istanbulDay(DateTime.utc(2026, 12, 31, 20, 59)),
        '2026-12-31',
      );
      expect(clock.istanbulDay(DateTime.utc(2026, 12, 31, 21)), '2027-01-01');
      expect(clock.istanbulDayKey(DateTime.utc(2026, 12, 31, 21)), '20270101');
    });

    test('artık yıl: 28 Şubat 2028 UTC 21:00 → 29 Şubat', () {
      expect(clock.istanbulDay(DateTime.utc(2028, 2, 28, 21)), '2028-02-29');
      expect(clock.istanbulDay(DateTime.utc(2028, 2, 29, 21)), '2028-03-01');
      expect(clock.istanbulDay(DateTime.utc(2027, 2, 28, 21)), '2027-03-01');
    });

    test('tek haneli ay ve gün sıfırla doldurulur', () {
      final day = DateTime.utc(2026, 3, 5, 9);

      expect(clock.istanbulDay(day), '2026-03-05');
      expect(clock.istanbulDayKey(day), '20260305');
    });

    test('yaz ve kış aynı kayma: DST yok', () {
      expect(
        clock.istanbulStartOfDay(DateTime.utc(2026, 7, 15, 12)),
        DateTime.utc(2026, 7, 14, 21),
      );
      expect(
        clock.istanbulStartOfDay(DateTime.utc(2026, 1, 15, 12)),
        DateTime.utc(2026, 1, 14, 21),
      );
    });

    test(
      'gün başlangıcı UTC işaretlidir, o günün içindedir ve 24 saat sürer',
      () {
        final instant = DateTime.utc(2026, 10, 8, 23, 30);
        final start = clock.istanbulStartOfDay(instant);

        expect(start.isUtc, isTrue);
        expect(start.isAfter(instant), isFalse);
        expect(instant.difference(start), lessThan(const Duration(days: 1)));
        expect(clock.istanbulDay(start), clock.istanbulDay(instant));
        expect(
          clock.istanbulDay(start.subtract(const Duration(milliseconds: 1))),
          isNot(clock.istanbulDay(instant)),
        );
        expect(
          clock.istanbulStartOfDay(start.add(const Duration(days: 1))),
          start.add(const Duration(days: 1)),
        );
      },
    );

    test('kayma Limits.istanbulUtcOffset kadardır (3 saat)', () {
      final start = clock.istanbulStartOfDay(DateTime.utc(2026, 10, 8, 12));

      expect(
        DateTime.utc(2026, 10, 8).difference(start),
        Limits.istanbulUtcOffset,
      );
      expect(Limits.istanbulUtcOffset, const Duration(hours: 3));
    });

    test('UTC olmayan girdi aynı an olarak yorumlanır', () {
      final utc = DateTime.utc(2026, 10, 8, 21);
      final local = utc.toLocal();

      expect(clock.istanbulDay(local), clock.istanbulDay(utc));
      expect(clock.istanbulDayKey(local), clock.istanbulDayKey(utc));
      expect(clock.istanbulStartOfDay(local), clock.istanbulStartOfDay(utc));
    });

    test('gün hesapları saatin "şu an"ına değil verilen ana bağlıdır', () {
      final other = FakeAppClock(DateTime.utc(2030, 5, 5, 5));
      final instant = DateTime.utc(2026, 10, 8, 21);

      expect(other.istanbulDay(instant), clock.istanbulDay(instant));
      other.advance(const Duration(days: 400));
      expect(other.istanbulDayKey(instant), '20261009');
    });

    test('duyuru sayacı günü: şu an ilerleyince gün anahtarı gece yarısında '
        'değişir', () {
      final now = FakeAppClock(DateTime.utc(2026, 10, 8, 20, 59, 59));
      expect(now.istanbulDayKey(now.nowUtc()), '20261008');

      now.advance(const Duration(seconds: 1));
      expect(now.istanbulDayKey(now.nowUtc()), '20261009');
      expect(now.istanbulDay(now.nowUtc()), '2026-10-09');
    });

    test('biçimler Limits.isoDayPattern ve yyyyMMdd ile uyumlu', () {
      final instant = DateTime.utc(2026, 10, 8, 12);

      expect(
        RegExp(Limits.isoDayPattern).hasMatch(clock.istanbulDay(instant)),
        isTrue,
      );
      expect(clock.istanbulDayKey(instant), matches(RegExp(r'^\d{8}$')));
      expect(
        clock.istanbulDay(instant).replaceAll('-', ''),
        clock.istanbulDayKey(instant),
      );
    });

    test('üretimdeki SystemAppClock ile aynı gün hesabı', () {
      const system = SystemAppClock();

      for (final instant in [
        DateTime.utc(2026, 10, 8, 20, 59, 59, 999),
        DateTime.utc(2026, 10, 8, 21),
        DateTime.utc(2026, 12, 31, 21),
        DateTime.utc(2028, 2, 28, 21),
        DateTime.utc(1999, 12, 31, 23, 59, 59),
      ]) {
        expect(clock.istanbulDay(instant), system.istanbulDay(instant));
        expect(clock.istanbulDayKey(instant), system.istanbulDayKey(instant));
        expect(
          clock.istanbulStartOfDay(instant),
          system.istanbulStartOfDay(instant),
        );
      }
    });
  });

  group('T-08 · FakeAppClock · gu_data test çiftiyle eşlik', () {
    test('kök kopya, packages/gu_data/test/fakes/fake_app_clock.dart ile aynı '
        'koddur (yorum ve içe aktarma hariç)', () {
      expect(
        _code(readText('test/helpers/fake_app_clock.dart')),
        _code(readText('packages/gu_data/test/fakes/fake_app_clock.dart')),
      );
    });

    test('kök kopya gu_data barrel dosyasını içe aktarır (src yolu değil)', () {
      final source = readText('test/helpers/fake_app_clock.dart');

      expect(source, contains("import 'package:gu_data/gu_data.dart';"));
      expect(source, isNot(contains('package:gu_data/src/')));
    });

    test(
      'yasaklı adlar yok (FakeClock, FixedAppClock, now(), istanbulNow())',
      () {
        final code = _code(readText('test/helpers/fake_app_clock.dart'));

        expect(
          code,
          contains('final class FakeAppClock implements AppClock {'),
        );
        expect(code, isNot(contains('FakeClock')));
        expect(code, isNot(contains('FixedAppClock')));
        expect(code, isNot(contains(' now()')));
        expect(code, isNot(contains('istanbulNow')));
        expect(code, isNot(contains('DateTime.now')));
      },
    );
  });
}
