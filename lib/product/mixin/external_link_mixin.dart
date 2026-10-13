import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/external_link_dialog.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/service/url_launcher_service.dart';

/// Dış bağlantı akışının sonucu ([confirmAndOpenExternalLink]).
enum ExternalLinkResult {
  /// Kullanıcı onayladı ve adres cihazda açıldı.
  opened,

  /// Kullanıcı vazgeçti ("Vazgeç", scrim, geri) — hiçbir şey açılmadı.
  cancelled,

  /// Adres açılamadı: şema izinli değil ya da cihazda açabilecek uygulama
  /// yok. İzinli olmayan şemada onay dialogu **gösterilmez**.
  failed,
}

/// Kulüp iletişim bağlantılarının adresleri ve açılabilirlik kuralı. CLB-03
/// "Hakkında" satırları (e-posta / Instagram / web) adreslerini buradan
/// alır; adres metni view'da birleştirilmez.
abstract final class ExternalLinks {
  /// Açılmasına izin verilen şemalar. Kulüp bağlantıları kullanıcı girdisidir
  /// (MGT-09): `tel:`, `sms:`, `intent:`, `javascript:` gibi şemalar
  /// açılmaz.
  static const Set<String> allowedSchemes = {_https, _http, _mailto};

  /// [uri] açılabilir mi: izinli şema ve — web adresinde — boş olmayan
  /// sunucu adı. Kullanıcı bilgisi taşıyan web adresi
  /// (`https://gumushane.edu.tr@baska.site`) açılmaz: sunucu adını gizleyen
  /// bilinen bir aldatmacadır.
  static bool isAllowed(Uri uri) => switch (uri.scheme) {
    _mailto => true,
    _https || _http => uri.host.isNotEmpty && uri.userInfo.isEmpty,
    _ => false,
  };

  /// [email] adresine e-posta (`mailto:`; CLB-03 `about.link.email`). Boş
  /// adres → `null`.
  static Uri? mail(String email) {
    final address = email.trim();
    return address.isEmpty ? null : Uri(scheme: _mailto, path: address);
  }

  /// [handle] Instagram profili (`https://instagram.com/<ad>`; baştaki `@`
  /// atılır — `screens-clubs.js:96`). Boş ad → `null`.
  static Uri? instagram(String handle) {
    final trimmed = handle.trim();
    final name = trimmed.startsWith(_at) ? trimmed.substring(1) : trimmed;
    return name.isEmpty
        ? null
        : Uri(scheme: _https, host: _instagramHost, path: name);
  }

  /// [address] web adresi (CLB-03 `about.link.web`). Şeması yoksa `https`
  /// eklenir; ayrıştırılamayan ya da izinli olmayan adres → `null`.
  static Uri? web(String address) {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(
      trimmed.contains(_schemeSeparator)
          ? trimmed
          : '$_https$_schemeSeparator$trimmed',
    );
    return uri != null && uri.scheme != _mailto && isAllowed(uri) ? uri : null;
  }

  static const String _https = 'https';
  static const String _http = 'http';
  static const String _mailto = 'mailto';
  static const String _schemeSeparator = '://';
  static const String _at = '@';
  static const String _instagramHost = 'instagram.com';
}

/// DLG-32 "Uygulamadan ayrılıyorsun" dialogunu [feedback] üzerinden açar —
/// **tek giriş**. "Aç" → `true`, "Vazgeç" → `false`, scrim / geri → `null`.
///
/// Yalnızca sorar; adresi açmaz. Akışın tamamı için
/// [confirmAndOpenExternalLink] / [ExternalLinkMixin].
Future<bool?> showExternalLinkDialog(FeedbackService feedback, Uri uri) =>
    feedback.showDialog<bool>(
      DialogId.dlg32,
      builder: (_) => ExternalLinkDialog(url: uri.toString()),
    );

/// Dış bağlantı akışı: DLG-32 onayı → [launcher] ile adresi aç.
///
/// İzinli olmayan şema ([ExternalLinks.isAllowed]) sorulmadan reddedilir.
/// ViewModel'ler [ExternalLinkMixin.openExternalLink] ile, view / sheet'ler
/// servisleri kendi erişim yollarından vererek çağırır.
Future<ExternalLinkResult> confirmAndOpenExternalLink({
  required FeedbackService feedback,
  required UrlLauncherService launcher,
  required Uri uri,
}) async {
  if (!ExternalLinks.isAllowed(uri)) return ExternalLinkResult.failed;
  final confirmed = await showExternalLinkDialog(feedback, uri);
  if (!(confirmed ?? false)) return ExternalLinkResult.cancelled;
  return await launcher.open(uri)
      ? ExternalLinkResult.opened
      : ExternalLinkResult.failed;
}

/// Dış bağlantı onayı — DLG-32 "Uygulamadan ayrılıyorsun" (`dialogs.js:52`):
/// uygulamanın dışına çıkan her bağlantı (kulüp e-postası / Instagram / web
/// — CLB-03; WhatsApp / e-posta paylaşımı — SHT-15; Google Takvim — SHT-14;
/// destek e-postası — DLG-01, SET-04) önce adresi gösterip sorar.
///
/// ```dart
/// Future<void> openWeb() async {
///   final uri = ExternalLinks.web(club.social.web ?? '');
///   if (uri != null) await openExternalLink(uri);
/// }
/// ```
///
/// Design: DLG-32
mixin ExternalLinkMixin on ProjectDependencyMixin {
  /// [uri] için DLG-32'yi gösterir; "Aç" seçilirse adresi cihazda açar
  /// (`UrlLauncherService.open`). Sonuç [ExternalLinkResult].
  Future<ExternalLinkResult> openExternalLink(Uri uri) =>
      confirmAndOpenExternalLink(
        feedback: feedback,
        launcher: urlLauncherService,
        uri: uri,
      );
}
