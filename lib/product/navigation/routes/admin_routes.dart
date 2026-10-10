part of 'shell_route.dart';

// T-11 yalnızca dal kökünü kurar.
// TODO(T-39): `AdminClubsRoute` ve form rotaları; kalan alt rotalar PLAN
// §13.3.6 tablosundaki task'larda.

/// Admin dalının rota ağacı (navigation.md §2.6). Alt rotalar sahip
/// task'larında bu ağaca eklenir.
const TypedGoRoute<AdminRoute> adminRouteTree = TypedGoRoute<AdminRoute>(
  path: AppPaths.admin,
);

/// Admin sekmesinin kökü — `/admin`.
final class AdminRoute extends GoRouteData with $AdminRoute, PlatformPageMixin {
  /// Sekme kökü rotası.
  const AdminRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      // TODO(T-38): `AdminView` (Admin sekme kökü).
      RoutePlaceholderView(title: (l10n) => l10n.navAdmin);
}
