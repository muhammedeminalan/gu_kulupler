// SHT-04 · Filtre ve sıralama (`ClubFilterSheet`): içerik (TR / EN), taslak
// üzerinde seçimler (kategori çoklu seçim, üyelik, anahtarlar, sıralama),
// "Sonuçları göster (n)" sayısı, "Temizle", sonuç (`pop(ClubFilters)`),
// kapanma (değişiklik yok), cihaz matrisi, açık + koyu golden.
// Referans: design/reference-shots/sheets/SHT-04__light.webp, __dark.webp;
// design/prototype/app/sheets.js:19–25.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/clubs/provider/club_filters.dart';
import 'package:gu_kulupler/features/clubs/view/widget/club_filter_sheet.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/l10n/static_labels.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../../helpers/device_matrix.dart';
import '../../../../helpers/test_l10n.dart';
import '../../club_list_test_support.dart';
import 'club_sheet_harness.dart';

Key _key(String action) => GuKey.action('SHT-04.$action');

/// Taslağa uyan kulüp sayısı: demo kulüpler, üyeliksiz kullanıcı.
int _countFor(ClubFilters filters) => filters.apply(kAllClubs).length;

ClubSheetHarness<ClubFilters> _harness({
  ClubFilters initial = ClubFilters.none,
  int Function(ClubFilters filters) countFor = _countFor,
}) => ClubSheetHarness<ClubFilters>(
  SheetId.sht04,
  (_) => ClubFilterSheet(initial: initial, countFor: countFor),
);

Future<void> _tap(WidgetTester tester, String action) async {
  final finder = find.byKey(_key(action));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

GuButton _apply(WidgetTester tester) =>
    tester.widget<GuButton>(find.byKey(_key('apply')));

void main() {
  group('SHT-04 · Filtre ve sıralama · içerik', () {
    for (final locale in DeviceMatrix.locales) {
      testWidgets('varsayılan (${locale.languageCode}): başlık, kategoriler, '
          'üyelik, anahtarlar, sıralama, alt düğmeler', (tester) async {
        final h = _harness();
        await h.pump(tester, locale: locale);
        await h.open(tester);
        final l10n = tester.l10nFor(locale);
        final context = tester.element(find.byType(ClubFilterSheet));

        final frame = tester.widget<GuSheetFrame>(find.byType(GuSheetFrame));
        expect(frame.title, l10n.sht04Title);
        expect(frame.closeSemanticLabel, l10n.a11yClose);

        for (final label in [
          l10n.sht04Category,
          l10n.sht04Membership,
          l10n.commonSort,
        ]) {
          expect(
            tester.widget<Text>(find.text(label)).style,
            context.gu.text.fieldLabel,
          );
        }

        // Kategori çipleri: 8 kategori, ikonlu, hiçbiri seçili değil.
        final chips = tester.widgetList<GuChip>(find.byType(GuChip)).toList();
        expect(chips.map((chip) => chip.label), [
          for (final category in StaticTables.categories)
            StaticLabels.category(context, category.id),
        ]);
        expect(chips.map((chip) => chip.selected).toSet(), {false});
        expect(chips.map((chip) => chip.icon), everyElement(isNotNull));

        final segmented = tester.widget<GuSegmented>(find.byType(GuSegmented));
        expect(segmented.options.map((option) => option.label), [
          l10n.commonAll,
          l10n.sht04Mine,
          l10n.sht04NotMine,
        ]);
        expect(segmented.value, ClubMembershipFilter.all.name);

        final switches = tester
            .widgetList<GuSwitch>(find.byType(GuSwitch))
            .toList();
        expect(switches.map((s) => s.semanticLabel), [
          l10n.sht04OpenOnly,
          l10n.sht04InstantOnly,
        ]);
        expect(switches.map((s) => s.value), [false, false]);
        expect(find.text(l10n.sht04OpenOnly), findsOneWidget);

        final rows = tester
            .widgetList<GuOptionRow>(find.byType(GuOptionRow))
            .toList();
        expect(rows.map((row) => row.label), [
          l10n.sht04SortPopular,
          l10n.sht04SortNew,
          l10n.sht04SortAz,
        ]);
        expect(rows.map((row) => row.selected), [true, false, false]);

        final clear = tester.widget<GuButton>(find.byKey(_key('clear')));
        expect(clear.label, l10n.commonClear);
        expect(clear.variant, GuButtonVariant.outline);
        expect(_apply(tester).label, l10n.sht04Show(kActiveClubCount));
        expect(_apply(tester).variant, GuButtonVariant.primary);
      });
    }

    testWidgets('açılış süzgeci taslağa yansır', (tester) async {
      const initial = ClubFilters(
        categoryIds: {'k03', 'k04'},
        membership: ClubMembershipFilter.notMine,
        applicationsOpenOnly: true,
        sort: ClubSort.newest,
      );
      final h = _harness(initial: initial);
      await h.pump(tester);
      await h.open(tester);

      for (final category in StaticTables.categories) {
        expect(
          tester
              .widget<GuChip>(find.byKey(_key('category.${category.id}')))
              .selected,
          initial.categoryIds.contains(category.id),
        );
      }
      expect(
        tester.widget<GuSegmented>(find.byType(GuSegmented)).value,
        ClubMembershipFilter.notMine.name,
      );
      expect(
        tester.widgetList<GuSwitch>(find.byType(GuSwitch)).map((s) => s.value),
        [true, false],
      );
      expect(
        tester
            .widgetList<GuOptionRow>(find.byType(GuOptionRow))
            .map((row) => row.selected),
        [false, true, false],
      );
      expect(_apply(tester).label, tester.l10n.sht04Show(_countFor(initial)));
    });
  });

  group('SHT-04 · Filtre ve sıralama · aksiyonlar', () {
    testWidgets('seçimler taslağı değiştirir, sayı güncellenir; "Sonuçları '
        'göster" taslağı döndürür', (tester) async {
      final h = _harness();
      await h.pump(tester);
      await h.open(tester);
      final l10n = tester.l10n;

      // Kategori: çoklu seçim; yeniden dokunma kaldırır.
      await _tap(tester, 'category.k04');
      await _tap(tester, 'category.k07');
      expect(
        _apply(tester).label,
        l10n.sht04Show(
          _countFor(const ClubFilters(categoryIds: {'k04', 'k07'})),
        ),
      );
      await _tap(tester, 'category.k07');

      await _tap(tester, 'membership.notMine');
      await _tap(tester, 'toggle.openOnly');
      await _tap(tester, 'toggle.instantOnly');
      await _tap(tester, 'sort.az');

      const expected = ClubFilters(
        categoryIds: {'k04'},
        membership: ClubMembershipFilter.notMine,
        applicationsOpenOnly: true,
        instantOnly: true,
        sort: ClubSort.az,
      );
      expect(_apply(tester).label, l10n.sht04Show(_countFor(expected)));
      expect(h.isClosed, isFalse);

      await _tap(tester, 'apply');
      expect(h.isClosed, isTrue);
      expect(h.result, expected);
    });

    testWidgets('sıralama satırları tek seçimlidir (popular / new / az)', (
      tester,
    ) async {
      final h = _harness();
      await h.pump(tester);
      await h.open(tester);
      for (final (action, index) in [('sort.new', 1), ('sort.popular', 0)]) {
        await _tap(tester, action);
        expect(
          tester
              .widgetList<GuOptionRow>(find.byType(GuOptionRow))
              .map((row) => row.selected),
          [for (var i = 0; i < ClubSort.values.length; i++) i == index],
        );
      }
    });

    testWidgets('"Temizle" taslağı sıfırlar, sayfa açık kalır', (tester) async {
      final h = _harness(
        initial: const ClubFilters(
          categoryIds: {'k01'},
          instantOnly: true,
          sort: ClubSort.az,
        ),
      );
      await h.pump(tester);
      await h.open(tester);
      await _tap(tester, 'clear');

      expect(h.isClosed, isFalse);
      expect(
        tester.widgetList<GuChip>(find.byType(GuChip)).map((c) => c.selected),
        everyElement(isFalse),
      );
      expect(_apply(tester).label, tester.l10n.sht04Show(kActiveClubCount));

      await _tap(tester, 'apply');
      expect(h.result, ClubFilters.none);
    });

    testWidgets('kapat (X) ve geri: sonuç yok — süzgeç değişmez', (
      tester,
    ) async {
      final h = _harness();
      await h.pump(tester);
      await h.open(tester);
      await _tap(tester, 'category.k01');
      await _tap(tester, 'close');
      expect(h.isClosed, isTrue);
      expect(h.result, isNull);

      await h.open(tester);
      // Yeniden açılış taslağı açılış süzgecinden kurar.
      expect(
        tester.widget<GuChip>(find.byKey(_key('category.k01'))).selected,
        isFalse,
      );
      await h.back(tester);
      expect(h.result, isNull);
    });
  });

  group('SHT-04 · Filtre ve sıralama · cihaz matrisi', () {
    testWidgets('varsayılan ve dolu süzgeç', (tester) async {
      for (final initial in [
        ClubFilters.none,
        const ClubFilters(
          categoryIds: {'k02', 'k06'},
          membership: ClubMembershipFilter.mine,
          applicationsOpenOnly: true,
          instantOnly: true,
          sort: ClubSort.newest,
        ),
      ]) {
        await DeviceMatrix.run(
          tester,
          (context) => Align(
            alignment: Alignment.bottomCenter,
            child: ClubFilterSheet(initial: initial, countFor: _countFor),
          ),
          safeAreas: true,
        );
      }
    });
  });

  group('SHT-04 · Filtre ve sıralama · golden', () {
    testWidgets('varsayılan açık + koyu', (tester) async {
      for (final theme in [ThemeMode.light, ThemeMode.dark]) {
        final h = _harness();
        await h.pump(tester, theme: theme);
        await h.open(tester);
        await h.expectGolden(tester, 'SHT-04', theme);
      }
    });
  });
}
