// T-08 · FakeAppClock: elle kurulan / ilerletilen sahte saat (PLAN §9.1,
// §10.3, §16.3 — her fake'in kendi testi vardır).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import 'fake_app_clock.dart';

void main() {
  final start = DateTime.utc(2026, 10, 10, 20, 59, 59);

  group('T-08 · FakeAppClock · nowUtc', () {
    test('AppClock arayüzünü uygular', () {
      expect(FakeAppClock(start), isA<AppClock>());
    });

    test('kurulduğu anı döndürür', () {
      final clock = FakeAppClock(start);

      expect(clock.nowUtc(), start);
      expect(clock.nowUtc().isUtc, isTrue);
    });

    test('kendiliğinden ilerlemez: ardışık okumalar aynı an', () {
      final clock = FakeAppClock(start);

      expect(
        [for (var i = 0; i < 5; i++) clock.nowUtc()],
        everyElement(start),
      );
    });

    test('yerel DateTime ile kurulursa aynı anın UTC karşılığını tutar', () {
      final clock = FakeAppClock(start.toLocal());

      expect(clock.nowUtc().isUtc, isTrue);
      expect(clock.nowUtc(), start);
    });

    test('iki saat birbirinden bağımsızdır', () {
      final a = FakeAppClock(start);
      final b = FakeAppClock(start)..advance(const Duration(hours: 1));

      expect(a.nowUtc(), start);
      expect(b.nowUtc(), start.add(const Duration(hours: 1)));
    });
  });

  group('T-08 · FakeAppClock · advance', () {
    test('saati verilen süre kadar ilerletir', () {
      final clock = FakeAppClock(start)..advance(const Duration(seconds: 1));

      expect(clock.nowUtc(), DateTime.utc(2026, 10, 10, 21));
      expect(clock.nowUtc().isUtc, isTrue);
    });

    test('ardışık ilerletmeler birikir', () {
      final clock = FakeAppClock(start)
        ..advance(const Duration(seconds: 30))
        ..advance(const Duration(minutes: 2))
        ..advance(const Duration(days: 7));

      expect(
        clock.nowUtc(),
        start.add(const Duration(days: 7, minutes: 2, seconds: 30)),
      );
    });

    test('sıfır süre saati değiştirmez', () {
      final clock = FakeAppClock(start)..advance(Duration.zero);

      expect(clock.nowUtc(), start);
    });

    test('negatif süre saati geri alır', () {
      final clock = FakeAppClock(start)..advance(const Duration(hours: -1));

      expect(clock.nowUtc(), DateTime.utc(2026, 10, 10, 19, 59, 59));
    });

    test('mikrosaniye hassasiyeti korunur', () {
      final clock = FakeAppClock(start)
        ..advance(const Duration(microseconds: 999999));

      expect(clock.nowUtc(), DateTime.utc(2026, 10, 10, 20, 59, 59, 999, 999));
    });

    test('gün sınırını geçince Istanbul günü değişir', () {
      final clock = FakeAppClock(start);

      expect(clock.istanbulDayKey(clock.nowUtc()), '20261010');
      expect(clock.istanbulDay(clock.nowUtc()), '2026-10-10');

      clock.advance(const Duration(seconds: 1));

      expect(clock.istanbulDayKey(clock.nowUtc()), '20261011');
      expect(clock.istanbulDay(clock.nowUtc()), '2026-10-11');
      expect(
        clock.istanbulStartOfDay(clock.nowUtc()),
        DateTime.utc(2026, 10, 10, 21),
      );
    });
  });

  group('T-08 · FakeAppClock · set', () {
    test('saati verilen ana kurar', () {
      final clock = FakeAppClock(start)..set(DateTime.utc(2030, 1, 2, 3, 4, 5));

      expect(clock.nowUtc(), DateTime.utc(2030, 1, 2, 3, 4, 5));
    });

    test('geçmiş bir ana da kurulabilir', () {
      final clock = FakeAppClock(start)..set(DateTime.utc(2020));

      expect(clock.nowUtc(), DateTime.utc(2020));
    });

    test('yerel DateTime verilirse aynı anın UTC karşılığını tutar', () {
      final target = DateTime.utc(2027, 5, 6, 7);
      final clock = FakeAppClock(start)..set(target.toLocal());

      expect(clock.nowUtc().isUtc, isTrue);
      expect(clock.nowUtc(), target);
    });

    test('set sonrası advance yeni andan devam eder', () {
      final clock = FakeAppClock(start)
        ..set(DateTime.utc(2027))
        ..advance(const Duration(days: 1));

      expect(clock.nowUtc(), DateTime.utc(2027, 1, 2));
    });
  });

  group('T-08 · FakeAppClock · Istanbul hesabı', () {
    test('gün hesabı "şu an"dan bağımsızdır (yalnızca verilen ana bağlı)', () {
      final instant = DateTime.utc(2026, 12, 31, 21);
      final early = FakeAppClock(DateTime.utc(2000));
      final late = FakeAppClock(DateTime.utc(2040));

      expect(early.istanbulDayKey(instant), '20270101');
      expect(late.istanbulDayKey(instant), '20270101');
      expect(early.istanbulDay(instant), late.istanbulDay(instant));
      expect(
        early.istanbulStartOfDay(instant),
        late.istanbulStartOfDay(instant),
      );
    });

    test('üretimdeki SystemAppClock ile aynı sonuçları verir', () {
      const system = SystemAppClock();
      final fake = FakeAppClock(start);
      var instant = DateTime.utc(2026, 2, 27);
      final end = DateTime.utc(2026, 3, 3);

      while (instant.isBefore(end)) {
        expect(fake.istanbulDayKey(instant), system.istanbulDayKey(instant));
        expect(fake.istanbulDay(instant), system.istanbulDay(instant));
        expect(
          fake.istanbulStartOfDay(instant),
          system.istanbulStartOfDay(instant),
        );
        instant = instant.add(const Duration(minutes: 13));
      }
    });
  });
}
