import 'package:flutter/widgets.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_ui/gu_ui.dart';

/// DLG-25 "Değişiklikler kaydedilmedi" dialogunun sonucu.
enum UnsavedChangesResult {
  /// "Kaydet" — çağıran kaydeder, başarılıysa ekranı kapatır.
  save,

  /// "Kaydetmeden çık" — değişiklikler atılır.
  discard,

  /// "Düzenlemeye devam et" — ekran açık kalır (scrim / geri de böyle
  /// yorumlanır: sonuç `null`).
  keep,
}

/// DLG-25 "Değişiklikler kaydedilmedi" — üç eylemli onay (`dialogs.js:43`;
/// referans `design/reference-shots/dialogs/DLG-25__light.webp`).
///
/// Eylemler: "Kaydet" (birincil; yalnızca [hasSave] ise — prototip `p.onSave`
/// yoksa çizmez: AUT-05, ADM-03 ve kirli sheet'ler), "Kaydetmeden çık"
/// (`dangerOutline`), "Düzenlemeye devam et" (metin). Her eylem rotayı kendi
/// [UnsavedChangesResult] değeriyle kapatır.
///
/// Üç eylemli olduğu için `DialogCatalog` kaydı yoktur; kurucuyla açılır:
/// ekranlarda `UnsavedChangesMixin`, sheet'lerde `showUnsavedChangesDialog`
/// (`lib/product/mixin/unsaved_changes_mixin.dart`).
class UnsavedChangesDialog extends StatelessWidget {
  const UnsavedChangesDialog({this.hasSave = false, super.key});

  /// "Kaydet" eylemi çizilsin mi?
  final bool hasSave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final designId = DialogId.dlg25.designId;
    void close(UnsavedChangesResult result) =>
        Navigator.of(context).pop(result);
    return GuDialogFrame(
      title: l10n.dlg25Title,
      body: l10n.dlg25Body,
      icon: GuIcons.triangleAlert,
      actions: [
        if (hasSave)
          GuButton(
            key: FeedbackKeys.of(designId, 'save'),
            label: l10n.commonSave,
            onPressed: () => close(UnsavedChangesResult.save),
          ),
        GuButton(
          key: FeedbackKeys.of(designId, 'discard'),
          label: l10n.dlg25Discard,
          variant: GuButtonVariant.dangerOutline,
          onPressed: () => close(UnsavedChangesResult.discard),
        ),
        GuButton(
          key: FeedbackKeys.of(designId, 'keep'),
          label: l10n.dlg25Keep,
          variant: GuButtonVariant.text,
          onPressed: () => close(UnsavedChangesResult.keep),
        ),
      ],
    );
  }
}
