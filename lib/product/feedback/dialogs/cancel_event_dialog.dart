import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/l10n/cancel_reason_labels.dart';
import 'package:gu_kulupler/product/widget/form/form_error_line.dart';
import 'package:gu_ui/gu_ui.dart';

/// DLG-23 "Etkinlik iptal edilsin mi?" — yayındaki etkinliği iptal onayı
/// (`dialogs.js:40–41`; referans `design/reference-shots/dialogs/DLG-23__*`).
///
/// * İkon `calendar-x` (`danger`); gövde "{count} kayıtlı katılımcıya iptal
///   bildirimi gidecek. Bu işlem geri alınamaz." ([count] = `goingCount`).
/// * Özel gövde: dört neden satırı (`OptionRow` radyo; sıra [reasons],
///   adları `CancelReasonLabels`), kap `margin:0 -12px` — satırlar içerik
///   genişliğini her yandan 12 aşar. Neden seçilmeden "Etkinliği iptal et" →
///   "Bu alan zorunlu" (`field-help is-error`); seçim hatayı siler.
/// * "Etkinliği iptal et" (`danger`) rotayı seçilen nedenin kimliğiyle
///   (`events.cancelReason`: `weather` · `speaker` · `venue` · `other`)
///   kapatır; "Vazgeç", scrim ve geri `null` bırakır. Yazım
///   (`ManagementRepository.cancelEvent` + bildirim) ve TST-48 çağırandadır
///   (`ManageEventActionsMixin.cancelEvent`).
/// * Anahtarlar `DLG-23.reason.<id>`, `DLG-23.confirm`, `DLG-23.cancel`
///   (+ `DLG-23.scrim`, `FeedbackService`).
///
/// Seçenekli olduğu için `DialogCatalog` kaydı yoktur; [show] ile açılır.
///
/// Design: DLG-23
class CancelEventDialog extends ConsumerStatefulWidget {
  /// [count] kayıtlısı olan etkinliğin iptal onayı.
  const CancelEventDialog({required this.count, super.key});

  /// Kayıtlı katılımcı sayısı (gövde).
  final int count;

  /// Neden kimlikleri, tasarım sırasıyla (`dialogs.js:41`).
  static const List<String> reasons = ['weather', 'speaker', 'venue', 'other'];

  /// [reason] satırının anahtarı (`DLG-23.reason.<id>`).
  static Key reasonKey(String reason) => switch (reason) {
    'weather' => GuKey.action('DLG-23.reason.weather'),
    'speaker' => GuKey.action('DLG-23.reason.speaker'),
    'venue' => GuKey.action('DLG-23.reason.venue'),
    _ => GuKey.action('DLG-23.reason.other'),
  };

  /// "Etkinliği iptal et" düğmesinin anahtarı (`DLG-23.confirm`).
  static final Key confirmKey = GuKey.action('DLG-23.confirm');

  /// "Vazgeç" düğmesinin anahtarı (`DLG-23.cancel`).
  static final Key cancelKey = GuKey.action('DLG-23.cancel');

  /// DLG-23'ü [feedback] üzerinden açar. Sonuç: onaylandıysa neden kimliği,
  /// vazgeçildiyse `null`.
  static Future<String?> show(FeedbackService feedback, {required int count}) =>
      feedback.showDialog<String>(
        DialogId.dlg23,
        builder: (_) => CancelEventDialog(count: count),
      );

  @override
  ConsumerState<CancelEventDialog> createState() => _CancelEventDialogState();
}

class _CancelEventDialogState extends ConsumerState<CancelEventDialog> {
  /// `margin:0 -12px` (`dialogs.js:41`): satırların her yandan taşması.
  static const double _bleed = GuSpacing.s12;

  String? _reason;
  bool _showError = false;

  void _select(String reason) => setState(() {
    _reason = reason;
    _showError = false;
  });

  void _confirm() {
    final reason = _reason;
    if (reason == null) {
      setState(() => _showError = true);
      return;
    }
    Navigator.of(context).pop(reason);
  }

  Widget _options(AppLocalizations l10n) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth + 2 * _bleed;
      return OverflowBox(
        fit: OverflowBoxFit.deferToChild,
        minWidth: width,
        maxWidth: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final reason in CancelEventDialog.reasons)
              GuOptionRow(
                key: CancelEventDialog.reasonKey(reason),
                label: CancelReasonLabels.of(l10n, reason) ?? reason,
                selected: _reason == reason,
                onTap: () => _select(reason),
              ),
          ],
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GuDialogFrame(
      title: l10n.dlg23Title,
      body: l10n.dlg23Body(widget.count),
      icon: GuIcons.calendarX,
      danger: true,
      actions: [
        GuButton(
          key: CancelEventDialog.confirmKey,
          label: l10n.dlg23Confirm,
          variant: GuButtonVariant.danger,
          onPressed: _confirm,
        ),
        GuButton(
          key: CancelEventDialog.cancelKey,
          label: l10n.commonGiveUp,
          variant: GuButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _options(l10n),
          if (_showError) FormErrorLine(l10n.authErrRequired),
        ],
      ),
    );
  }
}
