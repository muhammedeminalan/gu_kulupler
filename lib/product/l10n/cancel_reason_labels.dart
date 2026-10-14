import 'package:gu_kulupler/l10n/app_localizations.dart';

/// Etkinlik iptal nedeninin gösterilen adı — prototip
/// `t('cancelReason.' + ev.cancelReason)` (`screens-events.js:45, 56`,
/// `dialogs.js:32`).
///
/// `events.cancelReason` DLG-23'te seçilen nedenin kimliğidir (`weather`,
/// `venue`, `speaker`, `other`); tanınmayan değer (serbest metin) olduğu gibi
/// gösterilir. EVT-02 iptal bandı ve DLG-16 gövdesi aynı eşlemeyi kullanır.
abstract final class CancelReasonLabels {
  /// [reason] nedeninin adı; boş ya da yoksa `null`.
  static String? of(AppLocalizations l10n, String? reason) {
    final value = reason?.trim() ?? '';
    if (value.isEmpty) return null;
    return switch (value) {
      'weather' => l10n.cancelReasonWeather,
      'venue' => l10n.cancelReasonVenue,
      'speaker' => l10n.cancelReasonSpeaker,
      'other' => l10n.cancelReasonOther,
      _ => value,
    };
  }
}
