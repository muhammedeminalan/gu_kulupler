// T-06 · GuPageDots (widget-catalog #70; A.2 #70; css:394;
// screens-auth.js:49; CD-25).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

final Finder _dots = find.descendant(
  of: find.byType(GuPageDots),
  matching: find.byType(AnimatedContainer),
);

Color? _color(WidgetTester tester, int index) =>
    (tester.widget<AnimatedContainer>(_dots.at(index)).decoration!
            as BoxDecoration)
        .color;

void main() {
  group('T-06 · GuPageDots', () {
    testWidgets('T-06 · GuPageDots · nokta 8, etkin 24, aralık 6, ortalı; '
        'renkler açık + koyu; geçiş GuMotion.base, azaltılmış harekette '
        'anında', (tester) async {
      for (final (mode, colors) in [
        (ThemeMode.light, GuColors.light),
        (ThemeMode.dark, GuColors.dark),
      ]) {
        await tester.pumpApp(
          const Center(child: GuPageDots(count: 3, index: 0)),
          theme: mode,
        );
        expect(_dots, findsNWidgets(3));
        // 24 + 6 + 8 + 6 + 8 = 52, 390 içinde ortalı.
        expect(
          tester.getRect(_dots.at(0)),
          const Rect.fromLTWH(169, 418, 24, 8),
        );
        expect(tester.getRect(_dots.at(1)).left, 169 + 24 + 6);
        expect(tester.getSize(_dots.at(1)), const Size.square(8));
        expect(tester.getRect(_dots.at(2)).left, 169 + 24 + 6 + 8 + 6);
        expect(_color(tester, 0), colors.brandPrimary, reason: '$mode');
        expect(_color(tester, 1), colors.borderDefault);
        expect(
          (tester.widget<AnimatedContainer>(_dots.at(0)).decoration!
                  as BoxDecoration)
              .borderRadius,
          GuRadius.borderFull,
        );
      }

      var index = 0;
      late StateSetter rebuild;
      Widget host({required bool reduceMotion}) => MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Center(
          child: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return GuPageDots(count: 3, index: index);
            },
          ),
        ),
      );

      await tester.pumpApp(host(reduceMotion: false));
      rebuild(() => index = 1);
      await tester.pump();
      await tester.pump(GuMotion.base ~/ 2);
      expect(tester.getSize(_dots.at(1)).width, inExclusiveRange(8, 24));
      await tester.pump(GuMotion.base);
      expect(tester.getSize(_dots.at(0)).width, 8);
      expect(tester.getSize(_dots.at(1)).width, 24);

      await tester.pumpApp(host(reduceMotion: true));
      rebuild(() => index = 2);
      await tester.pump();
      await tester.pump();
      expect(tester.getSize(_dots.at(2)).width, 24);
      expect(tester.getSize(_dots.at(1)).width, 8);
      index = 0;
    });

    testWidgets('T-06 · GuPageDots · varsayılan dekoratif; semanticLabel → tek '
        'düğüm', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(
        const Center(child: GuPageDots(count: 3, index: 1)),
      );
      expect(
        find.descendant(
          of: find.byType(GuPageDots),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('.+')), findsNothing);

      await tester.pumpApp(
        const Center(
          child: GuPageDots(count: 3, index: 1, semanticLabel: '2 / 3'),
        ),
      );
      expect(
        tester.getSemantics(find.byType(GuPageDots)),
        isSemantics(label: '2 / 3'),
      );
      handle.dispose();
    });
  });
}
