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
import 'package:gu_data/src/core/unexpected_error_listener.dart';
import 'package:gu_data/src/services/firestore_types.dart';
import 'package:gu_data/src/services/firestore_write_source.dart';

/// Firestore erişiminin tek kapısı (PLAN §10.2, D-34).
///
/// Yalnızca `firebase_<alan>_repository.dart` uygulamaları çağırır; ViewModel
/// bu servisi ve SDK tiplerini görmez. Sonuç döndüren her metot istisna
/// **fırlatmaz**: hata [FirebaseFailure] olarak döner
/// ([FirestoreError.fromCode]; okuma / transaction zaman aşımı →
/// [FirestoreError.timeout]). Transaction dışı yazımda (`add`, `set`,
/// `update`, `commitBatch`, batch'siz `softDelete` / `restore`) zaman aşımı
/// **başarıdır**: yazım SDK'nın yerel kuyruğundadır ve bağlantı dönünce
/// işlenir — hata sayılırsa yeniden deneme yazımı ikiler (T-44 · D2-01).
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

  /// [ref] belgesini **yalnızca yerel önbellekten** okur (ağa gidilmez):
  /// oturum çözümünün çevrimdışı düşüşü (Q-12, T-44 · D2-02). Belge
  /// önbellekte yoksa [FirestoreError.unavailable]; önbellekte "yok" olarak
  /// biliniyorsa başarı `null`. Genel okumalarda kullanılmaz: [getDoc]
  /// önbelleğe yalnızca sunucu süre aşımından sonra bir kez düşer (A4-05);
  /// bu metot ağı hiç beklemez (oturum çözümünün `unavailable` düşüşü).
  Future<FirestoreResult<FirestoreDoc?>> getDocFromCache(
    DocumentReference<Json> ref,
  );

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

  /// Yalnızca DebugMenu çevrimdışı simülasyonu (T-44 · A4-08): ağ çağrısı
  /// değil, SDK ağ anahtarı. `false` iken okumalar önbellekten gelir,
  /// yazımlar yerel kuyrukta bekler; `true` ağı yeniden açar.
  Future<FirestoreResult<void>> setNetworkEnabled({required bool enabled});
}

/// [FirestoreService] uygulaması: `cloud_firestore` SDK'sını sarar.
///
/// **Okuma zaman aşımında önbellek (Q-12, T-44 · A4-05):** sunucu `timeout`
/// içinde dönmezse (arayüz açık ama sunucuya ulaşılamıyor; SDK önbelleğe
/// ancak kendi 10 sn'lik çevrimiçi zaman aşımından sonra düşer) okuma bir
/// kez kalıcı önbellekten denenir. Önbellekte belge yoksa, liste boşsa ya da
/// sonraki sayfa isteniyorsa asıl hata ([FirestoreError.timeout]) döner —
/// boş önbellek "boş durum", eksik sayfa "liste sonu" sayılmaz.
///
/// Yazımlar [addWriteListener] ile duyurulur (bellek içi okuma önbelleğinin
/// eşzamanlı geçersiz kılınması — T-44 · D3-01).
final class FirebaseFirestoreService
    implements FirestoreService, FirestoreWriteSource {
  /// Verilen `FirebaseFirestore` örneğini sarar. Okuma ve transaction
  /// `timeout` (varsayılan [Limits.firestoreTimeout]) içinde dönmezse
  /// [FirestoreError.timeout] ile sonuçlanır; transaction dışı yazımda süre
  /// dolması başarıdır (yazım kuyrukta — sınıf açıklaması).
  ///
  /// `onUnexpected` beklenmeyen hatayı ([FirestoreError.isUnexpected])
  /// orijinal yığınıyla alır (Crashlytics `nonFatal` — T-44 · D2-03).
  FirebaseFirestoreService(
    this._firestore, {
    this._timeout = Limits.firestoreTimeout,
    this._onUnexpected,
  });

  final FirebaseFirestore _firestore;
  final Duration _timeout;
  final UnexpectedErrorListener? _onUnexpected;

  /// Transaction'ın SDK tarafındaki en çok deneme sayısı (PLAN §10.2).
  static const int transactionMaxAttempts = 3;

  /// Yalnızca yerel (kalıcı) önbellekten okuma.
  static const GetOptions _fromCache = GetOptions(source: Source.cache);

  final List<FirestoreWriteListener> _writeListeners = [];

  @override
  void addWriteListener(FirestoreWriteListener listener) =>
      _writeListeners.add(listener);

  /// [paths] yazımlarını dinleyicilere duyurur; dinleyici hatası yutulur.
  void _announce(Iterable<String> paths) {
    for (final path in paths) {
      for (final listener in List.of(_writeListeners)) {
        try {
          listener(path);
        } on Object catch (_) {
          // Önbellek kancası yazımın sonucunu etkilemez.
        }
      }
    }
  }

  /// [write] yazımını duyurarak çalıştırır: yollar yazım başlarken (yerel
  /// önbellek yazımı hemen yansıtır) ve sunucu onayında (süre dolmuş olsa da)
  /// duyurulur.
  Future<void> Function() _announced(
    Iterable<String> paths,
    Future<void> Function() write,
  ) => () {
    _announce(paths);
    return write().then((_) => _announce(paths));
  };

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
      _guardRead(
        () async => FirestoreDoc.fromSnapshot(await ref.get()),
        // Önbellekte olmayan belge "yok" sayılmaz: `null` → asıl hata.
        () async => FirestoreDoc.fromSnapshot(await ref.get(_fromCache)),
      );

  @override
  Future<FirestoreResult<FirestoreDoc?>> getDocFromCache(
    DocumentReference<Json> ref,
  ) => _guard(
    () async => FirestoreDoc.fromSnapshot(
      await ref.get(const GetOptions(source: Source.cache)),
    ),
  );

  @override
  Future<FirestoreResult<List<FirestoreDoc>>> getList(Query<Json> query) =>
      _guardRead(() async => _docsOf(await query.get()), () async {
        // Boş önbellek "boş durum" değildir: `null` → asıl hata.
        final docs = _docsOf(await query.get(_fromCache));
        return docs.isEmpty ? null : docs;
      });

  @override
  Future<FirestoreResult<PageResult<FirestoreDoc>>> getPage(
    Query<Json> query,
    PageRequest page,
  ) {
    final after = page.after;
    PageResult<FirestoreDoc> pageOf(QuerySnapshot<Json> snapshot) {
      final docs = snapshot.docs;
      return PageResult(
        items: _docsOf(snapshot),
        next: docs.length == page.limit ? PageCursor(docs.last) : null,
      );
    }

    return _guardRead(
      () async {
        final start = after == null
            ? query
            : query.startAfterDocument(after.snapshot);
        return pageOf(await start.limit(page.limit).get());
      },
      // Yalnızca ilk sayfa: önbellekten eksik gelen sonraki sayfa yanlış bir
      // "liste sonu" üretirdi.
      after != null
          ? null
          : () async {
              final snapshot = await query.limit(page.limit).get(_fromCache);
              return snapshot.docs.isEmpty ? null : pageOf(snapshot);
            },
    );
  }

  @override
  Stream<FirestoreResult<FirestoreDoc?>> watchDoc(
    DocumentReference<Json> ref,
  ) => _results(
    ref.snapshots().map((snapshot) {
      // Önbellekte olmayan belge çevrimdışıyken `exists: false, fromCache:
      // true` gelir: "yok" değil, "bilinmiyor" (T-44 · A4-02; SDK `get()`
      // de unavailable verir). Akış kapanmaz; sunucu olayı başarı getirir.
      if (!snapshot.exists && snapshot.metadata.isFromCache) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
          message: 'çevrimdışı: belge önbellekte yok',
        );
      }
      return FirestoreDoc.fromSnapshot(snapshot);
    }),
  );

  @override
  Stream<FirestoreResult<List<FirestoreDoc>>> watchList(Query<Json> query) =>
      _results(query.snapshots().map(_docsOf));

  @override
  Future<FirestoreResult<String>> add(String collectionPath, Json data) async {
    // Kimlik yazımdan önce alınır: süre dolsa da (yazım kuyrukta) döner.
    final DocumentReference<Json> ref;
    try {
      ref = _firestore.collection(collectionPath).doc();
    } on Object catch (error, stack) {
      return _report(error, stack);
    }
    return _guardWrite(_announced([ref.path], () => ref.set(data)), ref.id);
  }

  @override
  Future<FirestoreResult<void>> set(
    DocumentReference<Json> ref,
    Json data, {
    bool merge = false,
  }) => _guardWrite(
    _announced(
      [ref.path],
      () => merge ? ref.set(data, SetOptions(merge: true)) : ref.set(data),
    ),
    null,
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
    return _guardWrite(
      _announced(
        [ref.path],
        () => ref.update({
          ...fields,
          if (touchUpdatedAt) ...BaseFieldsPayload.update(),
        }),
      ),
      null,
    );
  }

  @override
  Future<FirestoreResult<T>> runTransaction<T>(
    Future<T> Function(Transaction tx) body,
  ) async {
    // Gövdenin yazdığı yollar (yeniden denemelerde birikir; fazla duyuru
    // zararsızdır) yalnızca işlem başarıyla bitince duyurulur.
    final paths = <String>{};
    final result = await _guard(
      () => _firestore.runTransaction<T>(
        (tx) => body(_GuardedTransaction(tx, paths)),
        timeout: _timeout,
        maxAttempts: transactionMaxAttempts,
      ),
    );
    if (result.isSuccess) _announce(paths);
    return result;
  }

  @override
  Future<FirestoreResult<void>> commitBatch(
    void Function(WriteBatch batch) build,
  ) async {
    // Doğrulama eşzamanlıdır ve hatası hemen döner; yalnızca commit süre
    // sınırına girer (süre dolması başarıdır — `_guardWrite`). Tek zamanlayıcı:
    // dış bir `timeout` iç zamanlayıcıyla aynı anda dolup `timeout` döndürürdü.
    final WriteBatch inner;
    final int writeCount;
    final Set<String> paths;
    try {
      inner = _firestore.batch();
      final batch = _GuardedWriteBatch(inner);
      paths = batch.paths;
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
      writeCount = batch.writeCount;
      if (writeCount > Limits.batchMaxWrites) {
        throw _invalid(
          'commitBatch: $writeCount yazım, sınır ${Limits.batchMaxWrites}',
        );
      }
    } on Object catch (error, stack) {
      return _report(error, stack);
    }
    if (writeCount == 0) return const FirebaseSuccess(null);
    return _guardWrite(_announced(paths, inner.commit), null);
  }

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

  @override
  Future<FirestoreResult<void>> setNetworkEnabled({required bool enabled}) =>
      _guard(
        () =>
            enabled ? _firestore.enableNetwork() : _firestore.disableNetwork(),
      );

  /// [payload] yükünü [batch] verilmişse batch'e ekler (eşzamanlı; çağıran
  /// `commitBatch` gövdesinde beklemeden kullanabilir), verilmemişse hemen
  /// yazar.
  Future<FirestoreResult<void>> _write(
    DocumentReference<Json> ref,
    Json payload,
    WriteBatch? batch,
  ) {
    if (batch == null) {
      return _guardWrite(
        _announced([ref.path], () => ref.update(payload)),
        null,
      );
    }
    try {
      batch.update(ref, payload);
      return Future.value(const FirebaseSuccess(null));
    } on Object catch (error, stack) {
      return _rejected(error, batch, stack);
    }
  }

  /// Reddedilen soft delete / geri alma yazımının sonucu. [batch] bu servisin
  /// `commitBatch` batch'iyse onu geçersiz kılar: dönen sonuç gövdede
  /// beklenemediği için hata commit'te yeniden yükseltilir ve batch'in geri
  /// kalanı (ör. aynı işlemin sayaç yazımı) uygulanmaz.
  Future<FirestoreResult<void>> _rejected(
    Object error,
    WriteBatch? batch, [
    StackTrace? stack,
  ]) {
    if (batch is _GuardedWriteBatch) batch.poison ??= error;
    return Future.value(_report(error, stack ?? StackTrace.current));
  }

  /// Okuma / transaction: [action] çağrısını zaman aşımıyla sarar ve her
  /// hatayı [FirebaseFailure]'a çevirir (PLAN §10.1; süre dolması →
  /// [FirestoreError.timeout]).
  Future<FirestoreResult<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return FirebaseSuccess(await action().timeout(_timeout));
    } on Object catch (error, stack) {
      return _report(error, stack);
    }
  }

  /// Okuma: [server] okumasını zaman aşımıyla dener; **yalnızca** süre
  /// dolarsa [cache] okumasını bir kez (aynı süreyle) dener ve `null` olmayan
  /// sonucu başarı sayar (Q-12, T-44 · A4-05). Önbellek okuması başarısız ya
  /// da `null` ise asıl hata ([FirestoreError.timeout]) döner. Başka hatalar
  /// (unavailable, Rules …) için önbellek denenmez: SDK çevrimdışıyken
  /// varsayılan okuma zaten önbelleğe bakar.
  Future<FirestoreResult<T>> _guardRead<T>(
    Future<T> Function() server,
    Future<T?> Function()? cache,
  ) async {
    try {
      return FirebaseSuccess(await server().timeout(_timeout));
    } on TimeoutException catch (error, stack) {
      if (cache != null) {
        try {
          final cached = await cache().timeout(_timeout);
          if (cached != null) return FirebaseSuccess(cached);
        } on Object catch (_) {
          // Önbellekte yok ya da okunamadı: asıl hata döner.
        }
      }
      return _report(error, stack);
    } on Object catch (error, stack) {
      return _report(error, stack);
    }
  }

  /// Transaction dışı yazım: yerel SDK yazımı kuyruğa alır, gelecek yalnızca
  /// sunucu onayıyla tamamlanır. Süre dolarsa yazım kuyrukta kalır ve
  /// bağlantı dönünce işlenir; bu bir hata değildir (yeniden deneme yazımı
  /// ikilerdi — T-44 · D2-01). Gerçek SDK hataları (Rules, not-found …)
  /// süre içinde gelirse yine [FirebaseFailure] olur.
  Future<FirestoreResult<T>> _guardWrite<T>(
    Future<void> Function() write,
    T value,
  ) async {
    try {
      await write().timeout(_timeout, onTimeout: () {});
      return FirebaseSuccess(value);
    } on Object catch (error, stack) {
      return _report(error, stack);
    }
  }

  /// [error] hatasını sonuca çevirir; beklenmeyen hataysa
  /// ([FirestoreError.isUnexpected]) [_onUnexpected]'a orijinal yığınla
  /// bildirir (T-44 · D2-03). Dinleyicinin hatası yutulur.
  FirestoreResult<T> _report<T>(Object error, StackTrace stack) {
    final result = _failure<T>(error);
    if (result case FirebaseFailure(error: final code) when code.isUnexpected) {
      try {
        _onUnexpected?.call(error, stack, 'firestore:${code.name}');
      } on Object catch (_) {
        // Raporlama başarısız: sonucu etkilemez.
      }
    }
    return result;
  }

  /// [source] akışının olaylarını sonuca sarar; hata olayları akışı
  /// kapatmadan [FirebaseFailure] olarak iletilir.
  Stream<FirestoreResult<T>> _results<T>(Stream<T> source) => source.transform(
    StreamTransformer<T, FirestoreResult<T>>.fromHandlers(
      handleData: (data, sink) => sink.add(FirebaseSuccess(data)),
      handleError: (error, stack, sink) => sink.add(_report(error, stack)),
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

  /// Batch'e eklenen yazımların belge yolları (commit'te duyurulur).
  final Set<String> paths = {};

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    writeCount++;
    _inner.set(document, data, options);
    paths.add(document.path);
  }

  @override
  void update<T>(DocumentReference<T> document, T data) {
    writeCount++;
    _inner.update(document, data);
    paths.add(document.path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError(_unsupported('WriteBatch', invocation));
}

/// `runTransaction` gövdesine verilen transaction: okuma, `set` ve `update`
/// çağrılarını iletir, silmeyi reddeder.
final class _GuardedTransaction implements Transaction {
  _GuardedTransaction(this._inner, this._paths);

  final Transaction _inner;

  /// Gövdenin yazdığı belge yolları (işlem başarısında duyurulur).
  final Set<String> _paths;

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
    _paths.add(documentReference.path);
    return this;
  }

  @override
  Transaction update(
    DocumentReference<Object?> documentReference,
    Map<Object, Object?> data,
  ) {
    _inner.update(documentReference, data);
    _paths.add(documentReference.path);
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError(_unsupported('Transaction', invocation));
}
