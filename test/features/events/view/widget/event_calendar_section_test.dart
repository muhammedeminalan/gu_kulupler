// EVT-01 · takvim kipi (`EventCalendarSection`) — TR Pazartesi / EN Pazar
// başlangıcı, Istanbul gün sınırı (nokta + gün listesi), ay geçişi, "Bugün",
// gün seçimi, boş gün, anahtarlar, cihaz matrisi, açık + koyu golden.
// Referans: prototip screens-events.js:31–32, ui.js:140–150.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/events/view/widget/event_calendar_section.dart';
import 'package:gu_kulupler/product/widget/event/event_card.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../../fixtures/club_model_fixtures.dart';
import '../../../../fixtures/event_model_fixtures.dart';
import '../../../../helpers/device_matrix.dart';
import '../../../../helpers/golden_helper.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_l10n.dart';

/// Varsayılan sahte saat 2026-10-12 16:30Z = Istanbul 12 Ekim Pzt 19:30.
final DateTime _today = DateTime(2026, 10, 12);

EventModel _event(String id, DateTime startsAtUtc) =>
    EventModelFixtures.e01.copyWith(
      id: id,
      startsAt: startsAtUtc,
      endsAt: startsAtUtc.add(const Duration(hours: 2)),
    );

/// `n1` 13 Eki 21:30Z = Istanbul **14 Eki** 00:30 · `n2` 14 Eki 20:59Z =
/// 14 Eki 23:59 · `n3` 14 Eki 21:00Z = **15 Eki** 00:00 · `n4` bugün.
final List<EventModel> _events = [
  _event('n2', DateTime.utc(2026, 10, 14, 20, 59)),
  _event('n1', DateTime.utc(2026, 10, 13, 21, 30)),
  _event('n3', DateTime.utc(2026, 10, 14, 21)),
  _event('n4', DateTime.utc(2026, 10, 12, 15)),
];

Key _key(String action) => GuKey.action('EVT-01.$action');

/// Ayı ve seçili günü tutan çağıran (EVT-01 ekranının yerine).
class _Host extends StatefulWidget {
  const _Host({required this.month, required this.selected, this.cards});

  final DateTime month;
  final DateTime selected;
  final Widget Function(BuildContext, EventModel)? cards;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late DateTime month = widget.month;
  late DateTime selected = widget.selected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: EventCalendarSection(
      events: _events,
      month: month,
      selectedDay: selected,
      today: _today,
      onSelectDay: (day) => setState(() => selected = day),
      onMonthChanged: (value) => setState(() => month = value),
      cardBuilder:
          widget.cards ??
          (_, event) => Text(event.id, key: ValueKey<String>('c.${event.id}')),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  DateTime? month,
  DateTime? selected,
  Locale locale = const Locale('tr'),
}) async {
  await tester.pumpApp(
    Scaffold(
      body: _Host(month: month ?? _today, selected: selected ?? _today),
    ),
    locale: locale,
  );
  await tester.pump(GuMotion.base);
}

GuCalendar _calendar(WidgetTester tester) =>
    tester.widget<GuCalendar>(find.byType(GuCalendar));

void main() {
  group('EVT-01 · takvim · hafta başlangıcı', () {
    testWidgets('TR Pazartesi başlar: başlık Pz…Pa, ilk hücre 28 Eyl (Pzt)', (
      tester,
    ) async {
      await _pump(tester);
      final calendar = _calendar(tester);
      expect(calendar.firstDayOfWeek, DateTime.monday);
      expect(calendar.weekdayLabels, [
        'Pz',
        'Sa',
        'Ça',
        'Pe',
        'Cu',
        'Cm',
        'Pa',
      ]);
      expect(find.text('Ekim 2026'), findsOneWidget);
      final first = tester.getTopLeft(find.byKey(_key('day.2026-09-28')));
      final second = tester.getTopLeft(find.byKey(_key('day.2026-09-29')));
      expect(first.dy, second.dy);
      expect(first.dx, lessThan(second.dx));
      expect(find.byKey(_key('day.2026-09-27')), findsNothing);
    });

    testWidgets('EN Pazar başlar: başlık Su…Sa, ilk hücre 27 Sep (Sun)', (
      tester,
    ) async {
      await _pump(tester, locale: const Locale('en'));
      final calendar = _calendar(tester);
      expect(calendar.firstDayOfWeek, DateTime.sunday);
      expect(calendar.weekdayLabels, [
        'Su',
        'Mo',
        'Tu',
        'We',
        'Th',
        'Fr',
        'Sa',
      ]);
      expect(find.text('October 2026'), findsOneWidget);
      final sunday = tester.getTopLeft(find.byKey(_key('day.2026-09-27')));
      final monday = tester.getTopLeft(find.byKey(_key('day.2026-09-28')));
      expect(sunday.dy, monday.dy);
      expect(sunday.dx, lessThan(monday.dx));
    });
  });

  group('EVT-01 · takvim · Istanbul gün sınırı', () {
    test('nokta sayısı başlangıcın Istanbul günüdür', () {
      expect(EventCalendarSection.countsByDay(_events), {
        '2026-10-14': 2,
        '2026-10-15': 1,
        '2026-10-12': 1,
      });
    });

    testWidgets('GuCalendar noktaları: 13 Eki 0, 14 Eki 2, 15 Eki 1', (
      tester,
    ) async {
      await _pump(tester);
      final dots = _calendar(tester).dotsFor!;
      expect(dots(DateTime(2026, 10, 13)), 0);
      expect(dots(DateTime(2026, 10, 14)), 2);
      expect(dots(DateTime(2026, 10, 15)), 1);
    });

    testWidgets('14 Eki listesi n1, n2 (başlangıç sırası); 15 Eki n3', (
      tester,
    ) async {
      await _pump(tester, selected: DateTime(2026, 10, 14));
      expect(find.text('14 Ekim Çarşamba'), findsOneWidget);
      expect(find.byKey(const ValueKey('c.n3')), findsNothing);
      final n1 = tester.getTopLeft(find.byKey(const ValueKey('c.n1')));
      final n2 = tester.getTopLeft(find.byKey(const ValueKey('c.n2')));
      expect(n1.dy, lessThan(n2.dy));

      await tester.tap(find.byKey(_key('day.2026-10-15')));
      await tester.pump(GuMotion.base);
      expect(find.text('15 Ekim Perşembe'), findsOneWidget);
      expect(find.byKey(const ValueKey('c.n3')), findsOneWidget);
      expect(find.byKey(const ValueKey('c.n1')), findsNothing);
    });
  });

  group('EVT-01 · takvim · aksiyonlar', () {
    testWidgets('ay ileri / geri; diğer aydan gün seçmek ayı değiştirmez', (
      tester,
    ) async {
      await _pump(tester);
      await tester.tap(find.byKey(_key('nextMonth')));
      await tester.pump(GuMotion.base);
      expect(find.text('Kasım 2026'), findsOneWidget);
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byKey(_key('prevMonth')));
        await tester.pump(GuMotion.base);
      }
      expect(find.text('Eylül 2026'), findsOneWidget);

      await tester.tap(find.byKey(_key('day.2026-10-01')));
      await tester.pump(GuMotion.base);
      expect(find.text('Eylül 2026'), findsOneWidget);
      expect(find.text('1 Ekim Perşembe'), findsOneWidget);
    });

    testWidgets('"Bugün" ayı ve seçimi bugüne alır; bugün listesi n4', (
      tester,
    ) async {
      await _pump(
        tester,
        month: DateTime(2026, 12),
        selected: DateTime(2026, 12, 5),
      );
      expect(find.text(tester.l10n.eventsEmptyDay), findsOneWidget);
      await tester.tap(find.byKey(_key('today')));
      await tester.pump(GuMotion.base);
      expect(find.text('Ekim 2026'), findsOneWidget);
      expect(find.text(tester.l10n.timeToday), findsWidgets);
      expect(find.byKey(const ValueKey('c.n4')), findsOneWidget);
      expect(_calendar(tester).selected, _today);
    });

    testWidgets('boş gün: "Bu gün için etkinlik yok"', (tester) async {
      await _pump(tester, selected: DateTime(2026, 10, 20));
      expect(find.text(tester.l10n.eventsEmptyDay), findsOneWidget);
      expect(find.byType(GuEmptyState), findsOneWidget);
    });
  });

  group('EVT-01 · takvim · cihaz matrisi ve golden', () {
    testWidgets('cihaz matrisi: taşma yok', (tester) async {
      await DeviceMatrix.run(
        tester,
        (_) => Scaffold(
          body: _Host(month: _today, selected: DateTime(2026, 10, 14)),
        ),
      );
    });

    testWidgets('golden: 14 Eki seçili, iki sıkışık kart — açık + koyu (TR)', (
      tester,
    ) async {
      await goldenForThemes(
        tester,
        'EVT-01__calendar',
        Scaffold(
          body: _Host(
            month: _today,
            selected: DateTime(2026, 10, 14),
            cards: (_, event) => EventCard(
              event: event,
              club: ClubModelFixtures.c01,
              status: null,
              registeredCount: event.goingCount,
              compact: true,
              onOpen: () {},
            ),
          ),
        ),
      );
    });
  });
}
