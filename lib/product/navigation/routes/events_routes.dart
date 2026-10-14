part of 'shell_route.dart';

// T-11 dal kökünü, T-17 aramayı, T-23 etkinlik detayı ile bileti, T-24
// `EventListView` kökünü ve `MyEventsRoute`'u kurar (PLAN §13.3.3).
//
// Sıra önemlidir: sabit parçalı kardeşler (`search` — T-17, `mine` — T-24)
// `:eventId` kalıbından **önce** yazılır (go_router ilk eşleşeni alır).

/// Etkinlikler dalının rota ağacı (navigation.md §2.3). Alt rotalar sahip
/// task'larında bu ağaca eklenir.
const TypedGoRoute<EventsRoute> eventsRouteTree = TypedGoRoute<EventsRoute>(
  path: AppPaths.events,
  routes: <TypedRoute<RouteData>>[
    TypedGoRoute<MyEventsRoute>(path: MyEventsRoute.segment),
    TypedGoRoute<EventsSearchRoute>(path: EventsSearchRoute.segment),
    TypedGoRoute<EventDetailRoute>(
      path: EventDetailRoute.segment,
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<TicketRoute>(path: TicketRoute.segment),
      ],
    ),
  ],
);

/// EVT-01 Etkinlikler — Etkinlikler sekmesinin kökü, `/events` (guard `A`).
final class EventsRoute extends GoRouteData
    with $EventsRoute, PlatformPageMixin {
  /// Sekme kökü rotası.
  const EventsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const EventListView();
}

/// EVT-04 Etkinliklerim — `/events/mine?tab=upcoming|past|waitlist` (guard
/// `A`). EVT-01 "Biletlerim" düğmesi (`EVT-01.tickets`) `go` ile açar, geri
/// EVT-01'e döner. PRF-01 "Biletlerim" ve "Katıldığım etkinlik" kartı
/// (`tab: MyEventsTab.past`) da açar (T-27).
final class MyEventsRoute extends GoRouteData
    with $MyEventsRoute, PlatformPageMixin {
  /// Kullanıcının katılım kayıtları; [tab] ilk açılan sekmedir.
  const MyEventsRoute({this.tab});

  /// `/events` altındaki yol parçası (sabit; `:eventId`'den önce).
  static const String segment = 'mine';

  /// İlk açılan sekme (`?tab=`); `null` ya da tanınmayan değer → yaklaşan.
  final MyEventsTab? tab;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      MyEventsView(tab: tab);
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

/// EVT-02 Etkinlik detayı — `/events/:eventId?showCancelled=` (guard `A`;
/// yalnızca üyelere açık etkinliğin okuma izni Rules'tadır — reddedilirse
/// ekran TST-X18 + `EventsRoute` (CD-57)). EVT-01 / EVT-04 / CLB-03 /
/// CLB-02 kartları ve bildirimler `go` ile açar, geri EVT-01'e döner.
final class EventDetailRoute extends GoRouteData
    with $EventDetailRoute, PlatformPageMixin {
  /// [eventId] etkinliğinin detayı; [showCancelled] "Etkinlik iptal edildi"
  /// bildiriminden açılışta DLG-16'yı gösterir.
  const EventDetailRoute({
    required this.eventId,
    @TypedQueryParameter<bool>(name: showCancelledQuery)
    this.showCancelled = false,
  });

  /// `/events` altındaki yol parçası.
  static const String segment = ':${RouteAccessTable.eventIdParameter}';

  /// İptal bildiriminin sorgu parametresi adı (`?showCancelled=`).
  static const String showCancelledQuery = 'showCancelled';

  /// Etkinlik kimliği (yol parametresi).
  final String eventId;

  /// İptal bildiriminden açıldı (`?showCancelled=true`; varsayılan `false`
  /// sorguya yazılmaz).
  final bool showCancelled;

  /// go_router sayfa anahtarı yol **kalıbıdır** (`/events/:eventId`): bir
  /// etkinlikten ötekine `go` aynı sayfayı yeniden kullanır. View'ın anahtarı
  /// kimliktir; böylece ekran durumu (dinleyiciler, kaydırma) etkinlik
  /// değişince yeniden kurulur.
  @override
  Widget build(BuildContext context, GoRouterState state) => EventDetailView(
    key: ValueKey<String>(eventId),
    eventId: eventId,
    showCancelled: showCancelled,
  );
}

/// EVT-03 Bilet — `/events/:eventId/ticket` (guard `A` + kendi katılım
/// kaydı: kayıt yoksa `TicketViewModel` `EventDetailRoute`'a döner). EVT-02
/// "Biletini göster", TST-41 eylemi ve hatırlatıcı bildirimi `go` ile açar;
/// geri EVT-02'ye döner.
final class TicketRoute extends GoRouteData
    with $TicketRoute, PlatformPageMixin {
  /// [eventId] etkinliğinin bileti.
  const TicketRoute({required this.eventId});

  /// `/events/:eventId` altındaki yol parçası.
  static const String segment = 'ticket';

  /// Etkinlik kimliği (yol parametresi).
  final String eventId;

  /// View anahtarı etkinlik kimliğidir (bkz. [EventDetailRoute.build]).
  @override
  Widget build(BuildContext context, GoRouterState state) =>
      TicketView(key: ValueKey<String>(eventId), eventId: eventId);
}
