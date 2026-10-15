part of 'shell_route.dart';

// T-11 dal kökünü kurdu; T-38 kök ekranı (ADM-01) bağladı.
// TODO(T-39): `AdminClubsRoute` ve form rotaları; kalan alt rotalar PLAN
// §13.3.6 tablosundaki task'larda.

/// Admin dalının rota ağacı (navigation.md §2.6). Alt rotalar sahip
/// task'larında bu ağaca eklenir.
const TypedGoRoute<AdminRoute> adminRouteTree = TypedGoRoute<AdminRoute>(
  path: AppPaths.admin,
);

/// Admin sekmesinin kökü — `/admin` (ADM-01 `AdminView`; guard `S`).
final class AdminRoute extends GoRouteData with $AdminRoute, PlatformPageMixin {
  /// Sekme kökü rotası.
  const AdminRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const AdminView();
}
