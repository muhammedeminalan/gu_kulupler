part of 'shell_route.dart';

// T-11 dal kökünü kurdu; T-38 kök ekranı (ADM-01) bağladı; T-39 kulüpler
// (ADM-02) ile kulüp oluştur / düzenle (ADM-03) rotalarını ekler; T-40
// şikayetler (ADM-04); T-41 kullanıcılar (ADM-05) ile paylaşılan kullanıcı
// profili (CLB-07) — admin dalı tamam (PLAN §13.3.6).
//
// Tasarım hataları turu (kullanıcı kararı 2026-10-16): ADM-01 / 02 / 04 / 05
// tek sayfadır — `AdminRoute` (`/admin?tab=`), bölmeli geçiş (`AdminSegment
// Bar`) yığını değiştirmez, alt çubuk görünür. Eski `/admin/clubs`,
// `/admin/reports`, `/admin/users` rotaları kaldırıldı; alt sayfalar (ADM-03,
// admin CLB-07) doğrudan kökün altındadır (geri → aynı bölme).

/// Admin dalının rota ağacı (navigation.md §2.6).
const TypedGoRoute<AdminRoute> adminRouteTree = TypedGoRoute<AdminRoute>(
  path: AppPaths.admin,
  routes: <TypedRoute<RouteData>>[
    TypedGoRoute<AdminClubFormRoute>(path: AdminClubFormRoute.segment),
    TypedGoRoute<AdminClubEditRoute>(path: AdminClubEditRoute.segment),
    TypedGoRoute<AdminUserProfileRoute>(path: AdminUserProfileRoute.segment),
  ],
);

/// Admin sekmesinin kökü — `/admin?tab=&clubsTab=&reportsTab=&reportId=
/// &filter=` (ADM-01 Genel · ADM-02 Kulüpler · ADM-04 Şikayetler · ADM-05
/// Kullanıcılar tek sayfa, `AdminView`; guard `S`: yalnızca süper admin,
/// router'da).
///
/// Sorgu parametreleri **komuttur**: değişen ve dolu değer uygulanır (bölme,
/// alt sekme, süzgeç, SHT-26), boş değer sayfanın hâlini değiştirmez — alt
/// sayfaya (`go`) geçerken ebeveyn sorgusuz kurulur ve geri dönüşte aynı
/// bölme açık kalır. Bölme seçimi sayfa içinden de bu rotaya `go` eder
/// (adres seçimi yansıtır).
final class AdminRoute extends GoRouteData with $AdminRoute, PlatformPageMixin {
  /// Admin kökü; [tab] açılacak bölme, diğerleri o bölmenin açılış hâli.
  const AdminRoute({
    this.tab,
    @TypedQueryParameter<AdminClubsTab>(name: clubsTabQuery) this.clubsTab,
    @TypedQueryParameter<AdminReportsTab>(name: reportsTabQuery)
    this.reportsTab,
    @TypedQueryParameter<String>(name: reportIdQuery) this.reportId,
    this.filter,
  });

  /// [clubsTab] sorgu parametresinin adı (`?clubsTab=`).
  static const String clubsTabQuery = 'clubsTab';

  /// [reportsTab] sorgu parametresinin adı (`?reportsTab=`).
  static const String reportsTabQuery = 'reportsTab';

  /// [reportId] sorgu parametresinin adı (`?reportId=`; navigation.md §2.6,
  /// §4.1).
  static const String reportIdQuery = 'reportId';

  /// Açılacak bölme (`?tab=overview|clubs|reports|users`); `null` ya da
  /// tanınmayan değer → son seçili bölme (ilk açılışta genel bakış).
  final AdminTab? tab;

  /// ADM-02'nin açılacak sekmesi (`?clubsTab=active|suspended`).
  final AdminClubsTab? clubsTab;

  /// ADM-04'ün açılacak sekmesi (`?reportsTab=open|resolved`).
  final AdminReportsTab? reportsTab;

  /// ADM-04 açılışında `AppDurations.postNavigationSheetDelay` sonra SHT-26'sı
  /// açılan şikayet grubunun anahtarı `{targetType}_{targetId}`
  /// (`FirestoreIds.reportGroupKey`; `new_report` bildiriminin
  /// `refs.reportId` değeri — belge kimliği değildir). `null` → sheet
  /// açılmaz.
  final String? reportId;

  /// ADM-05'in seçilecek süzgeci (`?filter=all|managers|suspended`).
  final AdminUsersFilter? filter;

  @override
  Widget build(BuildContext context, GoRouterState state) => AdminView(
    tab: tab,
    clubsTab: clubsTab,
    reportsTab: reportsTab,
    reportId: reportId,
    filter: filter,
  );
}

/// ADM-03 Kulüp oluştur — `/admin/clubs/new`. Admin kökünün alt rotasıdır
/// (guard `S`). Düzenleme aynı ekranı [AdminClubEditRoute] ile açar (iki
/// rota sınıfı, tek `AdminClubFormView` — CD-54). ADM-02 "+"
/// (`ADM-02.create`) `go` ile açar; geri admin köküne (Kulüpler bölmesi
/// açık) döner.
final class AdminClubFormRoute extends GoRouteData
    with $AdminClubFormRoute, PlatformPageMixin {
  /// Yeni kulüp formu.
  const AdminClubFormRoute();

  /// `/admin` altındaki yol parçası; sabit `new` parçası kulüp kimliğiyle
  /// çakışmaz (düzenleme `clubs/:clubId/edit`).
  static const String segment = 'clubs/new';

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const AdminClubFormView();
}

/// ADM-03 Kulüp düzenle — `/admin/clubs/:clubId/edit`. Admin kökünün alt
/// rotasıdır (guard `S`). [AdminClubFormRoute] ile aynı `AdminClubFormView`'u
/// [clubId] ile açar (CD-54). ADM-02 satır menüsü "Düzenle" `go` ile açar;
/// geri admin köküne (Kulüpler bölmesi açık) döner.
final class AdminClubEditRoute extends GoRouteData
    with $AdminClubEditRoute, PlatformPageMixin {
  /// [clubId] kulübünün düzenleme formu.
  const AdminClubEditRoute({required this.clubId});

  /// `/admin` altındaki yol parçası.
  static const String segment = 'clubs/:clubId/edit';

  /// Düzenlenen kulübün kimliği (yol parametresi).
  final String clubId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      AdminClubFormView(clubId: clubId);
}

/// CLB-07 Kullanıcı profili (paylaşılan) — `/admin/users/:userId`. Admin
/// kökünün alt rotasıdır (guard `S`). ADM-05 satırı / "Profili gör" menüsü
/// `go` ile açar; geri admin köküne (Kullanıcılar bölmesi açık) döner. View
/// `ClubUserProfileRoute` ve `BlockedUserProfileRoute` ile paylaşılan
/// `UserProfileView`'dır (kulüp bağlamı yok).
final class AdminUserProfileRoute extends GoRouteData
    with $AdminUserProfileRoute, PlatformPageMixin {
  /// [userId] kullanıcısının profili.
  const AdminUserProfileRoute({required this.userId});

  /// `/admin` altındaki yol parçası.
  static const String segment = 'users/:userId';

  /// Profili açılan kullanıcının kimliği (yol parametresi).
  final String userId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      UserProfileView(userId: userId);
}
