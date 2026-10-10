import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gu_data/src/constants/limits.dart';
import 'package:gu_data/src/core/base_fields.dart';
import 'package:gu_data/src/core/conflict_exception.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/core/page_cursor.dart';
import 'package:gu_data/src/core/page_request.dart';
import 'package:gu_data/src/core/page_result.dart';
import 'package:gu_data/src/core/soft_delete.dart';
import 'package:gu_data/src/services/firestore_types.dart';

/// Firestore erişiminin tek kapısı (PLAN §10.2, D-34).
///
/// Yalnızca `firebase_<alan>_repository.dart` uygulamaları çağırır; ViewModel
/// bu servisi ve SDK tiplerini görmez. Sonuç döndüren her metot istisna
/// **fırlatmaz**: hata [FirebaseFailure] olarak döner
/// ([FirestoreError.fromCode], zaman aşımı → [FirestoreError.timeout]).
/// Yol/sorgu kurucuları ([doc], [newId], [collection], [collectionGroup],
/// [serverTimestamp]) ağ çağrısı yapmaz.
///
/// **Silme yoktur (D-10).** Arayüzde belge silen hiçbir üye bulunmaz; içerik
/// [softDelete] ile işaretlenir, [restore] ile geri alınır. [commitBatch] ve
/// [runTransaction] gövdelerine verilen nesneler de silme çağrısını çalışma
/// zamanında reddeder.
///
/// **Okuma sözleşmesi:** servis sorguya süzgeç **eklemez**. Liste sorgusunu
/// kuran repository `isDeleted == false` süzgecini taşımak zorundadır
/// (soft-delete.md §4; Security Rules süzgeçsiz sorguyu reddeder —
/// rules-spec §6). Tekil okumada silinmiş belgeyi "yok" saymak da
/// repository'nin işidir.
abstract interface class FirestoreService {
  /// [collectionPath] koleksiyonundaki [id] kimlikli belgenin referansı.
  /// Yol `FirestoreCollections` sabitleriyle kurulur.
  ///
  /// [id] tek yol parçası olmalıdır: boşsa ya da `/` içeriyorsa
  /// [ArgumentError] fırlatır (kimlik başka bir belgenin yoluna dönüşemez).
  /// Dış girdiden (rota parametresi, QR) gelen kimlikleri çağıran repository
  /// önce doğrular.
  DocumentReference<Json> doc(String collectionPath, String id);

  /// [collectionPath] için yeni, benzersiz bir belge kimliği üretir (belge
  /// yazılmaz). Gönderi görselleri yüklenmeden önce `postId` gerektiğinde
  /// kullanılır (CD-39).
  String newId(String collectionPath);

  /// [path] koleksiyonunun sorgusu.
  Query<Json> collection(String path);

  /// [collectionId] adlı tüm alt koleksiyonların sorgusu (yalnızca
  /// `private`, ADM-05).
  Query<Json> collectionGroup(String collectionId);

  /// [ref] belgesini okur; belge yoksa başarı `null` döner.
  Future<FirestoreResult<FirestoreDoc?>> getDoc(DocumentReference<Json> ref);

  /// [query] sonucunun tamamını okur; boş liste başarıdır.
  Future<FirestoreResult<List<FirestoreDoc>>> getList(Query<Json> query);

  /// [query] sonucundan bir sayfa okur: en çok `page.limit` belge,
  /// `page.after` imlecinden sonrası. Sayfa dolu geldiyse sonuç bir sonraki
  /// sayfanın imlecini taşır (`PageResult.hasMore`).
  Future<FirestoreResult<PageResult<FirestoreDoc>>> getPage(
    Query<Json> query,
    PageRequest page,
  );

  /// [ref] belgesini canlı dinler; belge yoksa olay `null` taşır. Hata olayı
  /// [FirebaseFailure] olarak akışa yazılır, akışı hatayla kapatmaz.
  Stream<FirestoreResult<FirestoreDoc?>> watchDoc(DocumentReference<Json> ref);

  /// [query] sonucunu canlı dinler (yalnızca PLAN §10.6 listesi). Hata olayı
  /// [FirebaseFailure] olarak akışa yazılır, akışı hatayla kapatmaz.
  Stream<FirestoreResult<List<FirestoreDoc>>> watchList(Query<Json> query);

  /// [collectionPath] koleksiyonuna otomatik kimlikli yeni belge yazar ve
  /// kimliğini döndürür. Ortak alanları (`BaseFieldsPayload.create`) çağıran
  /// [data] içinde verir.
  Future<FirestoreResult<String>> add(String collectionPath, Json data);

  /// [ref] belgesini [data] ile yazar; [merge] `true` ise var olan alanlar
  /// korunur. Ortak alanları (`BaseFieldsPayload.create`) çağıran verir.
  Future<FirestoreResult<void>> set(
    DocumentReference<Json> ref,
    Json data, {
    bool merge = false,
  });

  /// [ref] belgesinin [fields] alanlarını günceller ve `updatedAt` alanını
  /// sunucu zamanına çeker (`BaseFieldsPayload.update`). [fields] boşsa
  /// [FirestoreError.invalidArgument]; belge yoksa [FirestoreError.notFound].
  ///
  /// [touchUpdatedAt] `false` ise `updatedAt` **yazılmaz**: yalnızca Rules
  /// beyaz listesi `updatedAt` içermeyen yazımlar içindir (gönderi beğenisi
  /// `likes` + `likeCount` — rules-spec §3.5; `updatedAt` eklenirse kural
  /// `permission-denied` verir). Başka her güncelleme varsayılanı kullanır.
  Future<FirestoreResult<void>> update(
    DocumentReference<Json> ref,
    Json fields, {
    bool touchUpdatedAt = true,
  });

  /// [body] gövdesini bir transaction içinde çalıştırır (SDK en çok 3 kez
  /// dener). Gövde `ConflictException` atarsa sonuç
  /// [FirestoreError.ruleViolation] ya da [FirestoreError.conflict] olur ve
  /// istisnanın `detail` değeri başarısızlığa taşınır. Gövde yeniden
  /// çalıştırılabilir olmalıdır.
  Future<FirestoreResult<T>> runTransaction<T>(
    Future<T> Function(Transaction tx) body,
  );

  /// [build] ile doldurulan yazımları tek batch olarak işler (ya hepsi ya
  /// hiçbiri). En çok [Limits.batchMaxWrites] yazım; aşılırsa hiçbir şey
  /// yazılmadan [FirestoreError.invalidArgument] döner. [build] eşzamanlı
  /// olmalıdır (`async` gövde → [FirestoreError.invalidArgument], hiçbir şey
  /// yazılmaz) ve commit çağırmaz.
  ///
  /// Gövdede bu batch'e eklenen bir [softDelete] / [restore] başarısız olursa
  /// batch **geçersiz** sayılır: hiçbir yazım (aynı batch'teki sayaç dahil)
  /// uygulanmaz ve o hata döner. Gövde bu çağrıların sonucunu beklemek ya da
  /// denetlemek zorunda değildir.
  Future<FirestoreResult<void>> commitBatch(
    void Function(WriteBatch batch) build,
  );

  /// [ref] belgesini silinmiş olarak işaretler (`SoftDelete.payload`).
  /// [batch] verilirse yazım batch'e eklenir (commit'i `commitBatch` yapar),
  /// verilmezse hemen yazılır. [actorId] silen kullanıcının uid'idir; boşsa
  /// [FirestoreError.invalidArgument]. Batch kipindeki hata (boş [actorId]
  /// dahil) batch'i geçersiz kılar: [commitBatch] hiçbir şey yazmaz.
  Future<FirestoreResult<void>> softDelete(
    DocumentReference<Json> ref, {
    required String actorId,
    WriteBatch? batch,
  });

  /// [ref] belgesinin silinmesini geri alır (`SoftDelete.restorePayload`).
  /// [batch] verilirse yazım batch'e eklenir, verilmezse hemen yazılır.
  /// Batch kipindeki hata batch'i geçersiz kılar ([commitBatch] yazmaz).
  Future<FirestoreResult<void>> restore(
    DocumentReference<Json> ref, {
    WriteBatch? batch,
  });

  /// [query] ile eşleşen belge sayısı (belgeler indirilmez).
  Future<FirestoreResult<int>> count(Query<Json> query);

  /// Sunucu zamanı nöbetçi değeri. `Object` döner; modeller ve ViewModel
  /// `FieldValue` tipini görmez.
  Object serverTimestamp();
}

/// [FirestoreService] uygulaması: `cloud_firestore` SDK'sını sarar.
final class FirebaseFirestoreService implements FirestoreService {
  /// Verilen `FirebaseFirestore` örneğini sarar; her ağ çağrısı `timeout`
  /// (varsayılan [Limits.firestoreTimeout]) içinde dönmezse
  /// [FirestoreError.timeout] ile sonuçlanır.
  FirebaseFirestoreService(
    this._firestore, {
    this._timeout = Limits.firestoreTimeout,
  });

  final FirebaseFirestore _firestore;
  final Duration _timeout;

  /// Transaction'ın SDK tarafındaki en çok deneme sayısı (PLAN §10.2).
  static const int transactionMaxAttempts = 3;

  @override
  DocumentReference<Json> doc(String collectionPath, String id) {
    if (id.isEmpty || id.contains('/')) {
      throw ArgumentError.value(id, 'id', 'tek yol parçası olmalı');
    }
    return _firestore.collection(collectionPath).doc(id);
  }

  @override
  String newId(String collectionPath) =>
      _firestore.collection(collectionPath).doc().id;

  @override
  Query<Json> collection(String path) => _firestore.collection(path);

  @override
  Query<Json> collectionGroup(String collectionId) =>
      _firestore.collectionGroup(collectionId);

  @override
  Future<FirestoreResult<FirestoreDoc?>> getDoc(DocumentReference<Json> ref) =>
      _guard(() async => FirestoreDoc.fromSnapshot(await ref.get()));

  @override
  Future<FirestoreResult<List<FirestoreDoc>>> getList(Query<Json> query) =>
      _guard(() async => _docsOf(await query.get()));

  @override
  Future<FirestoreResult<PageResult<FirestoreDoc>>> getPage(
    Query<Json> query,
    PageRequest page,
  ) => _guard(() async {
    final after = page.after;
    final start = after == null
        ? query
        : query.startAfterDocument(after.snapshot);
    final snapshot = await start.limit(page.limit).get();
    final docs = snapshot.docs;
    return PageResult(
      items: _docsOf(snapshot),
      next: docs.length == page.limit ? PageCursor(docs.last) : null,
    );
  });

  @override
  Stream<FirestoreResult<FirestoreDoc?>> watchDoc(
    DocumentReference<Json> ref,
  ) => _results(ref.snapshots().map(FirestoreDoc.fromSnapshot));

  @override
  Stream<FirestoreResult<List<FirestoreDoc>>> watchList(Query<Json> query) =>
      _results(query.snapshots().map(_docsOf));

  @override
  Future<FirestoreResult<String>> add(String collectionPath, Json data) =>
      _guard(() async {
        final ref = _firestore.collection(collectionPath).doc();
        await ref.set(data);
        return ref.id;
      });

  @override
  Future<FirestoreResult<void>> set(
    DocumentReference<Json> ref,
    Json data, {
    bool merge = false,
  }) => _guard(
    () => merge ? ref.set(data, SetOptions(merge: true)) : ref.set(data),
  );

  @override
  Future<FirestoreResult<void>> update(
    DocumentReference<Json> ref,
    Json fields, {
    bool touchUpdatedAt = true,
  }) {
    if (fields.isEmpty) {
      return _invalidArgument('update: güncellenecek alan yok');
    }
    return _guard(
      () => ref.update({
        ...fields,
        if (touchUpdatedAt) ...BaseFieldsPayload.update(),
      }),
    );
  }

  @override
  Future<FirestoreResult<T>> runTransaction<T>(
    Future<T> Function(Transaction tx) body,
  ) => _guard(
    () => _firestore.runTransaction<T>(
      (tx) => body(_GuardedTransaction(tx)),
      timeout: _timeout,
      maxAttempts: transactionMaxAttempts,
    ),
  );

  @override
  Future<FirestoreResult<void>> commitBatch(
    void Function(WriteBatch batch) build,
  ) => _guard(() async {
    final inner = _firestore.batch();
    final batch = _GuardedWriteBatch(inner);
    // `async` bir gövde de bu tipe atanabilir; dönen değerden yakalanır.
    final Object? Function(WriteBatch) run = build;
    final returned = run(batch);
    if (returned is Future<Object?>) {
      // Batch reddedildi; gövdenin geç gelen hatası ayrıca raporlanmaz.
      returned.ignore();
      throw _invalid('commitBatch: gövde eşzamanlı olmalı (async verilmiş)');
    }
    final poison = batch.poison;
    if (poison != null) {
      // Batch'e eklenemeyen soft delete / geri alma: eşlik eden yazımlar
      // (sayaç vb.) tek başına işlenmez.
      Error.throwWithStackTrace(poison, StackTrace.current);
    }
    if (batch.writeCount > Limits.batchMaxWrites) {
      throw _invalid(
        'commitBatch: ${batch.writeCount} yazım, sınır '
        '${Limits.batchMaxWrites}',
      );
    }
    if (batch.writeCount > 0) await inner.commit();
  });

  @override
  Future<FirestoreResult<void>> softDelete(
    DocumentReference<Json> ref, {
    required String actorId,
    WriteBatch? batch,
  }) {
    if (actorId.isEmpty) {
      return _rejected(_invalid('softDelete: actorId boş'), batch);
    }
    return _write(ref, SoftDelete.payload(actorId: actorId), batch);
  }

  @override
  Future<FirestoreResult<void>> restore(
    DocumentReference<Json> ref, {
    WriteBatch? batch,
  }) => _write(ref, SoftDelete.restorePayload(), batch);

  @override
  Future<FirestoreResult<int>> count(Query<Json> query) =>
      _guard(() async => (await query.count().get()).count ?? 0);

  @override
  Object serverTimestamp() => FieldValue.serverTimestamp();

  /// [payload] yükünü [batch] verilmişse batch'e ekler (eşzamanlı; çağıran
  /// `commitBatch` gövdesinde beklemeden kullanabilir), verilmemişse hemen
  /// yazar.
  Future<FirestoreResult<void>> _write(
    DocumentReference<Json> ref,
    Json payload,
    WriteBatch? batch,
  ) {
    if (batch == null) return _guard(() => ref.update(payload));
    try {
      batch.update(ref, payload);
      return Future.value(const FirebaseSuccess(null));
    } on Object catch (error) {
      return _rejected(error, batch);
    }
  }

  /// Reddedilen soft delete / geri alma yazımının sonucu. [batch] bu servisin
  /// `commitBatch` batch'iyse onu geçersiz kılar: dönen sonuç gövdede
  /// beklenemediği için hata commit'te yeniden yükseltilir ve batch'in geri
  /// kalanı (ör. aynı işlemin sayaç yazımı) uygulanmaz.
  static Future<FirestoreResult<void>> _rejected(
    Object error,
    WriteBatch? batch,
  ) {
    if (batch is _GuardedWriteBatch) batch.poison ??= error;
    return Future.value(_failure(error));
  }

  /// [action] çağrısını zaman aşımıyla sarar ve her hatayı [FirebaseFailure]'a
  /// çevirir (PLAN §10.1).
  Future<FirestoreResult<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return FirebaseSuccess(await action().timeout(_timeout));
    } on Object catch (error) {
      return _failure(error);
    }
  }

  /// [source] akışının olaylarını sonuca sarar; hata olayları akışı
  /// kapatmadan [FirebaseFailure] olarak iletilir.
  Stream<FirestoreResult<T>> _results<T>(Stream<T> source) => source.transform(
    StreamTransformer<T, FirestoreResult<T>>.fromHandlers(
      handleData: (data, sink) => sink.add(FirebaseSuccess(data)),
      handleError: (error, _, sink) => sink.add(_failure(error)),
    ),
  );

  static Future<FirestoreResult<T>> _invalidArgument<T>(String message) =>
      Future.value(
        FirebaseFailure(FirestoreError.invalidArgument, message: message),
      );

  static FirestoreResult<T> _failure<T>(Object error) => switch (error) {
    ConflictException() => FirebaseFailure(
      error.error,
      message: error.toString(),
      detail: error.detail,
    ),
    TimeoutException() => FirebaseFailure(
      FirestoreError.timeout,
      message: error.message,
    ),
    FirebaseException() => FirebaseFailure(
      FirestoreError.fromCode(error.code),
      message: error.message,
    ),
    _ => FirebaseFailure(FirestoreError.unknown, message: error.toString()),
  };

  static List<FirestoreDoc> _docsOf(QuerySnapshot<Json> snapshot) => [
    for (final doc in snapshot.docs) ?FirestoreDoc.fromSnapshot(doc),
  ];

  /// Servisin kendi ürettiği `invalid-argument` hatası.
  static FirebaseException _invalid(String message) => FirebaseException(
    plugin: 'cloud_firestore',
    code: 'invalid-argument',
    message: message,
  );
}

/// Silme çağrısının reddedildiğini bildiren hata iletisi.
String _unsupported(String type, Invocation invocation) =>
    '$type.${invocation.memberName} bu serviste kullanılamaz: belge silme '
    'yoktur (D-10) ve commit işlemini servis yapar.';

/// `commitBatch` gövdesine verilen batch: yazımları sayar, `set` ve `update`
/// dışındaki her çağrıyı (silme, commit) reddeder ve servis üzerinden eklenen
/// yazımların hatasını [poison] ile commit'e taşır.
final class _GuardedWriteBatch implements WriteBatch {
  _GuardedWriteBatch(this._inner);

  final WriteBatch _inner;

  /// Batch'e eklenen yazım sayısı.
  int writeCount = 0;

  /// Batch'e eklenemeyen ilk soft delete / geri alma yazımının hatası. Doluysa
  /// batch commit edilmez (`commitBatch` bu hatayı döndürür).
  Object? poison;

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    writeCount++;
    _inner.set(document, data, options);
  }

  @override
  void update<T>(DocumentReference<T> document, T data) {
    writeCount++;
    _inner.update(document, data);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError(_unsupported('WriteBatch', invocation));
}

/// `runTransaction` gövdesine verilen transaction: okuma, `set` ve `update`
/// çağrılarını iletir, silmeyi reddeder.
final class _GuardedTransaction implements Transaction {
  _GuardedTransaction(this._inner);

  final Transaction _inner;

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> documentReference,
  ) => _inner.get(documentReference);

  @override
  Transaction set<T>(
    DocumentReference<T> documentReference,
    T data, [
    SetOptions? options,
  ]) {
    _inner.set(documentReference, data, options);
    return this;
  }

  @override
  Transaction update(
    DocumentReference<Object?> documentReference,
    Map<Object, Object?> data,
  ) {
    _inner.update(documentReference, data);
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError(_unsupported('Transaction', invocation));
}
