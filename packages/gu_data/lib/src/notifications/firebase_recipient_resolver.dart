import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gu_data/src/constants/firestore_collections.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/constants/limits.dart';
import 'package:gu_data/src/constants/static_tables.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/models/club_model.dart';
import 'package:gu_data/src/models/enums/club_role.dart';
import 'package:gu_data/src/models/enums/event_visibility.dart';
import 'package:gu_data/src/models/enums/membership_status.dart';
import 'package:gu_data/src/models/enums/rsvp_status.dart';
import 'package:gu_data/src/models/event_model.dart';
import 'package:gu_data/src/notifications/recipient_resolver.dart';
import 'package:gu_data/src/repositories/repository_helpers.dart';
import 'package:gu_data/src/repositories/user_repository.dart';
import 'package:gu_data/src/services/firestore_service.dart';
import 'package:gu_data/src/services/firestore_types.dart';

/// [RecipientResolver] uygulaması (PLAN §10.5; `docs/plans/T-25.md` §6 d).
///
/// Üyelik ve katılım sorgularını [FirestoreService] üzerinden **kendisi**
/// yapar: `MembershipRepository` dağıtıcıya bağımlıdır (başvuru bildirimi),
/// dağıtıcı da bu sınıfa — repository'yi kullanmak kompozisyon kökünde
/// döngü kurardı. Sorgular repository'lerinkiyle aynı biçimdedir ve aynı
/// Rules dallarından geçer:
///
/// - [managersOf] = `MembershipRepository.listManagers` (rules-spec §3.4
///   R(d), CD-139: başvuran dahil her etkin kullanıcı okur);
/// - [membersOf] = `listActiveMembers` süzgeci (`clubId`, `status: active`)
///   tek sorguda, sayfasız (R(b): kulüp yönetimi);
/// - [rsvpUsersOf] = `rsvps where eventId, clubId, status in …` (rules-spec
///   §6, `seesMgmt`; `AttendanceRepository.listParticipants` T-30'da
///   gelince ona devredilir);
/// - ilgi eşleşmesi `UserRepository.listByInterests` (CD-38).
///
/// Belgelerden yalnızca `userId` / `role` alanları okunur; alanı eksik ya
/// da bozuk belge atlanır (bir bozuk belge bütün alıcıları düşürmez).
/// Kimlik parametreleri dış girdi sayılır: geçersiz kimlik
/// `FirestoreError.invalidArgument` döner.
final class FirebaseRecipientResolver implements RecipientResolver {
  /// Üyelik / katılım sorgularını [_firestore] ile, ilgi eşleşmesini
  /// [_users] ile yapar.
  FirebaseRecipientResolver(this._firestore, this._users);

  final FirestoreService _firestore;
  final UserRepository _users;

  /// `application_received` alıcı rolleri (danışman hariç — `isManager`).
  static const List<ClubRole> _managerRoles = [
    ClubRole.board,
    ClubRole.president,
  ];

  @override
  Future<FirestoreResult<List<String>>> managersOf(String clubId) async {
    if (RepositoryHelpers.rejectInvalidIds<List<String>>({'clubId': clubId})
        case final rejected?) {
      return rejected;
    }
    final result = await _firestore.getList(
      _activeIn(clubId).where(
        FirestoreFields.role,
        whereIn: [for (final role in _managerRoles) role.json],
      ),
    );
    return result.map(_userIdsOf);
  }

  @override
  Future<FirestoreResult<List<String>>> membersOf(
    String clubId, {
    String? excludeUserId,
  }) async {
    if (RepositoryHelpers.rejectInvalidIds<List<String>>({'clubId': clubId})
        case final rejected?) {
      return rejected;
    }
    final result = await _firestore.getList(_activeIn(clubId));
    return result.map(
      (docs) => _userIdsOf(
        docs.where(
          (doc) => doc.data[FirestoreFields.role] != ClubRole.advisor.json,
        ),
        exclude: excludeUserId,
      ),
    );
  }

  @override
  Future<FirestoreResult<List<String>>> rsvpUsersOf(
    String eventId,
    String clubId,
    Set<RsvpStatus> statuses,
  ) async {
    if (RepositoryHelpers.rejectInvalidIds<List<String>>({
          'eventId': eventId,
          'clubId': clubId,
        })
        case final rejected?) {
      return rejected;
    }
    if (statuses.isEmpty) return const FirebaseSuccess([]);
    final result = await _firestore.getList(
      _firestore
          .collection(FirestoreCollections.rsvps)
          .where(FirestoreFields.eventId, isEqualTo: eventId)
          .where(FirestoreFields.clubId, isEqualTo: clubId)
          .where(
            FirestoreFields.status,
            whereIn: [for (final status in statuses) status.json],
          ),
    );
    return result.map(_userIdsOf);
  }

  @override
  Future<FirestoreResult<RecipientSet>> eventNew(
    EventModel event,
    ClubModel club,
  ) async {
    if (event.clubId != club.id) {
      return RepositoryHelpers.invalidArgument(
        'geçersiz kimlik: event.clubId ≠ club.id',
      );
    }
    final publisher = event.createdBy;
    final members = await membersOf(event.clubId, excludeUserId: publisher);
    if (members case FirebaseFailure(:final error, :final message)) {
      return FirebaseFailure(error, message: message);
    }
    final ids = {...?members.dataOrNull};
    final interests = StaticTables.interestIdsOf(club.categoryId);
    if (event.visibility != EventVisibility.public || interests.isEmpty) {
      return FirebaseSuccess(RecipientSet(ids: ids.toList()));
    }
    // Bir fazlası istenir: üst sınırın aşıldığı ancak böyle anlaşılır.
    final matched = await _users.listByInterests(
      interests,
      limit: Limits.eventNewInterestFanOutMax + 1,
    );
    switch (matched) {
      case FirebaseFailure(:final error, :final message):
        return FirebaseFailure(error, message: message);
      case FirebaseSuccess(data: final users):
        final truncated = users.length > Limits.eventNewInterestFanOutMax;
        for (final user in users.take(Limits.eventNewInterestFanOutMax)) {
          if (user.uid != publisher) ids.add(user.uid);
        }
        return FirebaseSuccess(
          RecipientSet(ids: ids.toList(), truncated: truncated),
        );
    }
  }

  @override
  Future<FirestoreResult<int>> estimateEventNew(
    EventModel event,
    ClubModel club,
  ) async => (await eventNew(event, club)).map((set) => set.ids.length);

  /// [clubId] kulübünün etkin üyelikleri. Üyelik soft delete edilmez:
  /// silinmemiş süzgeci yoktur (`FirebaseMembershipRepository` ile aynı).
  Query<Json> _activeIn(String clubId) => _firestore
      .collection(FirestoreCollections.memberships)
      .where(FirestoreFields.clubId, isEqualTo: clubId)
      .where(FirestoreFields.status, isEqualTo: MembershipStatus.active.json);

  /// [docs] belgelerinin tekil `userId` değerleri ([exclude] hariç); alanı
  /// geçerli kimlik olmayan belge atlanır.
  static List<String> _userIdsOf(
    Iterable<FirestoreDoc> docs, {
    String? exclude,
  }) => {
    for (final doc in docs)
      if (doc.data[FirestoreFields.userId] case final String id
          when RepositoryHelpers.isValidId(id) && id != exclude)
        id,
  }.toList();
}
