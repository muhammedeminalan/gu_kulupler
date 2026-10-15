// T-11 · Rota envanteri (kabuk + sistem + oturum öncesi yönlendirme
// hedefleri): router'daki yollar ↔ navigation.md §2 sınıf / yol tablosu ↔
// guard tablosu (PLAN §13.3, §13.5). Her ekran task'ı kendi satırını ekler;
// T-43'te 57 rota sınıfı / 51 ekran tamamlanır.
// T-13 · `RegisterRoute` (`/login/register`) ve `LegalRoute` (`/legal/:tip`).
// T-14 · `ResetPasswordRoute` (`/login/reset`).
// T-16 · `ClubDetailRoute` (`/clubs/:clubId`), `ClubAppliedRoute`
// (`…/applied`), `ClubApplicationRoute` (`…/application`).
// T-17 · `ClubsSearchRoute` (`/clubs/search`), `EventsSearchRoute`
// (`/events/search`) — aynı `SearchView`, başlangıç sekmesi farklı.
// T-18 · `ClubMembersRoute` (`/clubs/:clubId/members`),
// `ClubUserProfileRoute` (`/clubs/user/:userId?clubId=`).
// T-20 · `PostDetailRoute` (`/clubs/:clubId/posts/:postId`).
// T-21 · `ComposeRoute` (`/clubs/:clubId/compose?edit=`).
// T-23 · `EventDetailRoute` (`/events/:eventId?showCancelled=`),
// `TicketRoute` (`/events/:eventId/ticket`).
// T-24 · `EventsRoute` kökü gerçek view (EVT-01), `MyEventsRoute`
// (`/events/mine`).
// T-26 · `NotificationsRoute` kökü gerçek view (NTF-01),
// `NotificationPrefsRoute` (`/notifications/preferences`, NTF-02).
// T-27 · `ProfileRoute` kökü gerçek view (PRF-01), `EditProfileRoute`
// (`/profile/edit`), `MyClubsRoute` (`/profile/clubs?tab=`), `SavedRoute`
// (`/profile/saved`).
// T-28 · `SettingsRoute` (`/profile/settings`, SET-01) ve alt rotaları:
// `SettingsNotificationPrefsRoute` (NTF-02 paylaşılan), `BlockedRoute`
// (SET-02), `BlockedUserProfileRoute` (CLB-07 paylaşılan), `AboutRoute`
// (SET-04), `SupportRoute` (SET-05).
// T-31 · `ManageRoute` (`/clubs/:clubId/manage`, MGT-01), `ActivityLogRoute`
// (`/clubs/:clubId/manage/activity`, MGT-10).
// T-32 · `ManageApplicationsRoute` (`/clubs/:clubId/manage/applications
// ?tab=&applicant=`, MGT-02).
// T-33 · `ManageMembersRoute` (`/clubs/:clubId/manage/members?transfer=`,
// MGT-03).
// T-34 · `ManageEventsRoute` (`/clubs/:clubId/manage/events?tab=`, MGT-04),
// `EventFormRoute` (`…/events/new`) + `EventEditRoute`
// (`…/events/:eventId/edit`) — tek `EventFormView` (MGT-05, CD-54).
// T-35 · `AttendanceRoute` (`…/events/:eventId/attendance`, MGT-06),
// `ScanRoute` (`…/attendance/scan`, MGT-07).
// T-36 · `ManageContentRoute` (`/clubs/:clubId/manage/content`, MGT-08),
// `ClubSettingsRoute` (`…/manage/settings`, MGT-09); `ComposeRoute` `?type=`.
// T-39 · `AdminClubsRoute` (`/admin/clubs?tab=`, ADM-02),
// `AdminClubFormRoute` (`/admin/clubs/new`) + `AdminClubEditRoute`
// (`/admin/clubs/:clubId/edit`) — tek `AdminClubFormView` (ADM-03, CD-54).
// T-40 · `AdminReportsRoute` (`/admin/reports?tab=&reportId=`, ADM-04).
// T-41 · `AdminUsersRoute` (`/admin/users?filter=`, ADM-05),
// `AdminUserProfileRoute` (`/admin/users/:userId`, CLB-07 paylaşılan).
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart' show PostType;
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/app_router.dart';
import 'package:gu_kulupler/product/navigation/route_guards.dart';
import 'package:gu_kulupler/product/navigation/routes/auth_routes.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_kulupler/product/navigation/routes/system_routes.dart';

import '../../helpers/design_files.dart';
import '../../helpers/design_ids.dart';

/// Bildirilen rota sınıfları ve router'daki yol kalıpları (T-11 + T-13 +
/// T-14 + T-16 + T-17 + T-18 + T-20 + T-21 + T-23 + T-24 + T-26 + T-27 +
/// T-28 + T-29 + T-31 + T-32 + T-33 + T-34 + T-35 + T-36 + T-39 + T-40 +
/// T-41).
const Map<GoRouteData, String> _routes = {
  // Sistem (kabuksuz)
  SplashRoute(): '/splash',
  ErrorRoute(): '/error',
  OfflineRoute(): '/offline',
  NotFoundRoute(): '/not-found',
  DebugMenuRoute(): '/debug',
  // Oturum öncesi (T-13: ONB-01, AUT-01, AUT-02, AUT-06; T-14: AUT-03,
  // AUT-04, AUT-05)
  OnboardingRoute(): '/onboarding',
  LoginRoute(): '/login',
  RegisterRoute(): '/login/register',
  ResetPasswordRoute(): '/login/reset',
  LegalRoute(tip: LegalTab.kvkk): '/legal/:tip',
  VerifyEmailRoute(): '/verify',
  SetupProfileRoute(): '/setup-profile',
  // Kabuk: beş sekme kökü
  ClubsRoute(): '/clubs',
  // Kulüpler dalı (T-17: CLB-02; T-18: CLB-07, CLB-06; T-16: CLB-03,
  // CLB-04, CLB-05; T-20: FED-02; T-21: FED-03)
  ClubsSearchRoute(): '/clubs/search',
  ClubUserProfileRoute(userId: _userId): '/clubs/user/:userId',
  ClubDetailRoute(clubId: _clubId): '/clubs/:clubId',
  ClubAppliedRoute(clubId: _clubId): '/clubs/:clubId/applied',
  ClubApplicationRoute(clubId: _clubId): '/clubs/:clubId/application',
  ClubMembersRoute(clubId: _clubId): '/clubs/:clubId/members',
  PostDetailRoute(clubId: _clubId, postId: _postId):
      '/clubs/:clubId/posts/:postId',
  ComposeRoute(clubId: _clubId): '/clubs/:clubId/compose',
  // Yönetim (T-31: MGT-01, MGT-10; T-32: MGT-02; T-33: MGT-03)
  ManageRoute(clubId: _clubId): '/clubs/:clubId/manage',
  ManageApplicationsRoute(clubId: _clubId):
      '/clubs/:clubId/manage/applications',
  ManageMembersRoute(clubId: _clubId): '/clubs/:clubId/manage/members',
  ActivityLogRoute(clubId: _clubId): '/clubs/:clubId/manage/activity',
  // T-34: MGT-04, MGT-05 (iki rota sınıfı, tek view — CD-54)
  ManageEventsRoute(clubId: _clubId): '/clubs/:clubId/manage/events',
  EventFormRoute(clubId: _clubId): '/clubs/:clubId/manage/events/new',
  EventEditRoute(clubId: _clubId, eventId: _eventId):
      '/clubs/:clubId/manage/events/:eventId/edit',
  // T-35: MGT-06, MGT-07
  AttendanceRoute(clubId: _clubId, eventId: _eventId):
      '/clubs/:clubId/manage/events/:eventId/attendance',
  ScanRoute(clubId: _clubId, eventId: _eventId):
      '/clubs/:clubId/manage/events/:eventId/attendance/scan',
  // T-36: MGT-08, MGT-09
  ManageContentRoute(clubId: _clubId): '/clubs/:clubId/manage/content',
  ClubSettingsRoute(clubId: _clubId): '/clubs/:clubId/manage/settings',
  EventsRoute(): '/events',
  // Etkinlikler dalı (T-17: CLB-02, paylaşılan yaprak; T-23: EVT-02, EVT-03;
  // T-24: EVT-04)
  MyEventsRoute(): '/events/mine',
  EventsSearchRoute(): '/events/search',
  EventDetailRoute(eventId: _eventId): '/events/:eventId',
  TicketRoute(eventId: _eventId): '/events/:eventId/ticket',
  NotificationsRoute(): '/notifications',
  // Bildirimler dalı (T-26: NTF-02)
  NotificationPrefsRoute(): '/notifications/preferences',
  AdminRoute(): '/admin',
  // Admin dalı (T-39: ADM-02, ADM-03 — iki rota sınıfı, tek view, CD-54)
  AdminClubsRoute(): '/admin/clubs',
  AdminClubFormRoute(): '/admin/clubs/new',
  AdminClubEditRoute(clubId: _clubId): '/admin/clubs/:clubId/edit',
  // T-40: ADM-04
  AdminReportsRoute(): '/admin/reports',
  // T-41: ADM-05, CLB-07 (paylaşılan)
  AdminUsersRoute(): '/admin/users',
  AdminUserProfileRoute(userId: _userId): '/admin/users/:userId',
  ProfileRoute(): '/profile',
  // Profil dalı (T-27: PRF-02, PRF-03, PRF-04)
  EditProfileRoute(): '/profile/edit',
  MyClubsRoute(): '/profile/clubs',
  SavedRoute(): '/profile/saved',
  // Ayarlar (T-28: SET-01, NTF-02, SET-02, CLB-07, SET-04, SET-05)
  SettingsRoute(): '/profile/settings',
  SettingsNotificationPrefsRoute(): '/profile/settings/notifications',
  BlockedRoute(): '/profile/settings/blocked',
  BlockedUserProfileRoute(userId: _userId): '/profile/settings/blocked/:userId',
  AboutRoute(): '/profile/settings/about',
  SupportRoute(): '/profile/settings/support',
  // Hesap silme (T-29: SET-03, W-33)
  DeleteAccountRoute(): '/profile/settings/delete',
};

/// Parametreli kulüp rotalarının örnek kimliği.
const String _clubId = 'c01';

/// Parametreli kullanıcı rotalarının örnek kimliği.
const String _userId = 'u01';

/// Parametreli gönderi rotalarının örnek kimliği.
const String _postId = 'p01';

/// Parametreli etkinlik rotalarının örnek kimliği.
const String _eventId = 'e01';

/// Yol parametresi işareti (`/clubs/:clubId`).
const String _parameterMark = ':';

/// Tasarım kimliği olmayan rotalar (CD-69).
const Set<String> _idlessPaths = {'/debug'};

/// navigation.md §2'de kendi satırı olmayan, bir satırın **ikinci yolu**
/// olan rota sınıfları (CD-54: bir rota sınıfı = bir yol) → o satırın sınıfı
/// ve ikinci yolun, ilk yolun ebeveynine eklenen parçası.
const Map<String, (String, String)> _secondPathRoutes = {
  'EventEditRoute': ('EventFormRoute', '/:eventId/edit'),
  'AdminClubEditRoute': ('AdminClubFormRoute', '/:clubId/edit'),
};

/// Router ağacındaki tüm tam yollar.
Set<String> _collectPaths(List<RouteBase> routes, [String parent = '']) {
  final paths = <String>{};
  for (final route in routes) {
    var base = parent;
    if (route is GoRoute) {
      base = route.path.startsWith('/') ? route.path : '$parent/${route.path}';
      paths.add(base);
    }
    paths.addAll(_collectPaths(route.routes, base));
  }
  return paths;
}

/// navigation.md §2 tablolarından sınıf adı → Flutter yolu (sorgusuz).
///
/// Kulüp yollarındaki `:id` parçası `:clubId` olarak okunur — navigation.md
/// §2.2 notu: "`:id` ve `:clubId` aynı kulüp kimliğidir (yol parametresi adı
/// `clubId` olarak birleştirilir)". Etkinlik yollarındaki `:id` aynı kuralla
/// `:eventId`'dir (§2.3; MGT satırları zaten `:eventId` yazar).
Map<String, String> _documentedPaths() {
  final row = RegExp(r'^\|[^|]*\|\s*`([^`]+)`[^|]*\|\s*`(\w+Route)`\s*\|');
  return {
    for (final line in readText('docs/navigation.md').split('\n'))
      if (row.firstMatch(line) case final match?)
        match.group(2)!: match
            .group(1)!
            .split('?')
            .first
            .replaceFirst(
              RegExp(r'^/clubs/:id(?=/|$)'),
              '/clubs/:${RouteAccessTable.clubIdParameter}',
            )
            .replaceFirst(
              RegExp(r'^/events/:id(?=/|$)'),
              '/events/:${RouteAccessTable.eventIdParameter}',
            ),
  };
}

void main() {
  group('T-11 · rota envanteri', () {
    test('router yolları = kapsamdaki 57 yol (T-11: 14, T-13: +2, '
        'T-14: +1, T-16: +3, T-17: +2, T-18: +2, T-20: +1, T-21: +1, '
        'T-23: +2, T-24: +1, T-26: +1, T-27: +3, T-28: +6, T-29: +1, '
        'T-31: +2, T-32: +1, T-33: +1, T-34: +3, T-35: +2, T-36: +2, '
        'T-39: +3, T-40: +1, T-41: +2)', () {
      expect(_collectPaths(AppRouter.routes), _routes.values.toSet());
      expect(_routes, hasLength(57));
    });

    test(
      "T-41 · ADM-05 ADM-01'in altındadır (`filter` sorgu parametresi); "
      "CLB-07 (paylaşılan) ADM-05'in altındadır; ikisi de süper admin (S) "
      'ister',
      () {
        expect(AdminUsersRoute.segment, 'users');
        expect(AdminUserProfileRoute.segment, ':userId');
        expect(AdminUsersFilter.values.map((filter) => filter.name), [
          'all',
          'managers',
          'suspended',
        ]);
        const plain = AdminUsersRoute();
        expect(plain.filter, isNull);
        final deep = Uri.parse(
          const AdminUsersRoute(filter: AdminUsersFilter.suspended).location,
        );
        expect(deep.path, '/admin/users');
        expect(deep.queryParameters, {'filter': 'suspended'});
        for (final MapEntry(key: route, value: location)
            in <GoRouteData, String>{
              plain: '/admin/users',
              const AdminUserProfileRoute(userId: _userId): '/admin/users/u01',
            }.entries) {
          final name = '${route.runtimeType}';
          expect(route.location, location, reason: name);
          final match = RouteAccessTable.match(Uri.parse(location));
          expect(match.pattern, _routes[route], reason: name);
          expect(match.access, RouteAccess.superAdmin, reason: name);
        }
        expect(
          const AdminUserProfileRoute(userId: 'a/b').location,
          '/admin/users/a%2Fb',
        );
      },
    );

    test(
      "T-40 · ADM-04 ADM-01'in altındadır (`tab` + `reportId` sorgu "
      'parametreleri; `reportId` grup anahtarıdır) ve süper admin (S) ister',
      () {
        expect(AdminReportsRoute.segment, 'reports');
        expect(AdminReportsTab.values.map((tab) => tab.name), [
          'open',
          'resolved',
        ]);
        const plain = AdminReportsRoute();
        expect(plain.tab, isNull);
        expect(plain.reportId, isNull);
        expect(plain.location, '/admin/reports');
        final deep = Uri.parse(
          const AdminReportsRoute(
            tab: AdminReportsTab.resolved,
            reportId: 'post_p13',
          ).location,
        );
        expect(deep.path, '/admin/reports');
        expect(deep.queryParameters, {
          'tab': 'resolved',
          'reportId': 'post_p13',
        });
        final match = RouteAccessTable.match(Uri.parse(plain.location));
        expect(match.pattern, _routes[plain]);
        expect(match.access, RouteAccess.superAdmin);
      },
    );

    test(
      "T-39 · ADM-02 ADM-01'in altındadır (`tab` sorgu parametresi); ADM-03 "
      "iki rota sınıfı tek view'dır (CD-54) ve ADM-02'nin altındadır; hepsi "
      'süper admin (S) ister',
      () {
        expect(AdminClubsRoute.segment, 'clubs');
        expect(AdminClubFormRoute.segment, 'new');
        expect(AdminClubEditRoute.segment, ':clubId/edit');
        expect(AdminClubsTab.values.map((tab) => tab.name), [
          'active',
          'suspended',
        ]);
        const plain = AdminClubsRoute();
        expect(plain.tab, isNull);
        expect(plain.location, '/admin/clubs');
        final deep = Uri.parse(
          const AdminClubsRoute(tab: AdminClubsTab.suspended).location,
        );
        expect(deep.path, '/admin/clubs');
        expect(deep.queryParameters, {'tab': 'suspended'});
        for (final MapEntry(key: route, value: location)
            in <GoRouteData, String>{
              plain: '/admin/clubs',
              const AdminClubFormRoute(): '/admin/clubs/new',
              const AdminClubEditRoute(clubId: _clubId):
                  '/admin/clubs/c01/edit',
            }.entries) {
          final name = '${route.runtimeType}';
          expect(route.location, location, reason: name);
          final match = RouteAccessTable.match(Uri.parse(location));
          expect(match.pattern, _routes[route], reason: name);
          expect(match.access, RouteAccess.superAdmin, reason: name);
        }
        expect(
          const AdminClubEditRoute(clubId: 'a/b').location,
          '/admin/clubs/a%2Fb/edit',
        );
        // navigation.md ADM-03 satırı iki yolu birlikte yazar (CD-54).
        final row = readText('docs/navigation.md')
            .split('\n')
            .firstWhere((line) => line.contains('`AdminClubFormRoute`'));
        expect(row, contains('`/admin/clubs/:id/edit`'));
      },
    );

    test(
      "T-36 · MGT-08 ve MGT-09 MGT-01'in altındadır; ikisi de yönetici ya da "
      'danışman (V) ister; `clubId` yol parametresidir',
      () {
        expect(ManageContentRoute.segment, 'content');
        expect(ClubSettingsRoute.segment, 'settings');
        for (final MapEntry(key: route, value: location)
            in <GoRouteData, String>{
              const ManageContentRoute(clubId: _clubId):
                  '/clubs/c01/manage/content',
              const ClubSettingsRoute(clubId: _clubId):
                  '/clubs/c01/manage/settings',
            }.entries) {
          final name = '${route.runtimeType}';
          expect(route.location, location, reason: name);
          final match = RouteAccessTable.match(Uri.parse(location));
          expect(match.pattern, _routes[route], reason: name);
          expect(match.access, RouteAccess.managerOrAdvisor, reason: name);
          expect(match.clubId, _clubId, reason: name);
        }
        expect(
          const ClubSettingsRoute(clubId: 'a/b').location,
          '/clubs/a%2Fb/manage/settings',
        );
        // W-40: MGT-01 "Bu ay duyuru" sekmeyi `?tab=` ile seçer; sorgu
        // guard'ı değiştirmez.
        const announcements = ManageContentRoute(
          clubId: _clubId,
          tab: PostType.announcement,
        );
        expect(
          announcements.location,
          '/clubs/c01/manage/content?tab=announcement',
        );
        expect(
          RouteAccessTable.match(Uri.parse(announcements.location)).access,
          RouteAccess.managerOrAdvisor,
        );
      },
    );

    test(
      "T-35 · MGT-06 MGT-04'ün altındadır (V); MGT-07 MGT-06'nın altındadır "
      '(M); `clubId` ve `eventId` yol parametresidir',
      () {
        expect(AttendanceRoute.segment, ':eventId/attendance');
        expect(ScanRoute.segment, 'scan');
        for (final MapEntry(key: route, value: (location, access))
            in <GoRouteData, (String, RouteAccess)>{
              const AttendanceRoute(clubId: _clubId, eventId: _eventId): (
                '/clubs/c01/manage/events/e01/attendance',
                RouteAccess.managerOrAdvisor,
              ),
              const ScanRoute(clubId: _clubId, eventId: _eventId): (
                '/clubs/c01/manage/events/e01/attendance/scan',
                RouteAccess.manager,
              ),
            }.entries) {
          final name = '${route.runtimeType}';
          expect(route.location, location, reason: name);
          final match = RouteAccessTable.match(Uri.parse(location));
          expect(match.pattern, _routes[route], reason: name);
          expect(match.access, access, reason: name);
          expect(match.clubId, _clubId, reason: name);
        }
        // Kimlik yolda kodlanır (ayırıcı içeren değer yolu bölmez).
        expect(
          const AttendanceRoute(clubId: _clubId, eventId: 'a/b').location,
          '/clubs/c01/manage/events/a%2Fb/attendance',
        );
      },
    );

    test(
      "T-34 · MGT-04 MGT-01'in altındadır (V; `tab` sorgu parametresi); "
      "MGT-05 iki rota sınıfı tek view'dır (CD-54) ve MGT-04'ün altındadır (M)",
      () {
        expect(ManageEventsRoute.segment, 'events');
        expect(EventFormRoute.segment, 'new');
        expect(EventEditRoute.segment, ':eventId/edit');
        expect(ManageEventsTab.values.map((tab) => tab.name), [
          'published',
          'draft',
          'past',
          'cancelled',
        ]);
        const plain = ManageEventsRoute(clubId: _clubId);
        expect(plain.tab, isNull);
        expect(plain.location, '/clubs/c01/manage/events');
        final deep = Uri.parse(
          const ManageEventsRoute(
            clubId: _clubId,
            tab: ManageEventsTab.draft,
          ).location,
        );
        expect(deep.path, '/clubs/c01/manage/events');
        expect(deep.queryParameters, {'tab': 'draft'});
        for (final MapEntry(key: route, value: (location, access))
            in <GoRouteData, (String, RouteAccess)>{
              plain: (
                '/clubs/c01/manage/events',
                RouteAccess.managerOrAdvisor,
              ),
              const EventFormRoute(clubId: _clubId): (
                '/clubs/c01/manage/events/new',
                RouteAccess.manager,
              ),
              const EventEditRoute(clubId: _clubId, eventId: _eventId): (
                '/clubs/c01/manage/events/e01/edit',
                RouteAccess.manager,
              ),
            }.entries) {
          final name = '${route.runtimeType}';
          expect(route.location, location, reason: name);
          final match = RouteAccessTable.match(Uri.parse(location));
          expect(match.pattern, _routes[route], reason: name);
          expect(match.access, access, reason: name);
          expect(match.clubId, _clubId, reason: name);
        }
        // navigation.md MGT-05 satırı iki yolu birlikte yazar (CD-54).
        final row = readText(
          'docs/navigation.md',
        ).split('\n').firstWhere((line) => line.contains('`EventFormRoute`'));
        expect(row, contains('`…/events/:eventId/edit`'));
      },
    );

    test(
      "T-33 · MGT-03 MGT-01'in altındadır (V); `transfer` sorgu "
      'parametresidir (varsayılan `false` yola yazılmaz)',
      () {
        expect(ManageMembersRoute.segment, 'members');
        const plain = ManageMembersRoute(clubId: _clubId);
        expect(plain.transfer, isFalse);
        expect(plain.location, '/clubs/c01/manage/members');
        final deep = Uri.parse(
          const ManageMembersRoute(clubId: _clubId, transfer: true).location,
        );
        expect(deep.path, '/clubs/c01/manage/members');
        expect(deep.queryParameters, {'transfer': 'true'});
        final match = RouteAccessTable.match(deep);
        expect(match.pattern, '/clubs/:clubId/manage/members');
        expect(match.access, RouteAccess.managerOrAdvisor);
        expect(match.clubId, _clubId);
      },
    );

    test(
      "T-32 · MGT-02 MGT-01'in altındadır (V); `tab` ve `applicant` sorgu "
      'parametresidir (sekme adları ekran sırasıyla `ApplicationsTab`)',
      () {
        expect(ManageApplicationsRoute.segment, 'applications');
        expect(ManageApplicationsRoute.applicantQuery, 'applicant');
        expect(ApplicationsTab.values.map((tab) => tab.name), [
          'pending',
          'approved',
          'rejected',
        ]);
        const plain = ManageApplicationsRoute(clubId: _clubId);
        expect(plain.tab, isNull);
        expect(plain.applicantId, isNull);
        expect(plain.location, '/clubs/c01/manage/applications');
        final deep = Uri.parse(
          const ManageApplicationsRoute(
            clubId: _clubId,
            tab: ApplicationsTab.rejected,
            applicantId: _userId,
          ).location,
        );
        expect(deep.path, '/clubs/c01/manage/applications');
        expect(deep.queryParameters, {'tab': 'rejected', 'applicant': 'u01'});
        final match = RouteAccessTable.match(deep);
        expect(match.pattern, '/clubs/:clubId/manage/applications');
        expect(match.access, RouteAccess.managerOrAdvisor);
        expect(match.clubId, _clubId);
      },
    );

    test(
      'T-31 · yönetim rotaları: `clubId` yol parametresidir; MGT-10 '
      "MGT-01'in altındadır; ikisi de yönetici ya da danışman (V) ister",
      () {
        const manage = ManageRoute(clubId: _clubId);
        const activity = ActivityLogRoute(clubId: _clubId);
        expect(ManageRoute.segment, 'manage');
        expect(ActivityLogRoute.segment, 'activity');
        for (final MapEntry(key: route, value: location) in {
          manage: '/clubs/c01/manage',
          activity: '/clubs/c01/manage/activity',
        }.entries) {
          final name = '${route.runtimeType}';
          expect(route.location, location, reason: name);
          final match = RouteAccessTable.match(Uri.parse(location));
          expect(match.pattern, _routes[route], reason: name);
          expect(match.access, RouteAccess.managerOrAdvisor, reason: name);
          expect(match.clubId, _clubId, reason: name);
        }
        // Kimlik yolda kodlanır (ayırıcı içeren değer yolu bölmez).
        expect(
          const ManageRoute(clubId: 'a/b').location,
          '/clubs/a%2Fb/manage',
        );
      },
    );

    test(
      'T-28 · T-29 · ayarlar rotaları (SET-03 dahil) `/profile/settings` altındadır; '
      'BlockedUserProfileRoute `userId` yol parametresidir; hepsi aktif '
      'oturum (A) ister',
      () {
        const blockedProfile = BlockedUserProfileRoute(userId: _userId);
        expect(blockedProfile.location, '/profile/settings/blocked/u01');
        final locations = <String>[
          const SettingsRoute().location,
          const SettingsNotificationPrefsRoute().location,
          const BlockedRoute().location,
          blockedProfile.location,
          const AboutRoute().location,
          const SupportRoute().location,
          const DeleteAccountRoute().location,
        ];
        expect(locations, [
          '/profile/settings',
          '/profile/settings/notifications',
          '/profile/settings/blocked',
          '/profile/settings/blocked/u01',
          '/profile/settings/about',
          '/profile/settings/support',
          '/profile/settings/delete',
        ]);
        for (final location in locations) {
          final match = RouteAccessTable.match(Uri.parse(location));
          expect(match.access, RouteAccess.active, reason: location);
          expect(match.clubId, isNull, reason: location);
        }
      },
    );

    test('T-27 · profil rotaları: sabit parçalar; MyClubsRoute `tab` sorgu '
        'parametresidir (ekrandaki sekme sırasıyla `MyClubsTab` adları); '
        'hepsi aktif oturum (A) ister', () {
      expect(const EditProfileRoute().location, '/profile/edit');
      expect(const SavedRoute().location, '/profile/saved');
      expect(const MyClubsRoute().location, '/profile/clubs');
      expect(const MyClubsRoute().tab, isNull);
      expect(MyClubsTab.values.map((tab) => tab.name), [
        'active',
        'pending',
        'past',
      ]);
      final locations = <String>[
        const EditProfileRoute().location,
        const SavedRoute().location,
        const MyClubsRoute().location,
        for (final tab in MyClubsTab.values) MyClubsRoute(tab: tab).location,
      ];
      expect(
        const MyClubsRoute(tab: MyClubsTab.pending).location,
        '/profile/clubs?tab=pending',
      );
      for (final location in locations) {
        final match = RouteAccessTable.match(Uri.parse(location));
        // Sorgu yolu ve guard'ı değiştirmez.
        expect(match.pattern, Uri.parse(location).path, reason: location);
        expect(match.access, RouteAccess.active, reason: location);
        expect(match.clubId, isNull, reason: location);
      }
    });

    test('T-24 · MyEventsRoute: sabit `mine` parçası `:eventId` kalıbına '
        'düşmez; aktif oturum (A) ister', () {
      expect(const MyEventsRoute().location, '/events/mine');
      expect(MyEventsRoute.segment, 'mine');
      final match = RouteAccessTable.match(Uri.parse('/events/mine'));
      expect(match.pattern, '/events/mine');
      expect(match.access, RouteAccess.active);
      expect(match.clubId, isNull);
    });

    test('T-23 · etkinlik detayı ve bilet: `eventId` yol, `showCancelled` '
        'sorgu parametresidir; ikisi de aktif oturum (A) ister', () {
      const detail = EventDetailRoute(eventId: _eventId);
      expect(detail.location, '/events/e01');
      expect(detail.showCancelled, isFalse);
      const cancelled = EventDetailRoute(
        eventId: _eventId,
        showCancelled: true,
      );
      expect(cancelled.location, '/events/e01?showCancelled=true');
      const ticket = TicketRoute(eventId: _eventId);
      expect(ticket.location, '/events/e01/ticket');
      expect(EventDetailRoute.segment, ':eventId');
      expect(TicketRoute.segment, 'ticket');
      for (final MapEntry(key: location, value: pattern) in {
        detail.location: '/events/:eventId',
        cancelled.location: '/events/:eventId',
        ticket.location: '/events/:eventId/ticket',
      }.entries) {
        final match = RouteAccessTable.match(Uri.parse(location));
        expect(match.pattern, pattern, reason: location);
        expect(match.access, RouteAccess.active, reason: location);
        expect(match.clubId, isNull, reason: location);
      }
      // Sabit `search` parçası `:eventId` kalıbına düşmez.
      expect(
        RouteAccessTable.match(Uri.parse('/events/search')).pattern,
        '/events/search',
      );
      // Kimlik yolda kodlanır (ayırıcı içeren değer yolu bölmez).
      expect(
        const EventDetailRoute(eventId: 'a/b').location,
        '/events/a%2Fb',
      );
    });

    test('T-21 · gönderi oluşturma rotası: `clubId` yol, `edit` sorgu '
        'parametresidir; guard yöneticiyi (M) ister', () {
      const compose = ComposeRoute(clubId: _clubId);
      expect(compose.location, '/clubs/c01/compose');
      expect(compose.edit, isNull);
      expect(ComposeRoute.segment, 'compose');
      const edit = ComposeRoute(clubId: _clubId, edit: _postId);
      expect(edit.location, '/clubs/c01/compose?edit=p01');
      // T-36 (W-97): başlangıç türü `?type=` sorgusudur.
      expect(compose.type, isNull);
      const announcement = ComposeRoute(
        clubId: _clubId,
        type: PostType.announcement,
      );
      expect(announcement.location, '/clubs/c01/compose?type=announcement');
      // Sorgu yolu ve guard'ı değiştirmez.
      for (final location in [
        compose.location,
        edit.location,
        announcement.location,
      ]) {
        final match = RouteAccessTable.match(Uri.parse(location));
        expect(match.pattern, '/clubs/:clubId/compose', reason: location);
        expect(match.access, RouteAccess.manager, reason: location);
        expect(match.clubId, _clubId, reason: location);
      }
    });

    test('T-20 · gönderi detayı rotası: `clubId` ve `postId` yol '
        'parametresidir; guard kulübün içini görmeyi (üye) ister', () {
      const post = PostDetailRoute(clubId: _clubId, postId: _postId);
      expect(post.location, '/clubs/c01/posts/p01');
      final match = RouteAccessTable.match(Uri.parse(post.location));
      expect(match.pattern, '/clubs/:clubId/posts/:postId');
      expect(match.access, RouteAccess.member);
      expect(match.clubId, _clubId);
      expect(PostDetailRoute.segment, 'posts/:postId');
      // Kimlikler yolda kodlanır (ayırıcı içeren değer yolu bölmez).
      expect(
        const PostDetailRoute(clubId: _clubId, postId: 'a/b').location,
        '/clubs/c01/posts/a%2Fb',
      );
    });

    test('T-18 · üye listesi ve profil rotaları: `user` parçası `:clubId` '
        'kalıbına düşmez; `clubId` profil rotasında sorgu parametresidir', () {
      const members = ClubMembersRoute(clubId: _clubId);
      expect(members.location, '/clubs/c01/members');
      final membersMatch = RouteAccessTable.match(Uri.parse(members.location));
      expect(membersMatch.pattern, '/clubs/:clubId/members');
      expect(membersMatch.access, RouteAccess.member);
      expect(membersMatch.clubId, _clubId);
      expect(ClubMembersRoute.segment, 'members');

      const profile = ClubUserProfileRoute(userId: _userId);
      expect(profile.location, '/clubs/user/u01');
      expect(
        const ClubUserProfileRoute(userId: _userId, clubId: _clubId).location,
        '/clubs/user/u01?clubId=c01',
      );
      for (final location in [
        '/clubs/user/u01',
        '/clubs/user/u01?clubId=c01',
      ]) {
        final match = RouteAccessTable.match(Uri.parse(location));
        expect(match.pattern, '/clubs/user/:userId', reason: location);
        expect(match.access, RouteAccess.active, reason: location);
        expect(match.clubId, isNull, reason: location);
      }
      expect(ClubUserProfileRoute.segment, 'user/:userId');
    });

    test('T-17 · arama rotaları: sabit `search` parçası `:clubId` kalıbına '
        'düşmez; ikisi de aktif oturum (A) ister', () {
      const locations = <GoRouteData, String>{
        ClubsSearchRoute(): '/clubs/search',
        EventsSearchRoute(): '/events/search',
      };
      for (final MapEntry(key: route, value: location) in locations.entries) {
        final name = '${route.runtimeType}';
        expect(route.location, location, reason: name);
        final match = RouteAccessTable.match(Uri.parse(location));
        expect(match.pattern, location, reason: name);
        expect(match.access, RouteAccess.active, reason: name);
        expect(match.clubId, isNull, reason: name);
      }
      expect(ClubsSearchRoute.segment, 'search');
      expect(EventsSearchRoute.segment, 'search');
    });

    test('rota sınıfının `location` değeri kilitli yoldur', () {
      for (final MapEntry(key: route, value: path) in _routes.entries) {
        if (path.contains(_parameterMark)) continue; // parametreli: aşağıda
        expect(route.location, path, reason: '${route.runtimeType}');
      }
    });

    test('T-13 · LegalRoute: `tip` yol parametresidir; her sekmenin yolu '
        'guard tablosundaki kalıba uyar', () {
      expect(LegalTab.values.map((tab) => tab.name), [
        'kvkk',
        'gizlilik',
        'kosullar',
      ]);
      expect(RouteParamGuard.legalTabs, {
        for (final tab in LegalTab.values) tab.name,
      });
      for (final tab in LegalTab.values) {
        final location = LegalRoute(tip: tab).location;
        expect(location, '/legal/${tab.name}');
        expect(
          RouteAccessTable.match(Uri.parse(location)).pattern,
          RouteAccessTable.legalPattern,
        );
        expect(RouteParamGuard.check(Uri.parse(location)), isNull);

        // Kayıt formundan açılış sorguda taşınır; yol ve guard değişmez.
        final fromRegister = Uri.parse(
          LegalRoute(tip: tab, from: LegalOrigin.register).location,
        );
        expect(fromRegister.toString(), '/legal/${tab.name}?from=register');
        expect(
          RouteAccessTable.match(fromRegister).pattern,
          RouteAccessTable.legalPattern,
        );
        expect(RouteParamGuard.check(fromRegister), isNull);
      }
    });

    test('T-16 · kulüp rotaları: `clubId` yol parametresidir; her rotanın '
        'yolu guard tablosunda aktif oturum (A) ister', () {
      const locations = <GoRouteData, String>{
        ClubDetailRoute(clubId: _clubId): '/clubs/c01',
        ClubAppliedRoute(clubId: _clubId): '/clubs/c01/applied',
        ClubApplicationRoute(clubId: _clubId): '/clubs/c01/application',
      };
      for (final MapEntry(key: route, value: location) in locations.entries) {
        final name = '${route.runtimeType}';
        expect(route.location, location, reason: name);
        final match = RouteAccessTable.match(Uri.parse(location));
        expect(match.pattern, _routes[route], reason: name);
        expect(match.access, RouteAccess.active, reason: name);
        expect(match.clubId, _clubId, reason: name);
        expect(RouteParamGuard.check(Uri.parse(location)), isNull);
      }
      expect(ClubDetailRoute.segment, ':${RouteAccessTable.clubIdParameter}');
      expect(ClubAppliedRoute.segment, 'applied');
      expect(ClubApplicationRoute.segment, 'application');
      // Kimlik yolda kodlanır (ayırıcı içeren değer yolu bölmez).
      expect(
        const ClubDetailRoute(clubId: 'a/b c').location,
        '/clubs/a%2Fb%20c',
      );
    });

    test('T-16 · ClubDetailRoute: `tab` sorgu parametresidir; değerler '
        'ekrandaki sekme sırasıyla `ClubDetailTab` adlarıdır', () {
      expect(ClubDetailTab.values.map((tab) => tab.name), [
        'about',
        'events',
        'posts',
        'members',
      ]);
      expect(const ClubDetailRoute(clubId: _clubId).tab, isNull);
      for (final tab in ClubDetailTab.values) {
        final location = Uri.parse(
          ClubDetailRoute(clubId: _clubId, tab: tab).location,
        );
        expect(location.toString(), '/clubs/c01?tab=${tab.name}');
        // Sorgu yolu ve guard'ı değiştirmez.
        final match = RouteAccessTable.match(location);
        expect(match.pattern, '/clubs/:clubId');
        expect(match.access, RouteAccess.active);
      }
    });

    test('sınıf adları ve yollar navigation.md §2 ile aynıdır', () {
      final documented = _documentedPaths();
      // Tablo okunabiliyor mu (biçim değişirse sessizce boş geçmesin)?
      expect(documented.length, greaterThanOrEqualTo(50));
      for (final MapEntry(key: route, value: path) in _routes.entries) {
        if (_idlessPaths.contains(path)) continue;
        final name = '${route.runtimeType}';
        if (_secondPathRoutes[name] case (final owner, final tail)) {
          // Satırın ilk yolunun ebeveyni (`…/new` öncesi) + ikinci yolun
          // parçası.
          final first = documented[owner]!;
          expect(
            '${first.substring(0, first.lastIndexOf('/'))}$tail',
            path,
            reason: name,
          );
          continue;
        }
        expect(documented, contains(name), reason: name);
        expect(documented[name], path, reason: name);
      }
    });

    test('tasarım kimliği olmayan tek rota /debug’dır (CD-69)', () {
      final documented = _documentedPaths();
      final idless = {
        for (final MapEntry(key: route, value: path) in _routes.entries)
          if (!documented.containsKey('${route.runtimeType}') &&
              !_secondPathRoutes.containsKey('${route.runtimeType}'))
            path,
      };
      expect(idless, _idlessPaths);
    });

    test('her yolun guard tablosunda satırı vardır', () {
      for (final path in _routes.values) {
        expect(
          RouteAccessTable.patterns,
          contains(path),
          reason: path,
        );
        // Parametreli kalıp somut bir yolla eşlenir.
        final sample = path.replaceFirst(
          ':${RouteAccessTable.legalTabParameter}',
          LegalTab.kvkk.name,
        );
        expect(
          RouteAccessTable.match(Uri.parse(sample)).pattern,
          path,
          reason: path,
        );
      }
    });

    test('sorgu parametreleri opsiyonel bağlamdır (`?from=`)', () {
      expect(
        const ErrorRoute(from: '/clubs/c01').location,
        '/error?from=%2Fclubs%2Fc01',
      );
      expect(
        const LoginRoute(from: '/events').location,
        '/login?from=%2Fevents',
      );
      expect(const LoginRoute().location, '/login');
    });
  });

  group('T-11 · rota envanteri · kabuk', () {
    StatefulShellRoute shell() =>
        AppRouter.routes.whereType<StatefulShellRoute>().single;

    test('kabuk tek StatefulShellRoute’tur; beş dal registry sırasıyla', () {
      final branches = shell().branches;
      expect(branches, hasLength(5));
      expect(
        [for (final branch in branches) (branch.routes.single as GoRoute).path],
        [for (final tab in GuTab.values) tab.rootPath],
      );
      expect(
        [for (final tab in GuTab.values) tab.name],
        DesignIds.tabRoots.keys,
      );
    });

    test('her dal kendi gezgin anahtarını kullanır', () {
      final branches = shell().branches;
      for (final tab in GuTab.values) {
        expect(
          branches[tab.index].navigatorKey,
          same(tab.navigatorKey),
          reason: tab.name,
        );
      }
    });

    test('sekme kökleri registry.json#tabRoot ekranlarının yollarıdır', () {
      // Prototip yolu (`screens-actions.json#path`) sekme köklerinde Flutter
      // yoluyla aynıdır.
      for (final tab in GuTab.values) {
        final screenId = DesignIds.tabRoots[tab.name]!;
        expect(
          DesignIds.screenMeta[screenId]!.path,
          tab.rootPath,
          reason: screenId,
        );
      }
    });

    test('kabuksuz rotalar kök düzeydedir', () {
      final topLevel = {
        for (final route in AppRouter.routes.whereType<GoRoute>()) route.path,
      };
      expect(topLevel, {
        '/splash',
        '/error',
        '/offline',
        '/not-found',
        '/debug',
        '/onboarding',
        '/login',
        '/legal/:tip',
        '/verify',
        '/setup-profile',
      });
    });

    test('T-13 / T-14 · AUT-02 ve AUT-04 `/login` altındadır (geri → '
        'AUT-01); AUT-06 kök düzeydedir', () {
      final login = AppRouter.routes.whereType<GoRoute>().singleWhere(
        (route) => route.path == '/login',
      );
      expect(
        [for (final child in login.routes.whereType<GoRoute>()) child.path],
        [RegisterRoute.segment, ResetPasswordRoute.segment],
      );
      expect(const RegisterRoute().location, '/login/register');
      expect(const ResetPasswordRoute().location, '/login/reset');
      // Alt rotaların alt rotası yoktur.
      for (final child in login.routes.whereType<GoRoute>()) {
        expect(child.routes, isEmpty, reason: child.path);
      }
    });
  });
}
