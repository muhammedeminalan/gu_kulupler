// T-30 · AttendanceRepository (yönetici tarafı): elle yoklama ve geri alma
// (`going ↔ attended`), bilet okutma (QR ayrıştırma → bilet araması → aynı
// yoklama işlemi; kopyalanmış kod W-79), toplu yoklama (kayıt başına ayrı
// işlem), bekleme listesinden terfi (`waitlist → going` + `waitlist_promoted`
// bildirimi aynı işlemde), katılımcı listesi. Her geçişte kayıt, etkinlik
// sayacı (tam ±1) ve sayaç işaretçisi yan belgesi
// `events/{eventId}/private/counter` tek transaction'da ve ham yükleriyle
// (W-64, W-77); K-G yoklama penceresinin iki ucu; reddedilen durumlarda
// hiçbir yazım (PLAN §10.4; rules-spec §3.7, §3.8; docs/plans/T-30.md §4 a,
// b; D-10, Q-09).
//
// Mutlu yollar `fake_cloud_firestore` ile; işlem yazımları kayıt tutan servis
// çiftiyle (`test/fakes/recording_firestore_service.dart`). Bildirim gerçek
// `ClientFanOutDispatcher` + `FirebaseNotificationRepository` ile aynı
// kayıtçıdan yazılır: belgenin terfi işleminin içinde olduğu yazım listesinden
// görülür. Yetki (danışman, başka kulübün yöneticisi) Security Rules'tadır;
// burada yalnızca reddin `permissionDenied` olarak geçtiği doğrulanır.
import 'package:cloud_firestore/cloud_firestore.dart'
    show DocumentReference, Transaction;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/fake_app_clock.dart';
import '../fakes/fake_ticket_code_generator.dart';
import '../fakes/recording_firestore_service.dart';
import '../fakes/sdk_firestore_stubs.dart';
import '../helpers/plan_repository_table.dart';
import '../helpers/plan_service_table.dart';

const String _interface =
    'packages/gu_data/lib/src/repositories/attendance_repository.dart';
const String _implementation =
    'packages/gu_data/lib/src/repositories/firebase_attendance_repository.dart';

const String _clubId = 'c01';
const String _eventId = 'e01';
const String _eventPath = 'events/e01';
const String _counterPath = 'events/e01/private/counter';
const String _actor = 'u_board';
const String _ayse = 'u_ayse';
const String _can = 'u_can';
const String _ayseRsvp = 'rsvps/e01_u_ayse';

/// Ayşe'nin bilet kodu (`FirestoreIds.ticketCodePattern`).
const String _ticket = 'GU-ABCD-EFGH';

/// Sahte saatin gösterdiği an: etkinlik 1 sa sonra başlar (pencere açık).
final DateTime _now = DateTime.utc(2026, 10, 20, 14);
final DateTime _startsAt = DateTime.utc(2026, 10, 20, 15);
final DateTime _endsAt = DateTime.utc(2026, 10, 20, 17);
final DateTime _seededAt = DateTime.utc(2026, 10, 1, 8);

Map<String, Object?> _write(String op, String path, Json data) => {
  'op': op,
  'path': path,
  'data': data,
};

/// Yan belge yükü: işaretçi [userId] kaydını gösterir (W-64).
Map<String, Object?> _pointer(String userId) => _write('set', _counterPath, {
  'clubId': _clubId,
  'lastRsvpRef': 'rsvps/e01_$userId',
  'updatedAt': serverTimestampMark,
});

/// Yoklama işleminin üç yazımı (kayıt, sayaç, yan belge).
List<Map<String, Object?>> _attendWrites(
  String userId, {
  bool attended = true,
}) => [
  _write('update', 'rsvps/e01_$userId', {
    'status': attended ? 'attended' : 'going',
    'scannedAt': attended ? serverTimestampMark : null,
    'scannedBy': attended ? _actor : null,
    'updatedAt': serverTimestampMark,
  }),
  _write('update', _eventPath, {
    'attendedCount': incrementMark,
    'updatedAt': serverTimestampMark,
  }),
  _pointer(userId),
];

/// Bildirim çözümü terfide kullanılmaz.
final class _NoRecipients extends Fake implements RecipientResolver {}

/// Terfi bildirimi her zaman [FirestoreError.unavailable] ile başarısız olur.
final class _FailingDispatcher extends Fake implements NotificationDispatcher {
  @override
  Future<FirestoreResult<DispatchReport>> notifyWaitlistPromotedInTransaction({
    required String eventId,
    required String clubId,
    required String userId,
    required Transaction transaction,
  }) async => const FirebaseFailure(FirestoreError.unavailable);
}

/// [runTransaction] gövdesinin istisnayla bitip bitmediğini kaydeder (SDK
/// gövdesi istisnayla biten işlemi commit etmez); diğer üyeler [_inner]'a.
final class _BodyObservingService extends Fake implements FirestoreService {
  _BodyObservingService(this._inner);

  final FirestoreService _inner;
  bool bodyThrew = false;

  @override
  DocumentReference<Json> doc(String collectionPath, String id) =>
      _inner.doc(collectionPath, id);

  @override
  Future<FirestoreResult<T>> runTransaction<T>(
    Future<T> Function(Transaction tx) body,
  ) => _inner.runTransaction((tx) async {
    try {
      return await body(tx);
    } on Object {
      bodyThrew = true;
      rethrow;
    }
  });
}

void main() {
  late FakeFirebaseFirestore db;
  late RecordingFirestoreService service;
  late FakeAppClock clock;
  late AttendanceRepository repository;

  AttendanceRepository repositoryOn(FirestoreService firestore) =>
      FirebaseAttendanceRepository(
        firestore,
        FirebaseRsvpRepository(firestore, FakeTicketCodeGenerator(), clock),
        ClientFanOutDispatcher(
          writer: FirebaseNotificationRepository(firestore),
          recipients: _NoRecipients(),
        ),
        clock,
      );

  Future<Json?> read(String path) async => (await db.doc(path).get()).data();

  /// Etkinliğin `[goingCount, waitlistCount, attendedCount]` sayaçları.
  Future<List<Object?>> counters() async {
    final event = (await read(_eventPath))!;
    return [
      event['goingCount'],
      event['waitlistCount'],
      event['attendedCount'],
    ];
  }

  List<Map<String, Object?>> writes() => [
    for (final write in service.writes)
      _write(write.op, write.path, write.data),
  ];

  Future<void> seedEvent({
    String clubId = _clubId,
    int? capacity,
    int goingCount = 2,
    int waitlistCount = 1,
    int attendedCount = 0,
    EventStatus status = EventStatus.published,
    bool isDeleted = false,
    DateTime? endsAt,
  }) => db
      .doc(_eventPath)
      .set(
        EventModel(
          id: _eventId,
          clubId: clubId,
          createdBy: 'u_pres',
          title: 'Flutter Atölyesi',
          type: EventType.training,
          startsAt: _startsAt,
          endsAt: endsAt ?? _endsAt,
          coverPalette: ClubPalette.red,
          coverPattern: ClubPattern.dots,
          capacity: capacity,
          status: status,
          goingCount: goingCount,
          waitlistCount: waitlistCount,
          attendedCount: attendedCount,
          createdAt: _seededAt,
          updatedAt: _seededAt,
          isDeleted: isDeleted,
        ).toJson(),
      );

  Future<void> seedRsvp(
    String userId,
    RsvpStatus status, {
    String ticketCode = _ticket,
    String eventId = _eventId,
    String? storedUserId,
    DateTime? waitlistAt,
    String? scannedBy,
  }) => db
      .doc('rsvps/${_eventId}_$userId')
      .set(
        RsvpModel(
          eventId: eventId,
          clubId: _clubId,
          userId: storedUserId ?? userId,
          ticketCode: ticketCode,
          status: status,
          waitlistAt: waitlistAt,
          scannedAt: scannedBy == null ? null : _seededAt,
          scannedBy: scannedBy,
          createdAt: _seededAt,
          updatedAt: _seededAt,
        ).toJson(),
      );

  Future<FirestoreResult<void>> mark(String userId, {bool attended = true}) =>
      repository.markAttended(
        eventId: _eventId,
        userId: userId,
        actorId: _actor,
        attended: attended,
      );

  Future<FirestoreResult<ScanOutcome>> scan(String qrPayload) =>
      repository.scanTicket(
        eventId: _eventId,
        clubId: _clubId,
        qrPayload: qrPayload,
        actorId: _actor,
      );

  Future<FirestoreResult<void>> promote(String userId) =>
      repository.promote(eventId: _eventId, userId: userId, actorId: _actor);

  void expectViolation(
    FirestoreResult<Object?> result,
    FirestoreRuleCode code,
  ) {
    expect(result.errorOrNull, FirestoreError.ruleViolation);
    expect(switch (result) {
      FirebaseFailure(:final detail) => detail,
      FirebaseSuccess() => null,
    }, FirestoreFailureDetail(code));
  }

  void expectNothingWritten() {
    expect(service.writes, isEmpty);
    expect(service.outsideWrites, 0);
  }

  setUp(() {
    db = FakeFirebaseFirestore();
    service = RecordingFirestoreService(FirebaseFirestoreService(db));
    clock = FakeAppClock(_now);
    repository = repositoryOn(service);
  });

  test('T-30 · PLAN §10.4 tablosundaki altı üye arayüzde aynı imzayla var; '
      'başka üye yok', () {
    final plan = readPlanRepositoryMembers('$AttendanceRepository');

    expect(plan.map((row) => row.member), [
      'watchParticipants',
      'listParticipants',
      'scanTicket',
      'markAttended',
      'markAllAttended',
      'promote',
    ]);
    expect(interfaceMembers(_interface, '$AttendanceRepository').toSet(), {
      for (final row in plan) normalizeDartSource(row.signature),
    });
  });

  test('T-30 · arayüzde ve uygulamada silme üyesi yok (D-10)', () {
    expect(deleteIdentifiersIn(_interface), isEmpty);
    expect(deleteIdentifiersIn(_implementation), isEmpty);
  });

  group('T-30 · markAttended', () {
    test('going → attended → going: kayıt + attendedCount ±1 + yan belge '
        'tek transaction; önce tüm okumalar (etkinlik, kayıt); işaretçi '
        'etkinlik belgesine yazılmaz (W-64)', () async {
      await seedEvent();
      await seedRsvp(_ayse, RsvpStatus.going);

      expect((await mark(_ayse)).isSuccess, isTrue);
      expect(service.transactions, 1);
      expect(service.outsideWrites, 0);
      expect(service.reads, [_eventPath, _ayseRsvp]);
      expect(writes(), _attendWrites(_ayse));
      expect(await counters(), [2, 1, 1]);
      expect(await read(_counterPath), {
        'clubId': _clubId,
        'lastRsvpRef': _ayseRsvp,
        'updatedAt': isA<Object>(),
      });
      expect((await read(_eventPath))!.containsKey('lastRsvpRef'), isFalse);
      expect((await read(_ayseRsvp))!['scannedBy'], _actor);

      service.writes.clear();
      expect((await mark(_ayse, attended: false)).isSuccess, isTrue);
      expect(writes(), _attendWrites(_ayse, attended: false));
      expect(await counters(), [2, 1, 0]);
      expect(await read(_ayseRsvp), containsPair('scannedAt', null));
    });

    // K-G: başlangıç − 2 sa … bitiş + 6 sa, iki uç dahil.
    final window = <String, (DateTime, bool)>{
      'açılış anı (başlangıç − 2 sa)': (
        _startsAt.subtract(Limits.attendanceWindowBefore),
        true,
      ),
      'açılıştan 1 sn önce': (
        _startsAt
            .subtract(Limits.attendanceWindowBefore)
            .subtract(const Duration(seconds: 1)),
        false,
      ),
      'kapanış anı (bitiş + 6 sa)': (
        _endsAt.add(Limits.attendanceWindowAfter),
        true,
      ),
      'kapanıştan 1 sn sonra': (
        _endsAt
            .add(Limits.attendanceWindowAfter)
            .add(const Duration(seconds: 1)),
        false,
      ),
    };
    for (final MapEntry(key: name, value: (at, open)) in window.entries) {
      test(
        'pencere · $name → ${open ? 'yazılır' : 'attendanceWindowClosed, '
                  'yazım yok'}',
        () async {
          await seedEvent();
          await seedRsvp(_ayse, RsvpStatus.going);
          clock.set(at);

          final result = await mark(_ayse);

          if (open) {
            expect(result.isSuccess, isTrue);
            expect(await counters(), [2, 1, 1]);
          } else {
            expectViolation(result, FirestoreRuleCode.attendanceWindowClosed);
            expectNothingWritten();
          }
        },
      );
    }

    final rejected =
        <
          String,
          ({
            Future<void> Function() seed,
            bool attended,
            FirestoreError error,
          })
        >{
          'zaten attended (true)': (
            seed: () => seedRsvp(_ayse, RsvpStatus.attended, scannedBy: _actor),
            attended: true,
            error: FirestoreError.conflict,
          ),
          'going kaydın geri alınması (false)': (
            seed: () => seedRsvp(_ayse, RsvpStatus.going),
            attended: false,
            error: FirestoreError.conflict,
          ),
          'bekleme listesi': (
            seed: () => seedRsvp(_ayse, RsvpStatus.waitlist),
            attended: true,
            error: FirestoreError.conflict,
          ),
          'vazgeçilmiş kayıt': (
            seed: () => seedRsvp(_ayse, RsvpStatus.cancelled),
            attended: true,
            error: FirestoreError.conflict,
          ),
          'kayıt yok': (
            seed: () async {},
            attended: true,
            error: FirestoreError.conflict,
          ),
          'kimlik başka (etkinlik, kullanıcı) çiftine ait (birleşim '
              'belirsizliği)': (
            seed: () => seedRsvp(_ayse, RsvpStatus.going, storedUserId: _can),
            attended: true,
            error: FirestoreError.permissionDenied,
          ),
        };
    for (final MapEntry(key: name, value: row) in rejected.entries) {
      test('$name → ${row.error.name}, yazım yok', () async {
        await seedEvent();
        await row.seed();

        final result = await mark(_ayse, attended: row.attended);

        expect(result.errorOrNull, row.error);
        expectNothingWritten();
      });
    }

    final events = <String, (Future<void> Function(), FirestoreError)>{
      'taslak etkinlik': (
        () => seedEvent(status: EventStatus.draft),
        FirestoreError.conflict,
      ),
      'iptal edilmiş etkinlik': (
        () => seedEvent(status: EventStatus.cancelled),
        FirestoreError.conflict,
      ),
      'silinmiş etkinlik': (
        () => seedEvent(isDeleted: true),
        FirestoreError.conflict,
      ),
      'etkinlik yok': (() async {}, FirestoreError.notFound),
    };
    for (final MapEntry(key: name, value: (seed, error)) in events.entries) {
      test('$name → ${error.name}, yazım yok', () async {
        await seed();
        await seedRsvp(_ayse, RsvpStatus.going);

        expect((await mark(_ayse)).errorOrNull, error);
        expectNothingWritten();
      });
    }

    test('geçersiz kimlik → invalidArgument, işlem açılmaz; Rules reddi '
        '(danışman, başka kulübün yöneticisi) permissionDenied olarak '
        'döner', () async {
      expect((await mark('a/b')).errorOrNull, FirestoreError.invalidArgument);
      expect(service.transactions, 0);

      final denied = repositoryOn(
        FirebaseFirestoreService(
          StubFirestore(error: firestoreException('permission-denied')),
        ),
      );
      final result = await denied.markAttended(
        eventId: _eventId,
        userId: _ayse,
        actorId: 'u_advisor',
        attended: true,
      );
      expect(result.errorOrNull, FirestoreError.permissionDenied);
    });
  });

  group('T-30 · scanTicket', () {
    test('geçerli bilet → valid: markAttended ile aynı üç yazım tek '
        'transaction (scannedBy = okutan)', () async {
      await seedEvent();
      await seedRsvp(_ayse, RsvpStatus.going);

      final result = await scan(
        FirestoreIds.ticketQrPayload(_eventId, _ticket),
      );

      expect(result.dataOrNull, ScanOutcome.valid);
      expect(service.transactions, 1);
      expect(writes(), _attendWrites(_ayse));
      expect(await counters(), [2, 1, 1]);
    });

    test('zaten okutulmuş → alreadyScanned, yazım yok', () async {
      await seedEvent(attendedCount: 1);
      await seedRsvp(_ayse, RsvpStatus.attended, scannedBy: _actor);

      final result = await scan(
        FirestoreIds.ticketQrPayload(_eventId, _ticket),
      );

      expect(result.dataOrNull, ScanOutcome.alreadyScanned);
      expectNothingWritten();
    });

    final invalid = <String, (String, Future<void> Function())>{
      'çözülemeyen yük': ('merhaba', () async {}),
      'başka sürüm': ('gu:ticket:v2:e01:$_ticket', () async {}),
      'başka etkinliğin bileti': (
        FirestoreIds.ticketQrPayload('e02', _ticket),
        () => seedRsvp(_ayse, RsvpStatus.going),
      ),
      'kayıt yok': (
        FirestoreIds.ticketQrPayload(_eventId, 'GU-ZZZZ-ZZZZ'),
        () => seedRsvp(_ayse, RsvpStatus.going),
      ),
      'vazgeçilmiş kayıt': (
        FirestoreIds.ticketQrPayload(_eventId, _ticket),
        () => seedRsvp(_ayse, RsvpStatus.cancelled),
      ),
      'bekleme listesi': (
        FirestoreIds.ticketQrPayload(_eventId, _ticket),
        () => seedRsvp(_ayse, RsvpStatus.waitlist),
      ),
      'kopyalanmış kod: iki kayıt aynı kodu taşıyor (W-79)': (
        FirestoreIds.ticketQrPayload(_eventId, _ticket),
        () async {
          await seedRsvp(_ayse, RsvpStatus.going);
          await seedRsvp(_can, RsvpStatus.going);
        },
      ),
    };
    for (final MapEntry(key: name, value: (payload, seed)) in invalid.entries) {
      test('$name → invalid, yazım yok', () async {
        await seedEvent();
        await seed();

        expect((await scan(payload)).dataOrNull, ScanOutcome.invalid);
        expectNothingWritten();
      });
    }

    test('pencere dışında geçerli bilet → attendanceWindowClosed, yazım '
        'yok', () async {
      await seedEvent();
      await seedRsvp(_ayse, RsvpStatus.going);
      clock.set(_endsAt.add(const Duration(hours: 7)));

      expectViolation(
        await scan(FirestoreIds.ticketQrPayload(_eventId, _ticket)),
        FirestoreRuleCode.attendanceWindowClosed,
      );
      expectNothingWritten();
    });
  });

  group('T-30 · markAllAttended', () {
    test('going kayıtların her biri ayrı transaction (+n yok); attended / '
        'bekleyen atlanır; ilerleme her kayıttan sonra', () async {
      await seedEvent(goingCount: 3, attendedCount: 1);
      await seedRsvp(_ayse, RsvpStatus.going);
      await seedRsvp(_can, RsvpStatus.going, ticketCode: 'GU-CCCC-CCCC');
      await seedRsvp(
        'u_deniz',
        RsvpStatus.attended,
        ticketCode: 'GU-DDDD-DDDD',
      );
      await seedRsvp('u_ece', RsvpStatus.waitlist, ticketCode: 'GU-EEEE-EEEE');
      final progress = <(int, int)>[];

      final result = await repository.markAllAttended(
        eventId: _eventId,
        clubId: _clubId,
        actorId: _actor,
        onProgress: (done, total) => progress.add((done, total)),
      );

      expect(
        result.dataOrNull,
        const BulkResult(succeeded: [_ayse, _can]),
      );
      expect(service.transactions, 2);
      expect(writes(), [..._attendWrites(_ayse), ..._attendWrites(_can)]);
      expect(progress, [(1, 2), (2, 2)]);
      expect(await counters(), [3, 1, 3]);
    });

    test('pencere kapalı → ilk kayıtta durur (attendanceWindowClosed), '
        'yazım yok', () async {
      await seedEvent();
      await seedRsvp(_ayse, RsvpStatus.going);
      await seedRsvp(_can, RsvpStatus.going, ticketCode: 'GU-CCCC-CCCC');
      clock.set(_startsAt.subtract(const Duration(hours: 3)));

      final result = await repository.markAllAttended(
        eventId: _eventId,
        clubId: _clubId,
        actorId: _actor,
      );

      expectViolation(result, FirestoreRuleCode.attendanceWindowClosed);
      expect(service.transactions, 1);
      expectNothingWritten();
    });
  });

  group('T-30 · promote', () {
    test('waitlist → going: kayıt (yalnızca status) + goingCount +1 / '
        'waitlistCount −1 + yan belge + waitlist_promoted bildirimi TEK '
        'transaction; bekleme anı yerinde kalır', () async {
      await seedEvent(capacity: 3);
      await seedRsvp(_can, RsvpStatus.waitlist, waitlistAt: _seededAt);

      expect((await promote(_can)).isSuccess, isTrue);
      expect(service.transactions, 1);
      expect(service.outsideWrites, 0);
      expect(service.reads, [_eventPath, 'rsvps/e01_u_can']);
      final recorded = writes();
      expect(recorded.take(3), [
        _write('update', 'rsvps/e01_u_can', {
          'status': 'going',
          'updatedAt': serverTimestampMark,
        }),
        _write('update', _eventPath, {
          'goingCount': incrementMark,
          'waitlistCount': incrementMark,
          'updatedAt': serverTimestampMark,
        }),
        _pointer(_can),
      ]);
      final notification = recorded.last;
      expect(recorded, hasLength(4));
      expect(notification['op'], 'set');
      expect(
        notification['path'],
        matches(
          RegExp(r'^notifications/waitlist_promoted_[A-Za-z0-9]{20}_u_can$'),
        ),
      );
      expect(notification['data'], containsPair('userId', _can));
      expect(
        notification['data'],
        containsPair('refs', {
          'clubId': _clubId,
          'eventId': _eventId,
        }),
      );
      expect(await counters(), [3, 0, 0]);
      expect((await read('rsvps/e01_u_can'))!['waitlistAt'], isNotNull);
    });

    final rejected =
        <
          String,
          (Future<void> Function(), void Function(FirestoreResult<void>))
        >{
          'kontenjan dolu (TST-X14)': (
            () => seedEvent(capacity: 2),
            (result) => expectViolation(result, FirestoreRuleCode.capacityFull),
          ),
          'etkinlik bitmiş': (
            () => seedEvent(endsAt: _now),
            (result) => expectViolation(result, FirestoreRuleCode.eventEnded),
          ),
          'etkinlik yayında değil': (
            () => seedEvent(status: EventStatus.cancelled),
            (result) => expect(result.errorOrNull, FirestoreError.conflict),
          ),
        };
    for (final MapEntry(key: name, value: (seed, check)) in rejected.entries) {
      test('$name → ret; kayıt, sayaç ve bildirim yazılmaz', () async {
        await seed();
        await seedRsvp(_can, RsvpStatus.waitlist, waitlistAt: _seededAt);

        check(await promote(_can));
        expectNothingWritten();
      });
    }

    test('yöneticinin kendi kaydı (rules-spec §3.8): terfi ve yoklama '
        'invalidArgument, işlem açılmaz', () async {
      await seedEvent(capacity: 5);
      await seedRsvp(_actor, RsvpStatus.waitlist, waitlistAt: _seededAt);

      expect(
        (await promote(_actor)).errorOrNull,
        FirestoreError.invalidArgument,
      );
      expect((await mark(_actor)).errorOrNull, FirestoreError.invalidArgument);
      expect(service.transactions, 0);
      expectNothingWritten();
    });

    test('bildirim başarısızsa istisna gövdeden kaçar (işlem commit '
        'edilmez) ve hata sonuca taşınır', () async {
      await seedEvent(capacity: 3);
      await seedRsvp(_can, RsvpStatus.waitlist, waitlistAt: _seededAt);
      final observed = _BodyObservingService(service);
      final failing = FirebaseAttendanceRepository(
        observed,
        FirebaseRsvpRepository(observed, FakeTicketCodeGenerator(), clock),
        _FailingDispatcher(),
        clock,
      );

      final result = await failing.promote(
        eventId: _eventId,
        userId: _can,
        actorId: _actor,
      );

      expect(result.errorOrNull, FirestoreError.unavailable);
      expect(observed.bodyThrew, isTrue);
    });

    test('bekleme listesinde olmayan kayıt → conflict, yazım yok', () async {
      await seedEvent(capacity: 5);
      await seedRsvp(_ayse, RsvpStatus.going);

      expect((await promote(_ayse)).errorOrNull, FirestoreError.conflict);
      expectNothingWritten();
    });
  });

  group('T-30 · katılımcı listesi', () {
    test(
      'listParticipants: durum süzgeci; going kaydı (waitlistAt anahtarı '
      'yok) da döner; sıra status, waitlistAt; boş küme sorgusuz boş',
      () async {
        await seedEvent();
        await seedRsvp(
          'u_x',
          RsvpStatus.waitlist,
          waitlistAt: _seededAt.add(const Duration(hours: 1)),
          ticketCode: 'GU-XXXX-XXXX',
        );
        await seedRsvp(
          'u_y',
          RsvpStatus.waitlist,
          waitlistAt: _seededAt,
          ticketCode: 'GU-YYYY-YYYY',
        );
        await seedRsvp(_ayse, RsvpStatus.going);
        await seedRsvp(_can, RsvpStatus.cancelled, ticketCode: 'GU-CCCC-CCCC');
        await db.doc('rsvps/e09_u_z').set({
          ...(await read(_ayseRsvp))!,
          'eventId': 'e09',
          'userId': 'u_z',
        });

        final all = await repository.listParticipants(
          eventId: _eventId,
          clubId: _clubId,
        );
        final open = await repository.listParticipants(
          eventId: _eventId,
          clubId: _clubId,
          statuses: const {RsvpStatus.going, RsvpStatus.waitlist},
        );
        final none = await repository.listParticipants(
          eventId: _eventId,
          clubId: _clubId,
          statuses: const {},
        );

        List<String>? usersOf(FirestoreResult<List<RsvpModel>> result) =>
            result.dataOrNull?.map((rsvp) => rsvp.userId).toList();
        expect(usersOf(all), [_can, _ayse, 'u_y', 'u_x']);
        expect(usersOf(open), [_ayse, 'u_y', 'u_x']);
        expect(none.dataOrNull, isEmpty);
        expect(
          usersOf(
            await repository
                .watchParticipants(eventId: _eventId, clubId: _clubId)
                .first,
          ),
          [_can, _ayse, 'u_y', 'u_x'],
        );
        expect(
          (await repository
                  .watchParticipants(eventId: 'a/b', clubId: _clubId)
                  .toList())
              .single
              .errorOrNull,
          FirestoreError.invalidArgument,
        );
      },
    );
  });
}
