// T-07 · GuTextScale (widget-catalog ek-5; Q-14, K-08; PLAN §7.13).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../helpers/pump_app.dart';

void main() {
  group('T-07 · GuTextScale', () {
    test('T-07 · GuTextScale · düzeyler 1.0 / 1.3 / 1.6; etkin ölçek '
        'tablosu (§7.13): sistem × uygulama, tavan 1.6', () {
      expect(GuTextScaleLevel.values.map((l) => l.factor), [1.0, 1.3, 1.6]);
      expect(GuTextScale.maxScale, 1.6);
      expect(GuTextScaleLevel.values.last.factor, GuTextScale.maxScale);

      const table = <(double, GuTextScaleLevel, double)>[
        (1, GuTextScaleLevel.s100, 1),
        (1, GuTextScaleLevel.s130, 1.3),
        (1, GuTextScaleLevel.s160, 1.6),
        // 1.69 → 1.6.
        (1.3, GuTextScaleLevel.s130, 1.6),
        (2, GuTextScaleLevel.s100, 1.6),
        (0.85, GuTextScaleLevel.s160, 1.36),
      ];
      for (final (system, level, expected) in table) {
        final reason = '$system × $level';
        expect(
          GuTextScale.effectiveScale(system, level),
          moreOrLessEquals(expected, epsilon: 1e-9),
          reason: reason,
        );
        expect(
          GuTextScale.resolve(TextScaler.linear(system), level).scale(10),
          moreOrLessEquals(expected * 10, epsilon: 1e-9),
          reason: reason,
        );
      }
    });

    testWidgets('T-07 · GuTextScale · MediaQuery textScaler yeniden yazılır: '
        '1.3 × 1.3 → 1.6 kırpılır (15 → 24); context.gu.textScaler ve Text '
        'aynı ölçeği görür; diğer MediaQuery alanları korunur', (tester) async {
      late MediaQueryData inner;
      late TextScaler fromGu;
      const padding = EdgeInsets.only(top: 47, bottom: 34);
      await tester.pumpApp(
        GuTextScale(
          level: GuTextScaleLevel.s130,
          child: Builder(
            builder: (context) {
              inner = MediaQuery.of(context);
              fromGu = context.gu.textScaler;
              return const Align(
                alignment: Alignment.topLeft,
                child: Text('Ölçek', style: TextStyle(fontSize: 15, height: 1)),
              );
            },
          ),
        ),
        textScale: 1.3,
        viewPadding: padding,
      );
      expect(inner.textScaler, const TextScaler.linear(GuTextScale.maxScale));
      expect(inner.textScaler.scale(15), moreOrLessEquals(24, epsilon: 1e-9));
      expect(fromGu, inner.textScaler);
      expect(inner.viewPadding, padding);
      expect(inner.size, const Size(390, 844));
      expect(
        tester.getSize(find.text('Ölçek')).height,
        moreOrLessEquals(24, epsilon: 0.01),
      );

      // Kırpma yokken çarpım: 1.0 × 1.3.
      await tester.pumpApp(
        GuTextScale(
          level: GuTextScaleLevel.s130,
          child: Builder(
            builder: (context) {
              inner = MediaQuery.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(inner.textScaler.scale(10), moreOrLessEquals(13, epsilon: 1e-9));
    });
  });
}
