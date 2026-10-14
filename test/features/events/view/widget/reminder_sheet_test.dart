// SHT-13 · Hatırlatıcı — dört seçenek (CD-34), seçili radyo, anahtarlar
// (`SHT-13.select.<none|15m|1h|1d>`, `.close`), seçim sonucu
// (`pop(ReminderOption)`), kapanma `null`, cihaz matrisi, açık + koyu golden.
// Referans: design/reference-shots/sheets/SHT-13__light.webp, __dark.webp;
// prototip sheets.js:68–70.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/events/view/widget/reminder_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../../helpers/action_inventory.dart';
import '../../../../helpers/device_matrix.dart';
import '../../../../helpers/golden_helper.dart';
import '../../../../helpers/test_l10n.dart';
import '../../../clubs/view/widget/club_sheet_harness.dart';

ClubSheetHarness<ReminderOption> _harness({
  ReminderOption current = ReminderOption.none,
}) => ClubSheetHarness<ReminderOption>(
  SheetId.sht13,
  (_) => ReminderSheet(current: current),
);

void main() {
  group('SHT-13 · Hatırlatıcı', () {
    testWidgets('dört satır prototip sırasıyla (TR + EN); seçili olan '
        'işaretli; anahtarlar ReminderOption.json', (tester) async {
      for (final locale in const [Locale('tr'), Locale('en')]) {
        final h = _harness(current: ReminderOption.oneHour);
        await h.pump(tester, locale: locale);
        await h.open(tester);
        final l10n = tester.l10nFor(locale);

        final frame = tester.widget<GuSheetFrame>(find.byType(GuSheetFrame));
        expect(frame.title, l10n.sht13Title);
        expect(frame.flush, isTrue);
        expect(frame.menu, isFalse);
        final rows = tester
            .widgetList<GuOptionRow>(find.byType(GuOptionRow))
            .toList();
        expect(rows.map((row) => row.label), [
          l10n.reminderNone,
          l10n.reminder15m,
          l10n.reminder1h,
          l10n.reminder1d,
        ]);
        expect(rows.map((row) => row.selected), [false, false, true, false]);
        expect(rows.map((row) => row.key), [
          GuKey.action('SHT-13.select.none'),
          GuKey.action('SHT-13.select.15m'),
          GuKey.action('SHT-13.select.1h'),
          GuKey.action('SHT-13.select.1d'),
        ]);
      }
      expect(ActionInventory.found(tester), {
        'SHT-13.select.none',
        'SHT-13.select.15m',
        'SHT-13.select.1h',
        'SHT-13.select.1d',
        'SHT-13.close',
        'SHT-13.scrim',
      });
    });

    testWidgets('satıra dokunma seçimi döndürür; kapat / geri `null`', (
      tester,
    ) async {
      final h = _harness();
      await h.pump(tester);
      for (final option in ReminderOption.values) {
        await h.open(tester);
        await tester.tap(find.byKey(ReminderSheet.keyOf(option)));
        await tester.pumpAndSettle();
        expect(find.byType(GuSheetFrame), findsNothing);
        expect(h.result, option);
      }
      await h.open(tester);
      await tester.tap(
        find.byKey(FeedbackKeys.of(SheetId.sht13.designId, 'close')),
      );
      await tester.pumpAndSettle();
      expect(h.result, isNull);
      await h.open(tester);
      await h.back(tester);
      expect(h.result, isNull);
    });

    testWidgets('cihaz matrisi: taşma yok', (tester) async {
      await DeviceMatrix.run(
        tester,
        (context) => const Align(
          alignment: Alignment.bottomCenter,
          child: ReminderSheet(current: ReminderOption.none),
        ),
        safeAreas: true,
      );
    });

    testWidgets('golden: açık sayfa (scrim dahil) — açık + koyu', (
      tester,
    ) async {
      for (final theme in kGoldenThemes) {
        final h = _harness();
        await h.pump(tester, theme: theme);
        await h.open(tester);
        await h.expectGolden(tester, 'SHT-13', theme);
      }
    });
  });
}
