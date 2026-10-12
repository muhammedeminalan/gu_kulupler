import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/l10n/static_labels.dart';
import 'package:gu_ui/gu_ui.dart';

/// SHT-02 "Bölüm seç" — arama + fakülte grupları + tek seçim (prototip
/// `SHEETS['SHT-02']`, `sheets.js:15–16`). AUT-05 ve PRF-02 açar.
///
/// * Çerçeve tam yükseklik (`full`) ve dolgusuzdur (`flush`).
/// * Arama alanı (dolgu 0 / 16 / 16) açılışta odağı alır; bölüm adında
///   **o anki dilde** büyük/küçük harf duyarsız arar (Türkçede `I ↔ ı`,
///   `İ ↔ i`).
/// * Bölümler `StaticTables.faculties` sırasıyla gruplanır; eşleşmesi olmayan
///   fakülte çizilmez. Grup başlığı overline + büyük harftir; zemini sheet
///   yüzeyidir (`bg.surfaceRaised`).
/// * Seçili bölüm ([value]) kendi grubunun başına alınır; seçim `GuRadio`
///   ile gösterilir.
/// * Eşleşme yoksa "Bölüm bulunamadı" (bodyS, `text.muted`, ortalı, dolgu 16).
/// * Dokunma sayfayı bölüm kimliğiyle kapatır (`pop(String)`); X / scrim /
///   sürükleme / geri → `null`.
/// * Anahtarlar `SHT-02.search`, `SHT-02.select.<bölüm>`, `SHT-02.close`
///   (+ `SHT-02.scrim`, `FeedbackService`).
///
/// ```dart
/// final id = await feedback.showSheet<String>(
///   SheetId.sht02,
///   builder: (_) => DepartmentPickerSheet(value: state.departmentId),
/// );
/// ```
///
/// Design: SHT-02
class DepartmentPickerSheet extends ConsumerStatefulWidget {
  /// Bölüm seçimi; [value] seçili bölümün kimliği (`d01`–`d24`) ya da `null`.
  const DepartmentPickerSheet({this.value, super.key});

  /// Seçili bölüm kimliği.
  final String? value;

  /// Arama alanının anahtarı (`SHT-02.search`).
  static final Key searchKey = FeedbackKeys.of(
    SheetId.sht02.designId,
    'search',
  );

  /// [departmentId] seçeneğinin anahtarı (`SHT-02.select.<bölüm>`).
  static Key keyOf(String departmentId) =>
      FeedbackKeys.of(SheetId.sht02.designId, 'select.$departmentId');

  @override
  ConsumerState<DepartmentPickerSheet> createState() =>
      _DepartmentPickerSheetState();
}

class _DepartmentPickerSheetState extends ConsumerState<DepartmentPickerSheet> {
  String _query = '';

  /// Karşılaştırma biçimi: Türkçede `toLocaleLowerCase('tr')`, diğer dillerde
  /// yerelden bağımsız küçük harf.
  String _fold(String text, Locale locale) =>
      locale.languageCode == 'tr' ? text.trLower() : text.toLowerCase();

  /// Aramaya uyan bölümler, fakülte sırasıyla gruplanmış; seçili bölüm kendi
  /// grubunun başında (`sheets.js:15`).
  List<({String facultyId, List<String> departmentIds})> _groups(
    BuildContext context,
  ) {
    final locale = Localizations.localeOf(context);
    final needle = _fold(_query.trim(), locale);
    final selected = widget.value;
    final groups = <({String facultyId, List<String> departmentIds})>[];
    for (final faculty in StaticTables.faculties) {
      final ids = [
        for (final department in StaticTables.departmentsOf(faculty.id))
          if (needle.isEmpty ||
              _fold(
                StaticLabels.department(context, department.id),
                locale,
              ).contains(needle))
            department.id,
      ];
      if (ids.isEmpty) continue;
      if (selected != null && ids.remove(selected)) ids.insert(0, selected);
      groups.add((facultyId: faculty.id, departmentIds: ids));
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final groups = _groups(context);
    return GuSheetFrame(
      title: l10n.sht02Title,
      closeSemanticLabel: l10n.a11yClose,
      closeKey: FeedbackKeys.of(SheetId.sht02.designId, 'close'),
      full: true,
      flush: true,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: GuInsets.only(
              left: GuSpacing.s16,
              right: GuSpacing.s16,
              bottom: GuSpacing.s16,
            ),
            child: GuSearchField(
              value: _query,
              onChanged: (value) => setState(() => _query = value),
              placeholder: l10n.commonSearch,
              semanticLabel: l10n.commonSearch,
              autofocus: true,
              actionKey: DepartmentPickerSheet.searchKey,
            ),
          ),
          if (groups.isEmpty)
            Padding(
              padding: GuInsets.all16,
              child: Text(
                l10n.sht02Empty,
                textAlign: TextAlign.center,
                style: gu.text.bodyS.copyWith(color: gu.colors.textMuted),
              ),
            )
          else
            for (final group in groups) ...[
              // Zemin sheet yüzeyi (`sheets.js:16`
              // `background:var(--bg-surface-raised)`).
              GuGroupHeader(
                title: StaticLabels.faculty(
                  context,
                  group.facultyId,
                ).upperFor(locale),
                color: context.gu.colors.bgSurfaceRaised,
              ),
              for (final id in group.departmentIds)
                GuOptionRow(
                  key: DepartmentPickerSheet.keyOf(id),
                  label: StaticLabels.department(context, id),
                  selected: id == widget.value,
                  onTap: () => Navigator.of(context).pop(id),
                ),
            ],
        ],
      ),
    );
  }
}
