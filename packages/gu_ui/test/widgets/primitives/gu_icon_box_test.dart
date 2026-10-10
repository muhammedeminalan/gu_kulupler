// T-04 · GuIconBox (widget-catalog #64; CD-25, G9; css:405–406).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

BoxDecoration _decoration(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find.descendant(
                of: find.byType(GuIconBox),
                matching: find.byType(DecoratedBox),
              ),
            )
            .decoration
        as BoxDecoration;

GuIcon _icon(WidgetTester tester) => tester.widget<GuIcon>(find.byType(GuIcon));

/// CSS `.ni-*` (css:406): ton → (zemin, ikon).
Map<GuIconBoxTone, (Color, Color)> _expected(GuColors c) => {
  GuIconBoxTone.brand: (c.brandPrimaryContainer, c.brandPrimaryText),
  GuIconBoxTone.success: (c.stateSuccessContainer, c.stateSuccess),
  GuIconBoxTone.danger: (c.stateDangerContainer, c.stateDanger),
  GuIconBoxTone.info: (c.stateInfoContainer, c.stateInfo),
  GuIconBoxTone.warning: (c.stateWarningContainer, c.stateWarning),
  GuIconBoxTone.neutral: (c.bgSurfaceMuted, c.textSecondary),
};

void main() {
  group('T-04 · GuIconBox', () {
    testWidgets('T-04 · GuIconBox · 40 px daire + 20 px ikon; 6 ton açık ve '
        'koyu temada token renkleriyle', (tester) async {
      for (final (mode, colors) in [
        (ThemeMode.light, GuColors.light),
        (ThemeMode.dark, GuColors.dark),
      ]) {
        final expected = _expected(colors);
        expect(expected.keys, GuIconBoxTone.values);
        for (final tone in GuIconBoxTone.values) {
          await tester.pumpApp(
            Center(
              child: GuIconBox(icon: GuIcons.bell, tone: tone),
            ),
            theme: mode,
          );
          expect(tester.getSize(find.byType(GuIconBox)), const Size.square(40));
          final box = _decoration(tester);
          expect(box.color, expected[tone]!.$1, reason: '$mode $tone');
          expect(box.borderRadius, GuRadius.borderFull);
          expect(_icon(tester).icon, GuIcons.bell);
          expect(_icon(tester).size, GuSizes.icon20);
          expect(
            _icon(tester).color,
            expected[tone]!.$2,
            reason: '$mode $tone',
          );
        }
      }
      // Varsayılan ton brand.
      expect(const GuIconBox(icon: GuIcons.bell).tone, GuIconBoxTone.brand);
    });

    testWidgets('T-04 · GuIconBox · SHT-24 büyük ölçü (72 / 36) ve Semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(
        const Center(child: GuIconBox(icon: GuIcons.bell)),
      );
      // Etiketsiz → dekoratif.
      expect(find.bySemanticsLabel(RegExp('.+')), findsNothing);

      await tester.pumpApp(
        const Center(
          child: GuIconBox(
            icon: GuIcons.bell,
            tone: GuIconBoxTone.success,
            size: GuSizes.notifIconLg,
            iconSize: GuSizes.notifIconLgIcon,
            semanticLabel: 'Giriş onaylandı',
          ),
        ),
      );
      expect(tester.getSize(find.byType(GuIconBox)), const Size.square(72));
      expect(tester.getSize(find.byType(GuIcon)), const Size.square(36));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Giriş onaylandı')),
        matchesSemantics(label: 'Giriş onaylandı', isImage: true),
      );
      handle.dispose();
    });
  });
}
