// MGT-03 testlerinin ortak verisi: tasarım yakalamasındaki görünüm —
// `u_burak` (başkan) → `c03` (21 etkin üye: 1 başkan, 5 yönetim kurulu,
// 1 danışman, 14 üye). Fake'ler `seedApplications` ile (kulüp, bütün
// üyelikler, iletişim belgeleri, kullanıcılar) doldurulur.
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/features/management/provider/manage_members_state.dart';

import '../../fixtures/demo_data.dart';
import '../../fixtures/user_model_fixtures.dart';
import 'applications_test_support.dart';
import 'manage_test_support.dart';

/// `c03`'ün etkin üyelikleri (demo veri).
List<MembershipModel> activeMemberships() => [
  for (final m in clubMemberships())
    if (m.status == MembershipStatus.active) m,
];

/// Satır menüsü olmayan satırlar (başkan ve danışman — envanter).
const Set<String> kNoMenuIds = {'u_burak', 'u_a_c03'};

/// Süper admin oturumu (`c03`'te üyeliği yok).
SessionState superAdminSession() => SessionState(
  status: AuthStatus.active,
  uid: DemoDataFixture.superAdminId,
  onboardingSeen: true,
  isSuperAdmin: true,
  user: UserModelFixtures.byId(DemoDataFixture.superAdminId),
);

/// Tasarımdaki dolu durum (ViewModel'in üreteceği biçimde).
ManageMembersState loadedMembersState({
  ClubAccess access = ClubAccess.manager,
  ClubRole? role = ClubRole.president,
  ManageRoleFilter roleFilter = ManageRoleFilter.all,
}) {
  final active = activeMemberships();
  return ManageMembersState(
    access: access,
    role: role,
    club: kManageClub,
    managers: [
      for (final m in active)
        if (m.role == ClubRole.president || m.role == ClubRole.board) m,
    ],
    advisors: [
      for (final m in active)
        if (m.role == ClubRole.advisor) m,
    ],
    members: [
      for (final m in active)
        if (m.role == ClubRole.member) m,
    ],
    users: {for (final m in active) m.userId: UserModelFixtures.byId(m.userId)},
    roleFilter: roleFilter,
  );
}
