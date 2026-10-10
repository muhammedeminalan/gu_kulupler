// `StorageService` fake'i (PLAN §16.3): yüklemeleri bellekte tutar. Gerçek
// servisin yükleme öncesi denetimlerini (boş dosya, tür, boyut) aynen uygular;
// silme ve üzerine yazma yoktur (D-10).
//
//   final storage = FakeStorageService()..failNext(StorageError.unauthorized);
//   expect(storage.uploads.keys, [path]);
import 'dart:typed_data';

import 'package:gu_data/gu_data.dart';

import 'fake_base.dart';

final class FakeStorageService extends FakeBase implements StorageService {
  /// Yüklenen dosyalar: tam yol → baytlar.
  final Map<String, Uint8List> uploads = <String, Uint8List>{};

  /// Yüklenen dosyaların üst verisi: tam yol → bilgi.
  final Map<String, StorageFileInfo> infos = <String, StorageFileInfo>{};

  /// [downloadUrl] adreslerinin kökü.
  static const String downloadBase = 'https://storage.fake/';

  @override
  Future<StorageResult<String>> upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
    Map<String, String> customMetadata = const {},
    void Function(double fraction)? onProgress,
  }) async {
    record('upload', [path, bytes.length, contentType, customMetadata]);
    if (bytes.isEmpty) return const FirebaseFailure(StorageError.noFile);
    final extension = StoragePaths.extensionByContentType[contentType];
    if (extension == null || !path.endsWith('.$extension')) {
      return const FirebaseFailure(StorageError.invalidType);
    }
    if (bytes.length >= Limits.imageMaxBytes) {
      return const FirebaseFailure(StorageError.sizeLimit);
    }
    if (_failure() case final error?) return FirebaseFailure(error);
    if (uploads.containsKey(path)) {
      return const FirebaseFailure(StorageError.unauthorized);
    }
    uploads[path] = bytes;
    infos[path] = StorageFileInfo(
      path: path,
      sizeBytes: bytes.length,
      contentType: contentType,
      customMetadata: customMetadata,
    );
    onProgress?.call(1);
    return FirebaseSuccess(path);
  }

  @override
  Future<StorageResult<String>> downloadUrl(String path) async {
    record('downloadUrl', [path]);
    if (_failure() case final error?) return FirebaseFailure(error);
    if (!uploads.containsKey(path)) {
      return const FirebaseFailure(StorageError.notFound);
    }
    return FirebaseSuccess('$downloadBase$path');
  }

  @override
  Future<StorageResult<StorageFileInfo>> metadata(String path) async {
    record('metadata', [path]);
    if (_failure() case final error?) return FirebaseFailure(error);
    return switch (infos[path]) {
      final StorageFileInfo info => FirebaseSuccess(info),
      null => const FirebaseFailure(StorageError.notFound),
    };
  }

  StorageError? _failure() => switch (takeFailure()) {
    null => null,
    final StorageError error => error,
    _ => StorageError.unknown,
  };
}
