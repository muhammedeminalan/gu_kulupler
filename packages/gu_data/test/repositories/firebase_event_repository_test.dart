// T-22 · EventRepository: oluşturma (taslak / doğrudan yayın — etkinlik +
// günlük tek batch), içerik düzenleme (yalnızca verilen alanlar, boşaltma =
// açık null, kontenjan ≥ kayıtlı), durum makinesi (`draft → published →
// cancelled`, `published → draft` yalnızca kayıtlı yokken — K-F; günlük aynı
// transaction'da, yayın günlüğü yalnızca ilk yayında), kopyalama (tarih +7
// gün, sayaçlar sıfır, kapak kopyalanmaz), kayıt aç / kapa, taslağı kaldırma
// + geri yükleme (yayındaki etkinlik kaldırılamaz — D-10, DLG-31), kapak
// yükleme (CD-47: ön denetim, `customMetadata {clubId, uploaderId}`,
// `coverPath` yazımı, hata adımı), liste sorguları (isDeleted, visibility,
// status, startsAt süzgeçleri; sıra; sayfalama), tekil / çoklu okuma,
// geçersiz kimlik, ayrıştırma ve hata eşlemesi (PLAN §10.4; rules-spec §3.7,
// §3.11; W-51, W-54; docs/plans/T-22.md §6).
//
// Mutlu yollar `fake_cloud_firestore` ile (Q-06); transaction yazım kümesi
// kayıt tutan servis çiftiyle (`test/fakes/recording_firestore_service.dart`),
// hata yolları el yazımı SDK çiftleriyle (`test/fakes/sdk_firestore_stubs.dart`).
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/fake_app_clock.dart';
import '../fakes/recording_firestore_service.dart';
import '../fakes/recording_storage_service.dart';
import '../fakes/sdk_firestore_stubs.dart';
import '../helpers/plan_repository_table.dart';
import '../helpers/plan_service_table.dart';

const String _interface =
    'packages/gu_data/lib/src/repositories/event_repository.dart';
const String _implementation =
    'packages/gu_data/lib/src/repositories/firebase_event_repository.dart';

const String _clubId = 'c01';
const String _manager = 'u_baskan';
const String _board = 'u_yk';
const String _eventId = 'e01';
const String _eventPath = 'events/e01';
const String _title = 'Yapay Zeka Atölyesi';
const String _desc = 'Uygulamalı giriş atölyesi.';
const String _reason = 'Salon tadilatta.';
const String _copySuffix = ' (kopya)';

/// Geçersiz belge kimlikleri (W-54).
const List<String> _invalidIds = ['', 'c/1', '..', '__id__'];

final DateTime _now = DateTime.utc(2026, 10, 14, 9);
final DateTime _startsAt = DateTime.utc(2026, 10, 20, 15);
final DateTime _endsAt = DateTime.utc(2026, 10, 20, 17);
final DateTime _publishedAt = DateTime.utc(2026, 10, 1, 8);

/// `StoragePaths.newFileName` çıktıları: damga [_now], rastgele kısım sırayla
/// artan baytlar.
const String _firstCover = 'events/e01/20261014T090000Z_0001020304050607.jpg';
const String _secondCover = 'events/e01/20261014T090000Z_08090a0b0c0d0e0f.png';

/// `BaseFieldsPayload.create()` yükü.
const Json _baseCreate = {
  'createdAt': serverTimestampMark,
  'updatedAt': serverTimestampMark,
  'isDeleted': false,
  'deletedAt': null,
  'deletedBy': null,
};

/// [_draft] taslağından oluşturulan etkinlik belgesinin yükü: `null`
/// alanların (`placeText`, `coverPath`, `cancelReason`, sayaç işaretçisi)
/// anahtarı yoktur (W-51, W-64); `publishedAt` yalnızca yayında.
Json _eventCreate(
  String eventId, {
  bool published = false,
  String createdBy = _manager,
}) => {
  'clubId': _clubId,
  'createdBy': createdBy,
  'title': _title,
  'desc': _desc,
  'type': 'egitim',
  'startsAt': Timestamp.fromDate(_startsAt),
  'endsAt': Timestamp.fromDate(_endsAt),
  'placeId': 'pl01',
  'capacity': 40,
  'visibility': 'public',
  'status': published ? 'published' : 'draft',
  'coverSeed': 'event-$eventId',
  'coverPalette': 'red',
  'coverPattern': 'dots',
  'registrationOpen': true,
  'autoReminder': true,
  'goingCount': 0,
  'waitlistCount': 0,
  'attendedCount': 0,
  if (published) 'publishedAt': serverTimestampMark,
  ..._baseCreate,
};

Json _activity(String kind, String eventId, {String actorId = _manager}) => {
  'clubId': _clubId,
  'actorId': actorId,
  'kind': kind,
  'refs': {'eventId': eventId},
  'createdAt': serverTimestampMark,
};

Map<String, Object?> _write(String op, String path, Json data) => {
  'op': op,
  'path': path,
  'data': data,
};

/// Okunan belgede sunucu zamanı alanlarını ([keys]) nöbetçiyle değiştirir:
/// batch ile yazılan belge, kayıt tutulan transaction yüküyle aynı biçimde
/// karşılaştırılır.
Json _marked(
  Json data, [
  List<String> keys = const ['createdAt', 'updatedAt', 'publishedAt'],
]) => {
  for (final MapEntry(:key, :value) in data.entries)
    key: keys.contains(key) && value is Timestamp ? serverTimestampMark : value,
};

final EventDraft _draft = EventDraft(
  title: _title,
  desc: _desc,
  type: EventType.training,
  startsAt: _startsAt,
  endsAt: _endsAt,
  placeId: 'pl01',
  capacity: 40,
  coverPalette: ClubPalette.red,
  coverPattern: ClubPattern.dots,
);

EventDraft _draftWith({
  String title = _title,
  String desc = _desc,
  DateTime? startsAt,
  DateTime? endsAt,
  String? placeId,
  String? placeText,
  int? capacity,
}) => EventDraft(
  title: title,
  desc: desc,
  type: EventType.training,
  startsAt: startsAt ?? _startsAt,
  endsAt: endsAt ?? _endsAt,
  placeId: placeId,
  placeText: placeText,
  capacity: capacity,
  coverPalette: ClubPalette.red,
  coverPattern: ClubPattern.dots,
);

/// Tekil okumaları betikleyen servis çifti (`getEvents`): [errors] içindeki
/// yollar o hatayla döner, diğerleri [_inner] servisine gider; aynı anda
/// süren okuma sayısının en büyüğü [maxInFlight] ile izlenir.
final class _ScriptedReads implements FirestoreService {
  _ScriptedReads(this._inner, [this.errors = const {}]);

  final FirestoreService _inner;

  /// Belge yolu → o okumanın hatası.
  final Map<String, FirestoreError> errors;

  /// Okunan belge yolları, çağrı sırasıyla.
  final List<String> reads = [];

  /// Aynı anda süren en çok okuma sayısı.
  int maxInFlight = 0;

  int _inFlight = 0;

  @override
  DocumentReference<Json> doc(String collectionPath, String id) =>
      _inner.doc(collectionPath, id);

  @override
  Future<FirestoreResult<FirestoreDoc?>> getDoc(
    DocumentReference<Json> ref,
  ) async {
    reads.add(ref.path);
    _inFlight++;
    if (_inFlight > maxInFlight) maxInFlight = _inFlight;
    try {
      final error = errors[ref.path];
      // Askıya alınmadan dönen okuma eşzamanlılığı gizlerdi.
      await Future<void>.delayed(Duration.zero);
      return error == null ? await _inner.getDoc(ref) : FirebaseFailure(error);
    } finally {
      _inFlight--;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeFirebaseFirestore db;
  late RecordingFirestoreService service;
  late RecordingStorageService storage;
  late FakeAppClock clock;
  late EventRepository repository;

  EventRepository repositoryOn(FirestoreService firestore) =>
      FirebaseEventRepository(
        firestore,
        storage,
        FirebaseActivityRepository(firestore),
        clock,
        SequenceRandom(List<int>.generate(64, (i) => i)),
      );

  /// Her çağrısı [code] hatasıyla biten veritabanına bağlı repository.
  EventRepository failing(String code) => repositoryOn(
    FirebaseFirestoreService(StubFirestore(error: firestoreException(code))),
  );

  Future<Json?> read(String path) async => (await db.doc(path).get()).data();

  Future<List<String>> ids(String collection) async => [
    for (final doc in (await db.collection(collection).get()).docs) doc.id,
  ];

  /// Transaction'da kuyruğa giren yazımlar, sırayla.
  List<Map<String, Object?>> writes() => [
    for (final write in service.writes)
      _write(write.op, write.path, write.data),
  ];

  Future<void> seedEvent({
    String id = _eventId,
    String clubId = _clubId,
    String title = _title,
    EventStatus status = EventStatus.draft,
    EventVisibility visibility = EventVisibility.public,
    DateTime? startsAt,
    DateTime? endsAt,
    String? placeId = 'pl01',
    String? placeText,
    int? capacity = 40,
    int goingCount = 0,
    int waitlistCount = 0,
    int attendedCount = 0,
    bool registrationOpen = true,
    String? coverPath,
    String? cancelReason,
    DateTime? publishedAt,
    bool isDeleted = false,
  }) => db
      .doc('events/$id')
      .set(
        EventModel(
          clubId: clubId,
          createdBy: _manager,
          title: title,
          desc: _desc,
          type: EventType.training,
          startsAt: startsAt ?? _startsAt,
          endsAt:
              endsAt ?? (startsAt ?? _startsAt).add(const Duration(hours: 2)),
          placeId: placeId,
          placeText: placeText,
          capacity: capacity,
          visibility: visibility,
          status: status,
          cancelReason: cancelReason,
          coverSeed: 'event-$id',
          coverPalette: ClubPalette.red,
          coverPattern: ClubPattern.dots,
          coverPath: coverPath,
          registrationOpen: registrationOpen,
          goingCount: goingCount,
          waitlistCount: waitlistCount,
          attendedCount: attendedCount,
          publishedAt:
              publishedAt ??
              (status == EventStatus.draft ? null : _publishedAt),
          createdAt: _publishedAt,
          updatedAt: _publishedAt,
          isDeleted: isDeleted,
          deletedAt: isDeleted ? _publishedAt : null,
          deletedBy: isDeleted ? _manager : null,
        ).toJson(),
      );

  /// [result] [code] iş kuralının reddi mi (`detail` kodu taşır)?
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

  setUp(() {
    db = FakeFirebaseFirestore();
    service = RecordingFirestoreService(FirebaseFirestoreService(db));
    storage = RecordingStorageService();
    clock = FakeAppClock(_now);
    repository = repositoryOn(service);
  });

  group('T-22 · EventRepository · sözleşme', () {
    test('PLAN §10.4 tablosunun üyeleri arayüzde var; imzalar sözleşme '
        'sapmaları (uploadCover, listClubEvents.publicOnly — T-22 §6.10) '
        'dışında birebir', () {
      // PLAN bu iki üyeyi sözleşmeden farklı yazar (ya da hiç yazmaz); imzaları
      // aşağıda sözleşmedeki hâliyle beklenir.
      const deviating = {'uploadCover', 'listClubEvents'};
      final plan = [
        for (final row in readPlanRepositoryMembers('$EventRepository'))
          if (!deviating.contains(row.member)) row,
      ];

      expect(plan.map((row) => row.member), [
        'createDraft',
        'create',
        'update',
        'publish',
        'unpublish',
        'cancel',
        'duplicate',
        'setRegistrationOpen',
        'softDeleteEvent',
        'restoreEvent',
        'getEvent',
        'listPublicUpcoming',
        'listMembersUpcoming',
        'getEvents',
      ]);
      expect(interfaceMembers(_interface, '$EventRepository').toSet(), {
        for (final row in plan) normalizeDartSource(row.signature),
        normalizeDartSource(
          'Future<MediaUpdateResult<String>> uploadCover(String eventId, '
          'Uint8List bytes, {required String contentType, '
          'required String clubId, required String uploaderId})',
        ),
        normalizeDartSource(
          'Future<FirestoreResult<PageResult<EventModel>>> listClubEvents( '
          'String clubId, PageRequest page, {bool includeDrafts = false, '
          'bool publicOnly = false})',
        ),
      });
    });

    test('arayüzde ve uygulamada silme üyesi yok (D-10)', () {
      expect(deleteIdentifiersIn(_interface), isEmpty);
      expect(deleteIdentifiersIn(_implementation), isEmpty);
    });
  });

  group('T-22 · create / createDraft', () {
    test('taslak: yalnızca etkinlik belgesi, tek batch; sayaçlar sıfır, null '
        'alanların anahtarı yok, günlük yazılmaz', () async {
      final result = await repository.createDraft(
        _draft,
        clubId: _clubId,
        createdBy: _manager,
      );

      final model = result.dataOrNull!;
      expect(RepositoryHelpers.isValidId(model.id), isTrue);
      expect(service.outsideWrites, 1);
      expect(service.transactions, 0);
      expect(await ids('events'), [model.id]);
      expect(
        _marked((await read('events/${model.id}'))!),
        _eventCreate(model.id),
      );
      expect(await ids('activity'), isEmpty);

      expect(model.status, EventStatus.draft);
      expect(model.clubId, _clubId);
      expect(model.createdBy, _manager);
      expect(model.coverSeed, 'event-${model.id}');
      expect(model.coverPath, isNull);
      expect(model.publishedAt, isNull);
      expect(
        [model.goingCount, model.waitlistCount, model.attendedCount],
        [0, 0, 0],
      );
      expect(model.createdAt, _now);
    });

    test('doğrudan yayın: etkinlik (publishedAt sunucu zamanı) + '
        'event_published günlüğü tek batch', () async {
      final result = await repository.create(
        _draft,
        clubId: _clubId,
        createdBy: _manager,
        status: EventStatus.published,
      );

      final model = result.dataOrNull!;
      expect(service.outsideWrites, 1);
      expect(service.transactions, 0);
      expect(
        _marked((await read('events/${model.id}'))!),
        _eventCreate(model.id, published: true),
      );
      expect(await ids('activity'), [
        'c01_u_baskan_event_published_${model.id}',
      ]);
      expect(
        _marked(
          (await read('activity/c01_u_baskan_event_published_${model.id}'))!,
        ),
        _activity('event_published', model.id),
      );
      expect(model.status, EventStatus.published);
      expect(model.publishedAt, _now);
    });

    test('batch işlenemezse ne etkinlik ne günlük yazılır', () async {
      final broken = repositoryOn(
        FirebaseFirestoreService(
          FailingBatchFirestore(db, error: firestoreException('unavailable')),
        ),
      );

      final result = await broken.create(
        _draft,
        clubId: _clubId,
        createdBy: _manager,
        status: EventStatus.published,
      );

      expect(result.errorOrNull, FirestoreError.unavailable);
      expect(await ids('events'), isEmpty);
      expect(await ids('activity'), isEmpty);
    });

    test('iptal durumu ve alan kurallarına uymayan taslak invalidArgument; '
        'yayında başlangıç geçmişteyse eventEnded; hiçbir şey '
        'yazılmaz', () async {
      Future<FirestoreResult<EventModel>> create(
        EventDraft draft, {
        EventStatus status = EventStatus.draft,
      }) => repository.create(
        draft,
        clubId: _clubId,
        createdBy: _manager,
        status: status,
      );

      final invalid = [
        await create(_draft, status: EventStatus.cancelled),
        await create(_draftWith(title: '  ')),
        await create(_draftWith(title: 'a' * (Limits.eventTitleMax + 1))),
        await create(_draftWith(desc: 'a' * (Limits.eventDescMax + 1))),
        await create(_draftWith(placeId: 'pl99')),
        await create(_draftWith(placeText: 'a' * (Limits.placeTextMax + 1))),
        await create(_draftWith(capacity: 0)),
        await create(_draftWith(endsAt: _startsAt)),
      ];
      // Yayın koşulu `startsAt > şimdi`: sınırın kendisi de ret.
      final ended = await create(
        _draftWith(startsAt: _now, endsAt: _now.add(const Duration(hours: 1))),
        status: EventStatus.published,
      );

      for (final result in invalid) {
        expect(result.errorOrNull, FirestoreError.invalidArgument);
      }
      expectViolation(ended, FirestoreRuleCode.eventEnded);
      expect(service.outsideWrites, 0);
      expect(await ids('events'), isEmpty);
    });

    test('taslak geçmiş tarihli olabilir (yayın koşulu yalnızca '
        'yayında)', () async {
      final past = _now.subtract(const Duration(days: 3));

      final result = await repository.createDraft(
        _draftWith(startsAt: past, endsAt: past.add(const Duration(hours: 1))),
        clubId: _clubId,
        createdBy: _manager,
      );

      expect(result.dataOrNull!.status, EventStatus.draft);
    });
  });

  group('T-22 · update · içerik düzenleme', () {
    test('yalnızca verilen alanlar + updatedAt tek transaction; boşaltılan '
        'alan açık null; durum ve sayaçlar değişmez', () async {
      await seedEvent(
        status: EventStatus.published,
        goingCount: 3,
        waitlistCount: 1,
      );
      final newStart = DateTime.utc(2026, 10, 21, 10);

      final result = await repository.update(
        _eventId,
        EventEditPatch(
          title: 'Yeni başlık',
          startsAt: newStart,
          endsAt: newStart.add(const Duration(hours: 3)),
          placeText: 'Konferans Salonu',
          visibility: EventVisibility.membersOnly,
          type: EventType.social,
          coverPalette: ClubPalette.slate,
          clearPlaceId: true,
          clearCapacity: true,
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(service.transactions, 1);
      expect(service.outsideWrites, 0);
      expect(service.reads, [_eventPath]);
      expect(writes(), [
        _write('update', _eventPath, {
          'title': 'Yeni başlık',
          'type': 'sosyal',
          'startsAt': Timestamp.fromDate(newStart),
          'endsAt': Timestamp.fromDate(newStart.add(const Duration(hours: 3))),
          'placeId': null,
          'placeText': 'Konferans Salonu',
          'capacity': null,
          'visibility': 'members',
          'coverPalette': 'slate',
          'updatedAt': serverTimestampMark,
        }),
      ]);
      final after = (await read(_eventPath))!;
      expect(after['status'], 'published');
      expect(after['desc'], _desc);
      expect(after['goingCount'], 3);
      expect(after['waitlistCount'], 1);
      expect(after.containsKey('placeId'), isTrue);
      expect(after['placeId'], isNull);
    });

    test('kontenjan kayıtlı sayısına eşit olabilir; altına inerse '
        'capacityFull ve yazım yok', () async {
      await seedEvent(status: EventStatus.published, goingCount: 5);

      final equal = await repository.update(
        _eventId,
        const EventEditPatch(capacity: 5),
      );
      final below = await repository.update(
        _eventId,
        const EventEditPatch(capacity: 4),
      );

      expect(equal.isSuccess, isTrue);
      expectViolation(below, FirestoreRuleCode.capacityFull);
      expect((await read(_eventPath))!['capacity'], 5);
      expect(service.writes, hasLength(1));
    });

    test('yayındaki etkinliğin zamanı yalnızca başlamadan ve yeni başlangıç '
        'gelecekteyken değişir (güvenlik incelemesi: bitmiş etkinliğin '
        'bitişi ileri alınıp yoklama penceresi yeniden açılamaz) — '
        'eventEnded; taslakta ve değeri aynı kalan alanda serbest', () async {
      final started = _now.subtract(const Duration(hours: 3));
      final ended = _now.subtract(const Duration(hours: 1));
      await seedEvent(
        status: EventStatus.published,
        startsAt: started,
        endsAt: ended,
      );

      final reopened = await repository.update(
        _eventId,
        EventEditPatch(endsAt: _now.add(const Duration(days: 1))),
      );
      // Değeri aynı kalan zaman alanı + başka içerik: değişiklik sayılmaz.
      final sameTimes = await repository.update(
        _eventId,
        EventEditPatch(title: 'Yeni başlık', startsAt: started, endsAt: ended),
      );
      expectViolation(reopened, FirestoreRuleCode.eventEnded);
      expect(sameTimes.isSuccess, isTrue);
      expect((await read(_eventPath))!['endsAt'], Timestamp.fromDate(ended));

      // Gelecekteki yayında başlangıç geçmişe çekilemez (yayın koşulu).
      await seedEvent(id: 'e02', status: EventStatus.published);
      final backdated = await repository.update(
        'e02',
        EventEditPatch(startsAt: _now.subtract(const Duration(minutes: 1))),
      );
      expectViolation(backdated, FirestoreRuleCode.eventEnded);

      // Taslakta zaman serbest (yayın `startsAt > şimdi` ister).
      await seedEvent(id: 'e03', startsAt: started, endsAt: ended);
      final draft = await repository.update(
        'e03',
        EventEditPatch(endsAt: _now.add(const Duration(days: 1))),
      );
      expect(draft.isSuccess, isTrue);
      expect(service.writes, hasLength(2));
    });

    test('boş yama, değer + clear…, sınır dışı alan, başka etkinliğin kapak '
        'yolu ve yazım-sonrası endsAt <= startsAt invalidArgument', () async {
      await seedEvent();

      final results = [
        await repository.update(_eventId, const EventEditPatch()),
        await repository.update(
          _eventId,
          const EventEditPatch(placeId: 'pl02', clearPlaceId: true),
        ),
        await repository.update(
          _eventId,
          const EventEditPatch(capacity: 10, clearCapacity: true),
        ),
        await repository.update(_eventId, const EventEditPatch(title: ' ')),
        await repository.update(_eventId, const EventEditPatch(placeId: 'x')),
        await repository.update(_eventId, const EventEditPatch(capacity: 0)),
        await repository.update(
          _eventId,
          const EventEditPatch(
            coverPath: 'events/e02/20261014T090000Z_0001020304050607.jpg',
          ),
        ),
        await repository.update(
          _eventId,
          const EventEditPatch(coverPath: 'events/e01/cover.jpg'),
        ),
        // Yalnızca başlangıç değişti: belgedeki bitişin ötesine geçemez.
        await repository.update(
          _eventId,
          EventEditPatch(startsAt: _endsAt.add(const Duration(hours: 1))),
        ),
      ];

      for (final result in results) {
        expect(result.errorOrNull, FirestoreError.invalidArgument);
      }
      expect(service.writes, isEmpty);
    });

    test('iptal edilmiş etkinlik failedPrecondition; olmayan ve silinmiş '
        'notFound', () async {
      await seedEvent(status: EventStatus.cancelled, cancelReason: _reason);
      await seedEvent(id: 'e_silinmis', isDeleted: true);
      const patch = EventEditPatch(title: 'Yeni başlık');

      expect(
        (await repository.update(_eventId, patch)).errorOrNull,
        FirestoreError.failedPrecondition,
      );
      expect(
        (await repository.update('e_silinmis', patch)).errorOrNull,
        FirestoreError.notFound,
      );
      expect(
        (await repository.update('e_yok', patch)).errorOrNull,
        FirestoreError.notFound,
      );
      expect(service.writes, isEmpty);
    });
  });

  group('T-22 · durum geçişleri (draft → published → cancelled)', () {
    test('publish: status + publishedAt + ilk yayının günlüğü tek '
        'transaction', () async {
      await seedEvent();

      final result = await repository.publish(_eventId, actorId: _board);

      expect(result.isSuccess, isTrue);
      expect(service.transactions, 1);
      expect(service.outsideWrites, 0);
      expect(writes(), [
        _write('update', _eventPath, {
          'status': 'published',
          'publishedAt': serverTimestampMark,
          'updatedAt': serverTimestampMark,
        }),
        _write(
          'set',
          'activity/c01_u_yk_event_published_e01',
          _activity('event_published', _eventId, actorId: _board),
        ),
      ]);
      expect((await read(_eventPath))!['status'], 'published');
    });

    test('publish: yayından çekilmiş etkinlik yeniden yayınlanınca ikinci '
        'günlük yazılmaz', () async {
      await seedEvent(publishedAt: _publishedAt);

      final result = await repository.publish(_eventId, actorId: _manager);

      expect(result.isSuccess, isTrue);
      expect(writes().map((write) => write['path']), [_eventPath]);
      expect(await ids('activity'), isEmpty);
    });

    test('publish: taslak olmayan failedPrecondition; başlangıç geçmişte '
        'eventEnded; olmayan / silinmiş notFound; yazım yok', () async {
      await seedEvent(id: 'e_yayinda', status: EventStatus.published);
      await seedEvent(id: 'e_iptal', status: EventStatus.cancelled);
      await seedEvent(id: 'e_gecmis', startsAt: _now);
      await seedEvent(id: 'e_silinmis', isDeleted: true);

      Future<FirestoreResult<void>> publish(String id) =>
          repository.publish(id, actorId: _manager);

      expect(
        (await publish('e_yayinda')).errorOrNull,
        FirestoreError.failedPrecondition,
      );
      expect(
        (await publish('e_iptal')).errorOrNull,
        FirestoreError.failedPrecondition,
      );
      expectViolation(await publish('e_gecmis'), FirestoreRuleCode.eventEnded);
      expect(
        (await publish('e_silinmis')).errorOrNull,
        FirestoreError.notFound,
      );
      expect((await publish('e_yok')).errorOrNull, FirestoreError.notFound);
      expect(service.writes, isEmpty);
    });

    test('unpublish: yalnızca status + updatedAt; publishedAt korunur; '
        'bekleme listesi engel değildir', () async {
      await seedEvent(status: EventStatus.published, waitlistCount: 2);

      final result = await repository.unpublish(_eventId);

      expect(result.isSuccess, isTrue);
      expect(service.transactions, 1);
      expect(writes(), [
        _write('update', _eventPath, {
          'status': 'draft',
          'updatedAt': serverTimestampMark,
        }),
      ]);
      final after = (await read(_eventPath))!;
      expect(after['publishedAt'], Timestamp.fromDate(_publishedAt));
      expect(after['waitlistCount'], 2);
    });

    test('unpublish: kayıtlı varken eventHasRegistrations (K-F); yayında '
        'olmayan failedPrecondition; yazım yok', () async {
      await seedEvent(status: EventStatus.published, goingCount: 1);
      await seedEvent(id: 'e_taslak');
      await seedEvent(id: 'e_iptal', status: EventStatus.cancelled);

      expectViolation(
        await repository.unpublish(_eventId),
        FirestoreRuleCode.eventHasRegistrations,
      );
      expect(
        (await repository.unpublish('e_taslak')).errorOrNull,
        FirestoreError.failedPrecondition,
      );
      expect(
        (await repository.unpublish('e_iptal')).errorOrNull,
        FirestoreError.failedPrecondition,
      );
      expect((await read(_eventPath))!['status'], 'published');
      expect(service.writes, isEmpty);
    });

    test('cancel: status + kırpılmış neden + event_cancelled günlüğü tek '
        'transaction; sayaçlara dokunulmaz', () async {
      await seedEvent(
        status: EventStatus.published,
        goingCount: 7,
        waitlistCount: 2,
        attendedCount: 1,
      );

      final result = await repository.cancel(
        _eventId,
        reason: '  $_reason \n',
        actorId: _manager,
      );

      expect(result.isSuccess, isTrue);
      expect(service.transactions, 1);
      expect(service.outsideWrites, 0);
      expect(writes(), [
        _write('update', _eventPath, {
          'status': 'cancelled',
          'cancelReason': _reason,
          'updatedAt': serverTimestampMark,
        }),
        _write(
          'set',
          'activity/c01_u_baskan_event_cancelled_e01',
          _activity('event_cancelled', _eventId),
        ),
      ]);
      final after = (await read(_eventPath))!;
      expect(
        [after['goingCount'], after['waitlistCount'], after['attendedCount']],
        [7, 2, 1],
      );
    });

    test('cancel: boş / sınır üstü neden invalidArgument; yayında olmayan '
        '(taslak, zaten iptal) failedPrecondition; yazım yok', () async {
      await seedEvent(status: EventStatus.published);
      await seedEvent(id: 'e_taslak');
      await seedEvent(id: 'e_iptal', status: EventStatus.cancelled);

      Future<FirestoreResult<void>> cancel(
        String id, {
        String reason = _reason,
      }) => repository.cancel(id, reason: reason, actorId: _manager);

      expect(
        (await cancel(_eventId, reason: ' \n ')).errorOrNull,
        FirestoreError.invalidArgument,
      );
      expect(
        (await cancel(
          _eventId,
          reason: 'a' * (Limits.adminReasonMax + 1),
        )).errorOrNull,
        FirestoreError.invalidArgument,
      );
      expect(
        (await cancel('e_taslak')).errorOrNull,
        FirestoreError.failedPrecondition,
      );
      expect(
        (await cancel('e_iptal')).errorOrNull,
        FirestoreError.failedPrecondition,
      );
      expect(service.writes, isEmpty);
      expect(await ids('activity'), isEmpty);
    });
  });

  group('T-22 · duplicate · kopyalama', () {
    test('yeni taslak: içerik aynen, tarih +7 gün, başlık + ek; sayaçlar '
        'sıfır, durum taslak, kapak / yayın anı / iptal nedeni kopyalanmaz; '
        'kaynak değişmez', () async {
      await seedEvent(
        status: EventStatus.cancelled,
        cancelReason: _reason,
        goingCount: 12,
        waitlistCount: 3,
        attendedCount: 4,
        coverPath: _firstCover,
      );
      final before = await read(_eventPath);

      final result = await repository.duplicate(
        _eventId,
        createdBy: _board,
        copyTitleSuffix: _copySuffix,
      );

      final copy = result.dataOrNull!;
      expect(copy.id, isNot(_eventId));
      expect(await ids('events'), unorderedEquals([_eventId, copy.id]));
      expect(_marked((await read('events/${copy.id}'))!), {
        ..._eventCreate(copy.id, createdBy: _board),
        'title': '$_title$_copySuffix',
        'startsAt': Timestamp.fromDate(_startsAt.add(Limits.eventCopyShift)),
        'endsAt': Timestamp.fromDate(_endsAt.add(Limits.eventCopyShift)),
      });
      expect(copy.status, EventStatus.draft);
      expect(copy.clubId, _clubId);
      expect(await read(_eventPath), before);
      expect(await ids('activity'), isEmpty);
    });

    test('başlık Limits.eventTitleMax sınırına sığacak şekilde kısaltılır '
        '(sondaki boşluk atılır, vekil çift bölünmez); ek tek başına sığmazsa '
        'invalidArgument', () async {
      // Ek 8 birim: kaynak başlığa 72 birim kalır.
      final cases = {
        'a' * Limits.eventTitleMax: '${'a' * 72}$_copySuffix',
        '${'a' * 71} ${'b' * 8}': '${'a' * 71}$_copySuffix',
        '${'a' * 71}😀${'b' * 6}': '${'a' * 71}$_copySuffix',
      };
      for (final MapEntry(key: title, value: expected) in cases.entries) {
        await seedEvent(title: title);

        final copy = await repository.duplicate(
          _eventId,
          createdBy: _manager,
          copyTitleSuffix: _copySuffix,
        );

        expect(copy.dataOrNull!.title, expected);
        expect(expected.length, lessThanOrEqualTo(Limits.eventTitleMax));
      }

      final tooLong = await repository.duplicate(
        _eventId,
        createdBy: _manager,
        copyTitleSuffix: 'x' * (Limits.eventTitleMax + 1),
      );
      expect(tooLong.errorOrNull, FirestoreError.invalidArgument);
    });

    test('kaynak yok ya da silinmiş → notFound; hiçbir şey yazılmaz', () async {
      await seedEvent(isDeleted: true);

      for (final id in [_eventId, 'e_yok']) {
        final result = await repository.duplicate(
          id,
          createdBy: _manager,
          copyTitleSuffix: _copySuffix,
        );
        expect(result.errorOrNull, FirestoreError.notFound);
      }
      expect(service.outsideWrites, 0);
      expect(await ids('events'), [_eventId]);
    });
  });

  group('T-22 · setRegistrationOpen · softDeleteEvent · restoreEvent', () {
    test('setRegistrationOpen: tek ve kör yazım (registrationOpen + '
        'updatedAt)', () async {
      await seedEvent(status: EventStatus.published);
      final before = (await read(_eventPath))!;

      final result = await repository.setRegistrationOpen(_eventId, false);

      expect(result.isSuccess, isTrue);
      expect(service.outsideWrites, 1);
      expect(service.transactions, 0);
      final after = (await read(_eventPath))!;
      expect(after['registrationOpen'], isFalse);
      expect(after['updatedAt'], isNot(before['updatedAt']));
      expect(
        {...after}..removeWhere(
          (key, _) => key == 'registrationOpen' || key == 'updatedAt',
        ),
        {...before}..removeWhere(
          (key, _) => key == 'registrationOpen' || key == 'updatedAt',
        ),
      );
    });

    test('softDeleteEvent: taslak okunur ve yalnızca silme alanları yazılır '
        '(belge yerinde kalır)', () async {
      await seedEvent();

      final result = await repository.softDeleteEvent(
        _eventId,
        actorId: _manager,
      );

      expect(result.isSuccess, isTrue);
      expect(service.transactions, 1);
      expect(service.outsideWrites, 0);
      expect(writes(), [
        _write('update', _eventPath, {
          'isDeleted': true,
          'deletedAt': serverTimestampMark,
          'deletedBy': _manager,
          'updatedAt': serverTimestampMark,
        }),
      ]);
      final after = (await read(_eventPath))!;
      expect(after['isDeleted'], isTrue);
      expect(after['title'], _title);
      expect(after['status'], 'draft');
    });

    test('softDeleteEvent: yayındaki ve iptal edilmiş etkinlik '
        'failedPrecondition (kaldırılamaz); olmayan / zaten silinmiş '
        'notFound; yazım yok', () async {
      await seedEvent(status: EventStatus.published);
      await seedEvent(id: 'e_iptal', status: EventStatus.cancelled);
      await seedEvent(id: 'e_silinmis', isDeleted: true);

      Future<FirestoreResult<void>> remove(String id) =>
          repository.softDeleteEvent(id, actorId: _manager);

      expect(
        (await remove(_eventId)).errorOrNull,
        FirestoreError.failedPrecondition,
      );
      expect(
        (await remove('e_iptal')).errorOrNull,
        FirestoreError.failedPrecondition,
      );
      expect((await remove('e_silinmis')).errorOrNull, FirestoreError.notFound);
      expect((await remove('e_yok')).errorOrNull, FirestoreError.notFound);
      expect(service.writes, isEmpty);
      expect((await read(_eventPath))!['isDeleted'], isFalse);
    });

    test('restoreEvent: tek ve kör yazım; silme alanları geri alınır (null '
        'yazılır)', () async {
      await seedEvent(isDeleted: true);

      final result = await repository.restoreEvent(_eventId);

      expect(result.isSuccess, isTrue);
      expect(service.outsideWrites, 1);
      expect(service.transactions, 0);
      final after = (await read(_eventPath))!;
      expect(after['isDeleted'], isFalse);
      expect(after.containsKey('deletedAt'), isTrue);
      expect(after['deletedAt'], isNull);
      expect(after['deletedBy'], isNull);
      expect(after['status'], 'draft');
      expect((await repository.getEvent(_eventId)).dataOrNull!.id, _eventId);
    });
  });

  group('T-22 · uploadCover · özel kapak (CD-47)', () {
    Future<MediaUpdateResult<String>> upload({
      EventRepository? on,
      String eventId = _eventId,
      int length = 3,
      String contentType = 'image/jpeg',
      String clubId = _clubId,
      String uploaderId = _manager,
    }) => (on ?? repository).uploadCover(
      eventId,
      Uint8List(length),
      contentType: contentType,
      clubId: clubId,
      uploaderId: uploaderId,
    );

    test('dosya events/{eventId}/{yeni ad} yoluna yalnızca clubId + '
        'uploaderId üst verisiyle yüklenir, sonra coverPath tek yazımla '
        'çekilir; ikinci kapak yeni adla gider (üzerine yazma yok)', () async {
      await seedEvent(status: EventStatus.published, goingCount: 2);
      final bytes = Uint8List.fromList([1, 2, 3]);

      final first = await repository.uploadCover(
        _eventId,
        bytes,
        contentType: 'image/jpeg',
        clubId: _clubId,
        uploaderId: _manager,
      );

      expect(first.dataOrNull, _firstCover);
      expect(StoragePaths.isEventCover(_firstCover, _eventId), isTrue);
      final recorded = storage.uploads.single;
      expect(recorded.path, _firstCover);
      expect(recorded.bytes, same(bytes));
      expect(recorded.contentType, 'image/jpeg');
      // Rules: `uploaderId == request.auth.uid`, `isManagerOf(clubId)`.
      expect(recorded.customMetadata, {
        'clubId': _clubId,
        'uploaderId': _manager,
      });
      expect(service.outsideWrites, 1);
      expect(service.transactions, 0);
      final after = (await read(_eventPath))!;
      expect(after['coverPath'], _firstCover);
      expect(after['updatedAt'], isNot(Timestamp.fromDate(_publishedAt)));
      expect(after['status'], 'published');
      expect(after['goingCount'], 2);

      final second = await upload(contentType: 'image/png');

      expect(second.dataOrNull, _secondCover);
      expect(storage.uploads.map((upload) => upload.path), [
        _firstCover,
        _secondCover,
      ]);
      expect((await read(_eventPath))!['coverPath'], _secondCover);
    });

    test('ön denetim dosya gönderilmeden: geçersiz kimlik belge hatası; '
        'izinsiz tür, boş ve sınırdaki dosya yükleme hatası', () async {
      await seedEvent();

      for (final id in _invalidIds) {
        for (final result in [
          await upload(eventId: id),
          await upload(clubId: id),
          await upload(uploaderId: id),
        ]) {
          expect(
            result.errorOrNull,
            const MediaDocumentError(FirestoreError.invalidArgument),
            reason: 'kimlik "$id"',
          );
        }
      }
      expect(
        (await upload(contentType: 'image/gif')).errorOrNull,
        const MediaUploadError(StorageError.invalidType),
      );
      expect(
        (await upload(length: 0)).errorOrNull,
        const MediaUploadError(StorageError.noFile),
      );
      // Storage Rules `size < imageMaxBytes`: sınırın kendisi de ret.
      expect(
        (await upload(length: Limits.imageMaxBytes)).errorOrNull,
        const MediaUploadError(StorageError.sizeLimit),
      );
      expect(storage.uploads, isEmpty);
      expect(service.outsideWrites, 0);
      expect((await read(_eventPath))!.containsKey('coverPath'), isFalse);

      expect(
        (await upload(length: Limits.imageMaxBytes - 1)).dataOrNull,
        _firstCover,
      );
    });

    test('yükleme reddi (yönetici olmayan) yükleme hatası olarak döner; '
        'coverPath yazılmaz', () async {
      await seedEvent();
      storage.nextError = StorageError.unauthorized;

      final result = await upload();

      expect(
        result.errorOrNull,
        const MediaUploadError(StorageError.unauthorized),
      );
      expect(result.errorOrNull!.firestore, isNull);
      expect(service.outsideWrites, 0);
      expect((await read(_eventPath))!.containsKey('coverPath'), isFalse);
    });

    test('dosya yüklendi ama coverPath yazılamadı (Rules reddi, etkinlik '
        'yok) → belge hatası; dosya yerinde kalır (D-10)', () async {
      final denied = await upload(on: failing('permission-denied'));
      final missing = await upload(eventId: 'e_yok');

      expect(
        denied.errorOrNull,
        const MediaDocumentError(FirestoreError.permissionDenied),
      );
      expect(denied.errorOrNull!.storage, isNull);
      expect(
        missing.errorOrNull,
        const MediaDocumentError(FirestoreError.notFound),
      );
      expect(storage.uploads, hasLength(2));
      expect(await ids('events'), isEmpty);
    });
  });

  group('T-22 · okumalar ve liste sorguları', () {
    /// `fromUtc` sınırı: bu andan önce başlayan etkinlik "yaklaşan" değildir.
    final from = DateTime.utc(2026, 10, 14);

    DateTime day(int day) => DateTime.utc(2026, 10, day, 12);

    Future<void> seedAll() async {
      const published = EventStatus.published;
      const members = EventVisibility.membersOnly;
      // c01 · herkese açık.
      await seedEvent(id: 'p_gecmis', status: published, startsAt: day(10));
      await seedEvent(id: 'p_sinir', status: published, startsAt: from);
      await seedEvent(id: 'p_yakin', status: published, startsAt: day(15));
      await seedEvent(
        id: 'p_iptal',
        status: EventStatus.cancelled,
        startsAt: day(16),
      );
      await seedEvent(id: 'p_taslak', startsAt: day(17));
      await seedEvent(
        id: 'p_silinmis',
        status: published,
        startsAt: day(18),
        isDeleted: true,
      );
      // c01 · üyelere özel.
      await seedEvent(
        id: 'm_gecmis',
        status: published,
        visibility: members,
        startsAt: day(11),
      );
      await seedEvent(
        id: 'm_yakin',
        status: published,
        visibility: members,
        startsAt: day(19),
      );
      await seedEvent(
        id: 'm_iptal',
        status: EventStatus.cancelled,
        visibility: members,
        startsAt: day(20),
      );
      await seedEvent(id: 'm_taslak', visibility: members, startsAt: day(21));
      await seedEvent(
        id: 'm_silinmis',
        status: published,
        visibility: members,
        startsAt: day(22),
        isDeleted: true,
      );
      // Başka kulüp.
      await seedEvent(
        id: 'x_acik',
        clubId: 'c02',
        status: published,
        startsAt: day(23),
      );
      await seedEvent(
        id: 'x_uye',
        clubId: 'c02',
        status: published,
        visibility: members,
        startsAt: day(24),
      );
    }

    List<String> idsOf(FirestoreResult<List<EventModel>> result) => [
      for (final event in result.dataOrNull!) event.id,
    ];

    List<String> pageIds(FirestoreResult<PageResult<EventModel>> page) => [
      for (final event in page.dataOrNull!.items) event.id,
    ];

    test('listPublicUpcoming: herkese açık + yayında / iptal + silinmemiş + '
        'startsAt >= from (sınır dahil), en yakın üstte, tüm '
        'kulüplerden', () async {
      await seedAll();

      final result = await repository.listPublicUpcoming(fromUtc: from);

      expect(idsOf(result), ['p_sinir', 'p_yakin', 'p_iptal', 'x_acik']);
    });

    test('listMembersUpcoming: yalnızca bu kulübün üyelere özel, yayında / '
        'iptal, silinmemiş, yaklaşan etkinlikleri', () async {
      await seedAll();

      final own = await repository.listMembersUpcoming(_clubId, fromUtc: from);
      final other = await repository.listMembersUpcoming('c02', fromUtc: from);

      expect(idsOf(own), ['m_yakin', 'm_iptal']);
      expect(idsOf(other), ['x_uye']);
    });

    test('listClubEvents: yönetim taslaklar dahil her şeyi, üye yayında / '
        'iptal olanları, ziyaretçi yalnızca herkese açıkları görür; '
        'silinmişler hiçbirinde yok; en yeni başlangıç üstte', () async {
      await seedAll();
      const all = PageRequest(limit: 50);

      final management = await repository.listClubEvents(
        _clubId,
        all,
        includeDrafts: true,
      );
      final member = await repository.listClubEvents(_clubId, all);
      final visitor = await repository.listClubEvents(
        _clubId,
        all,
        publicOnly: true,
      );

      expect(pageIds(management), [
        'm_taslak',
        'm_iptal',
        'm_yakin',
        'p_taslak',
        'p_iptal',
        'p_yakin',
        'p_sinir',
        'm_gecmis',
        'p_gecmis',
      ]);
      expect(pageIds(member), [
        'm_iptal',
        'm_yakin',
        'p_iptal',
        'p_yakin',
        'p_sinir',
        'm_gecmis',
        'p_gecmis',
      ]);
      expect(pageIds(visitor), ['p_iptal', 'p_yakin', 'p_sinir', 'p_gecmis']);
    });

    test('listClubEvents: sayfalıdır; includeDrafts + publicOnly birlikte '
        'invalidArgument', () async {
      await seedAll();

      final first = await repository.listClubEvents(
        _clubId,
        const PageRequest(limit: 3),
        publicOnly: true,
      );
      final second = await repository.listClubEvents(
        _clubId,
        PageRequest(limit: 3, after: first.dataOrNull!.next),
        publicOnly: true,
      );
      final both = await repository.listClubEvents(
        _clubId,
        const PageRequest(),
        includeDrafts: true,
        publicOnly: true,
      );

      expect(pageIds(first), ['p_iptal', 'p_yakin', 'p_sinir']);
      expect(first.dataOrNull!.hasMore, isTrue);
      expect(pageIds(second), ['p_gecmis']);
      expect(second.dataOrNull!.hasMore, isFalse);
      expect(both.errorOrNull, FirestoreError.invalidArgument);
    });

    test('getEvent: etkinlik (taslak dahil) döner; silinmiş ve olmayan '
        'notFound', () async {
      await seedAll();

      final found = await repository.getEvent('m_taslak');

      expect(found.dataOrNull!.id, 'm_taslak');
      expect(found.dataOrNull!.visibility, EventVisibility.membersOnly);
      expect(found.dataOrNull!.startsAt, day(21));
      expect(found.dataOrNull!.coverSeed, 'event-m_taslak');
      expect(
        (await repository.getEvent('p_silinmis')).errorOrNull,
        FirestoreError.notFound,
      );
      expect(
        (await repository.getEvent('e_yok')).errorOrNull,
        FirestoreError.notFound,
      );
    });

    test('getEvents: girdi sırasıyla ve tekilleştirilmiş; göremediği '
        '(permissionDenied), olmayan ve silinmiş etkinlik atlanır; boş liste '
        'okuma yapmaz', () async {
      await seedAll();
      final scripted = _ScriptedReads(service, const {
        'events/m_yakin': FirestoreError.permissionDenied,
      });
      final reader = repositoryOn(scripted);

      final result = await reader.getEvents([
        'x_uye',
        'm_yakin',
        'p_taslak',
        'e_yok',
        'p_silinmis',
        'x_uye',
        'p_gecmis',
      ]);

      expect(idsOf(result), ['x_uye', 'p_taslak', 'p_gecmis']);
      // Liste sorgusu değil, kimlik başına tek okuma.
      expect(scripted.reads, [
        'events/x_uye',
        'events/m_yakin',
        'events/p_taslak',
        'events/e_yok',
        'events/p_silinmis',
        'events/p_gecmis',
      ]);

      scripted.reads.clear();
      expect((await reader.getEvents([])).dataOrNull, isEmpty);
      expect(scripted.reads, isEmpty);
    });

    test('getEvents: başka bir hata tüm çağrıyı başarısız kılar; aynı anda '
        'en çok whereInMax okuma yapılır', () async {
      final many = [
        for (var i = 0; i < RepositoryHelpers.whereInMax + 1; i++)
          'e${i.toString().padLeft(2, '0')}',
      ];
      for (final id in many) {
        await seedEvent(id: id, status: EventStatus.published);
      }
      final healthy = _ScriptedReads(service);
      final broken = _ScriptedReads(service, const {
        'events/e03': FirestoreError.unavailable,
      });

      final all = await repositoryOn(healthy).getEvents(many);
      final failed = await repositoryOn(broken).getEvents(many);

      expect(idsOf(all), many);
      expect(healthy.maxInFlight, RepositoryHelpers.whereInMax);
      expect(failed.errorOrNull, FirestoreError.unavailable);
    });
  });

  group('T-22 · geçersiz kimlik, ayrıştırma ve hata eşlemesi', () {
    const patch = EventEditPatch(title: 'Yeni başlık');

    test('geçersiz kimlik invalidArgument döner, hiçbir çağrı yapılmaz '
        '(W-54)', () async {
      for (final id in _invalidIds) {
        final results = <FirestoreResult<Object?>>[
          await repository.createDraft(_draft, clubId: id, createdBy: _manager),
          await repository.createDraft(_draft, clubId: _clubId, createdBy: id),
          await repository.create(
            _draft,
            clubId: id,
            createdBy: _manager,
            status: EventStatus.published,
          ),
          await repository.update(id, patch),
          await repository.publish(id, actorId: _manager),
          await repository.publish(_eventId, actorId: id),
          await repository.unpublish(id),
          await repository.cancel(id, reason: _reason, actorId: _manager),
          await repository.cancel(_eventId, reason: _reason, actorId: id),
          await repository.duplicate(
            id,
            createdBy: _manager,
            copyTitleSuffix: _copySuffix,
          ),
          await repository.duplicate(
            _eventId,
            createdBy: id,
            copyTitleSuffix: _copySuffix,
          ),
          await repository.setRegistrationOpen(id, true),
          await repository.softDeleteEvent(id, actorId: _manager),
          await repository.softDeleteEvent(_eventId, actorId: id),
          await repository.restoreEvent(id),
          await repository.getEvent(id),
          await repository.listMembersUpcoming(id, fromUtc: _now),
          await repository.listClubEvents(id, const PageRequest()),
          await repository.getEvents([_eventId, id]),
        ];
        for (final result in results) {
          expect(
            result.errorOrNull,
            FirestoreError.invalidArgument,
            reason: 'kimlik "$id"',
          );
        }
      }
      expect(service.transactions, 0);
      expect(service.outsideWrites, 0);
      expect(service.reads, isEmpty);
    });

    test('ayrıştırılamayan etkinlik belgesi parse (okuma ve geçiş)', () async {
      await db.doc(_eventPath).set({
        'clubId': _clubId,
        'title': _title,
        'type': 'bilinmeyen',
        'startsAt': Timestamp.fromDate(_startsAt),
        'endsAt': Timestamp.fromDate(_endsAt),
        'coverPalette': 'red',
        'coverPattern': 'dots',
        'visibility': 'public',
        'status': 'published',
        'isDeleted': false,
      });

      final results = <FirestoreResult<Object?>>[
        await repository.getEvent(_eventId),
        await repository.getEvents([_eventId]),
        await repository.listPublicUpcoming(fromUtc: _now),
        await repository.listClubEvents(_clubId, const PageRequest()),
        await repository.update(_eventId, patch),
        await repository.publish(_eventId, actorId: _manager),
        await repository.unpublish(_eventId),
        await repository.cancel(_eventId, reason: _reason, actorId: _manager),
        await repository.softDeleteEvent(_eventId, actorId: _manager),
        await repository.duplicate(
          _eventId,
          createdBy: _manager,
          copyTitleSuffix: _copySuffix,
        ),
      ];

      for (final result in results) {
        expect(result.errorOrNull, FirestoreError.parse);
      }
      expect(service.writes, isEmpty);
      expect(service.outsideWrites, 0);
    });

    test(
      'SDK hatası sözlüğe çevrilir (yetkisiz çağrı permissionDenied)',
      () async {
        final denied = failing('permission-denied');

        final results = <FirestoreResult<Object?>>[
          await denied.createDraft(
            _draft,
            clubId: _clubId,
            createdBy: _manager,
          ),
          await denied.create(
            _draft,
            clubId: _clubId,
            createdBy: _manager,
            status: EventStatus.published,
          ),
          await denied.update(_eventId, patch),
          await denied.publish(_eventId, actorId: _manager),
          await denied.unpublish(_eventId),
          await denied.cancel(_eventId, reason: _reason, actorId: _manager),
          await denied.duplicate(
            _eventId,
            createdBy: _manager,
            copyTitleSuffix: _copySuffix,
          ),
          await denied.setRegistrationOpen(_eventId, false),
          await denied.softDeleteEvent(_eventId, actorId: _manager),
          await denied.restoreEvent(_eventId),
          await denied.getEvent(_eventId),
        ];

        for (final result in results) {
          expect(result.errorOrNull, FirestoreError.permissionDenied);
        }
        // `getEvents`: göremediği etkinlik hata değildir, sonuçta yer almaz.
        expect((await denied.getEvents([_eventId])).dataOrNull, isEmpty);
      },
    );
  });
}
