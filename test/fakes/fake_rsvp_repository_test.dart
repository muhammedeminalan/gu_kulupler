// T-22 · FakeRsvpRepository sözleşmesi (PLAN §16.3): `rsvps`,
// `watchMineController(eventId, userId)`, `capacityRace`, `reminderWrites`;
// gerçek repository + Security Rules sonuçlarını izler
// (docs/plans/T-22.md §6.3–§6.4).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fixtures/demo_data.dart';
import '../fixtures/event_model_fixtures.dart';
import '../fixtures/rsvp_model_fixtures.dart';
import '../helpers/fake_app_clock.dart';
import 'fake_event_repository.dart';
import 'fake_rsvp_repository.dart';

const String _me = 'u_ayse';
const String _other = 'u_can';

void main() {
  late FakeAppClock clock;
  late FakeEventRepository events;
  late FakeRsvpRepository fake;

  setUp(() {
    clock = FakeAppClock(DemoDataFixture.today);
    events = FakeEventRepository(clock);
    EventModelFixtures.all().forEach(events.put);
    fake = FakeRsvpRepository(clock, events: events);
    for (final id in ['e03', 'e01', 'e18']) {
      RsvpModelFixtures.ofEvent(id).forEach(fake.put);
    }
  });

  /// Kontenjanı [capacity] olan, kayıtsız, yayındaki etkinlik `e_cap`.
  void putEvent({int? capacity}) => events.put(
    EventModelFixtures.e01.copyWith(
      id: 'e_cap',
      capacity: capacity,
      clearCapacity: capacity == null,
      goingCount: 0,
      waitlistCount: 0,
      attendedCount: 0,
    ),
  );

  Future<FirestoreResult<RsvpModel>> join(String eventId, String userId) =>
      fake.join(
        eventId: eventId,
        clubId: events.events[eventId]?.clubId ?? 'c01',
        userId: userId,
        reminder: ReminderOption.oneHour,
      );

  (int, int, int) counters(String eventId) {
    final event = events.events[eventId]!;
    return (event.goingCount, event.waitlistCount, event.attendedCount);
  }

  FirestoreRuleCode? codeOf(FirestoreResult<Object?> result) =>
      switch (result) {
        FirebaseFailure(:final FirestoreFailureDetail detail) => detail.code,
        _ => null,
      };

  group('T-22 · FakeRsvpRepository', () {
    test(
      'kontenjan 1: ilk katılım going, ikincisi waitlist (waitlistAt = '
      'şimdi); sayaçlar kayıtla birlikte; bilet kodu desende ve farklı',
      () async {
        putEvent(capacity: 1);

        final first = (await join('e_cap', _me)).dataOrNull!;
        final second = (await join('e_cap', _other)).dataOrNull!;

        expect((first.status, first.waitlistAt), (RsvpStatus.going, null));
        expect(
          (second.status, second.waitlistAt),
          (
            RsvpStatus.waitlist,
            clock.nowUtc(),
          ),
        );
        expect(counters('e_cap'), (1, 1, 0));
        expect(first.ticketCode, matches(FirestoreIds.ticketCodePattern));
        expect(first.ticketCode, isNot(second.ticketCode));
        expect(fake.rsvps['e_cap_$_me'], first);
      },
    );

    test('capacityRace: son yer aynı anda başkasına gider → katılım waitlist '
        'olur; bayrak tek seferliktir', () async {
      putEvent(capacity: 1);
      fake.capacityRace = true;

      final raced = (await join('e_cap', _me)).dataOrNull!;

      expect(raced.status, RsvpStatus.waitlist);
      expect(counters('e_cap'), (1, 1, 0));
      expect(fake.capacityRace, isFalse);
    });

    test('vazgeç → yeniden katıl: aynı kayıt ve bilet kodu, sayaç ±1; boşalan '
        'yere kimse otomatik alınmaz (Mod C) ve yeniden katılan önde bekleyeni '
        'atlayamaz (CD-144)', () async {
      putEvent(capacity: 1);
      final ticket = (await join('e_cap', _me)).dataOrNull!.ticketCode;
      await join('e_cap', _other);

      expect(
        (await fake.cancel(eventId: 'e_cap', userId: _me)).isSuccess,
        isTrue,
      );
      expect(counters('e_cap'), (0, 1, 0));
      expect(fake.rsvps['e_cap_$_other']!.status, RsvpStatus.waitlist);
      // Zaten vazgeçilmiş: yazımsız başarı.
      expect(
        (await fake.cancel(eventId: 'e_cap', userId: _me)).isSuccess,
        isTrue,
      );
      expect(counters('e_cap'), (0, 1, 0));

      // Yer boş ama önde bekleyen var: boşalan yer önce onundur.
      final again = (await join('e_cap', _me)).dataOrNull!;
      expect((again.status, again.ticketCode), (RsvpStatus.waitlist, ticket));
      expect(counters('e_cap'), (0, 2, 0));
      expect(
        (await join('e_cap', _me)).errorOrNull,
        FirestoreError.conflict,
      );
    });

    test('katılım reddi: taslak / iptal / kayıt kapalı registrationClosed, '
        'bitmiş eventEnded, olmayan permissionDenied, başka kulüp '
        'invalidArgument; yoklaması alınmış kayıttan vazgeçilemez', () async {
      expect(
        codeOf(await join('e22', _me)),
        FirestoreRuleCode.registrationClosed,
      );
      expect(
        codeOf(await join('e21', _me)),
        FirestoreRuleCode.registrationClosed,
      );
      expect(codeOf(await join('e19', _me)), FirestoreRuleCode.eventEnded);
      expect(
        (await join('yok', _me)).errorOrNull,
        FirestoreError.permissionDenied,
      );
      expect(
        (await fake.join(
          eventId: 'e01',
          clubId: 'c02',
          userId: _me,
          reminder: ReminderOption.none,
        )).errorOrNull,
        FirestoreError.invalidArgument,
      );
      expect(
        (await fake.cancel(eventId: 'e18', userId: 'u_mehmet')).errorOrNull,
        FirestoreError.failedPrecondition,
      );
      expect(
        (await fake.cancel(eventId: 'e01', userId: 'u_yok')).errorOrNull,
        FirestoreError.notFound,
      );
    });

    test('setReminder dört değeri yazar ve kaydeder; katılmamış / vazgeçmiş '
        'kayıt notMember', () async {
      for (final reminder in ReminderOption.values) {
        await fake.setReminder(
          eventId: 'e01',
          userId: 'u_mehmet',
          reminder: reminder,
        );
      }

      expect(
        fake.reminderWrites.map((write) => write.reminder),
        ReminderOption.values,
      );
      expect(fake.rsvps['e01_u_mehmet']!.reminder, ReminderOption.oneDay);
      expect(
        codeOf(
          await fake.setReminder(
            eventId: 'e01',
            userId: _me,
            reminder: ReminderOption.oneHour,
          ),
        ),
        FirestoreRuleCode.notMember,
      );
    });

    test('watchMine: ilk anlık görüntü, katılım ve elle yazılan olay akar; '
        'dinleyici sayılır', () async {
      putEvent();
      final seen = <FirestoreResult<RsvpModel?>>[];
      final subscription = fake
          .watchMine(eventId: 'e_cap', userId: _me)
          .listen(seen.add);
      await pumpEventQueue();
      expect(fake.activeListeners, 1);

      await join('e_cap', _me);
      fake
          .watchMineController('e_cap', _me)
          .add(const FirebaseFailure(FirestoreError.unavailable));
      await pumpEventQueue();
      await subscription.cancel();

      expect(seen.first.dataOrNull, isNull);
      expect(seen[1].dataOrNull?.status, RsvpStatus.going);
      expect(seen.last.errorOrNull, FirestoreError.unavailable);
      expect(fake.activeListeners, 0);
    });

    test('okumalar: listMine en yeni üstte (vazgeçilmiş dahil), bekleme sırası '
        "waitlistAt'tan, bilet kodu etkinliğe kapsamlı", () async {
      final waitlist = RsvpModelFixtures.ofEvent(
        'e03',
      ).where((rsvp) => rsvp.status == RsvpStatus.waitlist).toList();

      final positions = [
        for (final rsvp in waitlist)
          (await fake.waitlistPosition(
            eventId: 'e03',
            clubId: 'c03',
            waitlistAtUtc: rsvp.waitlistAt!,
          )).dataOrNull,
      ];
      expect(positions, [1, 2, 3, 4]);

      final mine = (await fake.listMine('u_mehmet')).dataOrNull!;
      expect(
        mine.map((rsvp) => rsvp.id),
        containsAll(['e01_u_mehmet', 'e18_u_mehmet']),
      );
      for (var i = 1; i < mine.length; i++) {
        expect(mine[i - 1].createdAt!.isBefore(mine[i].createdAt!), isFalse);
      }

      final ticket = RsvpModelFixtures.e01Mehmet.ticketCode;
      expect(
        (await fake.findByTicket(
          eventId: 'e01',
          clubId: 'c01',
          code: ticket,
        )).dataOrNull,
        RsvpModelFixtures.e01Mehmet,
      );
      expect(
        (await fake.findByTicket(
          eventId: 'e03',
          clubId: 'c03',
          code: ticket,
        )).dataOrNull,
        isNull,
      );
      expect(
        (await fake.findByTicket(
          eventId: 'e01',
          clubId: 'c01',
          code: 'GU-0000',
        )).dataOrNull,
        isNull,
      );
    });

    test('güvenlik incelemesi (CD-144): bitmiş etkinlikte vazgeçilemez '
        '(eventEnded); kopyalanmış bilet kodu belirsiz eşleşme '
        '(failedPrecondition)', () async {
      putEvent();
      final mine = (await join('e_cap', _me)).dataOrNull!;
      fake.put(
        mine.copyWith(id: 'e_cap_$_other', userId: _other),
      );

      expect(
        (await fake.findByTicket(
          eventId: 'e_cap',
          clubId: mine.clubId,
          code: mine.ticketCode,
        )).errorOrNull,
        FirestoreError.failedPrecondition,
      );

      clock.set(events.events['e_cap']!.endsAt);
      expect(
        codeOf(await fake.cancel(eventId: 'e_cap', userId: _me)),
        FirestoreRuleCode.eventEnded,
      );
      expect(fake.rsvps['e_cap_$_me']!.status, RsvpStatus.going);
    });

    test('failNext tek seferliktir (yetki reddi: üyelere özel etkinlik, '
        'katılımcıya kapalı bekleme sırası)', () async {
      fake.failNext(FirestoreError.permissionDenied);

      expect(
        (await join('e02', _me)).errorOrNull,
        FirestoreError.permissionDenied,
      );
      expect(counters('e02'), (
        EventModelFixtures.e02.goingCount,
        EventModelFixtures.e02.waitlistCount,
        EventModelFixtures.e02.attendedCount,
      ));
      expect((await join('e02', _me)).isSuccess, isTrue);
      expect(fake.callsTo('join'), hasLength(2));
    });
  });
}
