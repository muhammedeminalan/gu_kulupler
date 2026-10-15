// `AdminRepository` fake'i (PLAN §16.3; T-37): gerçek repository gibi
// **kompozisyondur** — kulüpler kayıtlı `FakeClubRepository`, kullanıcılar ve
// hesap belgeleri `FakeUserRepository`, üyelikler (başkan ataması, danışman
// bağlama — M11 / M13) `FakeMembershipRepository`, içerik gizleme
// `FakePostRepository` / `FakeCommentRepository` belleğinde işlenir. Kendi
// tuttuğu belgeler şikayetlerdir ([FakeAdminRepository.reports]).
//
//   final admin = FakeAdminRepository(clock, auth: auth, clubs: clubs,
//       users: users, memberships: memberships, posts: posts,
//       comments: comments);
//   admin.putReport(reporterId: 'u1', type: ReportTargetType.post, targetId: 'p01');
//   await admin.resolveReports(reportIds: ['u1_post_p01'],
//       action: ReportAction.removed, actorId: 'u_super');
//   expect(admin.resolutions.single.reporterIds, ['u1']);
//
// Sonuçlar gerçek `FirebaseAdminRepository` ile aynıdır (sözleşme
// `docs/plans/T-37.md` §4 a): aktör oturumdaki uid (`auth.currentUser`; yoksa
// `unauthenticated`); CD-63 ad benzersizliği (silinmiş kulübün adı da dolu →
// `alreadyExists`); etkin olmayan başkan / hedef → `conflict`; kulüp / kullanıcı
// askısı tek "işlem" (kullanıcıda gerekçe yalnızca hesap belgesinde — CD-133;
// silinmiş hesap `conflict`); şikayet grubu = aynı hedefin açık şikayetleri,
// `removed` yalnızca gönderi / yorumda ve hedef zaten gizliyse yeniden
// gizlenmez; açık şikayet kalmadıysa `conflict`. Yetki (claim — D-28)
// Rules'tadır: test `failNext(FirestoreError.permissionDenied)` ile kurar
// (bir sonraki çağrı, devredilen dahil). Silme metodu yoktur (D-10).
import 'dart:typed_data';

import 'package:gu_data/gu_data.dart';

import 'fake_base.dart';
import 'fake_club_repository.dart';
import 'fake_comment_repository.dart';
import 'fake_membership_repository.dart';
import 'fake_post_repository.dart';
import 'fake_storage_service.dart';
import 'fake_user_repository.dart';

/// Başarılı `resolveReports` çağrısı: grup anahtarı (`{type}_{id}`), çözülen
/// şikayetler, tekil şikayetçiler (`report_resolved` alıcıları), çözüm ve
/// içerik bu çağrıda gizlendi mi.
typedef FakeReportResolution = ({
  String groupKey,
  List<String> reportIds,
  List<String> reporterIds,
  ReportAction action,
  bool hidden,
});

/// `updateClubMedia` ile "yüklenen" tek görsel.
typedef FakeAdminMediaUpload = ({
  String clubId,
  String uploaderId,
  bool isLogo,
  String contentType,
  String path,
});

final class FakeAdminRepository extends FakeBase implements AdminRepository {
  /// Kayıtlı fake'leri paylaşır (`registerDefaultFakes`); [storage]
  /// verilirse kulüp görselleri oraya da yazılır.
  FakeAdminRepository(
    this._clock, {
    required this.auth,
    required this.clubs,
    required this.users,
    required this.memberships,
    required this.posts,
    required this.comments,
    this.storage,
  });

  final AppClock _clock;

  /// Aktörün okunduğu oturum.
  final AuthService auth;
  final FakeClubRepository clubs;
  final FakeUserRepository users;
  final FakeMembershipRepository memberships;
  final FakePostRepository posts;
  final FakeCommentRepository comments;
  final FakeStorageService? storage;

  /// `reports/{id}` belgeleri; test [putReport] ile kurar.
  final Map<String, ReportModel> reports = <String, ReportModel>{};

  /// [stats] dönüşü (dört `count()` yerine).
  AdminStats statsValue = const AdminStats();

  /// Başarılı şikayet çözümleri, sırasıyla.
  final List<FakeReportResolution> resolutions = <FakeReportResolution>[];

  /// `updateClubMedia` ile yüklenen görseller.
  final List<FakeAdminMediaUpload> mediaUploads = <FakeAdminMediaUpload>[];

  int _clubSerial = 0;
  int _mediaSerial = 0;

  /// Açık bir şikayet kurar ve döndürür (kimlik `{reporter}_{type}_{target}`).
  ReportModel putReport({
    required String reporterId,
    required ReportTargetType type,
    required String targetId,
    String? targetClubId,
    ReportReason reason = ReportReason.spam,
    ReportStatus status = ReportStatus.open,
    DateTime? createdAt,
  }) {
    final report = ReportModel(
      targetType: type,
      targetId: targetId,
      targetClubId: targetClubId,
      reporterId: reporterId,
      reason: reason,
      status: status,
      createdAt: createdAt ?? _clock.nowUtc(),
    );
    return reports[report.id] = report;
  }

  // ── Kulüp ──────────────────────────────────────────────────────────────

  @override
  Future<FirestoreResult<ClubModel>> createClub(
    ClubCreateInput input, {
    required String presidentUserId,
    required UserModel presidentUser,
    required String presidentEmail,
    AdvisorInput? advisor,
  }) async {
    record('createClub', [input, presidentUserId, presidentEmail, advisor]);
    if (_injected<ClubModel>() case final failure?) return failure;
    final actorId = auth.currentUser?.uid;
    if (actorId == null) return _unauthenticated();
    if (!RepositoryHelpers.isValidId(presidentUserId) ||
        presidentUser.uid != presidentUserId ||
        FieldValidators.clubName(input.name) != null ||
        FieldValidators.clubNameLower(input.nameLower) != null) {
      return _invalid();
    }
    if (!presidentUser.isActive) return _conflict();
    if (_nameTaken(input.nameLower)) {
      return const FirebaseFailure(FirestoreError.alreadyExists);
    }
    final now = _clock.nowUtc();
    final id = 'cAdmin${++_clubSerial}';
    final club = ClubModel(
      id: id,
      name: input.name,
      nameLower: input.nameLower,
      categoryId: input.categoryId,
      iconName: input.iconName,
      palette: input.palette,
      pattern: input.pattern,
      coverSeed: input.coverSeed ?? FirestoreIds.clubCoverSeed(id),
      founded: input.founded,
      presidentId: presidentUserId,
      memberCount: 1,
      approvalRequired: input.approvalRequired,
      applicationsOpen: input.applicationsOpen,
      requireNote: input.requireNote,
      summary: input.summary,
      about: input.about,
      advisor: advisor == null
          ? null
          : ClubAdvisorModel(name: advisor.name, title: advisor.title),
      createdBy: actorId,
      createdAt: now,
      updatedAt: now,
    );
    clubs.clubs[id] = club;
    memberships.put(
      MembershipModel(
        clubId: id,
        userId: presidentUserId,
        applicant: MembershipApplicantModel.fromUser(presidentUser),
        status: MembershipStatus.active,
        role: ClubRole.president,
        appliedAt: now,
        decidedAt: now,
        decidedBy: actorId,
        createdAt: now,
        updatedAt: now,
      ),
      email: presidentEmail,
    );
    return FirebaseSuccess(club);
  }

  @override
  Future<FirestoreResult<void>> updateClubIdentity(
    String clubId,
    ClubIdentityPatch patch,
  ) async {
    record('updateClubIdentity', [clubId, patch]);
    if (_injected<void>() case final failure?) return failure;
    if (!RepositoryHelpers.isValidId(clubId) || patch.isEmpty) {
      return _invalid();
    }
    final club = clubs.clubs[clubId];
    if (club == null || club.isDeleted) {
      return const FirebaseFailure(FirestoreError.notFound);
    }
    final nameLower = patch.nameLower;
    if (nameLower != null && _nameTaken(nameLower, except: clubId)) {
      return const FirebaseFailure(FirestoreError.alreadyExists);
    }
    final bound = club.advisor?.userId;
    if (patch.clearAdvisor && bound != null) {
      return const FirebaseFailure(FirestoreError.failedPrecondition);
    }
    final advisor = patch.advisor;
    clubs.clubs[clubId] = club.copyWith(
      name: patch.name,
      nameLower: patch.nameLower,
      categoryId: patch.categoryId,
      iconName: patch.iconName,
      founded: patch.founded,
      summary: patch.summary,
      about: patch.about,
      palette: patch.palette,
      pattern: patch.pattern,
      coverSeed: patch.coverSeed,
      applicationsOpen: patch.applicationsOpen,
      approvalRequired: patch.approvalRequired,
      // Bağlı danışman hesabı (`advisor.userId`) korunur.
      advisor: advisor == null
          ? null
          : ClubAdvisorModel(
              name: advisor.name,
              title: advisor.title,
              userId: bound,
            ),
      clearAdvisor: patch.clearAdvisor,
      updatedAt: _clock.nowUtc(),
    );
    return const FirebaseSuccess(null);
  }

  @override
  Future<MediaUpdateResult<ClubMediaPaths>> updateClubMedia(
    String clubId, {
    required String uploaderId,
    ClubMediaUpload? logo,
    ClubMediaUpload? cover,
  }) async {
    record('updateClubMedia', [clubId, uploaderId, logo, cover]);
    final injected = takeFailure();
    if (![clubId, uploaderId].every(RepositoryHelpers.isValidId) ||
        (logo == null && cover == null)) {
      return const FirebaseFailure(
        MediaDocumentError(FirestoreError.invalidArgument),
      );
    }
    for (final upload in [?logo, ?cover]) {
      if (_rejectUpload(upload.bytes, upload.contentType) case final error?) {
        return FirebaseFailure(MediaUploadError(error));
      }
    }
    final club = clubs.clubs[clubId];
    // Süper admin dalı `clubLive` istemez: askıdaki kulübün görseli de değişir.
    if (club == null || club.isDeleted) {
      return const FirebaseFailure(MediaDocumentError(FirestoreError.notFound));
    }
    if (injected is StorageError) {
      return FirebaseFailure(MediaUploadError(injected));
    }
    String? upload(ClubMediaUpload? media, {required bool isLogo}) {
      if (media == null) return null;
      final extension = StoragePaths.extensionByContentType[media.contentType]!;
      final serial = (++_mediaSerial).toRadixString(16).padLeft(16, '0');
      final file = '20261015T090000Z_$serial.$extension';
      final path = isLogo
          ? StoragePaths.clubLogo(clubId, file)
          : StoragePaths.clubCover(clubId, file);
      mediaUploads.add((
        clubId: clubId,
        uploaderId: uploaderId,
        isLogo: isLogo,
        contentType: media.contentType,
        path: path,
      ));
      storage?.uploads[path] = media.bytes;
      return path;
    }

    final paths = ClubMediaPaths(
      logoPath: upload(logo, isLogo: true),
      coverPath: upload(cover, isLogo: false),
    );
    // Dosyalar yüklendi; yol yazımı düşerse yetim kalır (D-10).
    if (injected != null) {
      return FirebaseFailure(
        MediaDocumentError(
          injected is FirestoreError ? injected : FirestoreError.unknown,
        ),
      );
    }
    clubs.clubs[clubId] = club.copyWith(
      logoPath: paths.logoPath,
      coverPath: paths.coverPath,
    );
    return FirebaseSuccess(paths);
  }

  @override
  Future<FirestoreResult<void>> suspendClub(
    String clubId, {
    required String reason,
  }) async {
    record('suspendClub', [clubId, reason]);
    if (_injected<void>() case final failure?) return failure;
    if (!RepositoryHelpers.isValidId(clubId) ||
        FieldValidators.adminReason(reason) != null) {
      return _invalid();
    }
    return _setClubStatus(clubId, ClubStatus.suspended, reason);
  }

  @override
  Future<FirestoreResult<void>> activateClub(String clubId) async {
    record('activateClub', [clubId]);
    if (_injected<void>() case final failure?) return failure;
    if (!RepositoryHelpers.isValidId(clubId)) return _invalid();
    return _setClubStatus(clubId, ClubStatus.active, null);
  }

  @override
  Future<FirestoreResult<void>> assignPresident({
    required String clubId,
    required String toUserId,
    required String actorId,
  }) async {
    record('assignPresident', [clubId, toUserId, actorId]);
    if (_injected<void>() case final failure?) return failure;
    _snapshotProfile(toUserId);
    return memberships.assignPresident(
      clubId: clubId,
      toUserId: toUserId,
      actorId: actorId,
    );
  }

  @override
  Future<FirestoreResult<void>> setAdvisor({
    required String clubId,
    required String userId,
    required bool active,
  }) async {
    record('setAdvisor', [clubId, userId, active]);
    if (_injected<void>() case final failure?) return failure;
    _snapshotProfile(userId);
    return memberships.setAdvisor(
      clubId: clubId,
      userId: userId,
      active: active,
    );
  }

  // ── Şikayet ────────────────────────────────────────────────────────────

  @override
  Future<FirestoreResult<PageResult<ReportModel>>> listOpenReports(
    PageRequest page,
  ) {
    record('listOpenReports', [page]);
    return _list(ReportStatus.open, page);
  }

  @override
  Future<FirestoreResult<PageResult<ReportModel>>> listReports(
    ReportStatus status,
    PageRequest page,
  ) {
    record('listReports', [status, page]);
    return _list(status, page);
  }

  @override
  Future<FirestoreResult<List<ReportModel>>> listReportsForTarget({
    required ReportTargetType type,
    required String targetId,
  }) async {
    record('listReportsForTarget', [type, targetId]);
    if (_injected<List<ReportModel>>() case final failure?) return failure;
    if (!RepositoryHelpers.isValidId(targetId)) return _invalid();
    return FirebaseSuccess(_openFor(type, targetId));
  }

  @override
  Future<FirestoreResult<void>> resolveReports({
    required List<String> reportIds,
    required ReportAction action,
    required String actorId,
    ReportTarget? target,
  }) async {
    record('resolveReports', [reportIds, action, actorId, target]);
    if (_injected<void>() case final failure?) return failure;
    if (![actorId, ?target?.id, ...reportIds].every(
          RepositoryHelpers.isValidId,
        ) ||
        (reportIds.isEmpty && target == null) ||
        (target != null && !_canResolve(action, target.type))) {
      return _invalid();
    }
    final session = auth.currentUser;
    if (session == null) return _unauthenticated();
    if (session.uid != actorId) return _invalid();

    final ReportTargetType type;
    final String targetId;
    final List<ReportModel> open;
    if (target != null) {
      type = target.type;
      targetId = target.id;
      open = _openFor(type, targetId);
      final others = reportIds.map((id) => reports[id]).toList();
      if (others.any((r) => r == null)) {
        return const FirebaseFailure(FirestoreError.notFound);
      }
      if (others.any((r) => r!.targetType != type || r.targetId != targetId)) {
        return _invalid();
      }
    } else {
      final read = [for (final id in reportIds.toSet()) reports[id]];
      if (read.any((r) => r == null)) {
        return const FirebaseFailure(FirestoreError.notFound);
      }
      final first = read.first!;
      type = first.targetType;
      targetId = first.targetId;
      if (read.any((r) => r!.targetType != type || r.targetId != targetId)) {
        return _invalid();
      }
      open = [
        for (final report in read)
          if (report!.status == ReportStatus.open) report,
      ];
    }
    if (open.isEmpty) return _conflict();
    if (!_canResolve(action, type)) return _invalid();

    var hidden = false;
    if (action == ReportAction.removed) {
      final isHidden = type == ReportTargetType.post
          ? posts.posts[targetId]?.isHidden
          : comments.comments[targetId]?.isHidden;
      if (isHidden == null) {
        return const FirebaseFailure(FirestoreError.notFound);
      }
      if (!isHidden) {
        final written = type == ReportTargetType.post
            ? await posts.hide(targetId, actorId: actorId)
            : await comments.hide(targetId, actorId: actorId);
        if (written case FirebaseFailure()) return written;
        hidden = true;
      }
    }
    final now = _clock.nowUtc();
    for (final report in open) {
      reports[report.id] = report.copyWith(
        status: ReportStatus.resolved,
        action: action,
        resolvedAt: now,
        resolvedBy: actorId,
        updatedAt: now,
      );
    }
    resolutions.add((
      groupKey: FirestoreIds.reportGroupKey(type.json, targetId),
      reportIds: [for (final report in open) report.id],
      reporterIds: {for (final report in open) report.reporterId}.toList(),
      action: action,
      hidden: hidden,
    ));
    return const FirebaseSuccess(null);
  }

  // ── Kullanıcı ──────────────────────────────────────────────────────────

  @override
  Future<FirestoreResult<void>> suspendUser(
    String uid, {
    required String reason,
  }) async {
    record('suspendUser', [uid, reason]);
    if (_injected<void>() case final failure?) return failure;
    if (FieldValidators.adminReason(reason) != null) return _invalid();
    return _setUserStatus(uid, UserStatus.suspended, reason);
  }

  @override
  Future<FirestoreResult<void>> activateUser(String uid) async {
    record('activateUser', [uid]);
    if (_injected<void>() case final failure?) return failure;
    return _setUserStatus(uid, UserStatus.active, null);
  }

  @override
  Future<FirestoreResult<PageResult<UserModel>>> listUsersByName(
    String prefixLower,
    PageRequest page,
  ) async {
    record('listUsersByName', [prefixLower, page]);
    if (_injected<PageResult<UserModel>>() case final failure?) return failure;
    final matches = [
      for (final user in users.users.values)
        if (!user.isDeleted && user.nameLower.startsWith(prefixLower)) user,
    ]..sort((a, b) => a.nameLower.compareTo(b.nameLower));
    return FirebaseSuccess(_slice(matches, page));
  }

  @override
  Future<FirestoreResult<List<UserModel>>> findUserByEmail(
    String emailLower,
  ) async {
    record('findUserByEmail', [emailLower]);
    if (_injected<List<UserModel>>() case final failure?) return failure;
    if (emailLower.isEmpty) return const FirebaseSuccess([]);
    final uids = [
      for (final MapEntry(key: uid, value: account) in users.accounts.entries)
        if (account.emailLower.isNotEmpty &&
            account.emailLower.startsWith(emailLower))
          uid,
    ]..sort();
    return FirebaseSuccess([
      for (final uid in uids.take(Limits.adminSearchMax)) ?users.users[uid],
    ]);
  }

  @override
  Future<FirestoreResult<Set<String>>> listManagerUserIds() async {
    record('listManagerUserIds');
    if (_injected<Set<String>>() case final failure?) return failure;
    return FirebaseSuccess({
      for (final membership in memberships.memberships.values)
        if (membership.status == MembershipStatus.active &&
            (membership.role == ClubRole.board ||
                membership.role == ClubRole.president))
          membership.userId,
    });
  }

  // ── Genel bakış ────────────────────────────────────────────────────────

  @override
  Future<FirestoreResult<AdminStats>> stats() async {
    record('stats');
    if (_injected<AdminStats>() case final failure?) return failure;
    return FirebaseSuccess(statsValue);
  }

  // ── Yardımcılar ────────────────────────────────────────────────────────

  /// Atanan kullanıcının profili ve hesap durumu üyelik fake'ine aktarılır
  /// (gerçek repository işlem içinde `users/{uid}`'yi okur).
  void _snapshotProfile(String uid) {
    final user = users.users[uid];
    if (user == null) return;
    memberships.applicants[uid] = MembershipApplicantModel.fromUser(user);
    memberships.userStatuses[uid] = user.isDeleted
        ? UserStatus.deleted
        : user.status;
  }

  FirestoreResult<void> _setClubStatus(
    String clubId,
    ClubStatus status,
    String? reason,
  ) {
    final club = clubs.clubs[clubId];
    if (club == null || club.isDeleted) {
      return const FirebaseFailure(FirestoreError.notFound);
    }
    clubs.clubs[clubId] = club.copyWith(
      status: status,
      suspendReason: reason,
      clearSuspendReason: reason == null,
      updatedAt: _clock.nowUtc(),
    );
    return const FirebaseSuccess(null);
  }

  /// `users.status` + `private/account.suspendReason` tek "işlem" (CD-133).
  FirestoreResult<void> _setUserStatus(
    String uid,
    UserStatus status,
    String? reason,
  ) {
    if (!RepositoryHelpers.isValidId(uid)) return _invalid();
    // Kendi hesabı (gerçek sınıf ve Rules ile aynı — güvenlik incelemesi T-37).
    if (auth.currentUser?.uid == uid) return _invalid();
    final user = users.users[uid];
    if (user == null) return const FirebaseFailure(FirestoreError.notFound);
    if (user.isDeleted || user.status == UserStatus.deleted) return _conflict();
    users.users[uid] = user.copyWith(status: status);
    final account = users.accounts[uid];
    if (account != null) {
      users.accounts[uid] = account.copyWith(
        suspendReason: reason,
        clearSuspendReason: reason == null,
      );
    }
    memberships.userStatuses[uid] = status;
    return const FirebaseSuccess(null);
  }

  Future<FirestoreResult<PageResult<ReportModel>>> _list(
    ReportStatus status,
    PageRequest page,
  ) async {
    if (_injected<PageResult<ReportModel>>() case final failure?) {
      return failure;
    }
    final matches = [
      for (final report in reports.values)
        if (report.status == status) report,
    ]..sort((a, b) => _newest(a.createdAt, b.createdAt));
    return FirebaseSuccess(_slice(matches, page));
  }

  List<ReportModel> _openFor(ReportTargetType type, String targetId) => [
    for (final report in reports.values)
      if (report.targetType == type &&
          report.targetId == targetId &&
          report.status == ReportStatus.open)
        report,
  ];

  bool _nameTaken(String nameLower, {String? except}) => clubs.clubs.values.any(
    (club) => club.id != except && club.nameLower == nameLower,
  );

  /// İlk sayfa [PageRequest.limit] öğe (imleç yok: fake tek sayfa döner,
  /// fazlası varsa `next` dolu değildir — sayfalama `FakePager` testlerinde).
  static PageResult<T> _slice<T>(List<T> all, PageRequest page) =>
      PageResult(items: all.take(page.limit).toList());

  static int _newest(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == b ? 0 : (a == null ? 1 : -1);
    return b.compareTo(a);
  }

  static bool _canResolve(ReportAction action, ReportTargetType type) =>
      action != ReportAction.removed ||
      type == ReportTargetType.post ||
      type == ReportTargetType.comment;

  static StorageError? _rejectUpload(Uint8List bytes, String contentType) {
    if (!StoragePaths.extensionByContentType.containsKey(contentType)) {
      return StorageError.invalidType;
    }
    if (bytes.isEmpty) return StorageError.noFile;
    if (bytes.length >= Limits.imageMaxBytes) return StorageError.sizeLimit;
    return null;
  }

  FirestoreResult<T>? _injected<T>() => switch (takeFailure()) {
    null => null,
    final FirestoreError error => FirebaseFailure(error),
    _ => const FirebaseFailure(FirestoreError.unknown),
  };

  static FirestoreResult<T> _invalid<T>() =>
      const FirebaseFailure(FirestoreError.invalidArgument);

  static FirestoreResult<T> _conflict<T>() =>
      const FirebaseFailure(FirestoreError.conflict);

  static FirestoreResult<T> _unauthenticated<T>() =>
      const FirebaseFailure(FirestoreError.unauthenticated);
}
