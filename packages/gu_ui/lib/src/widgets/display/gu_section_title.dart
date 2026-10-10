import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';
import 'package:gu_ui/src/widgets/primitives/gu_button.dart';

/// Bölüm başlığının üst boşluğu (K-35).
enum GuSectionTitleMargin {
  /// `.section-title:first-child{margin-top:8px}` (css:109).
  first(GuSizes.sectionTitleFirstMarginTop),

  /// `.section-title{margin:24px 0 12px}` (css:108).
  normal(GuSizes.sectionTitleMarginTop),

  /// Satır içi `margin-top:0` (CLB-01 "Kulüplerim", `screens-clubs.js:25`).
  none(0);

  const GuSectionTitleMargin(this.top);

  /// Üst boşluk (dp).
  final double top;
}

/// Bölüm başlığı — prototip `SectionTitle` (`ui.js:122`), CSS
/// `.section-title` (css:108–109).
///
/// Sol: [title] (titleM, başlık semantiği) + isteğe bağlı [subtitle]
/// (caption). Sağ: [actionLabel] verilirse eylem bağlantısı
/// (`btn btn-text btn-sm` → `GuButton(text, sm)`; anahtarı [actionKey],
/// CD-111). Yatay dolgu 16, alt boşluk 12, üst boşluk [topMargin]. Başlık
/// sarar; eylem en çok satırın yarısını kaplar ve `…` ile kesilir.
class GuSectionTitle extends StatelessWidget {
  const GuSectionTitle({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.actionKey,
    this.topMargin = GuSectionTitleMargin.normal,
    super.key,
  }) : assert(
         actionLabel == null || onAction != null,
         'GuSectionTitle: actionLabel verildiyse onAction da verilmeli',
       );

  /// Başlık metni.
  final String title;

  /// Başlığın altındaki açıklama (prototip `sub`).
  final String? subtitle;

  /// Sağdaki eylem bağlantısının metni; `null` → eylem yok.
  final String? actionLabel;

  /// Eylem dokunması.
  final VoidCallback? onAction;

  /// Eylem bağlantısının anahtarı (`GuKey.action('CLB-02.clearRecent')`).
  final Key? actionKey;

  /// Üst boşluk varyantı.
  final GuSectionTitleMargin topMargin;

  @override
  Widget build(BuildContext context) {
    final text = context.gu.text;
    final subtitle = this.subtitle;
    final actionLabel = this.actionLabel;
    return Padding(
      padding: GuInsets.only(
        left: GuSpacing.s16,
        top: topMargin.top,
        right: GuSpacing.s16,
        bottom: GuSizes.sectionTitleMarginBottom,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          spacing: GuSizes.sectionTitleGap,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(title, style: text.titleM),
                  ),
                  if (subtitle != null) Text(subtitle, style: text.caption),
                ],
              ),
            ),
            if (actionLabel != null)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth / 2,
                ),
                child: GuButton(
                  key: actionKey,
                  label: actionLabel,
                  onPressed: onAction,
                  variant: GuButtonVariant.text,
                  size: GuButtonSize.sm,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
