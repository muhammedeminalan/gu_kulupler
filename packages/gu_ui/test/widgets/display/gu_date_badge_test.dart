// T-04 · GuDateBadge (widget-catalog #31; CD-11, K-57).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('T-04 · GuDateBadge', () {
    testWidgets('T-04 · GuDateBadge · 48×52, radius 12, primaryContainer; gün '
        '18 / ay 11 (üst boşluk 3); Semantics tek düğüm', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(
        const Center(child: GuDateBadge(day: 9, monthShort: 'EKİ')),
      );
      const c = GuColors.light;
      final typography = GuTypography.resolve(c);
      expect(tester.getSize(find.byType(GuDateBadge)), const Size(48, 52));
      final box =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: find.byType(GuDateBadge),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      expect(box.color, c.brandPrimaryContainer);
      expect(box.borderRadius, GuRadius.borderSm);

      final day = tester.widget<Text>(find.text('9'));
      final month = tester.widget<Text>(find.text('EKİ'));
      expect(day.style, typography.dateBadgeDay);
      expect(day.style!.color, c.brandOnPrimaryContainer);
      expect(day.textScaler, isNull);
      expect(month.style, typography.dateBadgeMonth);
      expect(month.textScaler, TextScaler.noScaling);
      // css:319 — satır yüksekliği 1: 18 + 3 + 11, kutuda dikey ortalı.
      expect(tester.getSize(find.text('9')).height, 18);
      expect(tester.getSize(find.text('EKİ')).height, 11);
      expect(
        tester.getTopLeft(find.text('EKİ')).dy -
            tester.getBottomLeft(find.text('9')).dy,
        3,
      );
      expect(
        tester.getCenter(find.byType(Column)),
        tester.getCenter(find.byType(GuDateBadge)),
      );
      expect(
        tester.getSemantics(find.byType(GuDateBadge)),
        matchesSemantics(label: '9\nEKİ'),
      );
      handle.dispose();
    });

    testWidgets(
      'T-04 · GuDateBadge · 320 dp × 1.6: kutu sabit, gün ölçeklenir, '
      'ay ölçeklenmez (K-57), taşma yok; semanticLabel',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpApp(
          const Center(
            child: GuDateBadge(
              day: 28,
              monthShort: 'EYLÜL EYLÜL',
              semanticLabel: '28 Eylül Pazartesi',
            ),
          ),
          size: const Size(320, 640),
          textScale: 1.6,
          theme: ThemeMode.dark,
        );
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(GuDateBadge)), const Size(48, 52));
        expect(
          tester.renderObject<RenderParagraph>(find.text('28')).textScaler,
          const TextScaler.linear(1.6),
        );
        expect(
          tester
              .renderObject<RenderParagraph>(find.text('EYLÜL EYLÜL'))
              .textScaler,
          TextScaler.noScaling,
        );
        // İçerik kutuya sığacak biçimde küçültülür.
        final content = tester.getRect(find.byType(FittedBox));
        expect(content.width, lessThanOrEqualTo(48));
        expect(content.height, lessThanOrEqualTo(52));
        expect(
          (tester
                      .widget<DecoratedBox>(
                        find.descendant(
                          of: find.byType(GuDateBadge),
                          matching: find.byType(DecoratedBox),
                        ),
                      )
                      .decoration
                  as BoxDecoration)
              .color,
          GuColors.dark.brandPrimaryContainer,
        );
        expect(find.bySemanticsLabel('28 Eylül Pazartesi'), findsOneWidget);
        expect(find.bySemanticsLabel('28'), findsNothing);
        handle.dispose();
      },
    );
  });
}
