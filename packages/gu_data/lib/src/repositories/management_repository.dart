import 'package:gu_data/src/core/bulk_result.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/core/role_policy.dart';
import 'package:gu_data/src/models/club_settings_patch.dart';
import 'package:gu_data/src/models/enums/club_role.dart';
import 'package:gu_data/src/models/enums/reject_reason.dart';
import 'package:gu_data/src/models/post_draft.dart';
import 'package:gu_data/src/models/post_model.dart';

/// Kulüp yönetim paneli (MGT-*) yazımlarının tek kapısı (PLAN §10.4
/// `ManagementRepository`; sözleşme `docs/plans/T-30.md` §4).
///
/// **Kompozisyondur:** üyelik kararları `MembershipRepository`'ye, etkinlik
/// yayın / iptal `EventRepository`'ye, gönderi yayın / sabitleme / moderasyon
/// `PostRepository` / `CommentRepository`'ye devredilir; bu sınıf asıl
/// yazım **kesinleştikten sonra** çok alıcılı bildirimi (fan-out:
/// `event_new`, `event_cancelled`, `announcement`) `NotificationDispatcher`
/// ile dağıtır. Tek alıcılı kritik bildirimler (karar, çıkarma, rol, devir)
/// devredilen geçişin kendi transaction'ındadır. Kendi yazdığı tek belge
/// kulüp ayarlarıdır ([updateClubSettings]).
///
/// Fan-out hatası çağıranın sonucunu bozmaz (bildirim en iyi çaba —
/// rules-spec §5). Yetkiyi Security Rules uygular; danışman hiçbir yazımı
/// yapamaz (Q-09 — [isReadOnly] ile ViewModel önceden engeller).
abstract interface class ManagementRepository {
  /// M5 — `MembershipRepository.approve`; `application_approved` bildirimi
  /// aynı işlemdedir.
  Future<FirestoreResult<void>> approveApplication({
    required String clubId,
    required String userId,
    required String actorId,
  });

  /// M6 — `MembershipRepository.reject`; `application_rejected` bildirimi
  /// aynı işlemdedir.
  Future<FirestoreResult<void>> rejectApplication({
    required String clubId,
    required String userId,
    required String actorId,
    required RejectReason reason,
    String rejectNote = '',
  });

  /// M12 (a) — `MembershipRepository.undoDecision` (30 sn; TST-27 / TST-28
  /// "Geri al").
  Future<FirestoreResult<void>> undoDecision({
    required String clubId,
    required String userId,
    required String actorId,
  });

  /// M12 (b) — `MembershipRepository.undoRemoval` (30 sn; TST-47 "Geri al").
  Future<FirestoreResult<void>> undoRemoval({
    required String clubId,
    required String userId,
    required String actorId,
  });

  /// DLG-17 toplu onay: [userIds] başvurularının **her biri ayrı**
  /// [approveApplication] işlemidir (sırayla); çakışan başvuru
  /// [BulkResult.conflicted]'a, başka hatayla yazılamayan
  /// [BulkResult.failed]'a düşer. Sonuç her zaman [FirebaseSuccess]'tir;
  /// geçersiz [clubId] / [actorId] → [FirestoreError.invalidArgument].
  Future<FirestoreResult<BulkResult>> approveMany({
    required String clubId,
    required List<String> userIds,
    required String actorId,
  });

  /// DLG-17 toplu ret — [approveMany] gibi; her başvuru aynı [reason] ve
  /// [rejectNote] ile ayrı [rejectApplication] işlemidir.
  Future<FirestoreResult<BulkResult>> rejectMany({
    required String clubId,
    required List<String> userIds,
    required String actorId,
    required RejectReason reason,
    String rejectNote = '',
  });

  /// M9 — `MembershipRepository.remove`; `removed_from_club` bildirimi aynı
  /// işlemdedir.
  Future<FirestoreResult<void>> removeMember({
    required String clubId,
    required String userId,
    required String actorId,
    required ClubRole actorRole,
    bool actorIsSuper = false,
    String rejectNote = '',
  });

  /// M10 — `MembershipRepository.changeRole`; `role_changed` bildirimi aynı
  /// işlemdedir.
  Future<FirestoreResult<void>> changeRole({
    required String clubId,
    required String userId,
    required ClubRole role,
    required String actorId,
  });

  /// M11 — `MembershipRepository.transferPresidency` (tek işlem; iki
  /// `role_changed` bildirimi).
  Future<FirestoreResult<void>> transferPresidency({
    required String clubId,
    required String fromUserId,
    required String toUserId,
    required String actorId,
  });

  /// MGT-09 — kulüp ayarlarını [patch] ile günceller: **tek batch**
  /// `clubs/{clubId}` update (yalnızca yamanın alanları + `updatedAt`) +
  /// `settings_changed` günlüğü. Bildirim yoktur.
  ///
  /// Hatalar: boş yama ya da sınır dışı alan (`Limits.clubSummaryMax`,
  /// `clubAboutMax`, `conditionsMax`, `instagramHandlePattern`) →
  /// [FirestoreError.invalidArgument]; kulüp yok / silinmiş →
  /// [FirestoreError.notFound]; yönetici olmayan ya da askıdaki kulüp →
  /// Rules [FirestoreError.permissionDenied].
  Future<FirestoreResult<void>> updateClubSettings(
    String clubId,
    ClubSettingsPatch patch, {
    required String actorId,
  });

  /// MGT-05 / DLG-22 — `EventRepository.publish` (taslak → yayında +
  /// `event_published` günlüğü); [notifyMembers] ise yayın kesinleşince
  /// `event_new` fan-out: alıcılar `RecipientResolver.eventNew(event, club)`
  /// (yayıncı ve danışman hariç; public etkinlikte ilgi eşleşmesi ≤
  /// `Limits.eventNewInterestFanOutMax` — CD-38).
  Future<FirestoreResult<void>> publishEvent(
    String eventId, {
    required String clubId,
    required String actorId,
    required bool notifyMembers,
  });

  /// DLG-12 — `EventRepository.cancel` (yayında → iptal + `event_cancelled`
  /// günlüğü); kesinleşince `event_cancelled` fan-out (tercihe bakılmaz):
  /// alıcılar `RecipientResolver.rsvpUsersOf(eventId, clubId, {going,
  /// waitlist})`.
  Future<FirestoreResult<void>> cancelEvent(
    String eventId, {
    required String clubId,
    required String reason,
    required String actorId,
  });

  /// K-F — `EventRepository.unpublish` (kayıtlısı olan etkinlik taslağa
  /// alınamaz → [FirestoreRuleCode.eventHasRegistrations]).
  Future<FirestoreResult<void>> unpublishEvent(String eventId);

  /// MGT-08 — `PostRepository.create`; `announcement && pushSent` ise
  /// kesinleşince `announcement` fan-out (yazar ve danışman hariç —
  /// `RecipientResolver.membersOf(clubId, excludeUserId: authorId)`).
  Future<FirestoreResult<PostModel>> publishPost(
    PostDraft draft, {
    required String clubId,
    required String authorId,
    required String postId,
  });

  /// `PostRepository.pin` (kulüp başına tek sabit gönderi).
  Future<FirestoreResult<void>> pinPost(
    String postId, {
    required String clubId,
  });

  /// `PostRepository.unpin` (TST-53).
  Future<FirestoreResult<void>> unpinPost(
    String postId, {
    required String clubId,
  });

  /// DLG-29 / TST-51 — başkasının gönderisini kaldırır
  /// (`PostRepository.softDeletePost`; geri alma `PostRepository.restorePost`
  /// — TST-45).
  Future<FirestoreResult<void>> moderatePost(
    String postId, {
    required String clubId,
    required String actorId,
  });

  /// DLG-29 / TST-51 — başkasının yorumunu kaldırır
  /// (`CommentRepository.softDeleteComment`; geri alma
  /// `CommentRepository.restoreComment` — TST-45).
  Future<FirestoreResult<void>> moderateComment(
    String commentId, {
    required String postId,
    required String clubId,
    required String actorId,
  });

  /// [access] kipindeki kullanıcı için yönetim paneli salt okunur mu?
  /// `ClubAccess.advisor` → `true` (TST-26; Q-09). Ağ çağrısı yapmaz.
  bool isReadOnly(ClubAccess access);
}
