import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/tokens/gu_opacity.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';
import 'package:gu_ui/src/utils/gu_tap_target.dart';

/// Mini çizgi grafik — prototip `MiniLineChart` (`ui.js:133–139`), CSS
/// `.mini-chart` + `.tooltip` (css:341–342): yükseklik 120, genişliğe esner
/// (viewBox 320×110, dolgu 10); alan dolgusu `brand.primaryContainer` × .6,
/// çizgi 2.5 yuvarlak uç, nokta r 4 (seçili 6, dolu `brand.primary`).
///
/// * Noktaya dokunma seçer, ikinci dokunma kaldırır; seçili noktanın
///   üstünde ipucu çıkar ([tooltipBuilder], yoksa [pointLabelBuilder] metni).
/// * Nokta görseli 8 px kalır; her noktanın algılama kutusu
///   `GuTapTarget.minSizeFor` kenarlı karedir (K-03). Kutular dar ekranda
///   üst üste biner; dokunuş **en yakın** noktaya gider.
/// * Nokta anahtarlarını çağıran üretir ([pointKeyBuilder]:
///   `(i) => GuKey.action('MGT-01.chart.point.$i')`, CD-111);
///   erişilebilirlik etiketi çağırandan
///   ([pointLabelBuilder], CD-114 — gu_ui metin birleştirmez).
/// * SVG `preserveAspectRatio="none"` bozulması taşınmaz: nokta ve çizgi
///   ölçüleri her genişlikte token değerindedir, yalnızca konumlar esner.
class GuMiniLineChart extends StatefulWidget {
  const GuMiniLineChart({
    required this.data,
    required this.labels,
    required this.semanticLabel,
    required this.pointLabelBuilder,
    this.pointKeyBuilder,
    this.onPointSelected,
    this.tooltipBuilder,
    super.key,
  });

  /// Değerler (soldan sağa).
  final List<double> data;

  /// Nokta etiketleri ([data] ile aynı sıra ve uzunlukta); metinleri
  /// [pointLabelBuilder] / [tooltipBuilder] üretir.
  final List<String> labels;

  /// Nokta anahtarı üreticisi (`GuKey.action('<ID>.chart.point.$i')`);
  /// anahtar literali ekran dosyasında kalır (aksiyon envanteri taraması).
  final Key Function(int index)? pointKeyBuilder;

  /// Grafiğin erişilebilirlik etiketi (`role="img"` + `aria-label`).
  final String semanticLabel;

  /// Nokta erişilebilirlik etiketi (ARB `chartPointLabel`).
  final String Function(int index, double value) pointLabelBuilder;

  /// Seçim değişimi: seçilen nokta, kaldırılınca `null`.
  final ValueChanged<int?>? onPointSelected;

  /// İpucu metni; `null` → [pointLabelBuilder].
  final String Function(int index, double value)? tooltipBuilder;

  /// [data] noktalarının [size] içindeki konumları (ui.js:134–135): viewBox
  /// koordinatı × (`size` / viewBox).
  static List<Offset> pointsFor(List<double> data, Size size) {
    if (data.isEmpty) return const [];
    final scaleX = size.width / GuSizes.miniChartViewW;
    final scaleY = size.height / GuSizes.miniChartViewH;
    const innerWidth = GuSizes.miniChartViewW - GuSizes.miniChartPad * 2;
    const innerHeight = GuSizes.miniChartViewH - GuSizes.miniChartPad * 2;
    final low = data.reduce(math.min);
    final span = math.max<double>(1, data.reduce(math.max) - low);
    final last = data.length - 1;
    return [
      for (final (index, value) in data.indexed)
        Offset(
          (GuSizes.miniChartPad +
                  (last == 0 ? innerWidth / 2 : index * innerWidth / last)) *
              scaleX,
          (GuSizes.miniChartViewH -
                  GuSizes.miniChartPad -
                  (value - low) / span * innerHeight) *
              scaleY,
        ),
    ];
  }

  @override
  State<GuMiniLineChart> createState() => _GuMiniLineChartState();
}

class _GuMiniLineChartState extends State<GuMiniLineChart> {
  int? _selected;

  @override
  void didUpdateWidget(GuMiniLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = _selected;
    if (selected != null && selected >= widget.data.length) _selected = null;
  }

  void _toggle(int index) {
    final next = _selected == index ? null : index;
    setState(() => _selected = next);
    widget.onPointSelected?.call(next);
  }

  /// [position] (grafik koordinatı) algılama kutusuna düşen noktalardan en
  /// yakınını seçer; [fallback] dokunuşu alan kutunun noktasıdır.
  void _tapAt(
    Offset position,
    List<Offset> points,
    double reach,
    int fallback,
  ) {
    var nearest = fallback;
    var best = double.infinity;
    for (final (index, point) in points.indexed) {
      final delta = point - position;
      if (delta.dx.abs() > reach / 2 || delta.dy.abs() > reach / 2) continue;
      if (delta.distanceSquared < best) {
        best = delta.distanceSquared;
        nearest = index;
      }
    }
    _toggle(nearest);
  }

  @override
  Widget build(BuildContext context) {
    assert(
      widget.labels.length == widget.data.length,
      'GuMiniLineChart: labels ve data aynı uzunlukta olmalı.',
    );
    final gu = context.gu;
    final colors = gu.colors;
    final data = widget.data;
    final selected = _selected;
    final reach = GuTapTarget.minSizeFor(defaultTargetPlatform);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.semanticLabel,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(
            constraints.hasBoundedWidth
                ? constraints.maxWidth
                : GuSizes.miniChartViewW,
            GuSizes.miniChartHeight,
          );
          final points = GuMiniLineChart.pointsFor(data, size);
          return SizedBox.fromSize(
            size: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _MiniLineChartPainter(
                      points: points,
                      selected: selected,
                      line: colors.brandPrimary,
                      area: colors.brandPrimaryContainer.withValues(
                        alpha: GuOpacity.miniChartFill,
                      ),
                      pointFill: colors.bgSurface,
                    ),
                  ),
                ),
                for (final (index, point) in points.indexed)
                  Positioned(
                    left: point.dx - reach / 2,
                    top: point.dy - reach / 2,
                    width: reach,
                    height: reach,
                    child: Semantics(
                      key: widget.pointKeyBuilder?.call(index),
                      container: true,
                      button: true,
                      selected: index == selected,
                      label: widget.pointLabelBuilder(index, data[index]),
                      onTap: () => _toggle(index),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        excludeFromSemantics: true,
                        onTapUp: (details) => _tapAt(
                          point -
                              Offset(reach / 2, reach / 2) +
                              details.localPosition,
                          points,
                          reach,
                          index,
                        ),
                      ),
                    ),
                  ),
                if (selected != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: CustomSingleChildLayout(
                          delegate: _TooltipLayout(points[selected]),
                          child: _ChartTooltip(
                            (widget.tooltipBuilder ?? widget.pointLabelBuilder)(
                              selected,
                              data[selected],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// İpucu balonu — CSS `.tooltip` (css:341): `text.heading` zemin, `bg.surface`
/// metin, dolgu 4/8, radius 6, Inter 600 11 (ölçeklenmez, K-57), tek satır.
class _ChartTooltip extends StatelessWidget {
  const _ChartTooltip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: gu.colors.textHeading,
        borderRadius: GuRadius.borderCheckbox,
      ),
      child: Padding(
        padding: GuInsets.sym(
          h: GuSizes.tooltipPaddingX,
          v: GuSizes.tooltipPaddingY,
        ),
        child: Text(
          text,
          style: gu.text.tooltip,
          textScaler: TextScaler.noScaling,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// `.tooltip{transform:translate(-50%,-110%)}` (css:341): noktanın üstünde
/// yatay ortalı. Prototipten fark: balon grafik genişliğinin içinde tutulur
/// (ilk / son noktada kart kenarında kırpılmaz).
class _TooltipLayout extends SingleChildLayoutDelegate {
  const _TooltipLayout(this.anchor);

  final Offset anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(maxWidth: constraints.maxWidth);

  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset(
    (anchor.dx - childSize.width / 2).clamp(
      0,
      math.max(0, size.width - childSize.width),
    ),
    anchor.dy + GuSizes.tooltipOffsetYRatio * childSize.height,
  );

  @override
  bool shouldRelayout(_TooltipLayout oldDelegate) =>
      oldDelegate.anchor != anchor;
}

/// SVG eşdeğeri (ui.js:137): alan yolu (çizgi + taban), çizgi, noktalar.
class _MiniLineChartPainter extends CustomPainter {
  const _MiniLineChartPainter({
    required this.points,
    required this.selected,
    required this.line,
    required this.area,
    required this.pointFill,
  });

  final List<Offset> points;
  final int? selected;
  final Color line;
  final Color area;
  final Color pointFill;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas
      ..drawPath(
        Path.from(path)
          ..lineTo(points.last.dx, size.height)
          ..lineTo(points.first.dx, size.height)
          ..close(),
        Paint()..color = area,
      )
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = GuSizes.miniChartLine
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..color = line,
      );
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = GuSizes.miniChartPointStroke
      ..color = line;
    for (final (index, point) in points.indexed) {
      final isSelected = index == selected;
      final radius = isSelected
          ? GuSizes.miniChartPointSelected
          : GuSizes.miniChartPoint;
      canvas
        ..drawCircle(
          point,
          radius,
          Paint()..color = isSelected ? line : pointFill,
        )
        ..drawCircle(point, radius, stroke);
    }
  }

  @override
  bool shouldRepaint(_MiniLineChartPainter oldDelegate) =>
      !listEquals(oldDelegate.points, points) ||
      oldDelegate.selected != selected ||
      oldDelegate.line != line ||
      oldDelegate.area != area ||
      oldDelegate.pointFill != pointFill;
}
