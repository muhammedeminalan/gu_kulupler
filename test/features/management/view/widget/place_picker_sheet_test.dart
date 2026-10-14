// T-34 · SHT-30 · Mekân seç (`PlacePickerSheet`): arama (o anki dilde,
// Türkçe büyük / küçük harf), `StaticTables.places` satırları (seçili
// işaretli), satır → `PlacePickerResult.place`, "Başka bir yer yaz" →
// metin alanı + "Tamam" (boşken devre dışı) → `PlacePickerResult.custom`
// (kırpılmış), serbest metinle açılış, X → null, cihaz matrisi, açık + koyu
// golden. Referans: design/reference-shots/sheets/SHT-30__{light,dark}.webp;
// prototip sheets.js:141–143.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/management/view/widget/place_picker_sheet.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../../helpers/device_matrix.dart';
import '../../../../helpers/golden_helper.dart';
import '../../../clubs/view/widget/club_sheet_harness.dart';

ClubSheetHarness<PlacePickerResult> _harness({
  String? placeId,
  String? placeText,
}) => ClubSheetHarness<PlacePickerResult>(
  SheetId.sht30,
  (_) => PlacePickerSheet(placeId: placeId, placeText: placeText),
);

Key _k(String action) => PlacePickerSheet.keyOf(action);

GuButton _ok(WidgetTester tester) =>
    tester.widget<GuButton>(find.byKey(_k('okCustom')));

void main() {
  final tr = lookupAppLocalizations(const Locale('tr'));

  group('T-34 · SHT-30 · Mekân seç', () {
    test('anahtarlar prototipteki aksiyon adlarıdır', () {
      expect(_k('search'), GuKey.action('SHT-30.search'));
      expect(
        PlacePickerSheet.selectKeyOf('pl03'),
        GuKey.action('SHT-30.select.pl03'),
      );
      expect(_k('customToggle'), GuKey.action('SHT-30.customToggle'));
    });

    testWidgets('10 mekân, seçili işaretli; satır → place(id)', (
      tester,
    ) async {
      final h = _harness(placeId: 'pl02');
      await h.pump(tester);
      await h.open(tester);
      expect(find.text(tr.sht30Title), findsOneWidget);
      for (final place in StaticTables.places) {
        expect(
          find.byKey(PlacePickerSheet.selectKeyOf(place.id)),
          findsOneWidget,
        );
      }
      final rows = tester.widgetList<GuOptionRow>(find.byType(GuOptionRow));
      expect(rows.where((r) => r.selected).map((r) => r.label), [
        tr.placePl02,
      ]);
      expect(find.byKey(_k('okCustom')), findsNothing);

      await tester.ensureVisible(
        find.byKey(PlacePickerSheet.selectKeyOf('pl08')),
      );
      await tester.tap(find.byKey(PlacePickerSheet.selectKeyOf('pl08')));
      await tester.pumpAndSettle();
      expect(h.result, const PlacePickerResult.place('pl08'));
    });

    testWidgets('arama Türkçe harf kuralıyla süzer', (tester) async {
      final h = _harness();
      await h.pump(tester);
      await h.open(tester);
      await tester.enterText(find.byKey(_k('search')), 'KÜTÜPHANE');
      await tester.pump();
      expect(find.byType(GuOptionRow), findsOneWidget);
      expect(find.text(tr.placePl07), findsOneWidget);
    });

    testWidgets('Başka bir yer yaz → boşken Tamam devre dışı → metin → '
        'custom(kırpılmış)', (tester) async {
      final h = _harness();
      await h.pump(tester);
      await h.open(tester);
      await tester.ensureVisible(find.byKey(_k('customToggle')));
      await tester.tap(find.byKey(_k('customToggle')));
      await tester.pumpAndSettle();
      expect(find.text(tr.sht30CustomLabel), findsOneWidget);
      expect(_ok(tester).disabled, isTrue);
      await tester.tap(find.byKey(_k('okCustom')));
      await tester.pumpAndSettle();
      expect(h.isClosed, isFalse);

      await tester.enterText(find.byKey(_k('custom')), '  Kafeterya  ');
      await tester.pump();
      expect(_ok(tester).disabled, isFalse);
      await tester.tap(find.byKey(_k('okCustom')));
      await tester.pumpAndSettle();
      expect(h.result, const PlacePickerResult.custom('Kafeterya'));
    });

    testWidgets('serbest metinle açılış: alan açık ve dolu', (tester) async {
      final h = _harness(placeText: 'Kafeterya');
      await h.pump(tester);
      await h.open(tester);
      expect(find.byKey(_k('customToggle')), findsNothing);
      expect(find.text('Kafeterya'), findsOneWidget);
      expect(_ok(tester).disabled, isFalse);
    });

    testWidgets('X → null', (tester) async {
      final h = _harness();
      await h.pump(tester);
      await h.open(tester);
      await tester.tap(find.byKey(_k('close')));
      await tester.pumpAndSettle();
      expect(h.result, isNull);
    });

    testWidgets('cihaz matrisi: taşma yok (güvenli alan, klavye)', (
      tester,
    ) async {
      await DeviceMatrix.run(
        tester,
        (_) => const Align(
          alignment: Alignment.bottomCenter,
          child: PlacePickerSheet(placeText: 'Kafeterya'),
        ),
        safeAreas: true,
        keyboard: true,
      );
    });

    testWidgets('golden: seçim yok (scrim dahil) — açık + koyu', (
      tester,
    ) async {
      for (final theme in kGoldenThemes) {
        final h = _harness();
        await h.pump(tester, theme: theme);
        await h.open(tester);
        await h.expectGolden(tester, 'SHT-30', theme);
      }
    });
  });
}
