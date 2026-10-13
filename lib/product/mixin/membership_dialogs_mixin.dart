import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';

/// Üyelikten çıkış onayları — "İsteği iptal et?" (DLG-07), "Kulüpten
/// ayrıl?" (DLG-08) ve "Ayrılamazsın" (DLG-09). Aynı üç dialogu açan her
/// ViewModel (CLB-03 / SHT-06, CLB-05, PRF-03) bu mixin'i kullanır.
///
/// Mixin yalnızca **sorar**; yazımı (`membershipRepository.cancelApplication`
/// / `.leave`), çevrimdışı kapısını (`WriteGuardMixin.ensureOnline`) ve
/// sonuç bildirimini (TST-40 / TST-39) çağıran yapar:
///
/// ```dart
/// Future<void> cancelApplication() async {
///   if (!await confirmCancelApplication(clubName: club.name)) return;
///   if (!ensureOnline()) return;
///   …
/// }
/// ```
mixin MembershipDialogsMixin on ProjectDependencyMixin {
  /// "İsteği iptal et?" — bekleyen başvurunun geri çekilmesi onayı
  /// (`dialogs.js:22`). Gövde [clubName] adını taşır.
  ///
  /// "İsteği iptal et" → `true`; "Vazgeç", scrim ve geri → `false`.
  ///
  /// Design: DLG-07
  Future<bool> confirmCancelApplication({required String clubName}) =>
      _confirm(DialogId.dlg07, clubName);

  /// "Kulüpten ayrıl?" — üyelikten ayrılma onayı (`dialogs.js:24`). Gövde
  /// [clubName] adını taşır.
  ///
  /// "Kulüpten ayrıl" → `true`; "Vazgeç", scrim ve geri → `false`.
  ///
  /// Design: DLG-08
  Future<bool> confirmLeaveClub({required String clubName}) =>
      _confirm(DialogId.dlg08, clubName);

  /// "Ayrılamazsın" — başkan başkanlığı devretmeden ayrılamaz
  /// (`dialogs.js:25`; `FirestoreRuleCode.presidentCannotLeave`).
  ///
  /// "Başkanlığı devret" → `true` (çağıran devir akışını başlatır: SHT-25 →
  /// DLG-21, T-33); "Tamam", scrim ve geri → `false`.
  ///
  /// Design: DLG-09
  Future<bool> showSolePresidentDialog() async =>
      await feedback.showDialog<bool>(DialogId.dlg09) ?? false;

  Future<bool> _confirm(DialogId id, String clubName) async =>
      await feedback.showDialog<bool>(
        id,
        params: {DialogParamKeys.club: clubName},
      ) ??
      false;
}
