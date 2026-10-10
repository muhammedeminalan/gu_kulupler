import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/gu_page_transitions.dart';
import 'package:gu_kulupler/product/navigation/navigator_keys.dart';
import 'package:gu_kulupler/product/navigation/routes/route_placeholder_view.dart';
import 'package:gu_kulupler/product/navigation/shell/app_shell_view.dart';

// Dal dosyaları bu kütüphanenin parçasıdır: go_router_builder bir rota
// sınıfının üretilen mixin'ini, ağacını taşıyan bildirimin kütüphanesine
// yazar; kabuk ağacı tek bildirimdir (`AppShellRouteData`).
part 'admin_routes.dart';
part 'clubs_routes.dart';
part 'events_routes.dart';
part 'notifications_routes.dart';
part 'profile_routes.dart';
part 'shell_route.g.dart';

/// Kabuk: alt sekme çubuğu + beş bağımsız dal
/// (`StatefulShellRoute.indexedStack`; navigation.md §1, PLAN §13.2).
///
/// Dal sırası `GuTab` / `registry.json#tabs` ile aynıdır. Her dalın rota
/// ağacı kendi dosyasındaki sabittir; ekran task'ları oraya alt rota ekler.
@TypedStatefulShellRoute<AppShellRouteData>(
  branches: <TypedStatefulShellBranch<StatefulShellBranchData>>[
    TypedStatefulShellBranch<ClubsBranchData>(
      routes: <TypedRoute<RouteData>>[clubsRouteTree],
    ),
    TypedStatefulShellBranch<EventsBranchData>(
      routes: <TypedRoute<RouteData>>[eventsRouteTree],
    ),
    TypedStatefulShellBranch<NotificationsBranchData>(
      routes: <TypedRoute<RouteData>>[notificationsRouteTree],
    ),
    TypedStatefulShellBranch<AdminBranchData>(
      routes: <TypedRoute<RouteData>>[adminRouteTree],
    ),
    TypedStatefulShellBranch<ProfileBranchData>(
      routes: <TypedRoute<RouteData>>[profileRouteTree],
    ),
  ],
)
final class AppShellRouteData extends StatefulShellRouteData {
  /// Kabuk rotası.
  const AppShellRouteData();

  @override
  Widget builder(
    BuildContext context,
    GoRouterState state,
    StatefulNavigationShell navigationShell,
  ) => AppShellView(navigationShell: navigationShell);

  /// Kabuğa giriş (giriş sonrası) ve kabuktan çıkış (oturum kapatma) solar;
  /// sekme değişimi animasyonsuzdur (navigation.md §5).
  @override
  Page<void> pageBuilder(
    BuildContext context,
    GoRouterState state,
    StatefulNavigationShell navigationShell,
  ) => GuPageTransitions.fade<void>(
    context: context,
    key: state.pageKey,
    child: builder(context, state, navigationShell),
  );
}

/// Kulüpler dalı (0).
final class ClubsBranchData extends StatefulShellBranchData {
  /// Kulüpler dalı.
  const ClubsBranchData();

  /// Dalın gezgini.
  static final GlobalKey<NavigatorState> $navigatorKey = clubsNavigatorKey;
}

/// Etkinlikler dalı (1).
final class EventsBranchData extends StatefulShellBranchData {
  /// Etkinlikler dalı.
  const EventsBranchData();

  /// Dalın gezgini.
  static final GlobalKey<NavigatorState> $navigatorKey = eventsNavigatorKey;
}

/// Bildirimler dalı (2).
final class NotificationsBranchData extends StatefulShellBranchData {
  /// Bildirimler dalı.
  const NotificationsBranchData();

  /// Dalın gezgini.
  static final GlobalKey<NavigatorState> $navigatorKey =
      notificationsNavigatorKey;
}

/// Admin dalı (3). Sekme yalnızca süper admine görünür; dal yine tanımlıdır
/// ve rotayı R8 korur.
final class AdminBranchData extends StatefulShellBranchData {
  /// Admin dalı.
  const AdminBranchData();

  /// Dalın gezgini.
  static final GlobalKey<NavigatorState> $navigatorKey = adminNavigatorKey;
}

/// Profil dalı (4).
final class ProfileBranchData extends StatefulShellBranchData {
  /// Profil dalı.
  const ProfileBranchData();

  /// Dalın gezgini.
  static final GlobalKey<NavigatorState> $navigatorKey = profileNavigatorKey;
}
