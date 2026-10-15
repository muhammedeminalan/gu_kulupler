// SHT-33 · Kategori seç — sekiz kulüp kategorisi, tek seçim
// (`CategoryPickerSheet`). İçerik (dolgusuz çerçeve, tablo sırası, amblem +
// ad, seçili işareti), seçim sonucu (`pop(String)`), kapanma yolları
// (`SHT-33.close`, scrim, geri), cihaz matrisi, açık + koyu golden.
// Referans: design/reference-shots/sheets/SHT-33__light.webp, __dark.webp;
// prototip sheets.js:153–154.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/category_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/device_matrix.dart';
import '../../helpers/test_l10n.dart';
import 'sheet_test_support.dart';

const Locale _tr = Locale('tr');
const Locale _en = Locale('en');

Key _key(String action) => FeedbackKeys.of(SheetId.sht33.designId, action);

SheetHarness<String> _harness({String? selected}) => SheetHarness<String>(
  SheetId.sht33,
  (_) => CategoryPickerSheet(selected: selected),
);

List<GuOptionRow> _rows(WidgetTester tester) =>
    tester.widgetList<GuOptionRow>(find.byType(GuOptionRow)).toList();

void main() {
  group('SHT-33 · Kategori seç · sözleşme', () {
    test('anahtarlar prototipteki aksiyon adlarıdır', () {
      expect(
        CategoryPickerSheet.keyOf('k03'),
        GuKey.action('SHT-33.select.k03'),
      );
      expect(_key('close'), GuKey.action('SHT-33.close'));
    });
  });

  group('SHT-33 · Kategori seç · içerik', () {
    testWidgets('dolgusuz çerçeve, başlık + kapat; 8 kategori tablo '
        'sırasıyla, küçük amblem + ad — TR ve EN', (tester) async {
      for (final locale in [_tr, _en]) {
        final h = _harness();
        await h.pump(tester, locale: locale);
        await h.open(tester);
        final l10n = tester.l10nFor(locale);

        final frame = tester.widget<GuSheetFrame>(find.byType(GuSheetFrame));
        expect(frame.title, l10n.sht33Title);
        expect(frame.closeSemanticLabel, l10n.a11yClose);
        expect(frame.flush, isTrue);
        expect(find.byKey(_key('close')), findsOneWidget);

        final rows = _rows(tester);
        expect(rows, hasLength(StaticTables.categories.length));
        expect(
          [for (final row in rows) row.key],
          [
            for (final c in StaticTables.categories)
              CategoryPickerSheet.keyOf(c.id),
          ],
        );
        expect(rows.first.label, l10n.catK01);
        expect(rows.last.label, l10n.catK08);
        expect(rows.map((row) => row.selected).toSet(), {false});
        for (final row in rows) {
          final emblem = row.leading! as GuEmblem;
          expect(emblem.size, GuEmblemSize.xs);
          expect(emblem.icon, isNotNull);
        }
      }
    });

    testWidgets('seçili kategori işaretlidir (yalnızca o)', (tester) async {
      final h = _harness(selected: 'k03');
      await h.pump(tester);
      await h.open(tester);
      final selected = _rows(tester).where((row) => row.selected).toList();
      expect(selected, hasLength(1));
      expect(selected.single.key, CategoryPickerSheet.keyOf('k03'));
    });
  });

  group('SHT-33 · Kategori seç · sonuç ve kapanma', () {
    testWidgets('satıra dokunma sayfayı kategori kimliğiyle kapatır', (
      tester,
    ) async {
      final h = _harness(selected: 'k03');
      await h.pump(tester);
      await h.open(tester);

      await tester.tap(find.byKey(CategoryPickerSheet.keyOf('k06')));
      await tester.pumpAndSettle();

      expect(find.byType(GuSheetFrame), findsNothing);
      expect(h.result, 'k06');
    });

    testWidgets('kapat düğmesi ve geri tuşu `null` döndürür', (tester) async {
      final h = _harness(selected: 'k01');
      await h.pump(tester);

      await h.open(tester);
      await tester.tap(find.byKey(_key('close')));
      await tester.pumpAndSettle();
      expect(h.isClosed, isTrue);
      expect(h.result, isNull);

      await h.open(tester);
      await h.back(tester);
      expect(h.isClosed, isTrue);
      expect(h.result, isNull);
    });
  });

  group('SHT-33 · Kategori seç · yerleşim', () {
    testWidgets('cihaz matrisi: taşma yok', (tester) async {
      await DeviceMatrix.run(
        tester,
        (context) => const Align(
          alignment: Alignment.bottomCenter,
          child: CategoryPickerSheet(selected: 'k01'),
        ),
        safeAreas: true,
      );
    });

    testWidgets('golden: seçili kategoriyle (prototip örneği k01), açık '
        'sayfa — açık + koyu (TR)', (tester) async {
      await _harness(selected: 'k01').golden(tester, 'SHT-33');
    });
  });
}
