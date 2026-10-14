part of 'shell_route.dart';

// T-11 dal kökünü kurar; T-27 sekme kökünün gerçek ekranını ve profil
// alt rotalarını ekler (PLAN §13.3.5).
// TODO(T-28): `SettingsRoute` (`settings`) ve alt rotaları
// (`SettingsNotificationPrefsRoute`, `BlockedRoute`,
// `BlockedUserProfileRoute`, `AboutRoute`, `SupportRoute`).
// TODO(T-29): `DeleteAccountRoute` (`settings/delete`).

/// Profil dalının rota ağacı (navigation.md §2.5). Alt rotalar sahip
/// task'larında bu ağaca eklenir.
const TypedGoRoute<ProfileRoute> profileRouteTree = TypedGoRoute<ProfileRoute>(
  path: AppPaths.profile,
  routes: <TypedRoute<RouteData>>[
    TypedGoRoute<EditProfileRoute>(path: EditProfileRoute.segment),
    TypedGoRoute<MyClubsRoute>(path: MyClubsRoute.segment),
    TypedGoRoute<SavedRoute>(path: SavedRoute.segment),
  ],
);

/// PRF-01 Profil — Profil sekmesinin kökü, `/profile` (guard `A`).
final class ProfileRoute extends GoRouteData
    with $ProfileRoute, PlatformPageMixin {
  /// Sekme kökü rotası.
  const ProfileRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ProfileView();
}

/// PRF-02 Profili düzenle — `/profile/edit` (guard `A`). PRF-01 "Profili
/// düzenle" (`PRF-01.edit`) `go` ile açar, geri PRF-01'e döner.
final class EditProfileRoute extends GoRouteData
    with $EditProfileRoute, PlatformPageMixin {
  /// Profil düzenleme rotası.
  const EditProfileRoute();

  /// `/profile` altındaki yol parçası.
  static const String segment = 'edit';

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const EditProfileView();
}

/// PRF-03 Kulüplerim — `/profile/clubs?tab=active|pending|past` (guard
/// `A`). PRF-01 (`PRF-01.allClubs`, `PRF-01.stat.clubs`,
/// `PRF-01.stat.pending`), CLB-01 "Kulüplerim" (W-18) ve CLB-04
/// "Başvurularım" (W-65, `tab: MyClubsTab.pending`) `go` ile açar, geri
/// PRF-01'e döner.
final class MyClubsRoute extends GoRouteData
    with $MyClubsRoute, PlatformPageMixin {
  /// Kulüplerim; [tab] ilk açılan sekmedir.
  const MyClubsRoute({this.tab});

  /// `/profile` altındaki yol parçası.
  static const String segment = 'clubs';

  /// İlk açılan sekme (`?tab=active|pending|past`); `null` ya da tanınmayan
  /// değer → aktif.
  final MyClubsTab? tab;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      MyClubsView(tab: tab);
}

/// PRF-04 Kaydedilenler — `/profile/saved` (guard `A`). PRF-01
/// "Kaydedilenler" (`PRF-01.saved`) `go` ile açar, geri PRF-01'e döner.
final class SavedRoute extends GoRouteData with $SavedRoute, PlatformPageMixin {
  /// Kaydedilen gönderiler rotası.
  const SavedRoute();

  /// `/profile` altındaki yol parçası.
  static const String segment = 'saved';

  @override
  Widget build(BuildContext context, GoRouterState state) => const SavedView();
}
