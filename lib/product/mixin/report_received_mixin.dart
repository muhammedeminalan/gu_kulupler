import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/report_reason_sheet.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';

/// Şikayet onayı — DLG-12 "Şikayetin alındı" (`dialogs.js:28`). SHT-10
/// "Şikayet nedeni" başarıyla gönderilince (ya da aynı hedef daha önce
/// bildirilmişse) gösterilir: kulüp, gönderi, yorum, kullanıcı ve etkinlik
/// şikayetlerinin ortak son adımı. Kullanıcı şikayetinin yazımı da buradadır
/// ([sendReport]; CLB-06, CLB-07).
///
/// Design: DLG-12
mixin ReportReceivedMixin on ProjectDependencyMixin, WriteGuardMixin {
  /// SHT-10'da doğrulanan [report] şikayetini [reporterId] adına yazar
  /// (`reportRepository.report`). [ReportSubmitOutcome.sent] → sheet kapanır
  /// ve çağıran [showReportReceivedDialog] ile DLG-12'yi açar; aynı hedef
  /// daha önce bildirilmişse de `sent`. [ReportSubmitOutcome.dailyLimit] →
  /// günlük şikayet sınırı doldu (T-45, kullanıcı kararı 3): sheet açık kalır
  /// ve hata satırını gösterir (toast yok). [ReportSubmitOutcome.failed] →
  /// sheet açık kalır: oturum yok, çevrimdışı / ağ (TST-24), yetki yok
  /// (TST-X18), beklenmeyen hata (günlüğe düşer).
  Future<ReportSubmitOutcome> sendReport({
    required String? reporterId,
    required ReportReasonResult report,
  }) async {
    if (reporterId == null || !ensureOnline()) {
      return ReportSubmitOutcome.failed;
    }
    final result = await reportRepository.report(
      reporterId: reporterId,
      target: report.target,
      reason: report.reason,
      note: report.note,
    );
    switch (result) {
      case FirebaseSuccess():
      case FirebaseFailure(error: FirestoreError.alreadyExists):
        return ReportSubmitOutcome.sent;
      case FirebaseFailure(
        error: FirestoreError.ruleViolation,
        detail: FirestoreFailureDetail(code: FirestoreRuleCode.reportLimit),
      ):
        return ReportSubmitOutcome.dailyLimit;
      case FirebaseFailure(:final error, :final message):
        if (!showWriteFailureToast(error)) {
          AppLogger.warn(
            'Şikayet gönderilemedi: ${error.name}',
            error: message,
          );
        }
        return ReportSubmitOutcome.failed;
    }
  }

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
