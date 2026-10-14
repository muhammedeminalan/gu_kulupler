import 'package:flutter/foundation.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/manage/activity_lookups.dart';

/// Faaliyet satırının metni: tam cümle + içindeki kalın yazılan eylemci adı
/// (prototip `<b>actor</b>`, `screens-manage.js:38`).
@immutable
final class ActivityText {
  /// [text] cümlesi; [actorName] cümlenin içinde kalın çizilen ad (boş →
  /// kalın kısım yok).
  const ActivityText({required this.text, required this.actorName});

  /// Tam cümle (`activity.<kind>` ARB metni).
  final String text;

  /// Eylemi yapanın görünen adı.
  final String actorName;

  @override
  bool operator ==(Object other) =>
      other is ActivityText &&
      other.text == text &&
      other.actorName == actorName;

  @override
  int get hashCode => Object.hash(text, actorName);
}

/// Faaliyet kaydının metni — prototip `t('activity.' + a.kind, {actor, user,
/// event, role})` (`screens-manage.js:36`).
///
/// Belge metin taşımaz: metin `activity.<kind>` ARB anahtarlarından,
/// [ActivityLookups] adlarıyla üretilir. Bulunamayan (silinmiş / anonim)
/// kullanıcının yerine "Silinmiş kullanıcı", bulunamayan etkinliğin yerine
/// "İçerik kaldırıldı" yazılır; adı henüz okunmamış kimlik boş kalır.
/// [ActivityKind.unknown] kaydını çağıran listelemez (kategori yok); yine de
/// gelirse yalnızca eylemci adı döner.
final class ActivityTexts {
  /// [_l10n] etkin dilin metinleri.
  const ActivityTexts(this._l10n);

  final AppLocalizations _l10n;

  /// [a] kaydının satır metni.
  ActivityText text(ActivityModel a, ActivityLookups lookups) {
    final l = _l10n;
    final actor = userName(a.actorId, lookups);
    final text = switch (a.kind) {
      ActivityKind.applicationReceived => l.activityApplicationReceived(actor),
      ActivityKind.applicationApproved => l.activityApplicationApproved(
        actor,
        _target(a, lookups),
      ),
      ActivityKind.applicationRejected => l.activityApplicationRejected(
        actor,
        _target(a, lookups),
      ),
      ActivityKind.memberJoined => l.activityMemberJoined(actor),
      ActivityKind.memberLeft => l.activityMemberLeft(actor),
      ActivityKind.memberRemoved => l.activityMemberRemoved(
        actor,
        _target(a, lookups),
      ),
      ActivityKind.roleChanged => l.activityRoleChanged(
        actor,
        _target(a, lookups),
        _role(a.refs.role),
      ),
      ActivityKind.eventPublished => l.activityEventPublished(
        actor,
        _event(a, lookups),
      ),
      ActivityKind.eventCancelled => l.activityEventCancelled(
        actor,
        _event(a, lookups),
      ),
      ActivityKind.postCreated => l.activityPostCreated(actor),
      ActivityKind.announcement => l.activityAnnouncement(actor),
      ActivityKind.poll => l.activityPoll(actor),
      ActivityKind.settingsChanged => l.activitySettingsChanged(actor),
      ActivityKind.unknown => actor,
    };
    return ActivityText(text: text, actorName: actor);
  }

  /// [uid] kullanıcısının görünen adı: okunmadıysa boş; bulunamadı,
  /// silinmiş ya da anonimleştirilmişse "Silinmiş kullanıcı".
  String userName(String uid, ActivityLookups lookups) {
    final user = lookups.users[uid];
    if (user == null) {
      return lookups.missing.contains(uid) ? _l10n.commonDeletedUser : '';
    }
    if (user.isDeleted || user.isAnonymized) return _l10n.commonDeletedUser;
    return user.name;
  }

  String _target(ActivityModel a, ActivityLookups lookups) {
    final uid = a.refs.userId;
    return uid == null ? '' : userName(uid, lookups);
  }

  String _event(ActivityModel a, ActivityLookups lookups) {
    final id = a.refs.eventId;
    if (id == null) return '';
    if (lookups.missing.contains(id)) return _l10n.notifTargetRemoved;
    return lookups.eventTitles[id] ?? '';
  }

  String _role(ClubRole? role) => switch (role) {
    ClubRole.president => _l10n.rolePresident,
    ClubRole.board => _l10n.roleBoard,
    ClubRole.advisor => _l10n.roleAdvisor,
    ClubRole.member => _l10n.roleMember,
    null => '',
  };
}
