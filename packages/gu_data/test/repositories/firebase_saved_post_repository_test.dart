// T-19 · SavedPostRepository: kaydetme (oluşturma, yazılan alanlar), kaydet →
// kaldır → yeniden kaydet döngüsü (aynı belge geri yüklenir, `savedAt`
// yenilenir), zaten yürürlükteki kayıt, "Geri al" (`savedAt` korunur),
// kaydedilenler listesi (süzgeçler, sıralama, sayfalama), `isSaved`, geçersiz
// kimlik (W-54) ve hata eşlemesi (PLAN §9.6.16, §10.4; rules-spec §3.14, §6;
// docs/plans/T-19.md §6; D-10).
//
// Mutlu yollar `fake_cloud_firestore` ile (Q-06); hata yolları el yazımı
// çiftlerle (`test/fakes/sdk_firestore_stubs.dart`). Hangi yazımın yapıldığı,
// yazım çağrılarını kaydeden (ve betiklenen adımı reddeden) servis çiftiyle
// kanıtlanır.
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
    'packages/gu_data/lib/src/repositories/saved_post_repository.dart';
const String _implementation =
    'packages/gu_data/lib/src/repositories/firebase_saved_post_repository.dart';
const String _clubId = 'c01';
const String _me = 'u_ayse';
const String _other = 'u_mehmet';
const String _postId = 'p01';
const String _savedId = 'u_ayse_p01';
const String _savedPath = 'savedPosts/u_ayse_p01';

/// Geçersiz belge kimlikleri (W-54).
const List<String> _invalidIds = ['', 'u/1', '..', '__uid__'];

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreService service;
  late SavedPostRepository repository;

  Future<Json?> read([String id = _savedId]) async =>
      (await db.collection('savedPosts').doc(id).get()).data();

  Future<List<String>> ids() async => [
    for (final doc in (await db.collection('savedPosts').get()).docs) doc.id,
  ];

  Future<FirestoreResult<void>> save(
    SavedPostRepository target, {
    String userId = _me,
    String postId = _postId,
    String clubId = _clubId,
  }) => target.save(userId: userId, postId: postId, clubId: clubId);

  Future<FirestoreResult<void>> remove([
    String userId = _me,
    String postId = _postId,
  ]) => repository.softDeleteSaved(userId: userId, postId: postId);

  Future<bool?> isSaved([String userId = _me, String postId = _postId]) async =>
      (await repository.isSaved(userId: userId, postId: postId)).dataOrNull;

  /// Kaydı doğrudan yazar ([minute] kaydetme anını belirler).
  Future<void> seed(
    String userId,
    String postId, {
    int minute = 0,
    bool isDeleted = false,
  }) {
    final at = Timestamp.fromDate(DateTime.utc(2026, 10, 13, 9, minute));
    return db.collection('savedPosts').doc('${userId}_$postId').set({
      'userId': userId,
      'postId': postId,
      'clubId': _clubId,
      'savedAt': at,
      'createdAt': at,
      'updatedAt': at,
      'isDeleted': isDeleted,
      'deletedAt': isDeleted ? at : null,
      'deletedBy': isDeleted ? userId : null,
    });
  }

  /// Her çağrısı [code] hatasıyla biten veritabanına bağlı repository.
  SavedPostRepository failing(String code) => FirebaseSavedPostRepository(
    FirebaseFirestoreService(StubFirestore(error: firestoreException(code))),
  );

  setUp(() {
    db = FakeFirebaseFirestore();
    service = FirebaseFirestoreService(db);
    repository = FirebaseSavedPostRepository(service);
  });

  group('T-19 · SavedPostRepository · sözleşme', () {
    test('PLAN §10.4 tablosundaki her üye arayüzde aynı imzayla var; başka '
        'üye yok', () {
      final plan = readPlanRepositoryMembers('$SavedPostRepository');

      expect(plan, hasLength(6));
      expect(interfaceMembers(_interface, '$SavedPostRepository').toSet(), {
        for (final row in plan) normalizeDartSource(row.signature),
      });
    });

    test('arayüzde ve uygulamada silme üyesi yok (D-10)', () {
      expect(deleteIdentifiersIn(_interface), isEmpty);
      expect(deleteIdentifiersIn(_implementation), isEmpty);
    });
  });

  group('T-19 · SavedPostRepository · save', () {
    test('kayıt yoksa türeyen kimlikle oluşturur: sahibi, gönderi, kulüp, '
        'savedAt ve ortak alanlar yazılır', () async {
      final result = await save(repository);

      expect(result.isSuccess, isTrue);
      expect(await ids(), [_savedId]);
      expect(await read(), {
        'userId': _me,
        'postId': _postId,
        'clubId': _clubId,
        'savedAt': isA<Timestamp>(),
        'createdAt': isA<Timestamp>(),
        'updatedAt': isA<Timestamp>(),
        'isDeleted': false,
        'deletedAt': null,
        'deletedBy': null,
      });
    });

    test('kaydet → kaldır → yeniden kaydet: aynı belge tek güncellemeyle '
        'geri yüklenir, savedAt yenilenir, createdAt korunur', () async {
      await seed(_me, _postId);
      final created = (await read())!;
      await remove();
      // Yeniden kaydetme geri yüklemedir: `set` (yeniden oluşturma)
      // reddedilse de başarır.
      final scripted = _ScriptedService(service, denySet: true);

      final again = await save(FirebaseSavedPostRepository(scripted));

      expect(again.isSuccess, isTrue);
      expect(scripted.writes, [
        [
          'update',
          _savedPath,
          {
            'isDeleted': false,
            'deletedAt': null,
            'deletedBy': null,
            'updatedAt': serverTimestampMark,
            'savedAt': serverTimestampMark,
          },
        ],
      ]);
      expect(await read(), {
        ...created,
        'savedAt': isA<Timestamp>().having(
          (t) => t,
          'yeni',
          isNot(created['savedAt']),
        ),
        'updatedAt': isA<Timestamp>(),
      });
      expect(await ids(), [_savedId]);
      expect(await isSaved(), isTrue);
    });

    test(
      'kayıt zaten yürürlükteyse hiçbir şey yazmadan başarı döner',
      () async {
        await seed(_me, _postId);
        final before = await read();
        final scripted = _ScriptedService(service);

        final result = await save(FirebaseSavedPostRepository(scripted));

        expect(result.isSuccess, isTrue);
        expect(scripted.writes, isEmpty);
        expect(await read(), before);
      },
    );

    test('okuma reddi "kayıt yok" sayılır ve oluşturma denenir; o da '
        'reddedilirse ret döner; başka okuma hatası yazmadan döner', () async {
      final created = await save(
        FirebaseSavedPostRepository(
          _ScriptedService(service, readError: FirestoreError.permissionDenied),
        ),
      );
      final denied = await save(
        FirebaseSavedPostRepository(
          _ScriptedService(
            service,
            readError: FirestoreError.permissionDenied,
            denySet: true,
          ),
        ),
        postId: 'p02',
      );
      final unavailable = _ScriptedService(
        service,
        readError: FirestoreError.unavailable,
      );
      final offline = await save(
        FirebaseSavedPostRepository(unavailable),
        postId: 'p03',
      );

      expect(created.isSuccess, isTrue);
      expect(denied.errorOrNull, FirestoreError.permissionDenied);
      expect(offline.errorOrNull, FirestoreError.unavailable);
      expect(unavailable.writes, isEmpty);
      expect(await ids(), [_savedId]);
    });
  });

  group('T-19 · SavedPostRepository · softDeleteSaved / restoreSaved', () {
    test('kaldırma belgeyi işaretler (deletedBy = sahibi); Geri al yalnızca '
        'silme alanlarını geri alır, savedAt değişmez', () async {
      await seed(_me, _postId);
      final created = (await read())!;

      final removed = await remove();

      expect(removed.isSuccess, isTrue);
      expect(await read(), {
        ...created,
        'isDeleted': true,
        'deletedAt': isA<Timestamp>(),
        'deletedBy': _me,
        'updatedAt': isA<Timestamp>(),
      });
      expect(await isSaved(), isFalse);

      final scripted = _ScriptedService(service);
      final restored = await FirebaseSavedPostRepository(
        scripted,
      ).restoreSaved(userId: _me, postId: _postId);

      expect(restored.isSuccess, isTrue);
      expect(scripted.writes, [
        ['restore', _savedPath],
      ]);
      // `savedAt` ilk kaydetme anında kalır (kayıt listedeki eski yerine döner).
      expect(await read(), {...created, 'updatedAt': isA<Timestamp>()});
      expect(await isSaved(), isTrue);
    });

    test('kayıt yoksa notFound; belge oluşmaz', () async {
      final removed = await remove();
      final restored = await repository.restoreSaved(
        userId: _me,
        postId: _postId,
      );

      expect(removed.errorOrNull, FirestoreError.notFound);
      expect(restored.errorOrNull, FirestoreError.notFound);
      expect(await ids(), isEmpty);
    });
  });

  group('T-19 · SavedPostRepository · listSaved / isSaved', () {
    test('yalnızca sahibinin yürürlükteki kayıtları, en son kaydedilen üstte; '
        'imleçle sayfalanır', () async {
      await seed(_me, 'p_ilk', minute: 1);
      await seed(_me, 'p_son', minute: 3);
      await seed(_me, 'p_orta', minute: 2);
      await seed(_me, 'p_kaldirilmis', minute: 4, isDeleted: true);
      await seed(_other, 'p_son', minute: 5);

      final first = (await repository.listSaved(
        _me,
        const PageRequest(limit: 2),
      )).dataOrNull!;
      final second = (await repository.listSaved(
        _me,
        PageRequest(limit: 2, after: first.next),
      )).dataOrNull!;

      expect(first.items.map((saved) => saved.postId), ['p_son', 'p_orta']);
      expect(first.hasMore, isTrue);
      expect(second.items.map((saved) => saved.postId), ['p_ilk']);
      expect(second.hasMore, isFalse);
      expect(
        [...first.items, ...second.items],
        everyElement(
          isA<SavedPostModel>()
              .having((saved) => saved.userId, 'userId', _me)
              .having((saved) => saved.clubId, 'clubId', _clubId)
              .having((saved) => saved.isLive, 'isLive', isTrue)
              .having((saved) => saved.savedAt, 'savedAt', isNotNull),
        ),
      );
      expect(first.items.first.id, 'u_ayse_p_son');
    });

    test('sorgu sahibi ve silinmemiş süzgeçlerini taşır, savedAt azalan '
        'sıralar; istenen sayfa (varsayılan 20) aynen iletilir '
        '(rules-spec §6)', () async {
      final recording = _QueryRecordingService();
      const page = PageRequest();

      final result = await FirebaseSavedPostRepository(
        recording,
      ).listSaved(_me, page);

      expect(result.dataOrNull?.items, isEmpty);
      expect(recording.queries.keys, ['savedPosts']);
      expect(recording.queries['savedPosts']!.equalities, {
        'userId': _me,
        'isDeleted': false,
      });
      expect(recording.queries['savedPosts']!.orders, [
        ['savedAt', true],
      ]);
      expect(recording.pages, [same(page)]);
      expect(page.limit, 20);
    });

    test('isSaved: yürürlükteki kayıt true; kayıt yoksa ya da kaldırılmışsa '
        'false', () async {
      await seed(_me, _postId);
      await seed(_me, 'p_kaldirilmis', isDeleted: true);

      expect(await isSaved(), isTrue);
      expect(await isSaved(_me, 'p_kaldirilmis'), isFalse);
      expect(await isSaved(_me, 'p_yok'), isFalse);
      expect(await isSaved(_other), isFalse);
    });

    test('T-44 · D3-03 savedAmong: sayfadaki gönderilerden yalnızca '
        "yürürlükteki kendi kayıtları; 30'luk parçalar, tekilleştirme, boş "
        'liste sorgusuz', () async {
      await seed(_me, 'p01');
      await seed(_me, 'p02', isDeleted: true);
      await seed(_other, 'p03');
      for (var i = 0; i < 35; i++) {
        if (i.isEven) await seed(_me, 'q$i');
      }
      final page = [
        'p01',
        'p02',
        'p03',
        'p01',
        for (var i = 0; i < 35; i++) 'q$i',
      ];

      final result = await repository.savedAmong(userId: _me, postIds: page);

      expect(result.dataOrNull, {
        'p01',
        for (var i = 0; i < 35; i += 2) 'q$i',
      });
      // Boş liste: sorgu yapılmaz (yapılsaydı permission-denied dönerdi).
      final none = await failing(
        'permission-denied',
      ).savedAmong(userId: _me, postIds: const []);
      expect(none.dataOrNull, isEmpty);
      expect(
        (await failing(
          'unavailable',
        ).savedAmong(userId: _me, postIds: ['p01'])).errorOrNull,
        FirestoreError.unavailable,
      );
      for (final id in _invalidIds) {
        expect(
          (await repository.savedAmong(
            userId: id,
            postIds: ['p01'],
          )).errorOrNull,
          FirestoreError.invalidArgument,
          reason: id,
        );
        expect(
          (await repository.savedAmong(
            userId: _me,
            postIds: [id],
          )).errorOrNull,
          FirestoreError.invalidArgument,
          reason: id,
        );
      }
    });

    test(
      'modele çevrilemeyen kayıt parse hatasıdır (eksik liste dönmez)',
      () async {
        await seed(_me, _postId);
        await db.collection('savedPosts').doc('u_ayse_bozuk').set({
          'userId': _me,
          'isDeleted': false,
          'savedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 13, 10)),
        });

        final result = await repository.listSaved(_me, const PageRequest());

        expect(result.errorOrNull, FirestoreError.parse);
      },
    );
  });

  group('T-19 · SavedPostRepository · hata eşlemesi ve geçersiz kimlik', () {
    test('okuma ve yazma hatası aynen eşlenir', () async {
      final broken = failing('permission-denied');

      final results = <FirestoreResult<Object?>>[
        await save(broken),
        await broken.softDeleteSaved(userId: _me, postId: _postId),
        await broken.restoreSaved(userId: _me, postId: _postId),
        await broken.isSaved(userId: _me, postId: _postId),
        await FirebaseSavedPostRepository(
          _QueryRecordingService(error: FirestoreError.permissionDenied),
        ).listSaved(_me, const PageRequest()),
      ];

      expect(
        results.map((result) => result.errorOrNull),
        everyElement(FirestoreError.permissionDenied),
      );
    });

    for (final id in _invalidIds) {
      test(
        '"$id": her metot invalidArgument döner, istisna sızmaz (W-54)',
        () async {
          final results = <FirestoreResult<Object?>>[
            await save(repository, userId: id),
            await save(repository, postId: id),
            await save(repository, clubId: id),
            await repository.softDeleteSaved(userId: id, postId: _postId),
            await repository.softDeleteSaved(userId: _me, postId: id),
            await repository.restoreSaved(userId: id, postId: _postId),
            await repository.restoreSaved(userId: _me, postId: id),
            await repository.listSaved(id, const PageRequest()),
            await repository.isSaved(userId: id, postId: _postId),
            await repository.isSaved(userId: _me, postId: id),
          ];

          expect(
            results.map((result) => result.errorOrNull),
            everyElement(FirestoreError.invalidArgument),
          );
          expect(await ids(), isEmpty);
        },
      );
    }
  });
}

/// Çağrıları [_inner] servise ileten, yazımları kaydeden ve betiklenen
/// adımları reddeden servis: [readError] verilirse tekil okuma o hatayla
/// biter; [denySet] `true` ise oluşturma `permission-denied` alır ve [_inner]
/// servise ulaşmaz.
final class _ScriptedService implements FirestoreService {
  _ScriptedService(this._inner, {this.readError, this.denySet = false});

  final FirestoreService _inner;

  /// Tekil okumanın (`getDoc`) hatası; `null` ise okuma [_inner] servise gider.
  final FirestoreError? readError;

  /// `set` (oluşturma) reddedilsin mi?
  final bool denySet;

  /// Yazım çağrıları, sırayla: `[işlem, yol]` ve varsa
  /// [normalizePayload] ile sadeleştirilmiş yük (reddedilenler dahil).
  final List<List<Object?>> writes = [];

  @override
  DocumentReference<Json> doc(String collectionPath, String id) =>
      _inner.doc(collectionPath, id);

  @override
  Object serverTimestamp() => _inner.serverTimestamp();

  @override
  Future<FirestoreResult<FirestoreDoc?>> getDoc(
    DocumentReference<Json> ref,
  ) async {
    final error = readError;
    return error == null ? _inner.getDoc(ref) : FirebaseFailure(error);
  }

  @override
  Future<FirestoreResult<void>> set(
    DocumentReference<Json> ref,
    Json data, {
    bool merge = false,
  }) async {
    writes.add(['set', ref.path, normalizePayload(data)]);
    return denySet
        ? const FirebaseFailure(FirestoreError.permissionDenied)
        : _inner.set(ref, data, merge: merge);
  }

  @override
  Future<FirestoreResult<void>> update(
    DocumentReference<Json> ref,
    Json fields, {
    bool touchUpdatedAt = true,
  }) {
    writes.add(['update', ref.path, normalizePayload(fields)]);
    return _inner.update(ref, fields, touchUpdatedAt: touchUpdatedAt);
  }

  @override
  Future<FirestoreResult<void>> softDelete(
    DocumentReference<Json> ref, {
    required String actorId,
    WriteBatch? batch,
  }) {
    writes.add(['softDelete', ref.path, actorId]);
    return _inner.softDelete(ref, actorId: actorId, batch: batch);
  }

  @override
  Future<FirestoreResult<void>> restore(
    DocumentReference<Json> ref, {
    WriteBatch? batch,
  }) {
    writes.add(['restore', ref.path]);
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
/// [_RecordingQuery] verir; `getPage` istenen sayfayı kaydeder ve [error]
/// verilmişse o hatayı, verilmemişse boş sayfa döner.
final class _QueryRecordingService implements FirestoreService {
  _QueryRecordingService({this.error});

  /// Sayfa okumasının hatası; `null` ise boş sayfa döner.
  final FirestoreError? error;

  /// Koleksiyon yolu → o yol için kurulan sorgu.
  final Map<String, _RecordingQuery> queries = {};

  /// `getPage` çağrılarına verilen sayfa istekleri, sırayla.
  final List<PageRequest> pages = [];

  @override
  Query<Json> collection(String path) => queries[path] = _RecordingQuery();

  @override
  Future<FirestoreResult<PageResult<FirestoreDoc>>> getPage(
    Query<Json> query,
    PageRequest page,
  ) async {
    pages.add(page);
    final error = this.error;
    return error == null
        ? const FirebaseSuccess(PageResult(items: []))
        : FirebaseFailure(error);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
