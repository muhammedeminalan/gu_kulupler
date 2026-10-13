// CLB-06 testlerinin ortak verisi: demo verideki `c01` kulübü (Yazılım ve
// Yapay Zekâ Topluluğu) ve tasarımdaki 79 aktif üyeliği (1 başkan, 5 yönetim
// kurulu, 1 danışman, 72 üye), kullanıcı belgeleri ve oturum durumları.
// Modeller fixture'lardan kurulur; elle yazılmış alan yoktur.
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/features/clubs/provider/club_members_state.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_club_repository.dart';
import '../../fakes/fake_membership_repository.dart';
import '../../fakes/fake_session_states.dart';
import '../../fakes/fake_user_repository.dart';
import '../../fixtures/club_model_fixtures.dart';
import '../../fixtures/demo_data.dart';
import '../../fixtures/membership_model_fixtures.dart';
import '../../fixtures/user_model_fixtures.dart';

/// Testlerdeki kulübün kimliği.
const String kMembersClubId = 'c01';

/// Oturumdaki kullanıcının kimliği (`u_mehmet` — `c01` üyesi).
const String kMembersUid = FakeSessionStates.uid;

/// Oturumdaki kullanıcının e-postası.
const String kMembersEmail = 'mehmet.kaya@ogr.gumushane.edu.tr';

/// `c01` — Yazılım ve Yapay Zekâ Topluluğu (demo veri).
final ClubModel kMembersClub = ClubModelFixtures.byId(kMembersClubId);

/// Tasarım yakalamasında başvurusu bekleyen, demo veride sonradan onaylanan
/// iki üye: referans görüntüdeki 79 kişilik listede yokturlar.
const Set<String> _approvedAfterCapture = {'u182', 'u062'};

/// `c01` kulübünün tasarımdaki aktif üyelikleri (79), demo veri sırasıyla.
final List<MembershipModel> kClubMemberships = [
  for (final id in DemoDataFixture.ids(FirestoreCollections.memberships))
    if (id.startsWith('${kMembersClubId}_')) MembershipModelFixtures.byId(id),
].where(_isDesignMember).toList();

bool _isDesignMember(MembershipModel membership) =>
    membership.status == MembershipStatus.active &&
    !_approvedAfterCapture.contains(membership.userId);

/// Başkan + yönetim kurulu (6).
final List<MembershipModel> kClubManagers = [
  for (final membership in kClubMemberships)
    if (membership.role == ClubRole.president ||
        membership.role == ClubRole.board)
      membership,
];

/// Danışman (1 — `u_zeynep`).
final List<MembershipModel> kClubAdvisors = [
  for (final membership in kClubMemberships)
    if (membership.role == ClubRole.advisor) membership,
];

/// Sıradan üyeler (72).
final List<MembershipModel> kClubMembers = [
  for (final membership in kClubMemberships)
    if (membership.role == ClubRole.member) membership,
];

/// Üyelerin kullanıcı belgeleri (kimlik → belge).
final Map<String, UserModel> kClubUsers = {
  for (final membership in kClubMemberships)
    membership.userId: UserModelFixtures.byId(membership.userId),
};

/// Başkan olmayan bir yönetim kurulu üyesi ve sıradan bir üye (oturumdaki
/// kullanıcı değil).
final MembershipModel kBoardMember = kClubManagers.firstWhere(
  (membership) => membership.role == ClubRole.board,
);

/// Oturumdaki kullanıcı dışındaki ilk sıradan üye.
final MembershipModel kOtherMember = kClubMembers.firstWhere(
  (membership) => membership.userId != kMembersUid,
);

/// Aktif oturum + `c01` kulübünde [role] rolü ([blocked] engellenenler).
SessionState membersSession({
  ClubRole role = ClubRole.member,
  Set<String> blocked = const {},
}) => FakeSessionStates.active.copyWith(
  user: UserModelFixtures.byId(kMembersUid),
  memberships: {
    kMembersClubId: MembershipModelFixtures.c01Mehmet.copyWith(role: role),
  },
  blockedUserIds: blocked,
);

/// Tüm sayfaları okunmuş dolu ekran durumu (ViewModel'in ürettiği durumla
/// aynı); [session] engellenenleri verir.
ClubMembersState loadedMembersState({
  SessionState? session,
  ClubMembersState base = const ClubMembersState(),
}) => base.copyWith(
  club: kMembersClub,
  managers: kClubManagers,
  advisors: kClubAdvisors,
  members: kClubMembers,
  users: kClubUsers,
  blockedUserIds: session?.blockedUserIds,
);

/// Kayıtlı fake'lere `c01` kulübünü, 79 üyeliği ve kullanıcı belgelerini
/// yazar; oturumun kimliğini kurar.
void seedMembers() {
  (GetIt.I<ClubRepository>() as FakeClubRepository).clubs[kMembersClubId] =
      kMembersClub;
  kClubMemberships.forEach(
    (GetIt.I<MembershipRepository>() as FakeMembershipRepository).put,
  );
  (GetIt.I<UserRepository>() as FakeUserRepository).users.addAll(kClubUsers);
  (GetIt.I<AuthRepository>() as FakeAuthRepository)
    ..service.uid = kMembersUid
    ..currentUser = const AuthUserInfo(
      uid: kMembersUid,
      email: kMembersEmail,
      emailVerified: true,
    );
}
