import 'package:gu_data/gu_data.dart';
import 'package:gu_ui/gu_ui.dart';

/// Bildirim türünün ikonu ve `ni-*` zemini — prototip `NOTIF_ICON`
/// (`cards.js:134`; `registry.json#notifIcon`, 13 tür).
///
/// Tanınmayan tür ([NotificationType.unknown]) `system` görünümünü alır
/// (prototip `NOTIF_ICON[n.type] || NOTIF_ICON.system`).
abstract final class NotificationVisuals {
  /// [type] türünün (ikon, ton) çifti.
  static (GuIcons, GuIconBoxTone) of(NotificationType type) => switch (type) {
    NotificationType.applicationReceived => (
      GuIcons.userPlus,
      GuIconBoxTone.brand,
    ),
    NotificationType.applicationApproved => (
      GuIcons.circleCheck,
      GuIconBoxTone.success,
    ),
    NotificationType.applicationRejected => (
      GuIcons.circleX,
      GuIconBoxTone.danger,
    ),
    NotificationType.removedFromClub => (GuIcons.userX, GuIconBoxTone.danger),
    NotificationType.roleChanged => (GuIcons.userCog, GuIconBoxTone.info),
    NotificationType.announcement => (GuIcons.megaphone, GuIconBoxTone.brand),
    NotificationType.eventNew => (GuIcons.calendarPlus, GuIconBoxTone.info),
    NotificationType.eventReminder => (
      GuIcons.bellRing,
      GuIconBoxTone.warning,
    ),
    NotificationType.eventCancelled => (
      GuIcons.calendarX,
      GuIconBoxTone.danger,
    ),
    NotificationType.waitlistPromoted => (
      GuIcons.ticket,
      GuIconBoxTone.success,
    ),
    NotificationType.reportResolved => (
      GuIcons.shieldCheck,
      GuIconBoxTone.success,
    ),
    NotificationType.newReport => (GuIcons.flag, GuIconBoxTone.warning),
    NotificationType.system ||
    NotificationType.unknown => (GuIcons.info, GuIconBoxTone.neutral),
  };
}
