import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/tokens/gu_motion.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';

/// Halka grafik — prototip `Donut` (`ui.js:93`, satır içi SVG; CSS sınıfı
/// yok): 96 px, kalınlık 10, iz `bg.surfaceMuted`, dolum `brand.primary`
/// (saat 12'den saat yönünde, yuvarlak uç), ortada yüzde metni.
///
/// * [valueLabel] çağırandan gelir (`AppDateFormats.percent`: TR "%62",
///   EN "62%" — CD-101, K-39); stil `GuTypography.donutValueFor(size)`,
///   metin ölçeklenmez (K-57: SVG `font-size`).
/// * Dolum `GuMotion.fill` + `easeStandard` ile geçer (ilk çizimde animasyon
///   yok).
class GuDonut extends StatelessWidget {
  const GuDonut({
    required this.value,
    required this.valueLabel,
    required this.semanticLabel,
    this.size = GuSizes.donut,
    this.strokeWidth = GuSizes.donutStroke,
    super.key,
  });

  /// Yüzde değeri (0…100).
  final double value;

  /// Ortadaki metin (yerel ayara göre biçimlenmiş yüzde).
  final String valueLabel;

  /// Erişilebilirlik etiketi (`role="img"` + `aria-label`).
  final String semanticLabel;

  /// Dış çap (dp).
  final double size;

  /// Halka kalınlığı (dp).
  final double strokeWidth;

  /// Dolum oranı 0…1; geçersiz girişte 0.
  double get fraction => value.isFinite ? value.clamp(0, 100) / 100 : 0;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    return Semantics(
      container: true,
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: fraction),
            duration: gu.duration(GuMotion.fill),
            curve: GuMotion.easeStandard,
            builder: (context, animated, child) => CustomPaint(
              painter: _DonutPainter(
                fraction: animated,
                strokeWidth: strokeWidth,
                track: gu.colors.bgSurfaceMuted,
                fill: gu.colors.brandPrimary,
              ),
              child: child,
            ),
            child: Padding(
              padding: GuInsets.sym(h: strokeWidth, v: strokeWidth),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    valueLabel,
                    style: gu.text.donutValueFor(size),
                    textScaler: TextScaler.noScaling,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// SVG eşdeğeri (ui.js:93): `r = (size − stroke) / 2`, `rotate(−90)`,
/// `stroke-dasharray = c × value / 100`, `stroke-linecap: round`.
class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.fraction,
    required this.strokeWidth,
    required this.track,
    required this.fill,
  });

  final double fraction;
  final double strokeWidth;
  final Color track;
  final Color fill;

  static const double _startAngle = -math.pi / 2;
  static const double _fullAngle = 2 * math.pi;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    canvas.drawArc(
      rect,
      _startAngle,
      _fullAngle,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = track,
    );
    if (fraction <= 0) return;
    canvas.drawArc(
      rect,
      _startAngle,
      _fullAngle * fraction,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = fill,
    );
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.track != track ||
      oldDelegate.fill != fill;
}
