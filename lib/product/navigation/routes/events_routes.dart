part of 'shell_route.dart';

// T-11 dal kökünü, T-17 aramayı kurar.
// TODO(T-23): `EventDetailRoute`, `TicketRoute`; kalan alt rotalar PLAN
// §13.3.3 tablosundaki task'larda.
//
// Sıra önemlidir: sabit parçalı kardeşler (`search` — T-17, `mine` — T-24)
// `:eventId` kalıbından **önce** yazılır (go_router ilk eşleşeni alır).

/// Etkinlikler dalının rota ağacı (navigation.md §2.3). Alt rotalar sahip
/// task'larında bu ağaca eklenir.
const TypedGoRoute<EventsRoute> eventsRouteTree = TypedGoRoute<EventsRoute>(
  path: AppPaths.events,
  routes: <TypedRoute<RouteData>>[
    TypedGoRoute<EventsSearchRoute>(path: EventsSearchRoute.segment),
  ],
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

/// CLB-02 Arama (paylaşılan yaprak, PLAN §13.9) — `/events/search` (guard
/// `A`). `ClubsSearchRoute` ile aynı view'ı "Etkinlikler" sekmesiyle açar;
/// giriş noktası EVT-01 arama düğmesidir (T-24), geri EVT-01'e döner.
final class EventsSearchRoute extends GoRouteData
    with $EventsSearchRoute, PlatformPageMixin {
  /// Etkinlikler sekmesinden açılan arama.
  const EventsSearchRoute();

  /// `/events` altındaki yol parçası.
  static const String segment = 'search';

  @override
  Widget build(BuildContext context, GoRouterState state) => const SearchView(
    scope: SearchScope.events,
    applicationSheetBuilder: joinApplicationSheetBuilder,
  );
}
