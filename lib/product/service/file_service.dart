import 'dart:io';
import 'dart:typed_data';

import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:path_provider/path_provider.dart';

/// Geçici dosya yazma servisi (CD-08, T-23): SHT-14 "Cihaz takvimi" `.ics`
/// dosyası (`IcsBuilder.build` → [writeTemp] → `ShareService.shareFile`).
///
/// View ve ViewModel `path_provider` / `dart:io` dosya API'sini doğrudan
/// çağırmaz; tek giriş bu arayüzdür (`ProjectDependencyMixin.fileService`).
/// Tek metotlu arayüz bilinçlidir: testte `FakeFileService` ile değiştirilir.
// ignore: one_member_abstracts
abstract interface class FileService {
  /// [bytes] içeriğini uygulamanın geçici dizinine [fileName] adıyla yazar
  /// (varsa üzerine yazar) ve tam yolunu döndürür. Yazılamadıysa `null`;
  /// hiçbir zaman fırlatmaz.
  Future<String?> writeTemp(String fileName, Uint8List bytes);
}

/// [FileService]'in geçici dizin çağrısı (`getTemporaryDirectory` imzası).
typedef TempDirectoryCall = Future<Directory> Function();

/// [FileService] uygulaması: `path_provider` geçici dizini + `dart:io`.
final class DeviceFileService implements FileService {
  /// `tempDirectory` yalnızca testte verilir.
  const DeviceFileService({this._tempDirectory = getTemporaryDirectory});

  final TempDirectoryCall _tempDirectory;

  @override
  Future<String?> writeTemp(String fileName, Uint8List bytes) async {
    try {
      final directory = await _tempDirectory();
      final file = File('${directory.path}${Platform.pathSeparator}$fileName');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } on Object catch (error, stack) {
      AppLogger.warn(
        'Geçici dosya yazılamadı',
        error: error,
        stackTrace: stack,
      );
      return null;
    }
  }
}
