import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';
import 'package:gu_ui/src/widgets/primitives/gu_icon_button.dart';

/// Uygulama çubuğu — prototip `AppBar` (`ui.js:79`), CSS `.appbar`
/// `.appbar-title` `.appbar-large` `.is-surface` (css:127–131). Material
/// `AppBar` kullanılmaz.
///
/// * Normal: en az 56, dolgu 4 / 8, aralık 4, zemin `bg.canvas`; [onBack]
///   verilirse baştaki `GuIconButton` (`arrow-left`, [closeIcon] → `x`);
///   başlık bloğu (yatay dolgu 8): [titleWidget] ya da [title] (titleS, tek
///   satır `…`) + [subtitle] (caption, tek satır `…`); sonda [actions]
///   (`GuIconButton`, rol rozeti, metin düğmesi).
/// * [large]: dolgu 8 / 16 / 12, yalnızca [title] (titleL); eylem varken
///   yükseklik 68 (8 + 48 + 12).
/// * [surface]: zemin `bg.surface` + altta 1 px `border.soft` (css:128;
///   prototipte hiçbir ekran kullanmıyor). Kenarlık kutunun içindedir
///   (css:78): 48'lik düğmeyle çubuk 4 + 48 + 4 + 1 = 57 olur.
/// * Üst güvenli alan gerçek `MediaQuery.viewPadding.top` ile eklenir (K-07;
///   tasarımdaki `--safe-top` maket). Tam genişliktir (CD-29).
/// * Kaydırılmış (scrolled) durumu yoktur; saydam / kapak üstü çubuk
///   `GuParallaxHeader`'a aittir (`.parallax-bar`, css:397).
/// * Başlık metni ölçeklenir; çubuk içeriğiyle büyür. [preferredSize]
///   `Scaffold.appBar` için **üst sınırdır** (Scaffold çubuğu gevşek
///   yerleştirir, gövde çubuğun gerçek yüksekliğinden başlar).
/// * Geri düğmesinin anahtarı [backActionKey] (`GuKey.action('NAV.back')`,
///   CD-111), etiketi [backSemanticLabel] (`a11y.back` / `a11y.close`)
///   çağırandan.
class GuAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GuAppBar({
    this.title,
    this.titleWidget,
    this.subtitle,
    this.large = false,
    this.surface = false,
    this.onBack,
    this.closeIcon = false,
    this.backSemanticLabel,
    this.backActionKey,
    this.actions = const [],
    super.key,
  }) : assert(
         onBack == null || backSemanticLabel != null,
         'GuAppBar: onBack verildiyse backSemanticLabel da verilmeli',
       ),
       assert(
         !large || (titleWidget == null && subtitle == null),
         'GuAppBar: large çubuk yalnızca title çizer (ui.js:82)',
       );

  /// Başlık metni (çağırandan; ARB).
  final String? title;

  /// Özel başlık (prototip `titleNode`: adım çubuğu, `ManageHeader`, arama
  /// alanı); verilirse [title] çizilmez.
  final Widget? titleWidget;

  /// Başlığın altındaki açıklama (caption; SET-03 "1/3").
  final String? subtitle;

  /// Büyük başlık (`.appbar-large`; sekme kökleri).
  final bool large;

  /// `bg.surface` zemin + alt kenarlık (`.is-surface`).
  final bool surface;

  /// Geri / kapat dokunması; `null` → düğme yok.
  final VoidCallback? onBack;

  /// Geri oku yerine `x` (`closeIcon`, ui.js:81).
  final bool closeIcon;

  /// Geri / kapat düğmesinin erişilebilirlik etiketi.
  final String? backSemanticLabel;

  /// Geri / kapat düğmesinin anahtarı.
  final Key? backActionKey;

  /// Sağdaki eylemler (prototip `children`).
  final List<Widget> actions;

  /// [preferredSize] üst sınırının `appBarMinHeight` katı: iki satırlı başlık
  /// en büyük metin ölçeğinde de sığar.
  static const double _preferredHeightFactor = 3;

  @override
  Size get preferredSize => const Size.fromHeight(
    GuSizes.appBarMinHeight * _preferredHeightFactor,
  );

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final colors = gu.colors;
    final back = onBack;
    final border = surface ? GuSizes.appBarBorder : 0.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surface ? colors.bgSurface : colors.bgCanvas,
        border: surface
            ? Border(
                bottom: BorderSide(
                  color: colors.borderSoft,
                  // Token değeri varsayılanla (1) aynı; kaynak token kalır.
                  // ignore: avoid_redundant_argument_values
                  width: GuSizes.appBarBorder,
                ),
              )
            : null,
      ),
      child: Padding(
        padding: GuInsets.only(top: MediaQuery.viewPaddingOf(context).top),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: GuSizes.appBarMinHeight,
          ),
          child: Padding(
            // `box-sizing:border-box` (css:78): kenarlık 56'nın içindedir.
            padding: large
                ? GuInsets.only(
                    left: GuSizes.appBarLargePaddingX,
                    top: GuSizes.appBarLargePaddingTop,
                    right: GuSizes.appBarLargePaddingX,
                    bottom: GuSizes.appBarLargePaddingBottom + border,
                  )
                : GuInsets.only(
                    left: GuSizes.appBarPaddingX,
                    top: GuSizes.appBarPaddingY,
                    right: GuSizes.appBarPaddingX,
                    bottom: GuSizes.appBarPaddingY + border,
                  ),
            child: Row(
              spacing: GuSizes.appBarGap,
              children: [
                if (back != null)
                  GuIconButton(
                    key: backActionKey,
                    icon: closeIcon ? GuIcons.x : GuIcons.arrowLeft,
                    semanticLabel: backSemanticLabel ?? '',
                    onPressed: back,
                  ),
                Expanded(child: _buildTitle(context)),
                ...actions,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    final text = context.gu.text;
    final title = this.title;
    final subtitle = this.subtitle;
    final heading = title == null
        ? null
        : Semantics(
            header: true,
            child: Text(
              title,
              style: large ? text.titleL : text.titleS,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          );
    if (large) return heading ?? const SizedBox.shrink();
    final head = titleWidget ?? heading;
    return Padding(
      padding: GuInsets.sym(h: GuSizes.appBarTitlePaddingX),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ?head,
          if (subtitle != null)
            Text(
              subtitle,
              style: text.caption,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}
