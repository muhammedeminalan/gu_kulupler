import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';

/// Madde imli liste — prototip düz `<ul>` / `<li>` (SET-03 "Silinecekler",
/// `screens-profile.js:86`): CSS `.gu-root ul{margin:0;padding-left:20px}`
/// (css:84), varsayılan `disc` imi.
///
/// * Her madde: [indent] genişliğinde im sütunu (im ortada) + metin
///   (`Expanded`, satır kaydırmalı). Metin soldan [indent] kadar içeride
///   başlar.
/// * Maddeler arası [spacing] (prototip `.col.gap4`).
/// * Metin stili [style]; `null` → `bodyS` + `text.secondary` (`.t-body-s
///   .c-sec`). İm metinle aynı stildedir ve erişilebilirlik ağacına girmez.
///
/// Alan bilgisi taşımaz; maddeler çağırandan (ARB) gelir.
class GuBulletList extends StatelessWidget {
  /// [items] sırasıyla çizilir.
  const GuBulletList({
    required this.items,
    this.style,
    this.spacing = GuSpacing.s4,
    this.indent = GuSpacing.s20,
    super.key,
  });

  /// Madde metinleri.
  final List<String> items;

  /// Metin stili; `null` → `bodyS` + `text.secondary`.
  final TextStyle? style;

  /// Maddeler arası dikey boşluk.
  final double spacing;

  /// Metnin sol girintisi (`ul{padding-left}`).
  final double indent;

  /// Madde imi (`list-style: disc`).
  static const String bullet = '•';

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final textStyle =
        style ?? gu.text.bodyS.copyWith(color: gu.colors.textSecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing,
      children: [
        for (final item in items)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: indent,
                child: ExcludeSemantics(
                  child: Text(
                    bullet,
                    style: textStyle,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              Expanded(child: Text(item, style: textStyle)),
            ],
          ),
      ],
    );
  }
}
