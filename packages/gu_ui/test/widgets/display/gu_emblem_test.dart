// T-03 · GuEmblem (widget-catalog #76; CD-25, CD-91, K-35).
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

BoxDecoration _decoration(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find.descendant(
                of: find.byType(GuEmblem),
                matching: find.byType(DecoratedBox),
              ),
            )
            .decoration
        as BoxDecoration;

/// Dört kenarı aynı [color] / [width] kenarlık.
void _expectBorder(BoxDecoration box, Color color, double width) {
  final border = box.border! as Border;
  expect(border.isUniform, isTrue);
  expect(border.top.color, color);
  expect(border.top.width, width);
}

GuIcon _icon(WidgetTester tester) => tester.widget<GuIcon>(find.byType(GuIcon));

void main() {
  group('T-03 · GuEmblem', () {
    testWidgets('lg 72: bg.surface, radius 20, kenarlık 1 border.soft, e2', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(
        const Center(
          child: GuEmblem(icon: GuIcons.mountain, size: GuEmblemSize.lg),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(GuEmblem)), const Size.square(72));
      final box = _decoration(tester);
      expect(box.color, GuColors.light.bgSurface);
      expect(box.borderRadius, GuRadius.borderLg);
      _expectBorder(box, GuColors.light.borderSoft, GuSizes.emblemBorder);
      expect(box.boxShadow, GuShadows.light.e2);
      expect(_icon(tester).icon, GuIcons.mountain);
      expect(_icon(tester).size, GuSizes.icon34);
      expect(_icon(tester).color, GuColors.light.brandPrimaryText);
      // Dekoratif: ikon semantik ağacına girmez.
      expect(find.bySemanticsLabel(RegExp('.+')), findsNothing);
      handle.dispose();
    });

    testWidgets('sm 44 (varsayılan) ve xs 32: brand container, gölgesiz', (
      tester,
    ) async {
      await tester.pumpApp(const Center(child: GuEmblem(icon: GuIcons.drama)));
      expect(tester.getSize(find.byType(GuEmblem)), const Size.square(44));
      var box = _decoration(tester);
      expect(box.color, GuColors.light.brandPrimaryContainer);
      expect(box.borderRadius, GuRadius.borderSm);
      expect(box.boxShadow, isNull);
      expect(_icon(tester).size, GuSizes.icon20);

      await tester.pumpApp(
        const Center(
          child: GuEmblem(icon: GuIcons.drama, size: GuEmblemSize.xs),
        ),
        theme: ThemeMode.dark,
      );
      expect(tester.getSize(find.byType(GuEmblem)), const Size.square(32));
      box = _decoration(tester);
      expect(box.color, GuColors.dark.brandPrimaryContainer);
      expect(box.borderRadius, GuRadius.borderEmblemXs);
      _expectBorder(box, GuColors.dark.borderSoft, GuSizes.emblemBorder);
      expect(_icon(tester).size, GuSizes.icon16);
      expect(_icon(tester).color, GuColors.dark.brandPrimaryText);
    });

    testWidgets('CD-91 üst yazımları: PRF-01 kamera rozeti', (tester) async {
      const colors = GuColors.light;
      await tester.pumpApp(
        Center(
          child: GuEmblem(
            icon: GuIcons.camera,
            size: GuEmblemSize.xs,
            iconSize: GuSizes.icon14,
            background: colors.brandPrimary,
            foreground: colors.brandOnPrimary,
            borderColor: colors.bgCanvas,
            borderWidth: GuSizes.avatarBadgeBorder,
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      // Kenarlık kutunun içindedir; dış ölçü değişmez.
      expect(tester.getSize(find.byType(GuEmblem)), const Size.square(32));
      final box = _decoration(tester);
      expect(box.color, colors.brandPrimary);
      _expectBorder(box, colors.bgCanvas, 2);
      expect(_icon(tester).size, 14);
      expect(_icon(tester).color, colors.brandOnPrimary);
      expect(
        tester.widget<SvgPicture>(find.byType(SvgPicture)).colorFilter,
        ColorFilter.mode(colors.brandOnPrimary, BlendMode.srcIn),
      );
    });

    testWidgets('child: FED-03 bildirim önizlemesi GuLogo(20)', (tester) async {
      await tester.pumpApp(
        const Center(
          child: GuEmblem(
            size: GuEmblemSize.xs,
            child: GuLogo(size: 20, placeholder: true),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(GuIcon), findsNothing);
      expect(tester.getSize(find.byType(GuLogo)), const Size.square(20));
      expect(
        tester.getCenter(find.byType(GuLogo)),
        tester.getCenter(find.byType(GuEmblem)),
      );
    });

    test('icon ve child: tam biri (assert)', () {
      expect(GuEmblem.new, throwsAssertionError);
      expect(
        () => GuEmblem(icon: GuIcons.bell, child: const SizedBox()),
        throwsAssertionError,
      );
    });
  });
}
