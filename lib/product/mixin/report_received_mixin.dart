import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';

/// Şikayet onayı — DLG-12 "Şikayetin alındı" (`dialogs.js:28`). SHT-10
/// "Şikayet nedeni" başarıyla gönderilince (ya da aynı hedef daha önce
/// bildirilmişse) gösterilir: kulüp, gönderi, yorum, kullanıcı ve etkinlik
/// şikayetlerinin ortak son adımı.
///
/// Design: DLG-12
mixin ReportReceivedMixin on ProjectDependencyMixin {
  /// DLG-12'yi gösterir ve kapanana kadar bekler.
  ///
  /// [blockableUserName] verilirse (şikayet bir kullanıcıya bağlıysa:
  /// kullanıcı, gönderi ya da yorum sahibi) "Tamam"ın altında "{ad}
  /// kullanıcısını da engelle" çizilir. Dönen değer o eylemin seçilip
  /// seçilmediğidir: `true` → çağıran engelleme onayını (DLG-13) açar;
  /// "Tamam", scrim ve geri → `false`. Ad verilmediyse (kulüp / etkinlik
  /// şikayeti) her zaman `false`.
  Future<bool> showReportReceivedDialog({String? blockableUserName}) async {
    final name = blockableUserName?.trim() ?? '';
    final acknowledged = await feedback.showDialog<bool>(
      DialogId.dlg12,
      params: {if (name.isNotEmpty) DialogParamKeys.name: name},
    );
    // Katalog: "Tamam" → true, "… engelle" → false, scrim / geri → null.
    return name.isNotEmpty && acknowledged == false;
  }
}
