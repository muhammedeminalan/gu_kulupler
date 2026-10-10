import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';

/// Grup başlığı — CSS `.group-head` (css:215; prototipte ayrı bileşen yok:
/// `screens-events.js:30, 105`, `screens-clubs.js:147`,
/// `screens-manage.js:135, 195`, `sheets.js:16`). CD-25.
///
/// Zemin `bg.canvas`, dolgu 12/16/6, iki uca hizalı: solda [title]
/// (overline; büyük harfi çağıran `upperFor(locale)` ile uygular, CD-11),
/// sağda [trailingText] (caption, tabular; EVT-01 grup sayısı) ya da
/// [trailing].
///
/// [sticky] `true` → `PinnedHeaderSliver` döner (yalnızca sliver bağlamında):
/// CSS `position:sticky; top:0` karşılığı; grup kabı
/// `SliverMainAxisGroup(slivers: [GuGroupHeader(sticky: true), liste])`
/// olduğunda başlık grup sonunda bir sonraki başlıkla itilir. `false`
/// (varsayılan) → düz kutu (`Column`, sheet gövdesi).
class GuGroupHeader extends StatelessWidget {
  const GuGroupHeader({
    required this.title,
    this.trailingText,
    this.trailing,
    this.sticky = false,
    super.key,
  }) : assert(
         trailingText == null || trailing == null,
         'GuGroupHeader: trailingText ve trailing birlikte verilemez',
       );

  /// Başlık (overline).
  final String title;

  /// Sağdaki sayaç metni (caption).
  final String? trailingText;

  /// Sağdaki özel öğe ([trailingText] yerine).
  final Widget? trailing;

  /// `true` → yapışkan sliver.
  final bool sticky;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final trailingText = this.trailingText;
    final header = ColoredBox(
      color: gu.colors.bgCanvas,
      child: Padding(
        padding: GuInsets.only(
          left: GuSizes.groupHeadPaddingX,
          top: GuSizes.groupHeadPaddingTop,
          right: GuSizes.groupHeadPaddingX,
          bottom: GuSizes.groupHeadPaddingBottom,
        ),
        child: Row(
          spacing: GuSpacing.s8,
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(title, style: gu.text.overline),
              ),
            ),
            if (trailingText != null)
              Text(
                trailingText,
                style: gu.text.caption.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              )
            else
              ?trailing,
          ],
        ),
      ),
    );
    return sticky ? PinnedHeaderSliver(child: header) : header;
  }
}
