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
/// T-14 + T-16 + T-17).
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
  // Kulüpler dalı (T-17: CLB-02; T-16: CLB-03, CLB-04, CLB-05)
  ClubsSearchRoute(): '/clubs/search',
  ClubDetailRoute(clubId: _clubId): '/clubs/:clubId',
  ClubAppliedRoute(clubId: _clubId): '/clubs/:clubId/applied',
  ClubApplicationRoute(clubId: _clubId): '/clubs/:clubId/application',
  EventsRoute(): '/events',
  // Etkinlikler dalı (T-17: CLB-02, paylaşılan yaprak)
  EventsSearchRoute(): '/events/search',
  NotificationsRoute(): '/notifications',
  AdminRoute(): '/admin',
  ProfileRoute(): '/profile',
};

/// Parametreli kulüp rotalarının örnek kimliği.
const String _clubId = 'c01';

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
/// `clubId` olarak birleştirilir)".
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
            ),
  };
}

void main() {
  group('T-11 · rota envanteri', () {
    test('router yolları = kapsamdaki 22 yol (T-11: 14, T-13: +2, '
        'T-14: +1, T-16: +3, T-17: +2)', () {
      expect(_collectPaths(AppRouter.routes), _routes.values.toSet());
      expect(_routes, hasLength(22));
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
