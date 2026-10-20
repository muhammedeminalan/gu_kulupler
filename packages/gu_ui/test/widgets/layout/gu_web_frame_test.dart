// H-23 · GuWebFrame (web telefon kartı) ve GuContentColumnScope.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

const Key _cardKey = ValueKey<String>('frame.card');
const Key _sideKey = ValueKey<String>('frame.side');

/// Kartın gördüğü `MediaQuery` genişliği ve sütunun açık olup olmadığı.
Size? _cardMedia;
bool? _columnEnabled;

Widget _frame({required bool framed, bool showSidebar = false}) => GuWebFrame(
  framed: framed,
  showSidebar: showSidebar,
  sidebar: const SizedBox.expand(key: _sideKey),
  child: Builder(
    builder: (context) {
      _cardMedia = MediaQuery.sizeOf(context);
      _columnEnabled = GuContentColumnScope.enabledOf(context);
      return const SizedBox.expand(key: _cardKey);
    },
  ),
);

void main() {
  testWidgets('H-23 · çerçevesiz: kart pencereyi doldurur, yan menü yok, '
      'sütun açık', (tester) async {
    await tester.pumpApp(_frame(framed: false), size: const Size(700, 900));
    expect(
      tester.getRect(find.byKey(_cardKey)),
      Offset.zero & const Size(700, 900),
    );
    expect(find.byKey(_sideKey), findsNothing);
    expect(_columnEnabled, isTrue);
  });

  testWidgets('H-23 · çerçeveli: kart 480–768 arasında ortada; MediaQuery kart '
      'boyutu; sütun kapalı', (tester) async {
    await tester.pumpApp(_frame(framed: true), size: const Size(900, 800));
    final card = tester.getRect(find.byKey(_cardKey));
    expect(card.width, GuWebLayout.cardMaxWidth);
    expect(card.height, 800 - 2 * GuWebLayout.framePadding);
    expect(card.center.dx, 450);
    expect(_cardMedia, card.size);
    expect(_columnEnabled, isFalse);
  });

  testWidgets('H-23 · yan menü: animasyonla kartın soluna gelir (264, ara '
      '24, ikisi ortada), kapanınca gider', (tester) async {
    final show = ValueNotifier<bool>(false);
    addTearDown(show.dispose);
    await tester.pumpApp(
      ValueListenableBuilder<bool>(
        valueListenable: show,
        builder: (context, value, _) =>
            _frame(framed: true, showSidebar: value),
      ),
      size: const Size(1440, 900),
    );
    expect(find.byKey(_sideKey), findsNothing);

    show.value = true;
    await tester.pumpAndSettle();
    final side = tester.getRect(find.byKey(_sideKey));
    final card = tester.getRect(find.byKey(_cardKey));
    expect(side.width, GuWebLayout.sidebarWidth);
    expect(card.left - side.right, GuWebLayout.sidebarGap);
    expect((side.left + card.right) / 2, 720);

    show.value = false;
    await tester.pumpAndSettle();
    expect(find.byKey(_sideKey), findsNothing);
    expect(tester.getRect(find.byKey(_cardKey)).center.dx, 720);
  });
}
