// ADM-02 testlerinin ortak verisi: tasarım yakalamasındaki görünüm —
// `u_admin` (süper admin): demo verinin 14 kulübü (13 aktif, c14 askıda),
// demo `memberCount` değerleri ve başkan profilleri ("Başkan: Burak Şahin ·
// 231 üye"). Modeller demo veriden kurulur.
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/admin/provider/admin_clubs_state.dart';

import '../../fakes/fake_club_repository.dart';
import '../../fakes/fake_membership_repository.dart';
import '../../fakes/fake_user_repository.dart';
import '../../fixtures/club_model_fixtures.dart';
import '../../fixtures/membership_model_fixtures.dart';
import '../../fixtures/user_model_fixtures.dart';

/// Demo verideki `memberCount` değerleri (fixture dönüşümü üyeliklerden
/// sayar; tasarım görüntüsü demo sayaçlarını gösterir).
const Map<String, int> kAdminClubMemberCounts = {
  'c01': 188,
  'c02': 142,
  'c03': 231,
  'c04': 99,
  'c05': 74,
  'c06': 120,
  'c07': 88,
  'c08': 112,
  'c09': 65,
  'c10': 204,
  'c11': 157,
  'c12': 59,
  'c13': 133,
  'c14': 91,
};

/// Askıdaki demo kulübü.
const String kAdminSuspendedClubId = 'c14';

/// Tasarımın ilk satırı (ada göre ilk etkin kulüp): Doğa Sporları — başkan
/// Burak Şahin.
const String kFirstClubId = 'c03';

/// [id] kulübü demo `memberCount` ile.
ClubModel adminClub(String id) => ClubModelFixtures.byId(
  id,
).copyWith(memberCount: kAdminClubMemberCounts[id]);

/// Tüm demo kulüpleri (askıdaki dahil).
List<ClubModel> adminClubs() => [
  for (final id in kAdminClubMemberCounts.keys) adminClub(id),
];

/// Başkan profilleri (`uid` → profil).
Map<String, UserModel> adminPresidents() => {
  for (final club in adminClubs())
    club.presidentId: UserModelFixtures.byId(club.presidentId),
};

/// Tasarımdaki dolu görünüm (ViewModel'in üreteceği biçimde).
AdminClubsState loadedAdminClubsState({
  List<ClubModel>? clubs,
}) => AdminClubsState(
  clubs: clubs ?? adminClubs(),
  presidents: adminPresidents(),
  isLoaded: true,
);

/// Kayıtlı fake'lere kulüpleri, başkan profillerini ve başkan üyeliklerini
/// yazar.
void seedAdminClubs() {
  final clubs = (GetIt.I<ClubRepository>() as FakeClubRepository).clubs;
  final users = (GetIt.I<UserRepository>() as FakeUserRepository).users;
  final memberships =
      GetIt.I<MembershipRepository>() as FakeMembershipRepository;
  for (final club in adminClubs()) {
    clubs[club.id] = club;
    users[club.presidentId] = UserModelFixtures.byId(club.presidentId);
    memberships.put(
      MembershipModelFixtures.byId('${club.id}_${club.presidentId}'),
    );
  }
}
