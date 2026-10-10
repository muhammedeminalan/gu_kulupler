// T-11 · AppDateFormats: PLAN §14.7 biçim tablosu, TR (`tr_TR`) ve EN
// (`en_GB`); Istanbul duvar saati (D-26, CD-56, CD-101, CD-114).
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../helpers/fake_app_clock.dart';

void main() {
  // Örnek an: 12 Ekim 2026 Pazartesi 19:30 Istanbul = 16:30 UTC.
  final instant = DateTime.utc(2026, 10, 12, 16, 30);
  final clock = FakeAppClock(instant);
  const trLocale = Locale('tr');
  const enLocale = Locale('en');
  final tr = AppDateFormats(trLocale, clock);
  final en = AppDateFormats(enLocale, clock);
  final trL10n = lookupAppLocalizations(trLocale);
  final enL10n = lookupAppLocalizations(enLocale);

  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
  });

  group('T-11 · AppDateFormats · yerel ayar ve saat dilimi', () {
    test('intlLocale: tr → tr_TR, en → en_GB; bilinmeyen dil varsayılana '
        '(tr_TR) düşer', () {
      expect(AppDateFormats.intlLocale(trLocale), 'tr_TR');
      expect(AppDateFormats.intlLocale(enLocale), 'en_GB');
      expect(AppDateFormats.intlLocale(const Locale('en', 'US')), 'en_GB');
      expect(AppDateFormats.intlLocale(const Locale('de')), 'tr_TR');
    });

    test('toIstanbul: UTC+3 sabit kayma (DST yok); yerel zamanlı girdi '
        "önce UTC'ye çevrilir", () {
      expect(
        AppDateFormats.toIstanbul(instant),
        DateTime.utc(2026, 10, 12, 19, 30),
      );
      // Yaz ortası da +3.
      expect(
        AppDateFormats.toIstanbul(DateTime.utc(2026, 7, 1, 21)),
        DateTime.utc(2026, 7, 2),
      );
      expect(
        AppDateFormats.toIstanbul(instant.toLocal()),
        DateTime.utc(2026, 10, 12, 19, 30),
      );
    });

    test("gün sınırı Istanbul'a göredir: 21:30 UTC ertesi gündür", () {
      final lateUtc = DateTime.utc(2026, 10, 12, 21, 30);
      expect(tr.time(lateUtc), '00:30');
      expect(tr.dateShort(lateUtc), '13 Eki');
      expect(tr.weekdayShort(lateUtc), 'Sal');
    });
  });

  group('T-11 · AppDateFormats · biçim tablosu (TR)', () {
    test('time', () => expect(tr.time(instant), '19:30'));
    test('dateShort', () => expect(tr.dateShort(instant), '12 Eki'));
    test('date', () => expect(tr.date(instant), '12 Ekim 2026'));
    test('dateLong', () => expect(tr.dateLong(instant), '12 Ekim Pazartesi'));
    test(
      'dateTime',
      () => expect(tr.dateTime(trL10n, instant), '12 Eki Pzt, 19:30'),
    );
    test('monthYear', () => expect(tr.monthYear(instant), 'Ekim 2026'));
    test('monthShort', () => expect(tr.monthShort(instant), 'Eki'));
    test('weekdayShort', () => expect(tr.weekdayShort(instant), 'Pzt'));
    test("weekdayInitials Pazartesi'den başlar", () {
      expect(AppDateFormats.weekdayInitials(trLocale), [
        'Pz',
        'Sa',
        'Ça',
        'Pe',
        'Cu',
        'Cm',
        'Pa',
      ]);
    });
    test('number', () {
      expect(tr.number(1250), '1.250');
      expect(tr.number(0), '0');
      expect(tr.number(999), '999');
    });
    test('percent (CD-101): işaret önde', () {
      expect(tr.percent(62), '%62');
      expect(tr.percent(0), '%0');
      expect(tr.percent(100), '%100');
      expect(tr.percent(41.6), '%42');
    });
    test('twoDigits', () {
      expect(tr.twoDigits(7), '07');
      expect(tr.twoDigits(23), '23');
      expect(tr.twoDigits(0), '00');
    });
  });

  group('T-11 · AppDateFormats · biçim tablosu (EN, en_GB)', () {
    test('time 24 saat', () => expect(en.time(instant), '19:30'));
    test('dateShort', () => expect(en.dateShort(instant), '12 Oct'));
    test('date', () => expect(en.date(instant), '12 October 2026'));
    test('dateLong', () => expect(en.dateLong(instant), 'Monday 12 October'));
    test(
      'dateTime',
      () => expect(en.dateTime(enL10n, instant), 'Mon 12 Oct, 19:30'),
    );
    test('monthYear', () => expect(en.monthYear(instant), 'October 2026'));
    test('monthShort', () => expect(en.monthShort(instant), 'Oct'));
    test('weekdayShort', () => expect(en.weekdayShort(instant), 'Mon'));
    test("weekdayInitials Pazartesi'den başlar", () {
      expect(AppDateFormats.weekdayInitials(enLocale), [
        'Mo',
        'Tu',
        'We',
        'Th',
        'Fr',
        'Sa',
        'Su',
      ]);
    });
    test('number', () => expect(en.number(1250), '1,250'));
    test('percent (CD-101): işaret sonda', () {
      expect(en.percent(62), '62%');
      expect(en.percent(0), '0%');
      expect(en.percent(100), '100%');
    });
    test('twoDigits', () => expect(en.twoDigits(7), '07'));
  });

  group('T-11 · AppDateFormats · range', () {
    final end = DateTime.utc(2026, 10, 12, 18); // 21:00 Istanbul
    final nextDay = DateTime.utc(2026, 10, 13, 7); // 13 Eki Sal 10:00

    test('bitiş yoksa yalnızca başlangıç saati', () {
      expect(tr.range(trL10n, instant, null), '19:30');
    });

    test('aynı gün: saat aralığı (U+2013)', () {
      expect(tr.range(trL10n, instant, end), '19:30–21:00');
      expect(en.range(enL10n, instant, end), '19:30–21:00');
    });

    test('farklı gün: tarih-saat → tarih-saat', () {
      expect(
        tr.range(trL10n, instant, nextDay),
        '12 Eki Pzt, 19:30 → 13 Eki Sal, 10:00',
      );
      expect(
        en.range(enL10n, instant, nextDay),
        'Mon 12 Oct, 19:30 → Tue 13 Oct, 10:00',
      );
    });

    test("aynı gün denetimi Istanbul gününe göredir: UTC'de aynı gün olan "
        '20:00 ve 22:00 UTC farklı Istanbul günleridir', () {
      final a = DateTime.utc(2026, 10, 12, 20); // 23:00 Pzt
      final b = DateTime.utc(2026, 10, 12, 22); // 01:00 Sal
      expect(
        tr.range(trL10n, a, b),
        '12 Eki Pzt, 23:00 → 13 Eki Sal, 01:00',
      );
      // UTC'de farklı gün, Istanbul'da aynı gün: 21:30 UTC ve 23:00 UTC.
      final c = DateTime.utc(2026, 10, 12, 21, 30); // 00:30 Sal
      final d = DateTime.utc(2026, 10, 12, 23); // 02:00 Sal
      expect(tr.range(trL10n, c, d), '00:30–02:00');
    });
  });
}
