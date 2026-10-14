import 'dart:typed_data';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:image_picker/image_picker.dart';

/// Görselin alınacağı kaynak (SHT-16 "Fotoğraf kaynağı" satırları).
enum MediaSource {
  /// Cihaz kamerası (`SHT-16.camera`; kamera izni ister — DLG-04).
  camera,

  /// Sistem fotoğraf seçicisi (`SHT-16.gallery`; izin istemez — CD-16).
  gallery,
}

/// Seçilen ve yüklemeye hazırlanan görsel.
///
/// Eşitlik kimlikledir (her seçim yeni örnektir): State `props`'una
/// girdiğinde megabaytlarca bayt karşılaştırılmaz.
final class PickedImage {
  /// [bytes] baytları, [contentType] türü ve [width] × [height] piksel
  /// boyutuyla.
  const PickedImage({
    required this.bytes,
    required this.contentType,
    required this.width,
    required this.height,
  });

  /// Görselin baytları (önizleme `Image.memory`, yükleme
  /// `UserRepository.updateAvatar(bytes:)`).
  final Uint8List bytes;

  /// İçerik türü (`StoragePaths.extensionByContentType` anahtarı).
  /// `DeviceImagePickerService` her zaman `image/jpeg` üretir.
  final String contentType;

  /// Yeniden kodlanmış görselin genişliği, piksel (gönderi görselinde
  /// `PostImageUpload.width` → `PostImageModel.w`; T-21).
  final int width;

  /// Yeniden kodlanmış görselin yüksekliği, piksel.
  final int height;

  @override
  String toString() => 'PickedImage($contentType, ${bytes.length} bayt)';
}

/// Görsel seçilemedi: neden.
enum ImagePickError {
  /// Kamera (ya da eski cihazda fotoğraf) erişimi reddedildi (TST-32).
  permissionDenied,

  /// Seçilen dosya okunamadı ya da boş.
  unreadable,

  /// Dosya JPEG / PNG / WebP değil ve JPEG'e dönüştürülemedi.
  invalidType,

  /// Sıkıştırma sonrasında bile boyut sınırında ya da üstünde.
  tooLarge,

  /// Platform hatası: seçici açılamadı ya da izinli türdeki görsel yeniden
  /// kodlanamadı (özgün dosya yüklenmez — bkz. `DeviceImagePickerService`).
  failed,
}

/// [ImagePickerService.pick] sonucu.
sealed class ImagePickResult {
  const ImagePickResult();

  /// Seçilen görsel; iptal ya da hata durumunda `null`.
  PickedImage? get imageOrNull => switch (this) {
    ImagePickSuccess(:final image) => image,
    ImagePickCancelled() || ImagePickFailure() => null,
  };
}

/// Görsel seçildi ve yüklemeye hazır.
final class ImagePickSuccess extends ImagePickResult {
  /// [image] ile.
  const ImagePickSuccess(this.image);

  /// Yüklemeye hazır görsel.
  final PickedImage image;
}

/// Kullanıcı seçiciyi kapattı (ya da izin ön açıklamasında vazgeçti); hata
/// değildir, hiçbir şey gösterilmez.
final class ImagePickCancelled extends ImagePickResult {
  /// İptal sonucu.
  const ImagePickCancelled();
}

/// Görsel seçilemedi.
final class ImagePickFailure extends ImagePickResult {
  /// [error] nedeniyle.
  const ImagePickFailure(this.error);

  /// Hata türü.
  final ImagePickError error;
}

/// Kamera ya da galeriden **tek** görsel seçer ve yüklemeye hazırlar (CD-08;
/// Q-19): SHT-16 → AUT-05, PRF-02, SET-05, MGT-09.
///
/// Sonuç her zaman yüklenebilir bir görseldir: türü
/// `StoragePaths.extensionByContentType` içindedir, boş değildir ve boyutu
/// `maxBytes` sınırının altındadır (Storage Rules `imageOk()` ile aynı
/// koşullar). İzin
/// ön açıklamaları (DLG-04, DLG-05) bu servisin işi değildir:
/// `PermissionPromptMixin.pickImage` önce onları gösterir.
// Tek üyeli arayüz bilerek sınıftır: GetIt'e kaydedilir ve testte fake ile
// değiştirilir (CD-08).
// ignore: one_member_abstracts
abstract interface class ImagePickerService {
  /// [source] kaynağından bir görsel seçtirir. Hiçbir zaman fırlatmaz.
  ///
  /// Kullanıcı vazgeçerse [ImagePickCancelled]; erişim reddedilirse
  /// [ImagePickError.permissionDenied]; görsel `maxBytes` sınırında ya da
  /// üstündeyse [ImagePickError.tooLarge].
  Future<ImagePickResult> pick(
    MediaSource source, {
    int maxBytes = Limits.imageMaxBytes,
  });
}

/// [DeviceImagePickerService]'in seçici çağrısı: seçilen dosya ya da `null`
/// (kullanıcı vazgeçti).
typedef ImageFilePick = Future<XFile?> Function(ImageSource source);

/// [DeviceImagePickerService]'in sıkıştırma çağrısı: JPEG baytları.
typedef ImageCompress = Future<Uint8List> Function(Uint8List bytes);

/// [ImagePickerService] uygulaması: `image_picker` + `flutter_image_compress`.
///
/// * Seçici görseli uzun kenarı [maxEdgePx] olacak biçimde küçültür; ardından
///   görsel [jpegQuality] kalitesinde **JPEG**'e çevrilir (PLAN §11.5).
/// * **Özgün dosya hiçbir zaman yüklenmez (kapalı başarısızlık).** Kamera /
///   galeri dosyasının EXIF üst verisini (konum, cihaz, çekim zamanı) ayıklayan
///   tek adım yeniden kodlamadır (`flutter_image_compress`, `keepExif`
///   varsayılanı `false`); avatar ise doğrulanmış her kullanıcıya açıktır
///   (rules-spec §9.1). Yeniden kodlama hata verirse ya da çıktısı JPEG
///   değilse seçim hatayla biter: özgün dosya tanınan türdeyse
///   [ImagePickError.failed], değilse [ImagePickError.invalidType].
/// * Galeri sistem seçicisidir (Android Photo Picker / iOS PHPicker) ve
///   fotoğraf izni **istemez**: `requestFullMetadata: false` (CD-16).
/// * Piksel boyutu ([PickedImage.width] / `height`) yeniden kodlanmış JPEG'in
///   çerçeve başlığından okunur ([jpegSizeOf]; T-21: `PostImageModel.w / h`).
final class DeviceImagePickerService implements ImagePickerService {
  /// Platform çağrıları yalnızca testte verilir.
  const DeviceImagePickerService({
    this._pickFile = _pickWithPlugin,
    this._compress = _compressToJpeg,
  });

  /// Yüklenen görselin uzun kenarının üst sınırı, piksel.
  static const int maxEdgePx = 1600;

  /// JPEG kalitesi (`0–100`).
  static const int jpegQuality = 82;

  final ImageFilePick _pickFile;
  final ImageCompress _compress;

  @override
  Future<ImagePickResult> pick(
    MediaSource source, {
    int maxBytes = Limits.imageMaxBytes,
  }) async {
    final XFile? file;
    try {
      file = await _pickFile(switch (source) {
        MediaSource.camera => ImageSource.camera,
        MediaSource.gallery => ImageSource.gallery,
      });
    } on PlatformException catch (error, stack) {
      if (_accessDeniedCodes.contains(error.code)) {
        return const ImagePickFailure(ImagePickError.permissionDenied);
      }
      return _failed(error, stack);
    } on Object catch (error, stack) {
      return _failed(error, stack);
    }
    if (file == null) return const ImagePickCancelled();

    final Uint8List original;
    try {
      original = await file.readAsBytes();
    } on Object catch (error, stack) {
      AppLogger.warn(
        'Seçilen görsel okunamadı',
        error: error,
        stackTrace: stack,
      );
      return const ImagePickFailure(ImagePickError.unreadable);
    }
    if (original.isEmpty) {
      return const ImagePickFailure(ImagePickError.unreadable);
    }

    final bytes = await _toJpeg(original);
    if (bytes == null) {
      // Özgün baytlara dönülmez (EXIF sızıntısı): seçim hatayla biter.
      return ImagePickFailure(
        contentTypeOf(original) == null
            ? ImagePickError.invalidType
            : ImagePickError.failed,
      );
    }
    // Storage Rules `size < imageMaxBytes` ister: sınırın kendisi de reddedilir.
    if (bytes.length >= maxBytes) {
      return const ImagePickFailure(ImagePickError.tooLarge);
    }
    // Boyut yeniden kodlanmış baytlardan okunur (yön düzeltmesi uygulanmış,
    // EXIF ayıklanmış çıktı). Okunamazsa 0 × 0: avatar akışı boyut kullanmaz;
    // gönderi görseli yüklemesi (`PostRepository.uploadImages`) boyutsuz
    // görseli ön denetimde reddeder.
    final size = jpegSizeOf(bytes);
    return ImagePickSuccess(
      PickedImage(
        bytes: bytes,
        contentType: _jpegContentType,
        width: size?.width ?? 0,
        height: size?.height ?? 0,
      ),
    );
  }

  /// [bytes] JPEG görselinin piksel boyutu — çerçeve başlığından (SOF)
  /// okunur, görsel çözülmez. JPEG değilse, başlık bulunamazsa (kesik dosya)
  /// ya da boyut sıfırsa `null`. Hiçbir zaman fırlatmaz.
  static ({int width, int height})? jpegSizeOf(Uint8List bytes) {
    if (!_startsWith(bytes, _jpegMagic)) return null;
    var offset = _markerSize;
    while (offset + _segmentHeaderSize <= bytes.length) {
      if (bytes[offset] != _markerPrefix) return null;
      final marker = bytes[offset + 1];
      if (marker == _markerPrefix) {
        // Dolgu baytı: işaretçi bir sonraki bayttadır.
        offset++;
        continue;
      }
      if (_standaloneMarkers.contains(marker)) {
        offset += _markerSize;
        continue;
      }
      // Tarama verisi (SOS) ya da dosya sonu (EOI): çerçeve başlığı yok.
      if (marker == _sosMarker || marker == _eoiMarker) return null;
      final length = _uint16(bytes, offset + _markerSize);
      if (length < _lengthFieldSize) return null;
      if (_isFrameHeader(marker)) {
        // SOF: uzunluk (2) · örnek derinliği (1) · yükseklik (2) · genişlik (2).
        final heightAt = offset + _segmentHeaderSize + 1;
        final widthAt = heightAt + _lengthFieldSize;
        if (widthAt + _lengthFieldSize > bytes.length) return null;
        final height = _uint16(bytes, heightAt);
        final width = _uint16(bytes, widthAt);
        return width > 0 && height > 0 ? (width: width, height: height) : null;
      }
      offset += _markerSize + length;
    }
    return null;
  }

  /// SOF0 – SOF15; aralıktaki üç işaretçi çerçeve başlığı değildir (DHT, JPG,
  /// DAC).
  static bool _isFrameHeader(int marker) =>
      marker >= _sofFirst &&
      marker <= _sofLast &&
      !_nonFrameMarkers.contains(marker);

  static int _uint16(Uint8List bytes, int offset) =>
      (bytes[offset] << _byteBits) | bytes[offset + 1];

  /// [bytes] içeriğinin türü (dosya imzasından): `image/jpeg`, `image/png`,
  /// `image/webp`; başka her içerik için `null`. Dosya adına ve seçicinin
  /// bildirdiği türe güvenilmez.
  static String? contentTypeOf(Uint8List bytes) {
    if (_startsWith(bytes, _jpegMagic)) return _jpegContentType;
    if (_startsWith(bytes, _pngMagic)) return 'image/png';
    if (_startsWith(bytes, _riffMagic) &&
        _startsWith(bytes, _webpMagic, offset: _webpOffset)) {
      return 'image/webp';
    }
    return null;
  }

  /// Yeniden kodlanmış (EXIF'i ayıklanmış) JPEG; yeniden kodlama başarısızsa
  /// ya da çıktı JPEG değilse `null`. Özgün baytlar **döndürülmez**.
  Future<Uint8List?> _toJpeg(Uint8List original) async {
    try {
      final compressed = await _compress(original);
      if (contentTypeOf(compressed) == _jpegContentType) return compressed;
      AppLogger.warn("Görsel JPEG'e çevrilemedi; seçim reddedildi");
    } on Object catch (error, stack) {
      AppLogger.warn(
        'Görsel yeniden kodlanamadı; seçim reddedildi',
        error: error,
        stackTrace: stack,
      );
    }
    return null;
  }

  static ImagePickResult _failed(Object error, StackTrace stack) {
    AppLogger.warn('Görsel seçici açılamadı', error: error, stackTrace: stack);
    return const ImagePickFailure(ImagePickError.failed);
  }

  static bool _startsWith(Uint8List bytes, List<int> magic, {int offset = 0}) {
    if (bytes.length < offset + magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[offset + i] != magic[i]) return false;
    }
    return true;
  }

  static Future<XFile?> _pickWithPlugin(ImageSource source) =>
      ImagePicker().pickImage(
        source: source,
        maxWidth: maxEdgePx.toDouble(),
        maxHeight: maxEdgePx.toDouble(),
        // CD-16: tam üst veri fotoğraf kitaplığı izni ister; istenmez.
        requestFullMetadata: false,
      );

  static Future<Uint8List> _compressToJpeg(Uint8List bytes) =>
      FlutterImageCompress.compressWithList(
        bytes,
        // Seçici görseli zaten `maxEdgePx` kutusuna sığdırdı: burada yalnızca
        // tür ve kalite değişir (kutu ölçek alt sınırıdır, büyütme yapmaz).
        // EXIF çıktıya taşınmaz: `keepExif` verilmez (varsayılanı `false`);
        // `true` yapılırsa konum üst verisi herkese açık avatara sızar.
        minWidth: maxEdgePx,
        minHeight: maxEdgePx,
        quality: jpegQuality,
      );

  /// `image_picker` erişim reddi kodları (iOS / Android).
  static const Set<String> _accessDeniedCodes = {
    'camera_access_denied',
    'camera_access_restricted',
    'photo_access_denied',
    'photo_access_restricted',
  };

  static const String _jpegContentType = 'image/jpeg';

  static const List<int> _jpegMagic = [0xFF, 0xD8, 0xFF];
  static const List<int> _pngMagic = [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  ];
  static const List<int> _riffMagic = [0x52, 0x49, 0x46, 0x46];
  static const List<int> _webpMagic = [0x57, 0x45, 0x42, 0x50];
  static const int _webpOffset = 8;

  // JPEG bölüt yapısı (ITU-T T.81 §B.1): `FF <işaretçi> <uzunluk: 2 bayt>`.
  static const int _markerPrefix = 0xFF;
  static const int _markerSize = 2;
  static const int _lengthFieldSize = 2;
  static const int _segmentHeaderSize = _markerSize + _lengthFieldSize;
  static const int _byteBits = 8;
  static const int _sofFirst = 0xC0;
  static const int _sofLast = 0xCF;
  static const Set<int> _nonFrameMarkers = {0xC4, 0xC8, 0xCC};
  static const int _sosMarker = 0xDA;
  static const int _eoiMarker = 0xD9;

  /// Uzunluk alanı taşımayan işaretçiler: TEM, RST0 – RST7, SOI.
  static const Set<int> _standaloneMarkers = {
    0x01, 0xD0, 0xD1, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, //
  };
}
