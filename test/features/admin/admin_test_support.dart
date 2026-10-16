// ADM-01 testlerinin ortak verisi: tasarım yakalamasındaki görünüm —
// `u_admin` (süper admin): 13 aktif kulüp, 226 kullanıcı, 1 askıdaki kulüp,
// 5 açık şikayet; en aktif beş kulüp c03 · c10 · c01 · c11 · c02 (demo
// `memberCount` değerleri). Modeller demo veriden kurulur.
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/features/admin/provider/admin_state.dart';
import 'package:gu_kulupler/features/admin/view/admin_view.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';

import '../../fakes/fake_admin_repository.dart';
import '../../fakes/fake_club_repository.dart';
import '../../fakes/fake_session_states.dart';
import '../../fixtures/club_model_fixtures.dart';

/// Tasarımdaki KPI sayaçları (`AdminRepository.stats`).
const AdminStats kDesignStats = AdminStats(
  clubCount: 13,
  userCount: 226,
  openReportCount: 5,
  upcomingEventCount: 4,
);

/// Demo verideki `memberCount` değerleri (fixture dönüşümü üyeliklerden
/// sayar; tasarım görüntüsü demo sayaçlarını gösterir).
const Map<String, int> kDemoMemberCounts = {
  'c01': 188,
  'c02': 142,
  'c03': 231,
  'c04': 99,
  'c10': 204,
  'c11': 157,
  'c14': 91,
};

/// Tasarımdaki "En aktif 5 kulüp" sırası.
const List<String> kTopClubIds = ['c03', 'c10', 'c01', 'c11', 'c02'];

/// Tasarımdaki askıdaki kulüp.
const String kSuspendedClubId = 'c14';

/// Referans görüntüdeki artan eğriye benzeyen haftalık seri.
const List<int> kDesignChart = [12, 13, 14, 16, 16, 18, 19, 20];

/// [id] kulübü demo `memberCount` ile.
ClubModel designClub(String id) =>
    ClubModelFixtures.byId(id).copyWith(memberCount: kDemoMemberCounts[id]);

/// Süper admin oturumu.
const SessionState kAdminSession = FakeSessionStates.activeSuper;

/// Tasarımdaki dolu genel bakış (ViewModel'in üreteceği biçimde).
AdminState loadedAdminState({
  AdminRange range = AdminRange.days30,
  List<String> topClubIds = kTopClubIds,
}) => AdminState(
  range: range,
  stats: kDesignStats,
  suspendedClubCount: 1,
  newCount: 18,
  chart: kDesignChart,
  topClubs: [for (final id in topClubIds) designClub(id)],
  attendance: const AdminAttendance(
    eventCount: 6,
    registered: 120,
    attended: 74,
  ),
  isLoaded: true,
);

/// Kayıtlı fake'lere KPI sayaçlarını ve kulüpleri (askıdaki dahil) yazar.
void seedAdmin() {
  (GetIt.I<AdminRepository>() as FakeAdminRepository).statsValue = kDesignStats;
  final clubs = (GetIt.I<ClubRepository>() as FakeClubRepository).clubs;
  for (final id in kDemoMemberCounts.keys) {
    clubs[id] = designClub(id);
  }
  clubs[kSuspendedClubId] = clubs[kSuspendedClubId]!.copyWith(
    status: ClubStatus.suspended,
  );
}

/// Akış kipi router'larında admin kökü (`/admin`): sorgudan [AdminView]
/// (`AdminRoute` ayrıştırmasıyla aynı — tanınmayan değer `null`).
AdminView adminViewOf(GoRouterState state) {
  final query = state.uri.queryParameters;
  T? named<T extends Enum>(List<T> values, String key) {
    for (final value in values) {
      if (value.name == query[key]) return value;
    }
    return null;
  }

  return AdminView(
    tab: named(AdminTab.values, 'tab'),
    clubsTab: named(AdminClubsTab.values, AdminRoute.clubsTabQuery),
    reportsTab: named(AdminReportsTab.values, AdminRoute.reportsTabQuery),
    reportId: query[AdminRoute.reportIdQuery],
    filter: named(AdminUsersFilter.values, 'filter'),
  );
}
