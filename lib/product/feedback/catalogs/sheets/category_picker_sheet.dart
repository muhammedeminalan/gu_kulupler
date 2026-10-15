import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/l10n/static_labels.dart';
import 'package:gu_kulupler/product/widget/club/cover_mapper.dart';
import 'package:gu_ui/gu_ui.dart';

/// SHT-33 "Kategori seç" — sekiz kulüp kategorisi, tek seçim (prototip
/// `SHEETS['SHT-33']`, `sheets.js:154`). MGT-09 ve ADM-03 açar.
///
/// * Çerçeve dolgusuzdur (`flush`); seçenekler `StaticTables.categories`
///   sırasıyla (`k01`–`k08`), her satırda küçük amblem (`emblem is-xs`,
///   ikon 16) + kategori adı.
/// * Seçili kategori ([selected]) `GuRadio` ile gösterilir.
/// * Dokunma sayfayı seçilen kategorinin kimliğiyle kapatır
///   (`pop(String)`); X / scrim / sürükleme / geri → `null`.
/// * Anahtarlar `SHT-33.select.<kategori kimliği>`, `SHT-33.close`
///   (+ `SHT-33.scrim`, `FeedbackService`).
///
/// ```dart
/// final categoryId = await feedback.showSheet<String>(
///   SheetId.sht33,
///   builder: (_) => CategoryPickerSheet(selected: state.categoryId),
/// );
/// ```
///
/// Design: SHT-33
class CategoryPickerSheet extends StatelessWidget {
  /// Kategori seçimi; [selected] seçili kategorinin kimliği ya da `null`.
  const CategoryPickerSheet({this.selected, super.key});

  /// Seçili kategorinin kimliği (`clubs.categoryId`).
  final String? selected;

  /// Kayıtta olmayan kategori ikonunun yedeği (amblem boş çizilmez).
  static const GuIcons _fallbackIcon = GuIcons.users;

  /// [categoryId] seçeneğinin anahtarı (`SHT-33.select.<kimlik>`).
  static Key keyOf(String categoryId) =>
      FeedbackKeys.of(SheetId.sht33.designId, 'select.$categoryId');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GuSheetFrame(
      title: l10n.sht33Title,
      closeSemanticLabel: l10n.a11yClose,
      closeKey: FeedbackKeys.of(SheetId.sht33.designId, 'close'),
      flush: true,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final category in StaticTables.categories)
            GuOptionRow(
              key: keyOf(category.id),
              label: StaticLabels.category(context, category.id),
              selected: category.id == selected,
              leading: GuEmblem(
                icon: CoverMapper.icon(category.icon) ?? _fallbackIcon,
                size: GuEmblemSize.xs,
              ),
              onTap: () => Navigator.of(context).pop(category.id),
            ),
        ],
      ),
    );
  }
}
