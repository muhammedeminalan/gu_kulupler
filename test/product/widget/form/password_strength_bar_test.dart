// `PasswordStrengthBar` — AUT-02 / SHT-32 şifre gücü çubuğu: dilim sayısı,
// güce göre dolu dilim rengi (≤ 1 tehlike, 2 uyarı, ≥ 3 başarı), boş dilim
// `border.default`, semantik ağaçta yok; açık + koyu golden.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/product/widget/form/password_strength_bar.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';

List<Color?> _segments(WidgetTester tester) => [
  for (final box in tester.widgetList<DecoratedBox>(
    find.descendant(
      of: find.byType(PasswordStrengthBar),
      matching: find.byType(DecoratedBox),
    ),
  ))
    (box.decoration as BoxDecoration).color,
];

void main() {
  group('PasswordStrengthBar', () {
    testWidgets('dilimler ve güce göre renk', (tester) async {
      const colors = GuColors.light;
      for (final (strength, fill) in [
        (0, colors.stateDanger),
        (1, colors.stateDanger),
        (2, colors.stateWarning),
        (3, colors.stateSuccess),
        (4, colors.stateSuccess),
      ]) {
        await tester.pumpApp(PasswordStrengthBar(strength: strength, max: 4));
        expect(_segments(tester), [
          for (var i = 0; i < 4; i++)
            i < strength ? fill : colors.borderDefault,
        ], reason: 'güç $strength');
      }
    });

    testWidgets('dekoratif: semantik düğüm üretmez', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(const PasswordStrengthBar(strength: 2, max: 4));
      expect(
        find.descendant(
          of: find.byType(PasswordStrengthBar),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('golden: güç 2 / 4 (açık + koyu)', (tester) async {
      await goldenForThemes(
        tester,
        'password_strength_bar',
        const Padding(
          padding: GuInsets.all16,
          child: PasswordStrengthBar(strength: 2, max: 4),
        ),
        size: const Size(320, 40),
      );
    });
  });
}
