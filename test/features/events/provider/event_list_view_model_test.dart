// EVT-01 · EventListViewModel: istemci birleştirme (herkese açık + etkin üye
// olunan kulüp başına üyelere özel sorgu; tekilleştirme, askıdaki kulüp,
// `startsAt ↑`), katılım kayıtları, hata dalları (ilk okuma / çek-yenile /
// üye sorgusu / kayıtlar), süzgeç + çip + liste ↔ takvim, SHT-11 sayısı,
// TST-X2 (PLAN §12.6).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/events/provider/event_filter_state.dart';
import 'package:gu_kulupler/features/events/provider/event_list_state.dart';
import 'package:gu_kulupler/features/events/provider/event_list_view_model.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';

import '../../../fakes/fake_club_repository.dart';
import '../../../fakes/fake_event_repository.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_rsvp_repository.dart';
import '../../../fakes/register_fakes.dart';
import '../../../fixtures/event_model_fixtures.dart';
import '../../../helpers/test_container.dart';
import '../event_list_test_support.dart';

void main() {
  late FakeEventRepository events;
  late FakeClubRepository clubs;
  late FakeRsvpRepository rsvps;

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    events = GetIt.I<EventRepository>() as FakeEventRepository;
    clubs = GetIt.I<ClubRepository>() as FakeClubRepository;
    rsvps = GetIt.I<RsvpRepository>() as FakeRsvpRepository;
    seedEventList(rsvps: kMyRsvps);
  });

  ProviderContainer containerOf(SessionState session) {
    final container = createContainer(
      overrides: [
        sessionViewModelProvider.overrideWithBuild((ref, notifier) => session),
      ],
    );
    addTearDown(container.listen(eventListViewModelProvider, (_, _) {}).close);
    return container;
  }

  Future<ProviderContainer> loaded(SessionState session) async {
    final container = containerOf(session);
    await pumpEventQueue();
    return container;
  }

  EventListState stateOf(ProviderContainer c) =>
      c.read(eventListViewModelProvider);

  EventListViewModel vmOf(ProviderContainer c) =>
      c.read(eventListViewModelProvider.notifier);

  List<String> ids(Iterable<EventModel> list) => [for (final e in list) e.id];

  AppClock clock() => GetIt.I<AppClock>();

  group('EVT-01 · birleştirme', () {
    test('ilk durum iskelet + bugünün takvim günü; okuma eşzamanlı başlar', () {
      final c = containerOf(kVisitorSession);
      final state = stateOf(c);
      expect(state.isFetching, isTrue);
      expect(state.selectedDay, DateTime(2026, 10, 8));
      expect(state.calendarMonth, DateTime(2026, 10));
    });

    test('ziyaretçi: yalnızca herkese açık sorgu; askıdaki kulüp yok, '
        'başlangıca göre artan; kayıtlar okunur', () async {
      final c = await loaded(kVisitorSession);
      final state = stateOf(c);
      expect(state.isFetching, isFalse);
      expect(state.isError, isFalse);
      expect(events.membersUpcomingQueries, isEmpty);
      final from = events.callsTo('listPublicUpcoming').single.args.single;
      // Alt sınır bugünün İstanbul başlangıcı (7 Ekim 21:00 UTC).
      expect(from, DateTime.utc(2026, 10, 7, 21));
      expect(ids(state.upcomingAt(kNowUtc)), kVisitorCardIds);
      expect(state.clubs.any((club) => club.isSuspended), isFalse);
      expect(state.rsvps.keys, containsAll(<String>['e01', 'e08']));
      expect(rsvps.callsTo('listMine').single.args, [kUid]);
    });

    test('üye: etkin üyelik başına bir üyelere özel sorgu (bekleyen / '
        'reddedilen yok); sonuç tekil ve sıralı', () async {
      final c = await loaded(kMemberSession);
      final state = stateOf(c);
      expect(events.membersUpcomingQueries.toSet(), {'c01', 'c07'});
      final all = ids(state.events);
      expect(all.toSet().length, all.length);
      expect(all, contains('e02'));
      expect(all, isNot(contains('e22'))); // taslak
      final starts = [for (final e in state.events) e.startsAt];
      expect(starts, [...starts]..sort());
    });

    test('mergeEvents: aynı kimlik bir kez, yalnızca verilen kulüpler, '
        'başarısız sorgu atlanır', () {
      final e01 = EventModelFixtures.e01;
      final e03 = EventModelFixtures.e03;
      final merged = EventListViewModel.mergeEvents(
        clubIds: {e01.clubId},
        results: [
          FirebaseSuccess([e01, e03]),
          FirebaseSuccess([e01]),
          const FirebaseFailure(FirestoreError.permissionDenied),
        ],
      );
      expect(ids(merged), ['e01']);
    });
  });

  group('EVT-01 · hata dalları', () {
    test('herkese açık sorgu okunamazsa hata; "Yeniden dene" yükler', () async {
      events.failNext(FirestoreError.unavailable);
      final c = await loaded(kVisitorSession);
      expect(stateOf(c).isError, isTrue);
      expect(stateOf(c).isFetching, isFalse);

      await vmOf(c).fetch();
      expect(stateOf(c).isError, isFalse);
      expect(ids(stateOf(c).upcomingAt(kNowUtc)), kVisitorCardIds);
    });

    test('kulüpler okunamazsa hata', () async {
      clubs.failNext(FirestoreError.unavailable);
      final c = await loaded(kVisitorSession);
      expect(stateOf(c).isError, isTrue);
    });

    test('üye sorgusu okunamazsa o kulüp atlanır, liste gelir', () async {
      // Geçersiz kulüp kimliği → fake `invalidArgument` döner.
      final membership = kMemberSession.memberships['c01']!;
      final c = await loaded(
        kVisitorSession.copyWith(
          memberships: {'c01': membership, 'bad/id': membership},
        ),
      );
      expect(events.callsTo('listMembersUpcoming'), hasLength(2));
      expect(stateOf(c).isError, isFalse);
      expect(ids(stateOf(c).events), contains('e02'));
    });

    test('kayıtlar okunamazsa kartlar durumsuz, liste gelir', () async {
      rsvps.failNext(FirestoreError.unavailable);
      final c = await loaded(kVisitorSession);
      expect(stateOf(c).isError, isFalse);
      expect(stateOf(c).rsvps, isEmpty);
      expect(stateOf(c).events, isNotEmpty);
    });

    test('çek-yenile okunamazsa içerik kalır', () async {
      final c = await loaded(kVisitorSession);
      final before = stateOf(c).events;
      events.failNext(FirestoreError.unavailable);
      await vmOf(c).refresh();
      expect(stateOf(c).isError, isFalse);
      expect(stateOf(c).isRefreshing, isFalse);
      expect(stateOf(c).events, before);
    });
  });

  group('T-44 · EVT-01 · karttan katılım sonrası (D3-04)', () {
    test('onRsvpChanged yalnızca o etkinliği ve kaydı okur; kulüpler, '
        'yaklaşanlar ve katılım geçmişi yeniden okunmaz', () async {
      final c = await loaded(kMemberSession);
      final before = stateOf(c);
      final target = before.events.firstWhere(
        (e) => !before.rsvps.containsKey(e.id),
      );
      final other = before.events.firstWhere((e) => e.id != target.id);
      events.put(target.copyWith(goingCount: target.goingCount + 1));
      final mine = RsvpModel(
        eventId: target.id,
        clubId: target.clubId,
        userId: kUid,
        ticketCode: 'GU-ABCD-2345',
      );
      rsvps.put(mine);
      for (final fake in [events, clubs, rsvps]) {
        fake.calls.clear();
      }

      await vmOf(c).onRsvpChanged(target.id);

      expect(clubs.callsTo('fetchActiveClubs'), isEmpty);
      expect(events.callsTo('listPublicUpcoming'), isEmpty);
      expect(events.callsTo('listMembersUpcoming'), isEmpty);
      expect(rsvps.callsTo('listMine'), isEmpty);
      expect(events.callsTo('getEvent').single.args, [target.id]);
      expect(rsvps.callsTo('getMine'), hasLength(1));
      final after = stateOf(c);
      expect(
        after.events.firstWhere((e) => e.id == target.id).goingCount,
        target.goingCount + 1,
      );
      expect(after.events.firstWhere((e) => e.id == other.id), other);
      expect(after.rsvps[target.id], mine);
      expect(after.isRefreshing, isFalse);
    });

    test('etkinlik okunamazsa tam yenilemeye düşer', () async {
      final c = await loaded(kMemberSession);
      final target = stateOf(c).events.first;
      for (final fake in [events, clubs, rsvps]) {
        fake.calls.clear();
      }
      events.failNext(FirestoreError.unavailable);

      await vmOf(c).onRsvpChanged(target.id);

      expect(clubs.callsTo('fetchActiveClubs'), hasLength(1));
      expect(events.callsTo('listPublicUpcoming'), hasLength(1));
      expect(stateOf(c).isError, isFalse);
    });
  });

  group('EVT-01 · süzgeç, çip, kip', () {
    test('çipler: bugün / bu hafta / kulüplerim / herkese açık', () async {
      final c = await loaded(kMemberSession);
      final vm = vmOf(c)..setChip(EventListChip.today);
      expect(ids(stateOf(c).visibleAt(clock())), ['e17']);

      vm.setChip(EventListChip.week);
      expect(ids(stateOf(c).visibleAt(clock())), [
        'e17', 'e01', 'e04', 'e02', 'e06', 'e03', 'e21', 'e07', //
      ]);

      vm.setChip(EventListChip.mine);
      expect(
        stateOf(c).visibleAt(clock()).map((e) => e.clubId).toSet(),
        {'c01', 'c07'},
      );

      vm.setChip(EventListChip.public);
      expect(
        stateOf(c).visibleAt(clock()).map((e) => e.visibility).toSet(),
        {EventVisibility.public},
      );
      expect(stateOf(c).hasActiveFilter, isTrue);
    });

    test('süzgeç (tür + popüler) çipin altında; sayı çipsiz; temizle ikisini '
        'de sıfırlar', () async {
      final c = await loaded(kVisitorSession);
      final vm = vmOf(c);
      const filter = EventFilterState(
        types: {EventType.trip},
        sort: EventSort.popular,
      );
      vm.setFilter(filter);
      final visible = stateOf(c).visibleAt(clock());
      expect(visible.map((e) => e.type).toSet(), {EventType.trip});
      final going = [for (final e in visible) e.goingCount];
      expect(going, [...going]..sort((a, b) => b.compareTo(a)));
      expect(stateOf(c).activeFilterCount, 2);

      vm.setChip(EventListChip.today);
      expect(vm.countFor(filter), visible.length);

      vm.clearFilters();
      expect(stateOf(c).filter, EventFilterState.none);
      expect(stateOf(c).chip, EventListChip.all);
    });

    test('liste ↔ takvim; gün ve ay takvim günüdür', () async {
      final c = await loaded(kVisitorSession);
      final vm = vmOf(c)..setMode(EventListMode.calendar);
      expect(stateOf(c).mode, EventListMode.calendar);
      vm
        ..selectDay(DateTime(2026, 10, 13, 15))
        ..setMonth(DateTime(2026, 11, 20));
      expect(stateOf(c).selectedDay, DateTime(2026, 10, 13));
      expect(stateOf(c).calendarMonth, DateTime(2026, 11));
    });

    test('"Kayıtlar kapalı" → TST-X2', () async {
      final c = await loaded(kVisitorSession);
      vmOf(c).showRegistrationClosed();
      expect(
        (GetIt.I<FeedbackService>() as FakeFeedbackService).toasts,
        [ToastId.tstX2],
      );
    });
  });
}
