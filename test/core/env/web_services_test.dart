// Web derlemesinin yerel servisleri: push FCM'e kaydolmaz, hatırlatıcı planlamaz.
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/env/web_services.dart';
import 'package:gu_kulupler/l10n/app_localizations_tr.dart';
import 'package:gu_kulupler/product/service/local_reminder_service.dart';

import '../../fixtures/event_model_fixtures.dart';
import '../../fixtures/rsvp_model_fixtures.dart';

void main() {
  group('WebMessagingService', () {
    const service = WebMessagingService();

    test('izin yok, jeton yok: hesaba jeton yazılmaz', () async {
      expect(await service.isAuthorized(), isFalse);
      expect(await service.token(), isNull);
      expect(await service.invalidateToken(), isTrue);
      expect(await service.initialMessageData(), isNull);
      await service.configureForeground();
    });

    test('akışlar boştur', () async {
      expect(await service.onTokenRefresh.isEmpty, isTrue);
      expect(await service.openedMessageData.isEmpty, isTrue);
    });
  });

  group('WebLocalReminderService', () {
    const service = WebLocalReminderService();
    final rsvp = RsvpModelFixtures.e01Mehmet;
    final event = EventModelFixtures.byId(rsvp.eventId);

    test('tüm çağrılar hatasız ve etkisiz biter', () async {
      await service.ensureChannel(AppLocalizationsTr());
      await service.schedule(rsvp: rsvp, event: event);
      await service.cancel(rsvp.id);
      await service.cancelAll();
      await service.rescheduleAll(
        myGoing: [rsvp],
        events: {event.id: event},
        settings: UserSettingsModel.defaults(rsvp.userId),
      );
      expect(await service.initialLaunchPayload(), isNull);
      expect(await service.tappedPayloads.isEmpty, isTrue);
    });
  });
}
