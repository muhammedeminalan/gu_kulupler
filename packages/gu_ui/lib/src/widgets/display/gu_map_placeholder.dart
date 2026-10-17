import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/icons/gu_icon.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/tokens/gu_opacity.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';

/// Konum görseli — EVT-02 mekân kartı (`screens-events.js:65` `.map-ph`
/// yerinde); CD-25.
///
/// **Tasarımdan bilinçli sapma (H-24, kullanıcı kararı 2026-10-17):**
/// prototipteki şeritli kutu ve "map placeholder · …" taslak metni yerine
/// kapak deseni + büyük pin. Gerçek harita yoktur (D-31).
///
/// * 120 px yükseklik ([GuSizes.mapPlaceholderHeight]), radius 12, 1 px
///   `border.soft` kenarlık; zemin `brand.primaryContainer`, üstünde
///   `brand.primary` çapraz çizgi deseni (kapak katmanı opaklığı
///   [GuOpacity.coverIcon]).
/// * Ortada `brand.primary` daire içinde beyaz pin ([GuSizes.mapPinBadge])
///   ve `bg.surface` hapta [label] (mekân adı; tek satır, sığmazsa `…`).
/// * Dekoratiftir: mekân adını üstteki satır zaten okur, ekran okuyucuya
///   ikinci kez verilmez.
class GuMapPlaceholder extends StatelessWidget {
  const GuMapPlaceholder({required this.label, super.key});

  /// Haptaki metin (mekân adı).
  final String label;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final colors = gu.colors;
    return ExcludeSemantics(
      child: SizedBox(
        height: GuSizes.mapPlaceholderHeight,
        child: CustomPaint(
          painter: _MapPatternPainter(
            base: colors.brandPrimaryContainer,
            line: colors.brandPrimary.withValues(alpha: GuOpacity.coverIcon),
            border: colors.borderSoft,
          ),
          child: Center(
            child: Padding(
              padding: GuInsets.h16,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.brandPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(
                      dimension: GuSizes.mapPinBadge,
                      child: Center(
                        child: GuIcon(
                          GuIcons.mapPin,
                          color: colors.brandOnPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: GuSpacing.s12),
                  Flexible(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.bgSurface,
                        borderRadius: GuRadius.borderFull,
                      ),
                      child: Padding(
                        padding: GuInsets.only(
                          left: GuSpacing.s12,
                          right: GuSpacing.s12,
                          top: GuSpacing.s6,
                          bottom: GuSpacing.s6,
                        ),
                        child: Text(
                          label,
                          style: gu.text.labelM,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Zemin + çapraz (sol alttan sağ üste) çizgiler + 1 px kenarlık. Çizgiler
/// [GuSizes.mapPatternPeriod] aralıkla, [GuSizes.mapPatternLine] kalınlıkta;
/// yuvarlatılmış kutuya kırpılır.
class _MapPatternPainter extends CustomPainter {
  const _MapPatternPainter({
    required this.base,
    required this.line,
    required this.border,
  });

  final Color base;
  final Color line;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    const borderWidth = GuSizes.mapPlaceholderBorder;
    final outer = GuRadius.borderSm.toRRect(Offset.zero & size);
    canvas
      ..drawRRect(outer, Paint()..color = base)
      ..save()
      ..clipRRect(outer);
    final stroke = Paint()
      ..color = line
      ..strokeWidth = GuSizes.mapPatternLine;
    for (var x = -size.height; x < size.width; x += GuSizes.mapPatternPeriod) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        stroke,
      );
    }
    canvas
      ..restore()
      ..drawRRect(
        outer.deflate(borderWidth / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth
          ..color = border,
      );
  }

  @override
  bool shouldRepaint(_MapPatternPainter oldDelegate) =>
      oldDelegate.base != base ||
      oldDelegate.line != line ||
      oldDelegate.border != border;
}
