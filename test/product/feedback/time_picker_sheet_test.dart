// SHT-29 · Saat seç (`TimePickerSheet`) — saat (0–23) ve dakika (adımlı)
// tekerleği, seçim bandı + ":" ayırıcı, "Tamam" sonucu
// (`pop(TimeOfDayValue)`), "İptal" / X → `null`, açılış dakikasının adıma
// yuvarlanması, özel başlık / adım, anahtarlar, cihaz matrisi, açık + koyu
// golden. Referans: design/reference-shots/sheets/SHT-29__light.webp,
// __dark.webp; prototip sheets.js:136–140.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/time_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/format/time_of_day_value.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/design_files.dart';
import '../../helpers/device_matrix.dart';
import '../../helpers/test_l10n.dart';
import 'sheet_test_support.dart';

const TimeOfDayValue _sixPm = TimeOfDayValue(18, 0);

Key _key(String action) => TimePickerSheet.keyOf(action);

SheetHarness<TimeOfDayValue> _harness(WidgetBuilder builder) =>
    SheetHarness<TimeOfDayValue>(SheetId.sht29, builder);

Future<SheetHarness<TimeOfDayValue>> _open(
  WidgetTester tester,
  TimePickerSheet sheet,
) async {
  final h = _harness((_) => sheet);
  await h.pump(tester);
  await h.open(tester);
  return h;
}

GuWheelPicker _wheel(WidgetTester tester, String action) =>
    tester.widget<GuWheelPicker>(find.byKey(_key(action)));

void main() {
  group('SHT-29 · Saat seç · sözleşme', () {
    test('anahtarlar `SHT-29.<aksiyon>`', () {
      for (final action in ['hour', 'minute', 'ok', 'cancel', 'close']) {
        expect(_key(action), GuKey.action('SHT-29.$action'));
      }
    });

    test('`/// Design: SHT-29` izi TimePickerSheet sınıfındadır', () {
      final source = readText(
        'lib/product/feedback/catalogs/sheets/time_picker_sheet.dart',
      );
      expect(
        source,
        contains(RegExp(r'/// Design: SHT-29\s*\nclass TimePickerSheet\b')),
      );
    });
  });

  group('SHT-29 · Saat seç · seçim ve sonuç', () {
    testWidgets('başlık "Saat seç"; 24 saat, 5 dk adım; açılış saati seçili; '
        'ayırıcı; "Tamam" saati döndürür', (tester) async {
      final h = await _open(tester, const TimePickerSheet(initial: _sixPm));
      final l10n = tester.l10n;
      expect(find.text(l10n.sht29Title), findsOneWidget);
      final hour = _wheel(tester, 'hour');
      final minute = _wheel(tester, 'minute');
      expect(hour.values, hasLength(24));
      expect(hour.values.first, '00');
      expect(hour.values.last, '23');
      expect(hour.value, '18');
      expect(hour.semanticLabel, l10n.sht29Hour);
      expect(minute.values, [
        for (var m = 0; m < 60; m += 5) TimeOfDayValue.pad2(m),
      ]);
      expect(minute.value, '00');
      expect(minute.semanticLabel, l10n.sht29Minute);
      expect(find.text(':'), findsOneWidget);
      for (final action in ['cancel', 'ok', 'close']) {
        expect(find.byKey(_key(action)), findsOneWidget, reason: action);
      }

      await tester.tap(find.byKey(_key('ok')));
      await tester.pumpAndSettle();
      expect(h.result, _sixPm);
    });

    testWidgets('öğeye dokunma seçer: 19 · 05 → "Tamam" 19:05', (tester) async {
      final h = await _open(tester, const TimePickerSheet(initial: _sixPm));
      await tester.tap(find.text('19'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('05'));
      await tester.pumpAndSettle();
      expect(_wheel(tester, 'hour').value, '19');
      expect(_wheel(tester, 'minute').value, '05');
      expect(h.isClosed, isFalse);
      await tester.tap(find.byKey(_key('ok')));
      await tester.pumpAndSettle();
      expect(h.result, const TimeOfDayValue(19, 5));
    });

    testWidgets('"İptal" ve X → null', (tester) async {
      final h = await _open(tester, const TimePickerSheet(initial: _sixPm));
      await tester.tap(find.text('19'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_key('cancel')));
      await tester.pumpAndSettle();
      expect(h.isClosed, isTrue);
      expect(h.result, isNull);

      await h.open(tester);
      await tester.tap(find.byKey(_key('close')));
      await tester.pumpAndSettle();
      expect(h.result, isNull);
    });

    testWidgets('açılış dakikası adıma yuvarlanır (07:58 → 07:00 — '
        'sheets.js:139 `% 60`; 22:03 → 22:05)', (tester) async {
      var h = await _open(
        tester,
        const TimePickerSheet(initial: TimeOfDayValue(7, 58)),
      );
      expect(_wheel(tester, 'minute').value, '00');
      await tester.tap(find.byKey(_key('ok')));
      await tester.pumpAndSettle();
      expect(h.result, const TimeOfDayValue(7, 0));

      h = await _open(
        tester,
        const TimePickerSheet(initial: TimeOfDayValue(22, 3)),
      );
      await tester.tap(find.byKey(_key('ok')));
      await tester.pumpAndSettle();
      expect(h.result, const TimeOfDayValue(22, 5));
    });

    testWidgets('özel başlık ve adım (15 dk)', (tester) async {
      final title = tester.l10nFor(const Locale('tr')).notifPrefsQuietFrom;
      await _open(
        tester,
        TimePickerSheet(initial: _sixPm, minuteStep: 15, title: title),
      );
      expect(find.text(title), findsOneWidget);
      expect(_wheel(tester, 'minute').values, ['00', '15', '30', '45']);
    });
  });

  group('SHT-29 · Saat seç · cihaz matrisi ve golden', () {
    testWidgets('cihaz matrisi: taşma yok', (tester) async {
      await DeviceMatrix.run(
        tester,
        (_) => const Align(
          alignment: Alignment.bottomCenter,
          child: TimePickerSheet(initial: _sixPm),
        ),
        safeAreas: true,
      );
    });

    testWidgets('golden: 18:00 seçili — açık + koyu (TR)', (tester) async {
      await _harness(
        (_) => const TimePickerSheet(initial: _sixPm),
      ).golden(tester, 'SHT-29');
    });
  });
}
