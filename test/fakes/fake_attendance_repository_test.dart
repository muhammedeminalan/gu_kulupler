// T-30 · FakeAttendanceRepository sözleşmesi (PLAN §16.3): yoklama (K-G
// penceresi, `attendedCount ±1`), bilet okutma (`ScanOutcome`; kopyalanmış
// kod W-79), toplu yoklama ve terfi (`promoted`) — paylaşılan
// `FakeRsvpRepository` + `FakeEventRepository` üzerinde, gerçek
// `FirebaseAttendanceRepository` ile aynı hata eşlemesi.
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';

import '../fixtures/event_model_fixtures.dart';
import '../helpers/fake_app_clock.dart';
import 'fake_attendance_repository.dart';
import 'fake_event_repository.dart';
import 'fake_rsvp_repository.dart';
import 'register_fakes.dart';

const String _eventId = 'e_live';
const String _clubId = 'c01';
const String _manager = 'u_board';
final DateTime _now = DateTime.utc(2026, 10, 13, 9);

RsvpModel _rsvp(
  String uid,
  RsvpStatus status, {
  String code = 'GU-AAAA-AAAB',
  DateTime? waitlistAt,
}) => RsvpModel(
  eventId: _eventId,
  clubId: _clubId,
  userId: uid,
  status: status,
  ticketCode: code,
  waitlistAt: waitlistAt,
);

void main() {
  late FakeAppClock clock;
  late FakeEventRepository events;
  late FakeRsvpRepository rsvps;
  late FakeAttendanceRepository fake;

  /// Şimdi başlayan, 2 kontenjanlı yayındaki etkinlik (yoklama penceresi
  /// açık).
  void putEvent({int going = 1, int waitlist = 0, int attended = 0}) =>
      events.put(
        EventModelFixtures.e01.copyWith(
          id: _eventId,
          clubId: _clubId,
          startsAt: _now,
          endsAt: _now.add(const Duration(hours: 2)),
          capacity: 2,
          goingCount: going,
          waitlistCount: waitlist,
          attendedCount: attended,
        ),
      );

  EventModel event() => events.events[_eventId]!;

  setUp(() {
    clock = FakeAppClock(_now);
    events = FakeEventRepository(clock);
    rsvps = FakeRsvpRepository(clock, events: events);
    fake = FakeAttendanceRepository(clock, rsvps: rsvps);
  });

  test('AttendanceRepository arayüzünü uygular; registerDefaultFakes kayıtlı '
      'FakeRsvpRepository ile paylaştırarak kaydeder', () {
    addTearDown(GetIt.I.reset);
    registerDefaultFakes();

    final registered = GetIt.I<AttendanceRepository>();
    expect(registered, isA<FakeAttendanceRepository>());
    expect(
      (registered as FakeAttendanceRepository).rsvps,
      same(GetIt.I<RsvpRepository>()),
    );
  });

  test('elle yoklama: going → attended (+1, scannedBy) ve geri al (−1, '
      'alanlar boşalır); beklenmeyen durum conflict', () async {
    putEvent();
    rsvps.put(_rsvp('u1', RsvpStatus.going));

    final marked = await fake.markAttended(
      eventId: _eventId,
      userId: 'u1',
      actorId: _manager,
      attended: true,
    );
    expect(marked.isSuccess, isTrue);
    expect(event().attendedCount, 1);
    expect(rsvps.rsvps['${_eventId}_u1']?.scannedBy, _manager);

    final again = await fake.markAttended(
      eventId: _eventId,
      userId: 'u1',
      actorId: _manager,
      attended: true,
    );
    final undone = await fake.markAttended(
      eventId: _eventId,
      userId: 'u1',
      actorId: _manager,
      attended: false,
    );

    expect(again.errorOrNull, FirestoreError.conflict);
    expect(undone.isSuccess, isTrue);
    expect(event().attendedCount, 0);
    expect(rsvps.rsvps['${_eventId}_u1']?.status, RsvpStatus.going);
    expect(rsvps.rsvps['${_eventId}_u1']?.scannedBy, isNull);
  });

  test('K-G penceresi dışında yoklama attendanceWindowClosed; toplu yoklama '
      'ilk kayıtta durur', () async {
    putEvent();
    rsvps.put(_rsvp('u1', RsvpStatus.going));
    clock.advance(const Duration(days: 1));

    final single = await fake.markAttended(
      eventId: _eventId,
      userId: 'u1',
      actorId: _manager,
      attended: true,
    );
    final bulk = await fake.markAllAttended(
      eventId: _eventId,
      clubId: _clubId,
      actorId: _manager,
    );

    for (final result in [single, bulk]) {
      expect(result.errorOrNull, FirestoreError.ruleViolation);
      expect(
        (result as FirebaseFailure).detail,
        const FirestoreFailureDetail(FirestoreRuleCode.attendanceWindowClosed),
      );
    }
    expect(event().attendedCount, 0);
  });

  test(
    'bilet okutma: geçerli → valid (+1); yeniden → alreadyScanned; '
    'başka etkinliğin / bozuk / kopyalanmış (W-79) bileti → invalid',
    () async {
      putEvent(going: 3);
      rsvps
        ..put(_rsvp('u1', RsvpStatus.going))
        ..put(_rsvp('u2', RsvpStatus.going, code: 'GU-BBBB-CCCC'))
        ..put(_rsvp('u3', RsvpStatus.going, code: 'GU-BBBB-CCCC'));
      Future<ScanOutcome?> scan(String payload) async => (await fake.scanTicket(
        eventId: _eventId,
        clubId: _clubId,
        qrPayload: payload,
        actorId: _manager,
      )).dataOrNull;

      expect(
        await scan(FirestoreIds.ticketQrPayload(_eventId, 'GU-AAAA-AAAB')),
        ScanOutcome.valid,
      );
      expect(
        await scan(FirestoreIds.ticketQrPayload(_eventId, 'GU-AAAA-AAAB')),
        ScanOutcome.alreadyScanned,
      );
      expect(
        await scan(FirestoreIds.ticketQrPayload('e_other', 'GU-AAAA-AAAB')),
        ScanOutcome.invalid,
      );
      expect(await scan('bozuk'), ScanOutcome.invalid);
      expect(
        await scan(FirestoreIds.ticketQrPayload(_eventId, 'GU-BBBB-CCCC')),
        ScanOutcome.invalid,
      );
      expect(event().attendedCount, 1);
    },
  );

  test('terfi: waitlist → going (+1 / −1, promoted); dolu kontenjan '
      'capacityFull; bekleme listesinde olmayan conflict', () async {
    putEvent(waitlist: 2);
    rsvps
      ..put(_rsvp('u1', RsvpStatus.going))
      ..put(_rsvp('u2', RsvpStatus.waitlist, waitlistAt: _now))
      ..put(_rsvp('u3', RsvpStatus.waitlist, waitlistAt: _now));

    final notWaiting = await fake.promote(
      eventId: _eventId,
      userId: 'u1',
      actorId: _manager,
    );
    final promoted = await fake.promote(
      eventId: _eventId,
      userId: 'u2',
      actorId: _manager,
    );
    final full = await fake.promote(
      eventId: _eventId,
      userId: 'u3',
      actorId: _manager,
    );

    expect(promoted.isSuccess, isTrue);
    expect((event().goingCount, event().waitlistCount), (2, 1));
    expect(fake.promoted, [
      (eventId: _eventId, userId: 'u2', actorId: _manager),
    ]);
    expect(
      (full as FirebaseFailure).detail,
      const FirestoreFailureDetail(FirestoreRuleCode.capacityFull),
    );
    expect(notWaiting.errorOrNull, FirestoreError.conflict);
  });

  test(
    'yöneticinin kendi kaydı (rules-spec §3.8): yoklama ve terfi '
    'invalidArgument, toplu yoklamada kümeye girmez; sayaç oynamaz',
    () async {
      putEvent(going: 2, waitlist: 1);
      rsvps
        ..put(_rsvp('u1', RsvpStatus.going))
        ..put(_rsvp(_manager, RsvpStatus.going, code: 'GU-AAAA-AAAC'));

      final self = await fake.markAttended(
        eventId: _eventId,
        userId: _manager,
        actorId: _manager,
        attended: true,
      );
      final selfPromote = await fake.promote(
        eventId: _eventId,
        userId: _manager,
        actorId: _manager,
      );
      expect(self.errorOrNull, FirestoreError.invalidArgument);
      expect(selfPromote.errorOrNull, FirestoreError.invalidArgument);
      expect(event().attendedCount, 0);

      final bulk = await fake.markAllAttended(
        eventId: _eventId,
        clubId: _clubId,
        actorId: _manager,
      );
      expect(bulk.dataOrNull?.succeeded, ['u1']);
      expect(bulk.dataOrNull?.failed, isEmpty);
      expect(event().attendedCount, 1);
    },
  );

  test('katılımcı listesi status, waitlistAt, userId sırasıyla; boş durum '
      'kümesi boş liste; failNext bir sonraki çağrıyı düşürür', () async {
    putEvent();
    rsvps
      ..put(_rsvp('u2', RsvpStatus.waitlist, waitlistAt: _now))
      ..put(_rsvp('u1', RsvpStatus.going));

    final all = await fake.listParticipants(eventId: _eventId, clubId: _clubId);
    final none = await fake.listParticipants(
      eventId: _eventId,
      clubId: _clubId,
      statuses: const {},
    );
    fake.failNext(FirestoreError.permissionDenied);
    final denied = await fake.promote(
      eventId: _eventId,
      userId: 'u2',
      actorId: _manager,
    );

    expect([for (final r in all.dataOrNull!) r.userId], ['u1', 'u2']);
    expect(none.dataOrNull, isEmpty);
    expect(denied.errorOrNull, FirestoreError.permissionDenied);
    expect(event().waitlistCount, 0);
  });
}
