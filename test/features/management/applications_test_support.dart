// MGT-02 testlerinin ortak verisi: tasarım yakalamasındaki görünüm —
// `u_burak` (başkan) → `c03` (9 bekleyen başvuru: u035 · u039 · u043 ·
// u109 · u122 · u147 · u189 · u_cem · u_long; 4 reddedilen; onaylanan
// üyeler). Modeller demo veriden kurulur; MGT-01 ortak verisi
// `manage_test_support.dart`'tadır.
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/management/provider/manage_applications_state.dart';
import 'package:gu_kulupler/product/navigation/applications_tab.dart';

import '../../fakes/fake_club_repository.dart';
import '../../fakes/fake_membership_repository.dart';
import '../../fakes/fake_user_repository.dart';
import '../../fixtures/demo_data.dart';
import '../../fixtures/membership_model_fixtures.dart';
import '../../fixtures/user_model_fixtures.dart';
import 'manage_test_support.dart';

/// Tasarım yakalamasındaki bekleyen başvuranlar (envanter sırası).
const List<String> kPendingIds = [
  'u035',
  'u039',
  'u043',
  'u109',
  'u122',
  'u147',
  'u189',
  'u_cem',
  'u_long',
];

/// `c03` kulübündeki [uid] üyeliği (demo veri).
MembershipModel applicationOf(String uid) =>
    MembershipModelFixtures.byId(FirestoreIds.membership(kManageClubId, uid));

/// `c03` kulübündeki [uid] başvurusunun iletişim belgesi (not + e-posta).
MembershipContactModel contactOf(String uid) => MembershipContactModel.fromJson(
  DemoDataFixture.toFirestoreJson(
    FirestoreCollections.contactDoc,
    FirestoreIds.membership(kManageClubId, uid),
  ),
);

/// `c03`'ün demo verideki bütün üyelik belgeleri.
List<MembershipModel> clubMemberships() => [
  for (final id in DemoDataFixture.ids(FirestoreCollections.memberships))
    if (id.startsWith('${kManageClubId}_')) MembershipModelFixtures.byId(id),
];

/// Kayıtlı fake'lere `c03` kulübünü, bütün üyeliklerini (iletişim belgeleri
/// ve kullanıcılarıyla) yazar.
void seedApplications() {
  (GetIt.I<ClubRepository>() as FakeClubRepository).clubs[kManageClubId] =
      kManageClub;
  final memberships =
      GetIt.I<MembershipRepository>() as FakeMembershipRepository;
  final users = GetIt.I<UserRepository>() as FakeUserRepository;
  for (final m in clubMemberships()) {
    memberships.put(m);
    memberships.contacts[m.id] = contactOf(m.userId);
    users.users[m.userId] = UserModelFixtures.byId(m.userId);
  }
}

/// Tasarımdaki dolu "Bekleyen" sekmesi (ViewModel'in üreteceği biçimde).
ManageApplicationsState loadedApplicationsState({
  ClubAccess access = ClubAccess.manager,
  ClubRole? role = ClubRole.president,
  ClubModel? club,
  ApplicationsTab tab = ApplicationsTab.pending,
  bool selecting = false,
  Set<String> selectedIds = const {},
}) {
  final pending = [for (final id in kPendingIds) applicationOf(id)];
  final decided = clubMemberships();
  return ManageApplicationsState(
    access: access,
    role: role,
    club: club ?? kManageClub,
    tab: tab,
    lists: {
      ApplicationsTab.pending: pending,
      ApplicationsTab.approved: [
        for (final m in decided)
          if (m.status == MembershipStatus.active && m.decidedAt != null) m,
      ],
      ApplicationsTab.rejected: [
        for (final m in decided)
          if (m.status == MembershipStatus.rejected) m,
      ],
    },
    loadedTabs: ApplicationsTab.values.toSet(),
    users: {
      for (final m in [...pending, ...decided])
        m.userId: UserModelFixtures.byId(m.userId),
    },
    contacts: {for (final id in kPendingIds) id: contactOf(id)},
    selecting: selecting,
    selectedIds: selectedIds,
  );
}
