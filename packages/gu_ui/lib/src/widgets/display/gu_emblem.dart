import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/icons/gu_icon.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';

/// Amblem boyutu (CSS `.emblem` / `.is-sm` / `.is-xs`, css:398–400).
enum GuEmblemSize {
  /// 72 px, radius 20, zemin `bg.surface`, gölge `e2`, ikon 34 (CLB-03).
  lg(GuSizes.emblem, GuRadius.borderLg, GuSizes.icon34),

  /// 44 px, radius 12, zemin `brand.primaryContainer`, ikon 20 (liste satırı).
  sm(GuSizes.emblemSm, GuRadius.borderSm, GuSizes.icon20),

  /// 32 px, radius 9, zemin `brand.primaryContainer`, ikon 16 (EVT-02).
  xs(GuSizes.emblemXs, GuRadius.borderEmblemXs, GuSizes.icon16);

  const GuEmblemSize(this.dimension, this.borderRadius, this.iconSize);

  /// Kare kenar (dp).
  final double dimension;

  /// Köşe yarıçapı.
  final BorderRadius borderRadius;

  /// Varsayılan ikon boyutu.
  final double iconSize;
}

/// Kulüp amblemi — yuvarlatılmış kare ikon kutusu (CSS `.emblem`,
/// css:398–400; prototipte ayrı bileşen yok, `span.emblem`).
///
/// İçerik: [icon] ya da [child]'dan tam biri. [child] yalnızca FED-03
/// bildirim önizlemesindeki `GuLogo(size: 20)` içindir
/// (`screens-clubs.js:210`).
///
/// Üst yazımlar ayrı kurucu/`tone` olmadan parametreyle verilir (CD-91, K-35):
///
/// * [iconSize] — ClubCard liste 22, kamera rozeti 14, MGT-09 / ADM-03 30.
/// * [background] — `null` → boyut kuralı (`lg` `bg.surface`, `sm` / `xs`
///   `brand.primaryContainer`); ClubCard ızgara `bg.surface`, kamera rozeti
///   `brand.primary`.
/// * [foreground] — ikon rengi; `null` → `brand.primaryText`.
/// * [borderColor] / [borderWidth] — CSS tabanı her boyutta
///   `1px solid border.soft`'tur (css:398; `.is-sm` / `.is-xs` kenarlığı
///   ezmez). `borderColor == null` → `border.soft`; `borderWidth == 0` →
///   `GuSizes.emblemBorder` (1). PRF-01 kamera rozeti: `bg.canvas` +
///   `GuSizes.avatarBadgeBorder` (2).
///
/// Dekoratiftir; dokunulabilir sarmalayıcı ve etiket ekran düzeyindedir.
class GuEmblem extends StatelessWidget {
  const GuEmblem({
    this.icon,
    this.child,
    this.size = GuEmblemSize.sm,
    this.iconSize,
    this.background,
    this.foreground,
    this.borderColor,
    this.borderWidth = 0,
    super.key,
  }) : assert(
         (icon == null) != (child == null),
         'GuEmblem: icon ya da child parametrelerinden tam biri verilmeli',
       );

  /// Amblem ikonu ([child] ile birlikte verilmez).
  final GuIcons? icon;

  /// İkon yerine özel içerik ([icon] ile birlikte verilmez).
  final Widget? child;

  /// Boyut varyantı.
  final GuEmblemSize size;

  /// İkon boyutu; `null` → [GuEmblemSize.iconSize].
  final double? iconSize;

  /// Zemin; `null` → boyut kuralı.
  final Color? background;

  /// İkon rengi; `null` → `brand.primaryText`.
  final Color? foreground;

  /// Kenarlık rengi; `null` → `border.soft`.
  final Color? borderColor;

  /// Kenarlık kalınlığı; `0` → `GuSizes.emblemBorder`.
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final isLarge = size == GuEmblemSize.lg;
    final emblemIcon = icon;
    return SizedBox.square(
      dimension: size.dimension,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color:
              background ??
              (isLarge ? gu.colors.bgSurface : gu.colors.brandPrimaryContainer),
          borderRadius: size.borderRadius,
          border: Border.all(
            color: borderColor ?? gu.colors.borderSoft,
            width: borderWidth > 0 ? borderWidth : GuSizes.emblemBorder,
          ),
          boxShadow: isLarge ? gu.shadows.e2 : null,
        ),
        child: Center(
          child: emblemIcon != null
              ? GuIcon(
                  emblemIcon,
                  size: iconSize ?? size.iconSize,
                  color: foreground ?? gu.colors.brandPrimaryText,
                )
              : child,
        ),
      ),
    );
  }
}
