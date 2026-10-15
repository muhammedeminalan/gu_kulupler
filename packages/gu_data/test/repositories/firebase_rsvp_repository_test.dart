// T-22 · RsvpRepository (katılımcı tarafı): katıl (yer varsa `going`, dolu
// etkinlikte `waitlist`), kontenjan yarışı (aynı anda gelen iki istekten biri
// çakışmada yeniden koşar ve bekleme listesine düşer), vazgeç, yeniden katıl
// (aynı belge, aynı bilet kodu), hatırlatıcı (dört değer); her geçişte kayıt
// ile etkinlik sayacı (`goingCount` / `waitlistCount` ±1) tek transaction'da
// ve ham yükleriyle; reddedilen durumlar (taslak, iptal, kayıt kapalı, bitmiş
// etkinlik, çift katılım); okumalar, bekleme sırası, bilet araması ve sorgu
// sözleşmesi; kimlik birleşimi belirsizliği; geçersiz kimlik (W-54),
// ayrıştırma hatası ve hata eşlemesi (PLAN §10.4, §10.6; domain-model §2.8,
// §8; rules-spec §3.7, §3.8, §6; docs/plans/T-22.md §6.3–§6.5, §6.8; D-10,
// D-30, CD-34, W-51, W-64).
//
// Mutlu yollar `fake_cloud_firestore` ile (Q-06); yazım kümesi kayıt tutan
// servis çiftiyle (`test/fakes/recording_firestore_service.dart`), hata
// yolları el yazımı SDK çiftleriyle (`test/fakes/sdk_firestore_stubs.dart`).
// `fake_cloud_firestore` transaction çakışması üretmediği için kontenjan
// yarışı, iyimser eşzamanlılık uygulayan el yazımı çiftle ([_OptimisticDb])
// kurulur.
//
// SDK sınıfları `@sealed` işaretlidir; test çifti bilerek uygular.
// ignore_for_file: subtype_of_sealed_class
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
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
    'packages/gu_data/lib/src/repositories/rsvp_repository.dart';
const String _implementation =
    'packages/gu_data/lib/src/repositories/firebase_rsvp_repository.dart';

const String _clubId = 'c01';
const String _eventId = 'e01';
const String _eventPath = 'events/e01';
const String _uid = 'u_ayse';
const String _other = 'u_can';
const String _rsvpId = 'e01_u_ayse';
const String _rsvpPath = 'rsvps/e01_u_ayse';
const String _otherRsvpPath = 'rsvps/e01_u_can';

/// Tohum kayıtların bilet kodu (`FirestoreIds.ticketCodePattern` ile eşleşir).
const String _ticket = 'GU-ABCD-EFGH';

/// Geçersiz belge kimlikleri (W-54).
const List<String> _invalidIds = ['', 'e/1', '..', '__id__'];

/// Sahte saatin gösterdiği an.
final DateTime _now = DateTime.utc(2026, 10, 14, 9);
final DateTime _startsAt = DateTime.utc(2026, 10, 20, 15);
final DateTime _endsAt = DateTime.utc(2026, 10, 20, 17);

/// Tohum belgelerin zaman damgası (sunucu zamanından ayırt edilir).
final DateTime _seededAt = DateTime.utc(2026, 10, 1, 8);

/// `BaseFieldsPayload.create()` yükü.
const Json _baseCreate = {
  'createdAt': serverTimestampMark,
  'updatedAt': serverTimestampMark,
  'isDeleted': false,
  'deletedAt': null,
  'deletedBy': null,
};

/// Yeni katılım kaydının yükü: `null` alanların anahtarı yok (W-51);
/// `waitlistAt` yalnızca bekleme listesinde.
Json _rsvpCreate(
  String status, {
  required String ticketCode,
  String reminder = 'none',
  String userId = _uid,
}) => {
  'eventId': _eventId,
  'clubId': _clubId,
  'userId': userId,
  'status': status,
  'reminder': reminder,
  'ticketCode': ticketCode,
  if (status == 'waitlist') 'waitlistAt': serverTimestampMark,
  ..._baseCreate,
};

/// Yeniden katılım yükü: bilet kodu ve `createdAt` yükte yok.
Json _rsvpRejoin(String status, {String reminder = 'none'}) => {
  'status': status,
  'reminder': reminder,
  'waitlistAt': status == 'waitlist' ? serverTimestampMark : null,
  'updatedAt': serverTimestampMark,
};

/// Etkinliğin sayaç yükü: yalnızca [field] deltası + `updatedAt`. Kaydın yolu
/// herkese açık etkinlik belgesine yazılmaz (W-64).
Json _counter(String field) => {
  field: incrementMark,
  'updatedAt': serverTimestampMark,
};

Map<String, Object?> _write(String op, String path, Json data) => {
  'op': op,
  'path': path,
  'data': data,
};

void main() {
  late FakeFirebaseFirestore db;
  late RecordingFirestoreService service;
  late FakeAppClock clock;
  late FakeTicketCodeGenerator codes;
  late RsvpRepository repository;

  RsvpRepository repositoryOn(FirestoreService firestore) =>
      FirebaseRsvpRepository(firestore, codes, clock);

  /// Her çağrısı [code] hatasıyla biten veritabanına bağlı repository.
  RsvpRepository failing(String code) => repositoryOn(
    FirebaseFirestoreService(StubFirestore(error: firestoreException(code))),
  );

  Future<Json?> read(String path) async => (await db.doc(path).get()).data();

  /// Etkinliğin `[goingCount, waitlistCount, attendedCount]` sayaçları.
  Future<List<Object?>> counters([String path = _eventPath]) async {
    final event = (await read(path))!;
    return [
      event['goingCount'],
      event['waitlistCount'],
      event['attendedCount'],
    ];
  }

  /// Transaction'da kuyruğa giren yazımlar, sırayla.
  List<Map<String, Object?>> writes() => [
    for (final write in service.writes)
      _write(write.op, write.path, write.data),
  ];

  Future<void> seedEvent({
    String id = _eventId,
    String clubId = _clubId,
    int? capacity,
    int goingCount = 0,
    int waitlistCount = 0,
    EventStatus status = EventStatus.published,
    bool registrationOpen = true,
    DateTime? startsAt,
    DateTime? endsAt,
    bool isDeleted = false,
  }) => db
      .doc('events/$id')
      .set(
        EventModel(
          id: id,
          clubId: clubId,
          createdBy: 'u_pres',
          title: 'Flutter Atölyesi',
          type: EventType.training,
          startsAt: startsAt ?? _startsAt,
          endsAt: endsAt ?? _endsAt,
          coverPalette: ClubPalette.red,
          coverPattern: ClubPattern.dots,
          capacity: capacity,
          status: status,
          registrationOpen: registrationOpen,
          goingCount: goingCount,
          waitlistCount: waitlistCount,
          createdAt: _seededAt,
          updatedAt: _seededAt,
          isDeleted: isDeleted,
        ).toJson(),
      );

  Future<void> seedRsvp(
    RsvpStatus status, {
    String eventId = _eventId,
    String clubId = _clubId,
    String userId = _uid,
    String ticketCode = _ticket,
    ReminderOption reminder = ReminderOption.none,
    DateTime? waitlistAt,
    DateTime? createdAt,
    bool isDeleted = false,
  }) => db
      .doc('rsvps/${eventId}_$userId')
      .set(
        RsvpModel(
          eventId: eventId,
          clubId: clubId,
          userId: userId,
          ticketCode: ticketCode,
          status: status,
          reminder: reminder,
          waitlistAt: waitlistAt,
          createdAt: createdAt ?? _seededAt,
          updatedAt: createdAt ?? _seededAt,
          isDeleted: isDeleted,
        ).toJson(),
      );

  Future<FirestoreResult<RsvpModel>> join({
    RsvpRepository? on,
    String eventId = _eventId,
    String clubId = _clubId,
    String userId = _uid,
    ReminderOption reminder = ReminderOption.none,
  }) => (on ?? repository).join(
    eventId: eventId,
    clubId: clubId,
    userId: userId,
    reminder: reminder,
  );

  Future<FirestoreResult<void>> cancel({
    String eventId = _eventId,
    String userId = _uid,
  }) => repository.cancel(eventId: eventId, userId: userId);

  Future<FirestoreResult<void>> remind(
    ReminderOption reminder, {
    String eventId = _eventId,
    String userId = _uid,
  }) => repository.setReminder(
    eventId: eventId,
    userId: userId,
    reminder: reminder,
  );

  Future<FirestoreResult<RsvpModel?>> mine({
    String eventId = _eventId,
    String userId = _uid,
  }) => repository.getMine(eventId: eventId, userId: userId);

  /// [result] iş kuralı reddi mi ve `detail` [code] kodunu taşıyor mu?
  void expectViolation(
    FirestoreResult<Object?> result,
    FirestoreRuleCode code,
  ) {
    expect(result.errorOrNull, FirestoreError.ruleViolation);
    final detail = switch (result) {
      FirebaseFailure(:final detail) => detail,
      FirebaseSuccess() => null,
    };
    expect(detail, FirestoreFailureDetail(code));
  }

  /// Hiçbir belge yazılmadı ve bilet kodu üretilmedi.
  void expectNothingWritten() {
    expect(service.writes, isEmpty);
    expect(service.outsideWrites, 0);
    expect(codes.issuedTicketCodes, isEmpty);
  }

  setUp(() {
    db = FakeFirebaseFirestore();
    service = RecordingFirestoreService(FirebaseFirestoreService(db));
    clock = FakeAppClock(_now);
    codes = FakeTicketCodeGenerator();
    repository = repositoryOn(service);
  });

  group('T-22 · RsvpRepository · sözleşme', () {
    test('PLAN §10.4 tablosundaki sekiz üye arayüzde aynı imzayla var; başka '
        'üye yok (yoklama ve terfi AttendanceRepository — T-30)', () {
      final plan = readPlanRepositoryMembers('$RsvpRepository');

      expect(plan.map((row) => row.member), [
        'join',
        'cancel',
        'setReminder',
        'getMine',
        'watchMine',
        'listMine',
        'waitlistPosition',
        'findByTicket',
      ]);
      expect(interfaceMembers(_interface, '$RsvpRepository').toSet(), {
        for (final row in plan) normalizeDartSource(row.signature),
      });
    });

    test('arayüzde ve uygulamada silme üyesi yok (D-10)', () {
      expect(deleteIdentifiersIn(_interface), isEmpty);
      expect(deleteIdentifiersIn(_implementation), isEmpty);
    });
  });

  group('T-22 · join · yeni kayıt', () {
    final available = <String, ({int? capacity, int goingCount})>{
      'kontenjansız etkinlik': (capacity: null, goingCount: 250),
      'kontenjanda yer var (1 / 2)': (capacity: 2, goingCount: 1),
    };
    for (final MapEntry(key: name, value: seed) in available.entries) {
      test('$name → going: kayıt + goingCount +1 tek transaction; etkinliğe '
          'kayıt yolu yazılmaz; bilet kodu üreticiden', () async {
        await seedEvent(capacity: seed.capacity, goingCount: seed.goingCount);
        final code = FakeTicketCodeGenerator.ticketCodeAt(1);

        final result = await join(reminder: ReminderOption.oneHour);

        expect(writes(), [
          _write(
            'set',
            _rsvpPath,
            _rsvpCreate('going', ticketCode: code, reminder: '1h'),
          ),
          _write('update', _eventPath, _counter('goingCount')),
        ]);
        expect(service.transactions, 1);
        expect(service.outsideWrites, 0);
        // Transaction kuralı: önce etkinlik ve kayıt okunur.
        expect(service.reads, [_eventPath, _rsvpPath]);

        expect(await counters(), [seed.goingCount + 1, 0, 0]);
        final event = (await read(_eventPath))!;
        expect(event, isNot(contains('lastRsvpRef')));
        expect(event['updatedAt'], isNot(Timestamp.fromDate(_seededAt)));
        expect(await read(_rsvpPath), {
          'eventId': _eventId,
          'clubId': _clubId,
          'userId': _uid,
          'status': 'going',
          'reminder': '1h',
          'ticketCode': code,
          'createdAt': isA<Timestamp>(),
          'updatedAt': isA<Timestamp>(),
          'isDeleted': false,
          'deletedAt': null,
          'deletedBy': null,
        });
        expect(codes.issuedTicketCodes, [code]);
        expect(
          result.dataOrNull,
          RsvpModel(
            id: _rsvpId,
            eventId: _eventId,
            clubId: _clubId,
            userId: _uid,
            ticketCode: code,
            reminder: ReminderOption.oneHour,
            createdAt: _now,
            updatedAt: _now,
          ),
        );
      });
    }

    test('kontenjan dolu → waitlist: kayıt (waitlistAt sunucu zamanı) + '
        'waitlistCount +1 tek transaction; goingCount değişmez', () async {
      await seedEvent(capacity: 1, goingCount: 1);
      final code = FakeTicketCodeGenerator.ticketCodeAt(1);

      final result = await join();

      expect(writes(), [
        _write('set', _rsvpPath, _rsvpCreate('waitlist', ticketCode: code)),
        _write('update', _eventPath, _counter('waitlistCount')),
      ]);
      expect(service.transactions, 1);
      expect(service.outsideWrites, 0);
      expect(await counters(), [1, 1, 0]);
      final rsvp = (await read(_rsvpPath))!;
      expect(rsvp['status'], 'waitlist');
      expect(rsvp['waitlistAt'], isA<Timestamp>());
      final model = result.dataOrNull!;
      expect(model.status, RsvpStatus.waitlist);
      expect(model.waitlistAt, _now);
      expect(model.ticketCode, code);
    });

    test('yer var ama önde bekleyen var → waitlist (güvenlik incelemesi: '
        'boşalan yer önce bekleyenindir, sıra atlanamaz); kontenjansız '
        'etkinlikte bekleyen olsa da going', () async {
      await seedEvent(capacity: 3, goingCount: 1, waitlistCount: 1);

      final queued = await join();

      expect(queued.dataOrNull?.status, RsvpStatus.waitlist);
      expect(await counters(), [1, 2, 0]);

      await seedEvent(id: 'e02', goingCount: 1, waitlistCount: 1);
      final unlimited = await join(eventId: 'e02');

      expect(unlimited.dataOrNull?.status, RsvpStatus.going);
      expect(await counters('events/e02'), [2, 1, 0]);
    });

    test('kontenjan 1 iken iki eşzamanlı katılım: biri going; diğeri bayat '
        'sayaçla işlenemez, yeniden koşar ve waitlist olur — goingCount '
        'kontenjanı aşmaz', () async {
      await seedEvent(capacity: 1);
      final contended = _OptimisticDb(db);
      final target = repositoryOn(FirebaseFirestoreService(contended));

      final results = await Future.wait([
        join(on: target),
        join(on: target, userId: _other),
      ]);

      expect(results.map((result) => result.dataOrNull?.status), [
        RsvpStatus.going,
        RsvpStatus.waitlist,
      ]);
      // İki istek de sayacı 0 gördü; ikincinin commit'i çakıştı ve gövde bir
      // kez daha koştu (2 ilk deneme + 1 yeniden deneme).
      expect(contended.staleReads, 2);
      expect(contended.aborts, 1);
      expect(contended.attempts, 3);
      expect(await counters(), [1, 1, 0]);
      final first = (await read(_rsvpPath))!;
      final second = (await read(_otherRsvpPath))!;
      expect(first['status'], 'going');
      expect(first, isNot(contains('waitlistAt')));
      expect(second['status'], 'waitlist');
      expect(second['waitlistAt'], isA<Timestamp>());
      // Yeniden koşan işlem yeni kod üretmez: iki kayıt, iki kod.
      expect(codes.issuedTicketCodes, [
        first['ticketCode'],
        second['ticketCode'],
      ]);
      expect(first['ticketCode'], isNot(second['ticketCode']));
    });
  });

  group('T-22 · join · Rules reddinde tek yeniden deneme', () {
    test('kontenjan yarışında kaybeden commit Rules reddi alırsa (emülatör: '
        'çakışma yerine permission-denied) join güncel sayaçla bir kez daha '
        'koşar ve waitlist olur', () async {
      await seedEvent(capacity: 1);
      final contended = _OptimisticDb(db, denyStaleCommits: true);
      final target = repositoryOn(FirebaseFirestoreService(contended));

      final results = await Future.wait([
        join(on: target),
        join(on: target, userId: _other),
      ]);

      expect(results.map((result) => result.dataOrNull?.status), [
        RsvpStatus.going,
        RsvpStatus.waitlist,
      ]);
      // İkinci işlemin ilk commit'i reddedildi (SDK yeniden denemedi);
      // repository işlemi bir kez daha başlattı.
      expect(contended.denials, 1);
      expect(contended.attempts, 3);
      expect(await counters(), [1, 1, 0]);
      expect(
        (await read(_otherRsvpPath))!['ticketCode'],
        codes.issuedTicketCodes.last,
      );
      expect(codes.issuedTicketCodes, hasLength(2));
    });

    test('gerçek yetki reddi (permission-denied) ikinci denemede de döner: '
        'join en çok iki işlem başlatır', () async {
      await seedEvent(capacity: 1);
      final contended = _OptimisticDb(db, denyAll: true);

      final result = await join(
        on: repositoryOn(FirebaseFirestoreService(contended)),
      );

      expect(result.errorOrNull, FirestoreError.permissionDenied);
      expect(contended.attempts, 2);
      expect(await counters(), [0, 0, 0]);
    });
  });

  group('T-22 · join · reddedilen durumlar', () {
    final rejections =
        <
          String,
          ({
            Future<void> Function() seed,
            void Function(FirestoreResult<RsvpModel> result) check,
          })
        >{
          'etkinlik yok → notFound': (
            seed: () async {},
            check: (result) =>
                expect(result.errorOrNull, FirestoreError.notFound),
          ),
          'silinmiş etkinlik → notFound': (
            seed: () => seedEvent(isDeleted: true),
            check: (result) =>
                expect(result.errorOrNull, FirestoreError.notFound),
          ),
          'başka kulübün etkinliği → invalidArgument': (
            seed: () => seedEvent(clubId: 'c02'),
            check: (result) =>
                expect(result.errorOrNull, FirestoreError.invalidArgument),
          ),
          'taslak etkinlik → registrationClosed': (
            seed: () => seedEvent(status: EventStatus.draft),
            check: (result) =>
                expectViolation(result, FirestoreRuleCode.registrationClosed),
          ),
          'iptal edilmiş etkinlik → registrationClosed': (
            seed: () => seedEvent(status: EventStatus.cancelled),
            check: (result) =>
                expectViolation(result, FirestoreRuleCode.registrationClosed),
          ),
          'kayıt kapalı → registrationClosed': (
            seed: () => seedEvent(registrationOpen: false),
            check: (result) =>
                expectViolation(result, FirestoreRuleCode.registrationClosed),
          ),
          'bitmiş etkinlik → eventEnded': (
            seed: () => seedEvent(
              startsAt: _now.subtract(const Duration(days: 1, hours: 2)),
              endsAt: _now.subtract(const Duration(days: 1)),
            ),
            check: (result) =>
                expectViolation(result, FirestoreRuleCode.eventEnded),
          ),
          for (final status in [
            RsvpStatus.going,
            RsvpStatus.waitlist,
            RsvpStatus.attended,
          ])
            'zaten ${status.json} → conflict (çift katılım)': (
              seed: () async {
                await seedEvent(capacity: 5, goingCount: 1, waitlistCount: 1);
                await seedRsvp(status);
              },
              check: (result) =>
                  expect(result.errorOrNull, FirestoreError.conflict),
            ),
        };
    for (final MapEntry(key: name, value: scenario) in rejections.entries) {
      test('$name; hiçbir şey yazılmaz', () async {
        await scenario.seed();
        final before = await read(_eventPath);
        final rsvpBefore = await read(_rsvpPath);

        scenario.check(await join());

        expectNothingWritten();
        expect(await read(_eventPath), before);
        expect(await read(_rsvpPath), rsvpBefore);
      });
    }

    test('bitiş sınırı: endsAt == şimdi eventEnded, bir saniye öncesi '
        'katılır', () async {
      await seedEvent(
        startsAt: _now.subtract(const Duration(hours: 2)),
        endsAt: _now,
      );

      expectViolation(await join(), FirestoreRuleCode.eventEnded);
      expectNothingWritten();

      clock.advance(const Duration(seconds: -1));

      expect((await join()).dataOrNull?.status, RsvpStatus.going);
      expect(await counters(), [1, 0, 0]);
    });
  });

  group('T-22 · cancel', () {
    for (final status in [RsvpStatus.going, RsvpStatus.waitlist]) {
      test('${status.json} → cancelled: kayıtta yalnızca durum, etkinlikte '
          'ilgili sayaç −1 tek transaction; etkinliğin durumu aranmaz (iptal '
          'edilmiş etkinlikte de geçer), kimse terfi etmez', () async {
        await seedEvent(
          capacity: 1,
          goingCount: 1,
          waitlistCount: 1,
          status: EventStatus.cancelled,
        );
        final waitlistAt = status == RsvpStatus.waitlist ? _seededAt : null;
        await seedRsvp(status, waitlistAt: waitlistAt);
        // Diğer kullanıcı öbür durumda: sayaçlar tohumla tutarlı.
        final otherStatus = status == RsvpStatus.going
            ? RsvpStatus.waitlist
            : RsvpStatus.going;
        await seedRsvp(otherStatus, userId: _other);
        final seeded = (await read(_rsvpPath))!;
        final counter = status == RsvpStatus.going
            ? 'goingCount'
            : 'waitlistCount';

        final result = await cancel();

        expect(result.isSuccess, isTrue);
        expect(writes(), [
          _write('update', _rsvpPath, {
            'status': 'cancelled',
            'updatedAt': serverTimestampMark,
          }),
          _write('update', _eventPath, _counter(counter)),
        ]);
        expect(service.transactions, 1);
        expect(service.outsideWrites, 0);
        expect(service.reads, [_rsvpPath, _eventPath]);
        expect(
          await counters(),
          status == RsvpStatus.going ? [0, 1, 0] : [1, 0, 0],
        );
        // Bilet kodu, `createdAt` ve `waitlistAt` yerinde kalır.
        expect(await read(_rsvpPath), {
          ...seeded,
          'status': 'cancelled',
          'updatedAt': isA<Timestamp>(),
        });
        expect((await read(_otherRsvpPath))!['status'], otherStatus.json);
      });
    }

    test('bitmiş etkinlikte vazgeçilemez (güvenlik incelemesi — "Gelmedin" '
        'kaydı iptale çevrilip yoklama oranı şişirilemez): endsAt == şimdi '
        'eventEnded, bir saniye öncesi geçer', () async {
      await seedEvent(
        goingCount: 1,
        startsAt: _now.subtract(const Duration(hours: 2)),
        endsAt: _now,
      );
      await seedRsvp(RsvpStatus.going);

      final ended = await cancel();

      expectViolation(ended, FirestoreRuleCode.eventEnded);
      expect(service.writes, isEmpty);
      expect(await counters(), [1, 0, 0]);
      expect((await read(_rsvpPath))!['status'], 'going');

      clock.advance(const Duration(seconds: -1));
      expect((await cancel()).isSuccess, isTrue);
      expect(await counters(), [0, 0, 0]);
    });

    test('zaten cancelled: yazmadan başarı; kayıt yok → notFound; attended → '
        'failedPrecondition — sayaçlar oynamaz', () async {
      await seedEvent(goingCount: 3, waitlistCount: 2);

      final missing = await cancel();
      await seedRsvp(RsvpStatus.cancelled);
      final repeated = await cancel();
      await seedRsvp(RsvpStatus.attended);
      final attended = await cancel();

      expect(missing.errorOrNull, FirestoreError.notFound);
      expect(repeated.isSuccess, isTrue);
      expect(attended.errorOrNull, FirestoreError.failedPrecondition);
      expectNothingWritten();
      expect(await counters(), [3, 2, 0]);
      expect((await read(_rsvpPath))!['status'], 'attended');
    });
  });

  group('T-22 · vazgeç → yeniden katıl', () {
    test('aynı belge, aynı bilet kodu, createdAt korunur; goingCount '
        '1 → 0 → 1; yeniden katılımda kod üretilmez', () async {
      await seedEvent(capacity: 1);

      final first = (await join()).dataOrNull!;
      final created = (await read(_rsvpPath))!['createdAt'];
      expect(await counters(), [1, 0, 0]);
      expect((await cancel()).isSuccess, isTrue);
      expect(await counters(), [0, 0, 0]);
      service.writes.clear();
      clock.advance(const Duration(hours: 1));

      final again = await join(reminder: ReminderOption.oneDay);

      expect(writes(), [
        _write('update', _rsvpPath, _rsvpRejoin('going', reminder: '1d')),
        _write('update', _eventPath, _counter('goingCount')),
      ]);
      expect(service.transactions, 3);
      expect(service.outsideWrites, 0);
      expect(await counters(), [1, 0, 0]);
      final rsvp = (await read(_rsvpPath))!;
      expect(rsvp['status'], 'going');
      expect(rsvp['ticketCode'], first.ticketCode);
      expect(rsvp['createdAt'], created);
      expect(codes.issuedTicketCodes, [first.ticketCode]);
      expect(
        again.dataOrNull,
        first.copyWith(
          reminder: ReminderOption.oneDay,
          createdAt: (created! as Timestamp).toDate().toUtc(),
          updatedAt: _now.add(const Duration(hours: 1)),
        ),
      );
    });

    test('kontenjan kararı yeniden verilir: dolu etkinlikte waitlist + yeni '
        'waitlistAt; yer açılınca going ve waitlistAt null', () async {
      await seedEvent(capacity: 1, goingCount: 1);
      await seedRsvp(RsvpStatus.cancelled, waitlistAt: _seededAt);

      final waitlisted = await join();

      expect(writes(), [
        _write('update', _rsvpPath, _rsvpRejoin('waitlist')),
        _write('update', _eventPath, _counter('waitlistCount')),
      ]);
      expect(await counters(), [1, 1, 0]);
      expect(waitlisted.dataOrNull?.status, RsvpStatus.waitlist);
      expect(waitlisted.dataOrNull?.waitlistAt, _now);
      expect(
        (await read(_rsvpPath))!['waitlistAt'],
        isNot(Timestamp.fromDate(_seededAt)),
      );

      // Vazgeçer; kayıtlı katılımcı da ayrılır (yer açılır).
      expect((await cancel()).isSuccess, isTrue);
      await db.doc(_eventPath).update({'goingCount': 0});
      service.writes.clear();

      final going = await join();

      expect(writes(), [
        _write('update', _rsvpPath, _rsvpRejoin('going')),
        _write('update', _eventPath, _counter('goingCount')),
      ]);
      expect(await counters(), [1, 0, 0]);
      expect(going.dataOrNull?.status, RsvpStatus.going);
      expect(going.dataOrNull?.waitlistAt, isNull);
      final rsvp = (await read(_rsvpPath))!;
      expect(rsvp, containsPair('waitlistAt', null));
      expect(rsvp['ticketCode'], _ticket);
      expect(codes.issuedTicketCodes, isEmpty);
    });
  });

  group('T-22 · setReminder', () {
    for (final status in [RsvpStatus.going, RsvpStatus.waitlist]) {
      test('${status.json} kayıtta dört değer de yazılır: yalnızca reminder + '
          'updatedAt; etkinlik belgesine dokunulmaz', () async {
        await seedEvent(goingCount: 1, waitlistCount: 1);
        await seedRsvp(status);
        final event = await read(_eventPath);

        for (final option in ReminderOption.values.reversed) {
          service.writes.clear();

          final result = await remind(option);

          expect(result.isSuccess, isTrue, reason: option.json);
          expect(writes(), [
            _write('update', _rsvpPath, {
              'reminder': option.json,
              'updatedAt': serverTimestampMark,
            }),
          ]);
          expect((await read(_rsvpPath))!['reminder'], option.json);
        }
        expect(service.reads.toSet(), {_rsvpPath});
        expect(service.outsideWrites, 0);
        expect((await read(_rsvpPath))!['status'], status.json);
        expect(await read(_eventPath), event);
      });
    }

    test('kayıt yok, cancelled ya da attended → notMember (TST-X7); yazım '
        'yok', () async {
      final missing = await remind(ReminderOption.oneDay);
      await seedRsvp(RsvpStatus.cancelled);
      final cancelled = await remind(ReminderOption.oneDay);
      await seedRsvp(RsvpStatus.attended);
      final attended = await remind(ReminderOption.oneDay);

      for (final result in [missing, cancelled, attended]) {
        expectViolation(result, FirestoreRuleCode.notMember);
      }
      expectNothingWritten();
      expect((await read(_rsvpPath))!['reminder'], 'none');
    });
  });

  group('T-22 · okumalar', () {
    test('getMine: kayıt yok → null; kayıt → model; vazgeçilmiş kayıt '
        'cancelled durumuyla döner', () async {
      expect((await mine()).isSuccess, isTrue);
      expect((await mine()).dataOrNull, isNull);

      await seedRsvp(
        RsvpStatus.cancelled,
        reminder: ReminderOption.fifteenMinutes,
      );

      expect(
        (await mine()).dataOrNull,
        RsvpModel(
          id: _rsvpId,
          eventId: _eventId,
          clubId: _clubId,
          userId: _uid,
          ticketCode: _ticket,
          status: RsvpStatus.cancelled,
          reminder: ReminderOption.fifteenMinutes,
          createdAt: _seededAt,
          updatedAt: _seededAt,
        ),
      );
    });

    test('watchMine: canlı — kayıt yokken null, katılınca going, yönetici '
        'bileti okutunca attended', () async {
      await seedEvent();
      final statuses = <RsvpStatus?>[];
      final subscription = repository
          .watchMine(eventId: _eventId, userId: _uid)
          .listen((event) => statuses.add(event.dataOrNull?.status));
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      await join();
      await pumpEventQueue();
      await db.doc(_rsvpPath).update({
        'status': 'attended',
        'scannedAt': Timestamp.fromDate(_now),
        'scannedBy': 'u_pres',
      });
      await pumpEventQueue();

      expect(statuses, [null, RsvpStatus.going, RsvpStatus.attended]);
    });

    test('listMine: yalnızca kullanıcının silinmemiş kayıtları, en yeni '
        'üstte; vazgeçilmişler dahil', () async {
      DateTime day(int day) => DateTime.utc(2026, 10, day);
      await seedRsvp(RsvpStatus.going, createdAt: day(2));
      await seedRsvp(RsvpStatus.cancelled, eventId: 'e02', createdAt: day(5));
      await seedRsvp(RsvpStatus.attended, eventId: 'e03', createdAt: day(3));
      await seedRsvp(
        RsvpStatus.going,
        eventId: 'e04',
        createdAt: day(6),
        isDeleted: true,
      );
      await seedRsvp(RsvpStatus.going, userId: _other, createdAt: day(7));

      final result = await repository.listMine(_uid);

      expect(
        [
          for (final rsvp in result.dataOrNull!) (rsvp.eventId, rsvp.status),
        ],
        [
          ('e02', RsvpStatus.cancelled),
          ('e03', RsvpStatus.attended),
          ('e01', RsvpStatus.going),
        ],
      );
    });

    test('T-44 · D3-02 listMine süzgeçli kip: statuses yalnızca o '
        'durumları, clubId yalnızca o kulübü döndürür; boş küme sorgusuz boş, '
        'geçersiz clubId invalidArgument', () async {
      DateTime day(int day) => DateTime.utc(2026, 10, day);
      await seedRsvp(RsvpStatus.going, createdAt: day(2));
      await seedRsvp(RsvpStatus.cancelled, eventId: 'e02', createdAt: day(5));
      await seedRsvp(RsvpStatus.attended, eventId: 'e03', createdAt: day(3));
      await seedRsvp(
        RsvpStatus.going,
        eventId: 'e05',
        clubId: 'c02',
        createdAt: day(4),
      );
      await seedRsvp(
        RsvpStatus.going,
        eventId: 'e04',
        createdAt: day(6),
        isDeleted: true,
      );
      await seedRsvp(RsvpStatus.going, userId: _other, createdAt: day(7));

      Set<String> ids(FirestoreResult<List<RsvpModel>> result) => {
        for (final rsvp in result.dataOrNull!) rsvp.eventId,
      };

      expect(
        ids(await repository.listMine(_uid, statuses: {RsvpStatus.going})),
        {'e01', 'e05'},
      );
      expect(
        ids(
          await repository.listMine(
            _uid,
            statuses: {RsvpStatus.going, RsvpStatus.attended},
          ),
        ),
        {'e01', 'e03', 'e05'},
      );
      expect(ids(await repository.listMine(_uid, clubId: 'c02')), {'e05'});
      expect(
        ids(
          await repository.listMine(
            _uid,
            clubId: _clubId,
            statuses: {RsvpStatus.attended},
          ),
        ),
        {'e03'},
      );

      // Boş küme: sorgu yapılmaz (yapılsaydı permission-denied dönerdi).
      final denied = failing('permission-denied');
      final none = await denied.listMine(_uid, statuses: {});
      expect(none.isSuccess, isTrue);
      expect(none.dataOrNull, isEmpty);
      expect(
        (await repository.listMine(_uid, clubId: 'a/b')).errorOrNull,
        FirestoreError.invalidArgument,
      );
    });

    test('waitlistPosition: aynı etkinlik ve kulüpte daha önce girmiş '
        'bekleyenler + 1 (waitlistAt artan sıra)', () async {
      DateTime minute(int minute) => DateTime.utc(2026, 10, 14, 8, minute);
      await seedRsvp(RsvpStatus.waitlist, userId: 'u1', waitlistAt: minute(1));
      await seedRsvp(RsvpStatus.waitlist, userId: 'u2', waitlistAt: minute(2));
      await seedRsvp(RsvpStatus.waitlist, userId: 'u3', waitlistAt: minute(3));
      // Sayılmayanlar: vazgeçmiş, kayıtlıya alınmış, başka etkinlik / kulüp.
      await seedRsvp(RsvpStatus.cancelled, userId: 'u4', waitlistAt: minute(0));
      await seedRsvp(RsvpStatus.going, userId: 'u5', waitlistAt: minute(0));
      await seedRsvp(
        RsvpStatus.waitlist,
        eventId: 'e02',
        userId: 'u6',
        waitlistAt: minute(0),
      );
      await seedRsvp(
        RsvpStatus.waitlist,
        clubId: 'c02',
        userId: 'u7',
        waitlistAt: minute(0),
      );

      Future<int?> position(int at) async => (await repository.waitlistPosition(
        eventId: _eventId,
        clubId: _clubId,
        waitlistAtUtc: minute(at),
      )).dataOrNull;

      expect(await position(1), 1);
      expect(await position(2), 2);
      expect(await position(3), 3);
    });

    test('findByTicket: kod etkinliğe ve kulübe kapsamlı aranır; başka '
        'etkinliğin kodu ya da başka kulüp süzgeci null', () async {
      const elsewhere = 'GU-WXYZ-2345';
      await seedRsvp(RsvpStatus.going);
      await seedRsvp(RsvpStatus.going, eventId: 'e02', ticketCode: elsewhere);

      Future<FirestoreResult<RsvpModel?>> find(String code) => repository
          .findByTicket(eventId: _eventId, clubId: _clubId, code: code);

      final found = await find(_ticket);
      final otherEvent = await find(elsewhere);
      final otherClub = await repository.findByTicket(
        eventId: _eventId,
        clubId: 'c02',
        code: _ticket,
      );

      expect(found.dataOrNull?.id, _rsvpId);
      expect(found.dataOrNull?.userId, _uid);
      expect(otherEvent.isSuccess, isTrue);
      expect(otherEvent.dataOrNull, isNull);
      expect(otherClub.isSuccess, isTrue);
      expect(otherClub.dataOrNull, isNull);
    });

    test('findByTicket: başkasının kodunu kopyalayan ikinci kayıt (güvenlik '
        'incelemesi) gerçek sahibin okutmasını kendine çeviremez — belirsiz '
        'eşleşme failedPrecondition, hiçbir kayıt dönmez', () async {
      await seedRsvp(RsvpStatus.going);
      await seedRsvp(
        RsvpStatus.going,
        userId: _other,
        createdAt: _seededAt.add(const Duration(hours: 1)),
      );

      final result = await repository.findByTicket(
        eventId: _eventId,
        clubId: _clubId,
        code: _ticket,
      );

      expect(result.errorOrNull, FirestoreError.failedPrecondition);
      expect(result.dataOrNull, isNull);
    });

    test('findByTicket: biçimi tutmayan kod sorgu yapılmadan null', () async {
      // Sorgu yapılsaydı sonuç permission-denied olurdu.
      final denied = failing('permission-denied');

      for (final code in ['', 'gu-abcd-efgh', 'GU-ABCD-EFG1', ' $_ticket']) {
        final result = await denied.findByTicket(
          eventId: _eventId,
          clubId: _clubId,
          code: code,
        );

        expect(result.isSuccess, isTrue, reason: '"$code"');
        expect(result.dataOrNull, isNull);
      }
    });

    test('sorgu sözleşmesi (indekslerle birebir): süzgeçler, sıralama ve '
        'limit', () async {
      final queries = _QueryRecordingService();
      final target = repositoryOn(queries);
      final waitlistAt = DateTime.utc(2026, 10, 14, 8, 30);

      await target.listMine(_uid);
      await target.waitlistPosition(
        eventId: _eventId,
        clubId: _clubId,
        waitlistAtUtc: waitlistAt,
      );
      await target.findByTicket(
        eventId: _eventId,
        clubId: _clubId,
        code: _ticket,
      );

      expect(queries.paths, ['rsvps', 'rsvps', 'rsvps']);
      final [listMine, position, ticket] = queries.queries;
      expect(listMine.equalities, {'userId': _uid, 'isDeleted': false});
      expect(listMine.orders, [
        ['createdAt', true],
      ]);
      expect(listMine.limits, isEmpty);
      // Katılım kaydı soft delete edilmez: yönetim sorguları `isDeleted`
      // taşımaz (indeks: eventId, clubId, status, waitlistAt).
      expect(position.equalities, {
        'eventId': _eventId,
        'clubId': _clubId,
        'status': 'waitlist',
      });
      expect(position.lessThan, {
        'waitlistAt': Timestamp.fromDate(waitlistAt),
      });
      expect(position.orders, isEmpty);
      expect(queries.counted, [position]);
      expect(ticket.equalities, {
        'eventId': _eventId,
        'clubId': _clubId,
        'ticketCode': _ticket,
      });
      expect(ticket.lessThan, isEmpty);
      expect(ticket.limits, [2]);
    });

    test('T-44 · D3-02 süzgeçli listMine: yalnızca eşitlik / in, sırasız '
        've limitsiz (indeksler rules-spec §8)', () async {
      final queries = _QueryRecordingService();
      final target = repositoryOn(queries);

      await target.listMine(_uid, clubId: _clubId);
      await target.listMine(
        _uid,
        statuses: {RsvpStatus.going, RsvpStatus.attended},
      );

      final [byClub, byStatus] = queries.queries;
      expect(byClub.equalities, {
        'userId': _uid,
        'isDeleted': false,
        'clubId': _clubId,
      });
      expect(byClub.inValues, isEmpty);
      expect(byStatus.equalities, {'userId': _uid, 'isDeleted': false});
      expect(byStatus.inValues, {
        'status': unorderedEquals(['going', 'attended']),
      });
      for (final query in [byClub, byStatus]) {
        expect(query.orders, isEmpty);
        expect(query.limits, isEmpty);
      }
    });
  });

  group('T-22 · kimlik birleşimi belirsizliği', () {
    test(
      'kimliği aynı ama alanları başka (etkinlik, kullanıcı) çiftine ait '
      'kayıt kullanıcının sayılmaz: okuma null, yazım permissionDenied',
      () async {
        // `e01_u` + `ayse` ile `e01` + `u_ayse` aynı kimliği üretir.
        await seedEvent();
        await seedRsvp(RsvpStatus.going, eventId: 'e01_u', userId: 'ayse');
        final foreign = await read(_rsvpPath);
        expect(foreign, isNotNull);

        final read0 = await mine();
        final watched = await repository
            .watchMine(eventId: _eventId, userId: _uid)
            .first;
        final writesAttempted = <FirestoreResult<Object?>>[
          await join(),
          await cancel(),
          await remind(ReminderOption.oneDay),
        ];

        expect(read0.isSuccess, isTrue);
        expect(read0.dataOrNull, isNull);
        expect(watched.dataOrNull, isNull);
        for (final result in writesAttempted) {
          expect(result.errorOrNull, FirestoreError.permissionDenied);
        }
        expectNothingWritten();
        expect(await read(_rsvpPath), foreign);
        expect(await counters(), [0, 0, 0]);
      },
    );
  });

  group('T-22 · geçersiz kimlik, ayrıştırma ve hata eşlemesi', () {
    test('geçersiz kimlik invalidArgument döner, hiçbir çağrı yapılmaz '
        '(W-54)', () async {
      // Çağrı yapılsaydı sonuç permission-denied olurdu.
      final target = failing('permission-denied');
      for (final id in _invalidIds) {
        final results = <FirestoreResult<Object?>>[
          await join(on: target, eventId: id),
          await join(on: target, clubId: id),
          await join(on: target, userId: id),
          await target.cancel(eventId: id, userId: _uid),
          await target.cancel(eventId: _eventId, userId: id),
          await target.setReminder(
            eventId: id,
            userId: _uid,
            reminder: ReminderOption.none,
          ),
          await target.setReminder(
            eventId: _eventId,
            userId: id,
            reminder: ReminderOption.none,
          ),
          await target.getMine(eventId: id, userId: _uid),
          await target.getMine(eventId: _eventId, userId: id),
          await target.watchMine(eventId: id, userId: _uid).single,
          await target.watchMine(eventId: _eventId, userId: id).single,
          await target.listMine(id),
          await target.waitlistPosition(
            eventId: id,
            clubId: _clubId,
            waitlistAtUtc: _now,
          ),
          await target.waitlistPosition(
            eventId: _eventId,
            clubId: id,
            waitlistAtUtc: _now,
          ),
          await target.findByTicket(
            eventId: id,
            clubId: _clubId,
            code: _ticket,
          ),
          await target.findByTicket(
            eventId: _eventId,
            clubId: id,
            code: _ticket,
          ),
        ];
        for (final result in results) {
          expect(
            result.errorOrNull,
            FirestoreError.invalidArgument,
            reason: 'kimlik "$id"',
          );
        }
      }
      expect(codes.issuedTicketCodes, isEmpty);
    });

    test('ayrıştırılamayan kayıt ya da etkinlik parse (okuma ve geçiş); '
        'yazım yok', () async {
      await seedEvent();
      await db.doc(_rsvpPath).set({
        'eventId': _eventId,
        'clubId': _clubId,
        'userId': _uid,
        'status': 'bilinmeyen',
        'ticketCode': _ticket,
        'isDeleted': false,
        'createdAt': Timestamp.fromDate(_seededAt),
      });
      await db.doc('events/e09').set({'clubId': _clubId, 'isDeleted': false});

      final results = <FirestoreResult<Object?>>[
        await mine(),
        await repository.watchMine(eventId: _eventId, userId: _uid).first,
        await repository.listMine(_uid),
        await join(),
        await cancel(),
        await remind(ReminderOption.oneDay),
        await join(eventId: 'e09'),
      ];

      for (final result in results) {
        expect(result.errorOrNull, FirestoreError.parse);
      }
      expectNothingWritten();
    });

    test('SDK hatası sözlüğe çevrilir (Rules reddi, tükenen transaction '
        'denemesi, erişilemeyen servis)', () async {
      const mapping = {
        'permission-denied': FirestoreError.permissionDenied,
        'aborted': FirestoreError.aborted,
        'unavailable': FirestoreError.unavailable,
      };
      for (final MapEntry(key: code, value: error) in mapping.entries) {
        final target = failing(code);
        final results = <FirestoreResult<Object?>>[
          await join(on: target),
          await target.cancel(eventId: _eventId, userId: _uid),
          await target.setReminder(
            eventId: _eventId,
            userId: _uid,
            reminder: ReminderOption.oneHour,
          ),
          await target.getMine(eventId: _eventId, userId: _uid),
          await target.waitlistPosition(
            eventId: _eventId,
            clubId: _clubId,
            waitlistAtUtc: _now,
          ),
          await target.findByTicket(
            eventId: _eventId,
            clubId: _clubId,
            code: _ticket,
          ),
          await repositoryOn(
            _QueryRecordingService(error: error),
          ).listMine(_uid),
        ];

        for (final result in results) {
          expect(result.errorOrNull, error, reason: code);
        }
      }
    });
  });
}

/// İyimser eşzamanlılık uygulayan `FirebaseFirestore` çifti: istemci
/// SDK'sının transaction davranışını kurar (`fake_cloud_firestore` yazımları
/// anında uygular ve çakışma üretmez).
///
/// - Okuma, belgenin o andaki sürümünü kaydeder.
/// - Yazımlar gövde bitene kadar bekletilir.
/// - Commit'te, okunan belgelerden biri o arada değişmişse hiçbir yazım
///   uygulanmaz ve gövde **yeniden çalıştırılır** (en çok `maxAttempts` kez;
///   sonra `aborted`).
///
/// Okumalar ve commit'ler tek sırada işlenir (commit bölünmez); böylece aynı
/// anda başlayan iki işlem aynı sürümü okur ve yalnızca ilki işlenir.
final class _OptimisticDb implements FirebaseFirestore {
  /// Okumaların ve işlenen yazımların gittiği [_inner] veritabanını sarar.
  _OptimisticDb(
    this._inner, {
    this.denyStaleCommits = false,
    this.denyAll = false,
  });

  /// `true` ise çakışan commit yeniden denenmez, `permission-denied` ile
  /// reddedilir (emülatörün davranışı: Security Rules güncel belgeye karşı
  /// değerlendirilir ve kontenjanı aşan bayat yazımı reddeder).
  final bool denyStaleCommits;

  /// `true` ise her commit `permission-denied` ile reddedilir (gerçek yetki
  /// reddi).
  final bool denyAll;

  /// Rules reddiyle biten commit sayısı ([denyStaleCommits], [denyAll]).
  int denials = 0;

  final FirebaseFirestore _inner;
  final Map<String, int> _versions = {};
  Future<void> _tail = Future<void>.value();

  /// Gövdenin çalıştırılma sayısı (ilk denemeler + yeniden denemeler).
  int attempts = 0;

  /// Çakışma yüzünden işlenmeyen deneme sayısı.
  int aborts = 0;

  /// `events/…` belgesinin hiç yazılmamış (sürüm 0) hâlini okuyan deneme
  /// sayısı: yarışan işlemlerin aynı bayat sayacı gördüğünü kanıtlar.
  int staleReads = 0;

  @override
  CollectionReference<Json> collection(String collectionPath) =>
      _inner.collection(collectionPath);

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    for (var attempt = 1; ; attempt++) {
      attempts++;
      final transaction = _OptimisticTransaction(this);
      final result = await transactionHandler(transaction);
      if (denyAll) {
        denials++;
        throw firestoreException('permission-denied');
      }
      if (await _commit(transaction)) return result;
      if (denyStaleCommits) {
        denials++;
        throw firestoreException('permission-denied');
      }
      aborts++;
      if (attempt == maxAttempts) throw firestoreException('aborted');
    }
  }

  /// [ref] belgesini okur ve o andaki sürümünü [seen] içine kaydeder.
  Future<DocumentSnapshot<T>> _read<T>(
    DocumentReference<T> ref,
    Map<String, int> seen,
  ) => _exclusive(() async {
    final snapshot = await ref.get();
    final version = _versions[ref.path] ?? 0;
    seen[ref.path] = version;
    if (version == 0 && ref.path.startsWith('events/')) staleReads++;
    return snapshot;
  });

  /// Okunan sürümler hâlâ güncelse bekleyen yazımları uygular; değilse
  /// hiçbirini uygulamadan `false` döner.
  Future<bool> _commit(_OptimisticTransaction transaction) =>
      _exclusive(() async {
        final conflicted = transaction.seen.entries.any(
          (read) => (_versions[read.key] ?? 0) != read.value,
        );
        if (conflicted) return false;
        for (final write in transaction.pending) {
          await write.apply();
          _versions[write.path] = (_versions[write.path] ?? 0) + 1;
        }
        return true;
      });

  /// [action] işini öncekiler bittikten sonra, araya başka iş girmeden
  /// çalıştırır (geliş sırasıyla).
  Future<R> _exclusive<R>(Future<R> Function() action) {
    final previous = _tail;
    final released = Completer<void>();
    _tail = released.future;
    return previous.then((_) => action()).whenComplete(released.complete);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// [_OptimisticDb] transaction'ı: okuduğu sürümleri ve bekleyen yazımları
/// tutar. Yazımdan sonra okuma SDK'daki gibi reddedilir.
final class _OptimisticTransaction implements Transaction {
  _OptimisticTransaction(this._db);

  final _OptimisticDb _db;

  /// Okunan belge yolu → okunduğu andaki sürüm.
  final Map<String, int> seen = {};

  /// Commit'i bekleyen yazımlar, sırayla.
  final List<({String path, Future<void> Function() apply})> pending = [];

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> documentReference,
  ) {
    if (pending.isNotEmpty) {
      throw StateError('Transaction: okumalar yazımlardan önce yapılmalı.');
    }
    return _db._read(documentReference, seen);
  }

  @override
  Transaction set<T>(
    DocumentReference<T> documentReference,
    T data, [
    SetOptions? options,
  ]) {
    pending.add((
      path: documentReference.path,
      apply: () => documentReference.set(data, options),
    ));
    return this;
  }

  @override
  Transaction update(
    DocumentReference<Object?> documentReference,
    Map<Object, Object?> data,
  ) {
    pending.add((
      path: documentReference.path,
      apply: () => documentReference.update(data),
    ));
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Süzgeçleri, sıralamayı ve limiti kaydeden sorgu; her kurucu aynı nesneyi
/// döndürür.
final class _RecordingQuery implements Query<Json> {
  /// Alan → `isEqualTo` değeri.
  final Map<Object, Object?> equalities = {};

  /// Alan → `isLessThan` değeri.
  final Map<Object, Object?> lessThan = {};

  /// Alan → `whereIn` değerleri.
  final Map<Object, List<Object?>> inValues = {};

  /// `orderBy` çağrıları: `[alan, azalan mı]`.
  final List<List<Object?>> orders = [];

  /// `limit` çağrılarının değerleri.
  final List<int> limits = [];

  @override
  Query<Json> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    if (whereIn != null) {
      inValues[field] = whereIn.toList();
    } else if (isLessThan != null) {
      lessThan[field] = isLessThan;
    } else {
      equalities[field] = isEqualTo;
    }
    return this;
  }

  @override
  Query<Json> orderBy(Object field, {bool descending = false}) {
    orders.add([field, descending]);
    return this;
  }

  @override
  Query<Json> limit(int limit) {
    limits.add(limit);
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Koleksiyon sorgularını kaydeden servis: `collection` her çağrıda yeni bir
/// [_RecordingQuery] verir; `getList` ve `count` — [error] verilmişse o hatayı,
/// verilmemişse boş sonucu döndürür. Başka üyesi yoktur.
final class _QueryRecordingService implements FirestoreService {
  _QueryRecordingService({this.error});

  /// Okumaların döndürdüğü hata; `null` ise boş sonuç döner.
  final FirestoreError? error;

  /// `collection` çağrılarının yolları, sırayla.
  final List<String> paths = [];

  /// Kurulan sorgular, [paths] ile aynı sırada.
  final List<_RecordingQuery> queries = [];

  /// `count` ile sayılan sorgular.
  final List<Query<Json>> counted = [];

  @override
  Query<Json> collection(String path) {
    final query = _RecordingQuery();
    paths.add(path);
    queries.add(query);
    return query;
  }

  @override
  Future<FirestoreResult<List<FirestoreDoc>>> getList(Query<Json> query) async {
    final error = this.error;
    return error == null ? const FirebaseSuccess([]) : FirebaseFailure(error);
  }

  @override
  Future<FirestoreResult<int>> count(Query<Json> query) async {
    counted.add(query);
    final error = this.error;
    return error == null ? const FirebaseSuccess(0) : FirebaseFailure(error);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
