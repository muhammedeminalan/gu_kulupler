import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';

/// Harita yer tutucusu — CSS `.map-ph` (css:410); EVT-02 mekân kartı
/// (`screens-events.js:65`); CD-25.
///
/// 120 px yükseklik, radius 12, 45° şerit deseni (10 px `bg.surfaceMuted` /
/// 10 px `border.soft`), 1 px `border.soft` kenarlık, ortada `text.muted`
/// metin.
///
/// * [label] çağırandan gelir (ARB `eventMapPlaceholder`, CD-88).
/// * Yazı `GuTypography.mapPlaceholder` (Inter 500 12 + tabular; CSS
///   `ui-monospace` → K-26 / CD-19) ve ölçeklenmez (K-57: css:410 sabit
///   `12px`). Sığmayan metin en çok 3 satıra sarılır, sonra `…`.
class GuMapPlaceholder extends StatelessWidget {
  const GuMapPlaceholder({required this.label, super.key});

  /// Ortadaki metin.
  final String label;

  /// Sarılan metnin satır sınırı (kutu yüksekliğine sığan).
  static const int _maxLines = 3;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    return SizedBox(
      height: GuSizes.mapPlaceholderHeight,
      child: CustomPaint(
        painter: _MapStripesPainter(
          base: gu.colors.bgSurfaceMuted,
          stripe: gu.colors.borderSoft,
          border: gu.colors.borderSoft,
        ),
        child: Center(
          child: Padding(
            padding: GuInsets.h8,
            child: Text(
              label,
              style: gu.text.mapPlaceholder,
              textScaler: TextScaler.noScaling,
              textAlign: TextAlign.center,
              maxLines: _maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

/// CSS `repeating-linear-gradient(45deg, A 0 10px, B 10px 20px)` + 1 px
/// kenarlık: 45° = sağ üste doğru; 0 noktası iç kutunun (kenarlık içi,
/// `background-origin: padding-box`) sol alt köşesi; şeritler sol üstten sağ
/// alta uzanır, dönem 20 px.
class _MapStripesPainter extends CustomPainter {
  const _MapStripesPainter({
    required this.base,
    required this.stripe,
    required this.border,
  });

  final Color base;
  final Color stripe;
  final Color border;

  /// Dönemin (2 şerit) x / y bileşeni: `20 / √2`.
  static const double _step = 2 * GuSizes.mapPlaceholderStripe / math.sqrt2;

  /// Sert geçişli duraklar: ilk yarı [base], ikinci yarı [stripe].
  static const List<double> _stops = [0, 0.5, 0.5, 1];

  @override
  void paint(Canvas canvas, Size size) {
    const borderWidth = GuSizes.mapPlaceholderBorder;
    final outer = GuRadius.borderSm.toRRect(Offset.zero & size);
    final origin = Offset(borderWidth, size.height - borderWidth);
    canvas
      ..drawRRect(
        outer,
        Paint()
          ..shader = ui.Gradient.linear(
            origin,
            origin + const Offset(_step, -_step),
            [base, base, stripe, stripe],
            _stops,
            TileMode.repeated,
          ),
      )
      ..drawRRect(
        outer.deflate(borderWidth / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth
          ..color = border,
      );
  }

  @override
  bool shouldRepaint(_MapStripesPainter oldDelegate) =>
      oldDelegate.base != base ||
      oldDelegate.stripe != stripe ||
      oldDelegate.border != border;
}
