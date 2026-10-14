part of 'shell_route.dart';

// T-11 dal kökünü kurar; T-27 sekme kökünün gerçek ekranını ve profil
// alt rotalarını, T-28 ayarlar ağacını ekler (PLAN §13.3.5).
// TODO(T-29): `DeleteAccountRoute` (`settings/delete`).

/// Profil dalının rota ağacı (navigation.md §2.5). Alt rotalar sahip
/// task'larında bu ağaca eklenir.
const TypedGoRoute<ProfileRoute> profileRouteTree = TypedGoRoute<ProfileRoute>(
  path: AppPaths.profile,
  routes: <TypedRoute<RouteData>>[
    TypedGoRoute<EditProfileRoute>(path: EditProfileRoute.segment),
    TypedGoRoute<MyClubsRoute>(path: MyClubsRoute.segment),
    TypedGoRoute<SavedRoute>(path: SavedRoute.segment),
    TypedGoRoute<SettingsRoute>(
      path: SettingsRoute.segment,
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<SettingsNotificationPrefsRoute>(
          path: SettingsNotificationPrefsRoute.segment,
        ),
        TypedGoRoute<BlockedRoute>(
          path: BlockedRoute.segment,
          routes: <TypedRoute<RouteData>>[
            TypedGoRoute<BlockedUserProfileRoute>(
              path: BlockedUserProfileRoute.segment,
            ),
          ],
        ),
        TypedGoRoute<AboutRoute>(path: AboutRoute.segment),
        TypedGoRoute<SupportRoute>(path: SupportRoute.segment),
      ],
    ),
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

/// SET-01 Ayarlar — `/profile/settings` (guard `A`). PRF-01 ayarlar girişi
/// (W-32) `go` ile açar, geri PRF-01'e döner.
final class SettingsRoute extends GoRouteData
    with $SettingsRoute, PlatformPageMixin {
  /// Ayarlar rotası.
  const SettingsRoute();

  /// `/profile` altındaki yol parçası.
  static const String segment = 'settings';

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SettingsView();
}

/// NTF-02 Bildirim tercihleri (paylaşılan) — `/profile/settings/notifications`
/// (guard `A`). SET-01 "Bildirimler" `go` ile açar, geri SET-01'e döner;
/// kulüp satırı SHT-07 açar (PLAN §13.9).
final class SettingsNotificationPrefsRoute extends GoRouteData
    with $SettingsNotificationPrefsRoute, PlatformPageMixin {
  /// Ayarlar altındaki bildirim tercihleri rotası.
  const SettingsNotificationPrefsRoute();

  /// `/profile/settings` altındaki yol parçası.
  static const String segment = 'notifications';

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const NotificationPrefsView(
        clubPrefsSheetBuilder: NotificationPrefsRoute.clubPrefsSheet,
      );
}

/// SET-02 Engellenenler — `/profile/settings/blocked` (guard `A`). SET-01
/// "Engellenen kullanıcılar" `go` ile açar, geri SET-01'e döner.
final class BlockedRoute extends GoRouteData
    with $BlockedRoute, PlatformPageMixin {
  /// Engellenen kullanıcılar rotası.
  const BlockedRoute();

  /// `/profile/settings` altındaki yol parçası.
  static const String segment = 'blocked';

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const BlockedUsersView();
}

/// CLB-07 Kullanıcı profili (paylaşılan yaprak, PLAN §13.9) —
/// `/profile/settings/blocked/:userId` (guard `A`). SET-02 kullanıcı satırı
/// (`SET-02.user.<id>`) `go` ile açar, geri SET-02'ye döner.
final class BlockedUserProfileRoute extends GoRouteData
    with $BlockedUserProfileRoute, PlatformPageMixin {
  /// Engellenen [userId] kullanıcısının profili.
  const BlockedUserProfileRoute({required this.userId});

  /// `/profile/settings/blocked` altındaki yol parçası.
  static const String segment = ':userId';

  /// Profili açılan kullanıcının kimliği (yol parametresi).
  final String userId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      UserProfileView(userId: userId);
}

/// SET-04 Hakkında — `/profile/settings/about` (guard `A`). SET-01
/// "Hakkında" ve `system` bildirimi (W-30) `go` ile açar, geri SET-01'e
/// döner.
final class AboutRoute extends GoRouteData with $AboutRoute, PlatformPageMixin {
  /// Hakkında rotası.
  const AboutRoute();

  /// `/profile/settings` altındaki yol parçası.
  static const String segment = 'about';

  @override
  Widget build(BuildContext context, GoRouterState state) => const AboutView();
}

/// SET-05 Yardım ve destek — `/profile/settings/support` (guard `A`). SET-01
/// ve SET-04 "Destek" `go` ile açar, geri SET-01'e döner.
final class SupportRoute extends GoRouteData
    with $SupportRoute, PlatformPageMixin {
  /// Destek rotası.
  const SupportRoute();

  /// `/profile/settings` altındaki yol parçası.
  static const String segment = 'support';

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SupportView();
}
