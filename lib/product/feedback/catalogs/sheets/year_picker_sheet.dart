import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/l10n/static_labels.dart';
import 'package:gu_ui/gu_ui.dart';

/// SHT-03 "Sınıf seç" — sekiz öğrenim düzeyi, tek seçim (prototip
/// `SHEETS['SHT-03']`, `sheets.js:18`). AUT-05 ve PRF-02 açar.
///
/// * Çerçeve dolgusuzdur (`flush`); seçenekler [YearLevel] bildirim sırasıyla
///   (Hazırlık, 1.–4. sınıf, 5+, Yüksek lisans, Doktora).
/// * Seçili düzey ([value]) `GuRadio` ile gösterilir.
/// * Dokunma sayfayı seçilen düzeyle kapatır (`pop(YearLevel)`); X / scrim /
///   sürükleme / geri → `null`.
/// * Anahtarlar `SHT-03.select.<düzey>` (`YearLevel.json`: `prep`, `1` …
///   `5plus`, `master`, `phd`), `SHT-03.close` (+ `SHT-03.scrim`,
///   `FeedbackService`).
///
/// ```dart
/// final year = await feedback.showSheet<YearLevel>(
///   SheetId.sht03,
///   builder: (_) => YearPickerSheet(value: state.year),
/// );
/// ```
///
/// Design: SHT-03
class YearPickerSheet extends StatelessWidget {
  /// Sınıf seçimi; [value] seçili düzey ya da `null`.
  const YearPickerSheet({this.value, super.key});

  /// Seçili düzey.
  final YearLevel? value;

  /// [year] seçeneğinin anahtarı (`SHT-03.select.<düzey>`).
  static Key keyOf(YearLevel year) =>
      FeedbackKeys.of(SheetId.sht03.designId, 'select.${year.json}');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GuSheetFrame(
      title: l10n.sht03Title,
      closeSemanticLabel: l10n.a11yClose,
      closeKey: FeedbackKeys.of(SheetId.sht03.designId, 'close'),
      flush: true,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final year in YearLevel.values)
            GuOptionRow(
              key: keyOf(year),
              label: StaticLabels.year(context, year),
              selected: year == value,
              onTap: () => Navigator.of(context).pop(year),
            ),
        ],
      ),
    );
  }
}
