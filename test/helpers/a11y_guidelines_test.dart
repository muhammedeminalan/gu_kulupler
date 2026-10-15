import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import 'a11y_guidelines.dart';
import 'pump_app.dart';

/// [size] boyutlu dokunma hedefi; [label] `null` → etiketsiz.
Widget _target(double size, {String? label}) => Center(
  child: Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      onTap: () {},
      child: SizedBox.square(dimension: size),
    ),
  ),
);

/// Beyaz zemin üzerinde [color] renkli 12 px metin.
Widget _text(String text, Color color) => Center(
  child: ColoredBox(
    color: const Color(0xFFFFFFFF),
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Text(text, style: TextStyle(fontSize: 12, color: color)),
    ),
  ),
);

Future<String?> _failure(Future<void> Function() body) async {
  try {
    await body();
  } on TestFailure catch (error) {
    return '$error';
  }
  return null;
}

void main() {
  group('T-43 · expectA11yGuidelines', () {
    testWidgets('etiketli 44 dp hedef geçer', (tester) async {
      await tester.pumpApp(_target(44, label: 'Tamam'));
      await expectA11yGuidelines(tester);
    });

    testWidgets('etiketsiz hedef → etiket ihlali', (tester) async {
      await tester.pumpApp(_target(48));
      final failure = await _failure(() => expectA11yGuidelines(tester));
      expect(failure, contains('semantic label'));
    });

    testWidgets('< 44 dp hedef → boyut ihlali; etiketle muaf tutulabilir', (
      tester,
    ) async {
      await tester.pumpApp(_target(32, label: 'Küçük'));
      final failure = await _failure(() => expectA11yGuidelines(tester));
      expect(failure, contains('Size(44.0, 44.0)'));
      await expectA11yGuidelines(tester, smallTargetLabels: const {'Küçük'});
    });

    testWidgets('GuTapTarget içindeki küçük ikon 44 dp sağlar', (tester) async {
      await tester.pumpApp(
        Center(
          child: GuTapTarget(
            onTap: () {},
            semanticLabel: 'Geri',
            child: const SizedBox.square(dimension: 24),
          ),
        ),
        platform: TargetPlatform.iOS,
      );
      await expectA11yGuidelines(tester);
    });

    testWidgets('kontrast varsayılan açık (T-45): AA altı metin → ihlal; '
        'etiketle ya da contrast: false ile muaf', (tester) async {
      await tester.pumpApp(_text('Soluk', const Color(0xFFD0D0D0)));
      final failure = await _failure(() => expectA11yGuidelines(tester));
      expect(failure, contains('Expected contrast ratio of at least 4.5'));
      await expectA11yGuidelines(tester, lowContrastLabels: const {'Soluk'});
      await expectA11yGuidelines(tester, contrast: false);
    });

    testWidgets('K-91 textMuted açık (#5E708A) beyazda geçer', (tester) async {
      await tester.pumpApp(_text('Yardımcı', GuColors.light.textMuted));
      await expectA11yGuidelines(tester);
    });
  });
}
