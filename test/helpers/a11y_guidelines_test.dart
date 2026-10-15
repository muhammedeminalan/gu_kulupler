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
  });
}
