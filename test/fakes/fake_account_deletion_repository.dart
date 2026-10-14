// `AccountDeletionRepository` fake'i (PLAN §16.3; sözleşme
// `docs/plans/T-29.md` §4): hesap silme dizisini kayıtlı fake'ler üzerinde
// bellekte uygular.
//
//   final deletion = FakeAccountDeletionRepository(clock, users: users,
//       memberships: memberships);
//   await deletion.markDeleted('u1');           // users['u1'] anonim + deleted
//   await deletion.resumeCleanup('u1', onProgress: progress.add);
//   deletion.failCleanupAfter(1, FirestoreError.unavailable);   // 2. parça düşer
//
// Gerçek repository gibi:
// * [precheck] etkin başkanlıkları [membershipRepository]'den okur
//   (`blockedByPresidency`, kimlik sırasıyla); yazım yapmaz.
// * [markDeleted] `users/{uid}`'yi `Anonymization` değerleriyle anonimleştirir
//   (`status: deleted`, soft delete alanları; `avatarSeed` / `staff` /
//   `profileComplete` dokunulmaz) ve `private/account` e-postasını boşaltır.
//   Zaten silinmişse yazmadan başarı; askıdaysa `failedPrecondition`; belge
//   yoksa `notFound`.
// * [buildPlan] `status != deleted` → `failedPrecondition`; plan güncel
//   durumdan çıkar: [rsvps] / [unreadableRsvps] (test ön verisi; vazgeçilen
//   kayıt plandan düşer), etkin başkanlık hariç `active` / `pending` ya da
//   anlık görüntüsü anonim olmayan üyelikler (etkin başkan dahil),
//   [personalRefs] (soft delete edilen düşer).
// * [resumeCleanup] parçaları sırayla uygular (katılım → okunamayan katılım →
//   üyelik → kişisel); her kesinleşen parçada ilerleme bildirir, başarısız
//   parça diziyi durdurmaz, ilk hata sonda döner. Üyelik parçası
//   `FakeMembershipRepository.anonymizeChunk` (M14) çağrısıdır. Yarıda kalan
//   dizi sonraki çağrıda kaldığı yerden sürer (idempotent).
// * [cleanupGate] verilirse her parça uygulanmadan önce beklenir (ilerleme
//   göstergesi testte elle kurulur).
import 'dart:async';

import 'package:gu_data/gu_data.dart';

import 'fake_base.dart';
import 'fake_membership_repository.dart';
import 'fake_user_repository.dart';

final class FakeAccountDeletionRepository extends FakeBase
    implements AccountDeletionRepository {
  /// "Şu an" [_clock] saatidir (`deletedAt`). [users] / [memberships]
  /// verilmezse boş fake'ler kurulur; `registerDefaultFakes` kayıtlı
  /// örnekleri paylaştırır.
  FakeAccountDeletionRepository(
    this._clock, {
    FakeUserRepository? users,
    FakeMembershipRepository? memberships,
  }) : userRepository = users ?? FakeUserRepository(),
       membershipRepository = memberships ?? FakeMembershipRepository(_clock);

  final AppClock _clock;

  /// Profil ve hesap belgelerinin anonimleştirildiği fake.
  final FakeUserRepository userRepository;

  /// Başkanlık ön denetiminin okunduğu, M14'ün uygulandığı fake.
  final FakeMembershipRepository membershipRepository;

  /// Vazgeçilecek katılım kayıtları (test ön verisi); vazgeçilen kayıt
  /// [cancelledRsvps]'e taşınır.
  final List<RsvpModel> rsvps = <RsvpModel>[];

  /// Etkinliği okunamayan açık kayıtlar (test ön verisi —
  /// [DeletionPlan.unreadableRsvps]); vazgeçilen kayıt [cancelledRsvps]'e
  /// taşınır.
  final List<RsvpModel> unreadableRsvps = <RsvpModel>[];

  /// Vazgeçilmiş kayıtlar, sırasıyla.
  final List<RsvpModel> cancelledRsvps = <RsvpModel>[];

  /// Soft delete edilecek kişisel belgeler (test ön verisi); silinen belge
  /// [softDeleted]'e taşınır.
  final List<PersonalDocRef> personalRefs = <PersonalDocRef>[];

  /// Soft delete edilmiş kişisel belgeler, sırasıyla.
  final List<PersonalDocRef> softDeleted = <PersonalDocRef>[];

  /// Verilirse her parça uygulanmadan önce beklenir.
  Completer<void>? cleanupGate;

  /// Verilirse bir sonraki [markDeleted] hiçbir şey yazmadan bu hatayla düşer
  /// (tek seferlik; `failNext` dizinin ilk çağrısına — [precheck] — düşer).
  FirestoreError? markDeletedError;

  int? _failAfter;
  FirestoreError _cleanupError = FirestoreError.unavailable;

  /// [resumeCleanup]'ın ilk [chunks] parçası kesinleşir, sonraki parça
  /// [error] ile düşer (tek seferlik; kalan parçalar yine uygulanır).
  void failCleanupAfter(
    int chunks, [
    FirestoreError error = FirestoreError.unavailable,
  ]) {
    _failAfter = chunks;
    _cleanupError = error;
  }

  @override
  Future<FirestoreResult<DeletionPrecheck>> precheck(String uid) async {
    record('precheck', [uid]);
    if (_injected<DeletionPrecheck>() case final failure?) return failure;
    final active = await membershipRepository.listMine(
      uid,
      statuses: const {MembershipStatus.active},
    );
    return active.map((memberships) {
      final clubIds = [
        for (final membership in memberships)
          if (membership.role == ClubRole.president) membership.clubId,
      ]..sort();
      return clubIds.isEmpty
          ? const DeletionPrecheck.ready()
          : DeletionPrecheck.blockedByPresidency(clubIds);
    });
  }

  @override
  Future<FirestoreResult<void>> markDeleted(String uid) async {
    record('markDeleted', [uid]);
    if (_injected<void>() case final failure?) return failure;
    if (markDeletedError case final error?) {
      markDeletedError = null;
      return FirebaseFailure(error);
    }
    final user = userRepository.users[uid];
    if (user == null) return const FirebaseFailure(FirestoreError.notFound);
    if (user.status == UserStatus.deleted) return const FirebaseSuccess(null);
    if (user.status != UserStatus.active || user.isDeleted) {
      return const FirebaseFailure(FirestoreError.failedPrecondition);
    }
    final now = _clock.nowUtc();
    userRepository.users[uid] = user.copyWith(
      name: Anonymization.deletedUserName,
      nameLower:
          Anonymization.userPayload(uid)[FirestoreFields.nameLower]! as String,
      bio: '',
      interests: const [],
      clearAvatarPath: true,
      clearDepartment: true,
      clearYear: true,
      status: UserStatus.deleted,
      isDeleted: true,
      deletedAt: now,
      deletedBy: uid,
      updatedAt: now,
    );
    if (userRepository.accounts[uid] case final account?) {
      userRepository.accounts[uid] = account.copyWith(
        email: '',
        emailLower: '',
        fcmTokens: const [],
        updatedAt: now,
      );
    }
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<DeletionPlan>> buildPlan(String uid) async {
    record('buildPlan', [uid]);
    if (_injected<DeletionPlan>() case final failure?) return failure;
    final user = userRepository.users[uid];
    if (user == null) return const FirebaseFailure(FirestoreError.notFound);
    if (user.status != UserStatus.deleted) {
      return const FirebaseFailure(FirestoreError.failedPrecondition);
    }
    final memberships = [
      for (final membership in membershipRepository.memberships.values)
        if (membership.userId == uid &&
            (((membership.status == MembershipStatus.active &&
                        membership.role != ClubRole.president) ||
                    membership.status == MembershipStatus.pending) ||
                membership.applicant !=
                    FirebaseMembershipRepository.anonymizedApplicant))
          membership,
    ]..sort((a, b) => a.clubId.compareTo(b.clubId));
    return FirebaseSuccess(
      DeletionPlan(
        rsvps: [
          for (final rsvp in rsvps)
            if (rsvp.userId == uid) rsvp,
        ],
        unreadableRsvps: [
          for (final rsvp in unreadableRsvps)
            if (rsvp.userId == uid) rsvp,
        ],
        memberships: memberships,
        personalRefs: List.of(personalRefs),
      ),
    );
  }

  @override
  Future<FirestoreResult<void>> cancelRsvpChunk(
    String uid,
    List<RsvpModel> chunk,
  ) async {
    record('cancelRsvpChunk', [uid, chunk.map((r) => r.eventId).toList()]);
    if (_injected<void>() case final failure?) return failure;
    if (chunk.length > Limits.accountDeletionChunk) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    for (final rsvp in chunk) {
      if (rsvps.remove(rsvp)) {
        cancelledRsvps.add(rsvp.copyWith(status: RsvpStatus.cancelled));
      }
    }
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<void>> cancelUnreadableRsvp(
    String uid,
    RsvpModel rsvp,
  ) async {
    record('cancelUnreadableRsvp', [uid, rsvp.eventId]);
    if (_injected<void>() case final failure?) return failure;
    if (rsvp.userId != uid) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    if (unreadableRsvps.remove(rsvp)) {
      cancelledRsvps.add(rsvp.copyWith(status: RsvpStatus.cancelled));
    }
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<void>> anonymizeMembershipChunk(
    String uid,
    List<MembershipModel> chunk,
  ) async {
    record('anonymizeMembershipChunk', [
      uid,
      chunk.map((m) => m.clubId).toList(),
    ]);
    if (_injected<void>() case final failure?) return failure;
    return membershipRepository.anonymizeChunk(uid: uid, memberships: chunk);
  }

  @override
  Future<FirestoreResult<void>> softDeletePersonalChunk(
    String uid,
    List<PersonalDocRef> refs,
  ) async {
    record('softDeletePersonalChunk', [uid, refs.length]);
    if (_injected<void>() case final failure?) return failure;
    if (refs.length > Limits.batchMaxWrites) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    for (final ref in refs) {
      if (personalRefs.remove(ref)) softDeleted.add(ref);
    }
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<void>> resumeCleanup(
    String uid, {
    DeleteProgressCallback? onProgress,
  }) async {
    record('resumeCleanup', [uid]);
    if (_injected<void>() case final failure?) return failure;
    final DeletionPlan plan;
    switch (await buildPlan(uid)) {
      case FirebaseFailure(:final error):
        return FirebaseFailure(error);
      case FirebaseSuccess(:final data):
        plan = data;
    }
    final total = plan.chunkCount;
    final steps = <Future<FirestoreResult<void>> Function()>[
      for (final chunk in plan.rsvpChunks) () => cancelRsvpChunk(uid, chunk),
      for (final rsvp in plan.unreadableRsvps)
        () => cancelUnreadableRsvp(uid, rsvp),
      for (final chunk in plan.membershipChunks)
        () => anonymizeMembershipChunk(uid, chunk),
      for (final chunk in plan.personalChunks)
        () => softDeletePersonalChunk(uid, chunk),
    ];
    var done = 0;
    FirestoreResult<void>? firstFailure;
    for (final step in steps) {
      if (cleanupGate case final gate?) await gate.future;
      if (_failAfter case final limit? when done >= limit) {
        _failAfter = null;
        firstFailure ??= FirebaseFailure(_cleanupError);
        continue;
      }
      final result = await step();
      if (result is FirebaseFailure) {
        firstFailure ??= result;
        continue;
      }
      onProgress?.call(DeleteProgress(done: ++done, total: total));
    }
    return firstFailure ?? const FirebaseSuccess(null);
  }

  /// `failNext` ile enjekte edilen hata (FirestoreError beklenir).
  FirestoreResult<T>? _injected<T>() => switch (takeFailure()) {
    null => null,
    final FirestoreError error => FirebaseFailure(error),
    _ => const FirebaseFailure(FirestoreError.unknown),
  };
}
