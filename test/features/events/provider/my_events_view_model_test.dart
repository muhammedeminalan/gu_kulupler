// EVT-04 · MyEventsViewModel: açılış (listMine → getEvents → kulüp adları),
// sekme ayrımı (geçmiş = bitiş < şimdi sınırı, iptal edilmiş etkinlik, iptal
// edilmiş kayıt), sayfalama (20'lik sayfa, boş sekmede kendiliğinden
// devam), vazgeç (W-81 (b), DLG-14, iyimser gizleme + geri alma, hatırlatıcı
// iptali), hata / yenileme (PLAN §12.6).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/events/provider/my_events_state.dart';
import 'package:gu_kulupler/features/events/provider/my_events_view_model.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_kulupler/product/service/local_reminder_service.dart';

import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_event_repository.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_local_reminder_service.dart';
import '../../../fakes/fake_rsvp_repository.dart';
import '../../../fakes/fake_session_states.dart';
import '../../../fakes/register_fakes.dart';
import '../../../fixtures/club_model_fixtures.dart';
import '../../../fixtures/event_model_fixtures.dart';
import '../../../fixtures/rsvp_model_fixtures.dart';
import '../../../helpers/fake_app_clock.dart';
import '../../../helpers/test_container.dart';
import '../my_events_test_support.dart';

void main() {
  late FakeEventRepository events;
  late FakeRsvpRepository rsvps;
  late FakeFeedbackService feedback;
  late FakeLocalReminderService reminders;

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    events = GetIt.I<EventRepository>() as FakeEventRepository;
    rsvps = GetIt.I<RsvpRepository>() as FakeRsvpRepository;
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
    reminders = GetIt.I<LocalReminderService>() as FakeLocalReminderService;
  });

  Future<ProviderContainer> loaded() async {
    final container = createContainer(
      overrides: [
        sessionViewModelProvider.overrideWithBuild(
          (ref, notifier) => FakeSessionStates.active,
        ),
      ],
    );
    addTearDown(container.listen(myEventsViewModelProvider, (_, _) {}).close);
    await pumpEventQueue();
    return container;
  }

  MyEventsState stateOf(ProviderContainer c) =>
      c.read(myEventsViewModelProvider);

  MyEventsViewModel vmOf(ProviderContainer c) =>
      c.read(myEventsViewModelProvider.notifier);

  List<String> idsOf(ProviderContainer c) => [
    for (final (_, event) in vmOf(c).visible) event.id,
  ];

  group('EVT-04 · açılış ve sekmeler', () {
    test('kayıtlar + etkinlikler + kulüp adları; yaklaşan / geçmiş / bekleme '
        'ayrımı', () async {
      seedMyEvents();
      final c = await loaded();
      final state = stateOf(c);
      expect(state.isFetching, isFalse);
      expect(state.loadedCount, 3);
      expect(
        state.clubNames[kMyE01.clubId],
        ClubModelFixtures.byId('c01').name,
      );
      expect(rsvps.callsTo('listMine').single.args, [kMyUid]);
      expect(idsOf(c), ['e01']);
      vmOf(c).setTab(MyEventsTab.past);
      expect(idsOf(c), ['e18']);
      vmOf(c).setTab(MyEventsTab.waitlist);
      expect(idsOf(c), ['e08']);
    });

    test('geçmiş = bitiş < şimdi: bitiş anında hâlâ yaklaşan, 1 sn sonra '
        'geçmiş', () {
      final rsvp = RsvpModelFixtures.e01Mehmet;
      final end = kMyE01.endsAt;
      expect(MyEventsState.tabOf(rsvp, kMyE01, end), MyEventsTab.upcoming);
      expect(
        MyEventsState.tabOf(
          rsvp,
          kMyE01,
          end.add(const Duration(seconds: 1)),
        ),
        MyEventsTab.past,
      );
      // Vazgeç yalnızca bitiş > şimdi (W-81 (b)): bitiş anında yok.
      expect(MyEventsState.canLeave(rsvp, kMyE01, end), isFalse);
      expect(
        MyEventsState.canLeave(
          rsvp,
          kMyE01,
          end.subtract(const Duration(seconds: 1)),
        ),
        isTrue,
      );
    });

    test('iptal edilmiş etkinlik geçmişte; vazgeçilmiş kayıt hiçbir sekmede '
        'yok; geçmiş en yeni üstte', () async {
      final cancelled = kMyE08.copyWith(status: EventStatus.cancelled);
      seedMyEvents(
        events: [kMyE01, cancelled, kMyE18],
        rsvps: [
          RsvpModelFixtures.e01Mehmet.copyWith(status: RsvpStatus.cancelled),
          RsvpModelFixtures.e08Mehmet,
          RsvpModelFixtures.e18Mehmet,
        ],
      );
      final c = await loaded();
      expect(stateOf(c).rsvps.map((r) => r.eventId), ['e08', 'e18']);
      expect(idsOf(c), isEmpty);
      vmOf(c).setTab(MyEventsTab.past);
      expect(idsOf(c), ['e08', 'e18']);
      vmOf(c).setTab(MyEventsTab.waitlist);
      expect(idsOf(c), isEmpty);
    });

    test('kayıtlar okunamadı → isError; fetch yeniden okur', () async {
      seedMyEvents();
      rsvps.failNext(FirestoreError.unavailable);
      final c = await loaded();
      expect(stateOf(c).isError, isTrue);
      await vmOf(c).fetch();
      expect(stateOf(c).isError, isFalse);
      expect(idsOf(c), ['e01']);
    });

    test('yenileme okunamazsa içerik kalır', () async {
      seedMyEvents();
      final c = await loaded();
      rsvps.failNext(FirestoreError.unavailable);
      await vmOf(c).refresh();
      expect(stateOf(c).isError, isFalse);
      expect(stateOf(c).isRefreshing, isFalse);
      expect(idsOf(c), ['e01']);
    });
  });

  group('EVT-04 · sayfalama', () {
    test('ilk sayfa 20 etkinlik; loadMore sonrakini okur', () async {
      final batch = pastBatch(25);
      seedMyEvents(
        events: [kMyE01, ...batch.events],
        rsvps: [RsvpModelFixtures.e01Mehmet, ...batch.rsvps],
      );
      final c = await loaded();
      expect(stateOf(c).loadedCount, Limits.pageSize);
      expect(stateOf(c).hasMore, isTrue);
      expect(events.callsTo('getEvents').single.args.single, hasLength(20));
      await vmOf(c).loadMore();
      expect(stateOf(c).loadedCount, 26);
      expect(stateOf(c).hasMore, isFalse);
      vmOf(c).setTab(MyEventsTab.past);
      expect(vmOf(c).visible, hasLength(25));
    });

    test('seçili sekme ilk sayfada boşsa sıradaki sayfa kendiliğinden '
        'okunur', () async {
      final batch = pastBatch(Limits.pageSize);
      // `e01` kaydı en eskisi: ikinci sayfaya düşer (`listMine` en yeni
      // üstte).
      seedMyEvents(
        events: [...batch.events, kMyE01],
        rsvps: [
          ...batch.rsvps,
          RsvpModelFixtures.e01Mehmet.copyWith(createdAt: DateTime.utc(2026)),
        ],
      );
      final c = await loaded();
      expect(events.callsTo('getEvents'), hasLength(2));
      expect(idsOf(c), ['e01']);
      expect(stateOf(c).isLoadingMore, isFalse);
    });

    test('sayfa okunamazsa liste olduğu gibi kalır', () async {
      final batch = pastBatch(25);
      seedMyEvents(
        events: [kMyE01, ...batch.events],
        rsvps: [RsvpModelFixtures.e01Mehmet, ...batch.rsvps],
      );
      final c = await loaded();
      events.failNext(FirestoreError.unavailable);
      await vmOf(c).loadMore();
      expect(stateOf(c).loadedCount, Limits.pageSize);
      expect(stateOf(c).isLoadingMore, isFalse);
      expect(stateOf(c).isError, isFalse);
    });
  });

  group('EVT-04 · vazgeç', () {
    test('DLG-14 onayı → satır düşer, kayıt iptal, hatırlatıcı iptali, '
        'TST-42', () async {
      seedMyEvents();
      feedback.dialogResults[DialogId.dlg14] = true;
      final c = await loaded();
      final ok = await vmOf(c).leave('e01');
      expect(ok, isTrue);
      expect(feedback.dialogs, [DialogId.dlg14]);
      expect(feedback.dialogParams.single[DialogParamKeys.waitlist], isFalse);
      expect(rsvps.callsTo('cancel').single.args, ['e01', kMyUid]);
      expect(reminders.cancelled, [RsvpModelFixtures.e01Mehmet.id]);
      expect(feedback.toasts, [ToastId.tst42]);
      expect(idsOf(c), isEmpty);
      expect(stateOf(c).pendingIds, isEmpty);
    });

    test('bekleme listesi: DLG-14 bekleme metniyle', () async {
      seedMyEvents();
      feedback.dialogResults[DialogId.dlg14] = true;
      final c = await loaded();
      vmOf(c).setTab(MyEventsTab.waitlist);
      expect(await vmOf(c).leave('e08'), isTrue);
      expect(feedback.dialogParams.single[DialogParamKeys.waitlist], isTrue);
      expect(idsOf(c), isEmpty);
    });

    test('dialog kapatılırsa yazım yok', () async {
      seedMyEvents();
      feedback.dialogResults[DialogId.dlg14] = false;
      final c = await loaded();
      expect(await vmOf(c).leave('e01'), isFalse);
      expect(rsvps.callsTo('cancel'), isEmpty);
      expect(idsOf(c), ['e01']);
    });

    test('iyimser: yazım sürerken satır gizli; hata → geri gelir + '
        'TST-24', () async {
      seedMyEvents();
      feedback.dialogResults[DialogId.dlg14] = true;
      final c = await loaded();
      rsvps.failNext(FirestoreError.unavailable);
      expect(await vmOf(c).leave('e01'), isFalse);
      expect(feedback.toasts, [ToastId.tst24]);
      expect(reminders.cancelled, isEmpty);
      expect(idsOf(c), ['e01']);
      expect(stateOf(c).pendingIds, isEmpty);
    });

    test('yazım sürerken satır gizlenir', () async {
      seedMyEvents();
      feedback.dialogResults[DialogId.dlg14] = true;
      final c = await loaded();
      final hidden = <bool>[];
      c.listen(
        myEventsViewModelProvider,
        (_, next) => hidden.add(next.pendingIds.contains('e01')),
      );
      await vmOf(c).leave('e01');
      expect(hidden.first, isTrue);
      expect(hidden.last, isFalse);
    });

    test('etkinlik bitti (W-81 (b)) → TST-X6, dialog yok', () async {
      seedMyEvents();
      final c = await loaded();
      (GetIt.I<AppClock>() as FakeAppClock).set(kMyE01.endsAt);
      expect(await vmOf(c).leave('e01'), isFalse);
      expect(feedback.toasts, [ToastId.tstX6]);
      expect(feedback.dialogs, isEmpty);
    });

    test('çevrimdışı → TST-24, yazım yok', () async {
      seedMyEvents();
      feedback.dialogResults[DialogId.dlg14] = true;
      final c = await loaded();
      (GetIt.I<ConnectivityService>() as FakeConnectivityService).isOffline =
          true;
      expect(await vmOf(c).leave('e01'), isFalse);
      expect(feedback.toasts, [ToastId.tst24]);
      expect(rsvps.callsTo('cancel'), isEmpty);
      expect(idsOf(c), ['e01']);
    });
  });

  test('fixture: e08 ve e18 demo veride beklenen konumda', () {
    expect(kMyE08.endsAt.isAfter(kMyNowUtc), isTrue);
    expect(kMyE18.endsAt.isBefore(kMyNowUtc), isTrue);
    expect(EventModelFixtures.e01.endsAt.isAfter(kMyNowUtc), isTrue);
  });
}
