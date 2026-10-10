part of 'shell_route.dart';

// T-11 yalnızca dal kökünü kurar.
// TODO(T-23): `EventDetailRoute`, `TicketRoute`; kalan alt rotalar PLAN
// §13.3.3 tablosundaki task'larda.

/// Etkinlikler dalının rota ağacı (navigation.md §2.3). Alt rotalar sahip
/// task'larında bu ağaca eklenir.
const TypedGoRoute<EventsRoute> eventsRouteTree = TypedGoRoute<EventsRoute>(
  path: AppPaths.events,
);

/// Etkinlikler sekmesinin kökü — `/events`.
final class EventsRoute extends GoRouteData
    with $EventsRoute, PlatformPageMixin {
  /// Sekme kökü rotası.
  const EventsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      // TODO(T-24): `EventListView` (Etkinlikler sekme kökü).
      RoutePlaceholderView(title: (l10n) => l10n.navEvents);
}
