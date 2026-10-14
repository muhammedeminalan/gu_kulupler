/// Görsel gösterimi sabitleri (Storage indirme adresi önbelleği — PLAN §10.2;
/// uzaktan gelen görselin çözüm sınırları — `BoundedImage`).
///
/// Süre literalleri görünüm kodunda yazılmaz (HC08); `ImageUrlCache`
/// varsayılanları buradan okunur.
abstract final class MediaConstants {
  /// İndirme adresinin taze sayıldığı süre (PLAN §10.2 `downloadUrl`: "1 saat
  /// önbellek"). Süresi dolan adres kullanılırken arka planda yenilenir.
  static const Duration imageUrlTtl = Duration(hours: 1);

  /// Alınamayan adresin yeniden istenmeden önce bekleyeceği süre: yer
  /// tutucudaki görsel her yeniden çizimde istek başlatmaz.
  static const Duration imageUrlRetryAfter = Duration(seconds: 30);

  /// Bellekte tutulan en çok indirme adresi (en eski kayıt atılır).
  static const int imageUrlCacheMaxEntries = 512;

  /// Uzaktan gelen görselin çözüldüğü en uzun kenar (piksel). Uygulamanın
  /// yüklediği görsellerin üst sınırıdır (`DeviceImagePickerService.maxEdgePx`):
  /// kendi yüklememiz küçültülmez, daha büyük gelen görsel bu kutuya sığdırılır.
  static const int imageDecodeMaxEdgePx = 1600;

  /// Çözülmesine izin verilen kaynak görselin en çok piksel sayısı
  /// (genişlik × yükseklik): [imageDecodeMaxEdgePx] karesinin dört katı
  /// (≈ 10 MP; çözüm sırasında en çok ≈ 41 MB). Üstü çözülmeden reddedilir —
  /// Storage Rules piksel boyutunu göremez, 5 MB altındaki dosya on binlerce
  /// piksel kenarlı olabilir.
  static const int imageSourceMaxPixels =
      4 * imageDecodeMaxEdgePx * imageDecodeMaxEdgePx;
}
