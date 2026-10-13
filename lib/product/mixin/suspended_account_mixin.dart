import 'package:gu_kulupler/core/constants/app_constants.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/mixin/external_link_mixin.dart';

/// Askıya alınmış hesap bildirimi — DLG-01 "Hesabın askıya alındı"
/// (`dialogs.js:19`; navigation.md §3 "askıda → oturum kapat → `/login` +
/// DLG-01").
///
/// Askıyı fark eden her ViewModel (giriş akışı, oturum katmanı) aynı
/// bildirimi bu mixin ile gösterir:
///
/// ```dart
/// await authRepository.signOut();
/// await showSuspendedAccountDialog();
/// ```
///
/// Design: DLG-01
mixin SuspendedAccountMixin on ProjectDependencyMixin {
  /// DLG-01'i gösterir ve akış bitene kadar bekler.
  ///
  /// "Destekle iletişime geç" → dialog kapanır ve destek adresi dış
  /// bağlantı onayına (DLG-32) gider; "Aç" seçilirse e-posta açılır
  /// (`AppConstants.supportMailUri`; prototip `dialogs.js:19`). "Tamam",
  /// scrim ve geri yalnızca kapatır. Dönen değer destek bağlantısının açılıp
  /// açılmadığıdır (onay verilmediyse ya da cihazda e-posta uygulaması yoksa
  /// `false`).
  Future<bool> showSuspendedAccountDialog() async {
    final contact = await feedback.showDialog<bool>(DialogId.dlg01);
    if (!(contact ?? false)) return false;
    final result = await confirmAndOpenExternalLink(
      feedback: feedback,
      launcher: urlLauncherService,
      uri: AppConstants.supportMailUri,
    );
    return result == ExternalLinkResult.opened;
  }
}
