import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_ui/gu_ui.dart';

/// DLG-21 "Başkanlığı devret?" — iki adımlı devir onayı (`dialogs.js:37–38`;
/// referans `design/reference-shots/dialogs/DLG-21__*.webp`). SHT-25'te aday
/// seçildikten sonra açılır (MGT-03 "Başkanlığı devret", DLG-09, SET-03).
///
/// * İkon `crown` (`danger`), başlık "Başkanlığı devret?".
/// * **1. adım:** gövde "Başkanlığı {name} kullanıcısına devretmek üzeresin.
///   Sen Yönetim Kurulu üyesi olacaksın…" (eski başkan yönetim kuruluna
///   geçer); "Devam" (`danger`, `DLG-21.next`) → 2. adım.
/// * **2. adım:** gövde "Onaylamak için DEVRET yaz." + girdi (`DLG-21.word`,
///   yer tutucu "DEVRET", otomatik odak). "Devret" (`danger`,
///   `DLG-21.confirm`) yalnızca [matches] iken etkindir; devre dışıyken
///   dokunuş TST-X20 gösterir.
/// * "Devret" rotayı `true`, "Vazgeç" (`DLG-21.cancel`) `false` ile kapatır;
///   scrim / geri `null`. Yazma (M11 `transferPresidency`) ve TST-49
///   çağırandadır.
///
/// Adımlı ve girdili olduğu için `DialogCatalog` kaydı yoktur; [show] ile
/// açılır. Katalog dışındadır (`catalogs/dialogs` değil): sınıf izi ve
/// TST-X20 kullanımı burada sayılır (`check_design_coverage` IZ01 / KUL01).
///
/// Design: DLG-21
class TransferPresidencyDialog extends ConsumerStatefulWidget {
  /// Başkanlığı [name] adlı üyeye devretme onayı.
  const TransferPresidencyDialog({required this.name, super.key});

  /// Yeni başkanın görünen adı.
  final String name;

  /// "Devam" düğmesinin anahtarı (`DLG-21.next`).
  static final Key nextKey = GuKey.action('DLG-21.next');

  /// Onay sözcüğü girdisinin anahtarı (`DLG-21.word`).
  static final Key wordKey = GuKey.action('DLG-21.word');

  /// "Devret" düğmesinin anahtarı (`DLG-21.confirm`).
  static final Key confirmKey = GuKey.action('DLG-21.confirm');

  /// "Vazgeç" düğmesinin anahtarı (`DLG-21.cancel`).
  static final Key cancelKey = GuKey.action('DLG-21.cancel');

  /// [word] onay sözcüğüyle ([expected] — ARB `dlg21Word`, "DEVRET") **tam**
  /// eşleşiyor mu: girdi kırpılır ve Türkçe kurallarla büyük harfe çevrilir
  /// (prototip `word.trim().toLocaleUpperCase('tr') === 'DEVRET'`; `i → İ`,
  /// `ı → I`).
  static bool matches(String word, String expected) =>
      word.trim().trUpper() == expected;

  /// DLG-21'i [feedback] üzerinden açar. Sonuç `true` → devir onaylandı.
  static Future<bool> show(
    FeedbackService feedback, {
    required String name,
  }) async =>
      await feedback.showDialog<bool>(
        DialogId.dlg21,
        builder: (_) => TransferPresidencyDialog(name: name),
      ) ??
      false;

  @override
  ConsumerState<TransferPresidencyDialog> createState() =>
      _TransferPresidencyDialogState();
}

class _TransferPresidencyDialogState
    extends ConsumerState<TransferPresidencyDialog> {
  bool _typing = false;
  String _word = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ok = TransferPresidencyDialog.matches(_word, l10n.dlg21Word);
    return GuDialogFrame(
      title: l10n.dlg21Title,
      body: _typing ? l10n.dlg21Body2 : l10n.dlg21Body1(widget.name),
      icon: GuIcons.crown,
      danger: true,
      actions: [
        if (!_typing)
          GuButton(
            key: TransferPresidencyDialog.nextKey,
            label: l10n.commonContinue,
            variant: GuButtonVariant.danger,
            onPressed: () => setState(() => _typing = true),
          )
        else
          GuButton(
            key: TransferPresidencyDialog.confirmKey,
            label: l10n.dlg21Confirm,
            variant: GuButtonVariant.danger,
            disabled: !ok,
            onDisabledPressed: () =>
                ref.read(feedbackServiceProvider).showToast(ToastId.tstX20),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        GuButton(
          key: TransferPresidencyDialog.cancelKey,
          label: l10n.commonGiveUp,
          variant: GuButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
      child: _typing
          ? GuInput(
              placeholder: l10n.dlg21Word,
              semanticLabel: l10n.dlg21Body2,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onChanged: (v) => setState(() => _word = v),
              actionKey: TransferPresidencyDialog.wordKey,
            )
          : null,
    );
  }
}
