import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/tokens/gu_motion.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';

/// Başarı işareti — prototip `SuccessCheck` (`ui.js:151`), CSS
/// `.circle-draw` / `.check-draw` (css:332–333, `@keyframes draw` css:420).
///
/// SVG eşdeğeri (viewBox 96): `r = 40` daire, kalınlık 4; tik
/// `M30 49 l12 12 24-26`, kalınlık 5, yuvarlak uç / köşe; renk
/// `state.success`. Çizim tek seferdir: daire `GuMotion.circleDraw` (500 ms),
/// tik `GuMotion.checkDrawDelay` (200 ms) sonra `GuMotion.checkDraw`
/// (320 ms), ikisi de `easeStandard`.
///
/// * Dairenin son karesi kapalı değildir: `stroke-dasharray:200` çevrenin
///   (≈ 251) 200 birimini çizer; yay saat 3'ten saat yönünde ≈ 286° sürer
///   (`screens/CLB-04__light__tr.webp`).
/// * Azaltılmış harekette animasyon yok, son kare çizilir (css:427).
/// * [size] 96 (AUT-03, AUT-04); 72 (SET-05), 110 (CLB-04).
/// * `role="img"` + [semanticLabel] (`common.success`, çağırandan).
class GuSuccessCheck extends StatefulWidget {
  const GuSuccessCheck({
    required this.semanticLabel,
    this.size = GuSizes.successCheck,
    super.key,
  });

  /// Kenar (dp); çizim viewBox 96'dan ölçeklenir.
  final double size;

  /// Erişilebilirlik etiketi.
  final String semanticLabel;

  @override
  State<GuSuccessCheck> createState() => _GuSuccessCheckState();
}

class _GuSuccessCheckState extends State<GuSuccessCheck>
    with SingleTickerProviderStateMixin {
  /// Toplam süre: dairenin ve gecikmeli tikin bitişlerinden geç olanı.
  static final Duration _total =
      GuMotion.circleDraw > GuMotion.checkDrawDelay + GuMotion.checkDraw
      ? GuMotion.circleDraw
      : GuMotion.checkDrawDelay + GuMotion.checkDraw;

  static double _fraction(Duration part) =>
      part.inMicroseconds / _total.inMicroseconds;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _total,
  );
  late final Animation<double> _circle = _controller.drive(
    CurveTween(
      curve: Interval(
        0,
        _fraction(GuMotion.circleDraw),
        curve: GuMotion.easeStandard,
      ),
    ),
  );
  late final Animation<double> _check = _controller.drive(
    CurveTween(
      curve: Interval(
        _fraction(GuMotion.checkDrawDelay),
        _fraction(GuMotion.checkDrawDelay + GuMotion.checkDraw),
        curve: GuMotion.easeStandard,
      ),
    ),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.gu.reduceMotion) {
      // Son kare; süren çizim de durur.
      _controller.value = 1;
    } else if (!_started) {
      // Tek seferlik çizim; `TickerFuture` beklenmez.
      unawaited(_controller.forward());
    }
    _started = true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    image: true,
    label: widget.semanticLabel,
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _SuccessCheckPainter(
            circle: _circle,
            check: _check,
            color: context.gu.colors.stateSuccess,
            repaint: _controller,
          ),
        ),
      ),
    ),
  );
}

/// `stroke-dashoffset: dash → 0` (css:420): yolun görünen uzunluğu
/// `dash × ilerleme` (yol uzunluğuyla sınırlı).
class _SuccessCheckPainter extends CustomPainter {
  _SuccessCheckPainter({
    required this.circle,
    required this.check,
    required this.color,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final Animation<double> circle;
  final Animation<double> check;
  final Color color;

  // ignore-hardcode: eksik token — css:333 `.circle-draw{stroke-dasharray:200}`
  static const double _circleDash = 200;

  // ignore-hardcode: eksik token — css:332 `.check-draw{stroke-dasharray:60}`
  static const double _checkDash = 60;

  // ignore-hardcode: eksik token — ui.js:151 tik yolu `M30 49l12 12 24-26`
  static const List<double> _checkPath = [30, 49, 12, 12, 24, -26];

  static const double _center = GuSizes.successCheck / 2;

  /// Tik yolu, viewBox 96 koordinatlarında.
  static final Path _tick = Path()
    ..moveTo(_checkPath[0], _checkPath[1])
    ..relativeLineTo(_checkPath[2], _checkPath[3])
    ..relativeLineTo(_checkPath[4], _checkPath[5]);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / GuSizes.successCheck;
    canvas
      ..save()
      ..scale(scale, scale);
    // SVG `<circle>` saat 3'ten başlar, saat yönünde ilerler.
    final arcLength = _circleDash * circle.value;
    if (arcLength > 0) {
      canvas.drawArc(
        Rect.fromCircle(
          center: const Offset(_center, _center),
          radius: GuSizes.successCircleR,
        ),
        0,
        math.min(arcLength / GuSizes.successCircleR, 2 * math.pi),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = GuSizes.successCircleStroke
          ..color = color,
      );
    }
    final metric = _tick.computeMetrics().first;
    final tickLength = math.min(_checkDash * check.value, metric.length);
    if (tickLength > 0) {
      canvas.drawPath(
        metric.extractPath(0, tickLength),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = GuSizes.successCheckStroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = color,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SuccessCheckPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.circle != circle ||
      oldDelegate.check != check;
}
