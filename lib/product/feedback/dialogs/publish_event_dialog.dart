import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_ui/gu_ui.dart';

/// DLG-22 "Etkinlik yayınlansın mı?" — taslağı yayınlama onayı
/// (`dialogs.js:39`; referans `design/reference-shots/dialogs/DLG-22__*.webp`).
///
/// * İkon `calendar-check` (marka), gövde "Etkinlik herkesin görebileceği
///   şekilde yayınlanacak.".
/// * Özel gövde: "{count} üyeye bildirim gönder" onay kutusu (varsayılan
///   işaretli; `label.row` — metne dokunmak da kutuyu değiştirir, `.gap10`
///   CSS'te tanımsız olduğundan aralık `.row` 8 — K-42). [count] tahmini
///   alıcı sayısıdır (`RecipientResolver.estimateEventNew` — CD-38).
/// * "Yayınla" rotayı onay kutusunun değeriyle (`notifyMembers`) kapatır;
///   "Düzenlemeye dön", scrim ve geri `null` bırakır. Yazım
///   (`ManagementRepository.publishEvent`) ve TST-30 çağırandadır (MGT-05).
/// * Anahtarlar `DLG-22.notify`, `DLG-22.confirm`, `DLG-22.cancel`
///   (+ `DLG-22.scrim`, `FeedbackService`).
///
/// Onay kutulu olduğu için `DialogCatalog` kaydı yoktur; [show] ile açılır
/// (`check_design_coverage` IZ01 / KUL01 izi burada).
///
/// Design: DLG-22
class PublishEventDialog extends ConsumerStatefulWidget {
  /// [count] kişiye bildirim seçeneğiyle yayın onayı.
  const PublishEventDialog({required this.count, super.key});

  /// Bildirim gidecek tahmini kişi sayısı.
  final int count;

  /// Onay kutusunun anahtarı (`DLG-22.notify`).
  static final Key notifyKey = GuKey.action('DLG-22.notify');

  /// "Yayınla" düğmesinin anahtarı (`DLG-22.confirm`).
  static final Key confirmKey = GuKey.action('DLG-22.confirm');

  /// "Düzenlemeye dön" düğmesinin anahtarı (`DLG-22.cancel`).
  static final Key cancelKey = GuKey.action('DLG-22.cancel');

  /// DLG-22'yi [feedback] üzerinden açar. Sonuç: onaylandıysa üyelere
  /// bildirim gidecek mi, vazgeçildiyse `null`.
  static Future<bool?> show(FeedbackService feedback, {required int count}) =>
      feedback.showDialog<bool>(
        DialogId.dlg22,
        builder: (_) => PublishEventDialog(count: count),
      );

  @override
  ConsumerState<PublishEventDialog> createState() => _PublishEventDialogState();
}

class _PublishEventDialogState extends ConsumerState<PublishEventDialog> {
  bool _notify = true;

  void _toggle(bool value) => setState(() => _notify = value);

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final label = l10n.dlg22Notify(widget.count);
    return GuDialogFrame(
      title: l10n.dlg22Title,
      body: l10n.dlg22Body,
      icon: GuIcons.calendarCheck,
      actions: [
        GuButton(
          key: PublishEventDialog.confirmKey,
          label: l10n.eventFormPublish,
          onPressed: () => Navigator.of(context).pop(_notify),
        ),
        GuButton(
          key: PublishEventDialog.cancelKey,
          label: l10n.dlg22Back,
          variant: GuButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      child: Row(
        spacing: GuSpacing.s8,
        children: [
          GuCheckbox(
            key: PublishEventDialog.notifyKey,
            value: _notify,
            onChanged: _toggle,
            semanticLabel: label,
          ),
          Expanded(
            child: ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _toggle(!_notify),
                child: Text(
                  label,
                  style: gu.text.bodyS.copyWith(color: gu.colors.textHeading),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
