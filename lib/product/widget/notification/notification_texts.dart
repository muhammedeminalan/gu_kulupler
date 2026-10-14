import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/l10n/cancel_reason_labels.dart';
import 'package:gu_kulupler/product/notification/notification_lookups.dart';

/// Bildirimin başlık ve gövde metni — prototip `notifTitle` / `notifBody` /
/// `notifParams` (`cards.js:136–138`).
///
/// Belge metin taşımaz (T-25 şeması): metin `notifType.<tür>.title|body`
/// ARB anahtarlarından, `refs` kimliklerinin adlarıyla ([NotificationLookups])
/// üretilir. Silinmiş / bulunamayan kulüp, etkinlik ya da gönderinin yerine
/// "İçerik kaldırıldı" (`notifTargetRemoved`), bulunamayan başvuranın yerine
/// "Silinmiş kullanıcı" yazılır; adı henüz okunmamış kimlik boş kalır
/// (prototipteki gibi). Sistem bildirimi `refs.textKey` ile seçilir
/// (`welcome` varsayılan).
final class NotificationTexts {
  /// [_l10n] etkin dilin metinleri; saat [_formats] ile (Istanbul) yazılır.
  const NotificationTexts(this._l10n, this._formats);

  final AppLocalizations _l10n;
  final AppDateFormats _formats;

  /// Sistem bildiriminin "bakım" metin anahtarı (`refs.textKey`).
  static const String maintenanceKey = 'maintenance';

  /// [n] bildiriminin başlığı.
  String title(NotificationModel n, NotificationLookups lookups) {
    final l = _l10n;
    return switch (n.type) {
      NotificationType.applicationReceived =>
        l.notifTypeApplicationReceivedTitle,
      NotificationType.applicationApproved =>
        l.notifTypeApplicationApprovedTitle,
      NotificationType.applicationRejected =>
        l.notifTypeApplicationRejectedTitle,
      NotificationType.removedFromClub => l.notifTypeRemovedFromClubTitle,
      NotificationType.roleChanged => l.notifTypeRoleChangedTitle,
      NotificationType.announcement => l.notifTypeAnnouncementTitle(
        _club(n, lookups),
      ),
      NotificationType.eventNew => l.notifTypeEventNewTitle(_event(n, lookups)),
      NotificationType.eventReminder => l.notifTypeEventReminderTitle(
        _event(n, lookups),
      ),
      NotificationType.eventCancelled => l.notifTypeEventCancelledTitle,
      NotificationType.waitlistPromoted => l.notifTypeWaitlistPromotedTitle,
      NotificationType.reportResolved => l.notifTypeReportResolvedTitle,
      NotificationType.newReport => l.notifTypeNewReportTitle,
      NotificationType.system || NotificationType.unknown =>
        n.refs.textKey == maintenanceKey
            ? l.notifTypeSystemMaintenanceTitle
            : l.systemWelcomeTitle,
    };
  }

  /// [n] bildiriminin gövdesi.
  String body(NotificationModel n, NotificationLookups lookups) {
    final l = _l10n;
    return switch (n.type) {
      NotificationType.applicationReceived =>
        l.notifTypeApplicationReceivedBody(
          _user(n, lookups),
          _club(n, lookups),
        ),
      NotificationType.applicationApproved =>
        l.notifTypeApplicationApprovedBody(
          _club(n, lookups),
        ),
      NotificationType.applicationRejected =>
        l.notifTypeApplicationRejectedBody(
          _club(n, lookups),
        ),
      NotificationType.removedFromClub => l.notifTypeRemovedFromClubBody(
        _club(n, lookups),
      ),
      NotificationType.roleChanged => l.notifTypeRoleChangedBody(
        _club(n, lookups),
        _role(n.refs.role),
      ),
      NotificationType.announcement => l.notifTypeAnnouncementBody(
        _post(n, lookups),
      ),
      NotificationType.eventNew => l.notifTypeEventNewBody(_club(n, lookups)),
      NotificationType.eventReminder => l.notifTypeEventReminderBody(
        _eventTime(n, lookups),
      ),
      NotificationType.eventCancelled => l.notifTypeEventCancelledBody(
        _event(n, lookups),
        _cancelReason(n, lookups),
      ),
      NotificationType.waitlistPromoted => l.notifTypeWaitlistPromotedBody(
        _event(n, lookups),
      ),
      NotificationType.reportResolved => l.notifTypeReportResolvedBody,
      NotificationType.newReport => l.notifTypeNewReportBody,
      NotificationType.system || NotificationType.unknown =>
        n.refs.textKey == maintenanceKey
            ? l.notifTypeSystemMaintenanceBody
            : l.notifTypeSystemWelcomeBody,
    };
  }

  String _club(NotificationModel n, NotificationLookups lookups) =>
      _named(n.refs.clubId, lookups.clubNames, lookups);

  String _post(NotificationModel n, NotificationLookups lookups) =>
      _named(n.refs.postId, lookups.postTitles, lookups);

  String _event(NotificationModel n, NotificationLookups lookups) {
    final id = n.refs.eventId;
    if (id == null) return '';
    if (lookups.events[id] case final event?) return event.title;
    return lookups.missing.contains(id) ? _l10n.notifTargetRemoved : '';
  }

  String _eventTime(NotificationModel n, NotificationLookups lookups) =>
      switch (lookups.events[n.refs.eventId]) {
        final event? => _formats.time(event.startsAt),
        null => '',
      };

  String _cancelReason(NotificationModel n, NotificationLookups lookups) =>
      CancelReasonLabels.of(
        _l10n,
        lookups.events[n.refs.eventId]?.cancelReason,
      ) ??
      '';

  String _user(NotificationModel n, NotificationLookups lookups) {
    final id = n.refs.applicantId;
    if (id == null) return '';
    if (lookups.userNames[id] case final name?) return name;
    return lookups.missing.contains(id) ? _l10n.commonDeletedUser : '';
  }

  String _named(
    String? id,
    Map<String, String> names,
    NotificationLookups lookups,
  ) {
    if (id == null) return '';
    if (names[id] case final name?) return name;
    return lookups.missing.contains(id) ? _l10n.notifTargetRemoved : '';
  }

  String _role(ClubRole? role) => switch (role) {
    ClubRole.president => _l10n.rolePresident,
    ClubRole.board => _l10n.roleBoard,
    ClubRole.advisor => _l10n.roleAdvisor,
    ClubRole.member => _l10n.roleMember,
    null => '',
  };
}
