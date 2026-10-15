import 'dart:async';
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
/// CD-09). Hatırlatıcı Mod F'de (T-42) de yereldir: sunucu `event_reminder`
/// belgesine push göndermez (CD-165).
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
  ///
  /// T-42 (CD-165): uygulamanın tek `flutter_local_notifications` sahibi
  /// olarak push kanallarını da aynı dille kurar
  /// (`FlutterLocalReminderService.pushChannelsOf`: `gu_push` normal,
  /// `gu_push_quiet` sessiz saat — sessiz); push'u sistem gösterir.
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

  /// Tüm planları baştan kurar (açılış, oturum etkinleşmesi, dil değişimi,
  /// NTF-02 kaydı — PLAN §15.6): önce [cancelAll], sonra [myGoing]
  /// kayıtlarının her biri için [effectiveRsvp] seçeneğiyle [schedule].
  ///
  /// `settings.eventReminders == false` ⇒ hiçbiri planlanmaz. [events]'te
  /// olmayan, silinmiş ya da yayında olmayan (iptal, taslak) etkinlik, `going`
  /// olmayan kayıt ve tetik anı geçmiş plan atlanır. Sessiz saat uygulanmaz
  /// (CD-43).
  Future<void> rescheduleAll({
    required List<RsvpModel> myGoing,
    required Map<String, EventModel> events,
    required UserSettingsModel settings,
  });

  /// Uygulamayı hatırlatıcıya dokunarak soğuk açılışta başlatan bildirimin
  /// yükü; yoksa `null` (CD-72).
  Future<String?> initialLaunchPayload();

  /// Uygulama çalışırken (ön ya da arka planda) hatırlatıcıya dokunuşların
  /// yükleri (`onDidReceiveNotificationResponse`; CD-72). Soğuk açılış bu
  /// akışta değildir ([initialLaunchPayload]). Yayın akışıdır; dinlemeye
  /// başlamak eklentiyi kurar. Yükü olmayan dokunuş iletilmez.
  Stream<String> get tappedPayloads;

  /// Tek payload biçimi: `event_reminder:<eventId>` (§13.1, §15.8).
  static String payloadFor(String eventId) => '$payloadPrefix$eventId';

  /// [payloadFor] öneki.
  static const String payloadPrefix = 'event_reminder:';

  /// [payloadFor]'un tersi: `event_reminder:<eventId>` yükünün etkinlik
  /// kimliği; yük yoksa, biçimi tanınmıyorsa ya da kimlik geçersizse `null`
  /// (T-25 soğuk açılış köprüsü; T-26 `NotificationNavigator.parsePayload`
  /// aynı çözümü kullanır).
  static String? eventIdOfPayload(String? payload) {
    if (payload == null || !payload.startsWith(payloadPrefix)) return null;
    final eventId = payload.substring(payloadPrefix.length);
    return RepositoryHelpers.isValidId(eventId) ? eventId : null;
  }

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

  /// [rescheduleAll]'un [rsvp] için kullandığı kayıt: kendi seçeneği
  /// `none` değilse aynen; `none` ve `event.autoReminder` ise seçenek
  /// `settings.reminderTime` olur (PLAN §10.2 — aynı kayda tek plan); aksi
  /// halde `none` kalır (plan yok).
  static RsvpModel effectiveRsvp({
    required RsvpModel rsvp,
    required EventModel event,
    required UserSettingsModel settings,
  }) => rsvp.reminder == ReminderOption.none && event.autoReminder
      ? rsvp.copyWith(reminder: settings.reminderTime)
      : rsvp;

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
/// * Uygulama çalışırken dokunma (`onDidReceiveNotificationResponse`)
///   [tappedPayloads] akışına düşer; yönlendirme `NotificationNavigator
///   .openPayload`'dadır (T-26). Soğuk açılış yükü [initialLaunchPayload].
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

  /// Uygulama çalışırken dokunulan hatırlatıcıların yükleri.
  late final StreamController<String>
  _taps = StreamController<String>.broadcast(
    // Dokunuş yalnızca kurulumda verilen geri çağrıyla gelir: dinleyen varsa
    // eklenti kurulmuş olmalıdır.
    onListen: () =>
        unawaited(_guard('Hatırlatıcı eklentisi kurulamadı', _initialize)),
  );

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

  /// Push kanalları (T-42, CD-165; sunucu `channelId` ile aynı kimlikler):
  /// `AppConstants.pushChannelId` (ad `l10n.navNotifications`, açıklama
  /// `l10n.notifPushChannelDesc`, yüksek önem) ve
  /// `AppConstants.pushQuietChannelId` (ad `l10n.notifPrefsQuiet`, açıklama
  /// `l10n.notifPrefsQuietDesc`; ses ve titreşim yok — sessiz saat).
  static List<AndroidNotificationChannel> pushChannelsOf(
    AppLocalizations l10n,
  ) => [
    AndroidNotificationChannel(
      AppConstants.pushChannelId,
      l10n.navNotifications,
      description: l10n.notifPushChannelDesc,
      importance: Importance.high,
    ),
    AndroidNotificationChannel(
      AppConstants.pushQuietChannelId,
      l10n.notifPrefsQuiet,
      description: l10n.notifPrefsQuietDesc,
      playSound: false,
      enableVibration: false,
    ),
  ];

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
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) return;
      for (final channel in [channelOf(l10n), ...pushChannelsOf(l10n)]) {
        await android.createNotificationChannel(channel);
      }
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
    await cancelAll();
    if (!settings.eventReminders) return;
    final nowUtc = _clock.nowUtc();
    for (final rsvp in myGoing) {
      final event = events[rsvp.eventId];
      // Silinmiş / iptal edilmiş ya da yayında olmayan etkinlik planlanmaz.
      if (event == null ||
          event.isDeleted ||
          event.status != EventStatus.published) {
        continue;
      }
      final planned = LocalReminderService.effectiveRsvp(
        rsvp: rsvp,
        event: event,
        settings: settings,
      );
      // `cancelAll` sonrası plansız kayıt için ayrıca iptal çağrılmaz.
      if (LocalReminderService.plannedTriggerUtc(
            rsvp: planned,
            event: event,
            nowUtc: nowUtc,
          ) ==
          null) {
        continue;
      }
      await schedule(rsvp: planned, event: event);
    }
  }

  @override
  Stream<String> get tappedPayloads => _taps.stream;

  /// Eklentinin dokunma geri çağrısı (ön / arka planda çalışan uygulama).
  void _onResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    _taps.add(payload);
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
      onDidReceiveNotificationResponse: _onResponse,
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
