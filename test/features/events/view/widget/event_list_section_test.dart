// EventListSection.groupsOf — EVT-01 gün grupları (Bugün / Yarın / Bu hafta /
// Daha sonra / Geçmiş): İstanbul günü, yarı açık aralıklar, gruplar çakışmaz
// (prototipte yarınki etkinlik "Bu hafta"ya da düşüyordu), boş grup yok, grup
// içi sıra korunur.
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/events/view/widget/event_list_section.dart';

import '../../../../fixtures/event_model_fixtures.dart';
import '../../../../helpers/fake_app_clock.dart';

void main() {
  // 8 Ekim 2026 15:00 İstanbul; gün başı 7 Ekim 21:00 UTC.
  final clock = FakeAppClock(DateTime.utc(2026, 10, 8, 12));
  final base = EventModelFixtures.e01;

  EventModel at(String id, DateTime startsAt) => base.copyWith(
    id: id,
    startsAt: startsAt,
    endsAt: startsAt.add(const Duration(hours: 1)),
  );

  test('sınırlar İstanbul gününe göre; gruplar çakışmaz, boş grup düşer', () {
    final events = [
      at('past', DateTime.utc(2026, 10, 7, 20, 59)),
      at('today0', DateTime.utc(2026, 10, 7, 21)),
      at('today1', DateTime.utc(2026, 10, 8, 20, 59)),
      at('tomorrow', DateTime.utc(2026, 10, 9, 15)),
      at('week0', DateTime.utc(2026, 10, 9, 21)),
      at('week1', DateTime.utc(2026, 10, 14, 20, 59)),
      at('later', DateTime.utc(2026, 10, 14, 21)),
    ];
    final groups = EventListSection.groupsOf(events, clock: clock);
    expect(
      [
        for (final (group, list) in groups)
          '${group.name}: ${[for (final e in list) e.id].join(',')}',
      ],
      [
        'today: today0,today1',
        'tomorrow: tomorrow',
        'week: week0,week1',
        'later: later',
        'past: past',
      ],
    );

    expect(
      EventListSection.groupsOf([events[3]], clock: clock).single.$1,
      EventListGroup.tomorrow,
    );
    expect(EventListSection.groupsOf(const [], clock: clock), isEmpty);
  });
}
