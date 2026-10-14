// EVT-02 · EventDetailViewModel: açılış (etkinlik + kulüp + kayıt; izin yok
// → TST-X18 / CD-57; yok → SYS-04), rsvp durum makinesi (katıl → going /
// waitlist, vazgeç, yeniden katıl; hata geri alma), DLG-14 / DLG-15 / DLG-16,
// hatırlatıcı (SHT-13 → fake LocalReminderService; iyimser + geri alma),
// takvim (SHT-14), alt çubuk türü (PLAN §12.6, W-76, W-81).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/events/provider/event_calendar_mixin.dart';
import 'package:gu_kulupler/features/events/provider/event_detail_state.dart';
import 'package:gu_kulupler/features/events/provider/event_detail_view_model.dart';
import 'package:gu_kulupler/features/events/view/widget/add_to_calendar_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_kulupler/product/service/file_service.dart';
import 'package:gu_kulupler/product/service/local_reminder_service.dart';
import 'package:gu_kulupler/product/service/share_service.dart';

import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_event_repository.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_file_service.dart';
import '../../../fakes/fake_local_reminder_service.dart';
import '../../../fakes/fake_rsvp_repository.dart';
import '../../../fakes/fake_share_service.dart';
import '../../../fakes/register_fakes.dart';
import '../../../fixtures/event_model_fixtures.dart';
import '../../../helpers/fake_app_clock.dart';
import '../../../helpers/test_container.dart';
import '../event_detail_test_support.dart';

void main() {
  late FakeEventRepository events;
  late FakeRsvpRepository rsvps;
  late FakeFeedbackService feedback;
  late FakeLocalReminderService reminders;

  setUp(() async {
    await GetIt.I.reset();
    registerDefaultFakes();
    addTearDown(GetIt.I.reset);
    EventDetailViewModel.resetCancelledNotices();
    events = GetIt.I<EventRepository>() as FakeEventRepository;
    rsvps = GetIt.I<RsvpRepository>() as FakeRsvpRepository;
    feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
    reminders = GetIt.I<LocalReminderService>() as FakeLocalReminderService;
  });

  /// [eventId] ekranının ilk okuması bitmiş kapsayıcısı.
  Future<ProviderContainer> loaded({
    String? eventId,
    SessionState session = kVisitorSession,
  }) async {
    final container = createContainer(
      overrides: [
        sessionViewModelProvider.overrideWithBuild((ref, notifier) => session),
      ],
    );
    final provider = eventDetailViewModelProvider(eventId ?? kEvent.id);
    addTearDown(container.listen(provider, (_, _) {}).close);
    await pumpEventQueue();
    return container;
  }

  EventDetailState stateOf(ProviderContainer c, [String? eventId]) =>
      c.read(eventDetailViewModelProvider(eventId ?? kEvent.id));

  EventDetailViewModel vmOf(ProviderContainer c, [String? eventId]) =>
      c.read(eventDetailViewModelProvider(eventId ?? kEvent.id).notifier);

  group('EVT-02 · açılış', () {
    test('etkinlik + kulüp + kayıt okunur; erişim oturumdan', () async {
      seedEvents(rsvps: [kGoing]);
      final c = await loaded(session: memberSession());
      final state = stateOf(c);
      expect(state.event, kEvent);
      expect(state.club?.id, kEvent.clubId);
      expect(state.rsvp, kGoing);
      expect(state.access, ClubAccess.member);
      expect(state.isFetching, isFalse);
      expect(state.barAt(kNowUtc), EventDetailBar.going);
    });

    test('okuma izni yok (üyelere özel derin bağlantı) → TST-X18 + '
        'isDenied (CD-57)', () async {
      seedEvents(events: const []);
      final c = await loaded();
      expect(stateOf(c).isDenied, isTrue);
      expect(feedback.toasts, [ToastId.tstX18]);
    });

    test('silinmiş etkinlik → isNotFound (SYS-04)', () async {
      seedEvents(events: [kEvent.copyWith(isDeleted: true)]);
      final c = await loaded();
      expect(stateOf(c).isNotFound, isTrue);
      expect(feedback.toasts, isEmpty);
    });

    test('ağ hatası → isError; fetch yeniden okur', () async {
      seedEvents();
      events.failNext(FirestoreError.unavailable);
      final c = await loaded();
      expect(stateOf(c).isError, isTrue);
      await vmOf(c).fetch();
      expect(stateOf(c).isError, isFalse);
      expect(stateOf(c).event, kEvent);
    });
  });

  group('EVT-02 · rsvp durum makinesi', () {
    test('katıl → going: kayıt, sayaç, hatırlatıcı planı, TST-41', () async {
      seedEvents();
      final c = await loaded();
      var ticket = 0;
      final outcome = await vmOf(
        c,
      ).join(ReminderOption.oneHour, onTicket: () => ticket++);
      expect(outcome, EventJoinOutcome.going);
      final state = stateOf(c);
      expect(state.rsvp?.status, RsvpStatus.going);
      expect(state.event?.goingCount, kEvent.goingCount + 1);
      expect(state.isActing, isFalse);
      expect(state.barAt(kNowUtc), EventDetailBar.going);
      expect(reminders.scheduledFor(state.rsvp!.id), isNotNull);
      expect(feedback.toasts.last, ToastId.tst41);
      feedback.tapToastAction();
      expect(ticket, 1);
    });

    test('dolu etkinlik → waitlist: sıra = katılım sonrası waitlistCount '
        '(W-76), plan yok, TST-43', () async {
      final full = EventModelFixtures.e03;
      seedEvents();
      final c = await loaded(eventId: full.id);
      expect(stateOf(c, full.id).barAt(kNowUtc), EventDetailBar.cta);
      final outcome = await vmOf(c, full.id).join(ReminderOption.oneHour);
      expect(outcome, EventJoinOutcome.waitlist);
      final state = stateOf(c, full.id);
      expect(state.rsvp?.status, RsvpStatus.waitlist);
      expect(state.waitlistPosition, full.waitlistCount + 1);
      expect(state.barAt(kNowUtc), EventDetailBar.waitlist);
      expect(reminders.scheduled, isEmpty);
      expect(feedback.toasts.last, ToastId.tst43);
      expect(feedback.toastParams.last.n, full.waitlistCount + 1);
    });

    test('DLG-15 → onay → bekleme listesi (n = bekleyen)', () async {
      final full = EventModelFixtures.e03;
      seedEvents();
      final c = await loaded(eventId: full.id);
      feedback.dialogResults[DialogId.dlg15] = true;
      expect(
        await vmOf(c, full.id).joinWaitlist(),
        EventJoinOutcome.waitlist,
      );
      expect(feedback.dialogs, [DialogId.dlg15]);
      expect(feedback.dialogParams.single, {
        DialogParamKeys.n: full.waitlistCount,
      });
    });

    test('katılım hatası: durum geri gelir (yetki → TST-X18, çevrimdışı → '
        'TST-24 yazımsız)', () async {
      seedEvents();
      final c = await loaded();
      rsvps.failNext(FirestoreError.permissionDenied);
      expect(
        await vmOf(c).join(ReminderOption.oneHour),
        EventJoinOutcome.failed,
      );
      expect(stateOf(c).rsvp, isNull);
      expect(stateOf(c).isActing, isFalse);
      expect(stateOf(c).event?.goingCount, kEvent.goingCount);
      expect(feedback.toasts.last, ToastId.tstX18);

      (GetIt.I<ConnectivityService>() as FakeConnectivityService).isOffline =
          true;
      rsvps.calls.clear();
      expect(
        await vmOf(c).join(ReminderOption.oneHour),
        EventJoinOutcome.failed,
      );
      expect(rsvps.callsTo('join'), isEmpty);
      expect(feedback.toasts.last, ToastId.tst24);
    });

    test('DLG-14 vazgeç → cancelled, sayaç −1, plan iptal, TST-42; yeniden '
        'katıl aynı bilet kodu', () async {
      seedEvents(rsvps: [kGoing]);
      final c = await loaded(session: memberSession());
      feedback.dialogResults[DialogId.dlg14] = true;
      expect(await vmOf(c).cancelRsvp(), isTrue);
      expect(feedback.dialogParams.single, {DialogParamKeys.waitlist: false});
      var state = stateOf(c);
      expect(state.rsvp?.status, RsvpStatus.cancelled);
      expect(state.activeRsvp, isNull);
      expect(state.event?.goingCount, kEvent.goingCount - 1);
      expect(reminders.cancelled, [kGoing.id]);
      expect(feedback.toasts.last, ToastId.tst42);
      expect(state.barAt(kNowUtc), EventDetailBar.cta);

      expect(
        await vmOf(c).join(ReminderOption.oneDay),
        EventJoinOutcome.going,
      );
      state = stateOf(c);
      expect(state.rsvp?.status, RsvpStatus.going);
      expect(state.rsvp?.ticketCode, kGoing.ticketCode);
    });

    test('vazgeç: DLG-14 "Kalmaya devam et" → yazım yok', () async {
      seedEvents(rsvps: [kGoing]);
      final c = await loaded();
      feedback.dialogResults[DialogId.dlg14] = false;
      expect(await vmOf(c).cancelRsvp(), isFalse);
      expect(rsvps.callsTo('cancel'), isEmpty);
      expect(stateOf(c).rsvp, kGoing);
    });

    test('bitmiş etkinlikte vazgeç → TST-X6, dialog yok (W-81 (b))', () async {
      seedEvents(rsvps: [kGoing]);
      final c = await loaded();
      (GetIt.I<AppClock>() as FakeAppClock).set(
        kEvent.endsAt.add(const Duration(minutes: 1)),
      );
      expect(await vmOf(c).cancelRsvp(), isFalse);
      expect(feedback.dialogs, isEmpty);
      expect(feedback.toasts, [ToastId.tstX6]);
    });

    test('alt çubuk: geçmiş, iptal, yönetici, danışman, dolu, kapalı', () {
      final now = kNowUtc;
      expect(
        loadedState(event: EventModelFixtures.e19).barAt(now),
        EventDetailBar.ended,
      );
      expect(
        loadedState(event: EventModelFixtures.e21).barAt(now),
        EventDetailBar.cancelled,
      );
      expect(
        loadedState(
          session: memberSession(role: ClubRole.board),
        ).barAt(now),
        EventDetailBar.manager,
      );
      expect(
        loadedState(
          session: memberSession(role: ClubRole.advisor),
        ).barAt(now),
        EventDetailBar.advisor,
      );
      expect(
        loadedState(event: EventModelFixtures.e03).statusAt(now),
        isNotNull,
      );
    });
  });

  group('EVT-02 · hatırlatıcı (SHT-13)', () {
    test('kayıt yok → TST-X7', () async {
      seedEvents();
      final c = await loaded();
      expect(vmOf(c).ensureCanSetReminder(), isFalse);
      expect(await vmOf(c).setReminder(ReminderOption.oneDay), isFalse);
      expect(feedback.toasts, [ToastId.tstX7, ToastId.tstX7]);
    });

    test(
      'seçim → yazım + yerel plan (fake) → TST-37; "yok" → plan iptal',
      () async {
        seedEvents(rsvps: [kGoing]);
        final c = await loaded();
        expect(await vmOf(c).setReminder(ReminderOption.oneDay), isTrue);
        expect(stateOf(c).rsvp?.reminder, ReminderOption.oneDay);
        expect(rsvps.reminderWrites.single.reminder, ReminderOption.oneDay);
        final plan = reminders.scheduledFor(kGoing.id);
        expect(
          plan?.triggerAtUtc,
          kEvent.startsAt.subtract(const Duration(days: 1)),
        );
        expect(feedback.toasts.last, ToastId.tst37);
        expect(feedback.toastParams.last.off, isFalse);

        expect(await vmOf(c).setReminder(ReminderOption.none), isTrue);
        expect(reminders.scheduledFor(kGoing.id), isNull);
        expect(reminders.cancelled, [kGoing.id]);
        expect(feedback.toastParams.last.off, isTrue);
      },
    );

    test('yazım hatası → iyimser tercih geri alınır, plan yok', () async {
      seedEvents(rsvps: [kGoing]);
      final c = await loaded();
      rsvps.failNext(FirestoreError.unavailable);
      expect(await vmOf(c).setReminder(ReminderOption.oneDay), isFalse);
      expect(stateOf(c).rsvp?.reminder, kGoing.reminder);
      expect(reminders.callsTo('schedule'), isEmpty);
      expect(feedback.toasts.last, ToastId.tst24);
    });
  });

  group('EVT-02 · DLG-16 iptal bildirimi', () {
    final cancelled = EventModelFixtures.e21;

    test('oturumda bir kez; bildirimden gelince yeniden; "Benzer '
        'etkinlikleri gör" → true', () async {
      seedEvents();
      final c = await loaded(eventId: cancelled.id);
      final vm = vmOf(c, cancelled.id);
      feedback.dialogResults[DialogId.dlg16] = true;
      expect(await vm.showCancelledNotice(), isFalse);
      expect(feedback.dialogParams.single, {
        DialogParamKeys.event: cancelled.title,
        DialogParamKeys.reason: cancelled.cancelReason,
      });
      expect(await vm.showCancelledNotice(), isFalse);
      expect(feedback.dialogs, [DialogId.dlg16]);

      feedback.dialogResults[DialogId.dlg16] = false;
      expect(await vm.showCancelledNotice(force: true), isTrue);
      expect(feedback.dialogs, [DialogId.dlg16, DialogId.dlg16]);
    });

    test('iptal edilmemiş etkinlikte gösterilmez', () async {
      seedEvents();
      final c = await loaded();
      expect(await vmOf(c).showCancelledNotice(force: true), isFalse);
      expect(feedback.dialogs, isEmpty);
    });
  });

  group('EVT-02 · takvim (SHT-14) ve paylaşım', () {
    test('cihaz → .ics dosyası paylaşılır → TST-36; kopyala → TST-35; '
        'Google → DLG-32', () async {
      seedEvents();
      final c = await loaded();
      final files = GetIt.I<FileService>() as FakeFileService;
      final share = GetIt.I<ShareService>() as FakeShareService;
      Future<void> add(CalendarChoice choice) => vmOf(c).addToCalendar(
        choice,
        event: kEvent,
        clubName: 'Kulüp',
        placeLabel: 'Lab',
      );
      await add(CalendarChoice.device);
      expect(files.written.keys, [IcsBuilder.fileNameFor(kEvent)]);
      expect(share.sharedFiles.single.mimeType, IcsBuilder.mimeType);
      expect(feedback.toasts.last, ToastId.tst36);

      await add(CalendarChoice.copyLink);
      expect(share.copied.last, vmOf(c).shareUrl());
      expect(share.copied.last, EventLinks.share(kEvent.id));
      expect(feedback.toasts.last, ToastId.tst35);

      await add(CalendarChoice.google);
      expect(feedback.dialogs.last, DialogId.dlg32);
    });
  });
}
