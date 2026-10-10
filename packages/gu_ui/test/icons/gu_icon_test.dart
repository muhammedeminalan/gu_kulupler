// T-03 · GuIcon (widget-catalog #45; PLAN §7.11, D-13, CD-21).
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../helpers/golden_helper.dart';
import '../helpers/pump_app.dart';

SvgPicture _picture(WidgetTester tester) =>
    tester.widget<SvgPicture>(find.byType(SvgPicture));

void main() {
  group('T-03 · GuIcon', () {
    testWidgets('varsayılan: 24 px, text.heading srcIn (açık / koyu)', (
      tester,
    ) async {
      await tester.pumpApp(const Center(child: GuIcon(GuIcons.search)));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(GuIcon)), const Size.square(24));
      expect(_picture(tester).width, GuSizes.icon24);
      expect(_picture(tester).height, GuSizes.icon24);
      expect(
        _picture(tester).colorFilter,
        ColorFilter.mode(GuColors.light.textHeading, BlendMode.srcIn),
      );
      expect(
        (_picture(tester).bytesLoader as SvgAssetLoader).assetName,
        'assets/icons/search.svg',
      );

      await tester.pumpApp(
        const Center(child: GuIcon(GuIcons.search)),
        theme: ThemeMode.dark,
      );
      expect(
        _picture(tester).colorFilter,
        ColorFilter.mode(GuColors.dark.textHeading, BlendMode.srcIn),
      );
    });

    testWidgets('size ve color parametreleri uygulanır', (tester) async {
      await tester.pumpApp(
        Center(
          child: GuIcon(
            GuIcons.crown,
            size: GuSizes.icon16,
            color: GuColors.light.stateDanger,
          ),
        ),
      );
      await tester.pump();
      expect(tester.getSize(find.byType(GuIcon)), const Size.square(16));
      expect(
        _picture(tester).colorFilter,
        ColorFilter.mode(GuColors.light.stateDanger, BlendMode.srcIn),
      );
    });

    testWidgets('semanticLabel yok → dekoratif (ExcludeSemantics)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(const Center(child: GuIcon(GuIcons.bell)));
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(GuIcon),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
      expect(_picture(tester).excludeFromSemantics, isTrue);
      expect(find.bySemanticsLabel(RegExp('.+')), findsNothing);
      handle.dispose();
    });

    testWidgets('semanticLabel var → Semantics(label, image)', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(
        const Center(child: GuIcon(GuIcons.bell, semanticLabel: 'Bildirimler')),
      );
      await tester.pump();
      expect(
        tester.getSemantics(find.bySemanticsLabel('Bildirimler')),
        matchesSemantics(label: 'Bildirimler', isImage: true),
      );
      handle.dispose();
    });

    testWidgets('golden: 130 ikon 10 × 13 ızgara (açık + koyu)', (
      tester,
    ) async {
      const cell = 35.0;
      await goldenForWidget(tester, 'gu_icons', {
        'default': SizedBox(
          width: cell * 10,
          child: Wrap(
            children: [
              for (final icon in GuIcons.values)
                SizedBox.square(
                  dimension: cell,
                  child: Center(child: GuIcon(icon)),
                ),
            ],
          ),
        ),
      });
      expect(tester.takeException(), isNull);
    });
  });
}
