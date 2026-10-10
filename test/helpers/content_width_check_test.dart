// T-06 · `expectContentColumn` (PLAN §19.8; Q-13, CD-29).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// T-06: `GuContentColumn` barrel'a eklenince `package:gu_ui/gu_ui.dart` olur.
import 'package:gu_ui/gu_ui.dart';

import 'content_width_check.dart';
import 'pump_app.dart';

void main() {
  testWidgets('T-06 · expectContentColumn · 768 → 480 / sol 144, 390 → 390 / '
      'sol 0; sütun yoksa ya da içerik sütunu doldurmuyorsa düşer', (
    tester,
  ) async {
    const column = GuContentColumn(
      // İç içe sütun: en dıştaki ölçülür.
      child: GuContentColumn(child: SizedBox.expand()),
    );
    for (final size in [const Size(768, 1024), const Size(390, 844)]) {
      await tester.pumpApp(column, size: size);
      expectContentColumn(tester);
    }

    await tester.pumpApp(
      const GuContentColumn(child: SizedBox(width: 300, height: 100)),
      size: const Size(768, 1024),
    );
    expect(
      () => expectContentColumn(tester),
      throwsA(isA<TestFailure>()),
    );

    await tester.pumpApp(const SizedBox.expand(), size: const Size(768, 1024));
    expect(
      () => expectContentColumn(tester),
      throwsA(isA<TestFailure>()),
    );
  });
}
