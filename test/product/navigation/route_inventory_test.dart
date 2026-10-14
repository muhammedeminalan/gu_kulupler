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
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/app_router.dart';
import 'package:gu_kulupler/product/navigation/route_guards.dart';
import 'package:gu_kulupler/product/navigation/routes/auth_routes.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_kulupler/product/navigation/routes/system_routes.dart';

import '../../helpers/design_files.dart';
import '../../helpers/design_ids.dart';

/// Bildirilen rota sınıfları ve router'daki yol kalıpları (T-11 + T-13 +
/// T-14 + T-16 + T-17 + T-18 + T-20 + T-21 + T-23).
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
  EventsRoute(): '/events',
  // Etkinlikler dalı (T-17: CLB-02, paylaşılan yaprak; T-23: EVT-02, EVT-03)
  EventsSearchRoute(): '/events/search',
  EventDetailRoute(eventId: _eventId): '/events/:eventId',
  TicketRoute(eventId: _eventId): '/events/:eventId/ticket',
  NotificationsRoute(): '/notifications',
  AdminRoute(): '/admin',
  ProfileRoute(): '/profile',
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
    test('router yolları = kapsamdaki 28 yol (T-11: 14, T-13: +2, '
        'T-14: +1, T-16: +3, T-17: +2, T-18: +2, T-20: +1, T-21: +1, '
        'T-23: +2)', () {
      expect(_collectPaths(AppRouter.routes), _routes.values.toSet());
      expect(_routes, hasLength(28));
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
      // Sorgu yolu ve guard'ı değiştirmez.
      for (final location in [compose.location, edit.location]) {
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
        expect(documented, contains(name), reason: name);
        expect(documented[name], path, reason: name);
      }
    });

    test('tasarım kimliği olmayan tek rota /debug’dır (CD-69)', () {
      final documented = _documentedPaths();
      final idless = {
        for (final MapEntry(key: route, value: path) in _routes.entries)
          if (!documented.containsKey('${route.runtimeType}')) path,
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
