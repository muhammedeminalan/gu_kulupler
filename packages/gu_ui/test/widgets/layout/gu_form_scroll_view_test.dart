// K-93 · GuFormScrollView: formlu kaydırma sürüklenince klavye kapanır;
// çok satırlı alanın kendi içinde kaydırılması kapatmaz (Flutter `onDrag`
// iç kaydırıcının bildirimini de dinlediği için Android'de kapatıyordu —
// tasarım hataları turu, regresyon bulgusu 2).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

const Key _area = ValueKey<String>('area');
const Key _name = ValueKey<String>('name');

FocusNode _focusOf(WidgetTester tester, Key key) => tester
    .widget<EditableText>(
      find.descendant(of: find.byKey(key), matching: find.byType(EditableText)),
    )
    .focusNode;

ScrollableState _scrollableIn(WidgetTester tester, Finder of) =>
    tester.state<ScrollableState>(
      find.descendant(of: of, matching: find.byType(Scrollable)).first,
    );

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    group('GuFormScrollView · ${platform.name}', () {
      testWidgets('sayfa sürüklenince odak kalkar, klavye kapanır', (
        tester,
      ) async {
        await tester.pumpApp(
          const GuFormScrollView(
            padding: GuInsets.all16,
            child: Column(
              children: [
                GuInput(label: 'Ad', actionKey: _name),
                // ignore-hardcode: test içeriği — sayfa taşsın.
                SizedBox(height: 2000),
              ],
            ),
          ),
          platform: platform,
        );
        await tester.tap(find.byKey(_name));
        await tester.pump();
        expect(_focusOf(tester, _name).hasFocus, isTrue);
        expect(tester.testTextInput.isVisible, isTrue);

        final page = _scrollableIn(tester, find.byType(GuFormScrollView));
        // Alanın üstünden başlayan sürükleme sayfayı kaydırır → kapanır.
        await tester.drag(find.byKey(_name), const Offset(0, -120));
        await tester.pump();
        expect(page.position.pixels, greaterThan(0));
        expect(_focusOf(tester, _name).hasFocus, isFalse);
        expect(tester.testTextInput.isVisible, isFalse);
      });

      testWidgets('çok satırlı alanın içinde kaydırma odağı korur', (
        tester,
      ) async {
        final controller = TextEditingController(
          text: List.generate(30, (i) => 'Satır $i uzun metin').join('\n'),
        );
        addTearDown(controller.dispose);
        await tester.pumpApp(
          GuFormScrollView(
            padding: GuInsets.all16,
            child: Column(
              children: [
                GuInput(
                  label: 'Açıklama',
                  multiline: true,
                  controller: controller,
                  actionKey: _area,
                ),
                // ignore-hardcode: test içeriği — sayfa taşsın.
                const SizedBox(height: 2000),
              ],
            ),
          ),
          platform: platform,
        );
        await tester.tap(find.byKey(_area));
        await tester.pump();
        expect(_focusOf(tester, _area).hasFocus, isTrue);

        final inner = _scrollableIn(
          tester,
          find.ancestor(of: find.byKey(_area), matching: find.byType(GuInput)),
        );
        final page = _scrollableIn(tester, find.byType(GuFormScrollView));
        expect(inner.position.maxScrollExtent, greaterThan(0));
        await tester.drag(find.byKey(_area), const Offset(0, -60));
        await tester.pump();
        // Alan içi kaydı; sayfa yerinde; odak ve klavye duruyor.
        expect(inner.position.pixels, greaterThan(0));
        expect(page.position.pixels, 0);
        expect(_focusOf(tester, _area).hasFocus, isTrue);
        expect(tester.testTextInput.isVisible, isTrue);
      });
    });
  }

  testWidgets('PageStorageKey sarmalayıcıda: kaydırma konumu anahtarlıdır', (
    tester,
  ) async {
    Widget form(String step) => GuFormScrollView(
      key: PageStorageKey<String>('form-$step'),
      // ignore-hardcode: test içeriği — sayfa taşsın.
      child: const SizedBox(height: 2000),
    );
    await tester.pumpApp(form('a'));
    final first = _scrollableIn(tester, find.byType(GuFormScrollView));
    first.position.jumpTo(300);
    await tester.pump();
    await tester.pumpApp(form('b'));
    expect(
      _scrollableIn(tester, find.byType(GuFormScrollView)).position.pixels,
      0,
    );
  });
}
