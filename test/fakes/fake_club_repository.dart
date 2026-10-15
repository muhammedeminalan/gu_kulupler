// `ClubRepository` fake'i (PLAN §16.3): kulüpleri bellekte tutar.
//
//   final clubs = FakeClubRepository()..put('c01', approvalRequired: false);
//   clubs.failNext(FirestoreError.unavailable);
//   expect(clubs.isNameTakenCalls, ['satranç kulübü']);
//
// Gerçek repository gibi: silinmiş kulüp listede ve tekil okumada yoktur
// (`notFound`), askıdaki kulüp döner; `getClubs` istenen sırada, tekrarsız ve
// olmayanı atlayarak döner; silinmiş kulübün adı dolu sayılır; geçersiz
// kimlik `invalidArgument`. Salt okunurdur — `memberCount` yalnızca
// `FakeMembershipRepository` geçişleriyle değişir.
import 'package:gu_data/gu_data.dart';

import 'fake_base.dart';

final class FakeClubRepository extends FakeBase implements ClubRepository {
  /// `clubs/{clubId}` belgeleri; test ön veriyi buraya yazar ([put]).
  final Map<String, ClubModel> clubs = <String, ClubModel>{};

  /// `isNameTaken` çağrılarının `nameLower` argümanları, sırasıyla.
  final List<String> isNameTakenCalls = <String>[];

  /// `forceRefresh: true` ile yapılan okumaların metot adları, sırasıyla
  /// (T-44 · D3-01; çağrı günlüğü [calls] değişmez).
  final List<String> forcedReads = <String>[];

  /// [id] kimlikli bir kulüp kurar ve döndürür (varsayılan: aktif, onaylı,
  /// başvuruya açık, not zorunlu değil).
  ClubModel put(
    String id, {
    String? name,
    bool approvalRequired = true,
    bool applicationsOpen = true,
    bool requireNote = false,
    ClubStatus status = ClubStatus.active,
    int memberCount = 0,
    String presidentId = 'u_president',
    bool isDeleted = false,
  }) {
    final title = name ?? 'Kulüp $id';
    return clubs[id] = ClubModel(
      id: id,
      name: title,
      nameLower: title.toLowerCase(),
      categoryId: 'k01',
      iconName: 'cpu',
      palette: ClubPalette.red,
      pattern: ClubPattern.dots,
      founded: 2015,
      presidentId: presidentId,
      memberCount: memberCount,
      approvalRequired: approvalRequired,
      applicationsOpen: applicationsOpen,
      requireNote: requireNote,
      status: status,
      isDeleted: isDeleted,
    );
  }

  @override
  Future<FirestoreResult<List<ClubModel>>> fetchActiveClubs({
    bool forceRefresh = false,
  }) async {
    record('fetchActiveClubs');
    if (forceRefresh) forcedReads.add('fetchActiveClubs');
    if (_failure() case final error?) return FirebaseFailure(error);
    final live = [
      for (final club in clubs.values)
        if (!club.isDeleted) club,
    ]..sort((a, b) => a.nameLower.compareTo(b.nameLower));
    return FirebaseSuccess(live.take(Limits.clubsFetchMax).toList());
  }

  @override
  Future<FirestoreResult<ClubModel>> getClub(
    String clubId, {
    bool forceRefresh = false,
  }) async {
    record('getClub', [clubId]);
    if (forceRefresh) forcedReads.add('getClub');
    if (_failure() case final error?) return FirebaseFailure(error);
    if (!RepositoryHelpers.isValidId(clubId)) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    final club = clubs[clubId];
    return club == null || club.isDeleted
        ? const FirebaseFailure(FirestoreError.notFound)
        : FirebaseSuccess(club);
  }

  @override
  Future<FirestoreResult<List<ClubModel>>> getClubs(
    List<String> clubIds, {
    bool forceRefresh = false,
  }) async {
    record('getClubs', [clubIds]);
    if (forceRefresh) forcedReads.add('getClubs');
    if (_failure() case final error?) return FirebaseFailure(error);
    if (!clubIds.every(RepositoryHelpers.isValidId)) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    return FirebaseSuccess([
      for (final id in clubIds.toSet())
        if (clubs[id] case final club? when !club.isDeleted) club,
    ]);
  }

  @override
  Future<FirestoreResult<bool>> isNameTaken(String nameLower) async {
    record('isNameTaken', [nameLower]);
    if (_failure() case final error?) return FirebaseFailure(error);
    if (FieldValidators.clubNameLower(nameLower) != null) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    isNameTakenCalls.add(nameLower);
    return FirebaseSuccess(
      clubs.values.any((club) => club.nameLower == nameLower),
    );
  }

  FirestoreError? _failure() => switch (takeFailure()) {
    null => null,
    final FirestoreError error => error,
    _ => FirestoreError.unknown,
  };
}
