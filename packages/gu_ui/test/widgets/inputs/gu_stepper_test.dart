// T-05 · GuStepper (widget-catalog ek-2; MGT-05 `screens-manage.js:112`;
// K-03, CD-111).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

final Key _minus = GuKey.action('MGT-05.capacity.minus');
final Key _plus = GuKey.action('MGT-05.capacity.plus');

Widget _stepper(
  ValueNotifier<int> value, {
  bool disabled = false,
  int? min = 1,
  int? max = 1000,
}) => Padding(
  padding: GuInsets.all16,
  child: ValueListenableBuilder<int>(
    valueListenable: value,
    builder: (context, current, _) => GuStepper(
      value: current,
      min: min,
      max: max,
      step: 5,
      disabled: disabled,
      semanticLabel: 'Kontenjan',
      decreaseSemanticLabel: 'Azalt',
      increaseSemanticLabel: 'Artır',
      onChanged: (v) => value.value = v,
      minusKey: _minus,
      plusKey: _plus,
    ),
  ),
);

List<double> _buttonOpacities(WidgetTester tester) => tester
    .widgetList<Opacity>(find.byType(Opacity))
    .map((o) => o.opacity)
    .toList();

void main() {
  group('T-05 · GuStepper', () {
    testWidgets('T-05 · GuStepper · − / değer / + yerleşimi token '
        'değerleriyle; dokunma → onChanged(adım, sınıra kırpılır); sınırda ve '
        'devre dışıyken çağrılmaz; Semantics; dokunma hedefi ≥ 48 dp', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      const c = GuColors.light;
      final value = ValueNotifier<int>(40);
      addTearDown(value.dispose);
      await tester.pumpApp(_stepper(value));

      // screens-manage.js:112: IconButton 48 + bg.surfaceMuted daire, aralık
      // 12, değer min 64 ortalı, satır yatayda ortalı.
      final buttons = tester
          .widgetList<GuIconButton>(find.byType(GuIconButton))
          .toList();
      expect(buttons.map((b) => (b.icon, b.size, b.semanticLabel)), [
        (GuIcons.minus, GuIconButtonSize.md, 'Azalt'),
        (GuIcons.plus, GuIconButtonSize.md, 'Artır'),
      ]);
      final backgrounds = tester
          .widgetList<DecoratedBox>(
            find.ancestor(
              of: find.byType(GuIconButton),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((b) => b.decoration)
          .toList();
      expect(backgrounds, [
        ShapeDecoration(shape: const CircleBorder(), color: c.bgSurfaceMuted),
        ShapeDecoration(shape: const CircleBorder(), color: c.bgSurfaceMuted),
      ]);
      final minus = tester.getRect(find.byKey(_minus));
      final plus = tester.getRect(find.byKey(_plus));
      final label = tester.getRect(find.text('40'));
      expect(
        (minus.size, plus.size),
        (
          const Size.square(48),
          const Size.square(48),
        ),
      );
      expect(plus.left - minus.right, 12 + 64 + 12);
      expect(label.center.dx, moreOrLessEquals((minus.right + plus.left) / 2));
      expect((minus.left + plus.right) / 2, moreOrLessEquals(390 / 2));
      final text = tester.widget<Text>(find.text('40'));
      expect(
        text.style,
        GuTypography.resolve(c).bodyM.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(
        tester.getSemantics(find.byKey(_minus)),
        isSemantics(label: 'Azalt', isButton: true, isEnabled: true),
      );
      expect(
        tester.getSemantics(find.text('40')),
        isSemantics(label: 'Kontenjan\n40', isLiveRegion: true),
      );

      // Adım 5; üst sınır 1000'e kırpılır ve artı devre dışı kalır.
      await tester.tap(find.byKey(_plus));
      await tester.pump();
      expect(value.value, 45);
      await tester.tap(find.byKey(_minus));
      await tester.pump();
      expect(value.value, 40);
      value.value = 998;
      await tester.pump();
      await tester.tap(find.byKey(_plus));
      await tester.pump();
      expect(value.value, 1000);
      await tester.tap(find.byKey(_plus));
      await tester.pump();
      expect(value.value, 1000);
      expect(_buttonOpacities(tester), [1, GuOpacity.iconButtonDisabled]);
      expect(
        tester.getSemantics(find.byKey(_plus)),
        isSemantics(label: 'Artır', isButton: true, isEnabled: false),
      );

      // Alt sınır 1'e kırpılır ve eksi devre dışı kalır; zemin de solar.
      value.value = 3;
      await tester.pump();
      await tester.tap(find.byKey(_minus));
      await tester.pump();
      expect(value.value, 1);
      await tester.tap(find.byKey(_minus));
      await tester.pump();
      expect(value.value, 1);
      expect(_buttonOpacities(tester), [GuOpacity.iconButtonDisabled, 1]);
      expect(
        (tester
                    .widget<DecoratedBox>(
                      find
                          .ancestor(
                            of: find.byKey(_minus),
                            matching: find.byType(DecoratedBox),
                          )
                          .first,
                    )
                    .decoration
                as ShapeDecoration)
            .color!
            .a,
        moreOrLessEquals(GuOpacity.iconButtonDisabled),
      );

      // Sınırsız (min / max yok) → kırpma yok; disabled → ikisi de kapalı.
      value.value = 2;
      await tester.pumpApp(_stepper(value, min: null, max: null));
      await tester.tap(find.byKey(_minus));
      await tester.pump();
      expect(value.value, -3);
      await tester.tap(find.byKey(_plus));
      await tester.pump();
      expect(value.value, 2);
      await tester.pumpApp(_stepper(value, disabled: true));
      await tester.tap(find.byKey(_minus));
      await tester.tap(find.byKey(_plus));
      expect(value.value, 2);
      expect(_buttonOpacities(tester), [
        GuOpacity.iconButtonDisabled,
        GuOpacity.iconButtonDisabled,
      ]);
      handle.dispose();
    });

    testWidgets('T-05 · GuStepper · 320 dp × 1.6 ölçek + uzun değer → taşma '
        'yok', (tester) async {
      final value = ValueNotifier<int>(1000000);
      addTearDown(value.dispose);
      await tester.pumpApp(
        _stepper(value, max: null),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('1000000'), findsOneWidget);
    });
  });
}
