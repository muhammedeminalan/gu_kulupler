import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';

/// Başvuru ret nedeninin gösterilen adı — prototip
/// `t('rejectReason.' + m.rejectReason)` (`sheets.js:93, 101`,
/// `screens-manage.js:57`).
///
/// SHT-20 neden çipleri, SHT-19 karar bandı ve MGT-02 "Reddedilen" satırı
/// aynı eşlemeyi kullanır. `switch` tüketicidir: yeni bir [RejectReason]
/// değeri etiketsiz derlenmez.
abstract final class RejectReasonLabels {
  /// [reason] nedeninin adı (`rejectReason*` ARB).
  static String of(AppLocalizations l10n, RejectReason reason) =>
      switch (reason) {
        RejectReason.quota => l10n.rejectReasonQuota,
        RejectReason.criteria => l10n.rejectReasonCriteria,
        RejectReason.missing => l10n.rejectReasonMissing,
        RejectReason.other => l10n.rejectReasonOther,
      };
}
