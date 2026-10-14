// T-25 · NotificationRepository + NotificationWriter: canlı gelen kutusu
// (sahibi + silinmemiş, en yeni üstte, sınır), okundu işareti, "Tümünü okundu
// say" (Limits.batchMaxWrites parçaları, ilk hatada durma), kaydırarak silme /
// geri alma (soft delete), cihazın kendi hatırlatıcı belgesi (createSelf: önce
// okuma, varsa yazım yok), dağıtıcının yazma kapısı (newEventKey, addToBatch,
// createMany: kimlik `{type}_{eventKey}_{userId}`, W-51 yük, taslak / alıcı
// doğrulaması), Security Rules reddi ve hata eşlemesi, kimlik doğrulaması
// (W-54) (PLAN §10.4, §10.6; rules-spec §3.9, §6; docs/plans/T-25.md §6;
// D-10, W-49, CD-44, CD-147).
//
// Mutlu yollar `fake_cloud_firestore` ile (Q-06); hata yolları el yazımı
// çiftlerle (`test/fakes/sdk_firestore_stubs.dart`). Batch içeriği, batch'e
// giren yazımları kaydeden servis çiftiyle kanıtlanır.
//
// SDK sınıfları `@sealed` işaretlidir; test çifti bilerek uygular.
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/recording_firestore_service.dart';
import '../fakes/sdk_firestore_stubs.dart';
import '../helpers/plan_repository_table.dart';
import '../helpers/plan_service_table.dart';

const String _interface =
    'packages/gu_data/lib/src/repositories/notification_repository.dart';
const String _writer =
    'packages/gu_data/lib/src/notifications/notification_writer.dart';
const String _implementation =
    'packages/gu_data/lib/src/repositories/'
    'firebase_notification_repository.dart';
const String _uid = 'u_ayse';
const String _other = 'u_mehmet';
const String _clubId = 'c01';
const String _eventId = 'e01';
const String _postId = 'p01';

/// Dağıtıcı türlerinin olay anahtarı biçimi (20 karakter `[A-Za-z0-9]`).
const String _key = 'AbCdEfGhIjKlMnOpQrSt';

/// `event_reminder` belgesinin deterministik kimliği.
const String _reminderId = 'event_reminder_${_eventId}_$_uid';

/// Geçersiz belge kimlikleri (W-54).
const List<String> _invalidIds = ['', 'n/1', '..', '__id__'];

/// Tohum belgelerin zaman damgası (sunucu zamanından ayırt edilir).
final Timestamp _seededAt = Timestamp.fromDate(DateTime.utc(2026, 9));

/// Duyuru bildirimi taslağı (zorunlu referanslar: kulüp + gönderi).
const NotificationDraft _announcement = NotificationDraft(
  type: NotificationType.announcement,
  eventKey: _key,
  refs: NotificationRefsModel(clubId: _clubId, postId: _postId),
);

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreService service;
  late FirebaseNotificationRepository repository;

  Future<Json?> notification(String id) async =>
      (await db.collection('notifications').doc(id).get()).data();

  Future<List<String>> notificationIds() async => [
    for (final doc in (await db.collection('notifications').get()).docs) doc.id,
  ];

  Future<void> seed(
    String id, {
    String userId = _uid,
    int minute = 0,
    bool read = false,
    bool isDeleted = false,
  }) => db.collection('notifications').doc(id).set({
    'userId': userId,
    'type': 'announcement',
    'refs': {'clubId': _clubId, 'postId': _postId},
    'read': read,
    'createdAt': Timestamp.fromDate(DateTime.utc(2026, 10, 13, 8, minute)),
    'updatedAt': _seededAt,
    'isDeleted': isDeleted,
    'deletedAt': isDeleted ? _seededAt : null,
    'deletedBy': isDeleted ? userId : null,
  });

  /// Duyuru taslağının [userId] için beklenen yükü.
  Json announcementPayload(String userId) => {
    'userId': userId,
    'type': 'announcement',
    'refs': {'clubId': _clubId, 'postId': _postId},
    'read': false,
    'isDeleted': false,
    'createdAt': serverTimestampMark,
    'updatedAt': serverTimestampMark,
    'deletedAt': null,
    'deletedBy': null,
  };

  /// Her çağrısı [code] hatasıyla biten veritabanına bağlı repository.
  FirebaseNotificationRepository failing(String code) =>
      FirebaseNotificationRepository(
        FirebaseFirestoreService(
          StubFirestore(error: firestoreException(code)),
        ),
      );

  setUp(() {
    db = FakeFirebaseFirestore();
    service = FirebaseFirestoreService(db);
    repository = FirebaseNotificationRepository(service);
  });

  group('T-25 · NotificationRepository · sözleşme', () {
    test(
      'PLAN §10.4 tablosu: okuma / güncelleme üyeleri ve createSelf '
      'NotificationRepository içinde, addToBatch / createMany (+ newEventKey) '
      'NotificationWriter içinde aynı imzayla; watchUnreadCount yazılmaz',
      () {
        final plan = {
          for (final row in readPlanRepositoryMembers(
            '$NotificationRepository',
          ))
            row.member: normalizeDartSource(row.signature),
        };
        const writerMembers = {'addToBatch', 'createMany'};

        expect(plan.keys, [
          'watchInbox',
          'watchUnreadCount',
          'markRead',
          'markAllRead',
          'softDeleteNotification',
          'restoreNotification',
          'addToBatch',
          'createMany',
          'createSelf',
        ]);
        expect(
          interfaceMembers(_interface, '$NotificationRepository').toSet(),
          {
            for (final MapEntry(key: member, value: signature) in plan.entries)
              if (!writerMembers.contains(member) &&
                  member != 'watchUnreadCount')
                signature,
          },
        );
        expect(interfaceMembers(_writer, '$NotificationWriter').toSet(), {
          normalizeDartSource('String newEventKey()'),
          for (final member in writerMembers) plan[member],
        });
        expect(repository, isA<NotificationWriter>());
      },
    );

    test('arayüzlerde ve uygulamada silme üyesi yok (D-10)', () {
      expect(deleteIdentifiersIn(_interface), isEmpty);
      expect(deleteIdentifiersIn(_writer), isEmpty);
      expect(deleteIdentifiersIn(_implementation), isEmpty);
    });
  });

  group('T-25 · NotificationRepository · watchInbox', () {
    test('yalnızca sahibinin silinmemiş bildirimleri, en yeni üstte, en çok '
        'limit kadar; okundu / sil / geri al canlı yansır', () async {
      await seed('n_eski', minute: 1);
      await seed('n_orta', minute: 3);
      await seed('n_yeni', minute: 5);
      await seed('n_silinmis', minute: 9, isDeleted: true);
      await seed('n_baskasi', minute: 9, userId: _other);
      final events = <List<(String, bool)>>[];
      final subscription = repository
          .watchInbox(_uid, limit: 2)
          .listen(
            (event) => events.add([
              for (final item in event.dataOrNull!) (item.id, item.read),
            ]),
          );
      addTearDown(subscription.cancel);

      await pumpEventQueue();
      expect(events.last, [('n_yeni', false), ('n_orta', false)]);

      await repository.markRead('n_orta');
      await pumpEventQueue();
      expect(events.last, [('n_yeni', false), ('n_orta', true)]);

      await repository.softDeleteNotification('n_yeni', actorId: _uid);
      await pumpEventQueue();
      expect(events.last, [('n_orta', true), ('n_eski', false)]);

      await repository.restoreNotification('n_yeni');
      await pumpEventQueue();
      expect(events.last, [('n_yeni', false), ('n_orta', true)]);
    });

    test('sorgu userId + isDeleted == false süzgeçlerini, createdAt azalan '
        'sırayı ve varsayılan Limits.notificationInboxLimit sınırını taşır '
        '(rules-spec §6, indeks userId ↑ isDeleted ↑ createdAt ↓)', () async {
      final recording = _QueryRecordingService();

      final event = await FirebaseNotificationRepository(
        recording,
      ).watchInbox(_uid).first;

      expect(event.dataOrNull, isEmpty);
      expect(recording.queries.keys, ['notifications']);
      final query = recording.queries['notifications']!;
      expect(query.equalities, {'userId': _uid, 'isDeleted': false});
      expect(query.orders, [
        ['createdAt', true],
      ]);
      expect(query.limits, [Limits.notificationInboxLimit]);
    });

    test('hata olayı ve ayrıştırılamayan belge akışa başarısızlık olarak '
        'yazılır; limit < 1 invalidArgument', () async {
      final denied = await FirebaseNotificationRepository(
        _QueryRecordingService(error: FirestoreError.permissionDenied),
      ).watchInbox(_uid).first;
      await db.collection('notifications').doc('n_bozuk').set({
        'userId': _uid,
        'isDeleted': false,
        'createdAt': _seededAt,
      });

      final broken = await repository.watchInbox(_uid).first;
      final zero = await repository.watchInbox(_uid, limit: 0).first;

      expect(denied.errorOrNull, FirestoreError.permissionDenied);
      expect(broken.errorOrNull, FirestoreError.parse);
      expect(zero.errorOrNull, FirestoreError.invalidArgument);
    });
  });

  group('T-25 · NotificationRepository · markRead', () {
    test('yalnızca read: true + updatedAt yazılır; zaten okunmuşsa da '
        'başarı; belge yoksa notFound ve belge oluşmaz', () async {
      await seed('n1');
      await seed('n2', read: true);
      final before = (await notification('n1'))!;

      final first = await repository.markRead('n1');
      final again = await repository.markRead('n2');
      final missing = await repository.markRead('n_yok');

      expect(first.isSuccess, isTrue);
      expect(again.isSuccess, isTrue);
      expect(await notification('n1'), {
        ...before,
        'read': true,
        'updatedAt': isA<Timestamp>().having(
          (t) => t,
          'yeni',
          isNot(_seededAt),
        ),
      });
      expect(missing.errorOrNull, FirestoreError.notFound);
      expect(await notificationIds(), unorderedEquals(['n1', 'n2']));
    });
  });

  group('T-25 · NotificationRepository · markAllRead', () {
    test('kimlikler tekilleştirilip Limits.batchMaxWrites parçalarına bölünür '
        '(her parça tek batch: read + updatedAt); boş liste yazmaz', () async {
      final ids = [
        for (var i = 0; i <= Limits.batchMaxWrites; i++) 'n$i',
      ];
      for (final id in ids) {
        await seed(id);
      }
      final recording = _BatchRecordingService(service);
      final target = FirebaseNotificationRepository(recording);

      final empty = await target.markAllRead(_uid, const []);
      expect(empty.isSuccess, isTrue);
      expect(recording.attempts, 0);

      final result = await target.markAllRead(_uid, [...ids, ids.first]);

      expect(result.isSuccess, isTrue);
      expect(recording.batches.map((batch) => batch.length), [
        Limits.batchMaxWrites,
        1,
      ]);
      expect(recording.batches.expand((batch) => batch).first, [
        'update',
        'notifications/n0',
        {'read': true, 'updatedAt': serverTimestampMark},
      ]);
      for (final id in [ids.first, ids.last]) {
        expect((await notification(id))!['read'], isTrue);
      }
    });

    test(
      'ilk başarısız parçanın hatası döner; sonraki parça denenmez',
      () async {
        final ids = [
          for (var i = 0; i <= Limits.batchMaxWrites; i++) 'n$i',
        ];
        final recording = _BatchRecordingService(
          service,
          failWith: FirestoreError.permissionDenied,
        );

        final result = await FirebaseNotificationRepository(
          recording,
        ).markAllRead(_uid, ids);

        expect(result.errorOrNull, FirestoreError.permissionDenied);
        expect(recording.attempts, 1);
      },
    );
  });

  group('T-25 · NotificationRepository · softDeleteNotification / '
      'restoreNotification', () {
    test(
      'silme: isDeleted, deletedAt, deletedBy = aktör, updatedAt; geri '
      'alma: silme alanları null, createdAt korunur; belge yoksa notFound',
      () async {
        await seed('n1');
        final seeded = (await notification('n1'))!;

        final removed = await repository.softDeleteNotification(
          'n1',
          actorId: _uid,
        );
        final afterRemove = await notification('n1');
        final restored = await repository.restoreNotification('n1');

        expect(removed.isSuccess, isTrue);
        expect(afterRemove, {
          ...seeded,
          'isDeleted': true,
          'deletedAt': isA<Timestamp>(),
          'deletedBy': _uid,
          'updatedAt': isA<Timestamp>(),
        });
        expect(restored.isSuccess, isTrue);
        expect(await notification('n1'), {
          ...seeded,
          'isDeleted': false,
          'deletedAt': null,
          'deletedBy': null,
          'updatedAt': isA<Timestamp>(),
        });
        expect(
          (await repository.softDeleteNotification(
            'n_yok',
            actorId: _uid,
          )).errorOrNull,
          FirestoreError.notFound,
        );
        expect(
          (await repository.restoreNotification('n_yok')).errorOrNull,
          FirestoreError.notFound,
        );
        expect(await notificationIds(), ['n1']);
      },
    );
  });

  group('T-25 · NotificationRepository · createSelf', () {
    test('event_reminder_{eventId}_{uid} kimliğiyle tek set (refs yalnızca '
        'kulüp + etkinlik); belge varsa — silinmiş olsa da — yazmadan '
        'başarı', () async {
      final recording = RecordingFirestoreService(service);
      final target = FirebaseNotificationRepository(recording);

      final first = await target.createSelf(
        userId: _uid,
        eventId: _eventId,
        clubId: _clubId,
      );

      expect(first.isSuccess, isTrue);
      expect(recording.outsideWrites, 1);
      expect(await notificationIds(), [_reminderId]);
      expect(await notification(_reminderId), {
        'userId': _uid,
        'type': 'event_reminder',
        'refs': {'clubId': _clubId, 'eventId': _eventId},
        'read': false,
        'isDeleted': false,
        'createdAt': isA<Timestamp>(),
        'updatedAt': isA<Timestamp>(),
        'deletedAt': null,
        'deletedBy': null,
      });

      await target.softDeleteNotification(_reminderId, actorId: _uid);
      final deleted = await notification(_reminderId);
      final again = await target.createSelf(
        userId: _uid,
        eventId: _eventId,
        clubId: _clubId,
      );

      expect(again.isSuccess, isTrue);
      expect(recording.outsideWrites, 2);
      expect(await notification(_reminderId), deleted);
    });
  });

  group('T-25 · NotificationWriter', () {
    test('newEventKey: 20 karakter [A-Za-z0-9], her çağrıda yeni; yazım '
        'yok', () async {
      final keys = {for (var i = 0; i < 20; i++) repository.newEventKey()};

      expect(keys, hasLength(20));
      expect(keys, everyElement(matches(RegExp(r'^[A-Za-z0-9]{20}$'))));
      expect(await notificationIds(), isEmpty);
    });

    test('addToBatch: belge çağıranın batch içine eklenir '
        '({type}_{key}_{alıcı}, W-51 yük); geçersiz taslak / alıcı batch '
        'tamamını invalidArgument ile düşürür', () async {
      final recording = _BatchRecordingService(service);
      final target = FirebaseNotificationRepository(recording);
      const promoted = NotificationDraft(
        type: NotificationType.waitlistPromoted,
        eventKey: _key,
        refs: NotificationRefsModel(clubId: _clubId, eventId: _eventId),
      );

      final written = await recording.commitBatch((batch) {
        batch.set(service.doc('rsvps', '${_eventId}_$_uid'), {'x': 1});
        target.addToBatch(batch, promoted, recipientId: _uid);
      });

      expect(written.isSuccess, isTrue);
      expect(recording.batches, [
        [
          [
            'set',
            'rsvps/${_eventId}_$_uid',
            {'x': 1},
          ],
          [
            'set',
            'notifications/waitlist_promoted_${_key}_$_uid',
            {
              ...announcementPayload(_uid),
              'type': 'waitlist_promoted',
              'refs': {'clubId': _clubId, 'eventId': _eventId},
            },
          ],
        ],
      ]);

      final rejected = [
        for (final (draft, recipient) in [
          (promoted, 'u/1'),
          (
            const NotificationDraft(
              type: NotificationType.waitlistPromoted,
              eventKey: _key,
              refs: NotificationRefsModel(clubId: _clubId),
            ),
            _other,
          ),
        ])
          await recording.commitBatch((batch) {
            batch.set(service.doc('rsvps', 'r_dusmeli'), {'x': 1});
            target.addToBatch(batch, draft, recipientId: recipient);
          }),
      ];

      expect(
        rejected.map((result) => result.errorOrNull),
        everyElement(FirestoreError.invalidArgument),
      );
      expect(
        (await db.collection('rsvps').doc('r_dusmeli').get()).exists,
        isFalse,
      );
      expect(await notificationIds(), [
        'waitlist_promoted_${_key}_$_uid',
      ]);
    });

    test(
      'createMany: tekil alıcılar tek batch içinde, dönen sayı yazılan belge; '
      'aynı parçanın yeniden denemesi aynı kimliklere düşer; boş liste 0',
      () async {
        final recording = _BatchRecordingService(service);
        final target = FirebaseNotificationRepository(recording);

        final none = await target.createMany(_announcement, const []);
        final first = await target.createMany(_announcement, [
          _uid,
          _other,
          _uid,
        ]);
        final retry = await target.createMany(_announcement, [_uid, _other]);

        expect(none.dataOrNull, 0);
        expect(first.dataOrNull, 2);
        expect(retry.dataOrNull, 2);
        expect(recording.attempts, 2);
        expect(recording.batches.first, [
          [
            'set',
            'notifications/announcement_${_key}_$_uid',
            announcementPayload(_uid),
          ],
          [
            'set',
            'notifications/announcement_${_key}_$_other',
            announcementPayload(_other),
          ],
        ]);
        expect(
          await notificationIds(),
          unorderedEquals([
            'announcement_${_key}_$_uid',
            'announcement_${_key}_$_other',
          ]),
        );
      },
    );

    test('createMany: sınır üstü liste, geçersiz alıcı, tanınmayan tür, '
        'geçersiz anahtar ya da eksik zorunlu referans yazmadan '
        'invalidArgument', () async {
      final recording = _BatchRecordingService(service);
      final target = FirebaseNotificationRepository(recording);
      final tooMany = [
        for (var i = 0; i <= Limits.batchMaxWrites; i++) 'u$i',
      ];

      final results = [
        await target.createMany(_announcement, tooMany),
        await target.createMany(_announcement, [_uid, 'u/1']),
        await target.createMany(
          const NotificationDraft(
            type: NotificationType.unknown,
            eventKey: _key,
          ),
          [_uid],
        ),
        await target.createMany(
          const NotificationDraft(
            type: NotificationType.announcement,
            eventKey: 'a/b',
            refs: NotificationRefsModel(clubId: _clubId, postId: _postId),
          ),
          [_uid],
        ),
        await target.createMany(
          const NotificationDraft(
            type: NotificationType.announcement,
            eventKey: _key,
            refs: NotificationRefsModel(clubId: _clubId),
          ),
          [_uid],
        ),
      ];

      expect(
        results.map((result) => result.errorOrNull),
        everyElement(FirestoreError.invalidArgument),
      );
      expect(recording.attempts, 0);
      expect(await notificationIds(), isEmpty);
    });
  });

  group('T-25 · NotificationRepository · Security Rules reddi ve hata '
      'eşlemesi', () {
    for (final (code, error) in [
      ('permission-denied', FirestoreError.permissionDenied),
      ('unavailable', FirestoreError.unavailable),
    ]) {
      test('"$code": başkasının bildirimine dokunan / yazımı reddedilen her '
          'çağrı $error döner, istisna sızmaz', () async {
        final broken = failing(code);

        final results = <FirestoreResult<Object?>>[
          await broken.markRead('n1'),
          await broken.markAllRead(_uid, ['n1', 'n2']),
          await broken.softDeleteNotification('n1', actorId: _uid),
          await broken.restoreNotification('n1'),
          await broken.createSelf(
            userId: _uid,
            eventId: _eventId,
            clubId: _clubId,
          ),
          await broken.createMany(_announcement, [_other]),
        ];

        expect(
          results.map((result) => result.errorOrNull),
          everyElement(error),
        );
      });
    }
  });

  group('T-25 · NotificationRepository · geçersiz kimlik', () {
    for (final id in _invalidIds) {
      test(
        '"$id": her metot invalidArgument döner, istisna sızmaz (W-54)',
        () async {
          await seed('n1');
          final before = await notification('n1');

          final results = <FirestoreResult<Object?>>[
            await repository.watchInbox(id).first,
            await repository.markRead(id),
            await repository.markAllRead(id, ['n1']),
            await repository.markAllRead(_uid, ['n1', id]),
            await repository.softDeleteNotification(id, actorId: _uid),
            await repository.softDeleteNotification('n1', actorId: id),
            await repository.restoreNotification(id),
            await repository.createSelf(
              userId: id,
              eventId: _eventId,
              clubId: _clubId,
            ),
            await repository.createSelf(
              userId: _uid,
              eventId: id,
              clubId: _clubId,
            ),
            await repository.createSelf(
              userId: _uid,
              eventId: _eventId,
              clubId: id,
            ),
            await repository.createMany(_announcement, [id]),
          ];

          expect(
            results.map((result) => result.errorOrNull),
            everyElement(FirestoreError.invalidArgument),
          );
          expect(await notification('n1'), before);
          expect(await notificationIds(), ['n1']);
        },
      );
    }
  });
}

/// Batch'e giren yazımları kaydedip [_inner] batch'ine ileten sarmalayıcı.
final class _RecordingBatch implements WriteBatch {
  _RecordingBatch(this._inner, this._writes);

  final WriteBatch _inner;
  final List<List<Object?>> _writes;

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    _writes.add(['set', document.path, normalizePayload(data)]);
    _inner.set(document, data, options);
  }

  @override
  void update<T>(DocumentReference<T> document, T data) {
    _writes.add(['update', document.path, normalizePayload(data)]);
    _inner.update(document, data);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Batch içeriğini kaydeden servis: her `commitBatch` denemesi [attempts]'i
/// artırır; [failWith] verilmişse gövde çalıştırılmadan o hatayla biter,
/// verilmemişse yazımlar ([batches]: işlem, yol, sadeleştirilmiş yük) kaydedilip
/// [_inner] servise iletilir. Okuma ve tekil yazım üyeleri **yoktur** —
/// repository bunlardan birini çağırırsa test kırılır.
final class _BatchRecordingService implements FirestoreService {
  _BatchRecordingService(this._inner, {this.failWith});

  final FirestoreService _inner;

  /// Her commit'in döndüğü hata; `null` ise commit iletilir.
  final FirestoreError? failWith;

  /// Commit edilen batch'ler; her biri `[işlem, yol, yük]` üçlülerinin listesi.
  final List<List<List<Object?>>> batches = [];

  /// `commitBatch` çağrı sayısı.
  int attempts = 0;

  @override
  DocumentReference<Json> doc(String collectionPath, String id) =>
      _inner.doc(collectionPath, id);

  @override
  Future<FirestoreResult<void>> commitBatch(
    void Function(WriteBatch batch) build,
  ) {
    attempts++;
    final failWith = this.failWith;
    if (failWith != null) return Future.value(FirebaseFailure(failWith));
    return _inner.commitBatch((batch) {
      final writes = <List<Object?>>[];
      batches.add(writes);
      build(_RecordingBatch(batch, writes));
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// `where` eşitlik süzgeçlerini, sıralamayı ve sınırı kaydeden sorgu; her
/// kurucu aynı nesneyi döndürür.
final class _RecordingQuery implements Query<Json> {
  /// Alan → `isEqualTo` değeri, eklenme sırasıyla.
  final Map<Object, Object?> equalities = {};

  /// `orderBy` çağrıları: `[alan, azalan mı]`.
  final List<List<Object?>> orders = [];

  /// `limit` çağrıları.
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
    equalities[field] = isEqualTo;
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

/// Koleksiyon sorgularını kaydeden servis: `collection` her yol için bir
/// [_RecordingQuery] verir; `watchList` tek olay yayar — [error] verilmişse o
/// hata, verilmemişse boş liste.
final class _QueryRecordingService implements FirestoreService {
  _QueryRecordingService({this.error});

  /// Dinlemenin yaydığı hata; `null` ise boş liste yayılır.
  final FirestoreError? error;

  /// Koleksiyon yolu → o yol için kurulan sorgu.
  final Map<String, _RecordingQuery> queries = {};

  @override
  Query<Json> collection(String path) => queries[path] = _RecordingQuery();

  @override
  Stream<FirestoreResult<List<FirestoreDoc>>> watchList(Query<Json> query) {
    final error = this.error;
    return Stream.value(
      error == null ? const FirebaseSuccess([]) : FirebaseFailure(error),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
