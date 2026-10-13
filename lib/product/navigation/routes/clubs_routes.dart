part of 'shell_route.dart';

// T-11 dal kökünü, T-16 kulüp detayı ile başvuru rotalarını, T-17 sekme
// kökünün gerçek ekranını ve aramayı kurar; kalan alt rotalar PLAN §13.3.2
// tablosundaki task'larda eklenir.
//
// Sıra önemlidir: sabit parçalı kardeşler (`search` — T-17, `user/:userId` —
// T-18) `:clubId` kalıbından **önce** yazılır (go_router ilk eşleşeni alır).

/// Kulüpler dalının rota ağacı (navigation.md §2.2). Alt rotalar sahip
/// task'larında bu ağaca eklenir.
const TypedGoRoute<ClubsRoute> clubsRouteTree = TypedGoRoute<ClubsRoute>(
  path: AppPaths.clubs,
  routes: <TypedRoute<RouteData>>[
    TypedGoRoute<ClubsSearchRoute>(path: ClubsSearchRoute.segment),
    TypedGoRoute<ClubDetailRoute>(
      path: ClubDetailRoute.segment,
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<ClubAppliedRoute>(path: ClubAppliedRoute.segment),
        TypedGoRoute<ClubApplicationRoute>(path: ClubApplicationRoute.segment),
      ],
    ),
  ],
);

/// CLB-01 Kulüpler — Kulüpler sekmesinin kökü, `/clubs` (guard `A`).
final class ClubsRoute extends GoRouteData with $ClubsRoute, PlatformPageMixin {
  /// Sekme kökü rotası.
  const ClubsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ClubListView();
}

/// CLB-02 Arama — `/clubs/search` (guard `A`). CLB-01 arama düğmesi `go` ile
/// açar, geri CLB-01'e döner. Ekran paylaşılan yapraktır (PLAN §13.9):
/// `EventsSearchRoute` aynı view'ı "Etkinlikler" sekmesiyle açar.
final class ClubsSearchRoute extends GoRouteData
    with $ClubsSearchRoute, PlatformPageMixin {
  /// Kulüpler sekmesinden açılan arama.
  const ClubsSearchRoute();

  /// `/clubs` altındaki yol parçası.
  static const String segment = 'search';

  @override
  Widget build(BuildContext context, GoRouterState state) => const SearchView(
    scope: SearchScope.clubs,
    applicationSheetBuilder: joinApplicationSheetBuilder,
  );
}

/// Aramadaki kulüp kartının "Katıl" düğmesi için SHT-05 gövdesi: form
/// `features/clubs`'tadır, arama (`features/search`) onu içe aktaramaz —
/// rota (kompozisyon kökü) iki feature'ı burada bağlar.
Widget joinApplicationSheetBuilder(String clubId) =>
    JoinApplicationSheet(clubId: clubId);

/// CLB-03 Kulüp (+ FED-01 gönderiler sekmesi) — `/clubs/:clubId?tab=`.
///
/// Guard `A` (aktif oturum; `RouteAccessTable`). Kulübün içine özel sekmeler
/// (gönderiler, üyeler) rota düzeyinde korunmaz: ziyaretçi ekranı görür,
/// sekme kilitli bloğu gösterir (`screens-clubs.js:84`). Geçiş platform
/// varsayılanıdır (D-06); `go` ile açılır, geri CLB-01'e döner.
final class ClubDetailRoute extends GoRouteData
    with $ClubDetailRoute, PlatformPageMixin {
  /// [clubId] kulübünün sayfası; [tab] ilk açılan sekmedir.
  const ClubDetailRoute({required this.clubId, this.tab});

  /// `/clubs` altındaki yol parçası.
  static const String segment = ':${RouteAccessTable.clubIdParameter}';

  /// Kulüp kimliği (yol parametresi).
  final String clubId;

  /// İlk açılan sekme (`?tab=about|events|posts|members`); `null` ya da
  /// tanınmayan değer → hakkında.
  final ClubDetailTab? tab;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      ClubDetailView(clubId: clubId, tab: tab);
}

/// CLB-04 İsteğin iletildi — `/clubs/:clubId/applied`. CLB-03'ün alt
/// rotasıdır (guard `A`); başvuru gönderilince `go` ile açılır, geri kulübe
/// döner.
final class ClubAppliedRoute extends GoRouteData
    with $ClubAppliedRoute, PlatformPageMixin {
  /// [clubId] kulübüne yapılan başvurunun onay ekranı.
  const ClubAppliedRoute({required this.clubId});

  /// `/clubs/:clubId` altındaki yol parçası.
  static const String segment = 'applied';

  /// Kulüp kimliği (yol parametresi).
  final String clubId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      ClubAppliedView(clubId: clubId);
}

/// CLB-05 Başvuru durumu — `/clubs/:clubId/application`. CLB-03'ün alt
/// rotasıdır (guard `A`); `ClubCta` durum düğmesi ve başvuru bildirimleri
/// `go` ile açar (yığın: kulüp → başvuru durumu, navigation.md §4.1).
final class ClubApplicationRoute extends GoRouteData
    with $ClubApplicationRoute, PlatformPageMixin {
  /// [clubId] kulübündeki başvurunun durumu.
  const ClubApplicationRoute({required this.clubId});

  /// `/clubs/:clubId` altındaki yol parçası.
  static const String segment = 'application';

  /// Kulüp kimliği (yol parametresi).
  final String clubId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      ClubApplicationView(clubId: clubId);
}
