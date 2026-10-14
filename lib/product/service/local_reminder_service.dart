import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:timezone/data/latest_10y.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Cihazda planlı etkinlik hatırlatıcısı (Q-07; PLAN §10.2, §15.6; CD-08,
/// CD-09). Push yoktur (Mod C).
///
/// * Konum uygulama katmanıdır: `gu_data` Firebase dışı eklenti bilmez,
///   repository'ler bu servisi **bilmez**. Planlama ViewModel'de, repository
///   sonucu başarılıysa yapılır (`EventDetailViewModel` — SHT-12 / SHT-13 /
///   DLG-14; `TicketViewModel` — DLG-14; T-25'te
///   `SessionViewModel.rescheduleAll`).
/// * Bildirim izni bu arayüzde **yoktur**: DLG-03 / NTF-01 `enable` yalnızca
///   `PermissionService.requestNotifications()` çağırır. İzin yokken de plan
///   kurulur; sistem bildirimi göstermez, izin sonradan verilirse plan
///   geçerlidir.
/// * Rsvp başına **tek** plan; kimlik [notificationId] (kararlı FNV-1a).
///   Tetik anı = `event.startsAt − rsvp.reminder` ([triggerAtUtc]); geçmiş an
///   planlanmaz ([plannedTriggerUtc]); sessiz saat uygulanmaz (CD-43).
/// * Android: `AndroidScheduleMode.inexactAllowWhileIdle`;
///   `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` yazılmaz (CD-09).
/// * Hiçbir metot fırlatmaz: platform hatası günlüğe yazılır.
abstract interface class LocalReminderService {
  /// Android bildirim kanalını kurar (kimlik
  /// `AppConstants.reminderChannelId`, ad `l10n.eventReminder`, açıklama
  /// `l10n.notifPrefsEventReminders`) ve [l10n]'u bildirim metinleri için
  /// saklar. Dil değişince yeniden çağrılır.
  Future<void> ensureChannel(AppLocalizations l10n);

  /// [rsvp] için hatırlatıcıyı planlar (aynı kimlikteki eski planın yerine).
  /// Yalnızca `rsvp.status == going`; `rsvp.reminder == none` ya da tetik anı
  /// geçmişse önceki planı iptal eder ve yenisini kurmaz.
  Future<void> schedule({required RsvpModel rsvp, required EventModel event});

  /// [rsvpId] katılımının planını iptal eder (vazgeçme — DLG-14, etkinlik
  /// iptali, `reminder = none`). Yerel bildirim planı iptalidir, veri silme
  /// değildir.
  Future<void> cancel(String rsvpId);

  /// Tüm planları iptal eder (çıkış, hesap silme, [rescheduleAll] başı).
  Future<void> cancelAll();

  /// T-25: açılışta ve ayar değişiminde [cancelAll] + her `going` rsvp için
  /// [schedule]; `settings.eventReminders == false` ⇒ hiçbiri planlanmaz;
  /// `reminder == none ∧ event.autoReminder` ⇒ `settings.reminderTime`.
  Future<void> rescheduleAll({
    required List<RsvpModel> myGoing,
    required Map<String, EventModel> events,
    required UserSettingsModel settings,
  });

  /// Uygulamayı hatırlatıcıya dokunarak soğuk açılışta başlatan bildirimin
  /// yükü; yoksa `null` (CD-72).
  Future<String?> initialLaunchPayload();

  /// Tek payload biçimi: `event_reminder:<eventId>` (§13.1, §15.8).
  static String payloadFor(String eventId) => '$payloadPrefix$eventId';

  /// [payloadFor] öneki.
  static const String payloadPrefix = 'event_reminder:';

  /// [rsvpId] katılımının bildirim kimliği: `fnv1a32(rsvpId) & 0x7fffffff`
  /// (çalıştırmalar arası kararlı, pozitif 31 bit).
  static int notificationId(String rsvpId) =>
      fnv1a32(rsvpId) & _positiveInt31Mask;

  /// [option] seçeneğinin başlangıçtan önceki süresi
  /// (`AppConstants.reminderLeadTimes`); [ReminderOption.none] için `null`.
  static Duration? leadTimeOf(ReminderOption option) =>
      AppConstants.reminderLeadTimes[option];

  /// [rsvp] seçeneğine göre tetik anı (UTC): `event.startsAt − leadTime`;
  /// seçenek `none` ise `null`. Geçmiş an denetimi çağıranın işidir.
  static DateTime? triggerAtUtc({
    required RsvpModel rsvp,
    required EventModel event,
  }) {
    final lead = leadTimeOf(rsvp.reminder);
    return lead == null ? null : event.startsAt.toUtc().subtract(lead);
  }

  /// [schedule]'ın kuracağı tetik anı (UTC) ya da plan yoksa `null`: kayıt
  /// `going` değil, seçenek `none` ya da tetik anı [nowUtc]'den sonra değil.
  static DateTime? plannedTriggerUtc({
    required RsvpModel rsvp,
    required EventModel event,
    required DateTime nowUtc,
  }) {
    if (rsvp.status != RsvpStatus.going) return null;
    final trigger = triggerAtUtc(rsvp: rsvp, event: event);
    if (trigger == null || !trigger.isAfter(nowUtc.toUtc())) return null;
    return trigger;
  }

  static const int _positiveInt31Mask = 0x7fffffff;
}

/// [LocalReminderService] uygulaması: `flutter_local_notifications` +
/// `timezone` (`Europe/Istanbul` — D-26).
///
/// * Eklenti ilk çağrıda bir kez kurulur (`initialize`); saat dilimi
///   veritabanı aynı anda yüklenir ([istanbulTime]). Kurulum bootstrap'a
///   bağlı değildir: [schedule] [ensureChannel]'dan önce de çalışır, bildirim
///   metni o zaman cihaz dilinden üretilir.
/// * iOS `DarwinInitializationSettings` izin istemez (üç `request*Permission`
///   bayrağı `false`); izin `PermissionService`'tedir.
/// * Dokunma yönlendirmesi (`onDidReceiveNotificationResponse`) T-26'dadır;
///   soğuk açılış yükü [initialLaunchPayload].
final class FlutterLocalReminderService implements LocalReminderService {
  /// `plugin` yalnızca testte verilir; `clock` geçmiş tetik denetimi içindir.
  FlutterLocalReminderService({
    FlutterLocalNotificationsPlugin? plugin,
    this._clock = const SystemAppClock(),
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final AppClock _clock;

  /// [ensureChannel] ile verilen yerelleştirme (bildirim metinleri).
  AppLocalizations? _l10n;

  /// Süren / biten eklenti kurulumu (bir kez).
  Future<void>? _initialization;

  /// Hatırlatıcıların saat dilimi (D-26).
  static const String timeZoneName = 'Europe/Istanbul';

  /// Android bildirim küçük ikonu (uygulama ikonu; T-46 tek renkli ikon).
  static const String androidIcon = '@mipmap/ic_launcher';

  /// Eklenti kurulum ayarları: iOS izin **istemez** (PLAN §15.6).
  static const InitializationSettings initializationSettings =
      InitializationSettings(
        android: AndroidInitializationSettings(androidIcon),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );

  static bool _timeZonesLoaded = false;

  /// [utc] anının Istanbul saat dilimindeki karşılığı (`zonedSchedule`
  /// girdisi). Saat dilimi veritabanı ilk çağrıda yüklenir.
  static tz.TZDateTime istanbulTime(DateTime utc) {
    if (!_timeZonesLoaded) {
      tz_data.initializeTimeZones();
      _timeZonesLoaded = true;
    }
    return tz.TZDateTime.from(utc.toUtc(), tz.getLocation(timeZoneName));
  }

  /// Android kanalı — tek tanım (PLAN §14.10): kimlik
  /// `AppConstants.reminderChannelId`, ad `l10n.eventReminder`, açıklama
  /// `l10n.notifPrefsEventReminders`.
  static AndroidNotificationChannel channelOf(AppLocalizations l10n) =>
      AndroidNotificationChannel(
        AppConstants.reminderChannelId,
        l10n.eventReminder,
        description: l10n.notifPrefsEventReminders,
        importance: Importance.high,
      );

  /// Hatırlatıcı bildiriminin platform ayrıntıları ([channelOf] kanalında).
  static NotificationDetails detailsOf(AppLocalizations l10n) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.reminderChannelId,
          l10n.eventReminder,
          channelDescription: l10n.notifPrefsEventReminders,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      );

  @override
  Future<void> ensureChannel(AppLocalizations l10n) async {
    _l10n = l10n;
    await _guard('Hatırlatıcı kanalı kurulamadı', () async {
      await _initialize();
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channelOf(l10n));
    });
  }

  @override
  Future<void> schedule({
    required RsvpModel rsvp,
    required EventModel event,
  }) => _guard('Hatırlatıcı planlanamadı', () async {
    await _initialize();
    final id = LocalReminderService.notificationId(rsvp.id);
    final trigger = LocalReminderService.plannedTriggerUtc(
      rsvp: rsvp,
      event: event,
      nowUtc: _clock.nowUtc(),
    );
    if (trigger == null) {
      await _plugin.cancel(id: id);
      return;
    }
    final l10n = _l10n ?? _deviceL10n();
    final startsAt = AppDateFormats(
      Locale(l10n.localeName),
      _clock,
    ).time(event.startsAt);
    // Aynı kimlikteki eski plan yenisiyle değişir.
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: istanbulTime(trigger),
      notificationDetails: detailsOf(l10n),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: l10n.notifTypeEventReminderTitle(event.title),
      body: l10n.notifTypeEventReminderBody(startsAt),
      payload: LocalReminderService.payloadFor(event.id),
    );
  });

  @override
  Future<void> cancel(String rsvpId) =>
      _guard('Hatırlatıcı iptal edilemedi', () async {
        await _initialize();
        await _plugin.cancel(id: LocalReminderService.notificationId(rsvpId));
      });

  @override
  Future<void> cancelAll() =>
      _guard('Hatırlatıcılar iptal edilemedi', () async {
        await _initialize();
        await _plugin.cancelAll();
      });

  @override
  Future<void> rescheduleAll({
    required List<RsvpModel> myGoing,
    required Map<String, EventModel> events,
    required UserSettingsModel settings,
  }) async {
    // TODO(T-25): settings tercihleri + açılışta yeniden planlama (CD-09).
  }

  @override
  Future<String?> initialLaunchPayload() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (!(details?.didNotificationLaunchApp ?? false)) return null;
      return details?.notificationResponse?.payload;
    } on Object catch (error, stack) {
      AppLogger.warn(
        'Açılış bildirimi okunamadı',
        error: error,
        stackTrace: stack,
      );
      return null;
    }
  }

  /// Eklentiyi bir kez kurar; kurulum hata verirse sonraki çağrı yeniden
  /// dener.
  Future<void> _initialize() async {
    final pending = _initialization ??= _plugin.initialize(
      settings: initializationSettings,
    );
    try {
      await pending;
    } on Object {
      _initialization = null;
      rethrow;
    }
  }

  /// [ensureChannel] çağrılmadıysa cihaz dilinin yerelleştirmesi (desteklenmeyen
  /// dil → Türkçe, uygulamanın varsayılanı).
  static AppLocalizations _deviceL10n() {
    final code = PlatformDispatcher.instance.locale.languageCode;
    final supported = AppLocalizations.supportedLocales.any(
      (locale) => locale.languageCode == code,
    );
    return lookupAppLocalizations(Locale(supported ? code : _defaultLanguage));
  }

  static const String _defaultLanguage = 'tr';

  /// [body] platform çağrısını sarar: hata günlüğe yazılır, fırlatılmaz.
  static Future<void> _guard(
    String what,
    Future<void> Function() body,
  ) async {
    try {
      await body();
    } on Object catch (error, stack) {
      AppLogger.warn(what, error: error, stackTrace: stack);
    }
  }
}
