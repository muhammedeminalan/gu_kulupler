import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/tokens/gu_motion.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';

/// Yükleniyor halkası — prototip `Spinner` (`ui.js:7`), CSS `.spinner`
/// (css:153): 20 px daire, 2.5 px kenar, sağ çeyrek saydam (270° yay),
/// `spin .8s linear infinite`.
///
/// * [color] verilmezse kapsayıcının metin rengi (`currentColor` eşdeğeri:
///   `DefaultTextStyle`); düğme içinde çağıran ön plan rengini verir.
/// * Azaltılmış harekette dönmez, durağan 270° yay çizer (css:427).
/// * [semanticLabel] verilirse canlı bölge olarak okunur (`role="status"`,
///   metin çağırandan — ARB `commonLoading`); `null` → dekoratif.
class GuSpinner extends StatefulWidget {
  const GuSpinner({
    this.size = GuSizes.spinner,
    this.strokeWidth = GuSizes.spinnerStroke,
    this.color,
    this.semanticLabel,
    super.key,
  });

  /// Dış çap (dp).
  final double size;

  /// Halka kalınlığı (dp).
  final double strokeWidth;

  /// Halka rengi; `null` → `DefaultTextStyle` rengi.
  final Color? color;

  /// Erişilebilirlik etiketi; `null` → dekoratif.
  final String? semanticLabel;

  @override
  State<GuSpinner> createState() => _GuSpinnerState();
}

class _GuSpinnerState extends State<GuSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: GuMotion.spin,
  );
  late final Animation<double> _turns = _controller.drive(
    CurveTween(curve: GuMotion.spinCurve),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.gu.reduceMotion) {
      _controller
        ..stop()
        ..value = 0;
    } else if (!_controller.isAnimating) {
      // Sürekli dönüş; `TickerFuture` beklenmez (widget ömrünce sürer).
      unawaited(_controller.repeat());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final ring = RepaintBoundary(
      child: RotationTransition(
        turns: _turns,
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _SpinnerPainter(
            color:
                widget.color ??
                DefaultTextStyle.of(context).style.color ??
                gu.colors.textPrimary,
            strokeWidth: widget.strokeWidth,
          ),
        ),
      ),
    );
    final label = widget.semanticLabel;
    if (label == null) return ExcludeSemantics(child: ring);
    return Semantics(label: label, liveRegion: true, child: ring);
  }
}

/// CSS `border-right-color:transparent` (css:153): saydam çeyrek −45°…+45°;
/// görünen yay 45°'den saat yönünde 270°.
class _SpinnerPainter extends CustomPainter {
  const _SpinnerPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  static const double _startAngle = math.pi / 4;
  static const double _sweepAngle = math.pi * 3 / 2;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawArc(
      (Offset.zero & size).deflate(strokeWidth / 2),
      _startAngle,
      _sweepAngle,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_SpinnerPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
