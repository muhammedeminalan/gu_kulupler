// T-25 · Soğuk açılış köprüsü (CD-72; PLAN §15.6; docs/plans/T-25.md §6 h):
// hatırlatıcıya dokunarak açılan uygulama, oturum etkinleşip kabuk kurulunca
// etkinlik detayına (Etkinlikler sekmesi) gider ve hatırlatıcının liste
// belgesini yazar; yük yalnızca bir kez kullanılır.
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/service/local_reminder_service.dart';

import '../../fakes/fake_event_repository.dart';
import '../../fakes/fake_local_reminder_service.dart';
import '../../fakes/fake_notification_repository.dart';
import '../../fakes/fake_session_states.dart';
import '../../fakes/test_router.dart';
import '../../fixtures/event_model_fixtures.dart';

void main() {
  group('T-25 · soğuk açılış hatırlatıcı köprüsü', () {
    testWidgets('kabuk kurulunca etkinlik detayına gidilir, liste belgesi '
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

      // Etkinlik detayı Etkinlikler sekmesinde açıldı (detayın kendi
      // durumları — bulunamadı vb. — EVT-02 testlerindedir).
      expect(app.locationLog, contains('/events/e01'));
      final opened = app.locationLog.where((l) => l == '/events/e01').length;
      final inbox =
          GetIt.I<NotificationRepository>() as FakeNotificationRepository;
      final uid = FakeSessionStates.active.uid!;
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
  });
}
