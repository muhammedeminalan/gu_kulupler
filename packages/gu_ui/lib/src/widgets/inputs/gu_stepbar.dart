import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';

/// Adım çubuğu — prototip `Stepbar` (`ui.js:125`), CSS `.stepbar`
/// (css:320).
///
/// [total] eşit genişlikte parça, aralık 6, yükseklik 4, radius 2; ilk [step]
/// parça `brand.primary` (`.is-done`), kalanı `border.default`. Statiktir
/// (geçiş animasyonu yok). `GuProgress` değildir (G6: ayrık adım).
///
/// * Metin basmaz; [semanticLabel] çağırandan gelir (`'$step/$total'`,
///   `aria-label` ui.js:125) ve `Semantics(value:)` olarak okunur.
/// * Sınırlı genişlik ister (parçalar `Expanded`; AUT-05 / MGT-05 AppBar
///   başlık sütunu).
class GuStepbar extends StatelessWidget {
  const GuStepbar({
    required this.step,
    required this.total,
    required this.semanticLabel,
    super.key,
  });

  /// Tamamlanan adım sayısı (0…[total]; dışı değerler kırpılmış gibi çizilir).
  final int step;

  /// Toplam adım sayısı.
  final int total;

  /// Erişilebilirlik değeri (ör. "2/3").
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.gu.colors;
    return Semantics(
      container: true,
      value: semanticLabel,
      child: Row(
        spacing: GuSizes.stepbarGap,
        children: [
          for (var index = 0; index < total; index++)
            Expanded(
              child: SizedBox(
                height: GuSizes.stepbarHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: index < step
                        ? colors.brandPrimary
                        : colors.borderDefault,
                    borderRadius: GuRadius.borderHandle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
