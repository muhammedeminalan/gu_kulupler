// T-06 · GuContentColumn (widget-catalog #75; A.2 #75; Q-13, CD-29;
// PLAN §19.8).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

const Key _childKey = ValueKey<String>('column.child');

const Widget _column = GuContentColumn(child: SizedBox.expand(key: _childKey));

Finder _inside(Type type) => find.descendant(
  of: find.byType(GuContentColumn),
  matching: find.byType(type),
);

void main() {
  testWidgets('T-06 · GuContentColumn · 320 / 390 / 480 → çocuk olduğu gibi '
      '(ek kutu yok); 768 → 480 ortalı sütun, sol kenar 144', (tester) async {
    for (final width in [
      GuBreakpoints.phoneSmall,
      GuBreakpoints.phoneReference,
      GuBreakpoints.maxContentWidth,
    ]) {
      await tester.pumpApp(_column, size: Size(width, 844));
      expect(
        tester.getRect(find.byKey(_childKey)),
        Rect.fromLTWH(0, 0, width, 844),
        reason: '$width',
      );
      expect(_inside(Center), findsNothing);
      expect(_inside(ConstrainedBox), findsNothing);
    }

    await tester.pumpApp(
      _column,
      size: const Size(GuBreakpoints.tablet, 1024),
    );
    expect(
      tester.getRect(find.byKey(_childKey)),
      const Rect.fromLTWH(144, 0, 480, 1024),
    );
    expect(
      tester.widget<ConstrainedBox>(_inside(ConstrainedBox).first).constraints,
      const BoxConstraints(maxWidth: GuBreakpoints.maxContentWidth),
    );
    // Sütundan dar içerik de ortalanır.
    await tester.pumpApp(
      const GuContentColumn(
        child: SizedBox(key: _childKey, width: 300, height: 100),
      ),
      size: const Size(GuBreakpoints.tablet, 1024),
    );
    expect(
      tester.getRect(find.byKey(_childKey)),
      const Rect.fromLTWH(234, 462, 300, 100),
    );
  });
}
