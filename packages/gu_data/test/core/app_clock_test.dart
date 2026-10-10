// T-08 · AppClock / SystemAppClock: UTC "şu an" ve Istanbul günü hesabı
// (UTC+3 sabit, DST yok) — gün sınırı kenarları, biçimler, değişmezler
// (PLAN §9.1, §9.3, §10.3; D-26; domain-model §1.5).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/fake_app_clock.dart';
import '../helpers/repo_sources.dart';

/// Bir UTC anı ve beklenen Istanbul günü.
typedef _Case = ({
  String label,
  DateTime utc,
  String dayKey,
  String day,
  DateTime startOfDay,
});

/// Istanbul gece yarısı = UTC 21:00. Her satır: an → `yyyyMMdd`,
/// `yyyy-MM-dd`, günün başlangıcı (UTC).
final List<_Case> _cases = [
  (
    label: 'gün sınırından 1 sn önce (20:59:59Z = 23:59:59 Istanbul)',
    utc: DateTime.utc(2026, 10, 10, 20, 59, 59),
    dayKey: '20261010',
    day: '2026-10-10',
    startOfDay: DateTime.utc(2026, 10, 9, 21),
  ),
  (
    label: 'gün sınırından 1 µs önce (20:59:59.999999Z)',
    utc: DateTime.utc(2026, 10, 10, 20, 59, 59, 999, 999),
    dayKey: '20261010',
    day: '2026-10-10',
    startOfDay: DateTime.utc(2026, 10, 9, 21),
  ),
  (
    label: 'tam gün sınırı (21:00:00Z = 00:00 Istanbul, ertesi gün)',
    utc: DateTime.utc(2026, 10, 10, 21),
    dayKey: '20261011',
    day: '2026-10-11',
    startOfDay: DateTime.utc(2026, 10, 10, 21),
  ),
  (
    label: 'gün sınırından 1 µs sonra',
    utc: DateTime.utc(2026, 10, 10, 21, 0, 0, 0, 1),
    dayKey: '20261011',
    day: '2026-10-11',
    startOfDay: DateTime.utc(2026, 10, 10, 21),
  ),
  (
    label: 'UTC gece yarısı (00:00Z = 03:00 Istanbul, aynı gün)',
    utc: DateTime.utc(2026, 10, 10),
    dayKey: '20261010',
    day: '2026-10-10',
    startOfDay: DateTime.utc(2026, 10, 9, 21),
  ),
  (
    label: 'UTC gece yarısından 1 sn önce (23:59:59Z = 02:59:59 ertesi gün)',
    utc: DateTime.utc(2026, 10, 9, 23, 59, 59),
    dayKey: '20261010',
    day: '2026-10-10',
    startOfDay: DateTime.utc(2026, 10, 9, 21),
  ),
  (
    label: 'öğlen (09:00Z = 12:00 Istanbul)',
    utc: DateTime.utc(2026, 10, 10, 9),
    dayKey: '20261010',
    day: '2026-10-10',
    startOfDay: DateTime.utc(2026, 10, 9, 21),
  ),
  (
    label: 'yıl sonu: 31 Aralık 20:59:59Z hâlâ eski yıl',
    utc: DateTime.utc(2026, 12, 31, 20, 59, 59),
    dayKey: '20261231',
    day: '2026-12-31',
    startOfDay: DateTime.utc(2026, 12, 30, 21),
  ),
  (
    label: "yıl sonu: 31 Aralık 21:00Z Istanbul'da yeni yıl",
    utc: DateTime.utc(2026, 12, 31, 21),
    dayKey: '20270101',
    day: '2027-01-01',
    startOfDay: DateTime.utc(2026, 12, 31, 21),
  ),
  (
    label: 'ay sonu: 31 Ocak 21:00Z → 1 Şubat',
    utc: DateTime.utc(2026, 1, 31, 21),
    dayKey: '20260201',
    day: '2026-02-01',
    startOfDay: DateTime.utc(2026, 1, 31, 21),
  ),
  (
    label: 'artık yıl: 28 Şubat 2028 21:00Z → 29 Şubat',
    utc: DateTime.utc(2028, 2, 28, 21),
    dayKey: '20280229',
    day: '2028-02-29',
    startOfDay: DateTime.utc(2028, 2, 28, 21),
  ),
  (
    label: 'artık yıl: 29 Şubat 2028 21:00Z → 1 Mart',
    utc: DateTime.utc(2028, 2, 29, 21),
    dayKey: '20280301',
    day: '2028-03-01',
    startOfDay: DateTime.utc(2028, 2, 29, 21),
  ),
  (
    label: 'artık olmayan yıl: 28 Şubat 2026 21:00Z → 1 Mart',
    utc: DateTime.utc(2026, 2, 28, 21),
    dayKey: '20260301',
    day: '2026-03-01',
    startOfDay: DateTime.utc(2026, 2, 28, 21),
  ),
  (
    label: 'tek haneli ay ve gün sıfırla doldurulur',
    utc: DateTime.utc(2026, 1, 8, 21),
    dayKey: '20260109',
    day: '2026-01-09',
    startOfDay: DateTime.utc(2026, 1, 8, 21),
  ),
  (
    label: 'kış (DST yok): 15 Ocak 20:59:59Z hâlâ 15 Ocak',
    utc: DateTime.utc(2026, 1, 15, 20, 59, 59),
    dayKey: '20260115',
    day: '2026-01-15',
    startOfDay: DateTime.utc(2026, 1, 14, 21),
  ),
  (
    label: 'kış (DST yok): 15 Ocak 21:00Z → 16 Ocak (UTC+2 olsaydı 15 kalırdı)',
    utc: DateTime.utc(2026, 1, 15, 21),
    dayKey: '20260116',
    day: '2026-01-16',
    startOfDay: DateTime.utc(2026, 1, 15, 21),
  ),
  (
    label: 'yaz (DST yok): 15 Temmuz 20:59:59Z hâlâ 15 Temmuz',
    utc: DateTime.utc(2026, 7, 15, 20, 59, 59),
    dayKey: '20260715',
    day: '2026-07-15',
    startOfDay: DateTime.utc(2026, 7, 14, 21),
  ),
  (
    label: 'yaz (DST yok): 15 Temmuz 21:00Z → 16 Temmuz',
    utc: DateTime.utc(2026, 7, 15, 21),
    dayKey: '20260716',
    day: '2026-07-16',
    startOfDay: DateTime.utc(2026, 7, 15, 21),
  ),
  (
    label: 'Avrupa yaz saati geçişi (29 Mart 2026): sınır yine 21:00Z',
    utc: DateTime.utc(2026, 3, 28, 21),
    dayKey: '20260329',
    day: '2026-03-29',
    startOfDay: DateTime.utc(2026, 3, 28, 21),
  ),
  (
    label: 'Avrupa yaz saati geçişi günü 20:59:59Z hâlâ 29 Mart',
    utc: DateTime.utc(2026, 3, 29, 20, 59, 59),
    dayKey: '20260329',
    day: '2026-03-29',
    startOfDay: DateTime.utc(2026, 3, 28, 21),
  ),
  (
    label: 'Avrupa kış saati geçişi (25 Ekim 2026): sınır yine 21:00Z',
    utc: DateTime.utc(2026, 10, 24, 21),
    dayKey: '20261025',
    day: '2026-10-25',
    startOfDay: DateTime.utc(2026, 10, 24, 21),
  ),
  (
    label: 'Avrupa kış saati geçişi günü 20:59:59Z hâlâ 25 Ekim',
    utc: DateTime.utc(2026, 10, 25, 20, 59, 59),
    dayKey: '20261025',
    day: '2026-10-25',
    startOfDay: DateTime.utc(2026, 10, 24, 21),
  ),
  (
    label: 'Unix başlangıcı (1970-01-01T00:00Z = 03:00 Istanbul)',
    utc: DateTime.utc(1970),
    dayKey: '19700101',
    day: '1970-01-01',
    startOfDay: DateTime.utc(1969, 12, 31, 21),
  ),
];

void main() {
  /// Istanbul hesabını sunan her uygulama aynı tabloyu geçmelidir.
  final clocks = <String, AppClock>{
    'SystemAppClock': const SystemAppClock(),
    'FakeAppClock': FakeAppClock(DateTime.utc(2000)),
  };

  for (final MapEntry(key: name, value: clock) in clocks.entries) {
    group('T-08 · $name · Istanbul gün sınırı', () {
      for (final c in _cases) {
        test(c.label, () {
          expect(clock.istanbulDayKey(c.utc), c.dayKey);
          expect(clock.istanbulDay(c.utc), c.day);
          expect(clock.istanbulStartOfDay(c.utc), c.startOfDay);
        });
      }
    });
  }

  group('T-08 · SystemAppClock · biçimler', () {
    const clock = SystemAppClock();

    test("istanbulDayKey 'yyyyMMdd' (8 rakam)", () {
      for (final c in _cases) {
        expect(clock.istanbulDayKey(c.utc), matches(RegExp(r'^\d{8}$')));
      }
    });

    test("istanbulDay 'yyyy-MM-dd' ve Limits.isoDayPattern ile uyumlu", () {
      final pattern = RegExp(Limits.isoDayPattern);

      for (final c in _cases) {
        final day = clock.istanbulDay(c.utc);
        expect(day, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
        expect(pattern.hasMatch(day), isTrue, reason: day);
      }
    });

    test(
      'istanbulDay, istanbulDayKey ile aynı günü gösterir (tiresiz hali)',
      () {
        for (final c in _cases) {
          expect(
            clock.istanbulDay(c.utc).replaceAll('-', ''),
            clock.istanbulDayKey(c.utc),
          );
        }
      },
    );

    test('1000 öncesi yıl dört haneye sıfırla doldurulur', () {
      final utc = DateTime.utc(987, 6, 5, 12);

      expect(clock.istanbulDayKey(utc), '09870605');
      expect(clock.istanbulDay(utc), '0987-06-05');
    });

    test('istanbulDay DateTime.parse ile okunabilir ve aynı takvim günü', () {
      final parsed = DateTime.parse(
        '${clock.istanbulDay(DateTime.utc(2026, 10, 10, 21))}T00:00:00Z',
      );

      expect(parsed, DateTime.utc(2026, 10, 11));
    });
  });

  group('T-08 · SystemAppClock · istanbulStartOfDay', () {
    const clock = SystemAppClock();

    test('sonuç UTC işaretlidir', () {
      for (final c in _cases) {
        expect(clock.istanbulStartOfDay(c.utc).isUtc, isTrue);
      }
    });

    test('günün başlangıcı her zaman UTC 21:00:00.000000', () {
      for (final c in _cases) {
        final start = clock.istanbulStartOfDay(c.utc);
        expect(
          [
            start.hour,
            start.minute,
            start.second,
            start.millisecond,
            start.microsecond,
          ],
          [21, 0, 0, 0, 0],
        );
      }
    });

    test('Istanbul duvar saatiyle başlangıç tam 00:00 '
        '(Limits.istanbulUtcOffset)', () {
      for (final c in _cases) {
        final wall = clock
            .istanbulStartOfDay(c.utc)
            .add(Limits.istanbulUtcOffset);
        expect(
          [
            wall.hour,
            wall.minute,
            wall.second,
            wall.millisecond,
            wall.microsecond,
          ],
          [0, 0, 0, 0, 0],
        );
        expect(
          [wall.year, wall.month, wall.day],
          [
            int.parse(c.dayKey.substring(0, 4)),
            int.parse(c.dayKey.substring(4, 6)),
            int.parse(c.dayKey.substring(6, 8)),
          ],
        );
      }
    });

    test('başlangıç ≤ an < başlangıç + 24 sa', () {
      for (final c in _cases) {
        final start = clock.istanbulStartOfDay(c.utc);
        expect(start.isAfter(c.utc), isFalse);
        expect(c.utc.isBefore(start.add(const Duration(days: 1))), isTrue);
      }
    });

    test('idempotent: başlangıcın başlangıcı kendisidir', () {
      for (final c in _cases) {
        final start = clock.istanbulStartOfDay(c.utc);
        expect(clock.istanbulStartOfDay(start), start);
      }
    });

    test('başlangıç aynı güne, 1 µs öncesi önceki güne aittir', () {
      for (final c in _cases) {
        final start = clock.istanbulStartOfDay(c.utc);
        expect(clock.istanbulDayKey(start), c.dayKey);
        expect(
          clock.istanbulDayKey(
            start.subtract(const Duration(microseconds: 1)),
          ),
          isNot(c.dayKey),
        );
      }
    });

    test('ardışık günlerin başlangıçları tam 24 sa aralıklı', () {
      final start = clock.istanbulStartOfDay(DateTime.utc(2026, 10, 10, 12));
      final next = clock.istanbulStartOfDay(DateTime.utc(2026, 10, 11, 12));

      expect(next.difference(start), const Duration(days: 1));
    });
  });

  group('T-08 · SystemAppClock · saatlik tarama (2025–2028)', () {
    const clock = SystemAppClock();

    test(
      "gün anahtarı yalnızca UTC 21:00'de değişir; her gün tam 24 saat",
      () {
        var instant = DateTime.utc(2025);
        final end = DateTime.utc(2029);
        var previousKey = clock.istanbulDayKey(instant);
        var hoursInDay = 0;
        var changes = 0;
        var firstChangeSeen = false;

        while (instant.isBefore(end)) {
          final key = clock.istanbulDayKey(instant);
          if (key != previousKey) {
            expect(instant.hour, 21, reason: 'değişim anı: $instant');
            if (firstChangeSeen) {
              expect(hoursInDay, 24, reason: 'gün: $previousKey');
            }
            expect(
              key.compareTo(previousKey),
              greaterThan(0),
              reason: 'anahtarlar artan sırada: $previousKey → $key',
            );
            firstChangeSeen = true;
            hoursInDay = 0;
            changes++;
            previousKey = key;
          }
          expect(clock.istanbulStartOfDay(instant).hour, 21);
          hoursInDay++;
          instant = instant.add(const Duration(hours: 1));
        }

        // 2025 + 2026 + 2027 + 2028 (artık) = 365·3 + 366 gün sınırı.
        expect(changes, 365 * 3 + 366);
      },
    );

    test('gün anahtarı (UTC + 3 sa) anının takvim günüdür', () {
      var instant = DateTime.utc(2025, 12, 30);
      final end = DateTime.utc(2026, 1, 3);

      while (instant.isBefore(end)) {
        final shifted = instant.add(const Duration(hours: 3));
        final expected =
            '${shifted.year}'
            '${shifted.month.toString().padLeft(2, '0')}'
            '${shifted.day.toString().padLeft(2, '0')}';
        expect(clock.istanbulDayKey(instant), expected, reason: '$instant');
        instant = instant.add(const Duration(minutes: 7));
      }
    });
  });

  group('T-08 · SystemAppClock · UTC olmayan girdi', () {
    const clock = SystemAppClock();

    test('yerel DateTime aynı anın UTC karşılığı gibi işlenir '
        '(cihaz saat diliminden bağımsız)', () {
      for (final c in _cases) {
        final local = c.utc.toLocal();
        expect(local.isUtc, isFalse);
        expect(clock.istanbulDayKey(local), c.dayKey, reason: c.label);
        expect(clock.istanbulDay(local), c.day, reason: c.label);
        expect(
          clock.istanbulStartOfDay(local),
          c.startOfDay,
          reason: c.label,
        );
        expect(clock.istanbulStartOfDay(local).isUtc, isTrue);
      }
    });

    test('epoch milisaniyesinden kurulan yerel an aynı sonucu verir', () {
      final utc = DateTime.utc(2026, 10, 10, 21);
      final local = DateTime.fromMillisecondsSinceEpoch(
        utc.millisecondsSinceEpoch,
      );

      expect(clock.istanbulDayKey(local), clock.istanbulDayKey(utc));
      expect(clock.istanbulStartOfDay(local), clock.istanbulStartOfDay(utc));
    });
  });

  group('T-08 · SystemAppClock · nowUtc', () {
    test('UTC işaretlidir', () {
      expect(const SystemAppClock().nowUtc().isUtc, isTrue);
    });

    test('sistem saatini okur (çağrı öncesi ve sonrası arasında)', () {
      final before = DateTime.now().toUtc();
      final now = const SystemAppClock().nowUtc();
      final after = DateTime.now().toUtc();

      expect(now.isBefore(before), isFalse);
      expect(now.isAfter(after), isFalse);
    });

    test('const kurucu ve AppClock arayüzü', () {
      const a = SystemAppClock();
      const b = SystemAppClock();

      expect(identical(a, b), isTrue);
      expect(a, isA<AppClock>());
    });

    test('"bugün" nowUtc üzerinden tutarlı hesaplanır', () {
      const clock = SystemAppClock();
      final now = clock.nowUtc();
      final start = clock.istanbulStartOfDay(now);

      expect(clock.istanbulDayKey(start), clock.istanbulDayKey(now));
      expect(now.difference(start) < const Duration(days: 1), isTrue);
      expect(now.difference(start).isNegative, isFalse);
    });
  });

  group('T-08 · AppClock · Limits ile birlikte', () {
    test('Istanbul kayması Limits.istanbulUtcOffset = 3 sa', () {
      const clock = SystemAppClock();
      final boundary = DateTime.utc(
        2026,
        10,
        11,
      ).subtract(Limits.istanbulUtcOffset);

      expect(Limits.istanbulUtcOffset, const Duration(hours: 3));
      expect(clock.istanbulDayKey(boundary), '20261011');
      expect(
        clock.istanbulDayKey(
          boundary.subtract(const Duration(microseconds: 1)),
        ),
        '20261010',
      );
    });

    test('Limits.foundedMax saatin UTC yılını verir', () {
      final clock = FakeAppClock(DateTime.utc(2026, 10, 8));

      expect(Limits.foundedMax(clock), 2026);
    });

    test('Limits.foundedMax yıl değişiminde saatle birlikte ilerler', () {
      final clock = FakeAppClock(DateTime.utc(2026, 12, 31, 23, 59, 59));

      expect(Limits.foundedMax(clock), 2026);
      clock.advance(const Duration(seconds: 1));
      expect(Limits.foundedMax(clock), 2027);
    });
  });

  // Duyuru sayacının belge kimliği cihaz saatinden (`nowUtc`) üretilir; Rules
  // aynı günü sunucu saatinden (`request.time + 3 sa`) hesaplar. Cihaz saati
  // kayınca iki gün yalnızca Istanbul gün sınırının yakınında ayrışır — T-19
  // komşu gün yeniden denemesi bu özelliğe dayanır (CD-129, borç W-50).
  group('T-08 · AppClock · cihaz saati kayması ve sayaç günü', () {
    const clock = SystemAppClock();
    const tolerance = Limits.clockSkewTolerance;
    const day = Duration(days: 1);
    // Istanbul 2026-10-11 00:00 = 2026-10-10 21:00Z.
    final boundary = DateTime.utc(2026, 10, 10, 21);
    const skews = <Duration>[
      Duration(minutes: -5),
      Duration(minutes: -2),
      Duration(seconds: -1),
      Duration.zero,
      Duration(seconds: 1),
      Duration(minutes: 2),
      Duration(minutes: 5),
    ];

    /// [device] anının en yakın Istanbul gün sınırına uzaklığı.
    Duration distanceToBoundary(DateTime device) {
      final start = clock.istanbulStartOfDay(device);
      final sinceStart = device.difference(start);
      final untilNext = start.add(day).difference(device);
      return sinceStart < untilNext ? sinceStart : untilNext;
    }

    test('tolerans içindeki kaymada günler yalnızca gün sınırına tolerans '
        'kadar yakınken ayrışır; sunucu günü komşu gündür', () {
      var mismatches = 0;

      for (var s = -900; s <= 900; s += 15) {
        final server = boundary.add(Duration(seconds: s));
        for (final skew in skews) {
          expect(skew.abs(), lessThanOrEqualTo(tolerance));
          final device = server.add(skew);
          final deviceKey = clock.istanbulDayKey(device);
          final serverKey = clock.istanbulDayKey(server);
          if (deviceKey == serverKey) continue;
          mismatches++;

          final start = clock.istanbulStartOfDay(device);
          final previousKey = clock.istanbulDayKey(
            start.subtract(const Duration(microseconds: 1)),
          );
          final nextKey = clock.istanbulDayKey(start.add(day));

          expect(
            distanceToBoundary(device),
            lessThanOrEqualTo(tolerance),
            reason: 'sunucu=$server, kayma=$skew',
          );
          expect(
            serverKey,
            skew.isNegative ? nextKey : previousKey,
            reason: 'sunucu=$server, kayma=$skew',
          );
        }
      }

      expect(mismatches, greaterThan(0), reason: 'tarama sınırı kapsamalı');
    });

    test('gün sınırından tolerans kadar uzaktaki cihaz, tolerans içindeki her '
        'kaymada sunucuyla aynı günü üretir', () {
      const margin = Duration(seconds: 1);

      for (final device in [
        boundary.add(tolerance + margin),
        boundary.subtract(tolerance + margin),
        boundary.add(const Duration(hours: 12)),
      ]) {
        expect(distanceToBoundary(device), greaterThan(tolerance));
        for (final skew in skews) {
          final server = device.subtract(skew);

          expect(
            clock.istanbulDayKey(server),
            clock.istanbulDayKey(device),
            reason: 'cihaz=$device, kayma=$skew',
          );
        }
      }
    });

    test('sınır örnekleri: cihaz 5 dk ileride / geride', () {
      // Sunucu 23:58 Istanbul (10 Eki), cihaz 5 dk ileride → 00:03 (11 Eki).
      final serverBefore = boundary.subtract(const Duration(minutes: 2));
      // Sunucu 00:02 Istanbul (11 Eki), cihaz 5 dk geride → 23:57 (10 Eki).
      final serverAfter = boundary.add(const Duration(minutes: 2));

      expect(clock.istanbulDayKey(serverBefore), '20261010');
      expect(clock.istanbulDayKey(serverBefore.add(tolerance)), '20261011');
      expect(clock.istanbulDayKey(serverAfter), '20261011');
      expect(
        clock.istanbulDayKey(serverAfter.subtract(tolerance)),
        '20261010',
      );
    });

    test('PLAN §10.4 "gece yarısı kenarı" satırı pencereyi '
        'Limits.clockSkewTolerance ile tanımlar (Limits dışı sabit yok)', () {
      final row = readRepoFile('docs/PLAN.md')
          .split('\n')
          .singleWhere((line) => line.startsWith('| gece yarısı kenarı |'));

      expect(row, contains('`Limits.clockSkewTolerance`'));
      expect(row, contains('`AnnouncementCounterRepository.adjacentDayKey`'));
      expect(row, contains('`getToday`'));
      expect(row, contains('W-50'));
      expect(row, isNot(contains('23:58')));
    });
  });
}
