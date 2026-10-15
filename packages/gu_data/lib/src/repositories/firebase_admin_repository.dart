import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gu_data/src/constants/firestore_collections.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/constants/firestore_ids.dart';
import 'package:gu_data/src/constants/limits.dart';
import 'package:gu_data/src/constants/storage_paths.dart';
import 'package:gu_data/src/core/app_clock.dart';
import 'package:gu_data/src/core/base_fields.dart';
import 'package:gu_data/src/core/conflict_exception.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/core/media_update_error.dart';
import 'package:gu_data/src/core/page_request.dart';
import 'package:gu_data/src/core/page_result.dart';
import 'package:gu_data/src/core/storage_error.dart';
import 'package:gu_data/src/models/admin_stats.dart';
import 'package:gu_data/src/models/club_advisor_model.dart';
import 'package:gu_data/src/models/club_create_input.dart';
import 'package:gu_data/src/models/club_identity_patch.dart';
import 'package:gu_data/src/models/club_media_upload.dart';
import 'package:gu_data/src/models/club_model.dart';
import 'package:gu_data/src/models/enums/club_status.dart';
import 'package:gu_data/src/models/enums/event_status.dart';
import 'package:gu_data/src/models/enums/report_action.dart';
import 'package:gu_data/src/models/enums/report_status.dart';
import 'package:gu_data/src/models/enums/report_target_type.dart';
import 'package:gu_data/src/models/enums/user_status.dart';
import 'package:gu_data/src/models/report_model.dart';
import 'package:gu_data/src/models/user_model.dart';
import 'package:gu_data/src/repositories/admin/firebase_report_moderation.dart';
import 'package:gu_data/src/repositories/admin/firebase_user_search.dart';
import 'package:gu_data/src/repositories/admin_repository.dart';
import 'package:gu_data/src/repositories/firebase_club_repository.dart';
import 'package:gu_data/src/repositories/firebase_membership_repository.dart';
import 'package:gu_data/src/repositories/report_repository.dart';
import 'package:gu_data/src/repositories/repository_helpers.dart';
import 'package:gu_data/src/services/auth_service.dart';
import 'package:gu_data/src/services/firestore_service.dart';
import 'package:gu_data/src/services/firestore_types.dart';
import 'package:gu_data/src/services/storage_service.dart';
import 'package:gu_data/src/utils/field_validators.dart';

/// [AdminRepository] uygulaması — süper adminin kulüp ve kullanıcı yazımları
/// ile genel bakış sayaçları (PLAN §10.4; sözleşme `docs/plans/T-37.md` §4 a).
///
/// Kendi yazdığı yollar: kulüp oluşturma (kulüp + başkan üyeliği + iletişim
/// belgesi tek batch), kulüp kimlik alanları, kulüp görselleri, kulüp askısı
/// ve kullanıcı askısı (`users` + `private/account` tek işlem — CD-133).
/// Başkan ataması ve danışman bağlama üyelik belgelerinin sahibine
/// ([FirebaseMembershipRepository]) devredilir; şikayet okumaları / çözümü
/// [FirebaseReportModeration]'a, kullanıcı aramaları [FirebaseUserSearch]'e
/// **olduğu gibi** devredilir (sonuç değiştirilmez).
///
/// Yetki yalnızca Security Rules'ta (`superadmin` claim — D-28) uygulanır;
/// burada claim denetlenmez. Aktör oturumdaki uid'dir: oturum yoksa yazım
/// yapılmadan [FirestoreError.unauthenticated].
final class FirebaseAdminRepository implements AdminRepository {
  /// Kompozisyon kökü bağımlılıkları verir: yazımlar [_firestore] (görseller
  /// [_storage]) ile; aktör [_auth] oturumundan; kuruluş yılı sınırı,
  /// yaklaşan etkinlik eşiği ve dosya adı damgası [_clock] saatinden, dosya
  /// adının rastgele kısmı [_random] kaynağından (kompozisyon kökü
  /// `Random.secure()` verir). Başkan / danışman [_memberships], şikayetler
  /// [_reports], aramalar [_search] üzerinden.
  FirebaseAdminRepository({
    required this._firestore,
    required this._storage,
    required this._auth,
    required this._clock,
    required this._random,
    required this._memberships,
    required this._reports,
    required this._search,
  });

  final FirestoreService _firestore;
  final StorageService _storage;
  final AuthService _auth;
  final AppClock _clock;
  final Random _random;
  final FirebaseMembershipRepository _memberships;
  final FirebaseReportModeration _reports;
  final FirebaseUserSearch _search;

  /// Kulüp görselinin özel üst veri anahtarları (`ManagementRepository
  /// .updateClubMedia` ile aynı): Storage Rules `clubId`'nin yolun
  /// klasöründeki kulüp, `uploaderId`'nin oturumdaki uid olmasını ister.
  static const String _clubIdMetadata = 'clubId';
  static const String _uploaderIdMetadata = 'uploaderId';

  /// Yeni kulübün sayacı: yalnızca başkan (danışman sayılmaz — M13).
  static const int _founderCount = 1;

  /// Ad benzersizliği sorgusunun sınırı: kulübün kendisi + bir başkası.
  static const int _nameProbe = 2;

  // ── Kulüp ──────────────────────────────────────────────────────────────

  @override
  Future<FirestoreResult<ClubModel>> createClub(
    ClubCreateInput input, {
    required String presidentUserId,
    required UserModel presidentUser,
    required String presidentEmail,
    AdvisorInput? advisor,
  }) async {
    final actorId = _auth.currentUser?.uid;
    if (actorId == null) return _unauthenticated('createClub');
    final rejected =
        RepositoryHelpers.rejectInvalidIds<ClubModel>({
          'presidentUserId': presidentUserId,
          'actorId': actorId,
        }) ??
        _rejectCreate(input, advisor, presidentEmail);
    if (rejected != null) return rejected;
    if (presidentUser.uid != presidentUserId) {
      return RepositoryHelpers.invalidArgument(
        'createClub: presidentUser başka bir kullanıcı',
      );
    }
    // Askıdaki / silinmiş hesap başkan olamaz (Rules `users/{başkan}`).
    if (!presidentUser.isActive) {
      return const FirebaseFailure(
        FirestoreError.conflict,
        message: 'createClub: başkanın hesabı etkin değil',
      );
    }
    if (await _rejectTakenName<ClubModel>(input.nameLower) case final taken?) {
      return taken;
    }

    final clubId = _firestore.newId(FirestoreCollections.clubs);
    final coverSeed = input.coverSeed ?? FirestoreIds.clubCoverSeed(clubId);
    final advisorModel = advisor == null
        ? null
        : ClubAdvisorModel(name: advisor.name, title: advisor.title);
    final written = await _firestore.commitBatch((batch) {
      batch.set(_clubRef(clubId), {
        FirestoreFields.name: input.name,
        FirestoreFields.nameLower: input.nameLower,
        FirestoreFields.categoryId: input.categoryId,
        FirestoreFields.iconName: input.iconName,
        FirestoreFields.palette: input.palette.json,
        FirestoreFields.pattern: input.pattern.json,
        FirestoreFields.coverSeed: coverSeed,
        FirestoreFields.logoPath: null,
        FirestoreFields.coverPath: null,
        FirestoreFields.memberCount: _founderCount,
        FirestoreFields.approvalRequired: input.approvalRequired,
        FirestoreFields.applicationsOpen: input.applicationsOpen,
        FirestoreFields.requireNote: input.requireNote,
        FirestoreFields.founded: input.founded,
        FirestoreFields.summary: input.summary,
        FirestoreFields.about: input.about,
        FirestoreFields.conditions: const <String>[],
        FirestoreFields.social: const <String, Object?>{},
        FirestoreFields.presidentId: presidentUserId,
        FirestoreFields.pinnedPostId: null,
        // Hesap bağlama yalnızca `setAdvisor` / betikle (K-A).
        FirestoreFields.advisor: advisorModel == null
            ? null
            : {...advisorModel.toJson(), FirestoreFields.userId: null},
        FirestoreFields.status: ClubStatus.active.json,
        FirestoreFields.suspendReason: null,
        ...BaseFieldsPayload.create(createdBy: actorId),
      });
      _memberships.addFounderToBatch(
        batch,
        clubId: clubId,
        president: presidentUser,
        email: presidentEmail,
        actorId: actorId,
      );
    });
    if (written case FirebaseFailure(:final error, :final message)) {
      return FirebaseFailure(error, message: message);
    }
    // Sunucu zamanı yazımdan dönmez: zaman alanları yaklaşık değerdir.
    final now = _clock.nowUtc();
    return FirebaseSuccess(
      ClubModel(
        id: clubId,
        name: input.name,
        nameLower: input.nameLower,
        categoryId: input.categoryId,
        iconName: input.iconName,
        palette: input.palette,
        pattern: input.pattern,
        coverSeed: coverSeed,
        founded: input.founded,
        presidentId: presidentUserId,
        memberCount: _founderCount,
        approvalRequired: input.approvalRequired,
        applicationsOpen: input.applicationsOpen,
        requireNote: input.requireNote,
        summary: input.summary,
        about: input.about,
        advisor: advisorModel,
        createdBy: actorId,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  @override
  Future<FirestoreResult<void>> updateClubIdentity(
    String clubId,
    ClubIdentityPatch patch,
  ) async {
    final rejected =
        RepositoryHelpers.rejectInvalidIds<void>({'clubId': clubId}) ??
        _rejectIdentity(patch);
    if (rejected != null) return rejected;
    final nameLower = patch.nameLower;
    if (nameLower != null) {
      if (await _rejectTakenName<void>(nameLower, exceptClubId: clubId)
          case final taken?) {
        return taken;
      }
    }
    final clubRef = _clubRef(clubId);
    // Tek güncelleme; kulüp işlem içinde okunur: bağlı danışman hesabı
    // (`advisor.userId`) okunan değerle korunur (araya giren `setAdvisor`
    // işlemi yeniden dener, bağı ezmez).
    return _transact((tx) async {
      final doc = FirestoreDoc.fromSnapshot(await tx.get(clubRef));
      if (doc == null || RepositoryHelpers.isSoftDeleted(doc)) {
        throw _Stop(FirestoreError.notFound, '${clubRef.path}: yok');
      }
      final club = switch (RepositoryHelpers.parse(
        doc,
        FirebaseClubRepository.clubOf,
      )) {
        FirebaseSuccess(:final data) => data,
        FirebaseFailure(:final error, :final message) => throw _Stop(
          error,
          message,
        ),
      };
      final boundUserId = club.advisor?.userId;
      if (patch.clearAdvisor && boundUserId != null) {
        throw const _Stop(
          FirestoreError.failedPrecondition,
          'updateClubIdentity: hesabı bağlı danışman kaldırılamaz '
          '(önce setAdvisor active: false)',
        );
      }
      tx.update(clubRef, {
        ..._identityFields(patch, boundUserId),
        ...BaseFieldsPayload.update(),
      });
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
    // Ön okuma yalnızca hata ayrımı ve yetim dosyayı önlemek içindir: "yok /
    // silinmiş" → `notFound`, dosya gönderilmez. Süper admin dalı `clubLive`
    // istemez: askıdaki kulübün görseli de değişir.
    final clubRef = _clubRef(clubId);
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
    }

    // Her görsel yeni adla yüklenir (üzerine yazma yok); önce logo, sonra
    // kapak. Biri reddedilirse yol yazılmaz: önce yüklenen dosya yetim kalır
    // (silinmez — D-10), kulüp eski görsellerini gösterir.
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

    // Tek güncelleme (süper medya dalı); kulüp günlüğü yazılmaz.
    final written = await _firestore.update(clubRef, {
      FirestoreFields.logoPath: ?paths[true],
      FirestoreFields.coverPath: ?paths[false],
    });
    return switch (written) {
      FirebaseSuccess() => FirebaseSuccess(
        ClubMediaPaths(logoPath: paths[true], coverPath: paths[false]),
      ),
      // Dosyalar yerinde kalır (D-10); yollar eski değerindedir.
      FirebaseFailure(:final error, :final message) => FirebaseFailure(
        MediaDocumentError(error),
        message: message,
      ),
    };
  }

  @override
  Future<FirestoreResult<void>> suspendClub(
    String clubId, {
    required String reason,
  }) async {
    final rejected =
        RepositoryHelpers.rejectInvalidIds<void>({'clubId': clubId}) ??
        RepositoryHelpers.rejectInvalidFields<void>({
          FirestoreFields.suspendReason: FieldValidators.adminReason(reason),
        });
    if (rejected != null) return rejected;
    return _firestore.update(_clubRef(clubId), {
      FirestoreFields.status: ClubStatus.suspended.json,
      FirestoreFields.suspendReason: reason,
    });
  }

  @override
  Future<FirestoreResult<void>> activateClub(String clubId) async {
    if (RepositoryHelpers.rejectInvalidIds<void>({'clubId': clubId})
        case final rejected?) {
      return rejected;
    }
    return _firestore.update(_clubRef(clubId), {
      FirestoreFields.status: ClubStatus.active.json,
      FirestoreFields.suspendReason: null,
    });
  }

  @override
  Future<FirestoreResult<void>> assignPresident({
    required String clubId,
    required String toUserId,
    required String actorId,
  }) => _memberships.assignPresident(
    clubId: clubId,
    toUserId: toUserId,
    actorId: actorId,
  );

  @override
  Future<FirestoreResult<void>> setAdvisor({
    required String clubId,
    required String userId,
    required bool active,
  }) => _memberships.setAdvisor(clubId: clubId, userId: userId, active: active);

  // ── Şikayet ────────────────────────────────────────────────────────────

  @override
  Future<FirestoreResult<PageResult<ReportModel>>> listOpenReports(
    PageRequest page,
  ) => _reports.listOpenReports(page);

  @override
  Future<FirestoreResult<PageResult<ReportModel>>> listReports(
    ReportStatus status,
    PageRequest page,
  ) => _reports.listReports(status, page);

  @override
  Future<FirestoreResult<List<ReportModel>>> listReportsForTarget({
    required ReportTargetType type,
    required String targetId,
  }) => _reports.listReportsForTarget(type: type, targetId: targetId);

  @override
  Future<FirestoreResult<void>> resolveReports({
    required List<String> reportIds,
    required ReportAction action,
    required String actorId,
    ReportTarget? target,
  }) => _reports.resolveReports(
    reportIds: reportIds,
    action: action,
    actorId: actorId,
    target: target,
  );

  // ── Kullanıcı ──────────────────────────────────────────────────────────

  @override
  Future<FirestoreResult<void>> suspendUser(
    String uid, {
    required String reason,
  }) async {
    if (RepositoryHelpers.rejectInvalidFields<void>({
          FirestoreFields.suspendReason: FieldValidators.adminReason(reason),
        })
        case final rejected?) {
      return rejected;
    }
    return _setUserStatus(uid, UserStatus.suspended, reason);
  }

  @override
  Future<FirestoreResult<void>> activateUser(String uid) =>
      _setUserStatus(uid, UserStatus.active, null);

  @override
  Future<FirestoreResult<PageResult<UserModel>>> listUsersByName(
    String prefixLower,
    PageRequest page,
  ) => _search.listUsersByName(prefixLower, page);

  @override
  Future<FirestoreResult<List<UserModel>>> findUserByEmail(String emailLower) =>
      _search.findUserByEmail(emailLower);

  @override
  Future<FirestoreResult<Set<String>>> listManagerUserIds() =>
      _search.listManagerUserIds();

  // ── Genel bakış ────────────────────────────────────────────────────────

  @override
  Future<FirestoreResult<AdminStats>> stats() async {
    Query<Json> notDeleted(String collection) => _firestore
        .collection(collection)
        .where(FirestoreFields.isDeleted, isEqualTo: false);
    // Dört toplama sorgusu paralel; belge okunmaz.
    final counts = await Future.wait([
      _firestore.count(
        notDeleted(
          FirestoreCollections.clubs,
        ).where(FirestoreFields.status, isEqualTo: ClubStatus.active.json),
      ),
      _firestore.count(notDeleted(FirestoreCollections.users)),
      _firestore.count(
        _firestore
            .collection(FirestoreCollections.reports)
            .where(FirestoreFields.status, isEqualTo: ReportStatus.open.json),
      ),
      _firestore.count(
        _firestore
            .collection(FirestoreCollections.events)
            .where(
              FirestoreFields.status,
              isEqualTo: EventStatus.published.json,
            )
            .where(FirestoreFields.isDeleted, isEqualTo: false)
            .where(
              FirestoreFields.startsAt,
              isGreaterThanOrEqualTo: Timestamp.fromDate(_clock.nowUtc()),
            ),
      ),
    ]);
    final values = <int>[];
    for (final count in counts) {
      switch (count) {
        case FirebaseFailure(:final error, :final message, :final detail):
          return FirebaseFailure(error, message: message, detail: detail);
        case FirebaseSuccess(:final data):
          values.add(data);
      }
    }
    return FirebaseSuccess(
      AdminStats(
        clubCount: values[0],
        userCount: values[1],
        openReportCount: values[2],
        upcomingEventCount: values[3],
      ),
    );
  }

  // ── Yardımcılar ────────────────────────────────────────────────────────

  /// Askı / etkinleştirme (CD-133): kullanıcı belgesi işlem içinde okunur
  /// (yok → [FirestoreError.notFound], silinmiş hesap →
  /// [FirestoreError.conflict]), sonra **tek işlemde** `users/{uid}.status`
  /// + `private/account.suspendReason` ([reason]; etkinleştirmede `null`).
  /// Gerekçe `users` belgesine yazılmaz.
  Future<FirestoreResult<void>> _setUserStatus(
    String uid,
    UserStatus status,
    String? reason,
  ) async {
    if (RepositoryHelpers.rejectInvalidIds<void>({'uid': uid})
        case final rejected?) {
      return rejected;
    }
    // Süper admin kendi hesabının durumunu değiştiremez (Rules `uid !=
    // request.auth.uid` — güvenlik incelemesi T-37).
    if (_auth.currentUser?.uid == uid) {
      return RepositoryHelpers.invalidArgument(
        '${status.json}: süper admin kendi hesabını değiştiremez',
      );
    }
    final userRef = _firestore.doc(FirestoreCollections.users, uid);
    final accountRef = _firestore.doc(
      RepositoryHelpers.subcollectionPath(
        FirestoreCollections.users,
        uid,
        FirestoreCollections.privateSub,
      ),
      FirestoreCollections.accountDoc,
    );
    return _transact((tx) async {
      final doc = FirestoreDoc.fromSnapshot(await tx.get(userRef));
      if (doc == null) {
        throw _Stop(FirestoreError.notFound, '${userRef.path}: yok');
      }
      final user = switch (RepositoryHelpers.parse(doc, _userOf)) {
        FirebaseSuccess(:final data) => data,
        FirebaseFailure(:final error, :final message) => throw _Stop(
          error,
          message,
        ),
      };
      // Silinmiş (anonimleşmiş) hesap: Rules `resource.status in [active,
      // suspended]`.
      if (user.isAnonymized || !user.isLive) {
        throw const ConflictException.conflict();
      }
      tx
        ..update(userRef, {
          FirestoreFields.status: status.json,
          ...BaseFieldsPayload.update(),
        })
        ..update(accountRef, {
          FirestoreFields.suspendReason: reason,
          ...BaseFieldsPayload.update(),
        });
    });
  }

  /// CD-63 ad benzersizliği: `clubs where nameLower == x` (silinmiş kulübün
  /// adı da dolu sayılır — D-10). [exceptClubId] kulübünün kendisi sayılmaz
  /// (ad değişikliği). Ad alınmışsa [FirestoreError.alreadyExists], sorgu
  /// başarısızsa onun hatası; boşsa `null`. Kilit belgesi yoktur: aynı anda
  /// iki oluşturma yarışı kabul edilmiştir (rules-spec §9.4).
  Future<FirestoreResult<T>?> _rejectTakenName<T>(
    String nameLower, {
    String? exceptClubId,
  }) async {
    final result = await _firestore.getList(
      _firestore
          .collection(FirestoreCollections.clubs)
          .where(FirestoreFields.nameLower, isEqualTo: nameLower)
          .limit(_nameProbe),
    );
    return switch (result) {
      FirebaseFailure(:final error, :final message, :final detail) =>
        FirebaseFailure(error, message: message, detail: detail),
      FirebaseSuccess(data: final docs)
          when docs.any((doc) => doc.id != exceptClubId) =>
        FirebaseFailure(
          FirestoreError.alreadyExists,
          message: 'kulüp adı alınmış: $nameLower',
        ),
      FirebaseSuccess() => null,
    };
  }

  /// [input] / [advisor] / [email] alanlarının belge okunmadan denetlenen
  /// kuralları (rules-spec §3.3 C; `Limits`).
  FirestoreResult<T>? _rejectCreate<T>(
    ClubCreateInput input,
    AdvisorInput? advisor,
    String email,
  ) {
    final coverSeed = input.coverSeed;
    return RepositoryHelpers.rejectInvalidFields<T>({
      FirestoreFields.name: FieldValidators.clubName(input.name),
      FirestoreFields.nameLower: FieldValidators.clubNameLower(
        input.nameLower,
      ),
      FirestoreFields.categoryId: FieldValidators.categoryId(input.categoryId),
      FirestoreFields.iconName: FieldValidators.iconName(input.iconName),
      FirestoreFields.founded: FieldValidators.founded(input.founded, _clock),
      FirestoreFields.summary: FieldValidators.clubSummary(input.summary),
      FirestoreFields.about: FieldValidators.clubAbout(input.about),
      if (coverSeed != null)
        FirestoreFields.coverSeed: FieldValidators.coverSeed(coverSeed),
      if (advisor != null)
        FirestoreFields.advisorName: FieldValidators.name(advisor.name),
      if (advisor != null)
        FirestoreFields.advisorTitle: FieldValidators.advisorTitle(
          advisor.title,
        ),
      FirestoreFields.email: FieldValidators.universityEmail(email),
    });
  }

  /// [patch] yamasının belge okunmadan denetlenen kuralları: boş yama, ad ile
  /// küçük harfli adın birlikte verilmesi ve alan sınırları.
  FirestoreResult<void>? _rejectIdentity(ClubIdentityPatch patch) {
    if (patch.isEmpty) {
      return RepositoryHelpers.invalidArgument('updateClubIdentity: boş yama');
    }
    final name = patch.name;
    final nameLower = patch.nameLower;
    if ((name == null) != (nameLower == null)) {
      return RepositoryHelpers.invalidArgument(
        'updateClubIdentity: name ve nameLower birlikte verilir',
      );
    }
    final categoryId = patch.categoryId;
    final iconName = patch.iconName;
    final founded = patch.founded;
    final summary = patch.summary;
    final about = patch.about;
    final coverSeed = patch.coverSeed;
    final advisor = patch.advisor;
    return RepositoryHelpers.rejectInvalidFields<void>({
      if (name != null) FirestoreFields.name: FieldValidators.clubName(name),
      if (nameLower != null)
        FirestoreFields.nameLower: FieldValidators.clubNameLower(nameLower),
      if (categoryId != null)
        FirestoreFields.categoryId: FieldValidators.categoryId(categoryId),
      if (iconName != null)
        FirestoreFields.iconName: FieldValidators.iconName(iconName),
      if (founded != null)
        FirestoreFields.founded: FieldValidators.founded(founded, _clock),
      if (summary != null)
        FirestoreFields.summary: FieldValidators.clubSummary(summary),
      if (about != null)
        FirestoreFields.about: FieldValidators.clubAbout(about),
      if (coverSeed != null)
        FirestoreFields.coverSeed: FieldValidators.coverSeed(coverSeed),
      if (advisor != null)
        FirestoreFields.advisorName: FieldValidators.name(advisor.name),
      if (advisor != null)
        FirestoreFields.advisorTitle: FieldValidators.advisorTitle(
          advisor.title,
        ),
    });
  }

  /// [patch] yamasının yazılacak alanları (yalnızca verilenler). Danışman
  /// yazılırken bağlı hesap [boundUserId] korunur.
  static Json _identityFields(ClubIdentityPatch patch, String? boundUserId) {
    final advisor = patch.advisor;
    return {
      FirestoreFields.name: ?patch.name,
      FirestoreFields.nameLower: ?patch.nameLower,
      FirestoreFields.categoryId: ?patch.categoryId,
      FirestoreFields.iconName: ?patch.iconName,
      FirestoreFields.founded: ?patch.founded,
      FirestoreFields.summary: ?patch.summary,
      FirestoreFields.about: ?patch.about,
      FirestoreFields.palette: ?patch.palette?.json,
      FirestoreFields.pattern: ?patch.pattern?.json,
      FirestoreFields.coverSeed: ?patch.coverSeed,
      FirestoreFields.applicationsOpen: ?patch.applicationsOpen,
      FirestoreFields.approvalRequired: ?patch.approvalRequired,
      if (advisor != null)
        FirestoreFields.advisor: {
          ...ClubAdvisorModel(
            name: advisor.name,
            title: advisor.title,
          ).toJson(),
          FirestoreFields.userId: boundUserId,
        }
      else if (patch.clearAdvisor)
        FirestoreFields.advisor: null,
      if (patch.clearCoverPath) FirestoreFields.coverPath: null,
    };
  }

  /// [image] yüklenebilir mi (Storage Rules `imageOk()` + `fileNameOk` ile
  /// aynı — `ManagementRepository.updateClubMedia` kuralı): içerik türünden
  /// uzantı ya da yükleme hatası.
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

  /// [body] gövdesini transaction içinde çalıştırır; gövde yazım kuyruğa
  /// girmeden `ConflictException` (çakışma) ya da [_Stop] (bulunamadı,
  /// ayrıştırılamadı, ön koşul) ile reddedebilir.
  Future<FirestoreResult<void>> _transact(
    Future<void> Function(Transaction tx) body,
  ) async {
    final result = await _firestore.runTransaction<FirestoreResult<void>>((
      tx,
    ) async {
      try {
        await body(tx);
        return const FirebaseSuccess(null);
      } on _Stop catch (stop) {
        return FirebaseFailure(stop.error, message: stop.message);
      }
    });
    return switch (result) {
      FirebaseSuccess(:final data) => data,
      FirebaseFailure(:final error, :final message, :final detail) =>
        FirebaseFailure(error, message: message, detail: detail),
    };
  }

  static FirestoreResult<T> _unauthenticated<T>(String member) =>
      FirebaseFailure(
        FirestoreError.unauthenticated,
        message: '$member: oturum yok',
      );

  static UserModel _userOf(FirestoreDoc doc) =>
      UserModel.fromJson(doc.data, id: doc.id);

  DocumentReference<Json> _clubRef(String clubId) =>
      _firestore.doc(FirestoreCollections.clubs, clubId);
}

/// Transaction gövdesinin, yazım kuyruğa girmeden işlemi durdurduğu hata
/// (bulunamadı, ayrıştırılamadı, ön koşul). Çakışma bunun yerine
/// `ConflictException` ile bildirilir.
final class _Stop implements Exception {
  const _Stop(this.error, this.message);

  final FirestoreError error;
  final String? message;
}
