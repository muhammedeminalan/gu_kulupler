import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:share_plus/share_plus.dart';

/// İçeriği uygulamanın dışına veren servis (CD-08): sistem paylaşım sayfası
/// — kulüp / etkinlik / gönderi bağlantısı (SHT-15 "Diğer…",
/// `AppConstants.shareBaseUrl` + yol — K-D) ve takvim dosyası (SHT-14
/// `.ics`) — ile panoya kopyalama (SHT-15 / SHT-08 / SHT-14 "Bağlantıyı
/// kopyala" → TST-35; CLB-03 / CLB-07 e-posta → TST-08).
///
/// View ve ViewModel `share_plus` paketini ve `Clipboard`'ı doğrudan
/// çağırmaz; tek giriş bu arayüzdür (`ProjectDependencyMixin.shareService`).
/// Bildirimi (toast) çağıran gösterir — yalnızca sonuç `true` ise.
abstract interface class ShareService {
  /// [text] metnini panoya yazar (prototip `GU.copyText`, `core.js:424`).
  /// Yazıldıysa `true`; platform hata verdiyse `false`. Hiçbir zaman
  /// fırlatmaz.
  Future<bool> copyText(String text);

  /// [text] metnini (çoğunlukla bir bağlantı) sistem paylaşım sayfasıyla
  /// paylaşır. [subject] e-posta gibi konu satırı olan hedeflerde kullanılır.
  ///
  /// Paylaşım sayfası açıldıysa `true` (kullanıcı hedef seçmeden kapatsa
  /// da); platform hata verdiyse `false`. Hiçbir zaman fırlatmaz.
  ///
  /// [origin] iPad'de sayfanın çıkacağı dikdörtgendir (dokunulan düğme);
  /// verilmezse ekranın üst yarısı kullanılır.
  Future<bool> shareText(String text, {String? subject, Rect? origin});

  /// [path] yolundaki dosyayı [mimeType] türüyle paylaşır (SHT-14:
  /// `text/calendar`). Sonuç ve [origin] [shareText] ile aynıdır.
  Future<bool> shareFile(
    String path, {
    required String mimeType,
    Rect? origin,
  });
}

/// [ShareService]'in platform çağrısı (`SharePlus.instance.share` imzası).
typedef ShareCall = Future<ShareResult> Function(ShareParams params);

/// [ShareService]'in pano çağrısı (`Clipboard.setData` imzası).
typedef ClipboardWriteCall = Future<void> Function(ClipboardData data);

/// iPad paylaşım sayfasının varsayılan çıkış dikdörtgenini veren işlev.
typedef ShareOriginResolver = Rect Function();

/// [ShareService] uygulaması: `share_plus` + Flutter `Clipboard`.
///
/// Paylaşımın sonuç durumu (paylaşıldı / vazgeçildi) çağırana taşınmaz:
/// Android ve iOS farklı bildirir ve hiçbir akış buna bağlı değildir (SHT-15
/// "Diğer…" paylaşımdan sonra bildirim göstermez).
final class DeviceShareService implements ShareService {
  /// `share`, `writeClipboard` ve `fallbackOrigin` yalnızca testte verilir.
  const DeviceShareService({
    this._share = _platformShare,
    this._writeClipboard = Clipboard.setData,
    this._fallbackOrigin = _upperHalfOfScreen,
  });

  final ShareCall _share;
  final ClipboardWriteCall _writeClipboard;
  final ShareOriginResolver _fallbackOrigin;

  @override
  Future<bool> copyText(String text) async {
    try {
      await _writeClipboard(ClipboardData(text: text));
      return true;
    } on Object catch (error, stack) {
      // Kopyalanan metin günlüğe yazılmaz (e-posta kişisel veridir).
      AppLogger.warn('Panoya kopyalanamadı', error: error, stackTrace: stack);
      return false;
    }
  }

  @override
  Future<bool> shareText(String text, {String? subject, Rect? origin}) => _open(
    () => ShareParams(
      text: text,
      subject: subject,
      sharePositionOrigin: origin ?? _fallbackOrigin(),
    ),
  );

  @override
  Future<bool> shareFile(
    String path, {
    required String mimeType,
    Rect? origin,
  }) => _open(
    () => ShareParams(
      files: [XFile(path, mimeType: mimeType)],
      sharePositionOrigin: origin ?? _fallbackOrigin(),
    ),
  );

  Future<bool> _open(ShareParams Function() params) async {
    try {
      await _share(params());
      return true;
    } on Object catch (error, stack) {
      // Paylaşılan içerik günlüğe yazılmaz (bağlantı kişisel veri taşıyabilir).
      AppLogger.warn('Paylaşım açılamadı', error: error, stackTrace: stack);
      return false;
    }
  }

  static Future<ShareResult> _platformShare(ShareParams params) =>
      SharePlus.instance.share(params);

  /// iPad'de paylaşım sayfası bir çıkış dikdörtgeni ister (boş dikdörtgen
  /// platform hatasıdır); telefon bu değeri yok sayar.
  static Rect _upperHalfOfScreen() {
    final view = PlatformDispatcher.instance.views.firstOrNull;
    if (view == null) return Rect.zero;
    final size = view.physicalSize / view.devicePixelRatio;
    return Offset.zero & Size(size.width, size.height / _screenHalves);
  }

  /// Ekran yüksekliğinin bölündüğü parça sayısı (üst yarı).
  static const double _screenHalves = 2;
}
