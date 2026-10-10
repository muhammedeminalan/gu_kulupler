// T-11 · Rota envanteri (kabuk + sistem + oturum öncesi yönlendirme
// hedefleri): router'daki yollar ↔ navigation.md §2 sınıf / yol tablosu ↔
// guard tablosu (PLAN §13.3, §13.5). Her ekran task'ı kendi satırını ekler;
// T-43'te 57 rota sınıfı / 51 ekran tamamlanır.
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

/// T-11'de bildirilen rota sınıfları ve yolları.
const Map<GoRouteData, String> _routes = {
  // Sistem (kabuksuz)
  SplashRoute(): '/splash',
  ErrorRoute(): '/error',
  OfflineRoute(): '/offline',
  NotFoundRoute(): '/not-found',
  DebugMenuRoute(): '/debug',
  // Oturum öncesi yönlendirme hedefleri (yer tutucu view)
  OnboardingRoute(): '/onboarding',
  LoginRoute(): '/login',
  VerifyEmailRoute(): '/verify',
  SetupProfileRoute(): '/setup-profile',
  // Kabuk: beş sekme kökü
  ClubsRoute(): '/clubs',
  EventsRoute(): '/events',
  NotificationsRoute(): '/notifications',
  AdminRoute(): '/admin',
  ProfileRoute(): '/profile',
};

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
Map<String, String> _documentedPaths() {
  final row = RegExp(r'^\|[^|]*\|\s*`([^`]+)`[^|]*\|\s*`(\w+Route)`\s*\|');
  return {
    for (final line in readText('docs/navigation.md').split('\n'))
      if (row.firstMatch(line) case final match?)
        match.group(2)!: match.group(1)!.split('?').first,
  };
}

void main() {
  group('T-11 · rota envanteri', () {
    test('router yolları = T-11 kapsamındaki 14 yol', () {
      expect(_collectPaths(AppRouter.routes), _routes.values.toSet());
      expect(_routes, hasLength(14));
    });

    test('rota sınıfının `location` değeri kilitli yoldur', () {
      for (final MapEntry(key: route, value: path) in _routes.entries) {
        expect(route.location, path, reason: '${route.runtimeType}');
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
        expect(
          RouteAccessTable.match(Uri.parse(path)).pattern,
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
        '/verify',
        '/setup-profile',
      });
    });
  });
}
