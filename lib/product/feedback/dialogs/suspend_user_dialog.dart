import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_ui/gu_ui.dart';

/// DLG-30 "{name} askıya alınsın mı?" / "{name} askıdan çıkarılsın mı?" —
/// kullanıcı hesabını askıya alma ya da askıdan çıkarma onayı
/// (`dialogs.js:49–50`; referans `design/reference-shots/dialogs/DLG-30__*
/// .webp`). ADM-04 SHT-26 "Kullanıcıyı askıya al" (T-40) ve ADM-05 satır
/// menüsü (T-41) açar.
///
/// * Askıya alma ([suspending]): ikon `ban` (`danger`), gövde "Kullanıcı
///   giriş yapamaz…", "Neden" çok satırlı girdi (2 satır, otomatik odak) —
///   **zorunlu**: boşken "Askıya al" kapanmaz, girdi "Bu alan zorunlu"
///   hatasını gösterir; sınır `Limits.adminReasonMax` (aşımda sayaç kırmızı,
///   kapanmaz). Birincil düğme `danger`.
/// * Askıdan çıkarma: ikon `circle-check`, gövde "Kullanıcı yeniden giriş
///   yapabilir…", girdi yok; birincil düğme `primary` "Askıyı kaldır".
/// * Sonuç: onay → kırpılmış neden (askıdan çıkarmada boş metin); "Vazgeç",
///   scrim ve geri → `null`. Yazım (`suspendUser` / `activateUser`,
///   gerekirse `resolveReports(suspended)`) ve TST-52 çağırandadır.
/// * Anahtarlar `DLG-30.reason`, `DLG-30.confirm`, `DLG-30.cancel`
///   (+ `DLG-30.scrim`, `FeedbackService`).
///
/// Girdili olduğu için `DialogCatalog` kaydı yoktur; [show] ile açılır
/// (`SuspendClubDialog` kalıbı).
///
/// Design: DLG-30
class SuspendUserDialog extends ConsumerStatefulWidget {
  /// [userName] kullanıcısının askı ([suspending]) ya da askıdan çıkarma
  /// onayı.
  const SuspendUserDialog({
    required this.userName,
    required this.suspending,
    super.key,
  });

  /// Kullanıcının görünen adı (başlıktaki `{name}`).
  final String userName;

  /// `true` → askıya alma; `false` → askıdan çıkarma.
  final bool suspending;

  /// Neden girdisinin anahtarı (`DLG-30.reason`).
  static final Key reasonKey = GuKey.action('DLG-30.reason');

  /// Birincil düğmenin anahtarı (`DLG-30.confirm`).
  static final Key confirmKey = GuKey.action('DLG-30.confirm');

  /// "Vazgeç" düğmesinin anahtarı (`DLG-30.cancel`).
  static final Key cancelKey = GuKey.action('DLG-30.cancel');

  /// DLG-30'u [feedback] üzerinden açar. Sonuç: onaylandıysa kırpılmış neden
  /// (askıdan çıkarmada `''`), vazgeçildiyse `null`.
  static Future<String?> show(
    FeedbackService feedback, {
    required String userName,
    required bool suspending,
  }) => feedback.showDialog<String>(
    DialogId.dlg30,
    builder: (_) =>
        SuspendUserDialog(userName: userName, suspending: suspending),
  );

  @override
  ConsumerState<SuspendUserDialog> createState() => _SuspendUserDialogState();
}

class _SuspendUserDialogState extends ConsumerState<SuspendUserDialog> {
  /// `rows=${2}` (`dialogs.js:50`).
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
          ? l10n.dlg30Title(widget.userName)
          : l10n.dlg30TitleUnsuspend(widget.userName),
      body: suspending ? l10n.dlg30Body : l10n.dlg30BodyUnsuspend,
      icon: suspending ? GuIcons.ban : GuIcons.circleCheck,
      danger: suspending,
      actions: [
        GuButton(
          key: SuspendUserDialog.confirmKey,
          label: suspending ? l10n.adminUsersSuspend : l10n.adminUsersUnsuspend,
          variant: suspending
              ? GuButtonVariant.danger
              : GuButtonVariant.primary,
          onPressed: _confirm,
        ),
        GuButton(
          key: SuspendUserDialog.cancelKey,
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
              actionKey: SuspendUserDialog.reasonKey,
            )
          : null,
    );
  }
}
