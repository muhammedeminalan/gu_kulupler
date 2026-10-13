// T-15 · BlockRepository: engelleme (oluşturma, yazılan alanlar), engelle →
// kaldır → yeniden engelle döngüsü (soft delete ve geri yükleme alanları,
// `createdAt` korunur), zaten yürürlükteki engel, "Geri al", yürürlükteki
// engellerin sorgusu ve süzgeçleri, kendini engelleme, geçersiz kimlik (W-54)
// ve hata eşlemesi (PLAN §9.6.15, §10.4; rules-spec §3.13, §6; D-10).
//
// Mutlu yollar `fake_cloud_firestore` ile (Q-06); hata yolları el yazımı
// çiftlerle (`test/fakes/sdk_firestore_stubs.dart`). Hangi yazımın yapıldığı,
// istenmeyen yazımı reddeden servis çiftiyle kanıtlanır.
//
// SDK sınıfları `@sealed` işaretlidir; test çifti bilerek uygular.
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/sdk_firestore_stubs.dart';
import '../helpers/plan_repository_table.dart';
import '../helpers/plan_service_table.dart';

const String _interface =
    'packages/gu_data/lib/src/repositories/block_repository.dart';
const String _implementation =
    'packages/gu_data/lib/src/repositories/firebase_block_repository.dart';
const String _me = 'u_ayse';
const String _other = 'u_mehmet';
const String _blockId = 'u_ayse_u_mehmet';

/// Geçersiz belge kimlikleri (W-54).
const List<String> _invalidIds = ['', 'u/1', '..', '__uid__'];

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreService service;
  late BlockRepository repository;

  Future<Json?> read([String id = _blockId]) async =>
      (await db.collection('blocks').doc(id).get()).data();

  Future<List<String>> ids() async => [
    for (final doc in (await db.collection('blocks').get()).docs) doc.id,
  ];

  Future<FirestoreResult<void>> block([
    String blockerId = _me,
    String blockedId = _other,
  ]) => repository.block(blockerId: blockerId, blockedId: blockedId);

  Future<FirestoreResult<void>> unblock([
    String blockerId = _me,
    String blockedId = _other,
  ]) => repository.softDeleteBlock(blockerId: blockerId, blockedId: blockedId);

  Future<FirestoreResult<void>> restore([
    String blockerId = _me,
    String blockedId = _other,
  ]) => repository.restoreBlock(blockerId: blockerId, blockedId: blockedId);

  Future<Set<String>?> active([String blockerId = _me]) async =>
      (await repository.fetchActiveBlocks(blockerId)).dataOrNull;

  /// [service] servisine bağlı, betiklenen adımları reddedilen repository
  /// (bkz. [_ScriptedService]).
  BlockRepository scripted({
    FirestoreError? readError,
    bool denySet = false,
    bool denyRestore = false,
  }) => FirebaseBlockRepository(
    _ScriptedService(
      service,
      readError: readError,
      denySet: denySet,
      denyRestore: denyRestore,
    ),
  );

  /// Her çağrısı [code] hatasıyla biten veritabanına bağlı repository.
  BlockRepository failing(String code) => FirebaseBlockRepository(
    FirebaseFirestoreService(StubFirestore(error: firestoreException(code))),
  );

  setUp(() {
    db = FakeFirebaseFirestore();
    service = FirebaseFirestoreService(db);
    repository = FirebaseBlockRepository(service);
  });

  group('T-15 · BlockRepository · sözleşme', () {
    test('PLAN §10.4 tablosundaki her üye arayüzde aynı imzayla var; başka '
        'üye yok', () {
      final plan = readPlanRepositoryMembers('$BlockRepository');

      expect(plan, hasLength(5));
      expect(interfaceMembers(_interface, '$BlockRepository').toSet(), {
        for (final row in plan) normalizeDartSource(row.signature),
      });
    });

    test('arayüzde ve uygulamada silme üyesi yok (D-10)', () {
      expect(deleteIdentifiersIn(_interface), isEmpty);
      expect(deleteIdentifiersIn(_implementation), isEmpty);
    });
  });

  group('T-15 · BlockRepository · block', () {
    test('kayıt yoksa türeyen kimlikle oluşturur: yalnızca çift ve ortak '
        'alanlar yazılır', () async {
      final result = await block();

      expect(result.isSuccess, isTrue);
      expect(await ids(), [_blockId]);
      expect(await read(), {
        'blockerId': _me,
        'blockedId': _other,
        'createdAt': isA<Timestamp>(),
        'updatedAt': isA<Timestamp>(),
        'isDeleted': false,
        'deletedAt': null,
        'deletedBy': null,
      });
    });

    test('engelle → kaldır → yeniden engelle: aynı kayıt işaretlenir ve geri '
        'yüklenir, createdAt korunur', () async {
      await block();
      final created = (await read())!;

      final removed = await unblock();

      expect(removed.isSuccess, isTrue);
      expect(await read(), {
        ...created,
        'isDeleted': true,
        'deletedAt': isA<Timestamp>(),
        'deletedBy': _me,
        'updatedAt': isA<Timestamp>(),
      });
      expect(await active(), isEmpty);

      // Yeniden engelleme geri yüklemedir: `set` (yeniden oluşturma)
      // reddedilse de başarır.
      final again = await scripted(
        denySet: true,
      ).block(blockerId: _me, blockedId: _other);

      expect(again.isSuccess, isTrue);
      expect(await read(), {...created, 'updatedAt': isA<Timestamp>()});
      expect(await ids(), [_blockId]);
      expect(await active(), {_other});
    });

    test(
      'engel zaten yürürlükteyse hiçbir şey yazmadan başarı döner',
      () async {
        await block();
        final before = await read();

        final result = await scripted(
          denySet: true,
          denyRestore: true,
        ).block(blockerId: _me, blockedId: _other);

        expect(result.isSuccess, isTrue);
        expect(await read(), before);
      },
    );

    test('okuma reddi "kayıt yok" sayılır ve oluşturma denenir; o da '
        'reddedilirse ret döner', () async {
      final created = await scripted(
        readError: FirestoreError.permissionDenied,
      ).block(blockerId: _me, blockedId: _other);
      final denied = await scripted(
        readError: FirestoreError.permissionDenied,
        denySet: true,
      ).block(blockerId: _me, blockedId: 'u_zeynep');

      expect(created.isSuccess, isTrue);
      expect(denied.errorOrNull, FirestoreError.permissionDenied);
      expect(await ids(), [_blockId]);
    });

    test('başka okuma hatası yazmadan aynen döner', () async {
      final result = await scripted(
        readError: FirestoreError.unavailable,
      ).block(blockerId: _me, blockedId: _other);

      expect(result.errorOrNull, FirestoreError.unavailable);
      expect(await ids(), isEmpty);
    });
  });

  group('T-15 · BlockRepository · softDeleteBlock / restoreBlock', () {
    test('Geri al: kaldırılan engel geri yüklenir (silme alanları null, '
        'createdAt aynı)', () async {
      await block();
      final created = (await read())!;
      await unblock();

      final result = await restore();

      expect(result.isSuccess, isTrue);
      expect(await read(), {...created, 'updatedAt': isA<Timestamp>()});
      expect(await active(), {_other});
    });

    test('yalnızca verilen çiftin kaydı değişir', () async {
      await block();
      await block(_me, 'u_zeynep');
      await block(_other, _me);
      final untouched = [
        await read('u_ayse_u_zeynep'),
        await read('u_mehmet_u_ayse'),
      ];

      await unblock();

      expect([
        await read('u_ayse_u_zeynep'),
        await read('u_mehmet_u_ayse'),
      ], untouched);
      expect(await active(), {'u_zeynep'});
      expect(await active(_other), {_me});
    });

    test('kayıt yoksa notFound; belge oluşmaz', () async {
      expect((await unblock()).errorOrNull, FirestoreError.notFound);
      expect((await restore()).errorOrNull, FirestoreError.notFound);
      expect(await ids(), isEmpty);
    });

    test('yazma hatası aynen eşlenir', () async {
      final broken = failing('permission-denied');

      expect(
        (await broken.softDeleteBlock(
          blockerId: _me,
          blockedId: _other,
        )).errorOrNull,
        FirestoreError.permissionDenied,
      );
      expect(
        (await broken.restoreBlock(
          blockerId: _me,
          blockedId: _other,
        )).errorOrNull,
        FirestoreError.permissionDenied,
      );
    });
  });

  group('T-15 · BlockRepository · fetchActiveBlocks / listBlocked', () {
    test('yalnızca sahibinin yürürlükteki engelleri döner', () async {
      await block();
      await block(_me, 'u_zeynep');
      await block(_me, 'u_can');
      await unblock(_me, 'u_can');
      await block(_other, _me);

      final listed = (await repository.listBlocked(_me)).dataOrNull!;

      expect(await active(), {_other, 'u_zeynep'});
      expect(
        listed.map((block) => block.id),
        unorderedEquals([_blockId, 'u_ayse_u_zeynep']),
      );
      expect(
        listed,
        everyElement(
          isA<BlockModel>()
              .having((block) => block.blockerId, 'blockerId', _me)
              .having((block) => block.isLive, 'isLive', isTrue)
              .having((block) => block.createdAt, 'createdAt', isNotNull),
        ),
      );
    });

    test(
      'sorgu sahibi ve silinmemiş süzgeçlerini taşır (rules-spec §6)',
      () async {
        final recording = _QueryRecordingService();

        final result = await FirebaseBlockRepository(
          recording,
        ).listBlocked(_me);

        expect(result.dataOrNull, isEmpty);
        expect(recording.queries.keys, ['blocks']);
        expect(recording.queries['blocks']!.equalities, {
          'blockerId': _me,
          'isDeleted': false,
        });
      },
    );

    test('engel yoksa boş küme ve boş liste', () async {
      expect(await active(), isEmpty);
      expect((await repository.listBlocked(_me)).dataOrNull, isEmpty);
    });

    test(
      'modele çevrilemeyen kayıt parse hatasıdır (eksik liste dönmez)',
      () async {
        await block();
        await db.collection('blocks').doc('u_ayse_bozuk').set({
          'blockerId': _me,
          'isDeleted': false,
        });

        expect(
          (await repository.listBlocked(_me)).errorOrNull,
          FirestoreError.parse,
        );
        expect(
          (await repository.fetchActiveBlocks(_me)).errorOrNull,
          FirestoreError.parse,
        );
      },
    );

    test('okuma hatası aynen eşlenir', () async {
      final broken = failing('permission-denied');

      expect(
        (await broken.fetchActiveBlocks(_me)).errorOrNull,
        FirestoreError.permissionDenied,
      );
      expect(
        (await broken.listBlocked(_me)).errorOrNull,
        FirestoreError.permissionDenied,
      );
    });
  });

  group('T-15 · BlockRepository · kendini engelleme ve geçersiz kimlik', () {
    test('kullanıcı kendini engelleyemez: üç yazma metodu da yazmadan '
        'invalidArgument', () async {
      final results = [
        await block(_me, _me),
        await unblock(_me, _me),
        await restore(_me, _me),
      ];

      expect(
        results.map((result) => result.errorOrNull),
        everyElement(FirestoreError.invalidArgument),
      );
      expect(await ids(), isEmpty);
    });

    for (final id in _invalidIds) {
      test(
        '"$id": her metot invalidArgument döner, istisna sızmaz (W-54)',
        () async {
          final results = <FirestoreResult<Object?>>[
            await repository.fetchActiveBlocks(id),
            await repository.listBlocked(id),
            await block(id),
            await block(_me, id),
            await unblock(id),
            await unblock(_me, id),
            await restore(id),
            await restore(_me, id),
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

/// Çağrıları [_inner] servise ileten, betiklenen adımları reddeden servis:
/// [readError] verilirse tekil okuma o hatayla biter; [denySet] / [denyRestore]
/// `true` ise ilgili yazım `permission-denied` alır. Reddedilen yazım
/// [_inner] servise ulaşmaz.
final class _ScriptedService implements FirestoreService {
  _ScriptedService(
    this._inner, {
    this.readError,
    this.denySet = false,
    this.denyRestore = false,
  });

  final FirestoreService _inner;

  /// Tekil okumanın (`getDoc`) hatası; `null` ise okuma [_inner] servise gider.
  final FirestoreError? readError;

  /// `set` (oluşturma) reddedilsin mi?
  final bool denySet;

  /// `restore` (geri yükleme) reddedilsin mi?
  final bool denyRestore;

  static const FirestoreResult<void> _denied = FirebaseFailure(
    FirestoreError.permissionDenied,
  );

  @override
  DocumentReference<Json> doc(String collectionPath, String id) =>
      _inner.doc(collectionPath, id);

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
  }) async => denySet ? _denied : _inner.set(ref, data, merge: merge);

  @override
  Future<FirestoreResult<void>> restore(
    DocumentReference<Json> ref, {
    WriteBatch? batch,
  }) async => denyRestore ? _denied : _inner.restore(ref, batch: batch);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// `where` eşitlik süzgeçlerini kaydeden sorgu; her kurucu aynı nesneyi
/// döndürür.
final class _RecordingQuery implements Query<Json> {
  /// Alan → `isEqualTo` değeri, eklenme sırasıyla.
  final Map<Object, Object?> equalities = {};

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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Koleksiyon sorgularını kaydeden servis: `collection` her yol için bir
/// [_RecordingQuery] verir, `getList` boş liste döner.
final class _QueryRecordingService implements FirestoreService {
  /// Koleksiyon yolu → o yol için kurulan sorgu.
  final Map<String, _RecordingQuery> queries = {};

  @override
  Query<Json> collection(String path) => queries[path] = _RecordingQuery();

  @override
  Future<FirestoreResult<List<FirestoreDoc>>> getList(
    Query<Json> query,
  ) async => const FirebaseSuccess([]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
