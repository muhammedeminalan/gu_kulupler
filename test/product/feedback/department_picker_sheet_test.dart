// SHT-02 · Bölüm seç — arama + fakülte grupları + tek seçim
// (`DepartmentPickerSheet`). İçerik, seçili-önce sıralama, arama (TR / EN
// büyük-küçük harf), boş durum, seçim sonucu (`pop(String)`), kapanma yolları
// (`SHT-02.close`, `.scrim`, sürükleme, geri), cihaz matrisi, açık + koyu
// golden. Referans: design/reference-shots/sheets/SHT-02__light.webp,
// __dark.webp; prototip sheets.js:15–16.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/department_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/design_files.dart';
import '../../helpers/device_matrix.dart';
import '../../helpers/test_l10n.dart';
import 'sheet_test_support.dart';

const Locale _tr = Locale('tr');
const Locale _en = Locale('en');

Key _key(String action) => FeedbackKeys.of(SheetId.sht02.designId, action);

SheetHarness<String> _harness() => SheetHarness<String>(
  SheetId.sht02,
  (_) => const DepartmentPickerSheet(),
);

extension on SheetHarness<String> {
  /// Sayfayı [value] seçiliyken açar.
  Future<void> openWith(WidgetTester tester, {required String value}) {
    builder = (_) => DepartmentPickerSheet(value: value);
    return open(tester);
  }
}

/// Çizili seçenek satırlarının bölüm kimlikleri, ekran sırasıyla.
List<String> _rowIds(WidgetTester tester) => [
  for (final row in tester.widgetList<GuOptionRow>(find.byType(GuOptionRow)))
    (row.key! as ValueKey<String>).value.split('.').last,
];

/// Çizili grup başlıkları (overline metinleri), ekran sırasıyla.
List<String> _headers(WidgetTester tester) {
  final overline = tester.element(find.byType(GuSheetFrame)).gu.text.overline;
  return [
    for (final text in tester.widgetList<Text>(
      find.descendant(
        of: find.byType(GuSheetFrame),
        matching: find.byType(Text),
      ),
    ))
      if (text.style == overline) text.data!,
  ];
}

Future<void> _search(WidgetTester tester, String query) async {
  await tester.enterText(find.byKey(DepartmentPickerSheet.searchKey), query);
  await tester.pump();
}

void main() {
  group('SHT-02 · Bölüm seç · sözleşme', () {
    test('anahtarlar prototipteki aksiyon adlarıdır', () {
      expect(DepartmentPickerSheet.searchKey, GuKey.action('SHT-02.search'));
      expect(
        DepartmentPickerSheet.keyOf('d07'),
        GuKey.action('SHT-02.select.d07'),
      );
    });

    test('`/// Design: SHT-02` izi DepartmentPickerSheet sınıfındadır', () {
      final source = readText(
        'lib/product/feedback/catalogs/sheets/department_picker_sheet.dart',
      );
      expect(
        RegExp(r'///\s*Design:\s*SHT-02').allMatches(source),
        hasLength(1),
      );
      expect(
        source,
        contains(
          RegExp(r'/// Design: SHT-02\s*\nclass DepartmentPickerSheet\b'),
        ),
      );
    });
  });

  group('SHT-02 · Bölüm seç · içerik', () {
    testWidgets('çerçeve tam yükseklik + dolgusuz; başlık, kapat, odaklı '
        'arama alanı — TR ve EN', (tester) async {
      for (final locale in [_tr, _en]) {
        final h = _harness();
        await h.pump(tester, locale: locale);
        await h.open(tester);
        final l10n = tester.l10nFor(locale);

        final frame = tester.widget<GuSheetFrame>(find.byType(GuSheetFrame));
        expect(frame.title, l10n.sht02Title);
        expect(frame.closeSemanticLabel, l10n.a11yClose);
        expect(frame.full, isTrue);
        expect(frame.flush, isTrue);
        expect(frame.menu, isFalse);
        expect(frame.footer, isNull);
        expect(find.byKey(_key('close')), findsOneWidget);
        expect(find.byKey(_key('scrim')), findsOneWidget);
        // `.sheet-full`: yükseklik kullanılabilir alanın %90'ı.
        expect(
          tester.getSize(find.byType(GuSheetFrame)).height,
          844 * GuSizes.sheetFullHeightRatio,
        );

        final search = tester.widget<GuSearchField>(find.byType(GuSearchField));
        expect(search.value, isEmpty);
        expect(search.placeholder, l10n.commonSearch);
        expect(search.semanticLabel, l10n.commonSearch);
        expect(search.autofocus, isTrue);
        expect(search.onClear, isNull);
        expect(search.compact, isFalse);
        final field = tester.widget<TextField>(
          find.byKey(DepartmentPickerSheet.searchKey),
        );
        expect(field.focusNode!.hasFocus, isTrue, reason: '$locale');
        // Arama alanı dolgusu 0 / 16 / 16 (`px16 pb16`).
        final frameRect = tester.getRect(find.byType(GuSheetFrame));
        final searchRect = tester.getRect(find.byType(GuSearchField));
        expect(searchRect.left, frameRect.left + 16);
        expect(searchRect.right, frameRect.right - 16);
        final firstHeader = tester.getRect(find.text(_headers(tester).first));
        // Grup başlığı üst dolgusu 12 → arama alt dolgusu 16 + 12.
        expect(firstHeader.top, searchRect.bottom + 16 + 12);
        expect(firstHeader.left, frameRect.left + 16);
      }
    });

    testWidgets('24 bölüm, 6 fakülte grubu, tablo sırasıyla; başlıklar büyük '
        'harf (TR: i → İ); seçim yokken hiçbiri seçili değil', (tester) async {
      for (final locale in [_tr, _en]) {
        final h = _harness();
        await h.pump(tester, locale: locale);
        await h.open(tester);
        final l10n = tester.l10nFor(locale);

        expect(_rowIds(tester), [
          for (final department in StaticTables.departments) department.id,
        ]);
        final rows = tester
            .widgetList<GuOptionRow>(find.byType(GuOptionRow))
            .toList();
        expect(rows, hasLength(24));
        expect(rows.map((row) => row.selected).toSet(), {false});
        expect(rows.map((row) => row.control).toSet(), {GuOptionControl.radio});
        expect(rows.map((row) => row.sub).toSet(), {null});
        expect(rows.first.label, l10n.deptD01);
        expect(rows.last.label, l10n.deptD24);

        expect(_headers(tester), [
          l10n.facultyF1.upperFor(locale),
          l10n.facultyF2.upperFor(locale),
          l10n.facultyF3.upperFor(locale),
          l10n.facultyF4.upperFor(locale),
          l10n.facultyF5.upperFor(locale),
          l10n.facultyF6.upperFor(locale),
        ]);
      }
      // Türkçe büyük harf: "Mühendislik" → "MÜHENDİSLİK" (noktalı İ).
      expect(
        tester.l10nFor(_tr).facultyF1.upperFor(_tr),
        contains('MÜHENDİSLİK'),
      );
    });

    testWidgets('grup başlığı: zemin sheet yüzeyi (bg.surfaceRaised), başlık '
        'semantiği; her grup kendi bölümleriyle sıralı — açık + koyu', (
      tester,
    ) async {
      for (final theme in [ThemeMode.light, ThemeMode.dark]) {
        final h = _harness();
        await h.pump(tester, theme: theme);
        await h.open(tester);
        final colors = tester.element(find.byType(GuSheetFrame)).gu.colors;
        final header = find.text(_headers(tester).first);

        final box = tester.widget<ColoredBox>(
          find.ancestor(of: header, matching: find.byType(ColoredBox)).first,
        );
        expect(box.color, colors.bgSurfaceRaised, reason: '$theme');
        expect(
          tester.getSemantics(header),
          isSemantics(isHeader: true, label: _headers(tester).first),
        );
        // Başlık kendi grubunun ilk satırının üstünde, sonraki grubun
        // başlığı o grubun son satırının altındadır.
        final f1Last = tester.getRect(
          find.byKey(DepartmentPickerSheet.keyOf('d07')),
        );
        final f2Head = tester.getRect(find.text(_headers(tester)[1]));
        final f2First = tester.getRect(
          find.byKey(DepartmentPickerSheet.keyOf('d08')),
        );
        expect(f2Head.top, greaterThanOrEqualTo(f1Last.bottom));
        expect(f2First.top, greaterThanOrEqualTo(f2Head.bottom));
      }
    });

    testWidgets('seçili bölüm işaretlidir ve kendi grubunun başına alınır; '
        'grup sırası değişmez', (tester) async {
      final h = _harness();
      await h.pump(tester);
      await h.openWith(tester, value: 'd12');

      final ids = _rowIds(tester);
      // f3 = d10–d15: seçili d12 başa, diğerleri tablo sırasıyla.
      expect(ids.sublist(9, 15), ['d12', 'd10', 'd11', 'd13', 'd14', 'd15']);
      expect(ids.sublist(0, 9), [
        'd01',
        'd02',
        'd03',
        'd04',
        'd05',
        'd06',
        'd07',
        'd08',
        'd09',
      ]);
      final selected = tester
          .widgetList<GuOptionRow>(find.byType(GuOptionRow))
          .where((row) => row.selected)
          .toList();
      expect(selected, hasLength(1));
      expect(selected.single.label, tester.l10nFor(_tr).deptD12);
      expect(_headers(tester), hasLength(6));
    });

    testWidgets('tabloda olmayan seçili kimlik: liste değişmez, seçili yok', (
      tester,
    ) async {
      final h = _harness();
      await h.pump(tester);
      await h.openWith(tester, value: 'd99');

      expect(_rowIds(tester), [
        for (final department in StaticTables.departments) department.id,
      ]);
      expect(
        tester
            .widgetList<GuOptionRow>(find.byType(GuOptionRow))
            .where((row) => row.selected),
        isEmpty,
      );
    });
  });

  group('SHT-02 · Bölüm seç · arama', () {
    testWidgets(
      'ad içinde arar; eşleşmesi olmayan fakülte çizilmez; temizlenince '
      'tam liste döner',
      (tester) async {
        final h = _harness();
        await h.pump(tester);
        await h.open(tester);
        final l10n = tester.l10nFor(_tr);

        await _search(tester, 'mimar');
        expect(_rowIds(tester), ['d08', 'd09']);
        expect(_headers(tester), [l10n.facultyF2.upperFor(_tr)]);
        expect(find.text(l10n.sht02Empty), findsNothing);

        await _search(tester, '');
        expect(_rowIds(tester), hasLength(24));
        expect(_headers(tester), hasLength(6));
      },
    );

    testWidgets('Türkçe büyük/küçük harf duyarsız: "İNŞAAT", "inşaat"; '
        '"GIDA" → "Gıda" (I ↔ ı); baştaki / sondaki boşluk yok sayılır', (
      tester,
    ) async {
      final h = _harness();
      await h.pump(tester);
      await h.open(tester);
      final l10n = tester.l10nFor(_tr);
      expect(l10n.deptD03, 'İnşaat Mühendisliği');
      expect(l10n.deptD07, 'Gıda Mühendisliği');

      for (final query in ['İNŞAAT', 'inşaat', '  İnşaat  ']) {
        await _search(tester, query);
        expect(_rowIds(tester), ['d03'], reason: query);
      }
      for (final query in ['GIDA', 'gıda']) {
        await _search(tester, query);
        expect(_rowIds(tester), ['d07'], reason: query);
      }
      // Noktalı / noktasız i ayrı harftir: "gida" Türkçede "Gıda"yı bulmaz.
      await _search(tester, 'gida');
      expect(_rowIds(tester), isEmpty);
    });

    testWidgets('İngilizcede yerelden bağımsız küçük harf: "ENGIN" / "engin" '
        'aynı sonucu verir (Türkçe I → ı uygulanmaz)', (tester) async {
      final h = _harness();
      await h.pump(tester, locale: _en);
      await h.open(tester);
      // Beklenen: ekrandaki (ARB) adında "engin" geçen bölümler.
      final expected = [
        for (final row in tester.widgetList<GuOptionRow>(
          find.byType(GuOptionRow),
        ))
          if (row.label.toLowerCase().contains('engin'))
            (row.key! as ValueKey<String>).value.split('.').last,
      ];
      expect(expected, isNotEmpty);
      expect(expected.length, lessThan(24));

      for (final query in ['ENGIN', 'engin', 'Engin']) {
        await _search(tester, query);
        expect(_rowIds(tester), expected, reason: query);
      }
    });

    testWidgets('eşleşme yok: "Bölüm bulunamadı" (bodyS, text.muted, ortalı); '
        'grup ve satır çizilmez — TR ve EN', (tester) async {
      for (final locale in [_tr, _en]) {
        final h = _harness();
        await h.pump(tester, locale: locale);
        await h.open(tester);
        final l10n = tester.l10nFor(locale);

        await _search(tester, 'zzzz');
        expect(find.byType(GuOptionRow), findsNothing);
        expect(_headers(tester), isEmpty);
        final empty = tester.widget<Text>(find.text(l10n.sht02Empty));
        final gu = tester.element(find.byType(GuSheetFrame)).gu;
        expect(empty.textAlign, TextAlign.center);
        expect(empty.style, gu.text.bodyS.copyWith(color: gu.colors.textMuted));
        // Sayfa tam yükseklikte kalır (liste kısalınca küçülmez).
        expect(
          tester.getSize(find.byType(GuSheetFrame)).height,
          844 * GuSizes.sheetFullHeightRatio,
        );
      }
    });

    testWidgets('arama seçili bölümü de süzer; eşleşirse yine grubunun '
        'başındadır', (tester) async {
      final h = _harness();
      await h.pump(tester);
      await h.openWith(tester, value: 'd05');
      final l10n = tester.l10nFor(_tr);
      expect(l10n.deptD05, contains('Mühendisliği'));

      await _search(tester, 'mühendisliği');
      final ids = _rowIds(tester);
      expect(ids.first, 'd05');
      expect(ids.sublist(0, 7).toSet(), {
        'd01',
        'd02',
        'd03',
        'd04',
        'd05',
        'd06',
        'd07',
      });

      await _search(tester, 'mimar');
      expect(_rowIds(tester), ['d08', 'd09']);
      expect(
        tester
            .widgetList<GuOptionRow>(find.byType(GuOptionRow))
            .where((row) => row.selected),
        isEmpty,
      );
    });
  });

  group('SHT-02 · Bölüm seç · sonuç ve kapanma', () {
    testWidgets('satıra dokunma sayfayı bölüm kimliğiyle kapatır', (
      tester,
    ) async {
      final h = _harness();
      await h.pump(tester);
      await h.open(tester);

      await tester.tap(find.byKey(DepartmentPickerSheet.keyOf('d02')));
      await tester.pumpAndSettle();

      expect(find.byType(GuSheetFrame), findsNothing);
      expect(h.result, 'd02');
    });

    testWidgets('aramadan sonra seçim; zaten seçili bölüme dokunma da aynı '
        'kimliği döndürür', (tester) async {
      final h = _harness();
      await h.pump(tester);
      await h.openWith(tester, value: 'd09');
      await _search(tester, 'peyzaj');
      expect(_rowIds(tester), ['d09']);

      await tester.tap(find.byKey(DepartmentPickerSheet.keyOf('d09')));
      await tester.pumpAndSettle();

      expect(find.byType(GuSheetFrame), findsNothing);
      expect(h.result, 'd09');
    });

    testWidgets('listenin sonundaki bölüm kaydırılarak seçilir', (
      tester,
    ) async {
      final h = _harness();
      await h.pump(tester);
      await h.open(tester);
      final last = find.byKey(DepartmentPickerSheet.keyOf('d24'));

      await tester.ensureVisible(last);
      await tester.pumpAndSettle();
      await tester.tap(last);
      await tester.pumpAndSettle();

      expect(h.result, 'd24');
    });

    testWidgets('kapat düğmesi, scrim ve geri tuşu `null` döndürür', (
      tester,
    ) async {
      final h = _harness();
      await h.pump(tester);

      await h.openWith(tester, value: 'd01');
      await tester.tap(find.byKey(_key('close')));
      await tester.pumpAndSettle();
      expect(find.byType(GuSheetFrame), findsNothing);
      expect(h.isClosed, isTrue);
      expect(h.result, isNull);

      // Scrim: sayfanın üstünde kalan şerit (yükseklik %90).
      await h.openWith(tester, value: 'd01');
      expect(find.byKey(_key('scrim')), findsOneWidget);
      await tester.tapAt(const Offset(195, 24));
      await tester.pumpAndSettle();
      expect(find.byType(GuSheetFrame), findsNothing);
      expect(h.isClosed, isTrue);
      expect(h.result, isNull);

      await h.openWith(tester, value: 'd01');
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
        find.text(tester.l10nFor(_tr).sht02Title),
        const Offset(0, GuSizes.sheetDragCloseThreshold + 40),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GuSheetFrame), findsNothing);
      expect(h.isClosed, isTrue);
      expect(h.result, isNull);
    });
  });

  group('SHT-02 · Bölüm seç · yerleşim', () {
    testWidgets('cihaz matrisi: taşma yok (klavye ve güvenli alanlar dahil)', (
      tester,
    ) async {
      await DeviceMatrix.run(
        tester,
        (context) => const Align(
          alignment: Alignment.bottomCenter,
          child: DepartmentPickerSheet(value: 'd01'),
        ),
        keyboard: true,
        safeAreas: true,
      );
    });

    testWidgets('golden: seçili bölümle, açık sayfa (scrim dahil) — açık + '
        'koyu (TR)', (tester) async {
      final h = _harness()
        ..builder = (_) => const DepartmentPickerSheet(value: 'd01');
      await h.golden(tester, 'SHT-02');
    });
  });
}
