import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_ui/gu_ui.dart';

/// DLG-19 "{name} çıkarılsın mı?" — üyeyi kulüpten çıkarma onayı
/// (`dialogs.js:35`; referans `design/reference-shots/dialogs/DLG-19__*.webp`).
///
/// * İkon `user-x` (`danger`), başlık üyenin adını ([name]) taşır, gövde
///   "Üyelikten çıkarılacak ve bilgilendirilecek…".
/// * Özel gövde: "Neden (isteğe bağlı)" çok satırlı girdi (2 satır, en çok
///   `Limits.rejectNoteMax`; sayaç yok — prototip `counter` vermez).
/// * "Üyeyi çıkar" (`danger`) rotayı kırpılmış nedenle (boş olabilir) kapatır;
///   "Vazgeç", scrim ve geri `null` bırakır. Yazma (M9 `removeMember`,
///   `rejectNote`) ve TST-47 "Geri al" çağırandadır.
/// * Anahtarlar `DLG-19.reason`, `DLG-19.confirm`, `DLG-19.cancel`
///   (+ `DLG-19.scrim`, `FeedbackService`).
///
/// Girdili olduğu için `DialogCatalog` kaydı yoktur; [show] ile açılır.
/// Katalog dışındadır (`catalogs/dialogs` değil): sınıf izi ve `DialogId`
/// kullanımı burada sayılır (`check_design_coverage` IZ01 / KUL01).
///
/// Design: DLG-19
class RemoveMemberDialog extends ConsumerStatefulWidget {
  /// [name] adlı üyeyi çıkarma onayı.
  const RemoveMemberDialog({required this.name, super.key});

  /// Çıkarılacak üyenin görünen adı.
  final String name;

  /// Neden girdisinin anahtarı (`DLG-19.reason`).
  static final Key reasonKey = GuKey.action('DLG-19.reason');

  /// "Üyeyi çıkar" düğmesinin anahtarı (`DLG-19.confirm`).
  static final Key confirmKey = GuKey.action('DLG-19.confirm');

  /// "Vazgeç" düğmesinin anahtarı (`DLG-19.cancel`).
  static final Key cancelKey = GuKey.action('DLG-19.cancel');

  /// DLG-19'u [feedback] üzerinden açar. Sonuç: onaylandıysa kırpılmış neden
  /// (boş olabilir), vazgeçildiyse `null`.
  static Future<String?> show(
    FeedbackService feedback, {
    required String name,
  }) => feedback.showDialog<String>(
    DialogId.dlg19,
    builder: (_) => RemoveMemberDialog(name: name),
  );

  @override
  ConsumerState<RemoveMemberDialog> createState() => _RemoveMemberDialogState();
}

class _RemoveMemberDialogState extends ConsumerState<RemoveMemberDialog> {
  /// `rows=${2}` (`dialogs.js:35`).
  static const int _reasonRows = 2;

  String _reason = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GuDialogFrame(
      title: l10n.dlg19Title(widget.name),
      body: l10n.dlg19Body,
      icon: GuIcons.userX,
      danger: true,
      actions: [
        GuButton(
          key: RemoveMemberDialog.confirmKey,
          label: l10n.dlg19Confirm,
          variant: GuButtonVariant.danger,
          onPressed: () => Navigator.of(context).pop(_reason.trim()),
        ),
        GuButton(
          key: RemoveMemberDialog.cancelKey,
          label: l10n.commonGiveUp,
          variant: GuButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      child: GuInput(
        label: l10n.dlg19Reason,
        multiline: true,
        rows: _reasonRows,
        maxLength: Limits.rejectNoteMax,
        onChanged: (v) => _reason = v,
        actionKey: RemoveMemberDialog.reasonKey,
      ),
    );
  }
}
