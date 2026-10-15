import 'dart:math' as math;
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
/// * **Gösterim boyutu (T-44):** [coverEdgePx] verilirse görsel ayrıca
///   kısa kenarı en az [coverEdgePx] piksel kalacak kadar küçültülür
///   (`BoxFit.cover` ile çizilen 40 dp avatar, 72 dp amblem, 48 dp etkinlik
///   kapağı 1600 piksel çözülmez). Kısa kenar hiçbir zaman [coverEdgePx]
///   altına inmez — kaplama görseli germez; büyütme yoktur.
///
/// Eşitlik sarılan sağlayıcıya ve sınırlara bakar: her çizimde yeniden
/// kurulan çözücü görseli yeniden yüklemez. Görsel önbelleği anahtarı
/// (`ResizeImageKey`) [maxSourcePixels] değerini taşımaz: aynı görsel için
/// tek bir sınır kullanılır (uygulamada varsayılan). Anahtarın kutusu
/// [coverEdgePx] (yoksa [maxEdge]) olduğundan her gösterim boyutu ayrı
/// önbellek kaydıdır.
class BoundedImage extends ResizeImage {
  /// [imageProvider] görselinin sınırlı çözümü.
  const BoundedImage(
    super.imageProvider, {
    this.maxSourcePixels = MediaConstants.imageSourceMaxPixels,
    this.maxEdge = MediaConstants.imageDecodeMaxEdgePx,
    this.coverEdgePx,
  }) : super(
         width: coverEdgePx ?? maxEdge,
         height: coverEdgePx ?? maxEdge,
         policy: ResizeImagePolicy.fit,
       );

  /// Çözülmesine izin verilen kaynak görselin en çok piksel sayısı
  /// (genişlik × yükseklik).
  final int maxSourcePixels;

  /// Çözülen görselin uzun kenarının üst sınırı (piksel).
  final int maxEdge;

  /// Görselin `BoxFit.cover` ile çizildiği kutunun kenarı (piksel; dp ×
  /// cihaz piksel oranı). `null` → yalnızca [maxEdge] sınırı.
  final int? coverEdgePx;

  /// [intrinsicWidth] × [intrinsicHeight] kaynağın [coverEdgePx] kutusunu
  /// kaplayan en küçük çözüm boyutu: uzun kenar ≤ [maxEdge], kısa kenar ≥
  /// [coverEdge] (kaynak daha küçükse olduğu gibi; büyütme yok).
  static ui.TargetImageSize coverTarget(
    int intrinsicWidth,
    int intrinsicHeight, {
    required int coverEdge,
    required int maxEdge,
  }) {
    final longEdge = math.max(intrinsicWidth, intrinsicHeight);
    final shortEdge = math.min(intrinsicWidth, intrinsicHeight);
    if (shortEdge <= 0) return const ui.TargetImageSize();
    // Ölçek = min(1, maxEdge / uzun, kutu / kısa); tam sayı tavan bölmesiyle
    // (kayan nokta artığı kenarı bir piksel büyütmez).
    int ceilDiv(int a, int b) => (a + b - 1) ~/ b;
    final int targetLong;
    final int targetShort;
    if (coverEdge * longEdge <= maxEdge * shortEdge) {
      // Kutu bağlar: kısa kenar = kutu.
      if (coverEdge >= shortEdge) return const ui.TargetImageSize();
      targetShort = coverEdge;
      targetLong = ceilDiv(longEdge * coverEdge, shortEdge);
    } else {
      // Uzun kenar sınırı bağlar.
      if (maxEdge >= longEdge) return const ui.TargetImageSize();
      targetLong = maxEdge;
      targetShort = ceilDiv(shortEdge * maxEdge, longEdge);
    }
    final landscape = intrinsicWidth >= intrinsicHeight;
    return ui.TargetImageSize(
      width: landscape ? targetLong : targetShort,
      height: landscape ? targetShort : targetLong,
    );
  }

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
          final coverEdge = coverEdgePx;
          if (coverEdge != null) {
            return coverTarget(
              intrinsicWidth,
              intrinsicHeight,
              coverEdge: coverEdge,
              maxEdge: maxEdge,
            );
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
      other.maxEdge == maxEdge &&
      other.coverEdgePx == coverEdgePx;

  @override
  int get hashCode =>
      Object.hash(imageProvider, maxSourcePixels, maxEdge, coverEdgePx);
}
