// MGT-01 testlerinin ortak verisi: tasarım yakalamasındaki görünüm —
// `u_burak` (başkan) → `c03` Doğa Sporları ve Dağcılık Kulübü (sayaç demo
// dönüşümünden, 9 bekleyen başvuru, yaklaşan e03 / e16, son hareketler a105 ·
// a062 · a061 · a064 · a052). Modeller demo veriden kurulur.
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/features/management/provider/manage_state.dart';
import 'package:gu_kulupler/product/manage/activity_lookups.dart';

import '../../fakes/fake_activity_repository.dart';
import '../../fakes/fake_announcement_counter_repository.dart';
import '../../fakes/fake_club_repository.dart';
import '../../fakes/fake_event_repository.dart';
import '../../fakes/fake_membership_repository.dart';
import '../../fakes/fake_post_repository.dart';
import '../../fakes/fake_user_repository.dart';
import '../../fixtures/club_model_fixtures.dart';
import '../../fixtures/demo_data.dart';
import '../../fixtures/event_model_fixtures.dart';
import '../../fixtures/membership_model_fixtures.dart';
import '../../fixtures/post_model_fixtures.dart';
import '../../fixtures/user_model_fixtures.dart';

/// Testlerdeki kulüp (`c03`).
const String kManageClubId = 'c03';

/// Oturumdaki kullanıcı (`u_burak`, `c03` başkanı).
const String kManageUid = 'u_burak';

/// `c03` kulüp belgesi (demo veri; `memberCount` aktif üyeliklerden).
final ClubModel kManageClub = ClubModelFixtures.byId(kManageClubId);

/// Demo verideki [id] faaliyet kaydı.
ActivityModel activityById(String id) => ActivityModel.fromJson(
  DemoDataFixture.toFirestoreJson(FirestoreCollections.activity, id),
  id: id,
);

/// Tasarımdaki "Son hareketler" (en yeni üstte).
const List<String> kRecentIds = ['a105', 'a062', 'a061', 'a064', 'a052'];

/// Tasarımdaki yaklaşan etkinlikler (en yakın üstte).
final List<EventModel> kUpcomingEvents = [
  EventModelFixtures.byId('e03'),
  EventModelFixtures.byId('e16'),
];

/// Referans görüntüdeki artan eğriye benzeyen haftalık seri (görünüm
/// testleri; ViewModel testleri kendi verisini hesaplar).
const List<int> kDesignChart = [1, 2, 3, 4, 4, 5, 6, 7];

/// [kRecentIds] satırlarının kullanıcıları (eylemci + hedef).
Map<String, UserModel> recentUsers() {
  final ids = <String>{};
  for (final id in kRecentIds) {
    final a = activityById(id);
    ids.add(a.actorId);
    if (a.refs.userId case final target?) ids.add(target);
  }
  return {for (final uid in ids) uid: UserModelFixtures.byId(uid)};
}

/// `c03` kulübünde [role] rolüyle aktif oturum (`u_burak`).
SessionState manageSession({ClubRole role = ClubRole.president}) =>
    SessionState(
      status: AuthStatus.active,
      uid: kManageUid,
      onboardingSeen: true,
      user: UserModelFixtures.byId(kManageUid),
      memberships: {
        kManageClubId: MembershipModelFixtures.byId(
          FirestoreIds.membership(kManageClubId, kManageUid),
        ).copyWith(role: role),
      },
    );

/// Tasarımdaki dolu panel durumu (ViewModel'in üreteceği biçimde).
ManageState loadedManageState({
  ClubAccess access = ClubAccess.manager,
  ClubRole? role = ClubRole.president,
  bool hasMembers = true,
  List<ActivityModel>? recent,
  List<EventModel>? upcoming,
}) => ManageState(
  access: access,
  role: role,
  club: kManageClub,
  kpis: MgtKpis(
    memberCount: kManageClub.memberCount,
    pendingCount: 9,
    upcomingEventCount: 2,
    announcementCount: 1,
  ),
  chart: kDesignChart,
  upcomingEvents: upcoming ?? kUpcomingEvents,
  attendanceEventId: kUpcomingEvents.first.id,
  recentActivity: recent ?? [for (final id in kRecentIds) activityById(id)],
  lookups: ActivityLookups(
    users: recentUsers(),
    eventTitles: {for (final e in kUpcomingEvents) e.id: e.title},
  ),
  hasMembers: hasMembers,
);

/// Kayıtlı fake'lere `c03` kulübünü, bekleyen başvurularını, etkinliklerini,
/// gönderilerini, faaliyet kayıtlarını ve kullanıcılarını yazar.
void seedManage() {
  (GetIt.I<ClubRepository>() as FakeClubRepository).clubs[kManageClubId] =
      kManageClub;
  final memberships =
      GetIt.I<MembershipRepository>() as FakeMembershipRepository;
  for (final id in DemoDataFixture.ids(FirestoreCollections.memberships)) {
    if (id.startsWith('${kManageClubId}_')) {
      memberships.put(MembershipModelFixtures.byId(id));
    }
  }
  EventModelFixtures.ofClub(
    kManageClubId,
  ).forEach((GetIt.I<EventRepository>() as FakeEventRepository).put);
  final posts = GetIt.I<PostRepository>() as FakePostRepository;
  for (final id in DemoDataFixture.ids(FirestoreCollections.posts)) {
    final post = PostModelFixtures.byId(id);
    if (post.clubId == kManageClubId) posts.put(post);
  }
  final activity = GetIt.I<ActivityRepository>() as FakeActivityRepository;
  for (final id in DemoDataFixture.ids(FirestoreCollections.activity)) {
    final a = activityById(id);
    if (a.clubId == kManageClubId) activity.entries.add(a);
  }
  (GetIt.I<UserRepository>() as FakeUserRepository).users.addAll(
    recentUsers(),
  );
}

/// Kayıtlı sayaç fake'i (bugünkü duyuru hakkı).
FakeAnnouncementCounterRepository manageCounters() =>
    GetIt.I<AnnouncementCounterRepository>()
        as FakeAnnouncementCounterRepository;
