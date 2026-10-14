// T-24 · EventFilterState: SHT-11 süzgeç değer nesnesi (CD-108; prototip
// `applyEventFilters` / `efCount`, `screens-events.js:5–14`).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/events/provider/event_filter_state.dart';

import '../../../fixtures/event_model_fixtures.dart';
import '../../../helpers/fake_app_clock.dart';

/// Şu an: 14 Ekim 2026 Çarşamba 10:00 Istanbul (07:00 UTC).
final FakeAppClock _clock = FakeAppClock(DateTime.utc(2026, 10, 14, 7));

/// Istanbul duvar saati → UTC an (UTC+3 sabit).
DateTime _ist(int month, int day, [int hour = 12]) =>
    DateTime.utc(2026, month, day, hour).subtract(const Duration(hours: 3));

EventModel _event(
  String id,
  DateTime startsAt, {
  String clubId = 'c01',
  EventType type = EventType.social,
  EventVisibility visibility = EventVisibility.public,
  int goingCount = 0,
  int capacity = 50,
}) => EventModelFixtures.e01.copyWith(
  id: id,
  clubId: clubId,
  type: type,
  visibility: visibility,
  startsAt: startsAt,
  endsAt: startsAt.add(const Duration(hours: 2)),
  goingCount: goingCount,
  waitlistCount: 0,
  capacity: capacity,
);

void main() {
  // Bugün 00:30 · bugün 23:30 · yarın · +6 gün · +7 gün · +29 gün · +30 gün.
  final today0030 = _event(
    'a',
    _ist(10, 14, 0).add(const Duration(minutes: 30)),
  );
  final today2330 = _event(
    'b',
    _ist(10, 14, 23).add(const Duration(minutes: 30)),
  );
  final tomorrow = _event('c', _ist(10, 15), goingCount: 9, capacity: 9);
  final plus6 = _event('d', _ist(10, 20), clubId: 'c02', goingCount: 30);
  final plus7 = _event('e', _ist(10, 21), type: EventType.trip);
  final plus29 = _event(
    'f',
    _ist(11, 12),
    visibility: EventVisibility.membersOnly,
  );
  final plus30 = _event('g', _ist(11, 13), goingCount: 30);
  final all = [plus30, plus7, today2330, plus29, tomorrow, plus6, today0030];

  List<String> ids(EventFilterState f, [Iterable<EventModel>? events]) => [
    for (final e in f.apply(events ?? all, clock: _clock)) e.id,
  ];

  group('T-24 · EventFilterState', () {
    test('varsayılan: süzme yok, sayaç 0, tarihe göre artan', () {
      const f = EventFilterState.none;
      expect(f.props, const [
        EventDatePreset.all,
        null,
        null,
        <String>{},
        <EventType>{},
        EventVisibilityFilter.all,
        false,
        EventSort.date,
      ]);
      expect(f.activeCount, 0);
      expect(ids(f), ['a', 'b', 'c', 'd', 'e', 'f', 'g']);
    });

    test('tarih çipleri Istanbul gününe göre yarı açık aralıktır', () {
      expect(ids(const EventFilterState(datePreset: EventDatePreset.today)), [
        'a',
        'b',
      ]);
      expect(ids(const EventFilterState(datePreset: EventDatePreset.week)), [
        'a',
        'b',
        'c',
        'd',
      ]);
      expect(ids(const EventFilterState(datePreset: EventDatePreset.month)), [
        'a',
        'b',
        'c',
        'd',
        'e',
        'f',
      ]);
    });

    test('özel aralık: iki uç gün dahil; bitişsiz → üst sınır yok', () {
      final range = EventFilterState.none.withCustomRange(
        from: DateTime(2026, 10, 15),
        to: DateTime(2026, 10, 21),
      );
      expect(range.datePreset, EventDatePreset.custom);
      expect(ids(range), ['c', 'd', 'e']);
      final open = EventFilterState.none.withCustomRange(
        from: DateTime(2026, 11, 12),
      );
      expect(ids(open), ['f', 'g']);
      // Başka çip özel aralığı siler.
      final back = range.withDatePreset(EventDatePreset.week);
      expect(back.from, isNull);
      expect(back.to, isNull);
      expect(back, const EventFilterState(datePreset: EventDatePreset.week));
    });

    test('kulüp / tür / görünürlük / boş kontenjan süzgeçleri', () {
      expect(ids(const EventFilterState(clubIds: {'c02'})), ['d']);
      expect(ids(const EventFilterState(types: {EventType.trip})), ['e']);
      expect(
        ids(const EventFilterState(visibility: EventVisibilityFilter.members)),
        ['f'],
      );
      expect(
        ids(const EventFilterState(visibility: EventVisibilityFilter.public)),
        isNot(contains('f')),
      );
      expect(ids(const EventFilterState(freeOnly: true)), isNot(contains('c')));
    });

    test('popüler: kayıtlı sayısı çoktan aza, eşitlikte girdi sırası', () {
      expect(ids(const EventFilterState(sort: EventSort.popular)).take(3), [
        'g',
        'd',
        'c',
      ]);
    });

    test('activeCount: her alan bir kez sayılır', () {
      final f = const EventFilterState(
        clubIds: {'c01', 'c02'},
        types: {EventType.trip, EventType.social},
        visibility: EventVisibilityFilter.public,
        freeOnly: true,
        sort: EventSort.popular,
      ).withCustomRange(from: DateTime(2026, 10, 15));
      expect(f.activeCount, 6);
    });

    test('copyWith tüm alanları taşır; props eşitliği', () {
      final f = EventFilterState.none.copyWith(
        datePreset: EventDatePreset.custom,
        from: DateTime(2026, 10, 15),
        to: DateTime(2026, 10, 16),
        clubIds: {'c01'},
        types: {EventType.trip},
        visibility: EventVisibilityFilter.members,
        freeOnly: true,
        sort: EventSort.popular,
      );
      expect(f.copyWith(), f);
      expect(f.props, hasLength(8));
      expect(f.to, DateTime(2026, 10, 16));
      expect(f, isNot(EventFilterState.none));
    });
  });
}
