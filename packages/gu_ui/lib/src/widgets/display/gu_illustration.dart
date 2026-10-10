import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/widgets/display/gu_illustrations.dart';

/// Kare illüstrasyon (prototip `Illustration`, `art.js:88`; `.ill`).
///
/// [size] `GuSizes.illustrationSizes` kümesindendir (56, 72, 80, 96, 100,
/// 140, 160, 200; K-48): varsayılan `GuSizes.illustration` (140), kompakt
/// `GuSizes.illustrationCompact` (96). Dekoratiftir (`aria-hidden`,
/// `ExcludeSemantics`). Varlık iki renklidir; renk filtresi uygulanmaz ve
/// koyu temada aynı çizilir (K-20).
class GuIllustration extends StatelessWidget {
  const GuIllustration(
    this.illustration, {
    this.size = GuSizes.illustration,
    super.key,
  });

  /// Çizilecek illüstrasyon.
  final GuIllustrations illustration;

  /// Kare kenar (dp).
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SvgPicture.asset(
      illustration.assetPath,
      width: size,
      height: size,
      bundle: DefaultAssetBundle.of(context),
      excludeFromSemantics: true,
    ),
  );
}
