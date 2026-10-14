import 'package:gu_data/gu_data.dart';
import 'package:gu_ui/gu_ui.dart';

/// Faaliyet türü → satır sonu ikonu — prototip `ACT_ICON`
/// (`screens-manage.js:32`); bilinmeyen tür `info`.
abstract final class ActivityVisuals {
  /// [kind] türünün ikonu.
  static GuIcons icon(ActivityKind kind) => switch (kind) {
    ActivityKind.applicationReceived => GuIcons.userPlus,
    ActivityKind.applicationApproved => GuIcons.userCheck,
    ActivityKind.applicationRejected => GuIcons.userX,
    ActivityKind.memberJoined => GuIcons.userPlus,
    ActivityKind.memberLeft => GuIcons.logOut,
    ActivityKind.memberRemoved => GuIcons.userX,
    ActivityKind.roleChanged => GuIcons.userCog,
    ActivityKind.eventPublished => GuIcons.calendarPlus,
    ActivityKind.eventCancelled => GuIcons.calendarX,
    ActivityKind.postCreated => GuIcons.fileText,
    ActivityKind.announcement => GuIcons.megaphone,
    ActivityKind.poll => GuIcons.chartColumn,
    ActivityKind.settingsChanged => GuIcons.settings,
    ActivityKind.unknown => GuIcons.info,
  };
}
