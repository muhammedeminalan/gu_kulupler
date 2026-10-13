import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gu_data/gu_data.dart';

/// Transaction içinde kuyruğa giren tek yazım: işlem (`set` / `update`),
/// belge yolu ve [normalizePayload] ile sadeleştirilmiş yük.
typedef RecordedWrite = ({String op, String path, Json data});

/// Yüklerdeki sunucu zamanı nöbetçisinin kayıttaki karşılığı.
const String serverTimestampMark = '@serverTimestamp';

/// Yüklerdeki sayaç deltasının (`FieldValue.increment`) kayıttaki karşılığı.
/// Delta değeri nöbetçiden okunamaz; belgedeki etkisiyle doğrulanır.
const String incrementMark = '@increment';

/// Ham yükü karşılaştırılabilir biçime çevirir: sunucu zamanı nöbetçisi
/// [serverTimestampMark], başka her `FieldValue` [incrementMark] olur
/// (repository yalnızca bu iki nöbetçiyi yazar).
Object? normalizePayload(Object? value) => switch (value) {
  final FieldValue field when field == FieldValue.serverTimestamp() =>
    serverTimestampMark,
  FieldValue() => incrementMark,
  final Map<Object?, Object?> map => <String, Object?>{
    for (final entry in map.entries)
      entry.key! as String: normalizePayload(entry.value),
  },
  final List<Object?> list => [for (final item in list) normalizePayload(item)],
  _ => value,
};

/// Gerçek bir [FirestoreService]'i saran kayıt tutucu: transaction sayısını,
/// transaction içindeki yazımları ([writes]) ve transaction **dışındaki**
/// yazım çağrılarını ([outsideWrites]) kaydeder; her çağrıyı aynen iletir.
///
/// "Üyelik + sayaç + günlük tek işlemde" iddiası bununla kanıtlanır: beklenen
/// yazımların tümü [writes] içindedir, [transactions] 1 ve [outsideWrites] 0.
final class RecordingFirestoreService implements FirestoreService {
  /// [_inner] servisine iletir.
  RecordingFirestoreService(this._inner);

  final FirestoreService _inner;

  /// Transaction'larda kuyruğa giren yazımlar, sırayla.
  final List<RecordedWrite> writes = [];

  /// Transaction gövdesinde okunan belge yolları, sırayla.
  final List<String> reads = [];

  /// `runTransaction` çağrı sayısı.
  int transactions = 0;

  /// Transaction dışındaki yazım çağrıları (`set`, `update`, `add`,
  /// `commitBatch`, `softDelete`, `restore`).
  int outsideWrites = 0;

  @override
  DocumentReference<Json> doc(String collectionPath, String id) =>
      _inner.doc(collectionPath, id);

  @override
  String newId(String collectionPath) => _inner.newId(collectionPath);

  @override
  Query<Json> collection(String path) => _inner.collection(path);

  @override
  Query<Json> collectionGroup(String collectionId) =>
      _inner.collectionGroup(collectionId);

  @override
  Future<FirestoreResult<FirestoreDoc?>> getDoc(DocumentReference<Json> ref) =>
      _inner.getDoc(ref);

  @override
  Future<FirestoreResult<List<FirestoreDoc>>> getList(Query<Json> query) =>
      _inner.getList(query);

  @override
  Future<FirestoreResult<PageResult<FirestoreDoc>>> getPage(
    Query<Json> query,
    PageRequest page,
  ) => _inner.getPage(query, page);

  @override
  Stream<FirestoreResult<FirestoreDoc?>> watchDoc(
    DocumentReference<Json> ref,
  ) => _inner.watchDoc(ref);

  @override
  Stream<FirestoreResult<List<FirestoreDoc>>> watchList(Query<Json> query) =>
      _inner.watchList(query);

  @override
  Future<FirestoreResult<String>> add(String collectionPath, Json data) {
    outsideWrites++;
    return _inner.add(collectionPath, data);
  }

  @override
  Future<FirestoreResult<void>> set(
    DocumentReference<Json> ref,
    Json data, {
    bool merge = false,
  }) {
    outsideWrites++;
    return _inner.set(ref, data, merge: merge);
  }

  @override
  Future<FirestoreResult<void>> update(
    DocumentReference<Json> ref,
    Json fields, {
    bool touchUpdatedAt = true,
  }) {
    outsideWrites++;
    return _inner.update(ref, fields, touchUpdatedAt: touchUpdatedAt);
  }

  @override
  Future<FirestoreResult<T>> runTransaction<T>(
    Future<T> Function(Transaction tx) body,
  ) {
    transactions++;
    return _inner.runTransaction(
      (tx) => body(_RecordingTransaction(tx, writes, reads)),
    );
  }

  @override
  Future<FirestoreResult<void>> commitBatch(
    void Function(WriteBatch batch) build,
  ) {
    outsideWrites++;
    return _inner.commitBatch(build);
  }

  @override
  Future<FirestoreResult<void>> softDelete(
    DocumentReference<Json> ref, {
    required String actorId,
    WriteBatch? batch,
  }) {
    outsideWrites++;
    return _inner.softDelete(ref, actorId: actorId, batch: batch);
  }

  @override
  Future<FirestoreResult<void>> restore(
    DocumentReference<Json> ref, {
    WriteBatch? batch,
  }) {
    outsideWrites++;
    return _inner.restore(ref, batch: batch);
  }

  @override
  Future<FirestoreResult<int>> count(Query<Json> query) => _inner.count(query);

  @override
  Object serverTimestamp() => _inner.serverTimestamp();
}

/// Okuma ve yazımları kaydedip [_inner] transaction'ına ileten sarmalayıcı.
final class _RecordingTransaction implements Transaction {
  _RecordingTransaction(this._inner, this._writes, this._reads);

  final Transaction _inner;
  final List<RecordedWrite> _writes;
  final List<String> _reads;

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> documentReference,
  ) {
    _reads.add(documentReference.path);
    return _inner.get(documentReference);
  }

  @override
  Transaction set<T>(
    DocumentReference<T> documentReference,
    T data, [
    SetOptions? options,
  ]) {
    _record('set', documentReference.path, data);
    _inner.set(documentReference, data, options);
    return this;
  }

  @override
  Transaction update(
    DocumentReference<Object?> documentReference,
    Map<Object, Object?> data,
  ) {
    _record('update', documentReference.path, data);
    _inner.update(documentReference, data);
    return this;
  }

  void _record(String op, String path, Object? data) => _writes.add((
    op: op,
    path: path,
    data: normalizePayload(data)! as Json,
  ));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
