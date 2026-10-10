// T-04 · GuDivider (widget-catalog #67; css:106).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

Finder get _line => find.descendant(
  of: find.byType(GuDivider),
  matching: find.byType(ColoredBox),
);

void main() {
  group('T-04 · GuDivider', () {
    testWidgets('T-04 · GuDivider · 1 px border.soft, tam genişlik, margin; '
        'koyu tema; sınırsız genişlikte hata yok', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [GuDivider()],
        ),
      );
      expect(tester.getSize(_line), const Size(390, GuSizes.divider));
      expect(
        tester.widget<ColoredBox>(_line).color,
        GuColors.light.borderSoft,
      );
      expect(tester.getSize(find.byType(GuDivider)), const Size(390, 1));
      // Dekoratif.
      expect(find.bySemanticsLabel(RegExp('.+')), findsNothing);

      await tester.pumpApp(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [GuDivider(margin: GuInsets.h16v8)],
        ),
        theme: ThemeMode.dark,
        size: const Size(320, 640),
      );
      expect(tester.getSize(_line), const Size(288, 1));
      expect(tester.getSize(find.byType(GuDivider)), const Size(320, 17));
      expect(tester.widget<ColoredBox>(_line).color, GuColors.dark.borderSoft);

      await tester.pumpApp(
        const Row(mainAxisSize: MainAxisSize.min, children: [GuDivider()]),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(_line), const Size(0, 1));
      handle.dispose();
    });
  });
}
