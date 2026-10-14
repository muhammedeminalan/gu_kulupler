part of 'shell_route.dart';

// T-11 dal kökünü, T-16 kulüp detayı ile başvuru rotalarını, T-17 sekme
// kökünün gerçek ekranını ve aramayı, T-18 üye listesi ile kullanıcı
// profilini, T-20 gönderi detayını, T-21 gönderi oluşturmayı, T-31 yönetim
// panelini ve faaliyet geçmişini, T-32 başvuru yönetimini, T-33 üye
// yönetimini, T-34 etkinlik yönetimini ve formunu kurar; kalan alt rotalar
// PLAN §13.3.2
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
    TypedGoRoute<ClubUserProfileRoute>(path: ClubUserProfileRoute.segment),
    TypedGoRoute<ClubDetailRoute>(
      path: ClubDetailRoute.segment,
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<ClubAppliedRoute>(path: ClubAppliedRoute.segment),
        TypedGoRoute<ClubApplicationRoute>(path: ClubApplicationRoute.segment),
        TypedGoRoute<ClubMembersRoute>(path: ClubMembersRoute.segment),
        TypedGoRoute<PostDetailRoute>(path: PostDetailRoute.segment),
        TypedGoRoute<ComposeRoute>(path: ComposeRoute.segment),
        TypedGoRoute<ManageRoute>(
          path: ManageRoute.segment,
          routes: <TypedRoute<RouteData>>[
            TypedGoRoute<ManageApplicationsRoute>(
              path: ManageApplicationsRoute.segment,
            ),
            TypedGoRoute<ManageMembersRoute>(
              path: ManageMembersRoute.segment,
            ),
            TypedGoRoute<ManageEventsRoute>(
              path: ManageEventsRoute.segment,
              routes: <TypedRoute<RouteData>>[
                TypedGoRoute<EventFormRoute>(path: EventFormRoute.segment),
                TypedGoRoute<EventEditRoute>(path: EventEditRoute.segment),
              ],
            ),
            TypedGoRoute<ActivityLogRoute>(path: ActivityLogRoute.segment),
          ],
        ),
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
/// varsayılanıdır (D-06); `go` ile açılır, geri CLB-01'e döner. Etkinlik
/// kartından katılım (SHT-12 / DLG-15) `features/events`'tedir
/// ([runEventJoinFlow]); rota iki feature'ı burada bağlar.
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
  Widget build(BuildContext context, GoRouterState state) => ClubDetailView(
    clubId: clubId,
    tab: tab,
    commentsSheetBuilder: commentsSheetBuilder,
    eventJoinFlow: runEventJoinFlow,
  );
}

/// Akıştaki gönderi kartının yorum düğmesi için SHT-09 gövdesi: sayfa
/// `features/feed`'dedir, akış (FED-01, `features/clubs`) onu içe aktaramaz —
/// rota (kompozisyon kökü) iki feature'ı burada bağlar.
Widget commentsSheetBuilder(String clubId, String postId) =>
    CommentsSheet(clubId: clubId, postId: postId);

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

/// CLB-06 Üyeler — `/clubs/:clubId/members`. CLB-03'ün alt rotasıdır (guard
/// `üye`: kulübün içini görmeyen kulüp sayfasına yönlenir —
/// `RouteAccessTable`). CLB-03 "Üye listesi" ve SHT-06 "Üyeler" `go` ile
/// açar, geri kulübe döner.
final class ClubMembersRoute extends GoRouteData
    with $ClubMembersRoute, PlatformPageMixin {
  /// [clubId] kulübünün üye listesi.
  const ClubMembersRoute({required this.clubId});

  /// `/clubs/:clubId` altındaki yol parçası.
  static const String segment = 'members';

  /// Kulüp kimliği (yol parametresi).
  final String clubId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      ClubMembersView(clubId: clubId);
}

/// FED-02 Gönderi — `/clubs/:clubId/posts/:postId`. CLB-03'ün alt rotasıdır
/// (guard `üye`: kulübün içini görmeyen kulüp sayfasına yönlenir —
/// `RouteAccessTable`). Akıştaki gönderi kartı, SHT-09 "Tümünü gör" ve duyuru
/// bildirimi `go` ile açar, geri kulübe döner.
final class PostDetailRoute extends GoRouteData
    with $PostDetailRoute, PlatformPageMixin {
  /// [clubId] kulübünün [postId] gönderisi.
  const PostDetailRoute({required this.clubId, required this.postId});

  /// `/clubs/:clubId` altındaki yol parçası.
  static const String segment = 'posts/:postId';

  /// Kulüp kimliği (yol parametresi).
  final String clubId;

  /// Gönderi kimliği (yol parametresi).
  final String postId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      PostDetailView(clubId: clubId, postId: postId);
}

/// FED-03 Yeni gönderi — `/clubs/:clubId/compose?edit=`. CLB-03'ün alt
/// rotasıdır (guard `M`: yalnızca yönetim kurulu / başkan; danışman yönetim
/// paneline, diğerleri kulüp sayfasına yönlenir — `RouteAccessTable`).
/// CLB-03 / FED-01 "yazı oluştur" ve SHT-08 "Düzenle" (`edit`) `go` ile açar,
/// geri kulübe döner.
final class ComposeRoute extends GoRouteData
    with $ComposeRoute, PlatformPageMixin {
  /// [clubId] kulübünde yeni gönderi; [edit] verilirse o gönderinin
  /// düzenlemesi.
  const ComposeRoute({required this.clubId, this.edit});

  /// `/clubs/:clubId` altındaki yol parçası.
  static const String segment = 'compose';

  /// Kulüp kimliği (yol parametresi).
  final String clubId;

  /// Düzenlenen gönderinin kimliği (sorgu parametresi `?edit=`); yeni
  /// gönderide `null`.
  final String? edit;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      ComposeView(clubId: clubId, editPostId: edit);
}

/// MGT-01 Yönetim paneli — `/clubs/:clubId/manage`. CLB-03'ün alt rotasıdır
/// (guard `V`: o kulüpte yönetici ya da danışman; diğerleri kulüp sayfasına
/// TST-X18 ile yönlenir — `RouteAccessTable`). CLB-03 "Yönetim paneli",
/// SHT-18 ve PRF-01 yönetilen kulüp `go` ile açar, geri kulübe döner.
/// Danışman salt okunur görür (Q-09; yazma eylemleri TST-26).
final class ManageRoute extends GoRouteData
    with $ManageRoute, PlatformPageMixin {
  /// [clubId] kulübünün yönetim paneli.
  const ManageRoute({required this.clubId});

  /// `/clubs/:clubId` altındaki yol parçası.
  static const String segment = 'manage';

  /// Kulüp kimliği (yol parametresi).
  final String clubId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      ManageView(clubId: clubId);
}

/// MGT-02 Başvurular — `/clubs/:clubId/manage/applications?tab=&applicant=`.
/// MGT-01'in alt rotasıdır (guard `V`: yönetici ya da danışman; danışman
/// salt okunur görür, yazma eylemleri TST-26 — `RouteAccessTable`). MGT-01
/// "Başvurular" (W-36), faaliyet satırı (W-95) ve `application_received`
/// bildirimi (W-28) `go` ile açar, geri panele döner.
final class ManageApplicationsRoute extends GoRouteData
    with $ManageApplicationsRoute, PlatformPageMixin {
  /// [clubId] kulübünün başvuruları; [tab] ilk açılan sekme, [applicantId]
  /// açılıştan `AppDurations.postNavigationSheetDelay` sonra SHT-19'u açılan
  /// başvuran.
  const ManageApplicationsRoute({
    required this.clubId,
    this.tab,
    @TypedQueryParameter<String>(name: applicantQuery) this.applicantId,
  });

  /// `/clubs/:clubId/manage` altındaki yol parçası.
  static const String segment = 'applications';

  /// Açılışta SHT-19'u açılan başvuranın sorgu parametresi adı
  /// (`?applicant=`).
  static const String applicantQuery = 'applicant';

  /// Kulüp kimliği (yol parametresi).
  final String clubId;

  /// İlk açılan sekme (`?tab=pending|approved|rejected`); `null` ya da
  /// tanınmayan değer → bekleyenler.
  final ApplicationsTab? tab;

  /// Başvuru detayı (SHT-19) açılacak başvuranın kullanıcı kimliği
  /// (`?applicant=`, bildirim `refs.applicantId` — W-28); `null` → sheet
  /// açılmaz.
  final String? applicantId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      ManageApplicationsView(
        clubId: clubId,
        tab: tab,
        applicantId: applicantId,
      );
}

/// MGT-03 Üye yönetimi — `/clubs/:clubId/manage/members?transfer=`. MGT-01'in
/// alt rotasıdır (guard `V`: yönetici ya da danışman; danışman salt okunur
/// görür, yazma eylemleri TST-26 — `RouteAccessTable`). MGT-01 "Üyeler"
/// (W-37) `go` ile açar, geri panele döner. Başkanlık devri girişleri —
/// DLG-09 "Başkanlığı devret" (W-14) ve SET-03 başkan engeli (W-34) —
/// [transfer] ile açar: ekran açılınca SHT-25 (devir) açılır.
final class ManageMembersRoute extends GoRouteData
    with $ManageMembersRoute, PlatformPageMixin {
  /// [clubId] kulübünün üyeleri; [transfer] `true` ise açılışta SHT-25.
  const ManageMembersRoute({required this.clubId, this.transfer = false});

  /// `/clubs/:clubId/manage` altındaki yol parçası.
  static const String segment = 'members';

  /// Kulüp kimliği (yol parametresi).
  final String clubId;

  /// Açılışta başkanlık devri sayfası (SHT-25) açılsın mı (`?transfer=true`;
  /// W-14, W-34). Varsayılan `false` yola yazılmaz.
  final bool transfer;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      ManageMembersView(clubId: clubId, openTransfer: transfer);
}

/// MGT-04 Etkinlik yönetimi — `/clubs/:clubId/manage/events?tab=`. MGT-01'in
/// alt rotasıdır (guard `V`: yönetici ya da danışman; danışman salt okunur
/// görür, yazma eylemleri TST-26 — `RouteAccessTable`). MGT-01 hızlı eylemi
/// "Etkinlikler" (W-38) `go` ile açar, geri panele döner.
final class ManageEventsRoute extends GoRouteData
    with $ManageEventsRoute, PlatformPageMixin {
  /// [clubId] kulübünün etkinlikleri; [tab] ilk açılan sekme.
  const ManageEventsRoute({required this.clubId, this.tab});

  /// `/clubs/:clubId/manage` altındaki yol parçası.
  static const String segment = 'events';

  /// Kulüp kimliği (yol parametresi).
  final String clubId;

  /// İlk açılan sekme (`?tab=published|draft|past|cancelled`); `null` ya da
  /// tanınmayan değer → yayındakiler.
  final ManageEventsTab? tab;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      ManageEventsView(clubId: clubId, tab: tab);
}

/// MGT-05 Etkinlik oluştur — `/clubs/:clubId/manage/events/new`. MGT-04'ün
/// alt rotasıdır (guard `M`: yalnızca kulüp yönetimi). Düzenleme aynı
/// ekranı [EventEditRoute] ile açar (iki rota sınıfı, tek `EventFormView` —
/// CD-54). CLB-03 "Etkinlik oluştur" (W-17), MGT-01 hızlı eylemi (W-38) ve
/// MGT-04 "+" `go` ile açar; geri MGT-04'e döner.
final class EventFormRoute extends GoRouteData
    with $EventFormRoute, PlatformPageMixin {
  /// [clubId] kulübünde yeni etkinlik formu.
  const EventFormRoute({required this.clubId});

  /// `/clubs/:clubId/manage/events` altındaki yol parçası; sabit `new`
  /// parçası etkinlik kimliğiyle çakışmaz (düzenleme `:eventId/edit`).
  static const String segment = 'new';

  /// Kulüp kimliği (yol parametresi).
  final String clubId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      EventFormView(clubId: clubId);
}

/// MGT-05 Etkinlik düzenle — `/clubs/:clubId/manage/events/:eventId/edit`.
/// MGT-04'ün alt rotasıdır (guard `M`). [EventFormRoute] ile aynı
/// `EventFormView`'u [eventId] ile açar (CD-54). SHT-23 "Düzenle" ve EVT-02
/// yönetici "Düzenle" (W-27) `go` ile açar; geri MGT-04'e döner.
final class EventEditRoute extends GoRouteData
    with $EventEditRoute, PlatformPageMixin {
  /// [clubId] kulübünün [eventId] etkinliğinin düzenleme formu.
  const EventEditRoute({required this.clubId, required this.eventId});

  /// `/clubs/:clubId/manage/events` altındaki yol parçası.
  static const String segment = ':eventId/edit';

  /// Kulüp kimliği (yol parametresi).
  final String clubId;

  /// Düzenlenen etkinliğin kimliği (yol parametresi).
  final String eventId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      EventFormView(clubId: clubId, eventId: eventId);
}

/// MGT-10 Faaliyet geçmişi — `/clubs/:clubId/manage/activity`. MGT-01'in alt
/// rotasıdır (guard `V`); MGT-01 "Son hareketler → Tümü" `go` ile açar, geri
/// panele döner.
final class ActivityLogRoute extends GoRouteData
    with $ActivityLogRoute, PlatformPageMixin {
  /// [clubId] kulübünün faaliyet geçmişi.
  const ActivityLogRoute({required this.clubId});

  /// `/clubs/:clubId/manage` altındaki yol parçası.
  static const String segment = 'activity';

  /// Kulüp kimliği (yol parametresi).
  final String clubId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      ActivityLogView(clubId: clubId);
}

/// CLB-07 Profil — `/clubs/user/:userId?clubId=` (guard `A`). `/clubs`'un
/// doğrudan alt rotasıdır: geri CLB-01'e döner. Ekran paylaşılan yapraktır
/// (PLAN §13.9): `BlockedUserProfileRoute` (T-28) ve `AdminUserProfileRoute`
/// (T-41) aynı view'ı açar.
final class ClubUserProfileRoute extends GoRouteData
    with $ClubUserProfileRoute, PlatformPageMixin {
  /// [userId] kullanıcısının profili; [clubId] açıldığı kulüp bağlamıdır.
  const ClubUserProfileRoute({
    required this.userId,
    @TypedQueryParameter<String>(name: clubIdQuery) this.clubId,
  });

  /// `/clubs` altındaki yol parçası; sabit `user` parçası `:clubId`
  /// kalıbından önce eşleşir.
  static const String segment = 'user/:userId';

  /// Kulüp bağlamının sorgu parametresi adı (`?clubId=`).
  static const String clubIdQuery = 'clubId';

  /// Profili açılan kullanıcının kimliği (yol parametresi).
  final String userId;

  /// Açıldığı kulüp (`?clubId=`, üyelik bağlamı); yoksa `null`.
  final String? clubId;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      UserProfileView(userId: userId, clubId: clubId);
}
