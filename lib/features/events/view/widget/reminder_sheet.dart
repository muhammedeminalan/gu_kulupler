import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_ui/gu_ui.dart';

/// SHT-13 "Hatırlatıcı" — dört seçenek (`ReminderOption`: yok / 15 dk / 1 sa
/// / 1 gün — CD-34), seçili olan işaretli (prototip `SHEETS['SHT-13']`,
/// `sheets.js:68–70`; menü biçimi `flush`).
///
/// * Satırlar `GuOptionRow` (radyo göstergesi; seçili [current]).
/// * Sayfa yazma yapmaz: dokunulan seçenek döner (`pop(ReminderOption)`);
///   kaydı ve yerel planlamayı çağıran yürütür
///   (`EventDetailViewModel.setReminder` → `rsvpRepository.setReminder` →
///   `localReminderService.schedule / cancel` → TST-37). X / scrim / geri →
///   `null`.
/// * Anahtarlar `SHT-13.select.<none|15m|1h|1d>` (`ReminderOption.json`),
///   `SHT-13.close`.
///
/// ```dart
/// final option = await feedback.showSheet<ReminderOption>(
///   SheetId.sht13,
///   builder: (_) => ReminderSheet(current: rsvp.reminder),
/// );
/// if (option != null) await viewModel.setReminder(option);
/// ```
///
/// Design: SHT-13
class ReminderSheet extends StatelessWidget {
  /// Seçili seçeneği [current] olan hatırlatıcı sayfası.
  const ReminderSheet({required this.current, super.key});

  /// Kayıttaki seçenek (`RsvpModel.reminder`).
  final ReminderOption current;

  /// [option] satırının anahtarı (`SHT-13.select.<json>`).
  static Key keyOf(ReminderOption option) =>
      FeedbackKeys.of(SheetId.sht13.designId, 'select.${option.json}');

  /// [option] seçeneğinin metni (`reminder.<none|15m|1h|1d>`).
  static String labelOf(AppLocalizations l10n, ReminderOption option) =>
      switch (option) {
        ReminderOption.none => l10n.reminderNone,
        ReminderOption.fifteenMinutes => l10n.reminder15m,
        ReminderOption.oneHour => l10n.reminder1h,
        ReminderOption.oneDay => l10n.reminder1d,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GuSheetFrame(
      title: l10n.sht13Title,
      closeSemanticLabel: l10n.a11yClose,
      closeKey: FeedbackKeys.of(SheetId.sht13.designId, 'close'),
      flush: true,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Prototip sırası: none, 15m, 1h, 1d (sheets.js:70).
          for (final option in ReminderOption.values)
            GuOptionRow(
              key: keyOf(option),
              label: labelOf(l10n, option),
              selected: option == current,
              onTap: () => context.pop(option),
            ),
        ],
      ),
    );
  }
}
