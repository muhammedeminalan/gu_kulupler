// T-11 · RelativeTimeFormatter: göreli zaman (7 eşik), gün etiketi, geri
// sayım, süre — TR ve EN; "şu an" FakeAppClock (PLAN §14.7; CD-106, CD-114).
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/format/relative_time_formatter.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../helpers/fake_app_clock.dart';

void main() {
  // Şu an: 12 Ekim 2026 Pazartesi 19:30 Istanbul.
  final now = DateTime.utc(2026, 10, 12, 16, 30);
  final clock = FakeAppClock(now);
  final trL10n = lookupAppLocalizations(const Locale('tr'));
  final enL10n = lookupAppLocalizations(const Locale('en'));
  final tr = RelativeTimeFormatter(trL10n, clock);
  final en = RelativeTimeFormatter(enL10n, clock);

  DateTime ago(Duration d) => now.subtract(d);
  DateTime ahead(Duration d) => now.add(d);

  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
  });

  setUp(() => clock.set(now));

  group('T-11 · RelativeTimeFormatter · format (7 eşik)', () {
    // (geçen süre, TR, EN)
    final rows = <(Duration, String, String)>[
      // 1) < 1 dk → "Az önce"
      (Duration.zero, trL10n.timeJustNow, enL10n.timeJustNow),
      (const Duration(seconds: 29), trL10n.timeJustNow, enL10n.timeJustNow),
      // 2) < 60 dk → "N dk önce"
      (
        const Duration(seconds: 30),
        trL10n.timeMinutesAgo(1),
        enL10n.timeMinutesAgo(1),
      ),
      (
        const Duration(minutes: 12),
        trL10n.timeMinutesAgo(12),
        enL10n.timeMinutesAgo(12),
      ),
      (
        const Duration(minutes: 59),
        trL10n.timeMinutesAgo(59),
        enL10n.timeMinutesAgo(59),
      ),
      // 3) < 24 sa → "N saat önce"
      (
        const Duration(minutes: 60),
        trL10n.timeHoursAgo(1),
        enL10n.timeHoursAgo(1),
      ),
      (
        const Duration(hours: 2),
        trL10n.timeHoursAgo(2),
        enL10n.timeHoursAgo(2),
      ),
      (
        const Duration(hours: 23),
        trL10n.timeHoursAgo(23),
        enL10n.timeHoursAgo(23),
      ),
      // 4) 1 gün → "Dün"
      (const Duration(hours: 24), trL10n.timeYesterday, enL10n.timeYesterday),
      (const Duration(hours: 35), trL10n.timeYesterday, enL10n.timeYesterday),
      // 5) < 7 gün → "N gün önce"
      (const Duration(hours: 36), trL10n.timeDaysAgo(2), enL10n.timeDaysAgo(2)),
      (const Duration(days: 6), trL10n.timeDaysAgo(6), enL10n.timeDaysAgo(6)),
      // 6) < 30 gün → "N hafta önce" (tam hafta)
      (const Duration(days: 7), trL10n.timeWeeksAgo(1), enL10n.timeWeeksAgo(1)),
      (
        const Duration(days: 13),
        trL10n.timeWeeksAgo(1),
        enL10n.timeWeeksAgo(1),
      ),
      (
        const Duration(days: 14),
        trL10n.timeWeeksAgo(2),
        enL10n.timeWeeksAgo(2),
      ),
      (
        const Duration(days: 29),
        trL10n.timeWeeksAgo(4),
        enL10n.timeWeeksAgo(4),
      ),
      // 7) ≥ 30 gün → kısa tarih
      (const Duration(days: 30), '12 Eyl', '12 Sept'),
      (const Duration(days: 400), '7 Eyl', '7 Sept'),
    ];

    for (final (elapsed, expectedTr, expectedEn) in rows) {
      test('$elapsed önce → "$expectedTr" / "$expectedEn"', () {
        expect(tr.format(ago(elapsed)), expectedTr);
        expect(en.format(ago(elapsed)), expectedEn);
      });
    }

    test('metinler beklenen biçimde (TR/EN örnekleri)', () {
      expect(tr.format(ago(const Duration(seconds: 5))), 'Az önce');
      expect(tr.format(ago(const Duration(minutes: 12))), '12 dk önce');
      expect(tr.format(ago(const Duration(hours: 2))), '2 saat önce');
      expect(tr.format(ago(const Duration(days: 1))), 'Dün');
      expect(tr.format(ago(const Duration(days: 3))), '3 gün önce');
      expect(tr.format(ago(const Duration(days: 14))), '2 hafta önce');
      expect(en.format(ago(const Duration(seconds: 5))), 'Just now');
      expect(en.format(ago(const Duration(minutes: 12))), '12 min ago');
      expect(en.format(ago(const Duration(hours: 1))), '1 hour ago');
      expect(en.format(ago(const Duration(hours: 2))), '2 hours ago');
      expect(en.format(ago(const Duration(days: 1))), 'Yesterday');
      expect(en.format(ago(const Duration(days: 14))), '2 weeks ago');
    });

    test('gelecekteki an "Az önce" sayılır (saat kayması)', () {
      expect(tr.format(ahead(const Duration(minutes: 5))), trL10n.timeJustNow);
    });

    test('yerel zamanlı girdi aynı sonucu verir', () {
      expect(
        tr.format(ago(const Duration(minutes: 12)).toLocal()),
        trL10n.timeMinutesAgo(12),
      );
    });

    test("saat ilerledikçe metin değişir (şu an AppClock'tan)", () {
      final posted = now;
      expect(tr.format(posted), trL10n.timeJustNow);
      clock.advance(const Duration(minutes: 3));
      expect(tr.format(posted), trL10n.timeMinutesAgo(3));
      clock.advance(const Duration(hours: 5));
      expect(tr.format(posted), trL10n.timeHoursAgo(5));
    });
  });

  group('T-11 · RelativeTimeFormatter · dayLabel / dayTime', () {
    test('bugün / yarın / dün', () {
      expect(tr.dayLabel(now), trL10n.timeToday);
      expect(tr.dayLabel(ahead(const Duration(days: 1))), trL10n.timeTomorrow);
      expect(tr.dayLabel(ago(const Duration(days: 1))), trL10n.timeYesterday);
      expect(en.dayLabel(now), enL10n.timeToday);
      expect(en.dayLabel(ahead(const Duration(days: 1))), enL10n.timeTomorrow);
    });

    test('diğer günler uzun tarih', () {
      expect(tr.dayLabel(ahead(const Duration(days: 2))), '14 Ekim Çarşamba');
      expect(tr.dayLabel(ago(const Duration(days: 2))), '10 Ekim Cumartesi');
      expect(
        en.dayLabel(ahead(const Duration(days: 2))),
        'Wednesday 14 October',
      );
    });

    test(
      'gün farkı Istanbul takvim gününe göredir (24 saat farkına değil)',
      () {
        // Şu an Pzt 19:30. Sal 00:30 Istanbul (4,5 saat sonra) → "Yarın".
        expect(
          tr.dayLabel(DateTime.utc(2026, 10, 12, 21, 30)),
          trL10n.timeTomorrow,
        );
        // Pzt 00:05 Istanbul (19 saat önce, UTC'de Pazar) → "Bugün".
        expect(
          tr.dayLabel(DateTime.utc(2026, 10, 11, 21, 5)),
          trL10n.timeToday,
        );
        // Paz 23:55 Istanbul → "Dün".
        expect(
          tr.dayLabel(DateTime.utc(2026, 10, 11, 20, 55)),
          trL10n.timeYesterday,
        );
      },
    );

    test('dayTime: gün etiketi + saat (K-14)', () {
      expect(tr.dayTime(now), 'Bugün 19:30');
      expect(tr.dayTime(ahead(const Duration(days: 1))), 'Yarın 19:30');
      expect(en.dayTime(now), 'Today 19:30');
      expect(
        tr.dayTime(ahead(const Duration(days: 2))),
        '14 Ekim Çarşamba 19:30',
      );
    });
  });

  group('T-11 · RelativeTimeFormatter · countdown', () {
    test('kalan gün yukarı yuvarlanır', () {
      expect(
        tr.countdown(ahead(const Duration(hours: 1))),
        trL10n.timeInDays(1),
      );
      expect(
        tr.countdown(ahead(const Duration(days: 1))),
        trL10n.timeInDays(1),
      );
      expect(
        tr.countdown(ahead(const Duration(days: 2, minutes: 1))),
        trL10n.timeInDays(3),
      );
      expect(
        en.countdown(ahead(const Duration(days: 7))),
        enL10n.timeInDays(7),
      );
    });

    test('hedef şimdi ya da geçmişte → 0 ("bugün" dalı)', () {
      expect(tr.countdown(now), trL10n.timeInDays(0));
      expect(tr.countdown(ago(const Duration(days: 3))), trL10n.timeInDays(0));
      expect(tr.countdown(now), 'bugün');
    });

    test('metin örnekleri', () {
      expect(tr.countdown(ahead(const Duration(days: 3))), '3 gün');
      expect(en.countdown(ahead(const Duration(days: 1))), '1 day');
      expect(en.countdown(ahead(const Duration(days: 3))), '3 days');
    });
  });

  group('T-11 · RelativeTimeFormatter · duration', () {
    String trOf(int minutes) =>
        tr.duration(now, ahead(Duration(minutes: minutes)));
    String enOf(int minutes) =>
        en.duration(now, ahead(Duration(minutes: minutes)));

    test('60 dakikadan kısa → dakika', () {
      expect(trOf(45), '45 dk');
      expect(trOf(59), '59 dk');
      expect(enOf(45), '45 min');
    });

    test('60 dakika ve üzeri → saat; tam saat ondalıksız', () {
      expect(trOf(60), '1 sa');
      expect(trOf(120), '2 sa');
      expect(enOf(60), '1 h');
    });

    test('ondalıklı saat tek basamağa yuvarlanır', () {
      expect(trOf(90), '1.5 sa');
      expect(enOf(90), '1.5 h');
      expect(trOf(100), '1.7 sa');
      expect(trOf(63), '1.1 sa');
      expect(trOf(62), '1 sa');
    });

    test('saniyeler dakikaya yuvarlanır', () {
      expect(
        tr.duration(now, ahead(const Duration(minutes: 44, seconds: 40))),
        '45 dk',
      );
    });
  });
}
