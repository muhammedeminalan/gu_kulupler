part of 'shell_route.dart';

// T-11 dal kökünü kurdu; T-38 kök ekranı (ADM-01) bağladı; T-39 kulüpler
// (ADM-02) ile kulüp oluştur / düzenle (ADM-03) rotalarını ekler; T-40
// şikayetler (ADM-04). Kalan alt rotalar PLAN §13.3.6 tablosundaki task'ta
// (T-41).

/// Admin dalının rota ağacı (navigation.md §2.6). Alt rotalar sahip
/// task'larında bu ağaca eklenir.
const TypedGoRoute<AdminRoute> adminRouteTree = TypedGoRoute<AdminRoute>(
  path: AppPaths.admin,
  routes: <TypedRoute<RouteData>>[
    TypedGoRoute<AdminClubsRoute>(
      path: AdminClubsRoute.segment,
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<AdminClubFormRoute>(path: AdminClubFormRoute.segment),
        TypedGoRoute<AdminClubEditRoute>(path: AdminClubEditRoute.segment),
      ],
    ),
    TypedGoRoute<AdminReportsRoute>(path: AdminReportsRoute.segment),
  ],
);

/// Admin sekmesinin kökü — `/admin` (ADM-01 `AdminView`; guard `S`).
final class AdminRoute extends GoRouteData with $AdminRoute, PlatformPageMixin {
  /// Sekme kökü rotası.
  const AdminRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const AdminView();
}

/// ADM-02 Kulüpler — `/admin/clubs?tab=`. ADM-01'in alt rotasıdır (guard
/// `S`: yalnızca süper admin, router'da). ADM-01 kulüp göstergeleri ve
/// `AdminSegmentBar` "Kulüpler" (W-45) `go` ile açar; geri ADM-01'e döner.
final class AdminClubsRoute extends GoRouteData
    with $AdminClubsRoute, PlatformPageMixin {
  /// Kulüp listesi; [tab] ilk açılan sekme.
  const AdminClubsRoute({this.tab});

  /// `/admin` altındaki yol parçası.
  static const String segment = 'clubs';

  /// İlk açılan sekme (`?tab=active|suspended`); `null` ya da tanınmayan
  /// değer → etkin kulüpler.
  final AdminClubsTab? tab;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      AdminClubsView(tab: tab);
}

/// ADM-03 Kulüp oluştur — `/admin/clubs/new`. ADM-02'nin alt rotasıdır
/// (guard `S`). Düzenleme aynı ekranı [AdminClubEditRoute] ile açar (iki
/// rota sınıfı, tek `AdminClubFormView` — CD-54). ADM-02 "+" (`ADM-02.create`)
/// `go` ile açar; geri ADM-02'ye döner.
final class AdminClubFormRoute extends GoRouteData
    with $AdminClubFormRoute, PlatformPageMixin {
  /// Yeni kulüp formu.
  const AdminClubFormRoute();

  /// `/admin/clubs` altındaki yol parçası; sabit `new` parçası kulüp
  /// kimliğiyle çakışmaz (düzenleme `:clubId/edit`).
  static const String segment = 'new';

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const AdminClubFormView();
}

/// ADM-03 Kulüp düzenle — `/admin/clubs/:clubId/edit`. ADM-02'nin alt
/// rotasıdır (guard `S`). [AdminClubFormRoute] ile aynı `AdminClubFormView`'u
/// [clubId] ile açar (CD-54). ADM-02 satır menüsü "Düzenle" `go` ile açar;
/// geri ADM-02'ye döner.
final class AdminClubEditRoute extends GoRouteData
    with $AdminClubEditRoute, PlatformPageMixin {
  /// [clubId] kulübünün düzenleme formu.
  const AdminClubEditRoute({required this.clubId});

  /// `/admin/clubs` altındaki yol parçası.
  static const String segment = ':clubId/edit';

  /// Düzenlenen kulübün kimliği (yol parametresi).
  final String clubId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      AdminClubFormView(clubId: clubId);
}

/// ADM-04 Şikayetler — `/admin/reports?tab=&reportId=`. ADM-01'in alt
/// rotasıdır (guard `S`: yalnızca süper admin, router'da). ADM-01 "Açık
/// şikayet" göstergesi / bekleyen iş ve `AdminSegmentBar` "Şikayetler"
/// (W-46) `go` ile açar; `new_report` bildirimi (W-29) [reportId] ile açar.
/// Geri ADM-01'e döner.
final class AdminReportsRoute extends GoRouteData
    with $AdminReportsRoute, PlatformPageMixin {
  /// Şikayet listesi; [tab] ilk açılan sekme, [reportId] açılışta SHT-26'sı
  /// açılacak grup.
  const AdminReportsRoute({
    this.tab,
    @TypedQueryParameter<String>(name: reportIdQuery) this.reportId,
  });

  /// `/admin` altındaki yol parçası.
  static const String segment = 'reports';

  /// [reportId] sorgu parametresinin adı (`?reportId=`; navigation.md §2.6,
  /// §4.1).
  static const String reportIdQuery = 'reportId';

  /// İlk açılan sekme (`?tab=open|resolved`); `null` ya da tanınmayan değer
  /// → açık şikayetler.
  final AdminReportsTab? tab;

  /// Açılışta `AppDurations.postNavigationSheetDelay` sonra SHT-26'sı açılan
  /// şikayet grubunun anahtarı `{targetType}_{targetId}`
  /// (`FirestoreIds.reportGroupKey`; bildirimin `refs.reportId` değeri —
  /// belge kimliği değildir). `null` → sheet açılmaz.
  final String? reportId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      AdminReportsView(tab: tab, reportId: reportId);
}
