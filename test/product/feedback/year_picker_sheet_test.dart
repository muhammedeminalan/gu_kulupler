// SHT-03 · Sınıf seç — sekiz öğrenim düzeyi, tek seçim (`YearPickerSheet`).
// İçerik, seçili işareti, anahtarlar (`SHT-03.select.<düzey>`, `.close`,
// `.scrim`), seçim sonucu (`pop(YearLevel)`), kapanma yolları, cihaz matrisi,
// açık + koyu golden. Referans: design/reference-shots/sheets/
// SHT-03__light.webp, __dark.webp; prototip sheets.js:18.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/year_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/design_files.dart';
import '../../helpers/device_matrix.dart';
import '../../helpers/test_l10n.dart';
import 'sheet_test_support.dart';

const Locale _tr = Locale('tr');
const Locale _en = Locale('en');

Key _key(String action) => FeedbackKeys.of(SheetId.sht03.designId, action);

SheetHarness<YearLevel> _harness() => SheetHarness<YearLevel>(
  SheetId.sht03,
  (_) => const YearPickerSheet(),
);

extension on SheetHarness<YearLevel> {
  /// Sayfayı [value] seçiliyken açar.
  Future<void> openWith(WidgetTester tester, {required YearLevel value}) {
    builder = (_) => YearPickerSheet(value: value);
    return open(tester);
  }
}

void main() {
  group('SHT-03 · Sınıf seç · sözleşme', () {
    test('anahtarlar prototipteki aksiyon adlarıdır (`year.<kimlik>`)', () {
      expect(
        [
          for (final year in YearLevel.values)
            (YearPickerSheet.keyOf(year) as ValueKey<String>).value,
        ],
        [
          'SHT-03.select.prep',
          'SHT-03.select.1',
          'SHT-03.select.2',
          'SHT-03.select.3',
          'SHT-03.select.4',
          'SHT-03.select.5plus',
          'SHT-03.select.master',
          'SHT-03.select.phd',
        ],
      );
      expect(
        YearPickerSheet.keyOf(YearLevel.fivePlus),
        GuKey.action('SHT-03.select.5plus'),
      );
    });

    test('`/// Design: SHT-03` izi YearPickerSheet sınıfındadır', () {
      final source = readText(
        'lib/product/feedback/catalogs/sheets/year_picker_sheet.dart',
      );
      expect(
        RegExp(r'///\s*Design:\s*SHT-03').allMatches(source),
        hasLength(1),
      );
      expect(
        source,
        contains(RegExp(r'/// Design: SHT-03\s*\nclass YearPickerSheet\b')),
      );
    });
  });

  group('SHT-03 · Sınıf seç · içerik', () {
    testWidgets('çerçeve dolgusuz; başlık, kapat, sekiz radyo satırı tasarım '
        'sırasıyla — TR ve EN', (tester) async {
      for (final locale in [_tr, _en]) {
        final h = _harness();
        await h.pump(tester, locale: locale);
        await h.open(tester);
        final l10n = tester.l10nFor(locale);

        final frame = tester.widget<GuSheetFrame>(find.byType(GuSheetFrame));
        expect(frame.title, l10n.sht03Title);
        expect(frame.closeSemanticLabel, l10n.a11yClose);
        expect(frame.flush, isTrue);
        expect(frame.full, isFalse);
        expect(frame.menu, isFalse);
        expect(frame.footer, isNull);
        expect(find.byKey(_key('close')), findsOneWidget);
        expect(find.byKey(_key('scrim')), findsOneWidget);

        final rows = tester
            .widgetList<GuOptionRow>(find.byType(GuOptionRow))
            .toList();
        expect(rows.map((row) => row.label), [
          l10n.yearPrep,
          l10n.year1,
          l10n.year2,
          l10n.year3,
          l10n.year4,
          l10n.year5plus,
          l10n.yearMaster,
          l10n.yearPhd,
        ]);
        expect(rows.map((row) => row.key), [
          for (final year in YearLevel.values) YearPickerSheet.keyOf(year),
        ]);
        expect(rows.map((row) => row.control).toSet(), {GuOptionControl.radio});
        expect(rows.map((row) => row.sub).toSet(), {null});
        expect(rows.map((row) => row.selected).toSet(), {false});
        // Satırlar çerçevenin tam genişliğindedir (`is-flush`).
        expect(
          tester.getSize(find.byType(GuOptionRow).first).width,
          tester.getSize(find.byType(GuSheetFrame)).width,
        );
      }
      expect(tester.l10nFor(_tr).yearPrep, 'Hazırlık');
      expect(tester.l10nFor(_tr).year5plus, '5+ sınıf');
    });

    testWidgets('seçili düzey işaretlidir; sıra değişmez — her düzey', (
      tester,
    ) async {
      for (final value in YearLevel.values) {
        final h = _harness();
        await h.pump(tester);
        await h.openWith(tester, value: value);

        final rows = tester
            .widgetList<GuOptionRow>(find.byType(GuOptionRow))
            .toList();
        expect(rows.map((row) => row.selected), [
          for (final year in YearLevel.values) year == value,
        ], reason: value.name);
        expect(
          tester
              .widget<GuOptionRow>(find.byKey(YearPickerSheet.keyOf(value)))
              .selected,
          isTrue,
        );
      }
    });

    testWidgets('sekiz satır 390×844’te kaydırmadan sığar', (tester) async {
      final h = _harness();
      await h.pump(tester);
      await h.open(tester);

      final frame = tester.getRect(find.byType(GuSheetFrame));
      expect(frame.bottom, 844);
      expect(frame.height, lessThan(844 * GuSizes.sheetMaxHeightRatio));
      final last = tester.getRect(
        find.byKey(YearPickerSheet.keyOf(YearLevel.phd)),
      );
      expect(last.bottom, lessThanOrEqualTo(844));
      expect(
        tester.getRect(find.byType(GuOptionRow).first).height,
        GuSizes.optionRowMinHeight,
      );
    });
  });

  group('SHT-03 · Sınıf seç · sonuç ve kapanma', () {
    testWidgets('satıra dokunma sayfayı seçilen düzeyle kapatır — her düzey', (
      tester,
    ) async {
      final h = _harness();
      await h.pump(tester);
      for (final year in YearLevel.values) {
        await h.openWith(tester, value: YearLevel.first);
        await tester.tap(find.byKey(YearPickerSheet.keyOf(year)));
        await tester.pumpAndSettle();

        expect(find.byType(GuSheetFrame), findsNothing, reason: year.name);
        expect(h.result, year, reason: year.name);
      }
    });

    testWidgets('kapat düğmesi, scrim ve geri tuşu `null` döndürür', (
      tester,
    ) async {
      final h = _harness();
      await h.pump(tester);
      for (final action in ['close', 'scrim']) {
        await h.openWith(tester, value: YearLevel.second);
        await tester.tap(find.byKey(_key(action)));
        await tester.pumpAndSettle();
        expect(find.byType(GuSheetFrame), findsNothing, reason: action);
        expect(h.isClosed, isTrue, reason: action);
        expect(h.result, isNull, reason: action);
      }

      await h.openWith(tester, value: YearLevel.second);
      await h.back(tester);
      expect(find.byType(GuSheetFrame), findsNothing);
      expect(h.isClosed, isTrue);
      expect(h.result, isNull);
    });

    testWidgets('başlıktan aşağı sürükleme `null` ile kapatır', (tester) async {
      final h = _harness();
      await h.pump(tester);
      await h.open(tester);

      await tester.drag(
        find.text(tester.l10nFor(_tr).sht03Title),
        const Offset(0, GuSizes.sheetDragCloseThreshold + 40),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GuSheetFrame), findsNothing);
      expect(h.isClosed, isTrue);
      expect(h.result, isNull);
    });
  });

  group('SHT-03 · Sınıf seç · yerleşim', () {
    testWidgets('cihaz matrisi: taşma yok (güvenli alanlar dahil)', (
      tester,
    ) async {
      await DeviceMatrix.run(
        tester,
        (context) => const Align(
          alignment: Alignment.bottomCenter,
          child: YearPickerSheet(value: YearLevel.first),
        ),
        safeAreas: true,
      );
    });

    testWidgets('golden: seçili düzeyle, açık sayfa (scrim dahil) — açık + '
        'koyu (TR)', (tester) async {
      final h = _harness()
        ..builder = (_) => const YearPickerSheet(value: YearLevel.first);
      await h.golden(tester, 'SHT-03');
    });
  });
}
