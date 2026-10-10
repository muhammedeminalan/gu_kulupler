// T-05 · GuStepbar (widget-catalog #30; A.2 #30; css:320; G6).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

Widget _host(Widget child) => Center(
  child: Padding(padding: GuInsets.h16, child: child),
);

List<BoxDecoration> _bars(WidgetTester tester) => [
  for (final box in tester.widgetList<DecoratedBox>(
    find.descendant(
      of: find.byType(GuStepbar),
      matching: find.byType(DecoratedBox),
    ),
  ))
    box.decoration as BoxDecoration,
];

void main() {
  group('T-05 · GuStepbar', () {
    testWidgets('T-05 · GuStepbar · eşit parçalar (aralık 6, yükseklik 4, '
        'radius 2), dolu brand.primary / boş border.default açık + koyu; '
        'Semantics değeri', (tester) async {
      final handle = tester.ensureSemantics();
      for (final (mode, colors) in [
        (ThemeMode.light, GuColors.light),
        (ThemeMode.dark, GuColors.dark),
      ]) {
        await tester.pumpApp(
          _host(const GuStepbar(step: 2, total: 3, semanticLabel: '2/3')),
          theme: mode,
        );
        final bar = find.byType(GuStepbar);
        expect(tester.getSize(bar), const Size(358, 4));
        final parts = find.descendant(
          of: bar,
          matching: find.byType(DecoratedBox),
        );
        expect(parts, findsNWidgets(3));
        // (358 − 2×6) / 3.
        for (var index = 0; index < 3; index++) {
          final size = tester.getSize(parts.at(index));
          expect(size.width, closeTo(346 / 3, 0.001));
          expect(size.height, 4);
        }
        expect(
          tester.getTopLeft(parts.at(1)).dx -
              tester.getTopRight(parts.at(0)).dx,
          closeTo(6, 0.001),
        );
        final bars = _bars(tester);
        expect(
          [for (final bar in bars) bar.color],
          [colors.brandPrimary, colors.brandPrimary, colors.borderDefault],
          reason: '$mode',
        );
        expect(bars.first.borderRadius, GuRadius.borderHandle);
        expect(tester.getSemantics(bar), isSemantics(value: '2/3'));
      }
      handle.dispose();
    });

    testWidgets('T-05 · GuStepbar · sınır değerleri: step 0 → hepsi boş, '
        'step > total → hepsi dolu, total 0 → parça yok; 320 dp taşmaz', (
      tester,
    ) async {
      const colors = GuColors.light;
      await tester.pumpApp(
        _host(const GuStepbar(step: 0, total: 3, semanticLabel: '0/3')),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(GuStepbar)), const Size(288, 4));
      expect(
        _bars(tester).map((bar) => bar.color),
        everyElement(colors.borderDefault),
      );

      await tester.pumpApp(
        _host(const GuStepbar(step: 5, total: 4, semanticLabel: '4/4')),
      );
      expect(_bars(tester), hasLength(4));
      expect(
        _bars(tester).map((bar) => bar.color),
        everyElement(colors.brandPrimary),
      );

      await tester.pumpApp(
        _host(const GuStepbar(step: 0, total: 0, semanticLabel: '0/0')),
      );
      expect(_bars(tester), isEmpty);
      expect(tester.takeException(), isNull);
    });
  });
}
