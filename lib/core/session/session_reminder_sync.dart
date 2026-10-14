import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/service/local_reminder_service.dart';

/// Oturumun yerel hatırlatıcı köprüsü (PLAN §15.6; `docs/plans/T-25.md`
/// §6 h). `SessionViewModel` çağırır; oturum kararını (hangi uid, hâlâ
/// geçerli mi) o verir, bu sınıf yalnızca okur ve planlar.
///
/// * [reschedule] — oturum etkinleşince (açılış + giriş) ve dil değişince:
///   kanal yeni dille kurulur, `settings/{uid}` + kendi `going` kayıtları +
///   etkinlikleri okunur, planlar baştan kurulur
///   (`LocalReminderService.rescheduleAll`). Tetik anı geçmiş ama etkinliği
///   henüz bitmemiş hatırlatıcının liste belgesi yazılır (`createSelf` —
///   PLAN §15.6 `event_reminder` satırı; belgesi olan yeniden yazılmaz).
///   Okuma hatasında mevcut planlar korunur.
/// * [takeLaunchEventId] — soğuk açılış (CD-72): hatırlatıcıya dokunarak
///   başlatılan uygulamanın yükü `event_reminder:<eventId>` çözülür,
///   hatırlatıcının liste belgesi yazılır (en iyi çaba) ve etkinlik kimliği
///   döner; yönlendirmeyi kabuk yapar (`EventDetailRoute`). Ön planda dokunma
///   ve `NotificationNavigator.openPayload` (bilet ayrımı) T-26'dadır.
///
/// Hiçbir metot fırlatmaz: okuma / yazma hatası günlüğe düşer.
final class SessionReminderSync with ProjectDependencyMixin {
  /// [uid] kullanıcısının hatırlatıcılarını baştan kurar. [isCurrent]
  /// okumalardan sonra sorulur: `false` ise (oturum değişti / kapandı) plan
  /// kurulmaz.
  Future<void> reschedule(
    String uid, {
    required bool Function() isCurrent,
  }) async {
    await localReminderService.ensureChannel(_l10n());
    final settings = await settingsRepository.getSettings(uid);
    final mine = await rsvpRepository.listMine(uid);
    if (!isCurrent()) return;
    final UserSettingsModel prefs;
    final List<RsvpModel> rsvps;
    switch ((settings, mine)) {
      case (FirebaseSuccess(data: final read), FirebaseSuccess(:final data)):
        prefs = read;
        rsvps = data;
      default:
        AppLogger.warn(
          'Hatırlatıcılar yeniden kurulamadı: '
          '${settings.errorOrNull?.name ?? mine.errorOrNull?.name}',
        );
        return;
    }
    final going = [
      for (final rsvp in rsvps)
        if (rsvp.status == RsvpStatus.going && !rsvp.isDeleted) rsvp,
    ];
    final events = <String, EventModel>{};
    if (going.isNotEmpty) {
      final read = await eventRepository.getEvents([
        for (final rsvp in going) rsvp.eventId,
      ]);
      if (!isCurrent()) return;
      switch (read) {
        case FirebaseSuccess(:final data):
          for (final event in data) {
            events[event.id] = event;
          }
        case FirebaseFailure(:final error):
          AppLogger.warn('Hatırlatıcı etkinlikleri okunamadı: ${error.name}');
          return;
      }
    }
    await localReminderService.rescheduleAll(
      myGoing: going,
      events: events,
      settings: prefs,
    );
    if (!prefs.eventReminders) return;
    final nowUtc = appClock.nowUtc();
    for (final rsvp in going) {
      final event = events[rsvp.eventId];
      if (event == null || !_hasFired(rsvp, event, prefs, nowUtc)) continue;
      if (!isCurrent()) return;
      await _recordReminder(uid, event.id, event.clubId);
    }
  }

  /// Soğuk açılışın hatırlatıcı yükündeki etkinlik kimliği; yük yoksa ya da
  /// biçimi tanınmıyorsa `null`. [uid] oturumun kendi kimliğidir (liste
  /// belgesi ona yazılır).
  Future<String?> takeLaunchEventId(String uid) async {
    final eventId = LocalReminderService.eventIdOfPayload(
      await localReminderService.initialLaunchPayload(),
    );
    if (eventId == null) return null;
    // Kulüp kimliği etkinlikten okunur; okunamazsa (silinmiş, yetki) belge
    // yazılmaz, etkinlik ekranı kendi durumunu gösterir.
    switch (await eventRepository.getEvent(eventId)) {
      case FirebaseSuccess(data: final event):
        await _recordReminder(uid, event.id, event.clubId);
      case FirebaseFailure(:final error):
        AppLogger.warn('Hatırlatıcı etkinliği okunamadı: ${error.name}');
    }
    return eventId;
  }

  /// Tüm planları iptal eder (oturum kapandı).
  Future<void> cancelAll() => localReminderService.cancelAll();

  /// Tetik anı geçmiş ama etkinliği bitmemiş hatırlatıcı mı (yayındaki,
  /// silinmemiş etkinlikte, seçenek `none` değil)?
  static bool _hasFired(
    RsvpModel rsvp,
    EventModel event,
    UserSettingsModel settings,
    DateTime nowUtc,
  ) {
    if (event.isDeleted || event.status != EventStatus.published) {
      return false;
    }
    final trigger = LocalReminderService.triggerAtUtc(
      rsvp: LocalReminderService.effectiveRsvp(
        rsvp: rsvp,
        event: event,
        settings: settings,
      ),
      event: event,
    );
    return trigger != null &&
        !trigger.isAfter(nowUtc) &&
        event.endsAt.toUtc().isAfter(nowUtc);
  }

  Future<void> _recordReminder(
    String uid,
    String eventId,
    String clubId,
  ) async {
    final written = await notificationRepository.createSelf(
      userId: uid,
      eventId: eventId,
      clubId: clubId,
    );
    if (written case FirebaseFailure(:final error)) {
      AppLogger.warn('Hatırlatıcı bildirimi yazılamadı: ${error.name}');
    }
  }

  /// Bildirim metinlerinin dili: uygulama tercihi, yoksa cihaz dili
  /// (desteklenmeyen dil → Türkçe — PLAN §14.10).
  AppLocalizations _l10n() {
    final code =
        (appPreferencesStore.locale ?? PlatformDispatcher.instance.locale)
            .languageCode;
    final supported = AppLocalizations.supportedLocales.any(
      (locale) => locale.languageCode == code,
    );
    return lookupAppLocalizations(Locale(supported ? code : _fallbackLanguage));
  }

  static const String _fallbackLanguage = 'tr';
}
