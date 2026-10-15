// T-19 · CommentRepository: yorum yazma / kaldırma / geri yükleme (yorum
// belgesi ile gönderinin `commentCount` deltası ve `lastCommentRef`
// işaretçisi tek batch'te; önce okuma yok), Security Rules reddi (silinmiş /
// gizlenmiş gönderi, çift kaldırma), canlı yorum listesi ve süzgeçleri,
// moderasyon gizlemesi, metin ve kimlik doğrulaması (W-54), hata eşlemesi
// (PLAN §9.6.8, §10.4, §10.6; rules-spec §3.6, §6; docs/plans/T-19.md §6;
// D-10, CD-41).
//
// Mutlu yollar `fake_cloud_firestore` ile (Q-06); hata yolları el yazımı
// çiftlerle (`test/fakes/sdk_firestore_stubs.dart`). "Aynı batch" iddiası,
// batch'e giren yazımları kaydeden ve okuma / tekil yazım bilmeyen servis
// çiftiyle kanıtlanır.
//
// SDK sınıfları `@sealed` işaretlidir; test çifti bilerek uygular.
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/fake_app_clock.dart';
import '../fakes/recording_firestore_service.dart';
import '../fakes/sdk_firestore_stubs.dart';
import '../helpers/plan_repository_table.dart';
import '../helpers/plan_service_table.dart';

const String _interface =
    'packages/gu_data/lib/src/repositories/comment_repository.dart';
const String _implementation =
    'packages/gu_data/lib/src/repositories/firebase_comment_repository.dart';
const String _clubId = 'c01';
const String _postId = 'p01';
const String _postPath = 'posts/p01';
const String _author = 'u_ayse';
const String _manager = 'u_pres';
const String _commentId = 'cm01';
const String _commentPath = 'comments/cm01';

/// Geçersiz belge kimlikleri (W-54).
const List<String> _invalidIds = ['', 'p/1', '..', '__id__'];

/// Sahte saatin gösterdiği an.
final DateTime _now = DateTime.utc(2026, 10, 13, 9);

/// Tohum belgelerin zaman damgası (sunucu zamanından ayırt edilir).
final Timestamp _seededAt = Timestamp.fromDate(DateTime.utc(2026, 9));

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreService service;
  late FakeAppClock clock;
  late CommentRepository repository;

  Future<Json?> post([String id = _postId]) async =>
      (await db.collection('posts').doc(id).get()).data();

  Future<Json?> comment([String id = _commentId]) async =>
      (await db.collection('comments').doc(id).get()).data();

  Future<List<String>> commentIds() async => [
    for (final doc in (await db.collection('comments').get()).docs) doc.id,
  ];

  Future<void> seedPost({int commentCount = 2}) =>
      db.collection('posts').doc(_postId).set({
        'clubId': _clubId,
        'authorId': _manager,
        'type': 'post',
        'text': 'Merhaba',
        'commentCount': commentCount,
        'isHidden': false,
        'isDeleted': false,
        'updatedAt': _seededAt,
      });

  Future<void> seedComment(
    String id, {
    String postId = _postId,
    String clubId = _clubId,
    int minute = 0,
    bool isDeleted = false,
    bool isHidden = false,
  }) => db.collection('comments').doc(id).set({
    'postId': postId,
    'clubId': clubId,
    'authorId': _author,
    'text': 'yorum $id',
    'isHidden': isHidden,
    'createdAt': Timestamp.fromDate(DateTime.utc(2026, 10, 13, 8, minute)),
    'updatedAt': _seededAt,
    'isDeleted': isDeleted,
    'deletedAt': isDeleted ? _seededAt : null,
    'deletedBy': isDeleted ? _author : null,
  });

  Future<FirestoreResult<CommentModel>> add(
    CommentRepository target, {
    String postId = _postId,
    String clubId = _clubId,
    String authorId = _author,
    String text = 'Harika!',
  }) => target.add(
    postId: postId,
    clubId: clubId,
    authorId: authorId,
    text: text,
  );

  /// [database] veritabanına bağlı repository.
  CommentRepository on(FirebaseFirestore database) =>
      FirebaseCommentRepository(FirebaseFirestoreService(database), clock);

  /// Her çağrısı [code] hatasıyla biten veritabanına bağlı repository.
  CommentRepository failing(String code) =>
      on(StubFirestore(error: firestoreException(code)));

  /// Sayaç yazımının beklenen yükü: delta, işaretçi ve `updatedAt`.
  List<Object?> counterWrite(String commentId) => [
    'update',
    _postPath,
    {
      'commentCount': incrementMark,
      'lastCommentRef': 'comments/$commentId',
      'updatedAt': serverTimestampMark,
    },
  ];

  setUp(() {
    db = FakeFirebaseFirestore();
    service = FirebaseFirestoreService(db);
    clock = FakeAppClock(_now);
    repository = FirebaseCommentRepository(service, clock);
  });

  group('T-19 · CommentRepository · sözleşme', () {
    test('PLAN §10.4 tablosundaki üyeler arayüzde aynı imzayla var '
        "(getComment T-40 satırı W-103 ile T-43'te); başka üye yok", () {
      final plan = readPlanRepositoryMembers('$CommentRepository');
      final byMember = {for (final row in plan) row.member: row};

      expect(byMember.keys, [
        'add',
        'softDeleteComment',
        'restoreComment',
        'watchComments',
        'hide',
        'getComment',
      ]);
      expect(byMember['getComment']!.note, '(T-40)');
      expect(interfaceMembers(_interface, '$CommentRepository').toSet(), {
        for (final row in plan) normalizeDartSource(row.signature),
      });
    });

    test('arayüzde ve uygulamada silme üyesi yok (D-10)', () {
      expect(deleteIdentifiersIn(_interface), isEmpty);
      expect(deleteIdentifiersIn(_implementation), isEmpty);
    });
  });

  group('T-19 · CommentRepository · add', () {
    test('yorum ile commentCount +1 ve lastCommentRef aynı batch ile yazılır '
        '(önce okuma yok); yazılan model döner', () async {
      await seedPost();
      final recording = _BatchRecordingService(service);

      final result = await add(FirebaseCommentRepository(recording, clock));

      final written = result.dataOrNull!;
      expect(recording.directWrites, 0);
      expect(recording.batches, [
        [
          [
            'set',
            'comments/${written.id}',
            {
              'postId': _postId,
              'clubId': _clubId,
              'authorId': _author,
              'text': 'Harika!',
              'isHidden': false,
              'createdAt': serverTimestampMark,
              'updatedAt': serverTimestampMark,
              'isDeleted': false,
              'deletedAt': null,
              'deletedBy': null,
            },
          ],
          counterWrite(written.id),
        ],
      ]);
      // Deltanın etkisi belgede: 2 → 3.
      expect(await post(), {
        'clubId': _clubId,
        'authorId': _manager,
        'type': 'post',
        'text': 'Merhaba',
        'commentCount': 3,
        'lastCommentRef': 'comments/${written.id}',
        'isHidden': false,
        'isDeleted': false,
        'updatedAt': isA<Timestamp>().having(
          (t) => t,
          'yeni',
          isNot(_seededAt),
        ),
      });
      // Kimlik rastgeledir (kullanıcı kimliği taşımaz) ve dönen modelle aynı.
      expect(await commentIds(), [written.id]);
      expect(written.id, isNot(contains(_author)));
      expect(
        written,
        CommentModel(
          id: written.id,
          postId: _postId,
          clubId: _clubId,
          authorId: _author,
          text: 'Harika!',
          createdAt: _now,
          updatedAt: _now,
        ),
      );
    });

    test('boş, yalnızca boşluk ya da Limits.commentMax üstü metin yazmadan '
        'invalidArgument; sınırdaki metin yazılır', () async {
      await seedPost();
      final tooLong = 'a' * (Limits.commentMax + 1);

      final rejected = [
        await add(repository, text: ''),
        await add(repository, text: '   '),
        await add(repository, text: tooLong),
      ];

      expect(
        rejected.map((result) => result.errorOrNull),
        everyElement(FirestoreError.invalidArgument),
      );
      expect(await commentIds(), isEmpty);
      expect((await post())!['commentCount'], 2);

      final atLimit = await add(repository, text: 'a' * Limits.commentMax);

      expect(atLimit.isSuccess, isTrue);
      expect((await post())!['commentCount'], 3);
    });
  });

  group('T-19 · CommentRepository · softDeleteComment / restoreComment', () {
    test('kaldırma: yorum işaretlenir (deletedBy = aktör, yazar olmasa da) '
        've commentCount −1 aynı batch ile yazılır', () async {
      await seedPost();
      await seedComment(_commentId);
      final seeded = (await comment())!;
      final recording = _BatchRecordingService(service);

      final result = await FirebaseCommentRepository(
        recording,
        clock,
      ).softDeleteComment(_commentId, postId: _postId, actorId: _manager);

      expect(result.isSuccess, isTrue);
      expect(recording.directWrites, 0);
      expect(recording.batches, [
        [
          [
            'update',
            _commentPath,
            {
              'isDeleted': true,
              'deletedAt': serverTimestampMark,
              'deletedBy': _manager,
              'updatedAt': serverTimestampMark,
            },
          ],
          counterWrite(_commentId),
        ],
      ]);
      expect(await comment(), {
        ...seeded,
        'isDeleted': true,
        'deletedAt': isA<Timestamp>(),
        'deletedBy': _manager,
        'updatedAt': isA<Timestamp>(),
      });
      expect((await post())!['commentCount'], 1);
      expect((await post())!['lastCommentRef'], _commentPath);
    });

    test('geri alma: silme alanları null olur, createdAt korunur ve '
        'commentCount +1 aynı batch ile yazılır', () async {
      await seedPost();
      await seedComment(_commentId, isDeleted: true);
      final seeded = (await comment())!;
      final recording = _BatchRecordingService(service);

      final result = await FirebaseCommentRepository(
        recording,
        clock,
      ).restoreComment(_commentId, postId: _postId);

      expect(result.isSuccess, isTrue);
      expect(recording.directWrites, 0);
      expect(recording.batches, [
        [
          [
            'update',
            _commentPath,
            {
              'isDeleted': false,
              'deletedAt': null,
              'deletedBy': null,
              'updatedAt': serverTimestampMark,
            },
          ],
          counterWrite(_commentId),
        ],
      ]);
      expect(await comment(), {
        ...seeded,
        'isDeleted': false,
        'deletedAt': null,
        'deletedBy': null,
        'updatedAt': isA<Timestamp>(),
      });
      expect((await post())!['commentCount'], 3);
      expect((await post())!['lastCommentRef'], _commentPath);
    });

    test('yorum yoksa notFound; sayaç değişmez, belge oluşmaz', () async {
      await seedPost();
      final before = await post();

      final removed = await repository.softDeleteComment(
        _commentId,
        postId: _postId,
        actorId: _author,
      );
      final restored = await repository.restoreComment(
        _commentId,
        postId: _postId,
      );

      expect(removed.errorOrNull, FirestoreError.notFound);
      expect(restored.errorOrNull, FirestoreError.notFound);
      expect(await post(), before);
      expect(await commentIds(), isEmpty);
    });
  });

  group('T-19 · CommentRepository · Security Rules reddi ve hata eşlemesi', () {
    test('batch reddedilirse (silinmiş / gizlenmiş gönderiye yorum, çift '
        'kaldırma, çift geri alma) permissionDenied döner; yorum da sayaç da '
        'değişmez', () async {
      await seedPost();
      await seedComment(_commentId);
      final beforePost = await post();
      final beforeComment = await comment();
      final denied = on(
        FailingBatchFirestore(
          db,
          error: firestoreException('permission-denied'),
        ),
      );

      final results = <FirestoreResult<Object?>>[
        await add(denied),
        await denied.softDeleteComment(
          _commentId,
          postId: _postId,
          actorId: _author,
        ),
        await denied.restoreComment(_commentId, postId: _postId),
      ];

      expect(
        results.map((result) => result.errorOrNull),
        everyElement(FirestoreError.permissionDenied),
      );
      expect(await post(), beforePost);
      expect(await comment(), beforeComment);
      expect(await commentIds(), [_commentId]);
    });

    test('yazma hatası aynen eşlenir', () async {
      final broken = failing('unavailable');

      final results = <FirestoreResult<Object?>>[
        await add(broken),
        await broken.softDeleteComment(
          _commentId,
          postId: _postId,
          actorId: _author,
        ),
        await broken.restoreComment(_commentId, postId: _postId),
        await broken.hide(_commentId, actorId: 'u_super'),
      ];

      expect(
        results.map((result) => result.errorOrNull),
        everyElement(FirestoreError.unavailable),
      );
    });
  });

  group('T-19 · CommentRepository · watchComments', () {
    test('yalnızca gönderinin silinmemiş ve gizlenmemiş yorumları, eskiden '
        'yeniye; liste canlıdır', () async {
      await seedPost(commentCount: 4);
      await seedComment('c_yeni', minute: 5);
      await seedComment('c_eski', minute: 1);
      await seedComment('c_silinmis', minute: 2, isDeleted: true);
      await seedComment('c_gizli', minute: 3, isHidden: true);
      await seedComment('c_baska_gonderi', minute: 4, postId: 'p02');
      await seedComment('c_baska_kulup', minute: 4, clubId: 'c02');
      final events = <List<String>?>[];
      final subscription = repository
          .watchComments(_postId, clubId: _clubId)
          .listen(
            (event) => events.add([
              for (final item in event.dataOrNull ?? <CommentModel>[]) item.id,
            ]),
          );
      addTearDown(subscription.cancel);

      await pumpEventQueue();
      expect(events.last, ['c_eski', 'c_yeni']);

      await repository.softDeleteComment(
        'c_eski',
        postId: _postId,
        actorId: _author,
      );
      await pumpEventQueue();
      expect(events.last, ['c_yeni']);
    });

    test('sorgu gönderi, kulüp, silinmemiş ve gizli değil süzgeçlerini '
        'taşır; createdAt artan sıralar (rules-spec §6)', () async {
      final recording = _QueryRecordingService();

      final event = await FirebaseCommentRepository(
        recording,
        clock,
      ).watchComments(_postId, clubId: _clubId).first;

      expect(event.dataOrNull, isEmpty);
      expect(recording.queries.keys, ['comments']);
      expect(recording.queries['comments']!.equalities, {
        'postId': _postId,
        'clubId': _clubId,
        'isDeleted': false,
        'isHidden': false,
      });
      expect(recording.queries['comments']!.orders, [
        ['createdAt', false],
      ]);
    });

    test('hata olayı ve ayrıştırılamayan yorum akışa başarısızlık olarak '
        'yazılır', () async {
      final denied = await FirebaseCommentRepository(
        _QueryRecordingService(error: FirestoreError.permissionDenied),
        clock,
      ).watchComments(_postId, clubId: _clubId).first;
      await db.collection('comments').doc('c_bozuk').set({
        'postId': _postId,
        'clubId': _clubId,
        'isDeleted': false,
        'isHidden': false,
        'createdAt': _seededAt,
      });

      final broken = await repository
          .watchComments(_postId, clubId: _clubId)
          .first;

      expect(denied.errorOrNull, FirestoreError.permissionDenied);
      expect(broken.errorOrNull, FirestoreError.parse);
    });
  });

  group('W-103 · CommentRepository · getComment', () {
    test('yorumu döner; gizlenmiş yorum da döner (Rules okumaya izin '
        'verdiyse — süper admin)', () async {
      await seedComment(_commentId);
      await seedComment('cm02', isHidden: true);

      final visible = (await repository.getComment(_commentId)).dataOrNull;
      expect(visible?.id, _commentId);
      expect(visible?.text, 'yorum cm01');
      expect(visible?.authorId, _author);
      expect(visible?.postId, _postId);
      expect(visible?.clubId, _clubId);
      expect(
        (await repository.getComment('cm02')).dataOrNull?.isHidden,
        isTrue,
      );
    });

    test('silinmiş ya da olmayan yorum notFound; okuma hatası aynen '
        'eşlenir; yazım yok', () async {
      await seedComment(_commentId, isDeleted: true);

      expect(
        (await repository.getComment(_commentId)).errorOrNull,
        FirestoreError.notFound,
      );
      expect(
        (await repository.getComment('cm_yok')).errorOrNull,
        FirestoreError.notFound,
      );
      expect(
        (await failing('permission-denied').getComment(_commentId)).errorOrNull,
        FirestoreError.permissionDenied,
      );
      expect(
        (await failing('unavailable').getComment(_commentId)).errorOrNull,
        FirestoreError.unavailable,
      );
      expect(await commentIds(), [_commentId]);
    });
  });

  group('T-19 · CommentRepository · hide', () {
    test('tek yazımda gizler (hiddenBy, hiddenAt); gönderinin sayacı ve '
        'işaretçisi değişmez', () async {
      await seedPost();
      await seedComment(_commentId);
      final seeded = (await comment())!;
      final beforePost = await post();

      final result = await repository.hide(_commentId, actorId: 'u_super');

      expect(result.isSuccess, isTrue);
      expect(await comment(), {
        ...seeded,
        'isHidden': true,
        'hiddenBy': 'u_super',
        'hiddenAt': isA<Timestamp>(),
        'updatedAt': isA<Timestamp>().having(
          (t) => t,
          'yeni',
          isNot(_seededAt),
        ),
      });
      expect(await post(), beforePost);
    });

    test('yorum yoksa notFound; belge oluşmaz', () async {
      final result = await repository.hide(_commentId, actorId: 'u_super');

      expect(result.errorOrNull, FirestoreError.notFound);
      expect(await commentIds(), isEmpty);
    });
  });

  group('T-19 · CommentRepository · geçersiz kimlik', () {
    for (final id in _invalidIds) {
      test(
        '"$id": her metot invalidArgument döner, istisna sızmaz (W-54)',
        () async {
          await seedPost();
          final before = await post();

          final results = <FirestoreResult<Object?>>[
            await add(repository, postId: id),
            await add(repository, clubId: id),
            await add(repository, authorId: id),
            await repository.softDeleteComment(
              id,
              postId: _postId,
              actorId: _author,
            ),
            await repository.softDeleteComment(
              _commentId,
              postId: id,
              actorId: _author,
            ),
            await repository.softDeleteComment(
              _commentId,
              postId: _postId,
              actorId: id,
            ),
            await repository.restoreComment(id, postId: _postId),
            await repository.restoreComment(_commentId, postId: id),
            await repository.hide(id, actorId: 'u_super'),
            await repository.hide(_commentId, actorId: id),
            await repository.getComment(id),
            await repository.watchComments(id, clubId: _clubId).first,
            await repository.watchComments(_postId, clubId: id).first,
          ];

          expect(
            results.map((result) => result.errorOrNull),
            everyElement(FirestoreError.invalidArgument),
          );
          expect(await post(), before);
          expect(await commentIds(), isEmpty);
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

/// Batch içeriğini kaydeden servis: her `commitBatch` çağrısının yazımları
/// ([batches]: işlem, yol, [normalizePayload] ile sadeleştirilmiş yük) sırayla
/// tutulur ve [_inner] servise iletilir. Okuma ve tekil yazım üyeleri
/// **yoktur** — repository bunlardan birini çağırırsa test kırılır; batch
/// dışı soft delete / geri alma [directWrites] ile sayılır.
final class _BatchRecordingService implements FirestoreService {
  _BatchRecordingService(this._inner);

  final FirestoreService _inner;

  /// Commit edilen batch'ler; her biri `[işlem, yol, yük]` üçlülerinin listesi.
  final List<List<List<Object?>>> batches = [];

  /// Batch verilmeden çağrılan soft delete / geri alma sayısı.
  int directWrites = 0;

  @override
  DocumentReference<Json> doc(String collectionPath, String id) =>
      _inner.doc(collectionPath, id);

  @override
  String newId(String collectionPath) => _inner.newId(collectionPath);

  @override
  Future<FirestoreResult<void>> commitBatch(
    void Function(WriteBatch batch) build,
  ) => _inner.commitBatch((batch) {
    final writes = <List<Object?>>[];
    batches.add(writes);
    build(_RecordingBatch(batch, writes));
  });

  @override
  Future<FirestoreResult<void>> softDelete(
    DocumentReference<Json> ref, {
    required String actorId,
    WriteBatch? batch,
  }) {
    if (batch == null) directWrites++;
    return _inner.softDelete(ref, actorId: actorId, batch: batch);
  }

  @override
  Future<FirestoreResult<void>> restore(
    DocumentReference<Json> ref, {
    WriteBatch? batch,
  }) {
    if (batch == null) directWrites++;
    return _inner.restore(ref, batch: batch);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// `where` eşitlik süzgeçlerini ve sıralamayı kaydeden sorgu; her kurucu aynı
/// nesneyi döndürür.
final class _RecordingQuery implements Query<Json> {
  /// Alan → `isEqualTo` değeri, eklenme sırasıyla.
  final Map<Object, Object?> equalities = {};

  /// `orderBy` çağrıları: `[alan, azalan mı]`.
  final List<List<Object?>> orders = [];

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
