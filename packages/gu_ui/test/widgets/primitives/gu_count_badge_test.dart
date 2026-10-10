// T-04 · GuCountBadge (widget-catalog #66; CD-81, G8, K-57).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

/// Rozetin (dıştan içe) `BoxDecoration` zincirleri.
List<BoxDecoration> _decorations(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(
      find.descendant(
        of: find.byType(GuCountBadge),
        matching: find.byType(DecoratedBox),
      ),
    )
    .map((box) => box.decoration as BoxDecoration)
    .toList();

Text _text(WidgetTester tester) => tester.widget<Text>(
  find.descendant(of: find.byType(GuCountBadge), matching: find.byType(Text)),
);

void main() {
  group('T-04 · GuCountBadge', () {
    testWidgets('T-04 · GuCountBadge · sm 18 / md 20, tonlar ve halka token '
        'değerleriyle', (tester) async {
      // sm + brand (varsayılan): 18×18 pil, brand.primary + #fff 11/18.
      await tester.pumpApp(const Center(child: GuCountBadge(label: '2')));
      expect(tester.getSize(find.byType(GuCountBadge)), const Size.square(18));
      var boxes = _decorations(tester);
      expect(boxes, hasLength(1));
      expect(boxes.single.color, GuColors.light.brandPrimary);
      expect(boxes.single.borderRadius, GuRadius.borderFull);
      expect(
        _text(tester).style,
        GuTypography.resolve(GuColors.light).countBadge,
      );
      expect(_text(tester).style!.color, GuColors.light.brandOnPrimary);

      // md + muted (MGT-06 sıra): 20 yükseklik, dolgu 6, text.muted zemin.
      await tester.pumpApp(
        const Center(
          child: GuCountBadge(
            label: '12',
            size: GuCountBadgeSize.md,
            tone: GuCountBadgeTone.muted,
          ),
        ),
      );
      final md = tester.getSize(find.byType(GuCountBadge));
      final textWidth = tester.getSize(find.text('12')).width;
      expect(md.height, 20);
      expect(md.width, closeTo(textWidth + 2 * 6, 1e-6));
      expect(md.width, greaterThanOrEqualTo(20));
      expect(_decorations(tester).single.color, GuColors.light.textMuted);
      expect(
        _text(tester).style,
        GuTypography.resolve(GuColors.light).countBadgeLg.copyWith(
          color: GuColors.light.brandOnPrimary,
        ),
      );

      // inverted (koyu temada seçili çip, css:183) + ring (nav-badge, css:137):
      // content-box → dış ölçü 18 + 2 × 2.
      await tester.pumpApp(
        const Center(
          child: GuCountBadge(
            label: '4',
            tone: GuCountBadgeTone.inverted,
            ring: true,
          ),
        ),
        theme: ThemeMode.dark,
      );
      expect(tester.getSize(find.byType(GuCountBadge)), const Size.square(22));
      boxes = _decorations(tester);
      expect(boxes, hasLength(2));
      expect(boxes.first.color, GuColors.dark.bgSurface);
      expect(boxes.first.borderRadius, GuRadius.borderFull);
      expect(boxes.last.color, GuColors.dark.brandOnPrimary);
      expect(_text(tester).style!.color, GuColors.dark.brandPrimary);
    });

    testWidgets('T-04 · GuCountBadge · metin ölçeklenmez (K-57); 320 dp × 1.6 '
        'uzun metin taşmaz; Semantics', (tester) async {
      final handle = tester.ensureSemantics();
      final long = '9' * 80;
      await tester.pumpApp(
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GuCountBadge(label: '9+'),
              GuCountBadge(label: long, size: GuCountBadgeSize.md, ring: true),
            ],
          ),
        ),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.textScaler, TextScaler.noScaling);
        expect(text.maxLines, 1);
        expect(text.overflow, TextOverflow.ellipsis);
      }
      final short = tester.getSize(find.byType(GuCountBadge).first);
      expect(short.height, 18);
      expect(short.width, greaterThan(18));
      final wide = tester.getSize(find.byType(GuCountBadge).last);
      expect(wide, const Size(320, 24));
      expect(find.bySemanticsLabel('9+'), findsOneWidget);
      handle.dispose();
    });
  });
}
