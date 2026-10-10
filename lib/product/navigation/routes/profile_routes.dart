part of 'shell_route.dart';

// T-11 yalnızca dal kökünü kurar.
// TODO(T-27): `EditProfileRoute`, `MyClubsRoute`, `SavedRoute`; kalan alt
// rotalar PLAN §13.3.5 tablosundaki task'larda.

/// Profil dalının rota ağacı (navigation.md §2.5). Alt rotalar sahip
/// task'larında bu ağaca eklenir.
const TypedGoRoute<ProfileRoute> profileRouteTree = TypedGoRoute<ProfileRoute>(
  path: AppPaths.profile,
);

/// Profil sekmesinin kökü — `/profile`.
final class ProfileRoute extends GoRouteData
    with $ProfileRoute, PlatformPageMixin {
  /// Sekme kökü rotası.
  const ProfileRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      // TODO(T-27): `ProfileView` (Profil sekme kökü).
      RoutePlaceholderView(title: (l10n) => l10n.navProfile);
}
