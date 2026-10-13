// T-19 · FakeAnnouncementCounterRepository sözleşmesi (PLAN §16.3): `counts`;
// gerçek repository'nin gün ve hak kurallarını izler (Q-10, CD-129).
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/fake_app_clock.dart';
import 'fake_announcement_counter_repository.dart';
import 'register_fakes.dart';

const String _club = 'c01';

void main() {
  late FakeAppClock clock;
  late FakeAnnouncementCounterRepository fake;

  setUp(() {
    // 13 Ekim 2026 12:00 Istanbul: gün sınırı penceresinin dışında.
    clock = FakeAppClock(DateTime.utc(2026, 10, 13, 9));
    fake = FakeAnnouncementCounterRepository(clock);
  });

  group('T-19 · FakeAnnouncementCounterRepository', () {
    test('AnnouncementCounterRepository arayüzünü uygular; '
        'registerDefaultFakes kaydeder', () {
      addTearDown(GetIt.I.reset);
      registerDefaultFakes();
      expect(
        GetIt.I<AnnouncementCounterRepository>(),
        isA<FakeAnnouncementCounterRepository>(),
      );
    });

    test('sayaç yokken getToday null, hak günlük sınırdır; tryBump sınırda '
        'durur ve kalan hak sıfırın altına inmez', () async {
      expect((await fake.getToday(_club)).dataOrNull, isNull);
      expect(
        (await fake.remainingToday(_club)).dataOrNull,
        Limits.announcementDailyLimit,
      );

      expect(fake.tryBump(_club), isTrue);
      expect(fake.tryBump(_club), isTrue);
      expect(fake.tryBump(_club), isFalse);

      expect(fake.counts, {'c01_20261013': Limits.announcementDailyLimit});
      final today = (await fake.getToday(_club)).dataOrNull!;
      expect(
        (today.id, today.day, today.count),
        ('c01_20261013', '2026-10-13', 2),
      );
      expect((await fake.remainingToday(_club)).dataOrNull, 0);
      // Elle kurulan taşkın sayaçta kalan hak eksiye düşmez.
      fake.counts[fake.keyOf(_club)] = 5;
      expect((await fake.remainingToday(_club)).dataOrNull, 0);
    });

    test('gün Istanbul saatiyle değişir: 20:59Z dün, 21:00Z yeni gün (hak '
        'yenilenir)', () async {
      clock.set(DateTime.utc(2026, 10, 13, 20, 50));
      fake.counts[fake.keyOf(_club)] = 2;
      expect(fake.keyOf(_club), 'c01_20261013');

      clock.set(DateTime.utc(2026, 10, 13, 21, 30));

      expect(fake.keyOf(_club), 'c01_20261014');
      expect((await fake.remainingToday(_club)).dataOrNull, 2);
    });

    test('gün sınırı penceresinde (±5 dk) komşu günün sayacı büyükse o '
        'döner: ipucu fazla hak vaat etmez', () async {
      fake.counts['c01_20261013'] = 2;
      // 14 Ekim 00:02 Istanbul: cihaz günü yeni, komşu gün dün.
      clock.set(DateTime.utc(2026, 10, 13, 21, 2));

      final shown = (await fake.getToday(_club)).dataOrNull!;

      expect((shown.day, shown.count), ('2026-10-13', 2));
      expect((await fake.remainingToday(_club)).dataOrNull, 0);
      // Pencere dışında yalnızca cihaz günü okunur.
      clock.set(DateTime.utc(2026, 10, 13, 21, 6));
      expect((await fake.getToday(_club)).dataOrNull, isNull);
    });

    test('failNext ve geçersiz kimlik: hata döner, sayaç değişmez; çağrılar '
        'günlüğe düşer', () async {
      fake.failNext(FirestoreError.unavailable);
      expect(
        (await fake.remainingToday(_club)).errorOrNull,
        FirestoreError.unavailable,
      );
      expect(
        (await fake.getToday('')).errorOrNull,
        FirestoreError.invalidArgument,
      );
      expect(fake.counts, isEmpty);
      expect(fake.calls.map((call) => call.method), [
        'remainingToday',
        'getToday',
      ]);
    });
  });
}
