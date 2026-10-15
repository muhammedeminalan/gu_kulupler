// `MembershipRepository` fake'i (PLAN §16.3): üyelikleri ve iletişim
// belgelerini bellekte tutar; üyelik durum makinesinin başvuran / üye
// satırlarını (M1–M4, M7, M8), bekleyen başvurunun not düzenlemesini
// (T-16), hesap silmeyi (M14, T-29) ve yönetici geçişlerini (M5, M6,
// M9–M12; T-30 — `managerEvents`, `userStatuses`) gerçek repository ile aynı
// sonuçlarla uygular.
//
//   final clubs = FakeClubRepository()..put('c01');
//   final memberships = FakeMembershipRepository(clock, clubs: clubs);
//   memberships.put(MembershipModel(clubId: 'c01', userId: 'u1', …));
//   memberships.watchMyMembershipsController('u1').add(const FirebaseFailure(…));
//   expect(memberships.applied.single.status, MembershipStatus.pending);
//   expect(memberships.noteUpdates.single.note, 'Güncel not.');
//
// Kulüp koşulları (onay, not zorunluluğu, başvuruya açıklık, askı) ve
// `memberCount` sayacı [FakeMembershipRepository.clubRepository] üzerinden
// okunur / işlenir; `registerDefaultFakes` kayıtlı `FakeClubRepository`'yi
// paylaştırır. Sonuçların gerçek `FirebaseMembershipRepository` ile aynı
// olduğunu `fake_membership_repository_test.dart` karşılaştırmalı sınar
// (önceki durum × kulüp biçimi × çağrı).
//
// Canlı akış: `watchMyMemberships(uid)` dinlenince o anki üyelikleri yayar,
// her değişiklikte yeniden yayar; test `watchMyMembershipsController(uid)`
// ile elle olay (hata dahil) yazabilir. `activeListeners` açık dinleyici
// sayısıdır. Başarılı `updateApplicationNote` çağrıları `noteUpdates`
// listesine düşer; not `contacts` içinde değişir, üyelik belgesi ve akış
// değişmez. Silme metodu yoktur (D-10).
import 'dart:async';

import 'package:gu_data/gu_data.dart';

import 'fake_base.dart';
import 'fake_club_repository.dart';
import 'fake_pager.dart';

/// Başarılı `apply` / `joinInstant` çağrısı: argümanlar ve oluşan durum.
typedef FakeApplication = ({
  String clubId,
  String userId,
  String email,
  String note,
  MembershipStatus status,
});

/// Başarılı `updateApplicationNote` çağrısı.
typedef FakeNoteUpdate = ({String clubId, String userId, String note});

/// Başarılı yönetici geçişi (T-30): günlük türü, hedef, aktör, (rol / devir)
/// yeni rol.
typedef FakeManagerEvent = ({
  ActivityKind kind,
  String clubId,
  String userId,
  String actorId,
  ClubRole? role,
});

/// Akış olayı: kullanıcının üyelikleri ya da okuma hatası.
typedef FakeMembershipEvent = FirestoreResult<List<MembershipModel>>;

final class FakeMembershipRepository extends FakeBase
    implements MembershipRepository {
  /// Saat yeniden başvuru bekleme süresini ve zaman alanlarını belirler;
  /// [clubs] verilmezse boş bir `FakeClubRepository` kurulur.
  FakeMembershipRepository(this._clock, {FakeClubRepository? clubs})
    : clubRepository = clubs ?? FakeClubRepository();

  final AppClock _clock;

  /// Kulüp koşullarının okunduğu ve `memberCount`'un işlendiği fake.
  final FakeClubRepository clubRepository;

  /// `memberships/{clubId}_{userId}` belgeleri (anahtar = belge kimliği).
  /// Test ön veriyi [put] ile yazar (akış da güncellenir).
  final Map<String, MembershipModel> memberships = <String, MembershipModel>{};

  /// `memberships/{id}/private/contact` belgeleri (anahtar = üyelik kimliği).
  final Map<String, MembershipContactModel> contacts =
      <String, MembershipContactModel>{};

  /// Başarılı `apply` / `joinInstant` çağrıları, sırasıyla.
  final List<FakeApplication> applied = <FakeApplication>[];

  /// Başarılı `updateApplicationNote` çağrıları, sırasıyla.
  final List<FakeNoteUpdate> noteUpdates = <FakeNoteUpdate>[];

  /// Başarılı yönetici geçişleri (T-30), sırasıyla: gerçek repository'nin
  /// aynı işlemde yazdığı günlük kaydı + bildirim yerine. Geri al
  /// (M12) kayıt üretmez.
  final List<FakeManagerEvent> managerEvents = <FakeManagerEvent>[];

  /// Kullanıcı hesap durumları (W-89): `deleted` başvurana karar verilmez,
  /// `active` olmayan üyeye başkanlık devredilmez. Kaydı olmayan kullanıcı
  /// etkin sayılır (gerçek repository kullanıcı belgesini okur).
  final Map<String, UserStatus> userStatuses = <String, UserStatus>{};

  /// T-37 · atanan başkan / danışmanın profil anlık görüntüsü (gerçek
  /// repository `users/{uid}`'yi işlem içinde okur; `FakeAdminRepository`
  /// kayıtlı `FakeUserRepository`'den doldurur). Yoksa önceki üyeliğin
  /// görüntüsü, o da yoksa yalnızca `avatarSeed` = uid.
  final Map<String, MembershipApplicantModel> applicants =
      <String, MembershipApplicantModel>{};

  /// Açık `watchMyMemberships` dinleyicisi sayısı.
  int activeListeners = 0;

  final Map<String, StreamController<FakeMembershipEvent>> _controllers =
      <String, StreamController<FakeMembershipEvent>>{};
  final FakePager _pager = FakePager();

  /// [uid] akışının denetleyicisi: test elle olay yazar (hata olayı dahil).
  StreamController<FakeMembershipEvent> watchMyMembershipsController(
    String uid,
  ) => _controllers.putIfAbsent(
    uid,
    StreamController<FakeMembershipEvent>.broadcast,
  );

  /// [membership] belgesini yazar (varsa üzerine) ve sahibinin akışını
  /// günceller. [email] verilirse iletişim belgesi de kurulur.
  void put(MembershipModel membership, {String? email, String note = ''}) {
    memberships[membership.id] = membership;
    if (email != null) {
      contacts[membership.id] = MembershipContactModel(
        email: email,
        emailLower: email.toLowerCase(),
        note: note,
      );
    }
    _emit(membership.userId);
  }

  @override
  Stream<FirestoreResult<List<MembershipModel>>> watchMyMemberships(
    String uid,
  ) {
    record('watchMyMemberships', [uid]);
    if (!RepositoryHelpers.isValidId(uid)) {
      return Stream.value(
        const FirebaseFailure(FirestoreError.invalidArgument),
      );
    }
    final source = watchMyMembershipsController(uid);
    late final StreamController<FakeMembershipEvent> output;
    StreamSubscription<FakeMembershipEvent>? subscription;
    output = StreamController<FakeMembershipEvent>(
      onListen: () {
        activeListeners++;
        // İlk anlık görüntü (Firestore dinleyicisi gibi), sonra değişiklikler.
        output.add(FirebaseSuccess(_mine(uid)));
        subscription = source.stream.listen(output.add);
      },
      onCancel: () {
        activeListeners--;
        return subscription?.cancel();
      },
    );
    return output.stream;
  }

  @override
  Future<FirestoreResult<MembershipModel?>> getMembership(
    String clubId,
    String userId,
  ) async {
    record('getMembership', [clubId, userId]);
    if (_rejected<MembershipModel?>([clubId, userId]) case final failure?) {
      return failure;
    }
    return FirebaseSuccess(memberships[_key(clubId, userId)]);
  }

  @override
  Future<FirestoreResult<MembershipModel>> apply({
    required String clubId,
    required UserModel applicant,
    required String email,
    required String note,
  }) async {
    record('apply', [clubId, applicant.uid, email, note]);
    return _enter(clubId, applicant, email, note, MembershipStatus.pending);
  }

  @override
  Future<FirestoreResult<MembershipModel>> joinInstant({
    required String clubId,
    required UserModel applicant,
    required String email,
  }) async {
    record('joinInstant', [clubId, applicant.uid, email]);
    return _enter(clubId, applicant, email, '', MembershipStatus.active);
  }

  @override
  Future<FirestoreResult<void>> cancelApplication({
    required String clubId,
    required String userId,
  }) async {
    record('cancelApplication', [clubId, userId]);
    if (_rejected<void>([clubId, userId]) case final failure?) return failure;
    final current = memberships[_key(clubId, userId)];
    if (current?.status != MembershipStatus.pending) return _conflict();
    _write(current!.copyWith(status: MembershipStatus.cancelled));
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<void>> updateApplicationNote({
    required String clubId,
    required String userId,
    required String note,
  }) async {
    record('updateApplicationNote', [clubId, userId, note]);
    if (_rejected<void>([clubId, userId]) case final failure?) return failure;
    if (FieldValidators.applicationNote(note, requireNote: false) != null) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    final key = _key(clubId, userId);
    if (memberships[key]?.status != MembershipStatus.pending) {
      return _conflict();
    }
    final club = clubRepository.clubs[clubId];
    final contact = contacts[key];
    // İletişim belgesi olmayan başvuruda gerçek güncelleme `not-found` verir.
    if (club == null || club.isDeleted || contact == null) {
      return const FirebaseFailure(FirestoreError.notFound);
    }
    if (FieldValidators.applicationNote(note, requireNote: club.requireNote) !=
        null) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    // Üyelik belgesi yazılmaz: akış yeniden yayılmaz (CD-137).
    contacts[key] = contact.copyWith(note: note, updatedAt: _clock.nowUtc());
    noteUpdates.add((clubId: clubId, userId: userId, note: note));
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<void>> leave({
    required String clubId,
    required String userId,
  }) async {
    record('leave', [clubId, userId]);
    if (_rejected<void>([clubId, userId]) case final failure?) return failure;
    final current = memberships[_key(clubId, userId)];
    if (current == null || current.status != MembershipStatus.active) {
      return _conflict();
    }
    switch (current.role) {
      case ClubRole.president:
        return _violation(FirestoreRuleCode.presidentCannotLeave);
      case ClubRole.advisor:
        return _violation(FirestoreRuleCode.notMember);
      case ClubRole.member || ClubRole.board:
        break;
    }
    // Sayaç belgesi olmayan kulüpte işlem bütünüyle düşer (gerçek
    // transaction'da `clubs/{id}` güncellemesi `not-found` verir).
    if (!clubRepository.clubs.containsKey(clubId)) {
      return const FirebaseFailure(FirestoreError.notFound);
    }
    _bumpMemberCount(clubId, -1);
    _write(current.copyWith(status: MembershipStatus.left));
    return const FirebaseSuccess(null);
  }

  /// M14 (T-29; sözleşme `docs/plans/T-29.md` §4 a): gerçek repository gibi
  /// parça bütünüyle uygulanır ya da hiç uygulanmaz. Her üyelik için
  /// `applicant` anonim anlık görüntü olur, `active → left` (üye / yönetimde
  /// `memberCount −1`, danışmanda sayaç yok; etkin başkan `active` kalır,
  /// sayaç yok), `pending → cancelled`, geçmiş durumlar aynı kalır; iletişim
  /// belgesi boşaltılır. Belgesi olmayan üyelik atlanır.
  @override
  Future<FirestoreResult<void>> anonymizeChunk({
    required String uid,
    required List<MembershipModel> memberships,
  }) async {
    record('anonymizeChunk', [uid, memberships.map((m) => m.clubId).toList()]);
    if (_rejected<void>([uid]) case final failure?) return failure;
    if (memberships.length > Limits.accountDeletionChunk ||
        memberships.any((membership) => membership.userId != uid)) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    final current = [
      for (final membership in memberships)
        ?this.memberships[_key(membership.clubId, uid)],
    ];
    // Sayaç belgesi olmayan kulüpte işlem bütünüyle düşer (gerçek
    // transaction'da `clubs/{id}` güncellemesi `not-found` verir).
    bool counted(MembershipModel membership) =>
        membership.status == MembershipStatus.active &&
        (membership.role == ClubRole.member ||
            membership.role == ClubRole.board);
    if (current.any(
      (membership) =>
          counted(membership) &&
          !clubRepository.clubs.containsKey(membership.clubId),
    )) {
      return const FirebaseFailure(FirestoreError.notFound);
    }
    for (final membership in current) {
      final next = switch (membership.status) {
        // Etkin başkan `left` olamaz: durum aynı, yalnızca kişisel veri boşalır.
        MembershipStatus.active when membership.role == ClubRole.president =>
          MembershipStatus.active,
        MembershipStatus.active => MembershipStatus.left,
        MembershipStatus.pending => MembershipStatus.cancelled,
        final terminal => terminal,
      };
      if (counted(membership)) _bumpMemberCount(membership.clubId, -1);
      _write(
        membership.copyWith(
          status: next,
          applicant: FirebaseMembershipRepository.anonymizedApplicant,
        ),
      );
      if (contacts[membership.id] case final contact?) {
        contacts[membership.id] = contact.copyWith(
          email: '',
          emailLower: '',
          note: '',
          updatedAt: _clock.nowUtc(),
        );
      }
    }
    return const FirebaseSuccess(null);
  }

  // ── Yönetici geçişleri (T-30; sözleşme docs/plans/T-30.md §4) ─────────
  // Denetim sırası ve sonuçlar `FirebaseMembershipRepository` ile aynıdır
  // (`fake_membership_repository_test.dart` karşılaştırır). Rules'un tek
  // başına verdiği retler (danışman / başka kulübün yöneticisi / askıdaki
  // kulüp) burada bilinmez: test `failNext(FirestoreError.permissionDenied)`
  // ile kurar. Başarılı her geçiş [managerEvents]'e düşer (günlük + bildirim
  // yerine).

  @override
  Future<FirestoreResult<void>> approve({
    required String clubId,
    required String userId,
    required String actorId,
  }) async {
    record('approve', [clubId, userId, actorId]);
    return _decide(clubId, userId, actorId);
  }

  @override
  Future<FirestoreResult<void>> reject({
    required String clubId,
    required String userId,
    required String actorId,
    required RejectReason reason,
    String rejectNote = '',
  }) async {
    record('reject', [clubId, userId, actorId, reason, rejectNote]);
    if (_rejected<void>([clubId, userId, actorId]) case final failure?) {
      return failure;
    }
    if (FieldValidators.rejectNote(rejectNote) != null) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    return _decide(
      clubId,
      userId,
      actorId,
      reason: reason,
      rejectNote: rejectNote,
      checked: true,
    );
  }

  @override
  Future<FirestoreResult<void>> undoDecision({
    required String clubId,
    required String userId,
    required String actorId,
  }) async {
    record('undoDecision', [clubId, userId, actorId]);
    return _undo(clubId, userId, actorId, const {
      MembershipStatus.active,
      MembershipStatus.rejected,
    });
  }

  @override
  Future<FirestoreResult<void>> undoRemoval({
    required String clubId,
    required String userId,
    required String actorId,
  }) async {
    record('undoRemoval', [clubId, userId, actorId]);
    return _undo(clubId, userId, actorId, const {MembershipStatus.removed});
  }

  @override
  Future<FirestoreResult<void>> remove({
    required String clubId,
    required String userId,
    required String actorId,
    required ClubRole actorRole,
    bool actorIsSuper = false,
    String rejectNote = '',
  }) async {
    record('remove', [clubId, userId, actorId, actorRole, actorIsSuper]);
    if (_rejected<void>([clubId, userId, actorId]) case final failure?) {
      return failure;
    }
    if (FieldValidators.rejectNote(rejectNote) != null || userId == actorId) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    if (!actorIsSuper && actorRole == ClubRole.advisor) {
      return _violation(FirestoreRuleCode.notMember);
    }
    if (!RolePolicy.can(
      ClubPermission.removeMember,
      actorRole,
      isSuper: actorIsSuper,
    )) {
      return const FirebaseFailure(FirestoreError.permissionDenied);
    }
    final current = memberships[_key(clubId, userId)];
    if (current == null || current.status != MembershipStatus.active) {
      return _conflict();
    }
    switch (current.role) {
      case ClubRole.president:
        return _violation(FirestoreRuleCode.presidentCannotBeRemoved);
      case ClubRole.advisor:
        return _violation(FirestoreRuleCode.notMember);
      case ClubRole.member || ClubRole.board:
        break;
    }
    if (!RolePolicy.canRemove(actorRole, current.role, isSuper: actorIsSuper)) {
      return const FirebaseFailure(FirestoreError.permissionDenied);
    }
    if (!clubRepository.clubs.containsKey(clubId)) {
      return const FirebaseFailure(FirestoreError.notFound);
    }
    final now = _clock.nowUtc();
    _write(
      current.copyWith(
        status: MembershipStatus.removed,
        decidedAt: now,
        decidedBy: actorId,
        retryAfter: now.add(Limits.reapplyCooldown),
        rejectReason: RejectReason.other,
        rejectNote: rejectNote,
      ),
    );
    _bumpMemberCount(clubId, -1);
    _logManager(ActivityKind.memberRemoved, clubId, userId, actorId);
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<void>> changeRole({
    required String clubId,
    required String userId,
    required ClubRole role,
    required String actorId,
  }) async {
    record('changeRole', [clubId, userId, role, actorId]);
    if (_rejected<void>([clubId, userId, actorId]) case final failure?) {
      return failure;
    }
    if (!_assignable.contains(role)) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    final current = memberships[_key(clubId, userId)];
    if (current == null || current.status != MembershipStatus.active) {
      return _conflict();
    }
    switch (current.role) {
      case ClubRole.president:
        return _violation(FirestoreRuleCode.presidentCannotBeRemoved);
      case ClubRole.advisor:
        return _violation(FirestoreRuleCode.notMember);
      case ClubRole.member || ClubRole.board:
        break;
    }
    if (current.role == role) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    _write(current.copyWith(role: role));
    _logManager(ActivityKind.roleChanged, clubId, userId, actorId, role: role);
    return const FirebaseSuccess(null);
  }

  /// M13 (T-37) — danışman hesabını bağlar / bağı kaldırır; sonuçlar gerçek
  /// `FirebaseMembershipRepository.setAdvisor` ile aynıdır. Bağla: kulüpte
  /// danışman kaydı (ad / ünvan) yoksa `failedPrecondition`; zaten bağlıysa
  /// yazım yok, başarı; başka hesap bağlıysa ya da hedefin etkin / bekleyen
  /// üyeliği varsa ya da hesabı etkin değilse (`userStatuses`) `conflict`;
  /// aksi halde üyelik `active` + `advisor` (karar alanları boş) ve
  /// `advisor.userId`. Kaldır: etkin danışman üyeliği `left` + `advisor
  /// .userId` boşalır; bayat bağda (üyelik etkin danışman değil) yalnızca
  /// bağ boşalır; ikisi de değilse `conflict`. `memberCount` değişmez. İletişim
  /// belgesi fake'te yazılmaz (hesap e-postası `FakeUserRepository`'dedir).
  @override
  Future<FirestoreResult<void>> setAdvisor({
    required String clubId,
    required String userId,
    required bool active,
  }) async {
    record('setAdvisor', [clubId, userId, active]);
    if (_rejected<void>([clubId, userId]) case final failure?) return failure;
    final club = clubRepository.clubs[clubId];
    if (club == null || club.isDeleted) {
      return const FirebaseFailure(FirestoreError.notFound);
    }
    final key = _key(clubId, userId);
    final current = memberships[key];
    final isAdvisor =
        current?.status == MembershipStatus.active &&
        current?.role == ClubRole.advisor;
    final advisor = club.advisor;
    if (!active) {
      final linked = advisor?.userId == userId;
      if (!isAdvisor && !linked) return _conflict();
      if (isAdvisor) _write(current!.copyWith(status: MembershipStatus.left));
      if (linked) {
        clubRepository.clubs[clubId] = club.copyWith(
          advisor: advisor!.copyWith(clearUserId: true),
        );
      }
      return const FirebaseSuccess(null);
    }
    if (advisor == null) {
      return const FirebaseFailure(FirestoreError.failedPrecondition);
    }
    if (isAdvisor && advisor.userId == userId) {
      return const FirebaseSuccess(null);
    }
    if (advisor.userId != null ||
        current?.status == MembershipStatus.active ||
        current?.status == MembershipStatus.pending) {
      return _conflict();
    }
    if (userStatuses[userId] case final status?
        when status != UserStatus.active) {
      return _conflict();
    }
    final now = _clock.nowUtc();
    _write(
      MembershipModel(
        clubId: clubId,
        userId: userId,
        applicant: _appointee(userId, current),
        status: MembershipStatus.active,
        role: ClubRole.advisor,
        appliedAt: now,
        priorCount: current?.priorCount ?? 0,
        createdAt: current?.createdAt ?? now,
      ),
    );
    clubRepository.clubs[clubId] = club.copyWith(
      advisor: advisor.copyWith(userId: userId),
    );
    return const FirebaseSuccess(null);
  }

  /// T-37 — `AdminRepository.assignPresident`'in üyelik tarafı (gerçek
  /// `FirebaseMembershipRepository.assignPresident` ile aynı sonuçlar):
  /// hedef etkin `member` / `board` → [transferPresidency] (M11; eski başkan
  /// kulübün `presidentId`'sidir); üyeliği yok ya da geçmişte → hedef
  /// `active` + `president`, eski başkan `board`, `presidentId` ve
  /// `memberCount +1` (W-94). Hedef zaten başkan → `invalidArgument`; hedef
  /// danışman → `ruleViolation(notMember)`; hedef `pending`, hesabı etkin
  /// değil ya da eski başkanın üyeliği etkin başkan değil → `conflict`.
  Future<FirestoreResult<void>> assignPresident({
    required String clubId,
    required String toUserId,
    required String actorId,
  }) async {
    record('assignPresident', [clubId, toUserId, actorId]);
    if (_rejected<void>([clubId, toUserId, actorId]) case final failure?) {
      return failure;
    }
    final club = clubRepository.clubs[clubId];
    if (club == null || club.isDeleted) {
      return const FirebaseFailure(FirestoreError.notFound);
    }
    final fromUserId = club.presidentId;
    if (fromUserId == toUserId) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    final to = memberships[_key(clubId, toUserId)];
    if (to?.status == MembershipStatus.active) {
      if (to!.role == ClubRole.advisor) {
        return _violation(FirestoreRuleCode.notMember);
      }
      return transferPresidency(
        clubId: clubId,
        fromUserId: fromUserId,
        toUserId: toUserId,
        actorId: actorId,
      );
    }
    if (to?.status == MembershipStatus.pending) return _conflict();
    if (userStatuses[toUserId] case final status?
        when status != UserStatus.active) {
      return _conflict();
    }
    final from = memberships[_key(clubId, fromUserId)];
    if (from == null ||
        from.status != MembershipStatus.active ||
        from.role != ClubRole.president) {
      return _conflict();
    }
    final now = _clock.nowUtc();
    _write(from.copyWith(role: ClubRole.board));
    _write(
      MembershipModel(
        clubId: clubId,
        userId: toUserId,
        applicant: _appointee(toUserId, to),
        status: MembershipStatus.active,
        role: ClubRole.president,
        appliedAt: now,
        decidedAt: now,
        decidedBy: actorId,
        priorCount: to?.priorCount ?? 0,
        createdAt: to?.createdAt ?? now,
      ),
    );
    clubRepository.clubs[clubId] = club.copyWith(presidentId: toUserId);
    _bumpMemberCount(clubId, 1);
    _logManager(
      ActivityKind.roleChanged,
      clubId,
      toUserId,
      actorId,
      role: ClubRole.president,
    );
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<void>> transferPresidency({
    required String clubId,
    required String fromUserId,
    required String toUserId,
    required String actorId,
  }) async {
    record('transferPresidency', [clubId, fromUserId, toUserId, actorId]);
    if (_rejected<void>([clubId, fromUserId, toUserId, actorId])
        case final failure?) {
      return failure;
    }
    if (fromUserId == toUserId) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    final from = memberships[_key(clubId, fromUserId)];
    if (from == null ||
        from.status != MembershipStatus.active ||
        from.role != ClubRole.president) {
      return _conflict();
    }
    final to = memberships[_key(clubId, toUserId)];
    if (to == null ||
        to.status != MembershipStatus.active ||
        !_assignable.contains(to.role)) {
      return _conflict();
    }
    // W-89 (b): yeni başkanın hesabı etkin olmalı.
    if (userStatuses[toUserId] case final status?
        when status != UserStatus.active) {
      return _conflict();
    }
    final club = clubRepository.clubs[clubId];
    if (club == null) return const FirebaseFailure(FirestoreError.notFound);
    // Tek "işlem": kulüp hiçbir an başkansız ya da iki başkanlı kalmaz.
    _write(from.copyWith(role: ClubRole.board));
    _write(to.copyWith(role: ClubRole.president));
    clubRepository.clubs[clubId] = club.copyWith(presidentId: toUserId);
    _logManager(
      ActivityKind.roleChanged,
      clubId,
      toUserId,
      actorId,
      role: ClubRole.president,
    );
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<PageResult<MembershipModel>>> listActiveMembers(
    String clubId,
    PageRequest page, {
    ClubRole? role,
  }) async {
    record('listActiveMembers', [clubId, page, role]);
    if (_rejected<PageResult<MembershipModel>>([clubId]) case final failure?) {
      return failure;
    }
    final active = _inClub(clubId, MembershipStatus.active);
    return FirebaseSuccess(
      _pager.slice(
        role == null
            ? _newestFirst(active)
            : active.where((membership) => membership.role == role).toList(),
        page,
      ),
    );
  }

  @override
  Future<FirestoreResult<List<MembershipModel>>> listManagers(
    String clubId,
  ) async {
    record('listManagers', [clubId]);
    if (_rejected<List<MembershipModel>>([clubId]) case final failure?) {
      return failure;
    }
    return FirebaseSuccess([
      for (final membership in _inClub(clubId, MembershipStatus.active))
        if (membership.role == ClubRole.board ||
            membership.role == ClubRole.president)
          membership,
    ]);
  }

  @override
  Future<FirestoreResult<PageResult<MembershipModel>>> listPending(
    String clubId,
    PageRequest page,
  ) async {
    record('listPending', [clubId, page]);
    if (_rejected<PageResult<MembershipModel>>([clubId]) case final failure?) {
      return failure;
    }
    return FirebaseSuccess(
      _pager.slice(
        _newestFirst(_inClub(clubId, MembershipStatus.pending)),
        page,
      ),
    );
  }

  @override
  Future<FirestoreResult<PageResult<MembershipModel>>> listByStatus(
    String clubId,
    MembershipStatus status,
    PageRequest page,
  ) async {
    record('listByStatus', [clubId, status, page]);
    if (_rejected<PageResult<MembershipModel>>([clubId]) case final failure?) {
      return failure;
    }
    return FirebaseSuccess(
      _pager.slice(_newestFirst(_inClub(clubId, status)), page),
    );
  }

  @override
  Future<FirestoreResult<List<MembershipModel>>> listMine(
    String uid, {
    Set<MembershipStatus>? statuses,
  }) async {
    record('listMine', [uid, statuses]);
    if (_rejected<List<MembershipModel>>([uid]) case final failure?) {
      return failure;
    }
    return FirebaseSuccess([
      for (final membership in _mine(uid))
        if (statuses == null || statuses.contains(membership.status))
          membership,
    ]);
  }

  @override
  Future<FirestoreResult<MembershipContactModel?>> readContact(
    String clubId,
    String userId,
  ) async {
    record('readContact', [clubId, userId]);
    if (_rejected<MembershipContactModel?>([clubId, userId])
        case final failure?) {
      return failure;
    }
    return FirebaseSuccess(contacts[_key(clubId, userId)]);
  }

  /// Başvuru ([target] `pending`) ve anında katılımın ([target] `active`)
  /// ortak geçişi; denetim sırası gerçek repository ile aynıdır.
  FirestoreResult<MembershipModel> _enter(
    String clubId,
    UserModel applicant,
    String email,
    String note,
    MembershipStatus target,
  ) {
    final uid = applicant.uid;
    if (_rejected<MembershipModel>([clubId, uid]) case final failure?) {
      return failure;
    }
    if (FieldValidators.universityEmail(email) != null ||
        FieldValidators.applicationNote(note, requireNote: false) != null) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    final club = clubRepository.clubs[clubId];
    if (club == null || club.isDeleted) {
      return const FirebaseFailure(FirestoreError.notFound);
    }
    final instant = target == MembershipStatus.active;
    final key = _key(clubId, uid);
    final current = memberships[key];
    final now = _clock.nowUtc();

    if (club.isSuspended || !club.applicationsOpen) {
      return _violation(FirestoreRuleCode.applicationsClosed);
    }
    switch (current?.status) {
      case MembershipStatus.pending || MembershipStatus.active:
        return _conflict();
      case MembershipStatus.rejected || MembershipStatus.removed:
        final retryAfter = current?.retryAfter;
        if (retryAfter != null && now.isBefore(retryAfter)) {
          return _violation(
            FirestoreRuleCode.retryCooldown,
            retryAfter: retryAfter,
          );
        }
        if (instant) return _violation(FirestoreRuleCode.reapplyNeedsReview);
      case MembershipStatus.cancelled:
        // İptal edilen başvuru her kulüpte yalnızca `pending`'e döner
        // (onay dolanması kapalı — CD-137).
        if (instant) return _violation(FirestoreRuleCode.reapplyNeedsReview);
      case null || MembershipStatus.left:
        if (club.approvalRequired == instant) return _conflict();
    }
    if (!instant &&
        FieldValidators.applicationNote(note, requireNote: club.requireNote) !=
            null) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }

    final membership = MembershipModel(
      clubId: clubId,
      userId: uid,
      applicant: MembershipApplicantModel.fromUser(applicant),
      status: target,
      appliedAt: now,
      priorCount: current == null ? 0 : current.priorCount + 1,
      createdAt: current?.createdAt ?? now,
      updatedAt: now,
    );
    final contact = contacts[key];
    contacts[key] = contact == null
        ? MembershipContactModel(
            email: email,
            emailLower: email.toLowerCase(),
            note: note,
            createdAt: now,
            updatedAt: now,
          )
        : contact.copyWith(note: note, updatedAt: now);
    if (instant) _bumpMemberCount(clubId, 1);
    applied.add((
      clubId: clubId,
      userId: uid,
      email: email,
      note: note,
      status: target,
    ));
    memberships[key] = membership;
    _emit(uid);
    return FirebaseSuccess(membership);
  }

  /// M5 / M6 ortak gövdesi ([reason] `null` → onay). [checked] ise kimlik
  /// denetimi ve hata enjeksiyonu çağıranda yapılmıştır.
  FirestoreResult<void> _decide(
    String clubId,
    String userId,
    String actorId, {
    RejectReason? reason,
    String rejectNote = '',
    bool checked = false,
  }) {
    if (!checked) {
      if (_rejected<void>([clubId, userId, actorId]) case final failure?) {
        return failure;
      }
    }
    // Başvuran kendi başvurusuna karar veremez (rules-spec §3.4 M5).
    if (userId == actorId) {
      return const FirebaseFailure(FirestoreError.permissionDenied);
    }
    final current = memberships[_key(clubId, userId)];
    if (current == null || current.status != MembershipStatus.pending) {
      return _conflict();
    }
    // W-89 (a): hesabı silinmiş başvurana karar verilmez.
    if (userStatuses[userId] == UserStatus.deleted) return _conflict();
    final approved = reason == null;
    if (approved && !clubRepository.clubs.containsKey(clubId)) {
      return const FirebaseFailure(FirestoreError.notFound);
    }
    final now = _clock.nowUtc();
    _write(
      approved
          ? current.copyWith(
              status: MembershipStatus.active,
              role: ClubRole.member,
              decidedAt: now,
              decidedBy: actorId,
            )
          : current.copyWith(
              status: MembershipStatus.rejected,
              decidedAt: now,
              decidedBy: actorId,
              rejectReason: reason,
              rejectNote: rejectNote,
              retryAfter: now.add(Limits.reapplyCooldown),
            ),
    );
    if (approved) _bumpMemberCount(clubId, 1);
    _logManager(
      approved
          ? ActivityKind.applicationApproved
          : ActivityKind.applicationRejected,
      clubId,
      userId,
      actorId,
    );
    return const FirebaseSuccess(null);
  }

  /// M12 (a / b): önceki durum [from] içinde değilse `conflict`; kararı
  /// [actorId] vermemişse ya da `Limits.managerUndoWindow` geçmişse kodsuz
  /// `ruleViolation`; pencere içinde rolü değişmiş üyenin onayı geri
  /// alınmaz (`conflict`).
  FirestoreResult<void> _undo(
    String clubId,
    String userId,
    String actorId,
    Set<MembershipStatus> from,
  ) {
    if (_rejected<void>([clubId, userId, actorId]) case final failure?) {
      return failure;
    }
    final current = memberships[_key(clubId, userId)];
    if (current == null || !from.contains(current.status)) return _conflict();
    final decidedAt = current.decidedAt;
    if (current.decidedBy != actorId ||
        decidedAt == null ||
        !_clock.nowUtc().isBefore(decidedAt.add(Limits.managerUndoWindow))) {
      return const FirebaseFailure(FirestoreError.ruleViolation);
    }
    if (current.status == MembershipStatus.active &&
        current.role != ClubRole.member) {
      return _conflict();
    }
    final restore = current.status == MembershipStatus.removed;
    final counted = restore || current.status == MembershipStatus.active;
    if (counted && !clubRepository.clubs.containsKey(clubId)) {
      return const FirebaseFailure(FirestoreError.notFound);
    }
    _write(
      current.copyWith(
        status: restore ? MembershipStatus.active : MembershipStatus.pending,
        role: restore ? ClubRole.member : null,
        clearDecidedAt: true,
        clearDecidedBy: true,
        clearRetryAfter: true,
        clearRejectReason: true,
        clearRejectNote: true,
      ),
    );
    if (restore) {
      _bumpMemberCount(clubId, 1);
    } else if (current.status == MembershipStatus.active) {
      _bumpMemberCount(clubId, -1);
    }
    return const FirebaseSuccess(null);
  }

  MembershipApplicantModel _appointee(String uid, MembershipModel? current) =>
      applicants[uid] ??
      current?.applicant ??
      MembershipApplicantModel(name: '', avatarSeed: uid);

  void _logManager(
    ActivityKind kind,
    String clubId,
    String userId,
    String actorId, {
    ClubRole? role,
  }) => managerEvents.add((
    kind: kind,
    clubId: clubId,
    userId: userId,
    actorId: actorId,
    role: role,
  ));

  /// [membership] belgesini `updatedAt` ile yazar ve akışı günceller.
  void _write(MembershipModel membership) {
    memberships[membership.id] = membership.copyWith(
      updatedAt: _clock.nowUtc(),
    );
    _emit(membership.userId);
  }

  void _bumpMemberCount(String clubId, int delta) {
    final club = clubRepository.clubs[clubId]!;
    clubRepository.clubs[clubId] = club.copyWith(
      memberCount: club.memberCount + delta,
    );
  }

  /// Dinleyicisi olmayan akışta olay düşer (yayın akışı).
  void _emit(String uid) => _controllers[uid]?.add(FirebaseSuccess(_mine(uid)));

  List<MembershipModel> _mine(String uid) => [
    for (final membership in memberships.values)
      if (membership.userId == uid) membership,
  ];

  List<MembershipModel> _inClub(String clubId, MembershipStatus status) => [
    for (final membership in memberships.values)
      if (membership.clubId == clubId && membership.status == status)
        membership,
  ];

  /// `appliedAt` azalan (en yeni üstte); zamanı olmayan belge sonda.
  static List<MembershipModel> _newestFirst(List<MembershipModel> items) =>
      [...items]..sort((a, b) {
        final left = a.appliedAt;
        final right = b.appliedAt;
        if (left == null || right == null) {
          return left == right ? 0 : (left == null ? 1 : -1);
        }
        return right.compareTo(left);
      });

  /// Rol değişimi ve devirde hedef olabilen / atanabilen roller.
  static const Set<ClubRole> _assignable = {ClubRole.member, ClubRole.board};

  static String _key(String clubId, String userId) =>
      FirestoreIds.membership(clubId, userId);

  static FirestoreResult<T> _conflict<T>() =>
      const FirebaseFailure(FirestoreError.conflict);

  static FirestoreResult<T> _violation<T>(
    FirestoreRuleCode code, {
    DateTime? retryAfter,
  }) => FirebaseFailure(
    FirestoreError.ruleViolation,
    detail: FirestoreFailureDetail(code, retryAfter: retryAfter),
  );

  /// Bekleyen hata ya da geçersiz kimlik varsa başarısızlık; yoksa `null`.
  FirestoreResult<T>? _rejected<T>(List<String> ids) {
    final failure = switch (takeFailure()) {
      null => null,
      final FirestoreError error => error,
      _ => FirestoreError.unknown,
    };
    if (failure != null) return FirebaseFailure(failure);
    if (!ids.every(RepositoryHelpers.isValidId)) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    return null;
  }
}
