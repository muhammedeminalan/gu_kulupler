// T-29 · GuBulletList (widget-catalog #73; SET-03 "Silinecekler" `ul`).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/golden_helper.dart';
import '../../helpers/pump_app.dart';

const List<String> _items = [
  'Kulüp üyeliklerin',
  'Bekleyen başvuruların',
  'Çok uzun bir madde metni iki satıra kaydırılır ve im ilk satırda kalır',
];

void main() {
  group('T-29 · GuBulletList', () {
    testWidgets('ul{padding-left:20px}: metin 20 içeride, maddeler arası 4; '
        'varsayılan stil bodyS + text.secondary; im semantik dışı', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpApp(
        const Center(
          child: SizedBox(width: 240, child: GuBulletList(items: _items)),
        ),
      );

      final list = tester.getTopLeft(find.byType(GuBulletList));
      final first = find.text(_items.first);
      final second = find.text(_items[1]);
      expect(tester.getTopLeft(first).dx - list.dx, GuSpacing.s20);
      expect(
        tester.getTopLeft(second).dy - tester.getBottomLeft(first).dy,
        GuSpacing.s4,
      );
      expect(
        tester.widget<Text>(first).style,
        GuTypography.resolve(
          GuColors.light,
        ).bodyS.copyWith(color: GuColors.light.textSecondary),
      );
      expect(find.text(GuBulletList.bullet), findsNWidgets(_items.length));
      expect(find.bySemanticsLabel(GuBulletList.bullet), findsNothing);
      semantics.dispose();
    });

    testWidgets('golden açık + koyu', (tester) async {
      await goldenForWidget(tester, 'gu_bullet_list', {
        'default': const SizedBox(
          width: 280,
          child: GuBulletList(items: _items),
        ),
      }, size: const Size(320, 140));
    });
  });
}
