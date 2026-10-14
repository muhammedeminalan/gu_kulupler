import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/l10n/reject_reason_labels.dart';
import 'package:gu_ui/gu_ui.dart';

/// SHT-20'nin `pop` değeri: seçilen ret nedeni + isteğe bağlı açıklama
/// (kırpılmış; boş → `null`). Başvurana gösterilir (`rejectNote`).
typedef RejectDecision = (RejectReason reason, String? note);

/// SHT-20 "Red nedeni" — MGT-02 satırındaki "Reddet" ve SHT-19 "Reddet" açar
/// (prototip `SHEETS['SHT-20']`, `sheets.js:98–101`).
///
/// * Gövde (`col gap12 pb16`): başvuranın adı ([applicantName], `bodyS`
///   `text.secondary`); neden çipleri (`rejectReason*` ARB, `RejectReason`
///   sırası: kontenjan / koşullar / eksik bilgi / diğer; varsayılan
///   [RejectReason.quota]; `row wrap gap8`); "Açıklama (isteğe bağlı)" çok
///   satırlı alan (en çok `Limits.rejectNoteMax` = 200 karakter — fazlası
///   kesilir, sayaç %80'den sonra; yardım "Neden başvurana gösterilir.").
/// * Alt çubuk: "Reddet" (danger) → [RejectDecision] ile `pop`. X / scrim /
///   sürükleme / geri → `null`. Yazmayı çağıran yürütür
///   (`ManageApplicationsViewModel.reject`, TST-28).
/// * Anahtarlar `SHT-20.reason.<quota|criteria|missing|other>`,
///   `SHT-20.note`, `SHT-20.submit`, `SHT-20.close` (+ `SHT-20.scrim`).
///
/// ```dart
/// final decision = await feedback.showSheet<RejectDecision>(
///   SheetId.sht20,
///   builder: (_) => RejectReasonSheet(applicantName: m.applicant.name),
/// );
/// if (decision case (final reason, final note)) {
///   await viewModel.reject(m.userId, reason, note ?? '');
/// }
/// ```
///
/// Design: SHT-20
class RejectReasonSheet extends ConsumerStatefulWidget {
  /// [applicantName] başvuranının reddi için neden sayfası.
  const RejectReasonSheet({required this.applicantName, super.key});

  /// Başvuranın adı (gövdenin ilk satırı).
  final String applicantName;

  /// [reason] çipinin anahtarı (`SHT-20.reason.<neden>`).
  static Key reasonKey(RejectReason reason) =>
      GuKey.action('SHT-20.reason.${reason.json}');

  /// Açıklama alanının anahtarı (`SHT-20.note`).
  static final Key noteKey = GuKey.action('SHT-20.note');

  /// "Reddet" düğmesinin anahtarı (`SHT-20.submit`).
  static final Key submitKey = GuKey.action('SHT-20.submit');

  @override
  ConsumerState<RejectReasonSheet> createState() => _RejectReasonSheetState();
}

class _RejectReasonSheetState extends ConsumerState<RejectReasonSheet> {
  final TextEditingController _note = TextEditingController();
  RejectReason _reason = RejectReason.quota;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// `sheets.js:101` `setNote(v.slice(0, 200))`: sınırı aşan metin kesilir
  /// (yapıştırma dahil); yarım kalan vekil çift (emoji) bırakılmaz.
  void _onNoteChanged(String value) {
    const max = Limits.rejectNoteMax;
    if (value.length <= max) return;
    final unit = value.codeUnitAt(max - 1);
    final end = unit >= _highSurrogateStart && unit <= _highSurrogateEnd
        ? max - 1
        : max;
    final text = value.substring(0, end);
    _note.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// UTF-16 üst vekil aralığı (U+D800–U+DBFF).
  static const int _highSurrogateStart = 0xD800;
  static const int _highSurrogateEnd = 0xDBFF;

  void _submit() {
    final note = _note.text.trim();
    context.pop<RejectDecision>((_reason, note.isEmpty ? null : note));
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    return GuSheetFrame(
      title: l10n.sht20Title,
      closeSemanticLabel: l10n.a11yClose,
      closeKey: GuKey.action('SHT-20.close'),
      footer: [
        GuButton(
          key: RejectReasonSheet.submitKey,
          label: l10n.applicationsReject,
          variant: GuButtonVariant.danger,
          onPressed: _submit,
        ),
      ],
      body: Padding(
        padding: GuInsets.only(bottom: GuSpacing.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: GuSpacing.s12,
          children: [
            Text(
              widget.applicantName,
              style: gu.text.bodyS.copyWith(color: gu.colors.textSecondary),
            ),
            Wrap(
              spacing: GuSpacing.s8,
              runSpacing: GuSpacing.s8,
              children: [
                for (final reason in RejectReason.values)
                  GuChip(
                    key: RejectReasonSheet.reasonKey(reason),
                    label: RejectReasonLabels.of(l10n, reason),
                    selected: _reason == reason,
                    onTap: () => setState(() => _reason = reason),
                  ),
              ],
            ),
            GuInput(
              controller: _note,
              label: l10n.sht20Note,
              help: l10n.sht20Visible,
              multiline: true,
              rows: _noteRows,
              maxLength: Limits.rejectNoteMax,
              showCounter: true,
              actionKey: RejectReasonSheet.noteKey,
              onChanged: _onNoteChanged,
            ),
          ],
        ),
      ),
    );
  }

  /// `rows=${3}` (sheets.js:101).
  static const int _noteRows = 3;
}
