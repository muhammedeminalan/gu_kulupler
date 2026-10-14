// PRF-01 testlerinin ortak verisi: demo verideki Mehmet (`u_mehmet`) — aktif
// üyelikler `c01`, `c07` (üye), bekleyen başvuru `c06`, reddedilmiş `c05`;
// katılım kayıtları `e01` (going), `e08` (waitlist), `e18` (attended).
// Referans görüntüdeki sayılar: 2 kulüp · 1 katıldığı etkinlik · 1 bekleyen.
// Modeller fixture'lardan kurulur.
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/features/profile/provider/profile_state.dart';

import '../../fakes/fake_club_repository.dart';
import '../../fakes/fake_rsvp_repository.dart';
import '../../fakes/fake_session_states.dart';
import '../../fakes/fake_user_repository.dart';
import '../../fixtures/club_model_fixtures.dart';
import '../../fixtures/membership_model_fixtures.dart';
import '../../fixtures/rsvp_model_fixtures.dart';
import '../../fixtures/user_model_fixtures.dart';

/// Oturumdaki kullanıcı (`u_mehmet`).
const String kProfileUid = FakeSessionStates.uid;

/// Mehmet Kaya — Elektrik-Elektronik Mühendisliği · 3. sınıf; ilgi alanları
/// `i01`, `i06`, `i07`, `i11`.
final UserModel kProfileUser = UserModelFixtures.byId(kProfileUid);

/// Mehmet'in demo verideki üyelikleri (oturum sırası).
final List<MembershipModel> kProfileMemberships = [
  for (final clubId in const ['c01', 'c07', 'c06', 'c05'])
    MembershipModelFixtures.byId(FirestoreIds.membership(clubId, kProfileUid)),
];

/// Demo üyelikler; [roles] içindeki kulüplerin üyeliği verilen rolle.
List<MembershipModel> profileMembershipsWithRoles(
  Map<String, ClubRole> roles,
) => [
  for (final membership in kProfileMemberships)
    if (roles[membership.clubId] case final role?)
      membership.copyWith(role: role)
    else
      membership,
];

/// Aktif oturum: Mehmet'in belgesi ve [memberships] üyelikleri.
SessionState profileSession({
  List<MembershipModel>? memberships,
  UserModel? user,
  bool isSuperAdmin = false,
}) => SessionState(
  status: AuthStatus.active,
  uid: kProfileUid,
  user: user ?? kProfileUser,
  isSuperAdmin: isSuperAdmin,
  onboardingSeen: true,
  memberships: {
    for (final membership in memberships ?? kProfileMemberships)
      membership.clubId: membership,
  },
);

/// Fake'leri tohumlar: kullanıcı belgesi, üyeliklerin kulüpleri ve katılım
/// kayıtları.
void seedProfile() {
  (GetIt.I<UserRepository>() as FakeUserRepository).users[kProfileUid] =
      kProfileUser;
  final clubs = GetIt.I<ClubRepository>() as FakeClubRepository;
  for (final membership in kProfileMemberships) {
    clubs.clubs[membership.clubId] = ClubModelFixtures.byId(
      membership.clubId,
    );
  }
  [
    RsvpModelFixtures.e01Mehmet,
    RsvpModelFixtures.e08Mehmet,
    RsvpModelFixtures.e18Mehmet,
  ].forEach((GetIt.I<RsvpRepository>() as FakeRsvpRepository).put);
}

/// Dolu ekran durumu: [memberships] (varsayılan demo), aktif üyeliklerin
/// kulüpleri okunmuş, bir katıldığı etkinlik.
ProfileState loadedProfile({
  List<MembershipModel>? memberships,
  UserModel? user,
  bool isSuperAdmin = false,
}) {
  final list = memberships ?? kProfileMemberships;
  return ProfileState(
    user: user ?? kProfileUser,
    isSuperAdmin: isSuperAdmin,
    memberships: list,
    clubs: {
      for (final membership in list)
        if (membership.isActiveMember)
          membership.clubId: ClubModelFixtures.byId(membership.clubId),
    },
    attendedCount: 1,
  );
}
