import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';
import 'package:gu_ui/src/widgets/primitives/gu_button.dart';

/// Alt yapışkan eylem çubuğu — prototip `StickyCTA` (`ui.js:124`), CSS
/// `.ctabar` (css:296–299).
///
/// * Zemin `bg.surface`, üstte 1 px `border.soft`, gölge `GuShadows.ctaBar`
///   (`0 -4px 16px`; koyu temada yok, css:299); dolgu 12 / 16, aralık 12.
/// * [children] yatay dizilir; `GuButton` çocuklar satırı eşit paylaşır
///   (css:298 `.ctabar .btn{flex:1}`). Diğer çocuklar (durum metni, rozet,
///   FED-02 yorum yazıcı) olduğu gibi yerleşir; genişlemesi gerekeni çağıran
///   `Expanded` / `Flexible` ile sarar.
/// * Alt dolguya gerçek güvenli alan eklenir (`MediaQuery.viewPadding.bottom`,
///   K-07; `--safe-bottom` maket). Klavye açıkken çubuk `viewInsets.bottom`
///   kadar yukarıda kalır ve güvenli alan payı düşer (yeniden boyutlanan
///   `Scaffold` gövdesinde ikisi de zaten sıfırlanmıştır).
/// * `.in-nav` yazılmaz (prototipte 0 kullanım; CD-85).
class GuStickyCta extends StatelessWidget {
  const GuStickyCta({
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    super.key,
  });

  /// Çubuğun içeriği.
  final List<Widget> children;

  /// Çocukların dikey hizası.
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final colors = gu.colors;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = math.max<double>(
      0,
      MediaQuery.viewPaddingOf(context).bottom - keyboard,
    );
    return Padding(
      padding: GuInsets.only(bottom: keyboard),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.bgSurface,
          border: Border(
            top: BorderSide(
              color: colors.borderSoft,
              // Token değeri varsayılanla (1) aynı; kaynak token kalır.
              // ignore: avoid_redundant_argument_values
              width: GuSizes.ctaBarBorder,
            ),
          ),
          boxShadow: gu.shadows.ctaBar,
        ),
        child: Padding(
          padding: GuInsets.only(
            left: GuSizes.ctaBarPaddingX,
            top: GuSizes.ctaBarBorder + GuSizes.ctaBarPaddingY,
            right: GuSizes.ctaBarPaddingX,
            bottom: GuSizes.ctaBarPaddingY + safeBottom,
          ),
          child: Row(
            crossAxisAlignment: crossAxisAlignment,
            spacing: GuSizes.ctaBarGap,
            children: [
              for (final child in children)
                if (child is GuButton) Expanded(child: child) else child,
            ],
          ),
        ),
      ),
    );
  }
}
