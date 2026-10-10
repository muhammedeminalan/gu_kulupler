// T-03 · GuIllustration (widget-catalog #50; K-20, K-48).
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

SvgPicture _picture(WidgetTester tester) =>
    tester.widget<SvgPicture>(find.byType(SvgPicture));

void main() {
  group('T-03 · GuIllustration', () {
    testWidgets('varsayılan 140 px, renk filtresi yok, dekoratif', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(
        const Center(child: GuIllustration(GuIllustrations.emptyClubs)),
        theme: ThemeMode.dark,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(GuIllustration)),
        const Size.square(GuSizes.illustration),
      );
      expect(GuSizes.illustration, 140);
      // K-20: iki renkli varlık; koyu temada da yeniden renklendirilmez.
      expect(_picture(tester).colorFilter, isNull);
      expect(
        (_picture(tester).bytesLoader as SvgAssetLoader).assetName,
        'assets/illustrations/empty-clubs.svg',
      );
      expect(
        find.descendant(
          of: find.byType(GuIllustration),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('.+')), findsNothing);
      handle.dispose();
    });

    testWidgets('size kümesi (K-48) uygulanır', (tester) async {
      for (final size in GuSizes.illustrationSizes) {
        await tester.pumpApp(
          Center(child: GuIllustration(GuIllustrations.error, size: size)),
        );
        await tester.pump();
        expect(
          tester.getSize(find.byType(GuIllustration)),
          Size.square(size),
        );
      }
      expect(GuSizes.illustrationSizes, contains(GuSizes.illustrationCompact));
    });
  });
}
