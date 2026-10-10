import 'package:flutter/widgets.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_ui/gu_ui.dart';

/// [DialogSpec] kaydını `GuDialogFrame`'e çeviren standart dialog gövdesi.
///
/// Birincil düğme rotayı `true`, ikincil düğme `false` ile kapatır; scrim /
/// geri tuşu `null` bırakır. Düğme anahtarları `<ID>.<sonek>`
/// (`DLG-07.confirm`, `DLG-07.cancel`).
class SpecDialog extends StatelessWidget {
  const SpecDialog({
    required this.id,
    required this.spec,
    this.params = const <String, Object>{},
    super.key,
  });

  /// Dialog kimliği (anahtar öneki).
  final DialogId id;

  /// Katalog kaydı.
  final DialogSpec spec;

  /// Metin değişkenleri.
  final DialogParams params;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final secondary = spec.secondary;
    return GuDialogFrame(
      title: spec.title(l10n, params),
      body: spec.body?.call(l10n, params),
      icon: spec.icon,
      danger: spec.destructive,
      dismissable: spec.dismissible,
      actions: [
        GuButton(
          key: FeedbackKeys.of(id.designId, spec.primaryAction),
          label: spec.primary(l10n),
          variant: spec.destructive
              ? GuButtonVariant.danger
              : GuButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        if (secondary != null)
          GuButton(
            key: FeedbackKeys.of(id.designId, spec.secondaryAction),
            label: secondary(l10n),
            variant: GuButtonVariant.text,
            onPressed: () => Navigator.of(context).pop(false),
          ),
      ],
    );
  }
}
