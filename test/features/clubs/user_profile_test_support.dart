// CLB-07 testlerinin ortak düzeneği: demo veriden modeller (referans
// görüntünün kişileri — bakan `u_burak`, profil `u001`, açılış kulübü `c03`,
// ortak kulüp `c01`), hazır `UserProfileState` örnekleri, sahte depoların
// tohumlanması ve ekranı gerçek ViewModel + go_router ile açan
// `pumpProfileRoute`.
//
// İki kip vardır:
//
// * **Durum kipi** (içerik, cihaz matrisi, envanter, golden): ekran `pumpApp`
//   ile çizilir, ViewModel durumu `stateOverride` ile verilir (okuma
//   yapılmaz).
// * **Akış kipi** (aksiyon sonuçları): `pumpProfileRoute` ekranı gerçek
//   ViewModel, sahte depolar ve yer tutucu hedef rotalarla açar; gezinme
//   `locationOf` ile okunur.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/user_profile_state.dart';
import 'package:gu_kulupler/features/clubs/provider/user_profile_view_model.dart';
import 'package:gu_kulupler/features/clubs/view/user_profile_view.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';

import '../../fakes/fake_auth_service.dart';
import '../../fakes/fake_block_repository.dart';
import '../../fakes/fake_club_repository.dart';
import '../../fakes/fake_connectivity_service.dart';
import '../../fakes/fake_feedback_service.dart';
import '../../fakes/fake_membership_repository.dart';
import '../../fakes/fake_report_repository.dart';
import '../../fakes/fake_user_repository.dart';
import '../../fixtures/club_model_fixtures.dart';
import '../../fixtures/membership_model_fixtures.dart';
import '../../fixtures/user_model_fixtures.dart';
import '../../helpers/pump_app.dart';

/// Profili açılan kullanıcı (`screens-actions.json` `params.id`).
const String kUserId = 'u001';

/// Açılış kulübü (`params.clubId`): bakan başkanıdır, kullanıcı üyesi değil.
const String kClubId = 'c03';

/// Ortak kulüp: ikisi de aktif üyedir.
const String kSharedClubId = 'c01';

/// Bakanın e-postası (demo veri `u_burak`).
const String kViewerEmail = 'burak.sahin@ogr.gumushane.edu.tr';

/// Akış kipinde ekrandan önce gösterilen boş başlangıç sayfası.
const String kStartPath = '/start';

/// Akış kipinde profilin konumu (kulüp bağlamıyla).
const String kProfileLocation = '/clubs/user/$kUserId?clubId=$kClubId';

/// Oturumdaki kullanıcı (`u_burak` — `c03` başkanı, `c01` üyesi).
final UserModel kViewer = UserModelFixtures.byId('u_burak');

/// Profili açılan kullanıcı (`u001` — Yiğit Kılıç, `c01` üyesi).
final UserModel kUser = UserModelFixtures.byId(kUserId);

/// `c01` — Yazılım ve Yapay Zekâ Topluluğu.
final ClubModel kSharedClub = ClubModelFixtures.byId(kSharedClubId);

/// Bakanın üyelikleri.
final MembershipModel kViewerInShared = MembershipModelFixtures.byId(
  'c01_u_burak',
);
final MembershipModel kViewerInContext = MembershipModelFixtures.byId(
  'c03_u_burak',
);

/// Kullanıcının ortak kulüpteki üyeliği (aktif, üye).
final MembershipModel kUserInShared = MembershipModelFixtures.byId('c01_u001');

/// Görünür profil — referans görüntünün durumu: bölüm · sınıf + bir ortak
/// kulüp, rozet yok.
final UserProfileState kVisibleState = UserProfileState(
  user: kUser,
  sharedClubIds: const [kSharedClubId],
  sharedClubs: [kSharedClub],
);

/// Gizli profil: ortak kulüp yok (D-29).
final UserProfileState kPrivateState = UserProfileState(
  user: kUser,
  isHiddenByPrivacy: true,
);

/// Görünür profil, kullanıcı engelli (üstte uyarı bandı).
final UserProfileState kBlockedState = kVisibleState.copyWith(isBlocked: true);

/// Rozetli ve biyografili görünür profil.
final UserProfileState kRichState = UserProfileState(
  user: kViewer,
  sharedClubIds: const [kClubId, kSharedClubId],
  sharedClubs: [ClubModelFixtures.byId(kClubId), kSharedClub],
  roles: const [ClubRole.president, ClubRole.board, ClubRole.advisor],
  isSelf: true,
  isSuperAdmin: true,
);

/// Silinmiş (anonimleştirilmiş) kullanıcı.
final UserProfileState kDeletedState = UserProfileState(
  user: kUser.copyWith(status: UserStatus.deleted, isDeleted: true),
);

/// Okunuyor (iskelet).
const UserProfileState kLoadingState = UserProfileState(isFetching: true);

/// Okunamadı.
const UserProfileState kErrorState = UserProfileState(isError: true);

/// Ekranın ViewModel sağlayıcısı (referans parametreleriyle).
UserProfileViewModelProvider profileProvider({
  String userId = kUserId,
  String? clubId = kClubId,
}) => userProfileViewModelProvider(userId, clubId: clubId);

/// ViewModel'in durumunu [state] ile sabitler (okuma yapılmaz).
List<Override> stateOverride(UserProfileState state) => [
  profileProvider().overrideWithBuild((ref, notifier) => state),
];

/// Aktif oturum: bakan `u_burak`. [memberships] verilmezse `c01` üyeliği ve
/// `c03` başkanlığıyla.
SessionState viewerSession({
  List<MembershipModel>? memberships,
  bool isSuperAdmin = false,
  Set<String> blockedUserIds = const {},
}) => SessionState(
  status: AuthStatus.active,
  uid: kViewer.uid,
  user: kViewer,
  isSuperAdmin: isSuperAdmin,
  onboardingSeen: true,
  memberships: {
    for (final membership in memberships ?? [kViewerInShared, kViewerInContext])
      membership.clubId: membership,
  },
  blockedUserIds: blockedUserIds,
);

FakeFeedbackService feedbackFake() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;
FakeUserRepository usersFake() =>
    GetIt.I<UserRepository>() as FakeUserRepository;
FakeClubRepository clubsFake() =>
    GetIt.I<ClubRepository>() as FakeClubRepository;
FakeMembershipRepository membershipsFake() =>
    GetIt.I<MembershipRepository>() as FakeMembershipRepository;
FakeBlockRepository blocksFake() =>
    GetIt.I<BlockRepository>() as FakeBlockRepository;
FakeReportRepository reportsFake() =>
    GetIt.I<ReportRepository>() as FakeReportRepository;
FakeConnectivityService connectivityFake() =>
    GetIt.I<ConnectivityService>() as FakeConnectivityService;

/// Sahte depoları referans veriyle tohumlar: bakan ve kullanıcı belgeleri,
/// iki kulüp, bakanın üyelikleri ve kullanıcının ortak kulüpteki üyeliği;
/// oturum sahibi `u_burak` (oturum çözülürse aynı kullanıcıyı
/// ve üyelikleri okur).
///
/// [user] `null` ise kullanıcı belgesi yazılmaz; [shared] `false` ise
/// kullanıcının ortak kulüp üyeliği yazılmaz.
void seedProfile({UserModel? user, bool withUser = true, bool shared = true}) {
  (GetIt.I<AuthService>() as FakeAuthService).currentUser = AuthUserInfo(
    uid: kViewer.uid,
    email: kViewerEmail,
    emailVerified: true,
  );
  usersFake().users[kViewer.uid] = kViewer;
  if (withUser) usersFake().users[kUserId] = user ?? kUser;
  clubsFake().clubs[kSharedClubId] = kSharedClub;
  clubsFake().clubs[kClubId] = ClubModelFixtures.byId(kClubId);
  membershipsFake()
    ..put(kViewerInShared)
    ..put(kViewerInContext);
  if (shared) membershipsFake().put(kUserInShared);
}

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

/// Akış kipi: sahteleri tohumlar ve profili gerçek ViewModel ile açar.
///
/// Rota ağacı uygulamadaki gibidir: `/clubs` → `user/:userId` (CLB-07
/// gerçek) ve `:clubId` (yer tutucu); `/not-found` yer tutucudur. Sahteler
/// `pumpApp` tarafından sıfırlandığı için ekran, tohumlamadan **sonra**
/// açılır ([kStartPath] → [location]). [seed] varsayılan tohumlamadan sonra,
/// ekran açılmadan önce çağrılır.
Future<GoRouter> pumpProfileRoute(
  WidgetTester tester, {
  String location = kProfileLocation,
  SessionState? session,
  UserModel? user,
  bool withUser = true,
  bool shared = true,
  void Function()? seed,
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
              path: 'user/:userId',
              builder: (_, state) => UserProfileView(
                userId: state.pathParameters['userId']!,
                clubId: state.uri.queryParameters['clubId'],
              ),
            ),
            GoRoute(
              path: ':clubId',
              builder: (_, state) =>
                  RouteStub('/clubs/${state.pathParameters['clubId']}'),
            ),
          ],
        ),
        GoRoute(
          path: '/not-found',
          builder: (_, _) => const RouteStub('/not-found'),
        ),
      ],
    ),
    overrides: [
      sessionViewModelProvider.overrideWithBuild(
        (_, _) => session ?? viewerSession(),
      ),
    ],
  );
  final router = created!;
  addTearDown(router.dispose);

  seedProfile(user: user, withUser: withUser, shared: shared);
  seed?.call();

  router.go(location);
  await tester.pumpAndSettle();
  return router;
}
