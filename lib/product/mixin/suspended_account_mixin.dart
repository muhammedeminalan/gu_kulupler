import 'package:gu_kulupler/core/constants/app_constants.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';

/// Askıya alınmış hesap bildirimi — DLG-01 "Hesabın askıya alındı"
/// (`dialogs.js:18`; navigation.md §3 "askıda → oturum kapat → `/login` +
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
  /// DLG-01'i gösterir ve kapanana kadar bekler.
  ///
  /// "Destekle iletişime geç" → destek adresine e-posta açılır
  /// (`AppConstants.supportMailUri`); "Tamam", scrim ve geri yalnızca
  /// kapatır. Dönen değer destek bağlantısının açılıp açılmadığıdır
  /// (cihazda e-posta uygulaması yoksa `false`).
  Future<bool> showSuspendedAccountDialog() async {
    final contact = await feedback.showDialog<bool>(DialogId.dlg01);
    if (!(contact ?? false)) return false;
    return urlLauncherService.open(AppConstants.supportMailUri);
  }
}
