// LocalReminderService (Q-07, CD-09; PLAN §10.2, §15.6): saf hesaplar
// (tetik anı, geçmiş tetik, kimlik, payload) + FlutterLocalReminderService'in
// eklenti çağrıları (sahte eklenti): Istanbul saat dilimi, inexact kip,
// kanal, iptal, soğuk açılış yükü, platform hatasının yutulması; T-25
// rescheduleAll (tercih, autoReminder → reminderTime, iptal / geçmiş).
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/service/local_reminder_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../fixtures/event_model_fixtures.dart';
import '../../fixtures/rsvp_model_fixtures.dart';
import '../../helpers/fake_app_clock.dart';

/// Başlangıç 2026-10-08 18:00Z (Istanbul 21:00).
final DateTime _startsAt = DateTime.utc(2026, 10, 8, 18);

final EventModel _event = EventModelFixtures.e01.copyWith(
  startsAt: _startsAt,
  endsAt: _startsAt.add(const Duration(hours: 2)),
);

RsvpModel _rsvp({
  RsvpStatus status = RsvpStatus.going,
  ReminderOption reminder = ReminderOption.oneHour,
}) => RsvpModelFixtures.e01Mehmet.copyWith(status: status, reminder: reminder);

typedef _Scheduled = ({
  int id,
  tz.TZDateTime at,
  AndroidScheduleMode mode,
  String? title,
  String? body,
  String? payload,
  NotificationDetails details,
});

final class _FakeAndroid extends Fake
    implements AndroidFlutterLocalNotificationsPlugin {
  final List<AndroidNotificationChannel> channels = [];

  @override
  Future<void> createNotificationChannel(
    AndroidNotificationChannel notificationChannel,
  ) async => channels.add(notificationChannel);
}

final class _FakePlugin extends Fake
    implements FlutterLocalNotificationsPlugin {
  final _FakeAndroid android = _FakeAndroid();
  final List<InitializationSettings> initialized = [];
  final List<_Scheduled> scheduled = [];
  final List<int> cancelled = [];
  int cancelAllCalls = 0;
  NotificationAppLaunchDetails? launchDetails;
  Error? failSchedule;

  @override
  T? resolvePlatformSpecificImplementation<
    T extends FlutterLocalNotificationsPlatform
  >() => android is T ? android as T : null;

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    initialized.add(settings);
    onResponse = onDidReceiveNotificationResponse;
    return true;
  }

  /// Kurulumda verilen dokunma geri çağrısı.
  DidReceiveNotificationResponseCallback? onResponse;

  @override
  Future<void> zonedSchedule({
    required int id,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? title,
    String? body,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    if (failSchedule case final error?) throw error;
    scheduled.add((
      id: id,
      at: scheduledDate,
      mode: androidScheduleMode,
      title: title,
      body: body,
      payload: payload,
      details: notificationDetails,
    ));
  }

  @override
  Future<void> cancel({required int id, String? tag}) async =>
      cancelled.add(id);

  @override
  Future<void> cancelAll() async => cancelAllCalls++;

  @override
  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async => launchDetails;
}

void main() {
  final tr = lookupAppLocalizations(const Locale('tr'));
  final en = lookupAppLocalizations(const Locale('en'));

  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
  });

  group('LocalReminderService · saf hesaplar', () {
    test('tetik anı = startsAt − seçenek; none → null', () {
      expect(
        LocalReminderService.triggerAtUtc(rsvp: _rsvp(), event: _event),
        DateTime.utc(2026, 10, 8, 17),
      );
      expect(
        LocalReminderService.triggerAtUtc(
          rsvp: _rsvp(reminder: ReminderOption.fifteenMinutes),
          event: _event,
        ),
        DateTime.utc(2026, 10, 8, 17, 45),
      );
      expect(
        LocalReminderService.triggerAtUtc(
          rsvp: _rsvp(reminder: ReminderOption.oneDay),
          event: _event,
        ),
        DateTime.utc(2026, 10, 7, 18),
      );
      expect(
        LocalReminderService.triggerAtUtc(
          rsvp: _rsvp(reminder: ReminderOption.none),
          event: _event,
        ),
        isNull,
      );
    });

    test('plan: yalnızca going; geçmiş ya da şimdiki tetik planlanmaz', () {
      DateTime? planned({
        required DateTime now,
        RsvpStatus status = RsvpStatus.going,
        ReminderOption reminder = ReminderOption.oneHour,
      }) => LocalReminderService.plannedTriggerUtc(
        rsvp: _rsvp(status: status, reminder: reminder),
        event: _event,
        nowUtc: now,
      );
      final before = DateTime.utc(2026, 10, 8, 16);
      expect(planned(now: before), DateTime.utc(2026, 10, 8, 17));
      expect(planned(now: DateTime.utc(2026, 10, 8, 17)), isNull);
      expect(planned(now: DateTime.utc(2026, 10, 8, 17, 30)), isNull);
      expect(planned(reminder: ReminderOption.none, now: before), isNull);
      for (final status in [
        RsvpStatus.waitlist,
        RsvpStatus.cancelled,
        RsvpStatus.attended,
      ]) {
        expect(
          planned(status: status, now: before),
          isNull,
          reason: '$status',
        );
      }
    });

    test('kimlik kararlı FNV-1a (pozitif 31 bit); payload tek biçim', () {
      expect(fnv1a32(''), 0x811c9dc5);
      expect(fnv1a32('a'), 0xe40c292c);
      expect(fnv1a32('foobar'), 0xbf9cf968);
      final id = LocalReminderService.notificationId('e01_u_mehmet');
      expect(id, fnv1a32('e01_u_mehmet') & 0x7fffffff);
      expect(id, LocalReminderService.notificationId('e01_u_mehmet'));
      expect(id, isNonNegative);
      expect(
        id,
        isNot(LocalReminderService.notificationId('e02_u_mehmet')),
      );
      expect(LocalReminderService.payloadFor('e01'), 'event_reminder:e01');
      expect(
        LocalReminderService.payloadFor('e01'),
        startsWith(LocalReminderService.payloadPrefix),
      );
    });

    test('Istanbul saati: 18:00Z − 1 sa → 20:00 Europe/Istanbul', () {
      final at = FlutterLocalReminderService.istanbulTime(
        DateTime.utc(2026, 10, 8, 17),
      );
      expect(at.location.name, 'Europe/Istanbul');
      expect(
        [at.year, at.month, at.day, at.hour, at.minute],
        [2026, 10, 8, 20, 0],
      );
      expect(at.toUtc(), DateTime.utc(2026, 10, 8, 17));
    });
  });

  group('FlutterLocalReminderService · eklenti çağrıları', () {
    late _FakePlugin plugin;
    late FakeAppClock clock;
    late FlutterLocalReminderService service;

    setUp(() {
      plugin = _FakePlugin();
      clock = FakeAppClock(DateTime.utc(2026, 10, 1, 9));
      service = FlutterLocalReminderService(plugin: plugin, clock: clock);
    });

    test('ensureChannel: bir kez kurulum (iOS izin istemez) + Android kanalı '
        'ARB adlarıyla', () async {
      await service.ensureChannel(tr);
      await service.ensureChannel(en);

      expect(plugin.initialized, hasLength(1));
      final ios = plugin.initialized.single.iOS!;
      expect(ios.requestAlertPermission, isFalse);
      expect(ios.requestBadgePermission, isFalse);
      expect(ios.requestSoundPermission, isFalse);
      expect(plugin.initialized.single.android, isNotNull);

      expect(plugin.android.channels, hasLength(2));
      final channel = plugin.android.channels.first;
      expect(channel.id, AppConstants.reminderChannelId);
      expect(channel.id, 'event_reminders');
      expect(channel.name, tr.eventReminder);
      expect(channel.description, tr.notifPrefsEventReminders);
      expect(plugin.android.channels.last.name, en.eventReminder);
    });

    test('schedule: zonedSchedule — kararlı kimlik, Istanbul anı, inexact '
        'kip, ARB metinleri, payload', () async {
      await service.ensureChannel(tr);
      final rsvp = _rsvp();
      await service.schedule(rsvp: rsvp, event: _event);

      final call = plugin.scheduled.single;
      expect(call.id, LocalReminderService.notificationId(rsvp.id));
      expect(call.at.location.name, 'Europe/Istanbul');
      expect(call.at.toUtc(), DateTime.utc(2026, 10, 8, 17));
      expect(call.at.hour, 20);
      expect(call.mode, AndroidScheduleMode.inexactAllowWhileIdle);
      expect(call.title, tr.notifTypeEventReminderTitle(_event.title));
      // Başlangıç Istanbul saatiyle: 18:00Z → 21:00.
      expect(call.body, tr.notifTypeEventReminderBody('21:00'));
      expect(call.payload, 'event_reminder:e01');
      final android = call.details.android!;
      expect(android.channelId, AppConstants.reminderChannelId);
      expect(android.channelName, tr.eventReminder);
      expect(plugin.cancelled, isEmpty);
    });

    test(
      'schedule: ensureChannel öncesi de çalışır (kurulum + cihaz dili)',
      () async {
        await service.schedule(rsvp: _rsvp(), event: _event);
        expect(plugin.initialized, hasLength(1));
        expect(plugin.scheduled, hasLength(1));
        expect(plugin.scheduled.single.title, contains(_event.title));
      },
    );

    test(
      'schedule: none / going değil / geçmiş tetik → yalnızca iptal',
      () async {
        final id = LocalReminderService.notificationId(_rsvp().id);
        await service.schedule(
          rsvp: _rsvp(reminder: ReminderOption.none),
          event: _event,
        );
        await service.schedule(
          rsvp: _rsvp(status: RsvpStatus.cancelled),
          event: _event,
        );
        clock.advance(const Duration(days: 7, hours: 8, minutes: 30));
        await service.schedule(rsvp: _rsvp(), event: _event);

        expect(plugin.scheduled, isEmpty);
        expect(plugin.cancelled, [id, id, id]);
      },
    );

    test('cancel / cancelAll eklentiye iletilir', () async {
      await service.cancel('e01_u_mehmet');
      await service.cancelAll();
      expect(plugin.cancelled, [
        LocalReminderService.notificationId('e01_u_mehmet'),
      ]);
      expect(plugin.cancelAllCalls, 1);
    });

    test('platform hatası fırlatılmaz', () async {
      plugin.failSchedule = StateError('platform');
      await expectLater(
        service.schedule(rsvp: _rsvp(), event: _event),
        completes,
      );
      expect(plugin.scheduled, isEmpty);
    });

    test(
      'initialLaunchPayload: bildirimle açıldıysa yük, değilse null',
      () async {
        expect(await service.initialLaunchPayload(), isNull);
        plugin.launchDetails = const NotificationAppLaunchDetails(false);
        expect(await service.initialLaunchPayload(), isNull);
        plugin.launchDetails = const NotificationAppLaunchDetails(
          true,
          notificationResponse: NotificationResponse(
            notificationResponseType:
                NotificationResponseType.selectedNotification,
            payload: 'event_reminder:e01',
          ),
        );
        expect(await service.initialLaunchPayload(), 'event_reminder:e01');
      },
    );

    test('tappedPayloads: dinlemek eklentiyi kurar; dokunuş yükü iletilir, '
        'yüksüz dokunuş iletilmez (T-26)', () async {
      final taps = <String>[];
      final subscription = service.tappedPayloads.listen(taps.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();
      expect(plugin.initialized, hasLength(1));

      plugin.onResponse!(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: 'event_reminder:e01',
        ),
      );
      plugin.onResponse!(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
        ),
      );
      await pumpEventQueue();
      expect(taps, ['event_reminder:e01']);
    });
  });

  group('FlutterLocalReminderService · rescheduleAll (T-25)', () {
    late _FakePlugin plugin;
    late FlutterLocalReminderService service;

    setUp(() {
      plugin = _FakePlugin();
      service = FlutterLocalReminderService(
        plugin: plugin,
        clock: FakeAppClock(DateTime.utc(2026, 10, 1, 9)),
      );
    });

    EventModel event(
      String id, {
      bool autoReminder = false,
      EventStatus status = EventStatus.published,
      DateTime? startsAt,
    }) => _event.copyWith(
      id: id,
      autoReminder: autoReminder,
      status: status,
      startsAt: startsAt ?? _startsAt,
      endsAt: (startsAt ?? _startsAt).add(const Duration(hours: 2)),
    );

    RsvpModel rsvp(
      String eventId, {
      ReminderOption reminder = ReminderOption.none,
      RsvpStatus status = RsvpStatus.going,
    }) => _rsvp(status: status, reminder: reminder).copyWith(
      id: '${eventId}_u_mehmet',
      eventId: eventId,
    );

    test('cancelAll → yalnızca planlanabilir going kayıtları: kendi seçeneği, '
        'none + autoReminder → settings.reminderTime; iptal / silinmiş / '
        'geçmiş / etkinliği yok / going değil atlanır', () async {
      final events = {
        'e01': event('e01'),
        'e02': event('e02', autoReminder: true),
        'e03': event('e03'),
        'e04': event('e04', status: EventStatus.cancelled),
        'e05': event('e05').copyWith(isDeleted: true),
        'e06': event('e06', startsAt: DateTime.utc(2026, 10, 1, 9, 30)),
      };

      await service.rescheduleAll(
        myGoing: [
          rsvp('e01', reminder: ReminderOption.oneHour),
          rsvp('e02'),
          rsvp('e03'),
          rsvp('e04', reminder: ReminderOption.oneHour),
          rsvp('e05', reminder: ReminderOption.oneHour),
          rsvp('e06', reminder: ReminderOption.oneHour),
          rsvp('e07', reminder: ReminderOption.oneHour),
          rsvp(
            'e01',
            reminder: ReminderOption.oneHour,
            status: RsvpStatus.waitlist,
          ).copyWith(id: 'e01_u_other'),
        ],
        events: events,
        settings: const UserSettingsModel(
          uid: 'u_mehmet',
          reminderTime: ReminderOption.oneDay,
        ),
      );

      expect(plugin.cancelAllCalls, 1);
      expect(plugin.cancelled, isEmpty);
      expect(
        [for (final call in plugin.scheduled) (call.id, call.at.toUtc())],
        [
          (
            LocalReminderService.notificationId('e01_u_mehmet'),
            DateTime.utc(2026, 10, 8, 17),
          ),
          (
            LocalReminderService.notificationId('e02_u_mehmet'),
            DateTime.utc(2026, 10, 7, 18),
          ),
        ],
      );
      expect(plugin.scheduled.last.payload, 'event_reminder:e02');
    });

    test(
      'eventReminders kapalı → tüm planlar iptal, hiçbiri kurulmaz',
      () async {
        await service.rescheduleAll(
          myGoing: [rsvp('e01', reminder: ReminderOption.oneHour)],
          events: {'e01': event('e01', autoReminder: true)},
          settings: const UserSettingsModel(
            uid: 'u_mehmet',
            eventReminders: false,
          ),
        );

        expect(plugin.cancelAllCalls, 1);
        expect(plugin.scheduled, isEmpty);
      },
    );
  });
}
