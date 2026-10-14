part of 'shell_route.dart';

// T-11 dal kökünü kurar; T-26 sekme kökünün gerçek ekranını ve bildirim
// tercihlerini ekler (PLAN §13.3.4). NTF-02'nin ikinci girişi
// `SettingsNotificationPrefsRoute` (`/profile/settings/notifications`) T-28'de
// Profil dalına eklenir; aynı `NotificationPrefsView`'ı açar.

/// Bildirimler dalının rota ağacı (navigation.md §2.4).
const TypedGoRoute<NotificationsRoute> notificationsRouteTree =
    TypedGoRoute<NotificationsRoute>(
      path: AppPaths.notifications,
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<NotificationPrefsRoute>(
          path: NotificationPrefsRoute.segment,
        ),
      ],
    );

/// NTF-01 Bildirimler — sekme kökü `/notifications` (guard `A`).
final class NotificationsRoute extends GoRouteData
    with $NotificationsRoute, PlatformPageMixin {
  /// Sekme kökü rotası.
  const NotificationsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const NotificationsView();
}

/// NTF-02 Bildirim tercihleri — `/notifications/preferences` (guard `A`).
/// NTF-01 "Ayarlar" (`NTF-01.settings`) `go` ile açar, geri NTF-01'e döner.
final class NotificationPrefsRoute extends GoRouteData
    with $NotificationPrefsRoute, PlatformPageMixin {
  /// Bildirim tercihleri rotası.
  const NotificationPrefsRoute();

  /// `/notifications` altındaki yol parçası.
  static const String segment = 'preferences';

  /// "Kulüp bazlı ayarlar" satırının sheet'i (SHT-07; T-16).
  static Widget clubPrefsSheet(String clubId, String clubName) =>
      ClubNotificationSheet(clubId: clubId, clubName: clubName);

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const NotificationPrefsView(clubPrefsSheetBuilder: clubPrefsSheet);
}
