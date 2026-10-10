import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/tokens/gu_motion.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';

/// Sayfa noktaları — prototip ONB-01 slayt göstergesi
/// (`screens-auth.js:49`), CSS `.dots` (css:394).
///
/// Nokta 8×8 `border.default`, aralık 6, ortalı; etkin ([index]) nokta 24
/// genişlikte `brand.primary`. Genişlik ve renk `GuMotion.base` ile geçer
/// (azaltılmış harekette anında). Köşe 4 = yüksekliğin yarısı → hap.
///
/// Prototipte dekoratiftir (`aria-hidden`): [semanticLabel] `null` ise
/// semantik ağacına girmez; verilirse tek düğüm olarak okunur ("1 / 3").
class GuPageDots extends StatelessWidget {
  const GuPageDots({
    required this.count,
    required this.index,
    this.semanticLabel,
    super.key,
  });

  /// Nokta sayısı (ONB-01: 3).
  final int count;

  /// Etkin noktanın sırası.
  final int index;

  /// Erişilebilirlik etiketi; `null` → dekoratif.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final colors = gu.colors;
    final dots = Center(
      heightFactor: 1,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: GuSizes.pageDotGap,
        children: [
          for (var dot = 0; dot < count; dot++)
            AnimatedContainer(
              duration: gu.duration(GuMotion.base),
              curve: GuMotion.easeCss,
              width: dot == index
                  ? GuSizes.pageDotActiveWidth
                  : GuSizes.pageDot,
              height: GuSizes.pageDot,
              decoration: BoxDecoration(
                color: dot == index
                    ? colors.brandPrimary
                    : colors.borderDefault,
                borderRadius: GuRadius.borderFull,
              ),
            ),
        ],
      ),
    );
    final label = semanticLabel;
    if (label == null) return ExcludeSemantics(child: dots);
    return Semantics(label: label, excludeSemantics: true, child: dots);
  }
}
