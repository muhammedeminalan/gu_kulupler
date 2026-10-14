// `ManagementRepository` fake'i (PLAN §16.3; T-30): gerçek repository gibi
// **kompozisyondur** — üyelik kararları kayıtlı `MembershipRepository`
// fake'ine, etkinlik yayın / iptal `EventRepository`'ye, gönderi ve yorum
// `PostRepository` / `CommentRepository`'ye devredilir. Kendi yazdığı tek
// belge kulüp ayarlarıdır (`FakeClubRepository` belleğinde).
//
//   final management = FakeManagementRepository(
//     memberships: memberships, events: events, posts: posts,
//     comments: comments, clubs: clubs,
//   );
//   await management.approveMany(clubId: 'c01', userIds: ['u1', 'u2'], actorId: 'u_b');
//   expect(management.fanOuts.single.kind, NotificationType.eventCancelled);
//
// Fan-out yalnızca asıl yazım başarılıysa [FakeManagementRepository.fanOuts]
// listesine düşer (alıcı çözümü yok; gerçek dağıtım en iyi çabadır ve sonucu
// bozmaz). Ayar yaması gerçek repository ile aynı sınırları denetler; yetki
// (danışman, başka kulübün yöneticisi, askıdaki kulüp) Rules'tadır — test
// `failNext(FirestoreError.permissionDenied)` ile kurar. `failNext` bir
// sonraki çağrıyı (devredilen dahil) düşürür. Silme metodu yoktur (D-10).
import 'package:gu_data/gu_data.dart';

import 'fake_base.dart';
import 'fake_club_repository.dart';

/// Kesinleşmiş asıl yazımın ardından istenen fan-out: tür ve olayın kimliği
/// (`event_new` / `event_cancelled` → etkinlik, `announcement` → gönderi).
typedef FakeFanOut = ({NotificationType kind, String clubId, String id});

/// Başarılı `updateClubSettings` çağrısı.
typedef FakeSettingsUpdate = ({
  String clubId,
  ClubSettingsPatch patch,
  String actorId,
});

final class FakeManagementRepository extends FakeBase
    implements ManagementRepository {
  /// Devredilen yazımlar verilen repository'lerde; ayarlar [clubs]
  /// belleğinde (`registerDefaultFakes` kayıtlı örnekleri paylaştırır).
  FakeManagementRepository({
    required this.memberships,
    required this.events,
    required this.posts,
    required this.comments,
    required this.clubs,
  });

  final MembershipRepository memberships;
  final EventRepository events;
  final PostRepository posts;
  final CommentRepository comments;
  final FakeClubRepository clubs;

  /// İstenen fan-out'lar, sırasıyla.
  final List<FakeFanOut> fanOuts = <FakeFanOut>[];

  /// Başarılı ayar güncellemeleri, sırasıyla.
  final List<FakeSettingsUpdate> settingsUpdates = <FakeSettingsUpdate>[];

  @override
  Future<FirestoreResult<void>> approveApplication({
    required String clubId,
    required String userId,
    required String actorId,
  }) async {
    record('approveApplication', [clubId, userId, actorId]);
    return _injected<void>() ??
        await memberships.approve(
          clubId: clubId,
          userId: userId,
          actorId: actorId,
        );
  }

  @override
  Future<FirestoreResult<void>> rejectApplication({
    required String clubId,
    required String userId,
    required String actorId,
    required RejectReason reason,
    String rejectNote = '',
  }) async {
    record('rejectApplication', [clubId, userId, actorId, reason, rejectNote]);
    return _injected<void>() ??
        await memberships.reject(
          clubId: clubId,
          userId: userId,
          actorId: actorId,
          reason: reason,
          rejectNote: rejectNote,
        );
  }

  @override
  Future<FirestoreResult<void>> undoDecision({
    required String clubId,
    required String userId,
    required String actorId,
  }) async {
    record('undoDecision', [clubId, userId, actorId]);
    return _injected<void>() ??
        await memberships.undoDecision(
          clubId: clubId,
          userId: userId,
          actorId: actorId,
        );
  }

  @override
  Future<FirestoreResult<void>> undoRemoval({
    required String clubId,
    required String userId,
    required String actorId,
  }) async {
    record('undoRemoval', [clubId, userId, actorId]);
    return _injected<void>() ??
        await memberships.undoRemoval(
          clubId: clubId,
          userId: userId,
          actorId: actorId,
        );
  }

  @override
  Future<FirestoreResult<BulkResult>> approveMany({
    required String clubId,
    required List<String> userIds,
    required String actorId,
  }) async {
    record('approveMany', [clubId, userIds, actorId]);
    return _bulk(
      clubId,
      actorId,
      userIds,
      (userId) =>
          memberships.approve(clubId: clubId, userId: userId, actorId: actorId),
    );
  }

  @override
  Future<FirestoreResult<BulkResult>> rejectMany({
    required String clubId,
    required List<String> userIds,
    required String actorId,
    required RejectReason reason,
    String rejectNote = '',
  }) async {
    record('rejectMany', [clubId, userIds, actorId, reason, rejectNote]);
    return _bulk(
      clubId,
      actorId,
      userIds,
      (userId) => memberships.reject(
        clubId: clubId,
        userId: userId,
        actorId: actorId,
        reason: reason,
        rejectNote: rejectNote,
      ),
    );
  }

  @override
  Future<FirestoreResult<void>> removeMember({
    required String clubId,
    required String userId,
    required String actorId,
    required ClubRole actorRole,
    bool actorIsSuper = false,
    String rejectNote = '',
  }) async {
    record('removeMember', [clubId, userId, actorId, actorRole, actorIsSuper]);
    return _injected<void>() ??
        await memberships.remove(
          clubId: clubId,
          userId: userId,
          actorId: actorId,
          actorRole: actorRole,
          actorIsSuper: actorIsSuper,
          rejectNote: rejectNote,
        );
  }

  @override
  Future<FirestoreResult<void>> changeRole({
    required String clubId,
    required String userId,
    required ClubRole role,
    required String actorId,
  }) async {
    record('changeRole', [clubId, userId, role, actorId]);
    return _injected<void>() ??
        await memberships.changeRole(
          clubId: clubId,
          userId: userId,
          role: role,
          actorId: actorId,
        );
  }

  @override
  Future<FirestoreResult<void>> transferPresidency({
    required String clubId,
    required String fromUserId,
    required String toUserId,
    required String actorId,
  }) async {
    record('transferPresidency', [clubId, fromUserId, toUserId, actorId]);
    return _injected<void>() ??
        await memberships.transferPresidency(
          clubId: clubId,
          fromUserId: fromUserId,
          toUserId: toUserId,
          actorId: actorId,
        );
  }

  @override
  Future<FirestoreResult<void>> updateClubSettings(
    String clubId,
    ClubSettingsPatch patch, {
    required String actorId,
  }) async {
    record('updateClubSettings', [clubId, patch, actorId]);
    if (_injected<void>() case final failure?) return failure;
    if (!RepositoryHelpers.isValidId(clubId) ||
        !RepositoryHelpers.isValidId(actorId) ||
        !_validSettings(patch)) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    final club = clubs.clubs[clubId];
    if (club == null || club.isDeleted) {
      return const FirebaseFailure(FirestoreError.notFound);
    }
    clubs.clubs[clubId] = club.copyWith(
      summary: patch.summary,
      about: patch.about,
      conditions: patch.conditions,
      social: patch.social,
      approvalRequired: patch.approvalRequired,
      applicationsOpen: patch.applicationsOpen,
      requireNote: patch.requireNote,
      palette: patch.palette,
      pattern: patch.pattern,
      coverSeed: patch.coverSeed,
    );
    settingsUpdates.add((clubId: clubId, patch: patch, actorId: actorId));
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<void>> publishEvent(
    String eventId, {
    required String clubId,
    required String actorId,
    required bool notifyMembers,
  }) async {
    record('publishEvent', [eventId, clubId, actorId, notifyMembers]);
    if (_injected<void>() case final failure?) return failure;
    final published = await events.publish(eventId, actorId: actorId);
    if (published.isSuccess && notifyMembers) {
      fanOuts.add((
        kind: NotificationType.eventNew,
        clubId: clubId,
        id: eventId,
      ));
    }
    return published;
  }

  @override
  Future<FirestoreResult<void>> cancelEvent(
    String eventId, {
    required String clubId,
    required String reason,
    required String actorId,
  }) async {
    record('cancelEvent', [eventId, clubId, reason, actorId]);
    if (_injected<void>() case final failure?) return failure;
    final cancelled = await events.cancel(
      eventId,
      reason: reason,
      actorId: actorId,
    );
    if (cancelled.isSuccess) {
      fanOuts.add((
        kind: NotificationType.eventCancelled,
        clubId: clubId,
        id: eventId,
      ));
    }
    return cancelled;
  }

  @override
  Future<FirestoreResult<void>> unpublishEvent(String eventId) async {
    record('unpublishEvent', [eventId]);
    return _injected<void>() ?? await events.unpublish(eventId);
  }

  @override
  Future<FirestoreResult<PostModel>> publishPost(
    PostDraft draft, {
    required String clubId,
    required String authorId,
    required String postId,
  }) async {
    record('publishPost', [clubId, authorId, postId]);
    if (_injected<PostModel>() case final failure?) return failure;
    final created = await posts.create(
      draft,
      authorId: authorId,
      clubId: clubId,
      postId: postId,
    );
    if (created case FirebaseSuccess(
      data: final post,
    ) when post.type == PostType.announcement && post.pushSent) {
      fanOuts.add((
        kind: NotificationType.announcement,
        clubId: clubId,
        id: post.id,
      ));
    }
    return created;
  }

  @override
  Future<FirestoreResult<void>> pinPost(
    String postId, {
    required String clubId,
  }) async {
    record('pinPost', [postId, clubId]);
    return _injected<void>() ?? await posts.pin(postId, clubId: clubId);
  }

  @override
  Future<FirestoreResult<void>> unpinPost(
    String postId, {
    required String clubId,
  }) async {
    record('unpinPost', [postId, clubId]);
    return _injected<void>() ?? await posts.unpin(postId, clubId: clubId);
  }

  @override
  Future<FirestoreResult<void>> moderatePost(
    String postId, {
    required String clubId,
    required String actorId,
  }) async {
    record('moderatePost', [postId, clubId, actorId]);
    return _injected<void>() ??
        await posts.softDeletePost(postId, actorId: actorId, clubId: clubId);
  }

  @override
  Future<FirestoreResult<void>> moderateComment(
    String commentId, {
    required String postId,
    required String clubId,
    required String actorId,
  }) async {
    record('moderateComment', [commentId, postId, clubId, actorId]);
    return _injected<void>() ??
        await comments.softDeleteComment(
          commentId,
          postId: postId,
          actorId: actorId,
        );
  }

  @override
  bool isReadOnly(ClubAccess access) => access == ClubAccess.advisor;

  /// Gerçek repository'nin toplu kararı: tekilleştirilmiş kimlikler sırayla,
  /// her biri ayrı karar; `conflict` → çakışan, diğer hata → başarısız.
  Future<FirestoreResult<BulkResult>> _bulk(
    String clubId,
    String actorId,
    List<String> userIds,
    Future<FirestoreResult<void>> Function(String userId) decide,
  ) async {
    if (_injected<BulkResult>() case final failure?) return failure;
    if (!RepositoryHelpers.isValidId(clubId) ||
        !RepositoryHelpers.isValidId(actorId)) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    final succeeded = <String>[];
    final conflicted = <String>[];
    final failed = <String>[];
    for (final userId in userIds.toSet()) {
      switch (await decide(userId)) {
        case FirebaseSuccess():
          succeeded.add(userId);
        case FirebaseFailure(error: FirestoreError.conflict):
          conflicted.add(userId);
        case FirebaseFailure():
          failed.add(userId);
      }
    }
    return FirebaseSuccess(
      BulkResult(
        succeeded: succeeded,
        conflicted: conflicted,
        failed: failed,
      ),
    );
  }

  /// Gerçek repository'nin ön denetimi: boş yama ve alan sınırları.
  static bool _validSettings(ClubSettingsPatch patch) {
    if (patch.isEmpty) return false;
    final social = patch.social;
    final errors = [
      if (patch.summary case final summary?)
        FieldValidators.clubSummary(summary),
      if (patch.about case final about?) FieldValidators.clubAbout(about),
      if (patch.conditions case final conditions?)
        FieldValidators.conditions(conditions),
      if (social?.email case final email?) FieldValidators.socialEmail(email),
      if (social?.instagram case final instagram?)
        FieldValidators.instagram(instagram),
      if (social?.web case final web?) FieldValidators.web(web),
      if (patch.coverSeed case final coverSeed?)
        FieldValidators.requiredId(coverSeed),
    ];
    return errors.every((error) => error == null);
  }

  /// Bekleyen hata (`failNext`) varsa başarısızlık; yoksa `null`.
  FirestoreResult<T>? _injected<T>() => switch (takeFailure()) {
    null => null,
    final FirestoreError error => FirebaseFailure(error),
    _ => const FirebaseFailure(FirestoreError.unknown),
  };
}
