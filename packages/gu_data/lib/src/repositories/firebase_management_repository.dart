import 'dart:math';

import 'package:gu_data/src/constants/firestore_collections.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/constants/limits.dart';
import 'package:gu_data/src/constants/storage_paths.dart';
import 'package:gu_data/src/core/app_clock.dart';
import 'package:gu_data/src/core/base_fields.dart';
import 'package:gu_data/src/core/bulk_result.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/core/media_update_error.dart';
import 'package:gu_data/src/core/role_policy.dart';
import 'package:gu_data/src/core/storage_error.dart';
import 'package:gu_data/src/models/activity_draft.dart';
import 'package:gu_data/src/models/club_media_upload.dart';
import 'package:gu_data/src/models/club_settings_patch.dart';
import 'package:gu_data/src/models/enums/activity_kind.dart';
import 'package:gu_data/src/models/enums/club_role.dart';
import 'package:gu_data/src/models/enums/club_status.dart';
import 'package:gu_data/src/models/enums/post_type.dart';
import 'package:gu_data/src/models/enums/reject_reason.dart';
import 'package:gu_data/src/models/enums/rsvp_status.dart';
import 'package:gu_data/src/models/post_draft.dart';
import 'package:gu_data/src/models/post_model.dart';
import 'package:gu_data/src/notifications/notification_dispatcher.dart';
import 'package:gu_data/src/notifications/recipient_resolver.dart';
import 'package:gu_data/src/repositories/club_repository.dart';
import 'package:gu_data/src/repositories/comment_repository.dart';
import 'package:gu_data/src/repositories/event_repository.dart';
import 'package:gu_data/src/repositories/firebase_activity_repository.dart';
import 'package:gu_data/src/repositories/management_repository.dart';
import 'package:gu_data/src/repositories/membership_repository.dart';
import 'package:gu_data/src/repositories/post_repository.dart';
import 'package:gu_data/src/repositories/repository_helpers.dart';
import 'package:gu_data/src/services/firestore_service.dart';
import 'package:gu_data/src/services/storage_service.dart';
import 'package:gu_data/src/utils/field_validators.dart';

/// [ManagementRepository] uygulaması — kompozisyon (PLAN §10.4; sözleşme
/// `docs/plans/T-30.md` §4 a).
///
/// Üyelik kararları [MembershipRepository]'ye, etkinlik geçişleri
/// [EventRepository]'ye, gönderi / yorum yazımları [PostRepository] /
/// [CommentRepository]'ye **olduğu gibi** devredilir (sonuç değiştirilmez;
/// tek alıcılı kritik bildirimler devredilen işlemin içindedir). Çok alıcılı
/// bildirim (`event_new`, `event_cancelled`, `announcement`) yalnızca asıl
/// yazım **kesinleştikten sonra** dağıtılır; alıcı çözümü ya da dağıtım
/// başarısız olsa da sonuç asıl yazımınkidir (en iyi çaba — rules-spec §5).
///
/// Kendi yazdığı iki yol kulüp ayarları ([updateClubSettings]) ve kulüp
/// görselleridir ([updateClubMedia] — T-36: önce Storage yüklemesi, sonra
/// yollar); ikisi de kulüp + `settings_changed` günlüğünü tek batch'te yazar.
/// Yetkiyi Security Rules uygular (danışman hiçbir yazımı yapamaz — Q-09).
final class FirebaseManagementRepository implements ManagementRepository {
  /// Kompozisyon kökü bağımlılıkları verir: ayar yazımı [_firestore] ve
  /// [_activity] ile; devredilen yazımlar [_memberships], [_events],
  /// [_posts], [_comments]; fan-out alıcıları [_recipients] (kulüp
  /// [_clubs]'tan), dağıtım [_notifications]. Kulüp görselleri [_storage]
  /// ile yüklenir; dosya adının damgası [_clock] saatinden, rastgele kısmı
  /// [_random] kaynağından gelir (kompozisyon kökü `Random.secure()` verir —
  /// ad tahmin edilemez, üzerine yazma olmaz).
  FirebaseManagementRepository({
    required this._firestore,
    required this._storage,
    required this._clock,
    required this._random,
    required this._memberships,
    required this._events,
    required this._posts,
    required this._comments,
    required this._clubs,
    required this._activity,
    required this._notifications,
    required this._recipients,
  });

  final FirestoreService _firestore;
  final StorageService _storage;
  final AppClock _clock;
  final Random _random;
  final MembershipRepository _memberships;
  final EventRepository _events;
  final PostRepository _posts;
  final CommentRepository _comments;
  final ClubRepository _clubs;
  final FirebaseActivityRepository _activity;
  final NotificationDispatcher _notifications;
  final RecipientResolver _recipients;

  /// Kulüp görselinin özel üst veri anahtarı: Storage Rules değerin yolun
  /// klasöründeki kulüp olmasını ve yükleyenin o kulübün etkin yöneticisi
  /// olmasını ister (`clubMetadataOnly()` + `isManagerOf(clubId)`).
  /// [_uploaderIdMetadata] dışında özel üst veri gönderilmez (Rules reddeder).
  static const String _clubIdMetadata = 'clubId';

  /// Yükleyenin kimliği: Storage Rules değerin oturumdaki uid olmasını ister
  /// (dosyayı kimin yüklediği yalnızca bu alandan izlenir — CD-143).
  static const String _uploaderIdMetadata = 'uploaderId';

  /// `event_cancelled` alıcılarının katılım durumları.
  static const Set<RsvpStatus> _cancelRecipients = {
    RsvpStatus.going,
    RsvpStatus.waitlist,
  };

  @override
  Future<FirestoreResult<void>> approveApplication({
    required String clubId,
    required String userId,
    required String actorId,
  }) => _memberships.approve(clubId: clubId, userId: userId, actorId: actorId);

  @override
  Future<FirestoreResult<void>> rejectApplication({
    required String clubId,
    required String userId,
    required String actorId,
    required RejectReason reason,
    String rejectNote = '',
  }) => _memberships.reject(
    clubId: clubId,
    userId: userId,
    actorId: actorId,
    reason: reason,
    rejectNote: rejectNote,
  );

  @override
  Future<FirestoreResult<void>> undoDecision({
    required String clubId,
    required String userId,
    required String actorId,
  }) => _memberships.undoDecision(
    clubId: clubId,
    userId: userId,
    actorId: actorId,
  );

  @override
  Future<FirestoreResult<void>> undoRemoval({
    required String clubId,
    required String userId,
    required String actorId,
  }) => _memberships.undoRemoval(
    clubId: clubId,
    userId: userId,
    actorId: actorId,
  );

  @override
  Future<FirestoreResult<BulkResult>> approveMany({
    required String clubId,
    required List<String> userIds,
    required String actorId,
  }) => _bulk(
    clubId: clubId,
    actorId: actorId,
    userIds: userIds,
    decide: (userId) =>
        approveApplication(clubId: clubId, userId: userId, actorId: actorId),
  );

  @override
  Future<FirestoreResult<BulkResult>> rejectMany({
    required String clubId,
    required List<String> userIds,
    required String actorId,
    required RejectReason reason,
    String rejectNote = '',
  }) => _bulk(
    clubId: clubId,
    actorId: actorId,
    userIds: userIds,
    decide: (userId) => rejectApplication(
      clubId: clubId,
      userId: userId,
      actorId: actorId,
      reason: reason,
      rejectNote: rejectNote,
    ),
  );

  @override
  Future<FirestoreResult<void>> removeMember({
    required String clubId,
    required String userId,
    required String actorId,
    required ClubRole actorRole,
    bool actorIsSuper = false,
    String rejectNote = '',
  }) => _memberships.remove(
    clubId: clubId,
    userId: userId,
    actorId: actorId,
    actorRole: actorRole,
    actorIsSuper: actorIsSuper,
    rejectNote: rejectNote,
  );

  @override
  Future<FirestoreResult<void>> changeRole({
    required String clubId,
    required String userId,
    required ClubRole role,
    required String actorId,
  }) => _memberships.changeRole(
    clubId: clubId,
    userId: userId,
    role: role,
    actorId: actorId,
  );

  @override
  Future<FirestoreResult<void>> transferPresidency({
    required String clubId,
    required String fromUserId,
    required String toUserId,
    required String actorId,
  }) => _memberships.transferPresidency(
    clubId: clubId,
    fromUserId: fromUserId,
    toUserId: toUserId,
    actorId: actorId,
  );

  @override
  Future<FirestoreResult<void>> updateClubSettings(
    String clubId,
    ClubSettingsPatch patch, {
    required String actorId,
  }) async {
    final rejected =
        RepositoryHelpers.rejectInvalidIds<void>({
          'clubId': clubId,
          'actorId': actorId,
        }) ??
        _rejectSettings(patch);
    if (rejected != null) return rejected;
    final clubRef = _firestore.doc(FirestoreCollections.clubs, clubId);
    // Ön okuma yalnızca hata ayrımı içindir ("yok / silinmiş" →
    // `notFound`); askı ve yetki Rules'tadır.
    switch (await _firestore.getDoc(clubRef)) {
      case FirebaseFailure(:final error, :final message, :final detail):
        return FirebaseFailure(error, message: message, detail: detail);
      case FirebaseSuccess(data: final doc):
        if (doc == null || RepositoryHelpers.isSoftDeleted(doc)) {
          return FirebaseFailure(
            FirestoreError.notFound,
            message: '${clubRef.path}: yok',
          );
        }
    }
    // Kulüp + günlük tek batch: Rules günlüğü `getAfter(clubs/c).updatedAt
    // == request.time` ile ayar yazımına bağlar. Günlük kimliği otomatik
    // (aynı ayar birden çok kez değişebilir).
    return _firestore.commitBatch((batch) {
      batch.update(clubRef, {
        ...patch.toJson(),
        ...BaseFieldsPayload.update(),
      });
      _activity.addToBatch(
        batch,
        ActivityDraft(
          clubId: clubId,
          actorId: actorId,
          kind: ActivityKind.settingsChanged,
        ),
      );
    });
  }

  @override
  Future<MediaUpdateResult<ClubMediaPaths>> updateClubMedia(
    String clubId, {
    required String uploaderId,
    ClubMediaUpload? logo,
    ClubMediaUpload? cover,
  }) async {
    // Ön denetim dosya gönderilmeden: yüklenen dosya silinemez (D-10).
    final invalid = RepositoryHelpers.rejectInvalidIds<void>({
      'clubId': clubId,
      'uploaderId': uploaderId,
    });
    if (invalid case FirebaseFailure(:final error, :final message)) {
      return FirebaseFailure(MediaDocumentError(error), message: message);
    }
    if (logo == null && cover == null) {
      return const FirebaseFailure(
        MediaDocumentError(FirestoreError.invalidArgument),
        message: 'updateClubMedia: görsel yok',
      );
    }
    // İki görsel de yüklemeden ÖNCE denetlenir: kapak geçersizse logo da
    // yüklenmez (yetim dosya yok).
    final extensions = <bool, String>{};
    for (final (isLogo, image) in [(true, logo), (false, cover)]) {
      if (image == null) continue;
      switch (_extensionOf(image)) {
        case FirebaseFailure(:final error):
          return FirebaseFailure(MediaUploadError(error));
        case FirebaseSuccess(data: final extension):
          extensions[isLogo] = extension;
      }
    }
    // Ön okuma hata ayrımı ve yetim dosyayı önlemek içindir; iki durumda da
    // dosya gönderilmez: "yok / silinmiş" → `notFound`, askıdaki kulüp →
    // `permissionDenied` (Storage kulübü okumaz — dosya yüklenir ama yol
    // yazımı `clubLive`'da düşer, silinemeyen dosya kalırdı; T-36 güvenlik
    // incelemesi). Yetki yine Rules'tadır.
    final clubRef = _firestore.doc(FirestoreCollections.clubs, clubId);
    switch (await _firestore.getDoc(clubRef)) {
      case FirebaseFailure(:final error, :final message):
        return FirebaseFailure(MediaDocumentError(error), message: message);
      case FirebaseSuccess(data: final doc):
        if (doc == null || RepositoryHelpers.isSoftDeleted(doc)) {
          return FirebaseFailure(
            const MediaDocumentError(FirestoreError.notFound),
            message: '${clubRef.path}: yok',
          );
        }
        if (doc.data[FirestoreFields.status] != ClubStatus.active.json) {
          return FirebaseFailure(
            const MediaDocumentError(FirestoreError.permissionDenied),
            message: '${clubRef.path}: askıda',
          );
        }
    }

    // Her görsel yeni adla yüklenir (üzerine yazma yok); önce logo, sonra
    // kapak. Biri reddedilirse yol yazılmaz: daha önce yüklenen dosya yetim
    // kalır (silinmez — D-10), kulüp eski görsellerini gösterir.
    final paths = <bool, String>{};
    for (final (isLogo, image) in [(true, logo), (false, cover)]) {
      if (image == null) continue;
      final file = StoragePaths.newFileName(
        _clock,
        _random,
        extensions[isLogo]!,
      );
      final upload = await _storage.upload(
        path: isLogo
            ? StoragePaths.clubLogo(clubId, file)
            : StoragePaths.clubCover(clubId, file),
        bytes: image.bytes,
        contentType: image.contentType,
        customMetadata: {
          _clubIdMetadata: clubId,
          _uploaderIdMetadata: uploaderId,
        },
      );
      switch (upload) {
        case FirebaseFailure(:final error, :final message):
          return FirebaseFailure(MediaUploadError(error), message: message);
        case FirebaseSuccess(data: final path):
          paths[isLogo] = path;
      }
    }

    // Kulüp + günlük tek batch (ayar yazımıyla aynı): Rules günlüğü
    // `getAfter(clubs/c).updatedAt == request.time` ile bu yazıma bağlar.
    final written = await _firestore.commitBatch((batch) {
      batch.update(clubRef, {
        FirestoreFields.logoPath: ?paths[true],
        FirestoreFields.coverPath: ?paths[false],
        ...BaseFieldsPayload.update(),
      });
      _activity.addToBatch(
        batch,
        ActivityDraft(
          clubId: clubId,
          actorId: uploaderId,
          kind: ActivityKind.settingsChanged,
        ),
      );
    });
    return switch (written) {
      FirebaseSuccess() => FirebaseSuccess(
        ClubMediaPaths(logoPath: paths[true], coverPath: paths[false]),
      ),
      // Dosyalar yerinde kalır (D-10); `logoPath` / `coverPath` eski
      // değerindedir, yeniden deneme yeni ad üretir.
      FirebaseFailure(:final error, :final message) => FirebaseFailure(
        MediaDocumentError(error),
        message: message,
      ),
    };
  }

  @override
  Future<FirestoreResult<void>> publishEvent(
    String eventId, {
    required String clubId,
    required String actorId,
    required bool notifyMembers,
  }) async {
    if (RepositoryHelpers.rejectInvalidIds<void>({
          'eventId': eventId,
          'clubId': clubId,
          'actorId': actorId,
        })
        case final rejected?) {
      return rejected;
    }
    final published = await _events.publish(eventId, actorId: actorId);
    if (published is FirebaseFailure || !notifyMembers) return published;
    await _fanOutEventNew(eventId, clubId);
    return published;
  }

  @override
  Future<FirestoreResult<void>> cancelEvent(
    String eventId, {
    required String clubId,
    required String reason,
    required String actorId,
  }) async {
    if (RepositoryHelpers.rejectInvalidIds<void>({
          'eventId': eventId,
          'clubId': clubId,
          'actorId': actorId,
        })
        case final rejected?) {
      return rejected;
    }
    final cancelled = await _events.cancel(
      eventId,
      reason: reason,
      actorId: actorId,
    );
    if (cancelled is FirebaseFailure) return cancelled;
    // Tercihe bakılmaz; alıcılar iptal anındaki kayıtlı + bekleyenler.
    if (await _recipients.rsvpUsersOf(eventId, clubId, _cancelRecipients)
        case FirebaseSuccess(data: final recipients)
        when recipients.isNotEmpty) {
      await _notifications.notifyEventCancelled(
        eventId: eventId,
        clubId: clubId,
        recipients: recipients,
      );
    }
    return cancelled;
  }

  @override
  Future<FirestoreResult<void>> unpublishEvent(String eventId) =>
      _events.unpublish(eventId);

  @override
  Future<FirestoreResult<PostModel>> publishPost(
    PostDraft draft, {
    required String clubId,
    required String authorId,
    required String postId,
  }) async {
    final created = await _posts.create(
      draft,
      authorId: authorId,
      clubId: clubId,
      postId: postId,
    );
    // Bildirim yazarın oturumundan gider (Rules `post.authorId == uid()` —
    // W-83): bildirimli duyuru → `announcement`; normal gönderi / anket →
    // `post_new` (H-25). Günlük sınırı aşan (bildirimsiz) duyuru bildirim
    // üretmez.
    if (created case FirebaseSuccess(data: final post)) {
      final announced = post.type == PostType.announcement && post.pushSent;
      final isPost = post.type != PostType.announcement;
      if (announced || isPost) {
        if (await _recipients.membersOf(clubId, excludeUserId: authorId)
            case FirebaseSuccess(data: final recipients)
            when recipients.isNotEmpty) {
          if (announced) {
            await _notifications.notifyAnnouncement(
              postId: post.id,
              clubId: clubId,
              recipients: recipients,
            );
          } else {
            await _notifications.notifyPostNew(
              postId: post.id,
              clubId: clubId,
              recipients: recipients,
            );
          }
        }
      }
    }
    return created;
  }

  @override
  Future<FirestoreResult<void>> pinPost(
    String postId, {
    required String clubId,
  }) => _posts.pin(postId, clubId: clubId);

  @override
  Future<FirestoreResult<void>> unpinPost(
    String postId, {
    required String clubId,
  }) => _posts.unpin(postId, clubId: clubId);

  @override
  Future<FirestoreResult<void>> moderatePost(
    String postId, {
    required String clubId,
    required String actorId,
  }) => _posts.softDeletePost(postId, actorId: actorId, clubId: clubId);

  @override
  Future<FirestoreResult<void>> moderateComment(
    String commentId, {
    required String postId,
    required String clubId,
    required String actorId,
  }) => _comments.softDeleteComment(
    commentId,
    postId: postId,
    actorId: actorId,
  );

  @override
  bool isReadOnly(ClubAccess access) => access == ClubAccess.advisor;

  /// Toplu karar: [userIds] (tekilleştirilmiş, girdi sırası) her biri ayrı
  /// [decide] işlemi, sırayla. `conflict` → [BulkResult.conflicted], başka
  /// hata → [BulkResult.failed].
  Future<FirestoreResult<BulkResult>> _bulk({
    required String clubId,
    required String actorId,
    required List<String> userIds,
    required Future<FirestoreResult<void>> Function(String userId) decide,
  }) async {
    if (RepositoryHelpers.rejectInvalidIds<BulkResult>({
          'clubId': clubId,
          'actorId': actorId,
        })
        case final rejected?) {
      return rejected;
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

  /// Yayımlanan [eventId] için `event_new` fan-out (en iyi çaba): etkinlik ve
  /// kulüp okunur, alıcılar `RecipientResolver.eventNew` ile çözülür.
  /// Herhangi bir adım başarısızsa ya da etkinlik [clubId] kulübünün değilse
  /// dağıtım yapılmaz.
  Future<void> _fanOutEventNew(String eventId, String clubId) async {
    if (await _events.getEvent(eventId) case FirebaseSuccess(
      data: final event,
    ) when event.clubId == clubId) {
      if (await _clubs.getClub(clubId) case FirebaseSuccess(data: final club)) {
        if (await _recipients.eventNew(event, club) case FirebaseSuccess(
          data: final set,
        ) when set.ids.isNotEmpty) {
          await _notifications.notifyEventNew(
            eventId: eventId,
            clubId: clubId,
            recipients: set.ids,
          );
        }
      }
    }
  }

  /// [image] yüklenebilir mi (Storage Rules `imageOk()` + `fileNameOk`
  /// ile aynı): içerik türünden uzantı ya da yükleme hatası.
  static StorageResult<String> _extensionOf(ClubMediaUpload image) {
    final extension = StoragePaths.extensionByContentType[image.contentType];
    if (extension == null) {
      return const FirebaseFailure(StorageError.invalidType);
    }
    if (image.bytes.isEmpty) return const FirebaseFailure(StorageError.noFile);
    // Storage Rules `size < imageMaxBytes` ister: sınırın kendisi de ret.
    if (image.bytes.length >= Limits.imageMaxBytes) {
      return const FirebaseFailure(StorageError.sizeLimit);
    }
    return FirebaseSuccess(extension);
  }

  /// [patch] yamasının belge okunmadan denetlenebilen kuralları: boş yama
  /// ve alan sınırları (`Limits` — rules-spec §3.3 U(yönetim)).
  static FirestoreResult<void>? _rejectSettings(ClubSettingsPatch patch) {
    if (patch.isEmpty) {
      return RepositoryHelpers.invalidArgument('updateClubSettings: boş yama');
    }
    final summary = patch.summary;
    final about = patch.about;
    final conditions = patch.conditions;
    final coverSeed = patch.coverSeed;
    final social = patch.social;
    final email = social?.email;
    final instagram = social?.instagram;
    final web = social?.web;
    return RepositoryHelpers.rejectInvalidFields<void>({
      if (summary != null)
        FirestoreFields.summary: FieldValidators.clubSummary(summary),
      if (about != null)
        FirestoreFields.about: FieldValidators.clubAbout(about),
      if (conditions != null)
        FirestoreFields.conditions: FieldValidators.conditions(conditions),
      if (email != null)
        _socialField(FirestoreFields.email): FieldValidators.socialEmail(email),
      if (instagram != null)
        _socialField(FirestoreFields.instagram): FieldValidators.instagram(
          instagram,
        ),
      if (web != null)
        _socialField(FirestoreFields.web): FieldValidators.web(web),
      if (coverSeed != null)
        FirestoreFields.coverSeed: FieldValidators.coverSeed(coverSeed),
    });
  }

  /// `social` gömülü nesnesinin alan yolu (hata iletisi için).
  static String _socialField(String field) =>
      '${FirestoreFields.social}.$field';
}
