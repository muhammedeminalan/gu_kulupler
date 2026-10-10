part of 'shell_route.dart';

// T-11 yalnızca dal kökünü kurar.
// TODO(T-16): `ClubDetailRoute`, `ClubAppliedRoute`, `ClubApplicationRoute`;
// kalan alt rotalar PLAN §13.3.2 tablosundaki task'larda.

/// Kulüpler dalının rota ağacı (navigation.md §2.2). Alt rotalar sahip
/// task'larında bu ağaca eklenir.
const TypedGoRoute<ClubsRoute> clubsRouteTree = TypedGoRoute<ClubsRoute>(
  path: AppPaths.clubs,
);

/// Kulüpler sekmesinin kökü — `/clubs`.
final class ClubsRoute extends GoRouteData with $ClubsRoute, PlatformPageMixin {
  /// Sekme kökü rotası.
  const ClubsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      // TODO(T-17): `ClubListView` (Kulüpler sekme kökü).
      RoutePlaceholderView(title: (l10n) => l10n.navClubs);
}
