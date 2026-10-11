// T-13 · KeyboardFocusMixin: form ekranlarında odak sırası (design-analysis
// §G) — eylem tuşu, sıradaki alana geçiş, ilk hatalı alana odak, düğüm yaşam
// döngüsü ve klavye açıkken taşma.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/product/mixin/keyboard_focus_mixin.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/overflow_detector.dart';
import '../../helpers/pump_app.dart';

enum _Field { name, email, note, consent }

class _FormView extends ConsumerStatefulWidget {
  const _FormView();

  @override
  ConsumerState<_FormView> createState() => _FormViewState();
}

class _FormViewState extends ConsumerState<_FormView>
    with KeyboardFocusMixin<_FormView, _Field> {
  int submits = 0;

  /// Onay kutusu klavye sırasında değildir.
  @override
  List<_Field> get focusOrder => const [_Field.name, _Field.email, _Field.note];

  void _onSubmitted(_Field field) {
    if (!focusNext(field)) submits++;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SingleChildScrollView(
      padding: GuInsets.all16,
      child: Column(
        spacing: GuSpacing.s16,
        children: [
          for (final field in focusOrder)
            GuInput(
              actionKey: ValueKey<String>('field.${field.name}'),
              label: field.name,
              focusNode: focusNodeOf(field),
              textInputAction: actionFor(field),
              onChanged: (_) {},
              onSubmitted: () => _onSubmitted(field),
            ),
        ],
      ),
    ),
  );
}

_FormViewState _state(WidgetTester tester) =>
    tester.state<_FormViewState>(find.byType(_FormView));

void main() {
  group('T-13 · KeyboardFocusMixin', () {
    testWidgets('eylem tuşu: son alanda "bitti", diğerlerinde "sonraki"', (
      tester,
    ) async {
      await tester.pumpApp(const _FormView());
      final state = _state(tester);
      expect(state.actionFor(_Field.name), TextInputAction.next);
      expect(state.actionFor(_Field.email), TextInputAction.next);
      expect(state.actionFor(_Field.note), TextInputAction.done);
    });

    testWidgets('focusNodeOf alan başına tek düğüm kurar (tembel)', (
      tester,
    ) async {
      await tester.pumpApp(const _FormView());
      final state = _state(tester);
      final node = state.focusNodeOf(_Field.name);
      expect(state.focusNodeOf(_Field.name), same(node));
      expect(state.focusNodeOf(_Field.email), isNot(same(node)));
      expect(node.debugLabel, contains('name'));
    });

    testWidgets('focusNext sıradaki alana geçer; son alanda ve sıra dışı '
        'alanda `false` döner (çağıran gönderir)', (tester) async {
      await tester.pumpApp(const _FormView());
      final state = _state(tester);
      state.focusNodeOf(_Field.name).requestFocus();
      await tester.pump();

      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(state.focusNodeOf(_Field.email).hasFocus, isTrue);
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(state.focusNodeOf(_Field.note).hasFocus, isTrue);
      expect(state.submits, 0);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(state.submits, 1);

      expect(state.focusNext(_Field.note), isFalse);
      expect(state.focusNext(_Field.consent), isFalse);
      expect(state.focusNext(_Field.name), isTrue);
    });

    testWidgets('focusFirstError odağı sıradaki ilk hatalı alana taşır', (
      tester,
    ) async {
      await tester.pumpApp(const _FormView());
      final state = _state(tester);

      // Harita sırası değil, alan sırası belirler.
      expect(
        state.focusFirstError(const {_Field.note: 'x', _Field.email: 'y'}),
        _Field.email,
      );
      await tester.pump();
      expect(state.focusNodeOf(_Field.email).hasFocus, isTrue);

      // Sırada olmayan alan (onay kutusu) ve boş harita: odak değişmez.
      expect(state.focusFirstError(const {_Field.consent: 'x'}), isNull);
      expect(state.focusFirstError(const {}), isNull);
      await tester.pump();
      expect(state.focusNodeOf(_Field.email).hasFocus, isTrue);
    });

    testWidgets('unfocusAll klavyeyi kapatır', (tester) async {
      await tester.pumpApp(const _FormView());
      final state = _state(tester);
      state.focusNodeOf(_Field.name).requestFocus();
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);

      state.unfocusAll();
      await tester.pump();
      expect(state.focusNodeOf(_Field.name).hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('dispose düğümleri kapatır', (tester) async {
      await tester.pumpApp(const _FormView());
      final state = _state(tester);
      final nodes = [
        for (final field in state.focusOrder) state.focusNodeOf(field),
      ];
      await tester.pumpWidget(const SizedBox.shrink());
      for (final node in nodes) {
        // Kapatılmış düğüme dinleyici eklenemez.
        expect(() => node.addListener(() {}), throwsFlutterError);
      }
    });

    testWidgets('320×640 + klavye: odaklanan alan görünür kalır, taşma yok', (
      tester,
    ) async {
      OverflowDetector.install();
      addTearDown(OverflowDetector.uninstall);
      await tester.pumpApp(
        const _FormView(),
        size: const Size(320, 640),
        keyboardInset: 320,
      );
      final state = _state(tester);
      expect(state.focusFirstError(const {_Field.note: 'x'}), _Field.note);
      await tester.pumpAndSettle();
      final field = tester.getRect(
        find.byKey(const ValueKey<String>('field.note')),
      );
      expect(field.bottom, lessThanOrEqualTo(640 - 320));
      OverflowDetector.assertNone('320×640 + klavye');
    });
  });
}
