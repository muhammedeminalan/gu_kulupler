// `FileService` fake'i (PLAN §16.3, CD-08): diske yazmaz; yazılan
// dosyaları bellekte tutar.
//
//   final files = FakeFileService();
//   await viewModel.addToCalendar(CalendarChoice.device, ...);
//   expect(files.written.keys, [IcsBuilder.fileNameFor(event)]);
//   files.canWrite = false; // geçici dizine yazılamadı → null
import 'dart:typed_data';

import 'package:gu_kulupler/product/service/file_service.dart';

import 'fake_base.dart';

final class FakeFileService extends FakeBase implements FileService {
  /// Sahte geçici dizin.
  static const String tempDirectory = '/tmp/fake';

  /// Dosya adı → içerik (yazılamayanlar dahil değil).
  final Map<String, Uint8List> written = <String, Uint8List>{};

  /// Sonuç: `false` → yazılamadı (`null`).
  bool canWrite = true;

  /// Gerçek servis gibi fırlatmaz: bekleyen hata (`failNext`) `null`
  /// sonucuna çevrilir.
  @override
  Future<String?> writeTemp(String fileName, Uint8List bytes) async {
    record('writeTemp', [fileName, bytes.length]);
    if (takeFailure() != null || !canWrite) return null;
    written[fileName] = bytes;
    return '$tempDirectory/$fileName';
  }

  @override
  void resetFake() {
    super.resetFake();
    written.clear();
    canWrite = true;
  }
}
