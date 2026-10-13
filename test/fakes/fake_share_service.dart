// `ShareService` fake'i (PLAN §16.3, CD-08): paylaşım sayfası açmaz, panoya
// yazmaz; kaydeder.
//
//   final share = FakeShareService();
//   await viewModel.shareClub();
//   expect(share.sharedTexts, ['${AppConstants.shareBaseUrl}/clubs/c01']);
//   await viewModel.copyEmail();
//   expect(share.copied, ['kulup@gumushane.edu.tr']);
//   share.canShare = false; // platform paylaşım sayfasını açamadı
//   share.canCopy = false;  // pano yazılamadı
import 'dart:ui';

import 'package:gu_kulupler/product/service/share_service.dart';

import 'fake_base.dart';

/// Paylaşılması istenen dosya: yol ve içerik türü.
typedef FakeSharedFile = ({String path, String mimeType});

final class FakeShareService extends FakeBase implements ShareService {
  /// Paylaşılması istenen metinler, sırasıyla (açılamayanlar dahil).
  final List<String> sharedTexts = <String>[];

  /// [sharedTexts] ile aynı sırada konu satırları (verilmediyse `null`).
  final List<String?> subjects = <String?>[];

  /// Paylaşılması istenen dosyalar, sırasıyla (açılamayanlar dahil).
  final List<FakeSharedFile> sharedFiles = <FakeSharedFile>[];

  /// Panoya kopyalanması istenen metinler, sırasıyla (yazılamayanlar dahil).
  final List<String> copied = <String>[];

  /// Sonuç: `false` → platform paylaşım sayfasını açamadı.
  bool canShare = true;

  /// Sonuç: `false` → pano yazılamadı.
  bool canCopy = true;

  /// Panodaki son metin; hiç kopyalanmadıysa (ya da son kopyalama
  /// yazılamadıysa önceki değer) `null` olabilir.
  String? clipboard;

  @override
  Future<bool> copyText(String text) async {
    record('copyText', [text]);
    copied.add(text);
    final written = takeFailure() == null && canCopy;
    if (written) clipboard = text;
    return written;
  }

  /// Gerçek servis gibi hiçbir zaman fırlatmaz: bekleyen hata (`failNext`)
  /// `false` sonucuna çevrilir.
  @override
  Future<bool> shareText(String text, {String? subject, Rect? origin}) async {
    record('shareText', [text, subject]);
    sharedTexts.add(text);
    subjects.add(subject);
    return _result();
  }

  @override
  Future<bool> shareFile(
    String path, {
    required String mimeType,
    Rect? origin,
  }) async {
    record('shareFile', [path, mimeType]);
    sharedFiles.add((path: path, mimeType: mimeType));
    return _result();
  }

  bool _result() => takeFailure() == null && canShare;

  @override
  void resetFake() {
    super.resetFake();
    sharedTexts.clear();
    subjects.clear();
    sharedFiles.clear();
    copied.clear();
    canShare = true;
    canCopy = true;
    clipboard = null;
  }
}
