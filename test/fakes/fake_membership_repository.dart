// `MembershipRepository` fake'i (PLAN §16.3): üyelikleri ve iletişim
// belgelerini bellekte tutar; üyelik durum makinesinin başvuran / üye
// satırlarını (M1–M4, M7, M8) ve bekleyen başvurunun not düzenlemesini
// (T-16) gerçek repository ile aynı sonuçlarla uygular.
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
