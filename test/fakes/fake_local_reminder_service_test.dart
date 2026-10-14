// T-23 · FakeLocalReminderService sözleşmesi (PLAN §15.6): yalnızca `going`
// planlanır, `none` ⇒ plan yok, geçmiş an planlanmaz, rsvp başına tek plan;
// kimlik ve payload gerçek servisin statik türetimleriyle aynıdır.
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/service/local_reminder_service.dart';

import '../fixtures/event_model_fixtures.dart';
import '../fixtures/rsvp_model_fixtures.dart';
import '../helpers/fake_app_clock.dart';
import 'fake_local_reminder_service.dart';
import 'register_fakes.dart';

void main() {
  group('T-23 · FakeLocalReminderService', () {
    final event = EventModelFixtures.e01;
    final going = RsvpModelFixtures.e01Mehmet;

    test('LocalReminderService arayüzünü uygular; registerDefaultFakes '
        'kaydeder', () {
      addTearDown(GetIt.I.reset);
      registerDefaultFakes();
      expect(GetIt.I<LocalReminderService>(), isA<FakeLocalReminderService>());
    });

    test(
      'going + 1 sa: tetik anı startsAt − 1 sa, payload event_reminder:<id>; '
      'cancel planı kaldırır',
      () async {
        final clock = FakeAppClock(
          event.startsAt.subtract(const Duration(days: 2)),
        );
        final fake = FakeLocalReminderService(clock);
        expect(going.status, RsvpStatus.going);
        expect(going.reminder, ReminderOption.oneHour);

        await fake.schedule(rsvp: going, event: event);

        final plan = fake.scheduledFor(going.id);
        expect(plan, isNotNull);
        expect(
          plan!.triggerAtUtc,
          event.startsAt.subtract(const Duration(hours: 1)),
        );
        expect(plan.payload, 'event_reminder:${event.id}');
        expect(
          fake.scheduled.keys.single,
          LocalReminderService.notificationId(going.id),
        );

        await fake.cancel(going.id);
        expect(fake.scheduled, isEmpty);
        expect(fake.cancelled, [going.id]);
      },
    );

    test('none, waitlist ve geçmiş tetik anı planlanmaz; yeniden planlama '
        'eskisini ezer', () async {
      final clock = FakeAppClock(
        event.startsAt.subtract(const Duration(minutes: 30)),
      );
      final fake = FakeLocalReminderService(clock);

      await fake.schedule(
        rsvp: going.copyWith(reminder: ReminderOption.fifteenMinutes),
        event: event,
      );
      expect(fake.scheduled, hasLength(1));
      // 1 sa önce geçmişte kalır → önceki plan da kalkar.
      await fake.schedule(rsvp: going, event: event);
      expect(fake.scheduled, isEmpty);

      await fake.schedule(
        rsvp: going.copyWith(reminder: ReminderOption.none),
        event: event,
      );
      await fake.schedule(rsvp: RsvpModelFixtures.e08Mehmet, event: event);
      expect(fake.scheduled, isEmpty);
    });

    test('notificationId kararlı ve pozitif 31 bittir', () {
      final id = LocalReminderService.notificationId(going.id);
      expect(id, LocalReminderService.notificationId(going.id));
      expect(id, inInclusiveRange(0, 0x7fffffff));
      expect(fnv1a32('a'), 0xe40c292c); // FNV-1a başvuru değeri
    });

    test('ensureChannel / cancelAll / rescheduleAll / launchPayload kaydı; '
        'resetFake temizler', () async {
      final fake = FakeLocalReminderService()
        ..launchPayload = 'event_reminder:e01';
      await fake.cancelAll();
      expect(await fake.initialLaunchPayload(), 'event_reminder:e01');
      expect(fake.cancelAllCalls, 1);
      fake.resetFake();
      expect(fake.calls, isEmpty);
      expect(fake.launchPayload, isNull);
      expect(fake.channelEnsured, isFalse);
    });
  });
}
