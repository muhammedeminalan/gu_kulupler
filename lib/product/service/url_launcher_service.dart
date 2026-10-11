import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:url_launcher/url_launcher.dart';

/// Dış bağlantıları cihazda açan servis (CD-08): `mailto:` destek adresi
/// (DLG-01, SET-04 / SET-05), web / Instagram bağlantıları (CLB-03 → DLG-32),
/// Google Takvim (SHT-14), mağaza sayfası (DLG-26).
///
/// View ve ViewModel `url_launcher` paketini doğrudan çağırmaz; tek giriş bu
/// arayüzdür (`ProjectDependencyMixin.urlLauncherService`).
// Tek üyeli arayüz bilerek sınıftır: GetIt'e kaydedilir ve testte fake ile
// değiştirilir (CD-08).
// ignore: one_member_abstracts
abstract interface class UrlLauncherService {
  /// [uri] adresini uygulamanın dışında (e-posta istemcisi, tarayıcı, mağaza)
  /// açar. Açıldıysa `true`; cihazda adresi açabilecek uygulama yoksa ya da
  /// platform hata verdiyse `false`. Hiçbir zaman fırlatmaz.
  Future<bool> open(Uri uri);
}

/// [UrlLauncherService]'in platform çağrısı (`launchUrl` imzası).
typedef UrlLaunchCall = Future<bool> Function(Uri uri, {LaunchMode mode});

/// [UrlLauncherService] uygulaması: `url_launcher`.
///
/// Adres her zaman uygulama dışında açılır (`LaunchMode.externalApplication`):
/// uygulama içi web görünümü yoktur. Ön sorgu (`canLaunchUrl`) yapılmaz —
/// platform manifestlerinde şema bildirimi gerektirir ve sonucu `launchUrl`
/// zaten verir.
final class DeviceUrlLauncherService implements UrlLauncherService {
  /// `launch` yalnızca testte verilir (varsayılan `launchUrl`).
  const DeviceUrlLauncherService({this._launch = launchUrl});

  final UrlLaunchCall _launch;

  @override
  Future<bool> open(Uri uri) async {
    try {
      return await _launch(uri, mode: LaunchMode.externalApplication);
    } on Object catch (error, stack) {
      // Adres kişisel veri taşıyabilir (mailto); günlüğe yalnızca şema yazılır.
      AppLogger.warn(
        'Dış bağlantı açılamadı (${uri.scheme})',
        error: error,
        stackTrace: stack,
      );
      return false;
    }
  }
}
