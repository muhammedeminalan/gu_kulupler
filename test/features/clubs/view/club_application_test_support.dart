// CLB-04 ve CLB-05 ekran testlerinin ortak düzeneği: demo veriden modeller,
// hazır `ClubApplicationState` örnekleri, sahte depoların tohumlanması ve
// ekranı gerçek ViewModel + go_router ile açan `pumpClubRoute`.
//
// İki kip vardır:
//
// * **Durum kipi** (içerik, cihaz matrisi, envanter, golden): ekran
//   `pumpApp` ile çizilir, ViewModel durumu `stateOverride` ile verilir
//   (okuma yapılmaz).
// * **Akış kipi** (aksiyon sonuçları): `pumpClubRoute` ekranı gerçek
//   ViewModel, sahte depolar ve yer tutucu hedef rotalarla açar; gezinme
//   `locationOf` ile okunur.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/club_application_state.dart';
import 'package:gu_kulupler/features/clubs/provider/club_application_view_model.dart';
import 'package:gu_kulupler/features/clubs/view/club_application_view.dart';
import 'package:gu_kulupler/features/clubs/view/club_applied_view.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_kulupler/product/service/permission_service.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../fakes/fake_auth_service.dart';
import '../../../fakes/fake_club_repository.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_membership_repository.dart';
import '../../../fakes/fake_permission_service.dart';
import '../../../fakes/register_fakes.dart';
import '../../../fixtures/club_model_fixtures.dart';
import '../../../fixtures/membership_model_fixtures.dart';
import '../../../fixtures/user_model_fixtures.dart';
import '../../../helpers/pump_app.dart';

/// Referans görüntülerin kulübü (`screens-actions.json` `params.id`).
const String kClubId = 'c06';

/// Oturumdaki kullanıcının e-postası (demo veri `u_mehmet`).
const String kEmail = 'mehmet.kaya@ogr.gumushane.edu.tr';

/// Demo verideki başvuru notu (`c06_u_mehmet`; CD-137'den beri
/// `private/contact` belgesindedir).
const String kNote = 'Gitar çalıyorum, jam seanslarına katılmak istiyorum.';

/// Akış kipinde ekrandan önce gösterilen boş başlangıç sayfası.
const String kStartPath = '/start';

/// Oturumdaki kullanıcı (`u_mehmet`).
final UserModel kUser = UserModelFixtures.byId('u_mehmet');

/// `c06` — Müzik ve Sahne Sanatları Kulübü: onay ister, başvuruya açık, not
/// zorunlu değil.
final ClubModel kClub = ClubModelFixtures.byId(kClubId);

/// `c06_u_mehmet` — bekleyen başvuru (6 Ekim 2026).
final MembershipModel kPending = MembershipModelFixtures.byId('c06_u_mehmet');

/// Yeniden başvurunun açılacağı an: sahte saatten 3,8 gün sonra (demo
/// verideki `retryAfter_rel_days`).
final DateTime kRetryAfter = kDefaultFakeNowUtc.add(
  const Duration(days: 3, hours: 19),
);

/// Reddedilmiş başvuru: neden "Kontenjan dolu", karar 3 gün önce.
MembershipModel rejectedMembership({
  DateTime? retryAfter,
  RejectReason? reason = RejectReason.quota,
  String? rejectNote,
  MembershipStatus status = MembershipStatus.rejected,
}) => MembershipModel(
  clubId: kPending.clubId,
  userId: kPending.userId,
  applicant: kPending.applicant,
  status: status,
  appliedAt: kPending.appliedAt,
  decidedAt: kDefaultFakeNowUtc.subtract(const Duration(days: 3)),
  decidedBy: 'u_p_c06',
  retryAfter: retryAfter,
  rejectReason: reason,
  rejectNote: rejectNote,
);

/// [status] durumundaki üyelik (bekleyen başvurudan türetilir).
MembershipModel membershipWith(MembershipStatus status) => kPending.copyWith(
  status: status,
  decidedAt: kDefaultFakeNowUtc.subtract(const Duration(days: 2)),
);

/// Beklemede: kulüp ve not okunmuş (referans görüntünün durumu).
final ClubApplicationState kPendingState = ClubApplicationState(
  club: kClub,
  membership: kPending,
  note: kNote,
  savedNote: kNote,
  showNotificationPrompt: true,
);

/// Reddedildi, bekleme süresi sürüyor.
final ClubApplicationState kRejectedWaitingState = ClubApplicationState(
  club: kClub,
  membership: rejectedMembership(
    retryAfter: kRetryAfter,
    rejectNote: 'Bu dönem kontenjanımız doldu; bahar döneminde bekleriz.',
  ),
);

/// Reddedildi, bekleme süresi dolmuş.
final ClubApplicationState kRejectedOpenState = ClubApplicationState(
  club: kClub,
  membership: rejectedMembership(
    retryAfter: kDefaultFakeNowUtc.subtract(const Duration(days: 1)),
  ),
);

/// Onaylandı (aktif üye).
final ClubApplicationState kApprovedState = ClubApplicationState(
  club: kClub,
  membership: membershipWith(MembershipStatus.active),
);

/// Başvuru yok (üyelik belgesi yok).
final ClubApplicationState kNoneState = ClubApplicationState(club: kClub);

/// Okunuyor (iskelet).
final ClubApplicationState kLoadingState = ClubApplicationState(
  membership: kPending,
  isFetching: true,
);

/// Okunamadı.
final ClubApplicationState kErrorState = ClubApplicationState(
  membership: kPending,
  isError: true,
);

/// `intl` tarih simgeleri (`AppBootstrap`'ın açılışta yaptığı).
Future<void> initDateFormats() async {
  await initializeDateFormatting('tr_TR');
  await initializeDateFormatting('en_GB');
}

/// ViewModel'in durumunu [state] ile sabitler (okuma yapılmaz).
List<Override> stateOverride(ClubApplicationState state) => [
  clubApplicationViewModelProvider(
    kClubId,
  ).overrideWithBuild((ref, notifier) => state),
];

/// Aktif oturum; [membership] verilirse `c06` üyeliğiyle.
SessionState sessionWith([MembershipModel? membership]) => SessionState(
  status: AuthStatus.active,
  uid: kUser.uid,
  user: kUser,
  onboardingSeen: true,
  memberships: {kClubId: ?membership},
);

FakeFeedbackService feedbackFake() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;
FakeClubRepository clubsFake() =>
    GetIt.I<ClubRepository>() as FakeClubRepository;
FakeMembershipRepository membershipsFake() =>
    GetIt.I<MembershipRepository>() as FakeMembershipRepository;
FakeConnectivityService connectivityFake() =>
    GetIt.I<ConnectivityService>() as FakeConnectivityService;
FakePermissionService permissionsFake() =>
    GetIt.I<PermissionService>() as FakePermissionService;

/// Yer tutucu hedef sayfa: yolunu gösterir.
class RouteStub extends StatelessWidget {
  const RouteStub(this.location, {super.key});

  final String location;

  @override
  Widget build(BuildContext context) => Scaffold(body: Text(location));
}

/// Router'ın bulunduğu konum (sorgu dahil).
String locationOf(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

/// [tester] ağacındaki sağlayıcı kapsayıcısı.
ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Navigator).first));

/// Oturumu [session] ile değiştirir (canlı üyelik akışının yerine).
void setSession(WidgetTester tester, SessionState session) =>
    containerOf(tester).read(sessionViewModelProvider.notifier).state = session;

/// Akış kipi: sahteleri tohumlar ve [location] konumundaki ekranı gerçek
/// ViewModel ile açar.
///
/// Rota ağacı uygulamadaki gibidir: `/clubs` → `/clubs/:clubId` →
/// `applied` / `application` (CLB-04 ve CLB-05 gerçek, diğerleri yer
/// tutucu); `/profile` ve `/not-found` yer tutucudur. Sahteler `pumpApp`
/// tarafından sıfırlandığı için ekran, tohumlamadan **sonra** açılır
/// ([kStartPath] → [location]).
///
/// [club] `null` ise kulüp yazılmaz (kulüp yok); [membership] verilirse
/// üyelik ve [note] notlu iletişim belgesi yazılır. [session] verilmezse
/// oturum [membership] ile kurulur. [seed] ekran açılmadan önce çağrılır;
/// [overrides] ek sağlayıcı ezmeleridir (ör. `stateOverride`).
Future<GoRouter> pumpClubRoute(
  WidgetTester tester,
  String location, {
  ClubModel? club,
  bool withClub = true,
  MembershipModel? membership,
  String note = kNote,
  SessionState? session,
  String? email = kEmail,
  void Function()? seed,
  Locale locale = const Locale('tr'),
  List<Override> overrides = const [],
}) async {
  GoRouter? created;
  await tester.pumpAppRouter(
    routerOf: (_) => created ??= GoRouter(
      initialLocation: kStartPath,
      routes: [
        GoRoute(
          path: kStartPath,
          builder: (_, _) => const RouteStub(kStartPath),
        ),
        GoRoute(
          path: '/clubs',
          builder: (_, _) => const RouteStub('/clubs'),
          routes: [
            GoRoute(
              path: ':clubId',
              builder: (_, state) =>
                  RouteStub('/clubs/${state.pathParameters['clubId']}'),
              routes: [
                GoRoute(
                  path: 'applied',
                  builder: (_, state) => ClubAppliedView(
                    clubId: state.pathParameters['clubId']!,
                  ),
                ),
                GoRoute(
                  path: 'application',
                  builder: (_, state) => ClubApplicationView(
                    clubId: state.pathParameters['clubId']!,
                  ),
                ),
              ],
            ),
          ],
        ),
        for (final path in ['/profile', '/not-found'])
          GoRoute(path: path, builder: (_, _) => RouteStub(path)),
      ],
    ),
    locale: locale,
    overrides: [
      sessionViewModelProvider.overrideWithBuild(
        (_, _) => session ?? sessionWith(membership),
      ),
      ...overrides,
    ],
  );
  final router = created!;
  addTearDown(router.dispose);

  (GetIt.I<AuthService>() as FakeAuthService).currentUser = AuthUserInfo(
    uid: kUser.uid,
    email: email,
    emailVerified: true,
  );
  if (withClub) clubsFake().clubs[kClubId] = club ?? kClub;
  if (membership != null) {
    membershipsFake().put(membership, email: kEmail, note: note);
  }
  seed?.call();

  router.go(location);
  await tester.pumpAndSettle();
  // Açılış okumaları çağrı günlüğünü kirletmesin.
  membershipsFake().resetFake();
  clubsFake().resetFake();
  return router;
}
