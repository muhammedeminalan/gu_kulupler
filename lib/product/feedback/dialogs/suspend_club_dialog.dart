import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_ui/gu_ui.dart';

/// DLG-28 "{club} askıya alınsın mı?" / "{club} etkinleştirilsin mi?" —
/// kulübü askıya alma ya da yeniden etkinleştirme onayı (`dialogs.js:46–47`;
/// referans `design/reference-shots/dialogs/DLG-28__*.webp`). ADM-02 satır
/// menüsü ve ADM-04 SHT-26 "Kulübü askıya al" (T-40) açar.
///
/// * Askıya alma ([suspending]): ikon `ban` (`danger`), gövde "Kulüp listede
///   görünmez…", "Neden" çok satırlı girdi (2 satır, otomatik odak) —
///   **zorunlu**: boşken "Askıya al" kapanmaz, girdi "Bu alan zorunlu"
///   hatasını gösterir; sınır `Limits.adminReasonMax` (CD-30; aşımda sayaç
///   kırmızı, kapanmaz). Birincil düğme `danger`.
/// * Etkinleştirme: ikon `circle-check`, gövde "Kulüp yeniden listelenir…",
///   girdi yok; birincil düğme `primary` "Etkinleştir".
/// * Sonuç: onay → kırpılmış neden (etkinleştirmede boş metin); "Vazgeç",
///   scrim ve geri → `null`. Yazım (`suspendClub` / `activateClub`) ve TST-50
///   çağırandadır.
/// * Anahtarlar `DLG-28.reason`, `DLG-28.confirm`, `DLG-28.cancel`
///   (+ `DLG-28.scrim`, `FeedbackService`).
///
/// Girdili olduğu için `DialogCatalog` kaydı yoktur; [show] ile açılır
/// (`RemoveMemberDialog` kalıbı).
///
/// Design: DLG-28
class SuspendClubDialog extends ConsumerStatefulWidget {
  /// [clubName] kulübünün askı ([suspending]) ya da etkinleştirme onayı.
  const SuspendClubDialog({
    required this.clubName,
    required this.suspending,
    super.key,
  });

  /// Kulübün görünen adı (başlıktaki `{club}`).
  final String clubName;

  /// `true` → askıya alma; `false` → etkinleştirme.
  final bool suspending;

  /// Neden girdisinin anahtarı (`DLG-28.reason`).
  static final Key reasonKey = GuKey.action('DLG-28.reason');

  /// Birincil düğmenin anahtarı (`DLG-28.confirm`).
  static final Key confirmKey = GuKey.action('DLG-28.confirm');

  /// "Vazgeç" düğmesinin anahtarı (`DLG-28.cancel`).
  static final Key cancelKey = GuKey.action('DLG-28.cancel');

  /// DLG-28'i [feedback] üzerinden açar. Sonuç: onaylandıysa kırpılmış neden
  /// (etkinleştirmede `''`), vazgeçildiyse `null`.
  static Future<String?> show(
    FeedbackService feedback, {
    required String clubName,
    required bool suspending,
  }) => feedback.showDialog<String>(
    DialogId.dlg28,
    builder: (_) =>
        SuspendClubDialog(clubName: clubName, suspending: suspending),
  );

  @override
  ConsumerState<SuspendClubDialog> createState() => _SuspendClubDialogState();
}

class _SuspendClubDialogState extends ConsumerState<SuspendClubDialog> {
  /// `rows=${2}` (`dialogs.js:47`).
  static const int _reasonRows = 2;

  String _reason = '';

  bool _showRequired = false;

  void _confirm() {
    final reason = _reason.trim();
    if (widget.suspending) {
      switch (FieldValidators.adminReason(reason)) {
        case FieldError.empty || FieldError.tooShort:
          setState(() => _showRequired = true);
          return;
        case null:
          break;
        case _:
          // Sınır aşımı: sayaç kırmızı; kapanmaz.
          return;
      }
    }
    Navigator.of(context).pop(widget.suspending ? reason : '');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final suspending = widget.suspending;
    return GuDialogFrame(
      title: suspending
          ? l10n.dlg28Title(widget.clubName)
          : l10n.dlg28TitleActivate(widget.clubName),
      body: suspending ? l10n.dlg28Body : l10n.dlg28BodyActivate,
      icon: suspending ? GuIcons.ban : GuIcons.circleCheck,
      danger: suspending,
      actions: [
        GuButton(
          key: SuspendClubDialog.confirmKey,
          label: suspending ? l10n.adminClubsSuspend : l10n.adminClubsActivate,
          variant: suspending
              ? GuButtonVariant.danger
              : GuButtonVariant.primary,
          onPressed: _confirm,
        ),
        GuButton(
          key: SuspendClubDialog.cancelKey,
          label: l10n.commonGiveUp,
          variant: GuButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      child: suspending
          ? GuInput(
              label: l10n.dlg28Reason,
              multiline: true,
              rows: _reasonRows,
              maxLength: Limits.adminReasonMax,
              showCounter: true,
              autofocus: true,
              errorText: _showRequired ? l10n.authErrRequired : null,
              onChanged: (v) {
                _reason = v;
                if (_showRequired) setState(() => _showRequired = false);
              },
              actionKey: SuspendClubDialog.reasonKey,
            )
          : null,
    );
  }
}
