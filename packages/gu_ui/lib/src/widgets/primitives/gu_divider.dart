import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';

/// Yatay ayraç — CSS `.divider{height:1px;background:var(--border-soft);
/// margin:0}` (css:106; prototipte ayrı bileşen yok, `div.divider`).
///
/// Tam genişliktedir (blok öğe); kart içi satırlar ve sheet gövdeleri
/// arasında kullanılır. [margin] yalnızca `GuInsets` sabitleriyle verilir
/// (girinti gerekiyorsa `GuInsets.only(left: …)`). Dekoratiftir, semantik
/// ağacına girmez.
class GuDivider extends StatelessWidget {
  const GuDivider({this.margin = EdgeInsets.zero, super.key});

  /// Dış boşluk; varsayılan 0 (css:106 `margin:0`).
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) => Padding(
    padding: margin,
    // Sınırsız genişlikte (ör. `Row` içinde) 0'a düşer, hata vermez.
    child: LimitedBox(
      maxWidth: 0,
      child: SizedBox(
        width: double.infinity,
        height: GuSizes.divider,
        child: ColoredBox(color: context.gu.colors.borderSoft),
      ),
    ),
  );
}
