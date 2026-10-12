// El yazımı `StorageService` çifti (mock kütüphanesi yok — docs/testing.md
// §1.2): yüklemeleri bellekte kaydeder, isteğe göre hata döndürür. Repository
// testleri (yükleme + Firestore yol alanı yazımı) içindir; yükleme öncesi
// denetimler gerçek serviste sınanır (`storage_service_test.dart`).
import 'dart:math';
import 'dart:typed_data';

import 'package:gu_data/gu_data.dart';

/// Kaydedilen tek yükleme.
typedef RecordedUpload = ({
  String path,
  Uint8List bytes,
  String contentType,
  Map<String, String> customMetadata,
});

/// Yüklemeleri kaydeden depolama servisi.
final class RecordingStorageService implements StorageService {
  /// Yüklemeler, geliş sırasıyla (başarısız olanlar dahil).
  final List<RecordedUpload> uploads = [];

  /// Verilirse bir sonraki [upload] bu hatayla biter (tek seferlik).
  StorageError? nextError;

  /// Yükleme sürerken `onProgress` ile bildirilen oranlar.
  List<double> progress = const [0.5, 1];

  @override
  Future<StorageResult<String>> upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
    Map<String, String> customMetadata = const {},
    void Function(double fraction)? onProgress,
  }) async {
    uploads.add((
      path: path,
      bytes: bytes,
      contentType: contentType,
      customMetadata: customMetadata,
    ));
    final error = nextError;
    nextError = null;
    if (error != null) {
      return FirebaseFailure(error, message: 'storage/${error.name}');
    }
    progress.forEach(onProgress ?? (_) {});
    return FirebaseSuccess(path);
  }

  @override
  Future<StorageResult<String>> downloadUrl(String path) async =>
      const FirebaseFailure(StorageError.notFound);

  @override
  Future<StorageResult<StorageFileInfo>> metadata(String path) async =>
      const FirebaseFailure(StorageError.notFound);
}

/// Sırayla verilen baytları döndüren rastgele kaynak: dosya adının rastgele
/// kısmı testte sabitlenir (`StoragePaths.newFileName`).
final class SequenceRandom implements Random {
  /// [bytes] sırayla (bitince baştan) döner.
  SequenceRandom(this.bytes);

  /// Döndürülecek değerler (`0–255`).
  final List<int> bytes;

  int _index = 0;

  @override
  int nextInt(int max) => bytes[_index++ % bytes.length] % max;

  @override
  bool nextBool() => nextInt(2) == 1;

  @override
  double nextDouble() => nextInt(256) / 256;
}
