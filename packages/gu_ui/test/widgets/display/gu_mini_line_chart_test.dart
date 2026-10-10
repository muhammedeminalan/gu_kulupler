// T-04 · GuMiniLineChart (widget-catalog #35; K-03, K-57, CD-114).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

const _data = <double>[120, 128, 131, 140, 146, 152, 160, 171];
const _labels = ['-7', '-6', '-5', '-4', '-3', '-2', '-1', '0'];
const _action = 'MGT-01.chart.point';

String _pointLabel(int index, double value) =>
    'Hafta ${_labels[index]}: ${value.round()}';

String _tooltip(int index, double value) =>
    '${_labels[index]} · ${value.round()}';

Finder _point(int index) => find.byKey(GuKey.action('$_action.$index'));

final Finder _chart = find.byType(GuMiniLineChart);
final Finder _canvas = find.descendant(
  of: _chart,
  matching: find.byType(CustomPaint),
);
final Finder _tooltipBox = find.descendant(
  of: _chart,
  matching: find.byType(DecoratedBox),
);

void main() {
  group('T-04 · GuMiniLineChart', () {
    testWidgets('T-04 · GuMiniLineChart · 120 px, alan + çizgi 2.5 + nokta r 4; '
        'dokunma seçer (r 6 + ipucu), ikinci dokunma kaldırır; nokta hedefi '
        '48 dp; Semantics', (tester) async {
      final handle = tester.ensureSemantics();
      final selections = <int?>[];
      await tester.pumpApp(
        Center(
          child: Padding(
            padding: GuInsets.all32,
            child: GuMiniLineChart(
              data: _data,
              labels: _labels,
              pointKeyBuilder: (i) => GuKey.action('$_action.$i'),
              semanticLabel: 'Üye büyümesi',
              pointLabelBuilder: _pointLabel,
              tooltipBuilder: _tooltip,
              onPointSelected: selections.add,
            ),
          ),
        ),
      );
      const c = GuColors.light;
      const size = Size(326, 120);
      expect(tester.getSize(_chart), size);
      final origin = tester.getTopLeft(_chart);
      // ui.js:134–135 — viewBox 320×110, dolgu 10; en küçük altta, en büyük
      // üstte.
      final points = GuMiniLineChart.pointsFor(_data, size);
      expect(points, hasLength(8));
      expect(
        points.first,
        offsetMoreOrLessEquals(const Offset(10 * 326 / 320, 100 * 120 / 110)),
      );
      expect(
        points.last,
        offsetMoreOrLessEquals(const Offset(310 * 326 / 320, 10 * 120 / 110)),
      );

      expect(
        _canvas,
        paints
          ..path(
            color: c.brandPrimaryContainer.withValues(alpha: 0.6),
            style: PaintingStyle.fill,
          )
          ..path(
            color: c.brandPrimary,
            strokeWidth: 2.5,
            style: PaintingStyle.stroke,
          )
          ..circle(
            x: points[0].dx,
            y: points[0].dy,
            radius: 4,
            color: c.bgSurface,
            style: PaintingStyle.fill,
          )
          ..circle(
            x: points[0].dx,
            y: points[0].dy,
            radius: 4,
            color: c.brandPrimary,
            strokeWidth: 2,
            style: PaintingStyle.stroke,
          ),
      );

      // K-03: görsel 8 px, algılama kutusu 48 dp ve noktada ortalı.
      for (var i = 0; i < 8; i++) {
        expect(tester.getSize(_point(i)), const Size.square(48));
        expect(
          tester.getCenter(_point(i)),
          offsetMoreOrLessEquals(origin + points[i]),
        );
      }
      expect(find.bySemanticsLabel('Üye büyümesi'), findsOneWidget);
      expect(
        tester.getSemantics(_point(3)),
        matchesSemantics(
          label: 'Hafta -4: 140',
          isButton: true,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      expect(_tooltipBox, findsNothing);

      // Seçim: nokta r 6 dolu brand.primary + ipucu (css:341).
      await tester.tap(_point(3));
      await tester.pump();
      expect(selections, [3]);
      final selectedPattern = paints;
      for (var i = 0; i < 3; i++) {
        selectedPattern
          ..circle(radius: 4, color: c.bgSurface)
          ..circle(radius: 4);
      }
      selectedPattern.circle(
        x: points[3].dx,
        y: points[3].dy,
        radius: 6,
        color: c.brandPrimary,
        style: PaintingStyle.fill,
      );
      expect(_canvas, selectedPattern);
      final tip = tester.widget<Text>(find.text('-4 · 140'));
      expect(tip.style, GuTypography.resolve(c).tooltip);
      expect(tip.style!.color, c.bgSurface);
      expect(tip.textScaler, TextScaler.noScaling);
      final box = tester.widget<DecoratedBox>(_tooltipBox).decoration;
      expect(
        box,
        BoxDecoration(
          color: c.textHeading,
          borderRadius: GuRadius.borderCheckbox,
        ),
      );
      // translate(-50%, -110%): yatay ortalı, alt kenar noktanın %10 üstünde.
      final tipRect = tester.getRect(_tooltipBox);
      expect(tipRect.center.dx, closeTo(origin.dx + points[3].dx, 1e-6));
      expect(
        tipRect.bottom,
        closeTo(origin.dy + points[3].dy - tipRect.height * 0.1, 1e-6),
      );
      expect(
        tester.getSize(find.text('-4 · 140')),
        Size(tipRect.width - 16, tipRect.height - 8),
      );
      expect(
        tester.getSemantics(_point(3)),
        matchesSemantics(
          label: 'Hafta -4: 140',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );

      // Erişilebilirlik eylemi de seçer; aynı noktaya ikinci dokunma kaldırır.
      tester.semantics.tap(find.semantics.byLabel('Hafta -1: 160'));
      await tester.pump();
      expect(selections, [3, 6]);
      expect(find.text('-1 · 160'), findsOneWidget);
      await tester.tap(_point(6));
      await tester.pump();
      expect(selections, [3, 6, null]);
      expect(_tooltipBox, findsNothing);
      handle.dispose();
    });

    testWidgets(
      'T-04 · GuMiniLineChart · 320 dp × 1.6: üst üste binen kutuda en '
      'yakın nokta seçilir; ipucu grafiğin içinde kalır, uzun metin taşmaz; '
      'veri kısalınca seçim düşer',
      (tester) async {
        final long = 'Çok uzun hafta etiketi ' * 8;
        final data = ValueNotifier<List<double>>(_data);
        addTearDown(data.dispose);
        final selections = <int?>[];
        await tester.pumpApp(
          Center(
            child: Padding(
              padding: GuInsets.h16,
              child: ValueListenableBuilder<List<double>>(
                valueListenable: data,
                builder: (context, values, _) => GuMiniLineChart(
                  data: values,
                  labels: _labels.sublist(0, values.length),
                  pointKeyBuilder: (i) => GuKey.action('$_action.$i'),
                  semanticLabel: 'Grafik',
                  pointLabelBuilder: (index, value) =>
                      index == 7 ? long : _pointLabel(index, value),
                  onPointSelected: selections.add,
                ),
              ),
            ),
          ),
          size: const Size(320, 640),
          textScale: 1.6,
          theme: ThemeMode.dark,
        );
        final chart = tester.getRect(_chart);
        expect(chart.size, const Size(288, 120));
        // Nokta aralığı (≈ 38.6) < 48: 0 ve 1 kutuları üst üste biner. Dokunuş
        // sonra çizilen 1. kutuya düşer ama 0. noktaya daha yakındır.
        final target = tester.getCenter(_point(0)) + const Offset(16, 0);
        expect(tester.getRect(_point(1)).contains(target), isTrue);
        await tester.tapAt(target);
        await tester.pump();
        expect(selections, [0]);
        // tooltipBuilder yok → pointLabelBuilder metni; sol kenara yaslanır.
        expect(find.text('Hafta -7: 120'), findsOneWidget);
        expect(tester.getRect(_tooltipBox).left, chart.left);
        expect(
          tester.widget<Text>(find.text('Hafta -7: 120')).style!.color,
          GuColors.dark.bgSurface,
        );

        await tester.tap(_point(7));
        await tester.pump();
        expect(selections, [0, 7]);
        expect(tester.takeException(), isNull);
        final tip = tester.getRect(_tooltipBox);
        expect(tip.left, chart.left);
        expect(tip.right, chart.right);

        // Veri kısalır → seçim (7) geçersiz, ipucu kalkar; tek nokta ortada.
        data.value = const [5];
        await tester.pump();
        expect(_tooltipBox, findsNothing);
        expect(_point(1), findsNothing);
        expect(tester.getCenter(_point(0)).dx, closeTo(chart.center.dx, 1e-6));
        data.value = const [];
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(_point(0), findsNothing);
      },
    );
  });
}
