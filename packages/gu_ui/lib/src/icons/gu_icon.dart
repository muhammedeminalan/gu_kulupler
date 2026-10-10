import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';

/// Tek ikon widget'ı — `assets/icons` SVG'sini `ColorFilter.srcIn` ile
/// boyar (PLAN §7.11; D-13). Material `Icons` kullanılmaz (HC10).
///
/// * [size] kare kenardır (varsayılan `GuSizes.icon24`; diğerleri
///   `GuSizes.icon12`–`icon64`).
/// * [color] verilmezse `text.heading` (CSS `.iconbtn{color:var(--text-heading)}`
///   css:154, `svg currentColor`).
/// * [semanticLabel] verilmezse ikon dekoratiftir (`aria-hidden` eşdeğeri,
///   `ExcludeSemantics`); verilirse `Semantics(label:, image: true)`.
///
/// Çizgi kalınlığı varlıkta 1.75 sabittir; kalınlık parametresi yoktur
/// (CD-21, K-24).
class GuIcon extends StatelessWidget {
  const GuIcon(
    this.icon, {
    this.size = GuSizes.icon24,
    this.color,
    this.semanticLabel,
    super.key,
  });

  /// Çizilecek ikon.
  final GuIcons icon;

  /// Kare kenar (dp).
  final double size;

  /// İkon rengi; `null` → `context.gu.colors.textHeading`.
  final Color? color;

  /// Erişilebilirlik etiketi; `null` → dekoratif.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final picture = SvgPicture.asset(
      icon.assetPath,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(
        color ?? context.gu.colors.textHeading,
        BlendMode.srcIn,
      ),
      bundle: DefaultAssetBundle.of(context),
      excludeFromSemantics: true,
    );
    final label = semanticLabel;
    if (label == null) return ExcludeSemantics(child: picture);
    return Semantics(label: label, image: true, child: picture);
  }
}
