import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:gu_data/src/constants/limits.dart';
import 'package:gu_data/src/constants/storage_paths.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/storage_error.dart';

/// Bir Storage nesnesinin üst verisi (PLAN §10.2).
final class StorageFileInfo extends Equatable {
  /// Üst veriyi oluşturur.
  const StorageFileInfo({
    required this.path,
    required this.sizeBytes,
    required this.contentType,
    this.customMetadata = const {},
  });

  /// Nesnenin tam yolu (`users/u1/20261008T201501Z_3f9a1c2b7d4e5f60.jpg`).
  final String path;

  /// Boyut, bayt.
  final int sizeBytes;

  /// İçerik türü (`image/jpeg`); sunucu bildirmediyse `null`.
  final String? contentType;

  /// Yüklemede verilen özel üst veri (ör. gönderi görselinde `clubId`).
  final Map<String, String> customMetadata;

  @override
  List<Object?> get props => [path, sizeBytes, contentType, customMetadata];
}

/// Dosya depolama (Firebase Storage) kapısı (PLAN §10.2, D-34).
///
/// Yalnızca repository uygulamaları çağırır. Sonuç döndüren her metot istisna
/// fırlatmaz; hata [StorageError.fromCode] ile [FirebaseFailure]'a çevrilir.
///
/// **Dosya silme ve üzerine yazma yoktur (D-10).** Değiştirme = yeni adla
/// yükleme (`StoragePaths.newFileName`) + Firestore yol alanını güncelleme;
/// eski dosya yerinde kalır. Storage Rules da her yolda güncellemeyi ve
/// silmeyi reddeder.
abstract interface class StorageService {
  /// [bytes] görselini [path] yoluna yükler ve nesnenin tam yolunu döndürür.
  ///
  /// [path] yalnızca `StoragePaths` üreticilerinden gelir. Yükleme öncesi
  /// denetimler ağ çağrısı yapmadan döner: boş [bytes] →
  /// [StorageError.noFile]; [contentType] `image/jpeg`, `image/png`,
  /// `image/webp` dışında ya da [path] uzantısıyla uyuşmuyor →
  /// [StorageError.invalidType]; boyut [Limits.imageMaxBytes] sınırında ya da
  /// üstünde → [StorageError.sizeLimit].
  ///
  /// [customMetadata] nesneye yazılır (gönderi görselinde `{'clubId': …}`
  /// zorunludur — CD-39). [onProgress] yükleme sürerken `0.0–1.0` arası oranla
  /// çağrılır. [Limits.storageUploadTimeout] içinde bitmeyen yükleme iptal
  /// edilir ve [StorageError.timeout] döner.
  Future<StorageResult<String>> upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
    Map<String, String> customMetadata = const {},
    void Function(double fraction)? onProgress,
  });

  /// [path] nesnesinin indirme adresi (görsel önbelleği için).
  Future<StorageResult<String>> downloadUrl(String path);

  /// [path] nesnesinin üst verisi (boyut, içerik türü, özel üst veri).
  Future<StorageResult<StorageFileInfo>> metadata(String path);
}

/// [StorageService] uygulaması: `firebase_storage` SDK'sını sarar.
final class FirebaseStorageService implements StorageService {
  /// Verilen `FirebaseStorage` örneğini sarar. Yükleme `uploadTimeout`
  /// (varsayılan [Limits.storageUploadTimeout]), kısa çağrılar
  /// ([downloadUrl], [metadata]) `requestTimeout` (varsayılan
  /// [Limits.firestoreTimeout]) içinde dönmezse [StorageError.timeout] ile
  /// sonuçlanır.
  FirebaseStorageService(
    this._storage, {
    this._uploadTimeout = Limits.storageUploadTimeout,
    this._requestTimeout = Limits.firestoreTimeout,
  });

  final FirebaseStorage _storage;
  final Duration _uploadTimeout;
  final Duration _requestTimeout;

  @override
  Future<StorageResult<String>> upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
    Map<String, String> customMetadata = const {},
    void Function(double fraction)? onProgress,
  }) async {
    final rejection = _precheck(path, bytes, contentType);
    if (rejection != null) return FirebaseFailure(rejection);

    UploadTask? task;
    StreamSubscription<TaskSnapshot>? progress;
    try {
      final started = task = _storage
          .ref(path)
          .putData(
            bytes,
            SettableMetadata(
              contentType: contentType,
              customMetadata: customMetadata.isEmpty ? null : customMetadata,
            ),
          );
      if (onProgress != null) {
        progress = started.snapshotEvents.listen(
          (snapshot) {
            final total = snapshot.totalBytes;
            if (total > 0) onProgress(snapshot.bytesTransferred / total);
          },
          // Yükleme hatası görevin kendisinden (aşağıdaki await) okunur.
          onError: (Object _) {},
        );
      }
      final snapshot = await started.timeout(_uploadTimeout);
      return FirebaseSuccess(snapshot.ref.fullPath);
    } on TimeoutException catch (error) {
      // Süresi dolan yükleme arka planda sürmesin (iptal, dosya silme değil).
      unawaited(task?.cancel().then<void>((_) {}, onError: (Object _) {}));
      return FirebaseFailure(StorageError.timeout, message: error.message);
    } on Object catch (error) {
      return _failure(error);
    } finally {
      await progress?.cancel();
    }
  }

  @override
  Future<StorageResult<String>> downloadUrl(String path) =>
      _guard(() => _storage.ref(path).getDownloadURL());

  @override
  Future<StorageResult<StorageFileInfo>> metadata(String path) =>
      _guard(() async {
        final metadata = await _storage.ref(path).getMetadata();
        return StorageFileInfo(
          path: metadata.fullPath,
          sizeBytes: metadata.size ?? 0,
          contentType: metadata.contentType,
          customMetadata: metadata.customMetadata ?? const {},
        );
      });

  /// Yükleme öncesi istemci denetimi; sorun yoksa `null`.
  static StorageError? _precheck(
    String path,
    Uint8List bytes,
    String contentType,
  ) {
    if (bytes.isEmpty) return StorageError.noFile;
    final extension = StoragePaths.extensionByContentType[contentType];
    if (extension == null || !path.endsWith('.$extension')) {
      return StorageError.invalidType;
    }
    // Storage Rules `size < imageMaxBytes` ister: sınırın kendisi de reddedilir.
    if (bytes.length >= Limits.imageMaxBytes) return StorageError.sizeLimit;
    return null;
  }

  /// [action] çağrısını zaman aşımıyla sarar ve her hatayı [FirebaseFailure]'a
  /// çevirir (PLAN §10.1).
  Future<StorageResult<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return FirebaseSuccess(await action().timeout(_requestTimeout));
    } on Object catch (error) {
      return _failure(error);
    }
  }

  static StorageResult<T> _failure<T>(Object error) => switch (error) {
    TimeoutException() => FirebaseFailure(
      StorageError.timeout,
      message: error.message,
    ),
    FirebaseException() => FirebaseFailure(
      StorageError.fromCode(error.code),
      message: error.message,
    ),
    _ => FirebaseFailure(StorageError.unknown, message: error.toString()),
  };
}
