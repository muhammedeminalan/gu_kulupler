// H-23 · GuSidebar (web yan menüsü).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

const List<GuSidebarItem> _items = [
  GuSidebarItem(icon: GuIcons.usersRound, label: 'Kulüpler'),
  GuSidebarItem(icon: GuIcons.calendar, label: 'Etkinlikler'),
  GuSidebarItem(icon: GuIcons.bell, label: 'Bildirimler', badge: '4'),
];

void main() {
  testWidgets('H-23 · GuSidebar: satırlar, rozet, dokunma sırası, anahtar ve '
      'seçili semantiği', (tester) async {
    final taps = <int>[];
    await tester.pumpApp(
      SizedBox(
        width: GuWebLayout.sidebarWidth,
        height: 600,
        child: GuSidebar(
          items: _items,
          currentIndex: 1,
          onTap: taps.add,
          semanticLabel: 'Ana gezinme',
          header: const Text('GÜ Kulüpler'),
          itemKeyBuilder: (index) => ValueKey<String>('side.$index'),
        ),
      ),
    );
    expect(find.text('GÜ Kulüpler'), findsOneWidget);
    expect(find.text('Bildirimler'), findsOneWidget);
    expect(find.byType(GuCountBadge), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('side.2')));
    await tester.tap(find.byKey(const ValueKey<String>('side.1')));
    expect(taps, [2, 1]);

    expect(
      tester.getSemantics(find.text('Etkinlikler')),
      containsSemantics(isButton: true, isSelected: true),
    );
    expect(
      tester.getSemantics(find.text('Kulüpler')),
      containsSemantics(isButton: true, isSelected: false),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('side.0'))).height,
      greaterThanOrEqualTo(GuWebLayout.sidebarItemHeight),
    );
  });
}
