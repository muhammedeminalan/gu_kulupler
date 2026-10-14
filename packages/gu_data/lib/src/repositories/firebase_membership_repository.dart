import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gu_data/src/constants/anonymization.dart';
import 'package:gu_data/src/constants/firestore_collections.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/constants/firestore_ids.dart';
import 'package:gu_data/src/constants/limits.dart';
import 'package:gu_data/src/core/app_clock.dart';
import 'package:gu_data/src/core/base_fields.dart';
import 'package:gu_data/src/core/conflict_exception.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/core/firestore_failure_detail.dart';
import 'package:gu_data/src/core/page_request.dart';
import 'package:gu_data/src/core/page_result.dart';
import 'package:gu_data/src/core/role_policy.dart';
import 'package:gu_data/src/models/activity_draft.dart';
import 'package:gu_data/src/models/activity_refs_model.dart';
import 'package:gu_data/src/models/club_model.dart';
import 'package:gu_data/src/models/enums/activity_kind.dart';
import 'package:gu_data/src/models/enums/club_role.dart';
import 'package:gu_data/src/models/enums/membership_status.dart';
import 'package:gu_data/src/models/enums/reject_reason.dart';
import 'package:gu_data/src/models/enums/user_status.dart';
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
/// kaydı (PLAN §10.4; rules-spec §3.4 M1–M4, M7, M8, hesap silme M14 ve
/// `private/contact` U(b) not düzenleme; yönetici geçişleri M5, M6, M9–M12 —
/// sözleşme `docs/plans/T-30.md` §4).
///
/// Her geçiş tek transaction'dır: önce okur (başvuranın kullanıcı belgesi,
/// kulüp, üyelik, iletişim belgesi, günlük kaydı), beklenen durumu doğrular,
/// sonra yazar. Doğrulama tutmazsa **hiçbir yazım** kuyruğa girmez.
///
/// Herkese açık kulüp belgesine yalnızca sayaç deltası yazılır; kimin
/// katıldığını / ayrıldığını gösteren bir yol yazılmaz (CD-137). Yönetici
/// aktörlü sayaç geçişinin işaretçisi yalnızca yönetimin okuduğu
/// `clubs/{clubId}/private/counter` yan belgesindedir (W-64). Günlük
/// kaydının kimliği sabittir (`FirestoreIds.activity` / `managerActivity` /
/// `roleActivity`): bir geçişe tek kayıt; yönetici kaydı varsa yeniden
/// yazılmaz. Yönetici kararlarının kritik bildirimi aynı transaction'a
/// eklenir (`NotificationDispatcher` `…InTransaction` üyeleri).
final class FirebaseMembershipRepository implements MembershipRepository {
  /// [_firestore] üzerinden okur ve yazar; günlük kaydını [_activity] ile
  /// aynı transaction'a ekler, bildirimleri [_dispatcher]'dan ister (başvuru:
  /// işlem sonrası fan-out; yönetici kararı: aynı transaction). Yeniden
  /// başvuru bekleme süresi, `retryAfter` ve geri alma penceresi [_clock]
  /// saatine göre hesaplanır.
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

  /// Hesap silmede (M14) `applicant` alanına yazılan anonim anlık görüntü
  /// (`Anonymization.applicantPayload`) — model biçiminde. Anlık görüntüsü
  /// buna eşit olan üyelik anonimleşmiştir (`AccountDeletionRepository`
  /// planı ve [anonymizeChunk] idempotentliği bununla karşılaştırır).
  static final MembershipApplicantModel anonymizedApplicant =
      MembershipApplicantModel.fromJson(
        Anonymization.applicantPayload()[FirestoreFields.applicant]! as Json,
      );

  /// Rol değişimi (M10) ve devirde (M11) hedef olabilen / atanabilen roller
  /// (`RolePolicy` `_isAssignable` ile aynı küme).
  static const Set<ClubRole> _assignable = {ClubRole.member, ClubRole.board};

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
    if (result case FirebaseSuccess(data: final membership)) {
      // Fan-out asıl işlem kesinleştikten sonra ve en iyi çabayladır:
      // bildirim hatası başvurunun sonucunu bozmaz (PLAN §10.5). Olay
      // anahtarı bu başvurunun `priorCount`'udur (CD-148).
      await _dispatcher.notifyApplicationReceived(
        clubId: clubId,
        applicantId: applicant.uid,
        sequence: membership.priorCount,
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
  Future<FirestoreResult<void>> updateApplicationNote({
    required String clubId,
    required String userId,
    required String note,
  }) async {
    final rejected =
        _rejectPair<void>(clubId, userId) ??
        RepositoryHelpers.rejectInvalidFields<void>({
          // Alt sınır kulübe bağlıdır; işlem içinde, kulüp okununca denetlenir.
          FirestoreFields.note: FieldValidators.applicationNote(
            note,
            requireNote: false,
          ),
        });
    if (rejected != null) return rejected;
    final membershipRef = _membershipRef(clubId, userId);
    final clubRef = _clubRef(clubId);
    final contactRef = _contactRef(clubId, userId);
    return _transact((tx) async {
      // Transaction kuralı: tüm okumalar yazımlardan önce.
      final current = _membershipOrNull(await tx.get(membershipRef));
      final clubSnapshot = await tx.get(clubRef);
      // Not yalnızca başvuru beklerken düzenlenir (rules-spec §3.4 U(b)).
      if (current?.status != MembershipStatus.pending) {
        throw const ConflictException.conflict();
      }
      // Not isteyen kulüpte not boşaltılamaz (başvurudaki koşulun aynısı).
      _requireNote(note, _liveClub(clubSnapshot));
      // Üyelik belgesi yazılmaz: yalnızca `note` + `updatedAt` (CD-137).
      tx.update(contactRef, {
        FirestoreFields.note: note,
        ...BaseFieldsPayload.update(),
      });
    });
  }

  @override
  Future<FirestoreResult<void>> anonymizeChunk({
    required String uid,
    required List<MembershipModel> memberships,
  }) async {
    if (RepositoryHelpers.rejectInvalidIds<void>({'uid': uid})
        case final rejected?) {
      return rejected;
    }
    if (memberships.length > Limits.accountDeletionChunk) {
      return RepositoryHelpers.invalidArgument(
        'anonymizeChunk: ${memberships.length} üyelik, sınır '
        '${Limits.accountDeletionChunk}',
      );
    }
    final clubIds = <String>[];
    for (final membership in memberships) {
      if (membership.userId != uid) {
        return RepositoryHelpers.invalidArgument(
          'anonymizeChunk: başka kullanıcının üyeliği',
        );
      }
      if (!RepositoryHelpers.isValidId(membership.clubId)) {
        return RepositoryHelpers.invalidArgument(
          'geçersiz kimlik: memberships.clubId',
        );
      }
      // Kimlik `clubId_uid`: aynı kulüp iki kez = aynı belge iki kez.
      if (clubIds.contains(membership.clubId)) {
        return RepositoryHelpers.invalidArgument(
          'anonymizeChunk: aynı kulüpten iki üyelik',
        );
      }
      clubIds.add(membership.clubId);
    }
    if (clubIds.isEmpty) return const FirebaseSuccess(null);

    // Günlük kaydı (`activity`) ve `users/{uid}` yazılmaz: silinmiş hesabın
    // Rules'ta açık olan tek yazımları üyelik, iletişim belgesi ve sayaçtır
    // (sözleşme `docs/plans/T-29.md` §4 g).
    return _transact((tx) async {
      // Transaction kuralı: tüm okumalar yazımlardan önce. Durum ve iletişim
      // belgesinin varlığı işlem içinde okunur: parça yeniden koşarsa güncel
      // durumu görür (idempotent).
      final current = <String, MembershipModel>{};
      final contacts = <String, FirestoreDoc>{};
      for (final clubId in clubIds) {
        final membership = _membershipOrNull(
          await tx.get(_membershipRef(clubId, uid)),
        );
        // Belge yok: anonimleştirilecek bir şey yok.
        if (membership == null) continue;
        // Bileşik kimlik tek başına kanıt değildir (`a_b` + `c` ile `a` +
        // `b_c` aynı kimliği üretir): sahiplik alanlardan okunur.
        if (membership.clubId != clubId || membership.userId != uid) {
          throw _Halt(
            FirestoreError.permissionDenied,
            '${_membershipRef(clubId, uid).path}: başka bir üyeliğin kimliği',
          );
        }
        current[clubId] = membership;
        final contact = FirestoreDoc.fromSnapshot(
          await tx.get(_contactRef(clubId, uid)),
        );
        if (contact != null) contacts[clubId] = contact;
      }

      for (final MapEntry(key: clubId, value: membership) in current.entries) {
        final next = switch (membership.status) {
          // Etkin başkan `left` olamaz (önce devir — M11; Rules M14):
          // durum aynı kalır, yalnızca kişisel veri boşalır (W-90).
          MembershipStatus.active when membership.role == ClubRole.president =>
            MembershipStatus.active,
          MembershipStatus.active => MembershipStatus.left,
          MembershipStatus.pending => MembershipStatus.cancelled,
          // Geçmiş üyelik: durum aynı kalır, yalnızca anlık görüntü boşalır.
          final terminal => terminal,
        };
        if (next != membership.status ||
            membership.applicant != anonymizedApplicant) {
          tx.update(_membershipRef(clubId, uid), {
            if (next != membership.status) FirestoreFields.status: next.json,
            ...Anonymization.applicantPayload(),
            ...BaseFieldsPayload.update(),
          });
        }
        // Danışman `memberCount`'a sayılmaz (M13): ayrılışı sayacı oynatmaz;
        // başkan ayrılmaz.
        if (membership.status == MembershipStatus.active &&
            (membership.role == ClubRole.member ||
                membership.role == ClubRole.board)) {
          _bumpMemberCount(tx, _clubRef(clubId), _departed);
        }
        final contact = contacts[clubId];
        if (contact != null && !_isAnonymizedContact(contact.data)) {
          tx.update(_contactRef(clubId, uid), {
            ...Anonymization.contactPayload(),
            ...BaseFieldsPayload.update(),
          });
        }
      }
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

  // ── Yönetici geçişleri (T-30; sözleşme docs/plans/T-30.md §4) ─────────

  @override
  Future<FirestoreResult<void>> approve({
    required String clubId,
    required String userId,
    required String actorId,
  }) => _decide(clubId: clubId, userId: userId, actorId: actorId);

  @override
  Future<FirestoreResult<void>> reject({
    required String clubId,
    required String userId,
    required String actorId,
    required RejectReason reason,
    String rejectNote = _noNote,
  }) {
    final rejected = RepositoryHelpers.rejectInvalidFields<void>({
      FirestoreFields.rejectNote: FieldValidators.rejectNote(rejectNote),
    });
    if (rejected != null) return Future.value(rejected);
    return _decide(
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
  }) => _undo(
    clubId: clubId,
    userId: userId,
    actorId: actorId,
    from: const {MembershipStatus.active, MembershipStatus.rejected},
  );

  @override
  Future<FirestoreResult<void>> undoRemoval({
    required String clubId,
    required String userId,
    required String actorId,
  }) => _undo(
    clubId: clubId,
    userId: userId,
    actorId: actorId,
    from: const {MembershipStatus.removed},
  );

  @override
  Future<FirestoreResult<void>> remove({
    required String clubId,
    required String userId,
    required String actorId,
    required ClubRole actorRole,
    bool actorIsSuper = false,
    String rejectNote = _noNote,
  }) async {
    final rejected =
        _rejectManaged<void>(clubId, userId, actorId) ??
        RepositoryHelpers.rejectInvalidFields<void>({
          FirestoreFields.rejectNote: FieldValidators.rejectNote(rejectNote),
        });
    if (rejected != null) return rejected;
    if (userId == actorId) {
      return RepositoryHelpers.invalidArgument(
        'remove: yönetici kendini çıkaramaz',
      );
    }
    // Danışman hiçbir yönetici yazımı yapamaz (Q-09); süper admin muaf.
    if (!actorIsSuper && actorRole == ClubRole.advisor) {
      return _violationOf(FirestoreRuleCode.notMember);
    }
    if (!RolePolicy.can(
      ClubPermission.removeMember,
      actorRole,
      isSuper: actorIsSuper,
    )) {
      return const FirebaseFailure(
        FirestoreError.permissionDenied,
        message: 'remove: aktör yönetici değil',
      );
    }
    final membershipRef = _membershipRef(clubId, userId);
    return _transact((tx) async {
      // Hesabı silinmiş üye de çıkarılır: kullanıcı belgesi okunmaz (W-89).
      final current = _managedMembership(
        await tx.get(membershipRef),
        clubId,
        userId,
      );
      // M9: yalnızca aktif üye çıkarılır.
      if (current == null || current.status != MembershipStatus.active) {
        throw const ConflictException.conflict();
      }
      switch (current.role) {
        case ClubRole.president:
          throw _violation(FirestoreRuleCode.presidentCannotBeRemoved);
        case ClubRole.advisor:
          throw _violation(FirestoreRuleCode.notMember);
        case ClubRole.member || ClubRole.board:
          break;
      }
      // Hiyerarşi: yönetim kurulu yalnızca `member` üyeyi çıkarır.
      if (!RolePolicy.canRemove(
        actorRole,
        current.role,
        isSuper: actorIsSuper,
      )) {
        throw _Halt(
          FirestoreError.permissionDenied,
          'remove: ${actorRole.json} ${current.role.json} üyeyi çıkaramaz',
        );
      }
      final entry = _managerActivityOf(
        clubId,
        actorId,
        ActivityKind.memberRemoved,
        userId,
        current.priorCount,
      );
      final logged = await _isLogged(tx, entry);

      tx.update(membershipRef, {
        FirestoreFields.status: MembershipStatus.removed.json,
        FirestoreFields.decidedAt: _firestore.serverTimestamp(),
        FirestoreFields.decidedBy: actorId,
        FirestoreFields.retryAfter: _retryAfter(),
        FirestoreFields.rejectReason: RejectReason.other.json,
        FirestoreFields.rejectNote: rejectNote,
        ...BaseFieldsPayload.update(),
      });
      _bumpManagedMemberCount(tx, clubId, userId, _departed);
      if (!logged) _activity.addToTransaction(tx, entry);
      await _dispatcher.notifyRemovedInTransaction(
        clubId: clubId,
        userId: userId,
        transaction: tx,
      );
    });
  }

  @override
  Future<FirestoreResult<void>> changeRole({
    required String clubId,
    required String userId,
    required ClubRole role,
    required String actorId,
  }) async {
    if (_rejectManaged<void>(clubId, userId, actorId) case final rejected?) {
      return rejected;
    }
    // Başkanlık yalnızca devirle (M11), danışmanlık M13 ile verilir.
    if (!_assignable.contains(role)) {
      return RepositoryHelpers.invalidArgument(
        'changeRole: atanamaz rol ${role.json}',
      );
    }
    final membershipRef = _membershipRef(clubId, userId);
    return _transact((tx) async {
      final current = _managedMembership(
        await tx.get(membershipRef),
        clubId,
        userId,
      );
      if (current == null || current.status != MembershipStatus.active) {
        throw const ConflictException.conflict();
      }
      switch (current.role) {
        // Başkanın rolü yalnızca devirle düşer (kulüp başkansız kalmaz).
        case ClubRole.president:
          throw _violation(FirestoreRuleCode.presidentCannotBeRemoved);
        case ClubRole.advisor:
          throw _violation(FirestoreRuleCode.notMember);
        case ClubRole.member || ClubRole.board:
          break;
      }
      if (current.role == role) {
        throw _Halt(
          FirestoreError.invalidArgument,
          'changeRole: rol zaten ${role.json}',
        );
      }
      final entry = _roleActivityOf(
        clubId,
        actorId,
        userId,
        role,
        current.priorCount,
      );
      final logged = await _isLogged(tx, entry);

      tx.update(membershipRef, {
        FirestoreFields.role: role.json,
        ...BaseFieldsPayload.update(),
      });
      if (!logged) _activity.addToTransaction(tx, entry);
      await _dispatcher.notifyRoleChangedInTransaction(
        clubId: clubId,
        userId: userId,
        role: role,
        transaction: tx,
      );
    });
  }

  @override
  Future<FirestoreResult<void>> transferPresidency({
    required String clubId,
    required String fromUserId,
    required String toUserId,
    required String actorId,
  }) async {
    if (RepositoryHelpers.rejectInvalidIds<void>({
          'clubId': clubId,
          'fromUserId': fromUserId,
          'toUserId': toUserId,
          'actorId': actorId,
        })
        case final rejected?) {
      return rejected;
    }
    if (fromUserId == toUserId) {
      return RepositoryHelpers.invalidArgument(
        'transferPresidency: başkanlık kendine devredilemez',
      );
    }
    final fromRef = _membershipRef(clubId, fromUserId);
    final toRef = _membershipRef(clubId, toUserId);
    final toUserRef = _firestore.doc(FirestoreCollections.users, toUserId);
    return _transact((tx) async {
      // Transaction kuralı: tüm okumalar yazımlardan önce.
      final from = _managedMembership(
        await tx.get(fromRef),
        clubId,
        fromUserId,
      );
      if (from == null ||
          from.status != MembershipStatus.active ||
          from.role != ClubRole.president) {
        throw const ConflictException.conflict();
      }
      final to = _managedMembership(await tx.get(toRef), clubId, toUserId);
      if (to == null ||
          to.status != MembershipStatus.active ||
          !_assignable.contains(to.role)) {
        throw const ConflictException.conflict();
      }
      // W-89 (b): yeni başkanın hesabı etkin olmalı (silinmiş / askıda değil).
      final toUser = _userOrNull(await tx.get(toUserRef));
      if (toUser?.status != UserStatus.active) {
        throw const ConflictException.conflict();
      }
      // Devrin tek günlük kaydı yeni başkana aittir (eski başkanın kurula
      // inişi ayrıca yazılmaz — sözleşme §4 a).
      final entry = _roleActivityOf(
        clubId,
        actorId,
        toUserId,
        ClubRole.president,
        to.priorCount,
      );
      final logged = await _isLogged(tx, entry);

      // Tek işlem: kulüp hiçbir an başkansız ya da iki başkanlı kalmaz.
      tx
        ..update(fromRef, {
          FirestoreFields.role: ClubRole.board.json,
          ...BaseFieldsPayload.update(),
        })
        ..update(toRef, {
          FirestoreFields.role: ClubRole.president.json,
          ...BaseFieldsPayload.update(),
        })
        ..update(_clubRef(clubId), {
          FirestoreFields.presidentId: toUserId,
          ...BaseFieldsPayload.update(),
        });
      if (!logged) _activity.addToTransaction(tx, entry);
      // İki ayrı olay (iki olay anahtarı): yeni başkan, eski başkan.
      await _dispatcher.notifyRoleChangedInTransaction(
        clubId: clubId,
        userId: toUserId,
        role: ClubRole.president,
        transaction: tx,
      );
      await _dispatcher.notifyRoleChangedInTransaction(
        clubId: clubId,
        userId: fromUserId,
        role: ClubRole.board,
        transaction: tx,
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
  ) => listByStatus(clubId, MembershipStatus.pending, page);

  @override
  Future<FirestoreResult<PageResult<MembershipModel>>> listByStatus(
    String clubId,
    MembershipStatus status,
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
          status,
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
      if (!instant) _requireNote(note, club);

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

  /// M5 (onay — [reason] `null`) ve M6 (ret) ortak geçişi: `pending` →
  /// `active` | `rejected`; aynı işlemde (onayda) `memberCount +1` ve sayaç
  /// yan belgesi, günlük kaydı (yoksa) ve başvurana karar bildirimi.
  ///
  /// Başvuranın hesabı silinmişse (ya da kullanıcı belgesi yoksa) karar
  /// verilemez: [FirestoreError.conflict] (W-89; Rules
  /// `get(users/{userId}).data.status != 'deleted'`).
  Future<FirestoreResult<void>> _decide({
    required String clubId,
    required String userId,
    required String actorId,
    RejectReason? reason,
    String rejectNote = _noNote,
  }) async {
    if (_rejectManaged<void>(clubId, userId, actorId) case final rejected?) {
      return rejected;
    }
    // Karar veren başvuranın kendisi olamaz (rules-spec §3.4 M5).
    if (userId == actorId) {
      return const FirebaseFailure(
        FirestoreError.permissionDenied,
        message: 'karar: başvuran kendi başvurusuna karar veremez',
      );
    }
    final approved = reason == null;
    final membershipRef = _membershipRef(clubId, userId);
    final userRef = _firestore.doc(FirestoreCollections.users, userId);
    return _transact((tx) async {
      // Transaction kuralı: tüm okumalar yazımlardan önce.
      final current = _managedMembership(
        await tx.get(membershipRef),
        clubId,
        userId,
      );
      // Başka bir yönetici az önce karar vermiş olabilir (DLG-18).
      if (current == null || current.status != MembershipStatus.pending) {
        throw const ConflictException.conflict();
      }
      // W-89 (a): hesabı silinmiş (anonimleşmiş) başvuran onaylanamaz.
      final applicant = _userOrNull(await tx.get(userRef));
      if (applicant == null || applicant.isAnonymized) {
        throw const ConflictException.conflict();
      }
      final entry = _managerActivityOf(
        clubId,
        actorId,
        approved
            ? ActivityKind.applicationApproved
            : ActivityKind.applicationRejected,
        userId,
        current.priorCount,
      );
      final logged = await _isLogged(tx, entry);

      tx.update(membershipRef, {
        if (approved) ...{
          FirestoreFields.status: MembershipStatus.active.json,
          FirestoreFields.role: ClubRole.member.json,
        } else ...{
          FirestoreFields.status: MembershipStatus.rejected.json,
          FirestoreFields.rejectReason: reason.json,
          FirestoreFields.rejectNote: rejectNote,
          FirestoreFields.retryAfter: _retryAfter(),
        },
        FirestoreFields.decidedAt: _firestore.serverTimestamp(),
        FirestoreFields.decidedBy: actorId,
        ...BaseFieldsPayload.update(),
      });
      if (approved) _bumpManagedMemberCount(tx, clubId, userId, _joined);
      if (!logged) _activity.addToTransaction(tx, entry);
      await _dispatcher.notifyApplicationDecidedInTransaction(
        clubId: clubId,
        applicantId: userId,
        approved: approved,
        transaction: tx,
      );
    });
  }

  /// M12 — [actorId] yöneticisinin kendi kararını geri alır: önceki durum
  /// [from] içinde olmalı (değilse [FirestoreError.conflict]); kararı veren
  /// [actorId] değilse ya da `Limits.managerUndoWindow` geçmişse kodsuz
  /// [FirestoreError.ruleViolation] (sözleşme §4 d — yeni kural kodu yok).
  ///
  /// - `active` (onay) / `rejected` (ret) → `pending`; onay geri alınırsa
  ///   `memberCount −1` + sayaç yan belgesi. Pencere içinde rolü değişmiş
  ///   (`board`) üyenin onayı geri alınmaz ([FirestoreError.conflict]).
  /// - `removed` → `active` (rol `member`), `memberCount +1` + yan belge.
  ///
  /// Karar alanları `null`'a çekilir; günlük ve bildirim yazılmaz.
  Future<FirestoreResult<void>> _undo({
    required String clubId,
    required String userId,
    required String actorId,
    required Set<MembershipStatus> from,
  }) async {
    if (_rejectManaged<void>(clubId, userId, actorId) case final rejected?) {
      return rejected;
    }
    final membershipRef = _membershipRef(clubId, userId);
    return _transact((tx) async {
      final current = _managedMembership(
        await tx.get(membershipRef),
        clubId,
        userId,
      );
      if (current == null || !from.contains(current.status)) {
        throw const ConflictException.conflict();
      }
      // Rules: `decidedBy == uid() ∧ request.time < decidedAt + 30 sn`.
      final decidedAt = current.decidedAt;
      if (current.decidedBy != actorId ||
          decidedAt == null ||
          !_clock.nowUtc().isBefore(decidedAt.add(Limits.managerUndoWindow))) {
        throw const _Halt(
          FirestoreError.ruleViolation,
          'geri alma: karar başkasının ya da pencere kapandı',
        );
      }
      final restore = current.status == MembershipStatus.removed;
      if (current.status == MembershipStatus.active &&
          current.role != ClubRole.member) {
        throw const ConflictException.conflict();
      }

      tx.update(membershipRef, {
        if (restore) ...{
          FirestoreFields.status: MembershipStatus.active.json,
          FirestoreFields.role: ClubRole.member.json,
        } else
          FirestoreFields.status: MembershipStatus.pending.json,
        FirestoreFields.decidedAt: null,
        FirestoreFields.decidedBy: null,
        FirestoreFields.retryAfter: null,
        FirestoreFields.rejectReason: null,
        FirestoreFields.rejectNote: null,
        ...BaseFieldsPayload.update(),
      });
      if (restore) {
        _bumpManagedMemberCount(tx, clubId, userId, _joined);
      } else if (current.status == MembershipStatus.active) {
        _bumpManagedMemberCount(tx, clubId, userId, _departed);
      }
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

  /// `private/contact` belgesi zaten anonim mi (`Anonymization.contactPayload`
  /// alanlarının hepsi belgede aynı değerde)?
  static bool _isAnonymizedContact(Json contact) =>
      Anonymization.contactPayload().entries.every(
        (field) => contact[field.key] == field.value,
      );

  /// [note] [club] kulübünün başvuru notu koşulunu (`requireNote`, üst sınır)
  /// karşılamıyorsa işlemi [FirestoreError.invalidArgument] ile durdurur.
  static void _requireNote(String note, ClubModel club) {
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

  /// Yönetici aktörlü `memberCount` geçişi (M5, M9, M12): kulübe yalnızca
  /// delta yazılır; geçişin üyelik yolu (işaretçi) herkese açık kulüp
  /// belgesine değil, yalnızca yönetimin okuduğu
  /// `clubs/{clubId}/private/counter` yan belgesine **aynı işlemde** yazılır
  /// (W-64; Rules işaretçiyle üyelik geçişini birbirine bağlar).
  void _bumpManagedMemberCount(
    Transaction tx,
    String clubId,
    String userId,
    int delta,
  ) {
    _bumpMemberCount(tx, _clubRef(clubId), delta);
    tx.set(_counterRef(clubId), {
      FirestoreFields.clubId: clubId,
      FirestoreFields.lastMembershipRef: FirestoreIds.membershipRef(
        clubId,
        userId,
      ),
      ...BaseFieldsPayload.update(),
    });
  }

  /// Ret / çıkarma sonrası yeniden başvurunun açılacağı an (istemci saati +
  /// `Limits.reapplyCooldown`; Rules ±`Limits.clockSkewTolerance`).
  Timestamp _retryAfter() =>
      Timestamp.fromDate(_clock.nowUtc().add(Limits.reapplyCooldown).toUtc());

  /// [entry] günlük kaydı zaten var mı? Sabit kimlikli kayıt bir kez yazılır
  /// (günlük değiştirilemez — CD-137); işlem içinde, yazımlardan önce okunur.
  Future<bool> _isLogged(Transaction tx, ActivityDraft entry) async =>
      (await tx.get(
        _firestore.doc(FirestoreCollections.activity, entry.id!),
      )).exists;

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

  /// Yönetici geçişinin okuduğu üyelik ([_membershipOrNull]). Bileşik kimlik
  /// tek başına kanıt değildir (`a_b` + `c` ile `a` + `b_c` aynı kimliği
  /// üretir): belgenin alanları [clubId] / [userId] ile tutmuyorsa işlem
  /// [FirestoreError.permissionDenied] ile durur.
  static MembershipModel? _managedMembership(
    DocumentSnapshot<Json> snapshot,
    String clubId,
    String userId,
  ) {
    final membership = _membershipOrNull(snapshot);
    if (membership != null &&
        (membership.clubId != clubId || membership.userId != userId)) {
      throw _Halt(
        FirestoreError.permissionDenied,
        '${snapshot.reference.path}: başka bir üyeliğin kimliği',
      );
    }
    return membership;
  }

  /// Okunan kullanıcı; belge yoksa `null`. Ayrıştırılamıyorsa
  /// [FirestoreError.parse] ile işlemi durdurur.
  static UserModel? _userOrNull(DocumentSnapshot<Json> snapshot) {
    final doc = FirestoreDoc.fromSnapshot(snapshot);
    return doc == null ? null : _parsed(doc, _userOf);
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

  /// [_violation]'ın işlem dışı karşılığı (ağ çağrısı yapmadan ret).
  static FirestoreResult<T> _violationOf<T>(FirestoreRuleCode code) =>
      FirebaseFailure(
        FirestoreError.ruleViolation,
        detail: FirestoreFailureDetail(code),
      );

  /// Yöneticinin üyelik **kararı** için günlük kaydı (`application_approved`,
  /// `application_rejected`, `member_removed`): eylemi yapan [actorId],
  /// hedef [userId]; kimlik `FirestoreIds.managerActivity` (sabit).
  static ActivityDraft _managerActivityOf(
    String clubId,
    String actorId,
    ActivityKind kind,
    String userId,
    int priorCount,
  ) => ActivityDraft(
    clubId: clubId,
    actorId: actorId,
    kind: kind,
    refs: ActivityRefsModel(userId: userId),
    id: FirestoreIds.managerActivity(
      clubId,
      actorId,
      kind.json,
      userId,
      priorCount,
    ),
  );

  /// Rol değişimi (M10) ve devrin (M11) günlük kaydı: refs hedef ve yeni
  /// rol; kimlik `FirestoreIds.roleActivity` (sabit).
  static ActivityDraft _roleActivityOf(
    String clubId,
    String actorId,
    String userId,
    ClubRole role,
    int priorCount,
  ) => ActivityDraft(
    clubId: clubId,
    actorId: actorId,
    kind: ActivityKind.roleChanged,
    refs: ActivityRefsModel(userId: userId, role: role),
    id: FirestoreIds.roleActivity(
      clubId,
      actorId,
      userId,
      role.json,
      priorCount,
    ),
  );

  /// Yönetici geçişlerinin kimlik denetimi: kulüp, hedef ve aktör.
  static FirestoreResult<T>? _rejectManaged<T>(
    String clubId,
    String userId,
    String actorId,
  ) => RepositoryHelpers.rejectInvalidIds<T>({
    'clubId': clubId,
    'userId': userId,
    'actorId': actorId,
  });

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

  /// `clubs/{clubId}/private/counter` — yönetici sayaç işaretçisi (W-64).
  DocumentReference<Json> _counterRef(String clubId) => _firestore.doc(
    RepositoryHelpers.subcollectionPath(
      FirestoreCollections.clubs,
      clubId,
      FirestoreCollections.privateSub,
    ),
    FirestoreCollections.counterDoc,
  );

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
/// (bulunamadı, ayrıştırılamadı, geçersiz girdi, yetki, kodsuz iş kuralı —
/// M12 geri alma penceresi). Çakışma ve kodlu iş kuralı reddi bunun yerine
/// `ConflictException` ile bildirilir.
final class _Halt implements Exception {
  const _Halt(this.error, this.message);

  final FirestoreError error;
  final String? message;
}
