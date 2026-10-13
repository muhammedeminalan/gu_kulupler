import 'package:flutter/widgets.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_ui/gu_ui.dart';

/// DLG-32 "Uygulamadan ayrılıyorsun" — dış bağlantı onayı (`dialogs.js:52`;
/// referans `design/reference-shots/dialogs/DLG-32__light.webp`).
///
/// Gövde iki paragraftır: "Şu adrese gidilecek:" + adres (CSS `.code`
/// css:343 — `bg.surfaceMuted` zemin, yarıçap 6, dolgu 2 / 6; satıra sığmazsa
/// alt satıra iner ve her yerden bölünür) ve "Bu adrese güveniyor musun?".
/// Adresin **tamamı** gösterilir: kullanıcı nereye gideceğini görerek
/// onaylar. "Aç" rotayı `true`, "Vazgeç" `false` ile kapatır; scrim / geri
/// `null` bırakır.
///
/// * Yazı tipi: CSS `ui-monospace`; projede mono font paketli değildir
///   (D-12) → harita yer tutucusuyla aynı karşılık, Inter 500 / 12 + tabular
///   (`GuTypography.mapPlaceholder`, CD-19 / K-26), renk `text.heading`.
///   CSS sabit px'tir: metin ölçeğiyle büyümez (K-57).
/// * Özel gövdeli olduğu için `DialogCatalog` kaydı yoktur; tek giriş
///   `showExternalLinkDialog` / `ExternalLinkMixin`
///   (`lib/product/mixin/external_link_mixin.dart`).
class ExternalLinkDialog extends StatelessWidget {
  const ExternalLinkDialog({required this.url, super.key});

  /// Açılacak adres, kullanıcıya gösterilen biçimiyle (`https://…`,
  /// `mailto:…`).
  final String url;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final gu = context.gu;
    final designId = DialogId.dlg32.designId;
    final paragraph = gu.text.bodyS.copyWith(color: gu.colors.textSecondary);
    return GuDialogFrame(
      title: l10n.dlg32Title,
      icon: GuIcons.externalLink,
      actions: [
        GuButton(
          key: FeedbackKeys.of(designId, 'open'),
          label: l10n.commonOpen,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        GuButton(
          key: FeedbackKeys.of(designId, 'cancel'),
          label: l10n.commonGiveUp,
          variant: GuButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: GuSizes.dialogGap,
        children: [
          // Satır içi akış: etiket ve adres aynı satıra sığmazsa adres alt
          // satıra iner (`<p>… <span class="code break">`).
          Wrap(
            spacing: GuSpacing.s4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(l10n.dlg32Body1, style: paragraph),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: gu.colors.bgSurfaceMuted,
                  borderRadius: GuRadius.borderCheckbox,
                ),
                child: Padding(
                  padding: GuInsets.sym(h: GuSpacing.s6, v: GuSpacing.s2),
                  child: Text(
                    url,
                    style: gu.text.mapPlaceholder.copyWith(
                      color: gu.colors.textHeading,
                    ),
                    textScaler: TextScaler.noScaling,
                  ),
                ),
              ),
            ],
          ),
          Text(l10n.dlg32Body2, style: paragraph),
        ],
      ),
    );
  }
}
