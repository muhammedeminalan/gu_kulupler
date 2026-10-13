import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gu_data/src/constants/firestore_collections.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/constants/firestore_ids.dart';
import 'package:gu_data/src/core/app_clock.dart';
import 'package:gu_data/src/core/base_fields.dart';
import 'package:gu_data/src/core/conflict_exception.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/core/firestore_failure_detail.dart';
import 'package:gu_data/src/core/page_request.dart';
import 'package:gu_data/src/core/page_result.dart';
import 'package:gu_data/src/models/activity_draft.dart';
import 'package:gu_data/src/models/activity_refs_model.dart';
import 'package:gu_data/src/models/club_model.dart';
import 'package:gu_data/src/models/enums/activity_kind.dart';
import 'package:gu_data/src/models/enums/club_role.dart';
import 'package:gu_data/src/models/enums/membership_status.dart';
import 'package:gu_data/src/models/membership_applicant_model.dart';
import 'package:gu_data/src/models/membership_contact_model.dart';
import 'package:gu_data/src/models/membership_model.dart';
import 'package:gu_data/src/models/user_model.dart';
import 'package:gu_data/src/notifications/notification_dispatcher.dart';
import 'package:gu_data/src/repositories/firebase_activity_repository.dart';
import 'package:gu_data/src/repositories/firebase_club_repository.dart';
import 'package:gu_data/src/repositories/membership_repository.dart';
import 'package:gu_data/src/repositories/repository_helpers.dart';
import 'package:gu_data/src/services/firestore_service.dart';
import 'package:gu_data/src/services/firestore_types.dart';
import 'package:gu_data/src/utils/field_validators.dart';

/// [MembershipRepository] uygulaması: `memberships/{clubId}_{userId}`,
/// `memberships/{id}/private/contact`, `clubs.memberCount` sayacı ve günlük
/// kaydı (PLAN §10.4; rules-spec §3.4 M1–M4, M7, M8).
///
/// Her geçiş tek transaction'dır: önce okur (başvuranın kullanıcı belgesi,
/// kulüp, üyelik, iletişim belgesi), beklenen durumu doğrular, sonra yazar.
/// Doğrulama tutmazsa **hiçbir yazım** kuyruğa girmez.
///
/// Herkese açık kulüp belgesine yalnızca sayaç deltası yazılır; kimin
/// katıldığını / ayrıldığını gösteren bir yol yazılmaz (CD-137). Günlük
/// kaydının kimliği sabittir (`FirestoreIds.activity`): bir geçişe tek kayıt.
final class FirebaseMembershipRepository implements MembershipRepository {
  /// [_firestore] üzerinden okur ve yazar; günlük kaydını [_activity] ile
  /// aynı transaction'a ekler, başvuru bildirimini [_dispatcher]'dan ister.
  /// Yeniden başvuru bekleme süresi [_clock] saatine göre denetlenir.
  FirebaseMembershipRepository(
    this._firestore,
    this._activity,
    this._dispatcher,
    this._clock,
  );

  final FirestoreService _firestore;
  final FirebaseActivityRepository _activity;
  final NotificationDispatcher _dispatcher;
  final AppClock _clock;

  /// `memberCount` deltası: üye katıldı.
  static const int _joined = 1;

  /// `memberCount` deltası: üye ayrıldı.
  static const int _departed = -1;

  /// Anında katılımda `private/contact` belgesine yazılan (boş) not.
  static const String _noNote = '';

  /// Yöneticilerin rolleri (`listManagers` süzgeci; Rules `isManager`).
  static const List<ClubRole> _managerRoles = [
    ClubRole.board,
    ClubRole.president,
  ];

  @override
  Stream<FirestoreResult<List<MembershipModel>>> watchMyMemberships(
    String uid,
  ) {
    if (RepositoryHelpers.rejectInvalidIds<List<MembershipModel>>({'uid': uid})
        case final rejected?) {
      return Stream.value(rejected);
    }
    return _firestore
        .watchList(_memberships.where(FirestoreFields.userId, isEqualTo: uid))
        .map((event) => RepositoryHelpers.parseAll(event, _membershipOf));
  }

  @override
  Future<FirestoreResult<MembershipModel?>> getMembership(
    String clubId,
    String userId,
  ) async {
    if (_rejectPair<MembershipModel?>(clubId, userId) case final rejected?) {
      return rejected;
    }
    return RepositoryHelpers.parseOrNull(
      await _firestore.getDoc(_membershipRef(clubId, userId)),
      _membershipOf,
    );
  }

  @override
  Future<FirestoreResult<MembershipModel>> apply({
    required String clubId,
    required UserModel applicant,
    required String email,
    required String note,
  }) async {
    final result = await _enter(
      clubId: clubId,
      applicant: applicant,
      email: email,
      note: note,
      target: MembershipStatus.pending,
    );
    if (result.isSuccess) {
      // Fan-out asıl işlem kesinleştikten sonra ve en iyi çabayladır:
      // bildirim hatası başvurunun sonucunu bozmaz (PLAN §10.5).
      await _dispatcher.notifyApplicationReceived(
        clubId: clubId,
        applicantId: applicant.uid,
      );
    }
    return result;
  }

  @override
  Future<FirestoreResult<MembershipModel>> joinInstant({
    required String clubId,
    required UserModel applicant,
    required String email,
  }) => _enter(
    clubId: clubId,
    applicant: applicant,
    email: email,
    note: _noNote,
    target: MembershipStatus.active,
  );

  @override
  Future<FirestoreResult<void>> cancelApplication({
    required String clubId,
    required String userId,
  }) async {
    if (_rejectPair<void>(clubId, userId) case final rejected?) {
      return rejected;
    }
    final membershipRef = _membershipRef(clubId, userId);
    return _transact((tx) async {
      final current = _membershipOrNull(await tx.get(membershipRef));
      // M7: yalnızca bekleyen başvuru geri çekilir.
      if (current?.status != MembershipStatus.pending) {
        throw const ConflictException.conflict();
      }
      tx.update(membershipRef, {
        FirestoreFields.status: MembershipStatus.cancelled.json,
        ...BaseFieldsPayload.update(),
      });
    });
  }

  @override
  Future<FirestoreResult<void>> leave({
    required String clubId,
    required String userId,
  }) async {
    if (_rejectPair<void>(clubId, userId) case final rejected?) {
      return rejected;
    }
    final clubRef = _clubRef(clubId);
    final membershipRef = _membershipRef(clubId, userId);
    return _transact((tx) async {
      final current = _membershipOrNull(await tx.get(membershipRef));
      // M8: yalnızca aktif üye ayrılır.
      if (current == null || current.status != MembershipStatus.active) {
        throw const ConflictException.conflict();
      }
      switch (current.role) {
        case ClubRole.president:
          throw _violation(FirestoreRuleCode.presidentCannotLeave);
        case ClubRole.advisor:
          throw _violation(FirestoreRuleCode.notMember);
        case ClubRole.member || ClubRole.board:
          break;
      }
      tx.update(membershipRef, {
        FirestoreFields.status: MembershipStatus.left.json,
        ...BaseFieldsPayload.update(),
      });
      _bumpMemberCount(tx, clubRef, _departed);
      _activity.addToTransaction(
        tx,
        // Ayrılma `priorCount`'u değiştirmez: kimlik mevcut değeri taşır.
        _activityOf(
          clubId,
          userId,
          ActivityKind.memberLeft,
          current.priorCount,
        ),
      );
    });
  }

  @override
  Future<FirestoreResult<PageResult<MembershipModel>>> listActiveMembers(
    String clubId,
    PageRequest page, {
    ClubRole? role,
  }) async {
    if (RepositoryHelpers.rejectInvalidIds<PageResult<MembershipModel>>({
          'clubId': clubId,
        })
        case final rejected?) {
      return rejected;
    }
    final active = _inClub(clubId, MembershipStatus.active);
    // İki sorgu iki ayrı indeksle karşılanır (rules-spec §8): rol süzgeçli
    // sorgunun indeksi `appliedAt` taşımadığı için sıralama eklenmez.
    final query = role == null
        ? active.orderBy(FirestoreFields.appliedAt, descending: true)
        : active.where(FirestoreFields.role, isEqualTo: role.json);
    return RepositoryHelpers.parsePage(
      await _firestore.getPage(query, page),
      _membershipOf,
    );
  }

  @override
  Future<FirestoreResult<List<MembershipModel>>> listManagers(
    String clubId,
  ) async {
    if (RepositoryHelpers.rejectInvalidIds<List<MembershipModel>>({
          'clubId': clubId,
        })
        case final rejected?) {
      return rejected;
    }
    return RepositoryHelpers.parseAll(
      await _firestore.getList(
        _inClub(clubId, MembershipStatus.active).where(
          FirestoreFields.role,
          whereIn: [for (final role in _managerRoles) role.json],
        ),
      ),
      _membershipOf,
    );
  }

  @override
  Future<FirestoreResult<PageResult<MembershipModel>>> listPending(
    String clubId,
    PageRequest page,
  ) async {
    if (RepositoryHelpers.rejectInvalidIds<PageResult<MembershipModel>>({
          'clubId': clubId,
        })
        case final rejected?) {
      return rejected;
    }
    return RepositoryHelpers.parsePage(
      await _firestore.getPage(
        _inClub(
          clubId,
          MembershipStatus.pending,
        ).orderBy(FirestoreFields.appliedAt, descending: true),
        page,
      ),
      _membershipOf,
    );
  }

  @override
  Future<FirestoreResult<List<MembershipModel>>> listMine(
    String uid, {
    Set<MembershipStatus>? statuses,
  }) async {
    if (RepositoryHelpers.rejectInvalidIds<List<MembershipModel>>({'uid': uid})
        case final rejected?) {
      return rejected;
    }
    // Boş `whereIn` geçersiz bir sorgudur; boş küme = eşleşme yok.
    if (statuses != null && statuses.isEmpty) return const FirebaseSuccess([]);
    final mine = _memberships.where(FirestoreFields.userId, isEqualTo: uid);
    return RepositoryHelpers.parseAll(
      await _firestore.getList(
        statuses == null
            ? mine
            : mine.where(
                FirestoreFields.status,
                whereIn: [for (final status in statuses) status.json],
              ),
      ),
      _membershipOf,
    );
  }

  @override
  Future<FirestoreResult<MembershipContactModel?>> readContact(
    String clubId,
    String userId,
  ) async {
    if (_rejectPair<MembershipContactModel?>(clubId, userId)
        case final rejected?) {
      return rejected;
    }
    return RepositoryHelpers.parseOrNull(
      await _firestore.getDoc(_contactRef(clubId, userId)),
      (doc) => MembershipContactModel.fromJson(doc.data),
    );
  }

  /// Başvuru ([target] `pending`) ve anında katılımın ([target] `active`)
  /// ortak geçişi — Rules M1 / M2 (belge yok), M3 (`left` → `pending` |
  /// `active`; `cancelled` → yalnızca `pending`) ve M4 (`rejected` /
  /// `removed`; hedef yalnızca `pending`).
  ///
  /// `applicant` anlık görüntüsü çağıranın verdiği modelden değil, işlem
  /// içinde okunan `users/{uid}` belgesinden kurulur: Rules dört alanı o
  /// belgeyle birebir karşılaştırır ve oturumdaki model (başka cihazdaki
  /// profil değişikliğinden sonra) eski kalmış olabilir.
  Future<FirestoreResult<MembershipModel>> _enter({
    required String clubId,
    required UserModel applicant,
    required String email,
    required String note,
    required MembershipStatus target,
  }) {
    final uid = applicant.uid;
    final rejected =
        RepositoryHelpers.rejectInvalidIds<MembershipModel>({
          'clubId': clubId,
          'applicant.uid': uid,
        }) ??
        RepositoryHelpers.rejectInvalidFields<MembershipModel>({
          FirestoreFields.email: FieldValidators.universityEmail(email),
          // Alt sınır kulübe bağlıdır; işlem içinde, kulüp okununca denetlenir.
          FirestoreFields.note: FieldValidators.applicationNote(
            note,
            requireNote: false,
          ),
        });
    if (rejected != null) return Future.value(rejected);

    final instant = target == MembershipStatus.active;
    final userRef = _firestore.doc(FirestoreCollections.users, uid);
    final clubRef = _clubRef(clubId);
    final membershipRef = _membershipRef(clubId, uid);
    final contactRef = _contactRef(clubId, uid);

    return _transact((tx) async {
      // Transaction kuralı: tüm okumalar yazımlardan önce.
      final userSnapshot = await tx.get(userRef);
      final clubSnapshot = await tx.get(clubRef);
      final current = _membershipOrNull(await tx.get(membershipRef));
      // Yönetici eliyle açılmış üyeliğin iletişim belgesi olmayabilir.
      final hasContact = current != null && (await tx.get(contactRef)).exists;
      final snapshot = MembershipApplicantModel.fromUser(
        _existing(userSnapshot, _userOf),
      );
      final club = _liveClub(clubSnapshot);
      final now = _clock.nowUtc();

      if (club.isSuspended || !club.applicationsOpen) {
        throw _violation(FirestoreRuleCode.applicationsClosed);
      }
      switch (current?.status) {
        case MembershipStatus.pending || MembershipStatus.active:
          throw const ConflictException.conflict();
        case MembershipStatus.rejected || MembershipStatus.removed:
          final retryAfter = current?.retryAfter;
          if (retryAfter != null && now.isBefore(retryAfter)) {
            throw _violation(
              FirestoreRuleCode.retryCooldown,
              retryAfter: retryAfter,
            );
          }
          // M4'ün hedefi her zaman `pending`: reddedilen / çıkarılan kullanıcı
          // onaysız kulüpte de yönetici onayına döner.
          if (instant) throw _violation(FirestoreRuleCode.reapplyNeedsReview);
        case MembershipStatus.cancelled:
          // M3 (`cancelled`): hedef her kulüpte `pending`. İptal edilen
          // başvuru M4'ten gelmiş olabilir; anında katılım açık olsaydı
          // yönetici onayı başvur → iptal → katıl zinciriyle dolanılırdı.
          if (instant) throw _violation(FirestoreRuleCode.reapplyNeedsReview);
        case null || MembershipStatus.left:
          // M1 / M2 / M3 (`left`): çağrılan yol kulübün katılım biçimiyle
          // aynı olmalı; değilse ayar ekran açıkken değişmiştir.
          if (club.approvalRequired == instant) {
            throw const ConflictException.conflict();
          }
      }
      if (!instant) {
        final noteError = FieldValidators.applicationNote(
          note,
          requireNote: club.requireNote,
        );
        if (noteError != null) {
          throw _Halt(
            FirestoreError.invalidArgument,
            'geçersiz alan: ${FirestoreFields.note} (${noteError.name})',
          );
        }
      }

      final timestamp = _firestore.serverTimestamp();
      final priorCount = current == null ? 0 : current.priorCount + 1;
      if (current == null) {
        // M1 / M2 — `null` alanların anahtarı yazılmaz (W-51).
        tx.set(membershipRef, {
          ...MembershipModel(
            clubId: clubId,
            userId: uid,
            applicant: snapshot,
            status: target,
          ).toJson(),
          FirestoreFields.appliedAt: timestamp,
          ...BaseFieldsPayload.create(),
        });
      } else {
        // M3 / M4 — önceki kararın izleri açıkça `null`'a çekilir.
        tx.update(membershipRef, {
          FirestoreFields.status: target.json,
          FirestoreFields.role: ClubRole.member.json,
          FirestoreFields.applicant: snapshot.toJson(),
          FirestoreFields.appliedAt: timestamp,
          FirestoreFields.priorCount: priorCount,
          FirestoreFields.retryAfter: null,
          FirestoreFields.rejectReason: null,
          FirestoreFields.rejectNote: null,
          FirestoreFields.decidedAt: null,
          FirestoreFields.decidedBy: null,
          ...BaseFieldsPayload.update(),
        });
      }
      if (hasContact) {
        // E-posta yeniden yazılmaz; not bu başvurunun notuyla değişir.
        tx.update(contactRef, {
          FirestoreFields.note: note,
          ...BaseFieldsPayload.update(),
        });
      } else {
        tx.set(contactRef, {
          ...MembershipContactModel(
            email: email,
            emailLower: email.toLowerCase(),
            note: note,
          ).toJson(),
          ...BaseFieldsPayload.create(),
        });
      }
      if (instant) _bumpMemberCount(tx, clubRef, _joined);
      _activity.addToTransaction(
        tx,
        _activityOf(
          clubId,
          uid,
          instant
              ? ActivityKind.memberJoined
              : ActivityKind.applicationReceived,
          priorCount,
        ),
      );

      // Sunucu zamanı işlem içinde okunamaz: zaman alanları yaklaşık değerdir.
      return MembershipModel(
        clubId: clubId,
        userId: uid,
        applicant: snapshot,
        status: target,
        appliedAt: now,
        priorCount: priorCount,
        createdAt: current?.createdAt ?? now,
        updatedAt: now,
      );
    });
  }

  /// [body] gövdesini transaction içinde çalıştırır. Gövde, yazım kuyruğa
  /// girmeden **önce** reddedebilir: `ConflictException` (çakışma / iş
  /// kuralı) ya da [_Halt] (bulunamadı, ayrıştırılamadı, geçersiz girdi).
  Future<FirestoreResult<T>> _transact<T>(
    Future<T> Function(Transaction tx) body,
  ) async {
    final result = await _firestore.runTransaction<FirestoreResult<T>>((
      tx,
    ) async {
      try {
        return FirebaseSuccess(await body(tx));
      } on _Halt catch (halt) {
        return FirebaseFailure(halt.error, message: halt.message);
      }
    });
    return switch (result) {
      FirebaseSuccess(:final data) => data,
      FirebaseFailure(:final error, :final message, :final detail) =>
        FirebaseFailure(error, message: message, detail: detail),
    };
  }

  /// `clubs.memberCount` sayacını [delta] kadar oynatır. Değer hesaplanıp
  /// yazılmaz, yalnızca delta gönderilir.
  ///
  /// Sayaçla eşlenen üyeliğin yolu kulüp belgesine **yazılmaz**: belge
  /// doğrulanmış her kullanıcıya açıktır ve yol kimin katıldığını /
  /// ayrıldığını üye olmayana sızdırırdı (CD-137). Rules yolu oturumdan
  /// türetir (`memberships/{clubId}_{uid}`) ve aynı işlemdeki geçişi oradan
  /// doğrular.
  void _bumpMemberCount(
    Transaction tx,
    DocumentReference<Json> clubRef,
    int delta,
  ) => tx.update(clubRef, {
    FirestoreFields.memberCount: FieldValue.increment(delta),
    ...BaseFieldsPayload.update(),
  });

  /// Okunan kulüp: belge yoksa ya da silinmişse [FirestoreError.notFound],
  /// ayrıştırılamıyorsa [FirestoreError.parse] ile işlemi durdurur.
  static ClubModel _liveClub(DocumentSnapshot<Json> snapshot) {
    final doc = FirestoreDoc.fromSnapshot(snapshot);
    if (doc == null || RepositoryHelpers.isSoftDeleted(doc)) {
      throw _Halt(FirestoreError.notFound, '${snapshot.reference.path}: yok');
    }
    return _parsed(doc, FirebaseClubRepository.clubOf);
  }

  /// Okunan belge [fromDoc] ile; belge yoksa [FirestoreError.notFound],
  /// ayrıştırılamıyorsa [FirestoreError.parse] ile işlemi durdurur.
  static T _existing<T>(
    DocumentSnapshot<Json> snapshot,
    T Function(FirestoreDoc doc) fromDoc,
  ) {
    final doc = FirestoreDoc.fromSnapshot(snapshot);
    if (doc == null) {
      throw _Halt(FirestoreError.notFound, '${snapshot.reference.path}: yok');
    }
    return _parsed(doc, fromDoc);
  }

  /// Okunan üyelik; belge yoksa `null`. Ayrıştırılamıyorsa
  /// [FirestoreError.parse] ile işlemi durdurur.
  static MembershipModel? _membershipOrNull(DocumentSnapshot<Json> snapshot) {
    final doc = FirestoreDoc.fromSnapshot(snapshot);
    return doc == null ? null : _parsed(doc, _membershipOf);
  }

  static T _parsed<T>(FirestoreDoc doc, T Function(FirestoreDoc doc) fromDoc) =>
      switch (RepositoryHelpers.parse(doc, fromDoc)) {
        FirebaseSuccess(:final data) => data,
        FirebaseFailure(:final error, :final message) => throw _Halt(
          error,
          message,
        ),
      };

  /// [code] iş kuralının reddi; kod (ve varsa [retryAfter]) başarısızlığın
  /// `detail` alanında taşınır.
  static ConflictException _violation(
    FirestoreRuleCode code, {
    DateTime? retryAfter,
  }) => ConflictException(
    code,
    detail: FirestoreFailureDetail(code, retryAfter: retryAfter),
  );

  /// Üyenin kendi eylemi için günlük kaydı (eylemi yapan = hedef).
  /// [priorCount] geçişten sonraki üyelik belgesinin değeridir; kaydın sabit
  /// kimliğine girer (`FirestoreIds.activity`).
  static ActivityDraft _activityOf(
    String clubId,
    String userId,
    ActivityKind kind,
    int priorCount,
  ) => ActivityDraft(
    clubId: clubId,
    actorId: userId,
    kind: kind,
    refs: ActivityRefsModel(userId: userId),
    id: FirestoreIds.activity(clubId, userId, kind.json, priorCount),
  );

  static FirestoreResult<T>? _rejectPair<T>(String clubId, String userId) =>
      RepositoryHelpers.rejectInvalidIds<T>({
        'clubId': clubId,
        'userId': userId,
      });

  static MembershipModel _membershipOf(FirestoreDoc doc) =>
      MembershipModel.fromJson(doc.data, id: doc.id);

  static UserModel _userOf(FirestoreDoc doc) =>
      UserModel.fromJson(doc.data, id: doc.id);

  Query<Json> get _memberships =>
      _firestore.collection(FirestoreCollections.memberships);

  /// [clubId] kulübünün [status] durumundaki üyelikleri. Üyelik hiç soft
  /// delete edilmediği için silinmemiş süzgeci yoktur (indeksler de taşımaz).
  Query<Json> _inClub(String clubId, MembershipStatus status) => _memberships
      .where(FirestoreFields.clubId, isEqualTo: clubId)
      .where(FirestoreFields.status, isEqualTo: status.json);

  DocumentReference<Json> _clubRef(String clubId) =>
      _firestore.doc(FirestoreCollections.clubs, clubId);

  DocumentReference<Json> _membershipRef(String clubId, String userId) =>
      _firestore.doc(
        FirestoreCollections.memberships,
        FirestoreIds.membership(clubId, userId),
      );

  DocumentReference<Json> _contactRef(String clubId, String userId) =>
      _firestore.doc(
        RepositoryHelpers.subcollectionPath(
          FirestoreCollections.memberships,
          FirestoreIds.membership(clubId, userId),
          FirestoreCollections.privateSub,
        ),
        FirestoreCollections.contactDoc,
      );
}

/// Transaction gövdesinin, yazım kuyruğa girmeden işlemi durdurduğu hata
/// (bulunamadı, ayrıştırılamadı, geçersiz girdi). Çakışma ve iş kuralı reddi
/// bunun yerine `ConflictException` ile bildirilir.
final class _Halt implements Exception {
  const _Halt(this.error, this.message);

  final FirestoreError error;
  final String? message;
}
