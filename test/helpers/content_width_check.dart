// Tablet 480 dp içerik sütunu doğrulaması (Q-13, CD-29, PLAN §19.8).
//
// Ekran / sheet / dialog testleri `DeviceMatrix` tablet satırında
// (768 × 1024) `expectContentColumn(tester)` çağırır: en dıştaki
// `GuContentColumn`'un içeriği 480 dp genişliğinde ve ortalı olmalıdır
// (sol kenar (768 − 480) / 2 = 144). 480 ve altında içerik ekranı doldurur
// (390 → 390, sol kenar 0).
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';
// T-06: `GuContentColumn` barrel'a eklenince bu satır kalkar (gu_ui.dart
// yeter).

/// En dıştaki [GuContentColumn]'un içeriğinin genişliğini ve sol kenarını
/// doğrular: genişlik `min(ekran, GuBreakpoints.maxContentWidth)`, sol kenar
/// `(ekran − genişlik) / 2` — 768'de 480 / 144, 390'da 390 / 0.
///
/// Ağaçta `GuContentColumn` yoksa ya da içerik sütunu doldurmuyorsa
/// (uzama / daralma) test düşer.
void expectContentColumn(WidgetTester tester) {
  final columns = find.byType(GuContentColumn);
  expect(
    columns,
    findsWidgets,
    reason: 'Ağaçta GuContentColumn yok (CD-29: kabuk / overlay sarmalı).',
  );
  // `find.byType` ağaç sırasıyla döner: ilk eşleşme en dıştakidir.
  final column = columns.first;
  final child = tester.widget<GuContentColumn>(column).child;
  final rect = tester.getRect(
    find.descendant(of: column, matching: find.byWidget(child)).first,
  );
  final screen = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  final width = math.min(screen, GuBreakpoints.maxContentWidth);
  expect(
    rect.width,
    width,
    reason: 'İçerik sütunu genişliği ($screen dp ekranda $width olmalı).',
  );
  expect(
    rect.left,
    (screen - width) / 2,
    reason: 'İçerik sütunu ortalı değil.',
  );
}
