import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:gu_kulupler/product/media/constants/media_constants.dart';

/// Piksel sayısı sınırı aşan kaynak görsel **çözülmeden** reddedildi
/// ([BoundedImage]). `Image.errorBuilder` yer tutucuyu gösterir.
final class ImageTooLargeException implements Exception {
  /// [width] × [height] piksellik kaynak görselin reddi.
  const ImageTooLargeException(this.width, this.height);

  /// Kaynak görselin başlığındaki genişlik (piksel).
  final int width;

  /// Kaynak görselin başlığındaki yükseklik (piksel).
  final int height;

  @override
  String toString() => 'ImageTooLargeException: $width × $height piksel';
}

/// Uzaktan gelen (güvenilmeyen) görselin belleğe çözülmesini sınırlar.
///
/// Storage Rules yalnızca dosya boyutunu (< 5 MB) ve **beyan edilen** içerik
/// türünü görür; piksel boyutunu göremez. Değiştirilmiş istemciyle yükleme
/// yapan bir yönetici, birkaç MB'lık ama on binlerce piksel kenarlı bir PNG /
/// WebP'yi gönderiye iliştirebilir: sınırsız çözüm (`genişlik × yükseklik × 4`
/// bayt) akışı açan her üyenin uygulamasını bellekten düşürür ve dosya
/// silinemez (D-10). Uygulamanın kendi yüklediği görseller yeniden kodlanır
/// (uzun kenar ≤ `DeviceImagePickerService.maxEdgePx`) ve iki sınırın da
/// altındadır.
///
/// * **Ret:** görselin başlığındaki piksel sayısı [maxSourcePixels] değerini
///   aşıyorsa görsel hiç çözülmez; yükleme [ImageTooLargeException] ile düşer.
///   Başlık çözümden önce okunur (`ImageDescriptor`), bellek ayrılmaz.
/// * **Küçültme:** kabul edilen görsel, uzun kenarı en çok [maxEdge] olacak
///   biçimde (oran korunarak, büyütmeden) çözülür ve önbelleğe öyle girer
///   (`ResizeImage` — `ResizeImagePolicy.fit`).
///
/// Eşitlik sarılan sağlayıcıya ve sınırlara bakar: her çizimde yeniden
/// kurulan çözücü görseli yeniden yüklemez. Görsel önbelleği anahtarı
/// (`ResizeImageKey`) [maxSourcePixels] değerini taşımaz: aynı görsel için
/// tek bir sınır kullanılır (uygulamada varsayılan).
class BoundedImage extends ResizeImage {
  /// [imageProvider] görselinin sınırlı çözümü.
  const BoundedImage(
    super.imageProvider, {
    this.maxSourcePixels = MediaConstants.imageSourceMaxPixels,
    this.maxEdge = MediaConstants.imageDecodeMaxEdgePx,
  }) : super(width: maxEdge, height: maxEdge, policy: ResizeImagePolicy.fit);

  /// Çözülmesine izin verilen kaynak görselin en çok piksel sayısı
  /// (genişlik × yükseklik).
  final int maxSourcePixels;

  /// Çözülen görselin uzun kenarının üst sınırı (piksel).
  final int maxEdge;

  @override
  ImageStreamCompleter loadImage(
    ResizeImageKey key,
    ImageDecoderCallback decode,
  ) {
    // `ResizeImage` hedef boyutu `getTargetSize` ile verir; geri çağrı
    // görselin başlığı okunduktan sonra, çözümden ÖNCE çalışır — sınır orada
    // denetlenir.
    return super.loadImage(key, (buffer, {getTargetSize}) {
      return decode(
        buffer,
        getTargetSize: (intrinsicWidth, intrinsicHeight) {
          if (intrinsicWidth * intrinsicHeight > maxSourcePixels) {
            throw ImageTooLargeException(intrinsicWidth, intrinsicHeight);
          }
          return getTargetSize?.call(intrinsicWidth, intrinsicHeight) ??
              const ui.TargetImageSize();
        },
      );
    });
  }

  @override
  bool operator ==(Object other) =>
      other is BoundedImage &&
      other.imageProvider == imageProvider &&
      other.maxSourcePixels == maxSourcePixels &&
      other.maxEdge == maxEdge;

  @override
  int get hashCode => Object.hash(imageProvider, maxSourcePixels, maxEdge);
}
