import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/app_redirect.dart';
import 'package:gu_kulupler/product/navigation/navigator_keys.dart';
import 'package:gu_kulupler/product/navigation/routes/auth_routes.dart'
    as auth_routes;
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart'
    as shell_route;
import 'package:gu_kulupler/product/navigation/routes/system_routes.dart'
    as system_routes;
import 'package:gu_kulupler/product/navigation/session_refresh_listenable.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

/// Uygulamanın router'ı (D-05; navigation.md §1, PLAN §13.1).
///
/// Rota ağacı `routes/` altındaki kütüphanelerde bildirilir (CD-13); her biri
/// kendi üretilen `$appRoutes` listesini taşır ve burada birleştirilir. Bu
/// dosya feature import etmez (B07): bilinmeyen yolun sayfası da (SYS-04) bir
/// rota sınıfı üzerinden kurulur.
abstract final class AppRouter {
  /// Kök rota listesi: sistem + oturum öncesi + kabuk.
  static List<RouteBase> get routes => <RouteBase>[
    ...system_routes.$appRoutes,
    ...auth_routes.$appRoutes,
    ...shell_route.$appRoutes,
  ];

  /// Router'ı kurar. [listenable] oturum değiştikçe yönlendirmeyi yeniden
  /// değerlendirtir.
  static GoRouter create(SessionRefreshListenable listenable) => GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppPaths.splash,
    routes: routes,
    redirect: AppRedirect.goRouterRedirect,
    refreshListenable: listenable,
    errorPageBuilder: (context, state) =>
        const system_routes.NotFoundRoute().buildPage(context, state),
    debugLogDiagnostics: kDebugMode,
  );
}

/// Uygulama ömrü boyunca tek router (`MaterialApp.router(routerConfig:)`).
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final router = AppRouter.create(ref.watch(sessionRefreshListenableProvider));
  ref.onDispose(router.dispose);
  return router;
}
