// SHT-28 · Tarih seç (`DatePickerSheet`) — `GuCalendar` (compact) ile tek gün
// seçimi, "Tamam" sonucu (`pop(DateTime)`), "İptal" / X → `null`,
// `firstDate` / `lastDate` sınırı, ay geçişi, "Bugün", anahtarlar, cihaz
// matrisi, açık + koyu golden. Referans: design/reference-shots/sheets/
// SHT-28__light.webp, __dark.webp; prototip sheets.js:134–135.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/date_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/design_files.dart';
import '../../helpers/device_matrix.dart';
import '../../helpers/test_l10n.dart';
import 'sheet_test_support.dart';

/// Varsayılan sahte saat 2026-10-12 16:30Z = Istanbul 12 Ekim Pzt.
final DateTime _today = DateTime(2026, 10, 12);

Key _key(String action) => DatePickerSheet.keyOf(action);

SheetHarness<DateTime> _harness(WidgetBuilder builder) =>
    SheetHarness<DateTime>(SheetId.sht28, builder);

Future<SheetHarness<DateTime>> _open(
  WidgetTester tester,
  DatePickerSheet sheet,
) async {
  final h = _harness((_) => sheet);
  await h.pump(tester);
  await h.open(tester);
  return h;
}

GuCalendar _calendar(WidgetTester tester) =>
    tester.widget<GuCalendar>(find.byType(GuCalendar));

void main() {
  group('SHT-28 · Tarih seç · sözleşme', () {
    test('anahtarlar `SHT-28.<aksiyon>`; gün `SHT-28.day.<yyyy-mm-dd>`', () {
      expect(_key('ok'), GuKey.action('SHT-28.ok'));
      expect(_key('cancel'), GuKey.action('SHT-28.cancel'));
      expect(
        DatePickerSheet.dayKeyOf(DateTime(2026, 3, 7)),
        GuKey.action('SHT-28.day.2026-03-07'),
      );
    });

    test('`/// Design: SHT-28` izi DatePickerSheet sınıfındadır', () {
      final source = readText(
        'lib/product/feedback/catalogs/sheets/date_picker_sheet.dart',
      );
      expect(
        source,
        contains(RegExp(r'/// Design: SHT-28\s*\nclass DatePickerSheet\b')),
      );
    });
  });

  group('SHT-28 · Tarih seç · seçim ve sonuç', () {
    testWidgets('başlık varsayılan "Tarih seç"; compact; açılış günü seçili', (
      tester,
    ) async {
      await _open(tester, DatePickerSheet(initial: DateTime(2026, 11, 3)));
      expect(find.text(tester.l10n.sht28Title), findsOneWidget);
      expect(find.text('Kasım 2026'), findsOneWidget);
      final calendar = _calendar(tester);
      expect(calendar.compact, isTrue);
      expect(calendar.selected, DateTime(2026, 11, 3));
      expect(calendar.today, _today);
      for (final action in ['cancel', 'ok', 'close', 'prevMonth']) {
        expect(find.byKey(_key(action)), findsOneWidget, reason: action);
      }
    });

    testWidgets('gün seç → "Tamam" seçili günü döndürür (takvim günü)', (
      tester,
    ) async {
      final h = await _open(
        tester,
        DatePickerSheet(initial: DateTime.utc(2026, 10, 12, 21, 30)),
      );
      await tester.tap(
        find.byKey(DatePickerSheet.dayKeyOf(DateTime(2026, 10, 20))),
      );
      await tester.pump();
      expect(h.isClosed, isFalse);
      await tester.tap(find.byKey(_key('ok')));
      await tester.pumpAndSettle();
      expect(h.result, DateTime(2026, 10, 20));
    });

    testWidgets('"İptal" ve X → null', (tester) async {
      final h = await _open(tester, DatePickerSheet(initial: _today));
      await tester.tap(
        find.byKey(DatePickerSheet.dayKeyOf(DateTime(2026, 10, 20))),
      );
      await tester.tap(find.byKey(_key('cancel')));
      await tester.pumpAndSettle();
      expect(h.isClosed, isTrue);
      expect(h.result, isNull);

      await h.open(tester);
      await tester.tap(find.byKey(_key('close')));
      await tester.pumpAndSettle();
      expect(h.result, isNull);
    });

    testWidgets('özel başlık; ay ileri / geri', (tester) async {
      final to = tester.l10nFor(const Locale('tr')).sht11To;
      await _open(tester, DatePickerSheet(initial: _today, title: to));
      expect(find.text(to), findsOneWidget);
      await tester.tap(find.byKey(_key('nextMonth')));
      await tester.pump();
      expect(find.text('Kasım 2026'), findsOneWidget);
      await tester.tap(find.byKey(_key('prevMonth')));
      await tester.pump();
      await tester.tap(find.byKey(_key('prevMonth')));
      await tester.pump();
      expect(find.text('Eylül 2026'), findsOneWidget);
    });
  });

  group('SHT-28 · Tarih seç · sınırlar', () {
    testWidgets('firstDate / lastDate dışı gün seçilmez; sınır günleri dahil', (
      tester,
    ) async {
      final h = await _open(
        tester,
        DatePickerSheet(
          initial: DateTime(2026, 10, 15),
          firstDate: DateTime(2026, 10, 10),
          lastDate: DateTime(2026, 10, 20),
        ),
      );
      await tester.tap(
        find.byKey(DatePickerSheet.dayKeyOf(DateTime(2026, 10, 9))),
      );
      await tester.tap(
        find.byKey(DatePickerSheet.dayKeyOf(DateTime(2026, 10, 21))),
      );
      await tester.pump();
      expect(_calendar(tester).selected, DateTime(2026, 10, 15));
      await tester.tap(
        find.byKey(DatePickerSheet.dayKeyOf(DateTime(2026, 10, 20))),
      );
      await tester.pump();
      expect(_calendar(tester).selected, DateTime(2026, 10, 20));
      await tester.tap(
        find.byKey(DatePickerSheet.dayKeyOf(DateTime(2026, 10, 10))),
      );
      await tester.tap(find.byKey(_key('ok')));
      await tester.pumpAndSettle();
      expect(h.result, DateTime(2026, 10, 10));
    });

    testWidgets('sınır dışı açılış günü en yakın sınıra çekilir', (
      tester,
    ) async {
      final h = await _open(
        tester,
        DatePickerSheet(
          initial: DateTime(2026, 9, 2),
          firstDate: DateTime(2026, 10, 14),
        ),
      );
      expect(_calendar(tester).selected, DateTime(2026, 10, 14));
      await tester.tap(find.byKey(_key('ok')));
      await tester.pumpAndSettle();
      expect(h.result, DateTime(2026, 10, 14));
    });

    testWidgets('"Bugün": sınır içinde bugünü seçer, dışında yalnızca ayı '
        'değiştirir', (tester) async {
      await _open(tester, DatePickerSheet(initial: DateTime(2026, 12, 24)));
      await tester.tap(find.byKey(_key('today')));
      await tester.pump();
      expect(find.text('Ekim 2026'), findsOneWidget);
      expect(_calendar(tester).selected, _today);

      await _open(
        tester,
        DatePickerSheet(
          initial: DateTime(2026, 12, 24),
          firstDate: DateTime(2026, 12),
        ),
      );
      await tester.tap(find.byKey(_key('today')));
      await tester.pump();
      expect(find.text('Ekim 2026'), findsOneWidget);
      expect(_calendar(tester).selected, DateTime(2026, 12, 24));
    });
  });

  group('SHT-28 · Tarih seç · cihaz matrisi ve golden', () {
    testWidgets('cihaz matrisi: taşma yok', (tester) async {
      await DeviceMatrix.run(
        tester,
        (_) => Align(
          alignment: Alignment.bottomCenter,
          child: DatePickerSheet(initial: _today),
        ),
        safeAreas: true,
      );
    });

    testWidgets('golden: bugün seçili (12 Eki) — açık + koyu (TR)', (
      tester,
    ) async {
      await _harness(
        (_) => DatePickerSheet(initial: _today),
      ).golden(tester, 'SHT-28');
    });
  });
}
