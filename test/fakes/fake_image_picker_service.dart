// `ImagePickerService` fake'i (PLAN §16.3, CD-08): seçici açmaz, verilen
// görseli döndürür.
//
//   final picker = FakeImagePickerService()..nextPick = kFakeJpeg;
//   await viewModel.pickAvatar(MediaSource.gallery);
//   expect(picker.picks, [MediaSource.gallery]);
//
//   picker.nextPick = null;                       // kullanıcı vazgeçti
//   picker.permissionDenied = true;               // erişim reddedildi
//   picker.nextError = ImagePickError.tooLarge;   // tek seferlik hata
//
// Gerçek servis gibi: sonuç her zaman yüklenebilir bir görseldir — verilen
// görsel `maxBytes` sınırında ya da üstündeyse `tooLarge` döner.
import 'dart:typed_data';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';

import 'fake_base.dart';

/// En küçük JPEG imzalı örnek görsel (`image/jpeg`).
final PickedImage kFakeJpeg = PickedImage(
  bytes: Uint8List.fromList(const [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]),
  contentType: 'image/jpeg',
);

final class FakeImagePickerService extends FakeBase
    implements ImagePickerService {
  /// Bir sonraki [pick] sonucu; `null` → kullanıcı vazgeçti. Kalıcıdır (her
  /// seçim aynı görseli verir); varsayılan [kFakeJpeg].
  PickedImage? nextPick = kFakeJpeg;

  /// `true` → [pick] erişim reddiyle biter (`ImagePickError.permissionDenied`).
  bool permissionDenied = false;

  /// Verilirse bir sonraki [pick] bu hatayla biter (tek seferlik).
  ImagePickError? nextError;

  /// İstenen kaynaklar, sırasıyla.
  final List<MediaSource> picks = <MediaSource>[];

  /// Bekleyen hata (`failNext`) platform hatası sayılır
  /// (`ImagePickError.failed`); gerçek servis gibi hiçbir zaman fırlatmaz.
  @override
  Future<ImagePickResult> pick(
    MediaSource source, {
    int maxBytes = Limits.imageMaxBytes,
  }) async {
    record('pick', [source, maxBytes]);
    picks.add(source);
    if (takeFailure() != null) {
      return const ImagePickFailure(ImagePickError.failed);
    }
    if (permissionDenied) {
      return const ImagePickFailure(ImagePickError.permissionDenied);
    }
    final error = nextError;
    nextError = null;
    if (error != null) return ImagePickFailure(error);
    final image = nextPick;
    if (image == null) return const ImagePickCancelled();
    if (image.bytes.length >= maxBytes) {
      return const ImagePickFailure(ImagePickError.tooLarge);
    }
    return ImagePickSuccess(image);
  }

  @override
  void resetFake() {
    super.resetFake();
    nextPick = kFakeJpeg;
    permissionDenied = false;
    nextError = null;
    picks.clear();
  }
}
