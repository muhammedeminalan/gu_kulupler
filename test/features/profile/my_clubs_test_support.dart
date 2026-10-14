// PRF-03 testlerinin ortak verisi: demo verideki Mehmet'in dört üyeliği —
// `c01` (Yazılım ve Yapay Zekâ, aktif üye), `c07` (Fotoğraf ve Sinema,
// aktif üye), `c06` (bekleyen başvuru), `c05` (reddedildi) — ve onları
// taşıyan oturum. Modeller fixture'lardan kurulur.
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/features/profile/provider/my_clubs_state.dart';
import 'package:gu_kulupler/product/navigation/my_clubs_tab.dart';

import '../../fakes/fake_club_repository.dart';
import '../../fakes/fake_membership_repository.dart';
import '../../fakes/fake_session_states.dart';
import '../../fixtures/club_model_fixtures.dart';
import '../../fixtures/membership_model_fixtures.dart';

/// Oturumdaki kullanıcı (`u_mehmet`).
const String kMyClubsUid = FakeSessionStates.uid;

/// `c01` — aktif üye.
final MembershipModel kC01Active = MembershipModelFixtures.c01Mehmet;

/// `c07` — aktif üye.
final MembershipModel kC07Active = MembershipModelFixtures.byId(
  'c07_u_mehmet',
);

/// `c06` — bekleyen başvuru.
final MembershipModel kC06Pending = MembershipModelFixtures.byId(
  'c06_u_mehmet',
);

/// `c05` — reddedildi (`retryAfter` dolmak üzere).
final MembershipModel kC05Rejected = MembershipModelFixtures.byId(
  'c05_u_mehmet',
);

/// Mehmet'in üyelikleri.
List<MembershipModel> get kMyMemberships => [
  kC01Active,
  kC07Active,
  kC06Pending,
  kC05Rejected,
];

/// [memberships] üyeliklerini taşıyan aktif oturum.
SessionState myClubsSession([List<MembershipModel>? memberships]) =>
    SessionState(
      status: AuthStatus.active,
      uid: kMyClubsUid,
      onboardingSeen: true,
      memberships: {
        for (final membership in memberships ?? kMyMemberships)
          membership.clubId: membership,
      },
    );

/// Fake'leri tohumlar: üyeliklerin kulüpleri ve üyelik belgeleri.
void seedMyClubs([List<MembershipModel>? memberships]) {
  final clubs = GetIt.I<ClubRepository>() as FakeClubRepository;
  final repo = GetIt.I<MembershipRepository>() as FakeMembershipRepository;
  for (final membership in memberships ?? kMyMemberships) {
    clubs.clubs[membership.clubId] = ClubModelFixtures.byId(membership.clubId);
    repo.put(membership);
  }
}

/// Dolu ekran durumu.
MyClubsState loadedMyClubs({
  MyClubsTab tab = MyClubsTab.active,
  List<MembershipModel>? memberships,
}) {
  final list = memberships ?? kMyMemberships;
  return MyClubsState(
    tab: tab,
    memberships: {for (final m in list) m.clubId: m},
    clubs: {for (final m in list) m.clubId: ClubModelFixtures.byId(m.clubId)},
  );
}
