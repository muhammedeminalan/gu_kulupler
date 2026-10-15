import 'package:gu_data/src/models/enums/notification_type.dart';
import 'package:gu_data/src/models/notification_model.dart';
import 'package:gu_data/src/models/user_settings_model.dart';

/// Gelen kutusunun okuma süzgeci (Mod C: **okuyan taraf süzer** — PLAN
/// §15.5, §10.4 "Okuma süzgeci"; architecture §7; `docs/plans/T-25.md` §6 e).
///
/// Yazan taraf (dağıtıcı) tercihe bakmaz: başkasının `settings/{uid}`
/// belgesi okunamaz, belge her alıcıya yazılır. Görünürlük burada, alıcının
/// kendi tercihleriyle karar verilir; Mod F'de (sunucu tetikleyicisi — CD-147)
/// süzgeç aynen kalır, sunucu yalnızca push teslimini ayrıca keser
/// (T-42: `functions/src/lib/preference_filter.ts` birebir kopyadır; ortak
/// sözleşme `firebase/test/contracts/push_contract.json` iki tarafı sınar).
///
/// | Koşul | Sonuç |
/// |---|---|
/// | [forced] türleri | her zaman görünür |
/// | `application_received` ∧ `!management` | gizli |
/// | `application_approved` / `_rejected` ∧ `!applicationResults` | gizli |
/// | `announcement` ∧ (`!announcements` ∨ kulüp sessiz ∨ kulüpte duyuru kapalı) | gizli |
/// | `event_new` ∧ (`!newEvents` ∨ kulüp sessiz ∨ kulüpte etkinlik kapalı) | gizli |
/// | `event_reminder` ∧ `!eventReminders` | gizli |
/// | `system` ∧ `!system` | gizli |
/// | tanınmayan tür (`unknown`) | gizli |
///
/// Sessiz saat (`quiet*`) Mod C'de listeyi ve rozeti **etkilemez** (CD-43).
/// Okunmamış sayısı süzülmüş listeden sayılır (gizlenenler sayılmaz).
abstract final class NotificationPreferenceFilter {
  /// Tercihten bağımsız her zaman görünen türler (PLAN §15.5 `force`).
  static const Set<NotificationType> forced = {
    NotificationType.removedFromClub,
    NotificationType.roleChanged,
    NotificationType.eventCancelled,
    NotificationType.waitlistPromoted,
    NotificationType.reportResolved,
    NotificationType.newReport,
  };

  /// [notification] [settings] sahibinin gelen kutusunda görünür mü?
  static bool allows(
    NotificationModel notification,
    UserSettingsModel settings,
  ) {
    final type = notification.type;
    if (forced.contains(type)) return true;
    final club = switch (notification.refs.clubId) {
      final clubId? => settings.clubs[clubId],
      null => null,
    };
    final clubMuted = club?.muted ?? false;
    return switch (type) {
      NotificationType.applicationReceived => settings.management,
      NotificationType.applicationApproved ||
      NotificationType.applicationRejected => settings.applicationResults,
      NotificationType.announcement =>
        settings.announcements && !clubMuted && (club?.announcements ?? true),
      NotificationType.eventNew =>
        settings.newEvents && !clubMuted && (club?.events ?? true),
      NotificationType.eventReminder => settings.eventReminders,
      NotificationType.system => settings.system,
      NotificationType.unknown => false,
      // `forced` türleri yukarıda döndü.
      NotificationType.removedFromClub ||
      NotificationType.roleChanged ||
      NotificationType.eventCancelled ||
      NotificationType.waitlistPromoted ||
      NotificationType.reportResolved ||
      NotificationType.newReport => true,
    };
  }

  /// [items] içinden [settings] sahibine görünenler (sıra korunur).
  static List<NotificationModel> apply(
    UserSettingsModel settings,
    List<NotificationModel> items,
  ) => [
    for (final item in items)
      if (allows(item, settings)) item,
  ];
}
