// El yazımı `cloud_firestore` SDK çiftleri (mock kütüphanesi yok —
// docs/testing.md §1.2). `fake_cloud_firestore` hata fırlatamadığı ve
// askıda kalamadığı için hata eşleme ve zaman aşımı testleri bunları
// kullanır. SDK sınıfları `@sealed` işaretlidir; test çifti bilerek uygular.
// ignore_for_file: subtype_of_sealed_class
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gu_data/gu_data.dart';

/// Betiklenen çağrı sonucu: [error] doluysa o hatayla biter, boşsa **hiç
/// tamamlanmaz** (zaman aşımı testleri).
Future<T> _outcome<T>(Object? error) =>
    error == null ? Completer<T>().future : Future<T>.error(error);

/// `cloud_firestore` kaynaklı hata.
FirebaseException firestoreException(String code, {String? message}) =>
    FirebaseException(plugin: 'cloud_firestore', code: code, message: message);

/// Önbellek okuması (`GetOptions(source: Source.cache)`): [cached] varsa
/// o döner; yoksa [error] doluysa onunla biter, boşsa (askıda kalan stub)
/// "önbellekte yok" (`unavailable`) — zaman aşımı testleri önbellek
/// yedeğiyle aynı zamanlamada biter (T-44 · A4-05).
Future<T> _cacheOutcome<T>(T? cached, Object? error) {
  if (cached != null) return Future.value(cached);
  if (error != null) return Future<T>.error(error);
  return Future<T>.error(
    firestoreException('unavailable', message: 'önbellekte yok'),
  );
}

/// Her ağ çağrısı [error] ile biten (ya da askıda kalan) belge referansı.
/// [snapshotEvents] ile canlı dinleme olayları elle üretilir.
final class StubDocumentReference implements DocumentReference<Json> {
  /// [error] verilmezse çağrılar askıda kalır.
  StubDocumentReference({this.error, this.path = 'posts/p01', this.cached});

  /// Her çağrının fırlattığı hata; `null` ise çağrı tamamlanmaz.
  final Object? error;

  /// Önbellek okumasının döndürdüğü belge; `null` ise önbellekte yok.
  final DocumentSnapshot<Json>? cached;

  @override
  final String path;

  /// [snapshots] akışının denetleyicisi.
  final StreamController<DocumentSnapshot<Json>> snapshotEvents =
      StreamController<DocumentSnapshot<Json>>();

  /// [get] çağrılarına verilen seçenekler, sırasıyla (T-44 · önbellek okuması).
  final List<GetOptions?> getOptions = [];

  @override
  String get id => path.split('/').last;

  @override
  Future<DocumentSnapshot<Json>> get([GetOptions? options]) {
    getOptions.add(options);
    if (options?.source == Source.cache) return _cacheOutcome(cached, error);
    return _outcome(error);
  }

  @override
  Future<void> set(Json data, [SetOptions? options]) => _outcome(error);

  @override
  Future<void> update(Map<Object, Object?> data) => _outcome(error);

  @override
  Stream<DocumentSnapshot<Json>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => snapshotEvents.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Her ağ çağrısı [error] ile biten (ya da askıda kalan) sorgu / koleksiyon.
/// Sorgu kurucuları (`limit`, `where` …) aynı nesneyi döndürür.
final class StubQuery implements CollectionReference<Json> {
  /// [error] verilmezse çağrılar askıda kalır.
  StubQuery({this.error, this.cached});

  /// Her çağrının fırlattığı hata; `null` ise çağrı tamamlanmaz.
  final Object? error;

  /// Önbellek okumasının döndürdüğü sonuç; `null` ise önbellekte yok.
  final QuerySnapshot<Json>? cached;

  /// Önbellekten okuma çağrıları (T-44 · A4-05); sayısı [cacheReads].
  final List<GetOptions?> cacheReadLog = [];

  /// Önbellekten okuma çağrı sayısı.
  int get cacheReads => cacheReadLog.length;

  /// [snapshots] akışının denetleyicisi.
  final StreamController<QuerySnapshot<Json>> snapshotEvents =
      StreamController<QuerySnapshot<Json>>();

  @override
  Future<QuerySnapshot<Json>> get([GetOptions? options]) {
    if (options?.source != Source.cache) return _outcome(error);
    cacheReadLog.add(options);
    return _cacheOutcome(cached, error);
  }

  @override
  Query<Json> limit(int limit) => this;

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
  }) => this;

  /// T-37 · sıralı sayfa sorgularının hata eşlemesi (ADM-04 / ADM-05).
  @override
  Query<Json> orderBy(Object field, {bool descending = false}) => this;

  @override
  Query<Json> startAfterDocument(DocumentSnapshot<Object?> documentSnapshot) =>
      this;

  @override
  AggregateQuery count() => _StubAggregateQuery(error);

  @override
  DocumentReference<Json> doc([String? path]) =>
      StubDocumentReference(error: error, path: 'posts/${path ?? 'auto'}');

  @override
  Stream<QuerySnapshot<Json>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => snapshotEvents.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _StubAggregateQuery implements AggregateQuery {
  _StubAggregateQuery(this._error);

  final Object? _error;

  @override
  Future<AggregateQuerySnapshot> get({
    AggregateSource source = AggregateSource.server,
  }) => _outcome(_error);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Commit'i [error] ile biten (ya da askıda kalan) batch; yazımları ve commit
/// sayısını kaydeder.
final class StubWriteBatch implements WriteBatch {
  /// [error] verilmezse commit askıda kalır.
  StubWriteBatch({this.error});

  /// Commit'in fırlattığı hata; `null` ise commit tamamlanmaz.
  final Object? error;

  /// Batch'e eklenen yazım sayısı.
  int writes = 0;

  /// [commit] çağrı sayısı.
  int commits = 0;

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) =>
      writes++;

  @override
  void update<T>(DocumentReference<T> document, T data) => writes++;

  @override
  Future<void> commit() {
    commits++;
    return _outcome(error);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Her ağ çağrısı [error] ile biten (ya da askıda kalan) veritabanı;
/// `runTransaction` parametrelerini ve üretilen batch'leri kaydeder.
final class StubFirestore implements FirebaseFirestore {
  /// [error] verilmezse çağrılar askıda kalır.
  StubFirestore({this.error});

  /// Her çağrının fırlattığı hata; `null` ise çağrı tamamlanmaz.
  final Object? error;

  /// [batch] ile üretilen batch'ler, üretim sırasıyla.
  final List<StubWriteBatch> batches = [];

  /// Son `runTransaction` çağrısına verilen zaman aşımı.
  Duration? transactionTimeout;

  /// Son `runTransaction` çağrısına verilen en çok deneme sayısı.
  int? transactionMaxAttempts;

  @override
  CollectionReference<Json> collection(String collectionPath) =>
      StubQuery(error: error);

  /// T-37 · ADM-05 e-posta araması (`collectionGroup('private')`).
  @override
  Query<Json> collectionGroup(String collectionPath) => StubQuery(error: error);

  @override
  WriteBatch batch() {
    final batch = StubWriteBatch(error: error);
    batches.add(batch);
    return batch;
  }

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) {
    transactionTimeout = timeout;
    transactionMaxAttempts = maxAttempts;
    return _outcome(error);
  }

  /// `enableNetwork` / `disableNetwork` çağrıları (`true` = açma), sırasıyla
  /// (T-44 · A4-08). Ağ anahtarı [error] doluysa onunla biter, boşsa hemen
  /// tamamlanır (askıda kalmaz).
  final List<bool> networkCalls = [];

  @override
  Future<void> enableNetwork() {
    networkCalls.add(true);
    final failure = error;
    return failure == null ? Future.value() : Future.error(failure);
  }

  @override
  Future<void> disableNetwork() {
    networkCalls.add(false);
    final failure = error;
    return failure == null ? Future.value() : Future.error(failure);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Batch commit'i [error] ile biten, okumaları ve tekil yazımları [inner]
/// veritabanına giden çift: "belge zaten var, Rules ikinci yazımı reddediyor"
/// durumunu kurar (`fake_cloud_firestore` kural çalıştırmaz).
final class FailingBatchFirestore implements FirebaseFirestore {
  /// [inner] gerçek veriyi tutar; her `batch().commit()` [error] fırlatır.
  FailingBatchFirestore(this.inner, {required this.error});

  /// Okumaların gittiği veritabanı.
  final FirebaseFirestore inner;

  /// Batch commit'inin fırlattığı hata.
  final Object error;

  @override
  CollectionReference<Json> collection(String collectionPath) =>
      inner.collection(collectionPath);

  @override
  WriteBatch batch() => StubWriteBatch(error: error);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Olmayan belgenin anlık görüntüsü; [fromCache] `true` ise SDK'nın
/// çevrimdışı "önbellekte yok" olayıdır (T-44 · A4-02).
final class StubMissingSnapshot implements DocumentSnapshot<Json> {
  /// [fromCache] önbellek bayrağıyla olmayan belge.
  StubMissingSnapshot({required this.fromCache});

  /// `metadata.isFromCache` değeri.
  final bool fromCache;

  @override
  bool get exists => false;

  @override
  Json? data() => null;

  @override
  SnapshotMetadata get metadata => _StubMetadata(isFromCache: fromCache);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _StubMetadata implements SnapshotMetadata {
  _StubMetadata({required this.isFromCache});

  @override
  final bool isFromCache;

  @override
  bool get hasPendingWrites => false;
}
