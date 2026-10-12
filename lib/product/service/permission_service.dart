import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:permission_handler/permission_handler.dart' as handler;
import 'package:permission_handler/permission_handler.dart'
    show Permission, PermissionStatus;

// ViewModel'ler `permission_handler` paketini doğrudan içe aktarmaz: izin
// kimliği ve durum tipi bu dosyadan gelir.
export 'package:permission_handler/permission_handler.dart'
    show Permission, PermissionStatus;

/// Cihaz izinleri (CD-08, CD-16): kamera (DLG-04, TST-32) ve bildirim
/// (DLG-03) izni, "Ayarlara git".
///
/// **Galeri için izin istenmez** (CD-16): fotoğraf seçimi sistem seçicisiyle
/// yapılır (Android Photo Picker / iOS PHPicker); DLG-05 yalnızca ön
/// açıklamadır. Bildirim izni **yalnızca** buradan istenir (yerel hatırlatıcı
/// servisi izin istemez — PLAN §10.2).
///
/// Hiçbir metot fırlatmaz: platform hatası [PermissionStatus.denied] (ayarlar
/// için `false`) olarak döner ve günlüğe yazılır.
abstract interface class PermissionService {
  /// [permission] izninin güncel durumu. Sistem penceresi **açmaz**.
  Future<PermissionStatus> status(Permission permission);

  /// [permission] kullanılabilir mi ([PermissionStatusX.isUsable])? Sistem
  /// penceresi açmaz.
  Future<bool> isGranted(Permission permission);

  /// Kamera iznini ister ve son durumu döndürür. İzin daha önce verildiyse
  /// pencere açılmadan `granted`; kalıcı olarak reddedildiyse pencere
  /// açılmadan `permanentlyDenied` döner ([PermissionStatusX.needsSettings]
  /// → TST-32 "Ayarlara git").
  Future<PermissionStatus> requestCamera();

  /// Bildirim iznini ister ve son durumu döndürür (DLG-03 "İzin ver",
  /// NTF-01 `enable`).
  Future<PermissionStatus> requestNotifications();

  /// Sistem ayarlarında uygulamanın sayfasını açar. Açıldıysa `true`.
  Future<bool> openAppSettings();
}

/// İzin durumunun uygulamadaki iki yorumu.
extension PermissionStatusX on PermissionStatus {
  /// Özellik kullanılabilir: `granted`, iOS'ta kısıtlı erişim (`limited`) ve
  /// sessiz bildirim izni (`provisional`) dahil.
  bool get isUsable =>
      this == PermissionStatus.granted ||
      this == PermissionStatus.limited ||
      this == PermissionStatus.provisional;

  /// Sistem bir daha sormaz: izin yalnızca sistem ayarlarından açılabilir
  /// (`permanentlyDenied`) ya da cihaz kısıtı vardır (`restricted`).
  bool get needsSettings =>
      this == PermissionStatus.permanentlyDenied ||
      this == PermissionStatus.restricted;
}

/// [DevicePermissionService]'in platform çağrısı: bir iznin durumunu okur ya
/// da izni ister.
typedef PermissionCall = Future<PermissionStatus> Function(Permission value);

/// [PermissionService] uygulaması: `permission_handler`.
final class DevicePermissionService implements PermissionService {
  /// Platform çağrıları yalnızca testte verilir (varsayılan
  /// `permission_handler`).
  const DevicePermissionService({
    this._read = _readStatus,
    this._request = _requestPermission,
    this._openSettings = handler.openAppSettings,
  });

  final PermissionCall _read;
  final PermissionCall _request;
  final Future<bool> Function() _openSettings;

  @override
  Future<PermissionStatus> status(Permission permission) =>
      _guard(permission, _read, 'okunamadı');

  @override
  Future<bool> isGranted(Permission permission) async =>
      (await status(permission)).isUsable;

  @override
  Future<PermissionStatus> requestCamera() =>
      _guard(Permission.camera, _request, 'istenemedi');

  @override
  Future<PermissionStatus> requestNotifications() =>
      _guard(Permission.notification, _request, 'istenemedi');

  @override
  Future<bool> openAppSettings() async {
    try {
      return await _openSettings();
    } on Object catch (error, stack) {
      AppLogger.warn(
        'Uygulama ayarları açılamadı',
        error: error,
        stackTrace: stack,
      );
      return false;
    }
  }

  /// [call] çağrısını sarar: platform hatası "izin yok" sayılır.
  static Future<PermissionStatus> _guard(
    Permission permission,
    PermissionCall call,
    String what,
  ) async {
    try {
      return await call(permission);
    } on Object catch (error, stack) {
      AppLogger.warn(
        'İzin durumu $what ($permission)',
        error: error,
        stackTrace: stack,
      );
      return PermissionStatus.denied;
    }
  }

  static Future<PermissionStatus> _readStatus(Permission permission) =>
      permission.status;

  static Future<PermissionStatus> _requestPermission(Permission permission) =>
      permission.request();
}
