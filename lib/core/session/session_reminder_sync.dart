import 'dart:async';

import 'package:flutter/foundation.dart' show setEquals;

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/l10n/app_l10n_lookup.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/service/local_reminder_service.dart';

/// Oturumun yerel hatırlatıcı köprüsü (PLAN §15.6; `docs/plans/T-25.md`
/// §6 h). `SessionViewModel` çağırır; oturum kararını (hangi uid, hâlâ
/// geçerli mi) o verir, bu sınıf yalnızca okur ve planlar.
///
/// * [reschedule] — oturum etkinleşince (açılış + giriş) ve dil değişince:
///   kanal yeni dille kurulur, `settings/{uid}` + kendi `going` kayıtları
///   (yalnızca `going` — T-44 · D3-02) birlikte, ardından etkinlikleri okunur,
///   planlar baştan kurulur
///   (`LocalReminderService.rescheduleAll`). Tetik anı geçmiş ama etkinliği
///   henüz bitmemiş hatırlatıcının liste belgesi yazılır (`createSelf` —
///   PLAN §15.6 `event_reminder` satırı; belgesi olan yeniden yazılmaz).
///   Okuma hatasında mevcut planlar korunur. **Bitmiş etkinlik bir daha
///   okunmaz (T-44 · D2-06):** iptal edilmiş ya da bitmiş (yayında,
///   `endsAt ≤ şimdi`) etkinliğin kimliği hesap başına cihazda tutulur
///   (`AppPreferencesStore.reminderDoneEvents`); Rules bu durumları kalıcı
///   kılar (bitmiş etkinlik düzenlenemez, iptal geri alınamaz). Küme `going`
///   kayıtlarıyla kesişir, sınırsız büyümez.
/// * [takeLaunchPayload] — soğuk açılış (CD-72): hatırlatıcıya dokunarak
///   başlatılan uygulamanın yükü (`event_reminder:<eventId>`) döner; biçimi
///   tanınmayan yük atılır. Liste belgesi (`createSelf`), bilet ayrımı ve
///   yönlendirme `NotificationNavigator.openPayload`'dadır (T-26) — kabuk
///   çağırır; uygulama açıkken dokunma da aynı yoldan geçer.
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
    final (settings, mine) = await (
      settingsRepository.getSettings(uid),
      rsvpRepository.listMine(uid, statuses: {RsvpStatus.going}),
    ).wait;
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
    // Bitmiş / iptal etkinlik okunmaz: planı da hatırlatıcı belgesi de yoktur
    // (`rescheduleAll` ve `_hasFired` haritada olmayanı atlar).
    final done = appPreferencesStore.reminderDoneEvents(uid);
    final toRead = [
      for (final rsvp in going)
        if (!done.contains(rsvp.eventId)) rsvp.eventId,
    ];
    final events = <String, EventModel>{};
    if (toRead.isNotEmpty) {
      final read = await eventRepository.getEvents(toRead);
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
    final nowUtc = appClock.nowUtc();
    _rememberFinished(uid, done, going, events.values, nowUtc);
    await localReminderService.rescheduleAll(
      myGoing: going,
      events: events,
      settings: prefs,
    );
    if (!prefs.eventReminders) return;
    for (final rsvp in going) {
      final event = events[rsvp.eventId];
      if (event == null || !_hasFired(rsvp, event, prefs, nowUtc)) continue;
      if (!isCurrent()) return;
      await _recordReminder(uid, event.id, event.clubId);
    }
  }

  /// Soğuk açılışın hatırlatıcı yükü; yük yoksa ya da biçimi tanınmıyorsa
  /// `null` (tanınmayan yük günlüğe düşer).
  Future<String?> takeLaunchPayload() async {
    final payload = await localReminderService.initialLaunchPayload();
    if (payload == null) return null;
    if (LocalReminderService.eventIdOfPayload(payload) == null) {
      AppLogger.warn('Açılış bildirimi yükü tanınmadı: $payload');
      return null;
    }
    return payload;
  }

  /// Tüm planları iptal eder (oturum kapandı).
  Future<void> cancelAll() => localReminderService.cancelAll();

  /// Okunan etkinliklerden bitmiş / iptal olanları [done] kümesine ekler ve
  /// kümeyi yalnızca [going] kayıtlarıyla kesişen hâliyle saklar (değiştiyse).
  void _rememberFinished(
    String uid,
    Set<String> done,
    List<RsvpModel> going,
    Iterable<EventModel> read,
    DateTime nowUtc,
  ) {
    final goingIds = {for (final rsvp in going) rsvp.eventId};
    final finished = {
      ...done,
      for (final event in read)
        if (event.status == EventStatus.cancelled ||
            (event.status == EventStatus.published &&
                !event.endsAt.toUtc().isAfter(nowUtc)))
          event.id,
    }.intersection(goingIds);
    if (setEquals(finished, done)) return;
    unawaited(appPreferencesStore.setReminderDoneEvents(uid, finished));
  }

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
  AppLocalizations _l10n() => appL10nOf(appPreferencesStore.locale);
}
