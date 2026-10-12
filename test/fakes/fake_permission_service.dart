// `PermissionService` fake'i (PLAN §16.3, CD-08): sistem penceresi açmaz,
// izin durumlarını bellekte tutar.
//
//   final permissions = FakePermissionService();
//   permissions.results[Permission.camera] = PermissionStatus.permanentlyDenied;
//   await viewModel.pickAvatar(MediaSource.camera);
//   expect(permissions.requested, [Permission.camera]);
//   expect(permissions.openedSettings, 1); // TST-32 "Ayarlara git"
//
// Durumu verilmemiş izin "henüz sorulmadı" sayılır: `status` `denied`, istek
// `granted` döner ve sonuç kalıcıdır (gerçek cihazda "İzin ver").
import 'package:gu_kulupler/product/service/permission_service.dart';

import 'fake_base.dart';

final class FakePermissionService extends FakeBase
    implements PermissionService {
  /// İzin → istek sonrası durum. Verilmeyen izin için istek `granted` döner.
  final Map<Permission, PermissionStatus> results =
      <Permission, PermissionStatus>{};

  /// İstenen izinler, sırasıyla (sistem penceresi açılmış sayılır).
  final List<Permission> requested = <Permission>[];

  /// [openAppSettings] çağrı sayısı.
  int openedSettings = 0;

  /// [openAppSettings] sonucu: `false` → ayarlar açılamadı.
  bool canOpenSettings = true;

  @override
  Future<PermissionStatus> status(Permission permission) async {
    record('status', [permission]);
    return results[permission] ?? PermissionStatus.denied;
  }

  @override
  Future<bool> isGranted(Permission permission) async {
    record('isGranted', [permission]);
    return (results[permission] ?? PermissionStatus.denied).isUsable;
  }

  @override
  Future<PermissionStatus> requestCamera() => _request(Permission.camera);

  @override
  Future<PermissionStatus> requestNotifications() =>
      _request(Permission.notification);

  /// Gerçek servis gibi hiçbir zaman fırlatmaz: bekleyen hata (`failNext`)
  /// `false` sonucuna çevrilir.
  @override
  Future<bool> openAppSettings() async {
    record('openAppSettings');
    openedSettings++;
    if (takeFailure() != null) return false;
    return canOpenSettings;
  }

  /// Bekleyen hata (`failNext`) platform hatası sayılır: `denied`.
  Future<PermissionStatus> _request(Permission permission) async {
    record('request', [permission]);
    requested.add(permission);
    if (takeFailure() != null) return PermissionStatus.denied;
    return results.putIfAbsent(permission, () => PermissionStatus.granted);
  }

  @override
  void resetFake() {
    super.resetFake();
    results.clear();
    requested.clear();
    openedSettings = 0;
    canOpenSettings = true;
  }
}
