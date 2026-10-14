// EVT-03 · TicketViewModel — canlı bilet (watchMine: valid → used → voided,
// TST-15), bilet yok / etkinlik yok / hata, "Vazgeç" (DLG-14 → cancel +
// yerel hatırlatıcı iptali → TST-42; çevrimdışı TST-24; bitmiş TST-X6),
// takvime ekle (SHT-14 yolları: .ics → TST-36, Google → DLG-32, bağlantı →
// TST-35), TicketViewState türetmeleri.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/events/provider/event_calendar_mixin.dart';
import 'package:gu_kulupler/features/events/provider/ticket_state.dart';
import 'package:gu_kulupler/features/events/provider/ticket_view_model.dart';
import 'package:gu_kulupler/features/events/view/widget/add_to_calendar_sheet.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_kulupler/product/service/file_service.dart';
import 'package:gu_kulupler/product/service/local_reminder_service.dart';
import 'package:gu_kulupler/product/service/share_service.dart';
import 'package:gu_kulupler/product/service/url_launcher_service.dart';

import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_event_repository.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_file_service.dart';
import '../../../fakes/fake_local_reminder_service.dart';
import '../../../fakes/fake_rsvp_repository.dart';
import '../../../fakes/fake_share_service.dart';
import '../../../fakes/fake_url_launcher_service.dart';
import '../../../fakes/register_fakes.dart';
import '../../../helpers/test_container.dart';
import '../ticket_test_support.dart';

const String _place = 'Bilgisayar Laboratuvarı-2';

void main() {
  late FakeEventRepository events;
  late FakeRsvpRepository rsvps;
  late FakeFeedbackService feedback;
  late FakeConnectivityService connectivity;
  late FakeLocalReminderService reminders;
  late FakeFileService files;
  late FakeShareService share;
  late FakeUrlLauncherService launcher;

  final provider = ticketViewModelProvider(kTicketEventId);

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    events = GetIt.I<EventRepository>() as FakeEventRepository;
    rsvps = GetIt.I<RsvpRepository>() as FakeRsvpRepository;
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
    connectivity = GetIt.I<ConnectivityService>() as FakeConnectivityService;
    reminders = GetIt.I<LocalReminderService>() as FakeLocalReminderService;
    files = GetIt.I<FileService>() as FakeFileService;
    share = GetIt.I<ShareService>() as FakeShareService;
    launcher = GetIt.I<UrlLauncherService>() as FakeUrlLauncherService;
  });

  /// Dinlenen kapsayıcı; ilk okuma beklenir.
  Future<ProviderContainer> loaded() async {
    final container = createContainer(
      overrides: [
        sessionViewModelProvider.overrideWithBuild(
          (ref, notifier) => ticketSession(),
        ),
      ],
    );
    addTearDown(container.listen(provider, (_, _) {}).close);
    await pumpEventQueue();
    return container;
  }

  TicketViewState stateOf(ProviderContainer container) =>
      container.read(provider);

  TicketViewModel vmOf(ProviderContainer container) =>
      container.read(provider.notifier);

  void emit(RsvpModel? rsvp) => rsvps
      .watchMineController(kTicketEventId, kTicketUid)
      .add(FirebaseSuccess(rsvp));

  group('EVT-03 · TicketViewModel · canlı bilet', () {
    test('ilk kare iskelet; etkinlik + kulüp + kayıt gelir (geçerli bilet, '
        'D-30 QR yükü); dinleme tek ve ekran kapanınca iptal', () async {
      seedTicket();
      final container = createContainer(
        overrides: [
          sessionViewModelProvider.overrideWithBuild(
            (ref, notifier) => ticketSession(),
          ),
        ],
      );
      final subscription = container.listen(provider, (_, _) {});
      expect(stateOf(container).isFetching, isTrue);

      await pumpEventQueue();
      final state = stateOf(container);
      expect(state.isFetching, isFalse);
      expect(state.isError || state.isNotFound || state.hasNoTicket, isFalse);
      expect(state.event, kTicketEvent);
      expect(state.club, kTicketClub);
      expect(state.rsvp, kTicketRsvp);
      expect(state.status, TicketState.valid);
      expect(state.qrPayload, 'gu:ticket:v1:e01:GU-CWV4-JMW9');
      expect(rsvps.callsTo('watchMine'), hasLength(1));
      expect(rsvps.activeListeners, 1);

      subscription.close();
      container.dispose();
      await pumpEventQueue();
      expect(rsvps.activeListeners, 0);
    });

    test('okutulunca (going → attended) rozet "used" + TST-15 bir kez; '
        'etkinlik iptali voided', () async {
      seedTicket();
      final container = await loaded();
      expect(feedback.toasts, isEmpty);

      emit(kScannedRsvp);
      await pumpEventQueue();
      expect(stateOf(container).status, TicketState.used);
      expect(stateOf(container).rsvp!.scannedAt, kScannedRsvp.scannedAt);
      expect(feedback.toasts, [ToastId.tst15]);

      // Aynı durumun yeniden gelmesi toast üretmez.
      emit(kScannedRsvp);
      await pumpEventQueue();
      expect(feedback.toasts, [ToastId.tst15]);

      // Vazgeçilmiş kayıt → iptal (voided).
      emit(kTicketRsvp.copyWith(status: RsvpStatus.cancelled));
      await pumpEventQueue();
      expect(stateOf(container).status, TicketState.voided);
      expect(stateOf(container).hasNoTicket, isFalse);
    });

    test('ilk olay zaten "attended" ise TST-15 gösterilmez', () async {
      seedTicket();
      rsvps.put(kScannedRsvp);
      final container = await loaded();
      expect(stateOf(container).status, TicketState.used);
      expect(feedback.toasts, isEmpty);
    });

    test('iptal edilmiş etkinlikte bilet voided', () async {
      seedTicket();
      events.put(kTicketEvent.copyWith(status: EventStatus.cancelled));
      final container = await loaded();
      expect(stateOf(container).status, TicketState.voided);
      expect(stateOf(container).canLeaveAt(kTicketNowUtc), isFalse);
    });

    test('kayıt yok / bekleme listesi → hasNoTicket (EVT-02)', () async {
      seedTicket(withRsvp: false);
      final container = await loaded();
      expect(stateOf(container).hasNoTicket, isTrue);
      expect(stateOf(container).rsvp, isNull);

      emit(kTicketRsvp.copyWith(status: RsvpStatus.waitlist));
      await pumpEventQueue();
      expect(stateOf(container).hasNoTicket, isTrue);

      emit(kTicketRsvp);
      await pumpEventQueue();
      expect(stateOf(container).hasNoTicket, isFalse);
      expect(stateOf(container).status, TicketState.valid);
    });

    test('etkinlik yok / silinmiş → isNotFound; dinleme açılmaz', () async {
      seedTicket();
      events.events.remove(kTicketEventId);
      final container = await loaded();
      expect(stateOf(container).isNotFound, isTrue);
      expect(rsvps.callsTo('watchMine'), isEmpty);

      events.put(kTicketEvent.copyWith(isDeleted: true));
      await vmOf(container).fetch();
      await pumpEventQueue();
      expect(stateOf(container).isNotFound, isTrue);
    });

    test('okuma hatası → isError; "Yeniden dene" dolu duruma döner', () async {
      seedTicket();
      events.failNext(FirestoreError.unavailable);
      final container = await loaded();
      expect(stateOf(container).isError, isTrue);
      expect(stateOf(container).isFetching, isFalse);

      await vmOf(container).fetch();
      await pumpEventQueue();
      expect(stateOf(container).isError, isFalse);
      expect(stateOf(container).status, TicketState.valid);
    });

    test('akış hatası içerik varken içeriği silmez', () async {
      seedTicket();
      final container = await loaded();
      rsvps
          .watchMineController(kTicketEventId, kTicketUid)
          .add(const FirebaseFailure(FirestoreError.unavailable));
      await pumpEventQueue();
      expect(stateOf(container).isError, isFalse);
      expect(stateOf(container).status, TicketState.valid);
    });
  });

  group('EVT-03 · TicketViewModel · vazgeç (DLG-14)', () {
    test('onay → cancel + yerel hatırlatıcı iptali + TST-42', () async {
      seedTicket();
      final container = await loaded();
      feedback.nextDialogResult = true;

      expect(await vmOf(container).leave(), isTrue);
      expect(feedback.dialogs, [DialogId.dlg14]);
      expect(rsvps.callsTo('cancel'), hasLength(1));
      expect(rsvps.rsvps[kTicketRsvp.id]!.status, RsvpStatus.cancelled);
      expect(reminders.cancelled, [kTicketRsvp.id]);
      expect(feedback.toasts, [ToastId.tst42]);
      expect(stateOf(container).isLeaving, isFalse);
    });

    test('vazgeçilmezse yazım yok; çevrimdışı → TST-24', () async {
      seedTicket();
      final container = await loaded();
      expect(await vmOf(container).leave(), isFalse);
      expect(rsvps.callsTo('cancel'), isEmpty);

      connectivity.emit(true);
      feedback.nextDialogResult = true;
      expect(await vmOf(container).leave(), isFalse);
      expect(rsvps.callsTo('cancel'), isEmpty);
      expect(feedback.toasts, [ToastId.tst24]);
      expect(reminders.cancelled, isEmpty);
    });

    test('bitmiş etkinlik → TST-X6; plan iptal edilmez', () async {
      seedTicket();
      final container = await loaded();
      events.put(
        kTicketEvent.copyWith(
          startsAt: kTicketNowUtc.subtract(const Duration(hours: 3)),
          endsAt: kTicketNowUtc.subtract(const Duration(hours: 1)),
        ),
      );
      feedback.nextDialogResult = true;
      expect(await vmOf(container).leave(), isFalse);
      expect(feedback.toasts, [ToastId.tstX6]);
      expect(reminders.cancelled, isEmpty);
    });
  });

  group('EVT-03 · TicketViewModel · takvime ekle (SHT-14)', () {
    test('cihaz takvimi: .ics geçici dosya → text/calendar paylaşımı → '
        'TST-36', () async {
      seedTicket();
      final container = await loaded();
      await vmOf(container).addToCalendar(
        CalendarChoice.device,
        event: kTicketEvent,
        clubName: kTicketClub.name,
        placeLabel: _place,
      );
      expect(files.written.keys, [IcsBuilder.fileNameFor(kTicketEvent)]);
      final ics = utf8.decode(files.written.values.single);
      expect(
        ics,
        IcsBuilder.build(
          kTicketEvent,
          clubName: kTicketClub.name,
          location: _place,
        ),
      );
      expect(share.sharedFiles.single.mimeType, 'text/calendar');
      expect(
        share.sharedFiles.single.path,
        '${FakeFileService.tempDirectory}/${IcsBuilder.fileNameFor(kTicketEvent)}',
      );
      expect(feedback.toasts, [ToastId.tst36]);
    });

    test('dosya yazılamaz ya da paylaşım açılmazsa toast yok', () async {
      seedTicket();
      final container = await loaded();
      files.canWrite = false;
      await vmOf(container).addToCalendar(
        CalendarChoice.device,
        event: kTicketEvent,
        clubName: kTicketClub.name,
        placeLabel: _place,
      );
      expect(share.sharedFiles, isEmpty);
      files.canWrite = true;
      share.canShare = false;
      await vmOf(container).addToCalendar(
        CalendarChoice.device,
        event: kTicketEvent,
        clubName: kTicketClub.name,
        placeLabel: _place,
      );
      expect(feedback.toasts, isEmpty);
    });

    test('Google Takvim: DLG-32 onayı → şablon adresi açılır', () async {
      seedTicket();
      final container = await loaded();
      feedback.nextDialogResult = true;
      await vmOf(container).addToCalendar(
        CalendarChoice.google,
        event: kTicketEvent,
        clubName: kTicketClub.name,
        placeLabel: _place,
      );
      expect(feedback.dialogs, [DialogId.dlg32]);
      final uri = launcher.opened.single;
      expect(uri.host, 'calendar.google.com');
      expect(uri.path, '/calendar/render');
      expect(uri.queryParameters, {
        'action': 'TEMPLATE',
        'text': kTicketEvent.title,
        'dates': '20261009T150000Z/20261009T170000Z',
        'location': _place,
      });
      expect(uri.toString(), isNot(contains('+')));
    });

    test('bağlantıyı kopyala → etkinlik bağlantısı panoda + TST-35', () async {
      seedTicket();
      final container = await loaded();
      await vmOf(container).addToCalendar(
        CalendarChoice.copyLink,
        event: kTicketEvent,
        clubName: kTicketClub.name,
        placeLabel: _place,
      );
      expect(share.copied, ['https://kulupler.gumushane.edu.tr/events/e01']);
      expect(share.copied.single, EventLinks.share(kTicketEventId));
      expect(feedback.toasts, [ToastId.tst35]);
    });
  });

  group('EVT-03 · TicketViewState', () {
    test('status / qrPayload / canLeaveAt türetmeleri; props + copyWith '
        'tüm alanlar', () {
      const empty = TicketViewState();
      expect(empty.status, isNull);
      expect(empty.qrPayload, isNull);
      expect(empty.canLeaveAt(kTicketNowUtc), isFalse);

      final loadedState = loadedTicketState();
      expect(loadedState.status, TicketState.valid);
      expect(loadedState.canLeaveAt(kTicketNowUtc), isTrue);
      expect(loadedState.canLeaveAt(kTicketEvent.endsAt), isFalse);
      expect(
        loadedTicketState(rsvp: kScannedRsvp).canLeaveAt(kTicketNowUtc),
        isFalse,
      );

      final full = loadedState.copyWith(
        isFetching: true,
        isError: true,
        isNotFound: true,
        hasNoTicket: true,
        isLeaving: true,
      );
      expect(full.props, hasLength(8));
      expect(full, isNot(loadedState));
      expect(full.copyWith(), full);
      expect(full.copyWith(clearRsvp: true).rsvp, isNull);
      expect(
        full.copyWith(
          isFetching: false,
          isError: false,
          isNotFound: false,
          hasNoTicket: false,
          isLeaving: false,
        ),
        loadedState,
      );
    });
  });
}
