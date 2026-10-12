import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';
import 'package:gu_kulupler/product/service/permission_service.dart';

/// İzin ön açıklamaları ve görsel seçme akışı — **tek mekanizma** (D-16):
/// DLG-03 "Bildirimleri açalım mı?", DLG-04 "Kamera erişimi", DLG-05
/// "Fotoğraflarına erişim", TST-32 "Kamera izni gerekli." (`dialogs.js:10–17`,
/// `sheets.js:80–81`).
///
/// Görsel seçen her ViewModel (AUT-05, PRF-02, SET-05, MGT-09, FED-03) SHT-16
/// kaynağını aldıktan sonra [pickImage] çağırır:
///
/// ```dart
/// Future<void> pickAvatar(MediaSource source) async {
///   final image = (await pickImage(source)).imageOrNull;
///   if (image == null) return;
///   state = state.copyWith(avatar: image, isDirty: true);
/// }
/// ```
///
/// Prototipin OS izin maketi (`PermissionSim`) uygulanmaz (K-02): gerçek
/// sistem penceresi `PermissionService` üzerinden açılır.
///
/// Design: DLG-03, DLG-04, DLG-05
mixin PermissionPromptMixin on ProjectDependencyMixin {
  /// [source] kaynağından tek görsel seçtirir; gerekli ön açıklamayı
  /// ([ensureCameraAccess] / [ensureGalleryAccess]) kendisi gösterir.
  ///
  /// * Kullanıcı açıklamada ya da seçicide vazgeçerse [ImagePickCancelled].
  /// * Kamera erişimi reddedilirse TST-32 gösterilir ("Ayarlara git" → sistem
  ///   ayarları) ve sonuç [ImagePickError.permissionDenied] olur.
  /// * Diğer hatalar ([ImagePickError.tooLarge], `invalidType`, `unreadable`,
  ///   `failed`) için burada toast **gösterilmez**; çağıran kendi hata
  ///   durumuna çevirir.
  Future<ImagePickResult> pickImage(
    MediaSource source, {
    int maxBytes = Limits.imageMaxBytes,
  }) async {
    switch (source) {
      case MediaSource.camera:
        // Ret toastını (TST-32) `ensureCameraAccess` gösterdi.
        final access = await _cameraAccess();
        if (access != _Access.granted) {
          return access == _Access.denied
              ? const ImagePickFailure(ImagePickError.permissionDenied)
              : const ImagePickCancelled();
        }
      case MediaSource.gallery:
        if (!await ensureGalleryAccess()) return const ImagePickCancelled();
    }
    final result = await imagePickerService.pick(source, maxBytes: maxBytes);
    if (result case ImagePickFailure(error: ImagePickError.permissionDenied)) {
      // Sistem seçicisi erişimi kendisi reddetti (izin bu arada kaldırıldı).
      _showCameraDenied();
    }
    return result;
  }

  /// Kameraya erişim var mı; yoksa ister.
  ///
  /// İzin zaten verildiyse pencere açılmadan `true`. Aksi halde DLG-04
  /// gösterilir: "İzin ver" → sistem kamera izni; verilirse `true`,
  /// reddedilirse TST-32 ("Ayarlara git" → `openAppSettings`) ve `false`.
  /// "Şimdi değil", scrim ve geri toast göstermeden `false` döner.
  Future<bool> ensureCameraAccess() async =>
      await _cameraAccess() == _Access.granted;

  /// Fotoğraf seçicisi açılabilir mi (DLG-05 ön açıklaması; CD-16)?
  ///
  /// Galeri sistem seçicisiyle açıldığından sistem izni istenmez. Açıklama
  /// bir kez onaylandıysa (`AppPreferencesStore.photoAccessExplained`)
  /// yeniden gösterilmez. "İzin ver" → `true` (onay cihaza yazılır); "Şimdi
  /// değil", scrim ve geri → `false`.
  Future<bool> ensureGalleryAccess() async {
    if (appPreferencesStore.photoAccessExplained) return true;
    final allowed = await feedback.showDialog<bool>(DialogId.dlg05);
    if (!(allowed ?? false)) return false;
    if (!await appPreferencesStore.setPhotoAccessExplained(true)) {
      AppLogger.warn('Fotoğraf erişimi onayı kalıcı yazılamadı');
    }
    return true;
  }

  /// Bildirim izni ön açıklaması (DLG-03): "İzin ver" → sistem bildirim izni;
  /// verilirse TST-19 ve `true`. Reddedilirse, "Şimdi değil" seçilirse ya da
  /// dialog kapatılırsa `false` (toast yok).
  ///
  /// "Bir kez" bayrağını (`notificationPermissionAsked`) **çağıran**
  /// işaretler — sonuç ne olursa olsun
  /// (`AppPreferencesViewModel.markNotificationPermissionAsked`); bu metot
  /// bayrağı okumaz ve yazmaz. NTF-01 `enable` aynı metodu çağırabilir.
  Future<bool> askNotificationPermission() async {
    final allowed = await feedback.showDialog<bool>(DialogId.dlg03);
    if (!(allowed ?? false)) return false;
    final status = await permissionService.requestNotifications();
    if (!status.isUsable) return false;
    feedback.showToast(ToastId.tst19);
    return true;
  }

  Future<_Access> _cameraAccess() async {
    if (await permissionService.isGranted(Permission.camera)) {
      return _Access.granted;
    }
    final allowed = await feedback.showDialog<bool>(DialogId.dlg04);
    if (!(allowed ?? false)) return _Access.declined;
    final status = await permissionService.requestCamera();
    if (status.isUsable) return _Access.granted;
    _showCameraDenied();
    return _Access.denied;
  }

  /// TST-32 "Kamera izni gerekli." + "Ayarlara git" (`scan.goSettings`).
  void _showCameraDenied() => feedback.showToast(
    ToastId.tst32,
    onAction: () => unawaited(permissionService.openAppSettings()),
  );
}

/// Kamera erişimi isteğinin sonucu.
enum _Access {
  /// İzin var.
  granted,

  /// Ön açıklamada vazgeçildi (toast yok).
  declined,

  /// Sistem izni reddedildi (TST-32 gösterildi).
  denied,
}
