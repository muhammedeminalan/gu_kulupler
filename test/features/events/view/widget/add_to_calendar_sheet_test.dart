// SHT-14 · Takvime ekle — üç yol (cihaz takvimi `.ics`, Google Takvim,
// bağlantıyı kopyala), sayfa `Row` biçimi (22 dp `text.heading` ikon),
// anahtarlar (`SHT-14.device|google|copyLink|close`), seçim sonucu
// (`pop(CalendarChoice)`), kapanma `null`, cihaz matrisi, açık + koyu golden.
// Referans: design/reference-shots/sheets/SHT-14__light.webp, __dark.webp;
// prototip sheets.js:71–73.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/features/events/view/widget/add_to_calendar_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../../helpers/action_inventory.dart';
import '../../../../helpers/device_matrix.dart';
import '../../../../helpers/golden_helper.dart';
import '../../../../helpers/test_l10n.dart';
import '../../../clubs/view/widget/club_sheet_harness.dart';

ClubSheetHarness<CalendarChoice> _harness() => ClubSheetHarness<CalendarChoice>(
  SheetId.sht14,
  (_) => const AddToCalendarSheet(),
);

void main() {
  group('SHT-14 · Takvime ekle', () {
    testWidgets('menü çerçevesi; üç satır: ikon, metin, ".ics" alt satırı '
        '(TR + EN)', (tester) async {
      for (final locale in const [Locale('tr'), Locale('en')]) {
        final h = _harness();
        await h.pump(tester, locale: locale);
        await h.open(tester);
        final l10n = tester.l10nFor(locale);
        final gu = tester.element(find.byType(GuSheetFrame)).gu;

        final frame = tester.widget<GuSheetFrame>(find.byType(GuSheetFrame));
        expect(frame.title, l10n.sht14Title);
        expect(frame.menu, isTrue);
        expect(frame.flush, isTrue);
        final tiles = tester.widgetList<GuTile>(find.byType(GuTile)).toList();
        expect(tiles.map((tile) => tile.title), [
          l10n.sht14Device,
          l10n.sht14Google,
          l10n.sht08CopyLink,
        ]);
        expect(tiles.map((tile) => tile.subtitle), ['.ics', null, null]);
        expect(tiles.map((tile) => tile.key), [
          for (final choice in CalendarChoice.values)
            AddToCalendarSheet.keyOf(choice),
        ]);
        const icons = [GuIcons.smartphone, GuIcons.globe, GuIcons.link];
        for (var i = 0; i < icons.length; i++) {
          final icon = tiles[i].leading! as GuIcon;
          expect(icon.icon, icons[i]);
          expect(icon.size, GuSizes.icon22);
          expect(icon.color, gu.colors.textHeading);
        }
      }
      expect(ActionInventory.found(tester), {
        'SHT-14.device',
        'SHT-14.google',
        'SHT-14.copyLink',
        'SHT-14.close',
        'SHT-14.scrim',
      });
    });

    testWidgets('satıra dokunma seçimi döndürür; kapat / geri `null`', (
      tester,
    ) async {
      final h = _harness();
      await h.pump(tester);
      for (final choice in CalendarChoice.values) {
        await h.open(tester);
        await tester.tap(find.byKey(AddToCalendarSheet.keyOf(choice)));
        await tester.pumpAndSettle();
        expect(find.byType(GuSheetFrame), findsNothing);
        expect(h.result, choice);
      }
      await h.open(tester);
      await tester.tap(
        find.byKey(FeedbackKeys.of(SheetId.sht14.designId, 'close')),
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
          child: AddToCalendarSheet(),
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
        await h.expectGolden(tester, 'SHT-14', theme);
      }
    });
  });
}
