import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/media/constants/media_constants.dart';

/// Storage yolunun indirme adresini getiren çağrı (`StorageService
/// .downloadUrl`). Hiçbir zaman fırlatmaz; hata [FirebaseFailure] olarak
/// döner.
typedef ImageUrlFetch = Future<StorageResult<String>> Function(String path);

/// Storage yolu → indirme adresi önbelleği (PLAN §10.2 `downloadUrl`:
/// "sonuç `ImageUrlCache` içinde 1 saat önbellek").
///
/// Görsel çözücüleri eşzamanlıdır (widget `build` içinde çağrılır): bilinen
/// adresi [peek] ile okur, bilinmeyeni [request] ile arka planda ister. Yeni
/// bir adres geldiğinde dinleyiciler uyarılır (çözücü sağlayıcısı kendini
/// yeniler, izleyen widget yeniden çizilir).
///
/// * **Tazeleme:** adres [ttl] süresince tazedir. Süresi dolan adres
///   kullanılmaya devam eder ([peek] onu döner — görsel titremez) ve bir
///   sonraki [request] arka planda yenisini ister.
/// * **Hata:** adres alınamazsa ([StorageError.notFound], yetki, ağ…) sonuç
///   `null`'dır, dinleyiciler uyarılmaz ve aynı yol [retryAfter] dolmadan
///   yeniden istenmez (her yeniden çizimde istek yağmaz).
/// * **Tek istek:** aynı yol için süren istek varken ikincisi başlatılmaz.
/// * Dosyalar değişmez (üzerine yazma ve silme yok — D-10): yol, görselin
///   kalıcı kimliğidir; adres yalnızca erişim jetonunu taşır.
///
/// Bellekte en çok [maxEntries] adres tutulur (en eski kayıt atılır).
final class ImageUrlCache extends ChangeNotifier {
  /// `fetch` ile adres isteyen, zamanı `clock` saatinden okuyan önbellek.
  ImageUrlCache({
    required this._fetch,
    required this._clock,
    this.ttl = MediaConstants.imageUrlTtl,
    this.retryAfter = MediaConstants.imageUrlRetryAfter,
    this.maxEntries = MediaConstants.imageUrlCacheMaxEntries,
  });

  /// Adresin taze sayıldığı süre.
  final Duration ttl;

  /// Başarısız isteğin yeniden denenmeden önce bekleyeceği süre.
  final Duration retryAfter;

  /// Bellekte tutulan en çok adres sayısı.
  final int maxEntries;

  final ImageUrlFetch _fetch;
  final AppClock _clock;

  /// Yol → (adres, alındığı an); ekleme sırasıyla (en eski başta).
  final LinkedHashMap<String, ({String url, DateTime at})> _urls =
      LinkedHashMap();

  /// Yol → son başarısız isteğin anı.
  final Map<String, DateTime> _failedAt = {};

  /// Süren istekler.
  final Map<String, Future<String?>> _pending = {};

  bool _disposed = false;

  /// [path] için bilinen adres (süresi dolmuş olsa da); hiç alınmadıysa
  /// `null`. İstek başlatmaz.
  String? peek(String path) => _urls[path]?.url;

  /// [path] için adres isteği gerekiyorsa başlatır ve sonucunu döner (adres
  /// alınamazsa `null`). İstek gerekmiyorsa — adres taze, istek sürüyor ya da
  /// son hata [retryAfter] içinde — `null` döner ve hiçbir şey yapmaz.
  Future<String?>? request(String path) {
    if (_disposed || _pending.containsKey(path)) return null;
    final now = _clock.nowUtc();
    final known = _urls[path];
    if (known != null && now.difference(known.at) < ttl) return null;
    final failed = _failedAt[path];
    if (failed != null && now.difference(failed) < retryAfter) return null;
    return _pending[path] = _load(path);
  }

  /// [path] adresini döner: tazeyse önbellekten, değilse isteyerek (süren
  /// istek varsa onu bekler). Adres alınamazsa bilinen (eski) adres, o da
  /// yoksa `null`.
  Future<String?> resolve(String path) async {
    final started = request(path) ?? _pending[path];
    if (started == null) return peek(path);
    return await started ?? peek(path);
  }

  Future<String?> _load(String path) async {
    StorageResult<String> result;
    try {
      result = await _fetch(path);
    } on Object catch (error) {
      // Sözleşme gereği fırlatmaz; yine de çizim hattı hiçbir zaman düşmez.
      result = FirebaseFailure(StorageError.unknown, message: '$error');
    }
    // Kaldırılan değer bu isteğin kendisidir (beklenmez).
    _pending.remove(path)?.ignore();
    if (_disposed) return null;
    final now = _clock.nowUtc();
    switch (result) {
      case FirebaseFailure():
        _failedAt[path] = now;
        return null;
      case FirebaseSuccess(data: final url):
        _failedAt.remove(path);
        final changed = _urls[path]?.url != url;
        // Yeniden eklenen kayıt sıranın sonuna geçer (en yeni).
        _urls
          ..remove(path)
          ..[path] = (url: url, at: now);
        while (_urls.length > maxEntries) {
          _urls.remove(_urls.keys.first);
        }
        if (changed) notifyListeners();
        return url;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
