// `FirestoreService` fake'i (PLAN §4.7): gerçek `FirebaseFirestoreService`'i
// bellekteki `FakeFirebaseFirestore` üzerinde çalıştırır — sorgu, batch,
// transaction ve soft delete davranışı gerçek servisle aynıdır; üstüne çağrı
// günlüğü ve tek seferlik hata (`failNext`) ekler.
//
//   final firestore = FakeFirestoreService();
//   await firestore.db.collection('clubs').doc('c01').set({...}); // ön veri
//   firestore.failNext(FirestoreError.unavailable);
//
// Canlı akışlar (`watchDoc` / `watchList`) bekleyen hatayı tüketmez: hata
// yalnızca sonuç döndüren çağrılara enjekte edilir. Silme metodu yoktur (D-10).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:gu_data/gu_data.dart';

import 'fake_base.dart';

final class FakeFirestoreService extends FakeBase implements FirestoreService {
  /// Bellekteki veritabanı; test ön veriyi buraya yazar ve sonucu buradan
  /// okur. İlk kullanımda kurulur (`registerDefaultFakes` her `pumpApp`'te
  /// yeni bir fake kaydeder; kullanılmayan veritabanı kurulmaz).
  late final FakeFirebaseFirestore db = FakeFirebaseFirestore();

  late final FirestoreService _real = FirebaseFirestoreService(db);

  @override
  DocumentReference<Json> doc(String collectionPath, String id) =>
      _real.doc(collectionPath, id);

  @override
  String newId(String collectionPath) => _real.newId(collectionPath);

  @override
  Query<Json> collection(String path) => _real.collection(path);

  @override
  Query<Json> collectionGroup(String collectionId) =>
      _real.collectionGroup(collectionId);

  @override
  Future<FirestoreResult<FirestoreDoc?>> getDoc(DocumentReference<Json> ref) {
    record('getDoc', [ref.path]);
    return _run(() => _real.getDoc(ref));
  }

  @override
  Future<FirestoreResult<List<FirestoreDoc>>> getList(Query<Json> query) {
    record('getList');
    return _run(() => _real.getList(query));
  }

  @override
  Future<FirestoreResult<PageResult<FirestoreDoc>>> getPage(
    Query<Json> query,
    PageRequest page,
  ) {
    record('getPage', [page]);
    return _run(() => _real.getPage(query, page));
  }

  @override
  Stream<FirestoreResult<FirestoreDoc?>> watchDoc(DocumentReference<Json> ref) {
    record('watchDoc', [ref.path]);
    return _real.watchDoc(ref);
  }

  @override
  Stream<FirestoreResult<List<FirestoreDoc>>> watchList(Query<Json> query) {
    record('watchList');
    return _real.watchList(query);
  }

  @override
  Future<FirestoreResult<String>> add(String collectionPath, Json data) {
    record('add', [collectionPath, data]);
    return _run(() => _real.add(collectionPath, data));
  }

  @override
  Future<FirestoreResult<void>> set(
    DocumentReference<Json> ref,
    Json data, {
    bool merge = false,
  }) {
    record('set', [ref.path, data, merge]);
    return _run(() => _real.set(ref, data, merge: merge));
  }

  @override
  Future<FirestoreResult<void>> update(
    DocumentReference<Json> ref,
    Json fields, {
    bool touchUpdatedAt = true,
  }) {
    record('update', [ref.path, fields, touchUpdatedAt]);
    return _run(
      () => _real.update(ref, fields, touchUpdatedAt: touchUpdatedAt),
    );
  }

  @override
  Future<FirestoreResult<T>> runTransaction<T>(
    Future<T> Function(Transaction tx) body,
  ) {
    record('runTransaction');
    return _run(() => _real.runTransaction(body));
  }

  @override
  Future<FirestoreResult<void>> commitBatch(
    void Function(WriteBatch batch) build,
  ) {
    record('commitBatch');
    return _run(() => _real.commitBatch(build));
  }

  @override
  Future<FirestoreResult<void>> softDelete(
    DocumentReference<Json> ref, {
    required String actorId,
    WriteBatch? batch,
  }) {
    record('softDelete', [ref.path, actorId]);
    return _run(() => _real.softDelete(ref, actorId: actorId, batch: batch));
  }

  @override
  Future<FirestoreResult<void>> restore(
    DocumentReference<Json> ref, {
    WriteBatch? batch,
  }) {
    record('restore', [ref.path]);
    return _run(() => _real.restore(ref, batch: batch));
  }

  @override
  Future<FirestoreResult<int>> count(Query<Json> query) {
    record('count');
    return _run(() => _real.count(query));
  }

  @override
  Object serverTimestamp() => _real.serverTimestamp();

  /// Bekleyen hata varsa onu döndürür (gerçek servise gidilmez), yoksa
  /// [action] sonucunu.
  Future<FirestoreResult<T>> _run<T>(
    Future<FirestoreResult<T>> Function() action,
  ) async => switch (takeFailure()) {
    null => await action(),
    final FirestoreError error => FirebaseFailure(error),
    _ => const FirebaseFailure(FirestoreError.unknown),
  };
}
