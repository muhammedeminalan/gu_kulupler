// T-04 · GuSpinner (widget-catalog #3; CD-25; css:153, 427).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

Finder _within(Type type) =>
    find.descendant(of: find.byType(GuSpinner), matching: find.byType(type));

double _turns(WidgetTester tester) =>
    tester.widget<RotationTransition>(_within(RotationTransition)).turns.value;

void main() {
  group('T-04 · GuSpinner', () {
    testWidgets('T-04 · GuSpinner · 20 px / 2.5 kalınlık, 270° yay, 800 ms '
        'doğrusal dönüş, renk kapsayıcıdan; Semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(
        Center(
          child: DefaultTextStyle(
            style: TextStyle(color: GuColors.light.textMuted),
            child: const GuSpinner(semanticLabel: 'Yükleniyor'),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(GuSpinner)),
        const Size.square(GuSizes.spinner),
      );
      expect(
        _within(CustomPaint),
        paints..arc(
          rect: const Rect.fromLTWH(1.25, 1.25, 17.5, 17.5),
          startAngle: math.pi / 4,
          sweepAngle: math.pi * 3 / 2,
          useCenter: false,
          color: GuColors.light.textMuted,
          strokeWidth: GuSizes.spinnerStroke,
          style: PaintingStyle.stroke,
        ),
      );
      expect(_turns(tester), 0);
      await tester.pump(GuMotion.spin * 0.25);
      expect(_turns(tester), closeTo(0.25, 1e-9));
      await tester.pump(GuMotion.spin);
      expect(_turns(tester), closeTo(0.25, 1e-9));
      expect(tester.hasRunningAnimations, isTrue);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Yükleniyor')),
        matchesSemantics(label: 'Yükleniyor', isLiveRegion: true),
      );

      // Açık renk ve ölçü parametreleri.
      await tester.pumpApp(
        Center(
          child: GuSpinner(
            size: GuSizes.icon24,
            strokeWidth: GuSizes.navBadgeBorder,
            color: GuColors.light.brandOnPrimary,
          ),
        ),
      );
      expect(tester.getSize(find.byType(GuSpinner)), const Size.square(24));
      expect(
        _within(CustomPaint),
        paints..arc(color: GuColors.light.brandOnPrimary, strokeWidth: 2),
      );
      // Etiketsiz → dekoratif.
      expect(find.bySemanticsLabel(RegExp('.+')), findsNothing);
      handle.dispose();
    });

    testWidgets('T-04 · GuSpinner · azaltılmış harekette durağan 270° yay', (
      tester,
    ) async {
      final reduce = ValueNotifier<bool>(true);
      addTearDown(reduce.dispose);
      await tester.pumpApp(
        ValueListenableBuilder<bool>(
          valueListenable: reduce,
          builder: (context, disable, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: disable),
            child: child!,
          ),
          child: const Material(child: Center(child: GuSpinner())),
        ),
      );
      await tester.pump(GuMotion.spin * 0.5);
      expect(_turns(tester), 0);
      expect(tester.hasRunningAnimations, isFalse);
      // Material → DefaultTextStyle (bodyM) rengi = currentColor eşdeğeri.
      expect(
        _within(CustomPaint),
        paints..arc(
          color: GuColors.light.textPrimary,
          sweepAngle: math.pi * 3 / 2,
        ),
      );

      reduce.value = false;
      await tester.pump();
      await tester.pump(GuMotion.spin * 0.5);
      expect(_turns(tester), closeTo(0.5, 1e-9));

      reduce.value = true;
      await tester.pump();
      expect(_turns(tester), 0);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
