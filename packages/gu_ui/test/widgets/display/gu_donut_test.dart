// T-04 · GuDonut (widget-catalog #21; CD-101, K-39, K-57).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

final Finder _canvas = find.descendant(
  of: find.byType(GuDonut),
  matching: find.byType(CustomPaint),
);

void main() {
  group('T-04 · GuDonut', () {
    testWidgets('T-04 · GuDonut · 96 px halka, kalınlık 10, iz + %62 dolum; '
        'metin donutValueFor, ölçeklenmez; Semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(
        const Center(
          child: GuDonut(
            value: 62,
            valueLabel: '%62',
            semanticLabel: 'Yoklama oranı %62',
          ),
        ),
        textScale: 1.6,
      );
      const c = GuColors.light;
      expect(tester.getSize(find.byType(GuDonut)), const Size.square(96));
      // ui.js:93 — r = (96 − 10) / 2, saat 12'den saat yönünde, yuvarlak uç.
      const ring = Rect.fromLTWH(5, 5, 86, 86);
      expect(
        _canvas,
        paints
          ..arc(
            rect: ring,
            startAngle: -math.pi / 2,
            sweepAngle: 2 * math.pi,
            color: c.bgSurfaceMuted,
            strokeWidth: 10,
            style: PaintingStyle.stroke,
            strokeCap: StrokeCap.butt,
          )
          ..arc(
            rect: ring,
            startAngle: -math.pi / 2,
            sweepAngle: 2 * math.pi * 0.62,
            color: c.brandPrimary,
            strokeWidth: 10,
            style: PaintingStyle.stroke,
            strokeCap: StrokeCap.round,
          ),
      );

      // Montserrat 700, 96 / 4.5 px, text.heading; K-57: ölçeklenmez.
      final text = tester.widget<Text>(find.text('%62'));
      expect(text.style, GuTypography.resolve(c).donutValueFor(96));
      expect(text.style!.fontSize, closeTo(21.333, 0.001));
      expect(text.style!.color, c.textHeading);
      expect(text.textScaler, TextScaler.noScaling);

      expect(
        tester.getSemantics(find.byType(GuDonut)),
        matchesSemantics(label: 'Yoklama oranı %62', isImage: true),
      );
      expect(find.bySemanticsLabel('%62'), findsNothing);
      handle.dispose();
    });

    testWidgets('T-04 · GuDonut · dolum GuMotion.fill ile geçer; değer 0–100 '
        'sınırlanır; 320 dp × 1.6 uzun metin taşmaz', (tester) async {
      final value = ValueNotifier<double>(0);
      addTearDown(value.dispose);
      await tester.pumpApp(
        Center(
          child: ValueListenableBuilder<double>(
            valueListenable: value,
            builder: (context, current, _) => GuDonut(
              value: current,
              valueLabel: '%100 ' * 12,
              semanticLabel: 'Oran',
              size: 56,
              strokeWidth: 6,
            ),
          ),
        ),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(GuDonut)), const Size.square(56));
      // Metin halkanın iç çapına (56 − 2 × 6) küçültülür.
      expect(
        tester.getSize(find.byType(FittedBox)).width,
        lessThanOrEqualTo(44),
      );
      // %0 → yalnızca iz çizilir.
      expect(_canvas, paints..arc(color: GuColors.light.bgSurfaceMuted));
      expect(
        _canvas,
        isNot(
          paints
            ..arc()
            ..arc(),
        ),
      );

      value.value = 250;
      await tester.pump();
      await tester.pump(GuMotion.fill ~/ 2);
      expect(
        _canvas,
        paints
          ..arc()
          ..arc(color: GuColors.light.brandPrimary),
      );
      expect(
        _canvas,
        isNot(
          paints
            ..arc()
            ..arc(sweepAngle: 2 * math.pi),
        ),
      );
      await tester.pump(GuMotion.fill);
      expect(
        _canvas,
        paints
          ..arc()
          ..arc(sweepAngle: 2 * math.pi),
      );
      expect(
        const GuDonut(
          value: double.nan,
          valueLabel: '',
          semanticLabel: '',
        ).fraction,
        0,
      );
    });
  });
}
