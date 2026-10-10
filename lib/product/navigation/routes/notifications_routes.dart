part of 'shell_route.dart';

// T-11 yalnızca dal kökünü kurar.
// TODO(T-26): `NotificationPrefsRoute`.

/// Bildirimler dalının rota ağacı (navigation.md §2.4). Alt rotalar sahip
/// task'larında bu ağaca eklenir.
const TypedGoRoute<NotificationsRoute> notificationsRouteTree =
    TypedGoRoute<NotificationsRoute>(
      path: AppPaths.notifications,
    );

/// Bildirimler sekmesinin kökü — `/notifications`.
final class NotificationsRoute extends GoRouteData
    with $NotificationsRoute, PlatformPageMixin {
  /// Sekme kökü rotası.
  const NotificationsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      // TODO(T-26): `NotificationsView` (Bildirimler sekme kökü).
      RoutePlaceholderView(title: (l10n) => l10n.navNotifications);
}
