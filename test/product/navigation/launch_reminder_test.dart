// T-25 / T-26 · Yerel hatırlatıcı köprüsü (CD-72; PLAN §15.6, §15.8):
// hatırlatıcıya dokunarak açılan uygulama, oturum etkinleşip kabuk kurulunca
// `NotificationNavigator.openPayload` ile hedefe (bilet varsa EVT-03, yoksa
// EVT-02; Etkinlikler sekmesi) gider ve hatırlatıcının liste belgesini yazar;
// yük yalnızca bir kez kullanılır. Uygulama açıkken dokunma
// (`onDidReceiveNotificationResponse` → `tappedPayloads`) aynı yoldan geçer.
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/service/local_reminder_service.dart';

import '../../fakes/fake_event_repository.dart';
import '../../fakes/fake_local_reminder_service.dart';
import '../../fakes/fake_messaging_service.dart';
import '../../fakes/fake_notification_repository.dart';
import '../../fakes/fake_rsvp_repository.dart';
import '../../fakes/fake_session_states.dart';
import '../../fakes/test_router.dart';
import '../../fixtures/event_model_fixtures.dart';
import '../../fixtures/rsvp_model_fixtures.dart';

void main() {
  group('T-25 / T-26 · hatırlatıcı köprüsü', () {
    testWidgets('soğuk açılış: kabuk kurulunca hedefe gidilir, liste belgesi '
        'yazılır; kabuk yeniden kurulunca yük yeniden kullanılmaz', (
      tester,
    ) async {
      final app = await TestRouter.pump(
        tester,
        session: FakeSessionStates.signedOut,
      );
      final reminders =
          GetIt.I<LocalReminderService>() as FakeLocalReminderService;
      (GetIt.I<EventRepository>() as FakeEventRepository).put(
        EventModelFixtures.e01,
      );
      reminders.launchPayload = LocalReminderService.payloadFor('e01');

      app.session = FakeSessionStates.active;
      await tester.pumpAndSettle();

      // Kayıt yok → etkinlik detayı Etkinlikler sekmesinde (detayın kendi
      // durumları EVT-02 testlerindedir).
      expect(app.locationLog, contains('/events/e01'));
      final opened = app.locationLog.where((l) => l == '/events/e01').length;
      final inbox =
          GetIt.I<NotificationRepository>() as FakeNotificationRepository;
      const uid = FakeSessionStates.uid;
      expect(
        inbox.notifications['event_reminder_e01_$uid']?.refs.clubId,
        EventModelFixtures.e01.clubId,
      );

      app.session = FakeSessionStates.signedOut;
      await tester.pumpAndSettle();
      app.session = FakeSessionStates.active;
      await tester.pumpAndSettle();
      expect(
        app.locationLog.where((l) => l == '/events/e01'),
        hasLength(opened),
      );
      expect(reminders.callsTo('initialLaunchPayload'), hasLength(1));
    });

    testWidgets('soğuk açılış: bileti olan kullanıcı bilete (EVT-03) gider', (
      tester,
    ) async {
      final app = await TestRouter.pump(
        tester,
        session: FakeSessionStates.signedOut,
      );
      (GetIt.I<EventRepository>() as FakeEventRepository).put(
        EventModelFixtures.e01,
      );
      (GetIt.I<RsvpRepository>() as FakeRsvpRepository).put(
        RsvpModelFixtures.e01Mehmet.copyWith(status: RsvpStatus.going),
      );
      (GetIt.I<LocalReminderService>() as FakeLocalReminderService)
          .launchPayload = LocalReminderService.payloadFor(
        'e01',
      );

      app.session = FakeSessionStates.active;
      await tester.pumpAndSettle();

      expect(app.locationLog, contains('/events/e01/ticket'));
    });

    testWidgets('T-42 · push: soğuk açılış yükü kabuk kurulunca bir kez, '
        'arka plandan dokunma etkin oturumda → openPush (bildirim belgesi '
        'okunur, hedefe gidilir)', (tester) async {
      final app = await TestRouter.pump(
        tester,
        session: FakeSessionStates.signedOut,
      );
      final messaging = GetIt.I<MessagingService>() as FakeMessagingService;
      final inbox =
          GetIt.I<NotificationRepository>() as FakeNotificationRepository;
      (GetIt.I<EventRepository>() as FakeEventRepository).put(
        EventModelFixtures.e01,
      );
      for (final (id, type) in [
        ('n_soguk', NotificationType.eventNew),
        ('n_sicak', NotificationType.eventCancelled),
      ]) {
        inbox.put(
          NotificationModel(
            id: id,
            userId: FakeSessionStates.uid,
            type: type,
            refs: const NotificationRefsModel(clubId: 'c01', eventId: 'e01'),
          ),
        );
      }
      messaging.launchData = {'notificationId': 'n_soguk'};

      app.session = FakeSessionStates.active;
      await tester.pumpAndSettle();
      // Etkinlik detayına gidildi (detayın kendi durumları EVT-02
      // testlerindedir; kabuk dışına çıkılmış olabilir).
      expect(app.locationLog, contains('/events/e01'));

      // Kabuk yeniden kurulur: soğuk açılış yükü yeniden kullanılmaz,
      // arka plan dokunuşları dinlenir.
      await app.go('/clubs');
      expect(messaging.hasTapListener, isTrue);
      messaging.tap({'notificationId': 'n_sicak'});
      await tester.pumpAndSettle();
      expect(app.locationLog, contains('/events/e01?showCancelled=true'));
      expect(inbox.callsTo('getNotification'), hasLength(2));

      app.session = FakeSessionStates.signedOut;
      await tester.pumpAndSettle();
      expect(messaging.hasTapListener, isFalse);
      expect(messaging.callsTo('initialMessageData'), hasLength(1));
    });

    testWidgets('uygulama açıkken dokunma → openPayload (etkin oturumda)', (
      tester,
    ) async {
      final app = await TestRouter.pump(tester, location: '/clubs');
      final reminders =
          GetIt.I<LocalReminderService>() as FakeLocalReminderService;
      (GetIt.I<EventRepository>() as FakeEventRepository).put(
        EventModelFixtures.e01,
      );
      expect(reminders.hasTapListener, isTrue);

      reminders.tap(LocalReminderService.payloadFor('e01'));
      await tester.pumpAndSettle();

      // Etkinlik detayına gidildi (detayın kendi durumları EVT-02
      // testlerindedir).
      expect(app.locationLog, contains('/events/e01'));
      final inbox =
          GetIt.I<NotificationRepository>() as FakeNotificationRepository;
      expect(inbox.callsTo('createSelf'), hasLength(1));

      // Kabuk söküldü (oturum kapandı): dinleyici bırakılır.
      app.session = FakeSessionStates.signedOut;
      await tester.pumpAndSettle();
      expect(reminders.hasTapListener, isFalse);
    });
  });
}
