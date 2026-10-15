// T-16 · Kulüpler dalının alt rotaları — gerçek rota ağacı + yönlendirme:
// CLB-03 `/clubs/:clubId?tab=`, CLB-04 `…/applied`, CLB-05 `…/application`
// (navigation.md §2.2, PLAN §13.3.2). Yol / sorgu parametreleri view'a
// aktarılır, yığın rota ağacından kurulur (geri ebeveyne döner), alt çubuk
// derin ekranda gizlenir, guard `A` (oturumsuz → giriş), geçiş platform
// varsayılanıdır (D-06).
// T-18 · CLB-06 `/clubs/:clubId/members` (guard `üye`), CLB-07
// `/clubs/user/:userId?clubId=` (guard `A`; `user` parçası `:clubId`
// kalıbından önce eşleşir).
// T-20 · FED-02 `/clubs/:clubId/posts/:postId` (guard `üye`); SHT-09 gövdesi
// kulüp sayfasına rotadan verilir (`commentsSheetBuilder`).
// T-21 · FED-03 `/clubs/:clubId/compose?edit=` (guard `M`).
// T-36 · FED-03 `?type=` başlangıç türü (W-97).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/features/clubs/view/club_application_view.dart';
import 'package:gu_kulupler/features/clubs/view/club_applied_view.dart';
import 'package:gu_kulupler/features/clubs/view/club_detail_view.dart';
import 'package:gu_kulupler/features/clubs/view/club_members_view.dart';
import 'package:gu_kulupler/features/clubs/view/user_profile_view.dart';
import 'package:gu_kulupler/features/feed/view/compose_view.dart';
import 'package:gu_kulupler/features/feed/view/post_detail_view.dart';
import 'package:gu_kulupler/features/feed/view/widget/comments_sheet.dart';
import 'package:gu_kulupler/features/management/view/club_settings_view.dart';
import 'package:gu_kulupler/features/management/view/manage_content_view.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fakes/fake_club_repository.dart';
import '../../fakes/fake_post_repository.dart';
import '../../fakes/fake_session_states.dart';
import '../../fakes/fake_user_repository.dart';
import '../../fakes/test_router.dart';
import '../../fixtures/club_model_fixtures.dart';
import '../../fixtures/post_model_fixtures.dart';

/// Gerçek rota ağacını çizer, demo veriden kulüpleri (ve profil rotasının
/// kullanıcılarını) sahte repository'ye yazar ve [location] yoluna gider.
/// Kulüp ekranları kulübü, CLB-07 kullanıcıyı, FED-02 gönderiyi açılışta
/// okur; bulunamayan kulüp / kullanıcı / gönderi SYS-04'e yönlenir — bu
/// yüzden veri yola gitmeden önce yazılır (fake'ler `pump` sırasında
/// sıfırlanır).
Future<TestRouter> _pump(
  WidgetTester tester, {
  SessionState session = FakeSessionStates.active,
  String? location,
}) async {
  final app = await TestRouter.pump(tester, session: session);
  final clubs = GetIt.I<ClubRepository>() as FakeClubRepository;
  for (final id in const ['c01', 'c03', 'c06', 'c07', 'c09']) {
    clubs.clubs[id] = ClubModelFixtures.byId(id);
  }
  final users = GetIt.I<UserRepository>() as FakeUserRepository;
  const ['u01', 'u02'].forEach(users.putActive);
  (GetIt.I<PostRepository>() as FakePostRepository)
    ..put(PostModelFixtures.p01)
    ..put(PostModelFixtures.p02);
  if (location != null) await app.go(location);
  return app;
}

ClubDetailView _detail(WidgetTester tester) =>
    tester.widget<ClubDetailView>(find.byType(ClubDetailView));

void main() {
  group('T-36 · içerik yönetimi ve kulüp ayarları rotaları (MGT-08, '
      'MGT-09)', () {
    testWidgets('/clubs/:clubId/manage/content ve …/settings → view(clubId); '
        'geri panele döner; danışman açar, üye kulüp sayfasına yönlenir', (
      tester,
    ) async {
      final app = await _pump(
        tester,
        session: FakeSessionStates.activeManager('c01'),
        location: '/clubs/c01/manage/content',
      );
      expect(app.location, '/clubs/c01/manage/content');
      expect(
        tester.widget<ManageContentView>(find.byType(ManageContentView)).clubId,
        'c01',
      );
      expect(find.byType(GuBottomNav), findsNothing);
      expect(app.stackDepth(GuTab.clubs), 4);
      expect(await app.systemBack(), isTrue);
      expect(app.location, '/clubs/c01/manage');

      // W-40: `?tab=` ilk sekmedir; tanınmayan değer yok sayılır.
      await app.go('/clubs/c01/manage/content?tab=announcement');
      expect(
        tester.widget<ManageContentView>(find.byType(ManageContentView)).tab,
        PostType.announcement,
      );
      await app.go('/clubs/c01/manage/content?tab=bogus');
      expect(
        tester.widget<ManageContentView>(find.byType(ManageContentView)).tab,
        isNull,
      );

      await app.go('/clubs/c01/manage/settings');
      expect(
        tester.widget<ClubSettingsView>(find.byType(ClubSettingsView)).clubId,
        'c01',
      );
      expect(app.stackDepth(GuTab.clubs), 4);
      expect(await app.systemBack(), isTrue);
      expect(app.location, '/clubs/c01/manage');
    });

    testWidgets('danışman iki ekranı açar; üye kulüp sayfasına yönlenir', (
      tester,
    ) async {
      final app = await _pump(
        tester,
        session: FakeSessionStates.activeAdvisor('c01'),
        location: '/clubs/c01/manage/settings',
      );
      expect(app.location, '/clubs/c01/manage/settings');
      expect(find.byType(ClubSettingsView), findsOneWidget);
      await app.go('/clubs/c01/manage/content');
      expect(find.byType(ManageContentView), findsOneWidget);

      final member = await _pump(
        tester,
        session: FakeSessionStates.activeMember('c01'),
        location: '/clubs/c01/manage/settings',
      );
      expect(member.location, '/clubs/c01');
      expect(find.byType(ClubSettingsView), findsNothing);
    });
  });

  group('T-21 · gönderi oluşturma rotası (FED-03)', () {
    testWidgets('/clubs/:clubId/compose?edit= → ComposeView(clubId, '
        'editPostId); yönetici olmayan kulüp sayfasına yönlenir; geri '
        'kulübe döner', (tester) async {
      final app = await _pump(
        tester,
        session: FakeSessionStates.activeManager('c01'),
        location: '/clubs/c01/compose?edit=p01',
      );
      ComposeView compose() =>
          tester.widget<ComposeView>(find.byType(ComposeView));
      expect(app.location, '/clubs/c01/compose?edit=p01');
      expect(compose().clubId, 'c01');
      expect(compose().editPostId, 'p01');
      expect(find.byType(GuBottomNav), findsNothing);
      expect(app.stackDepth(GuTab.clubs), 3);

      const ComposeRoute(
        clubId: 'c01',
      ).go(tester.element(find.byType(ComposeView)));
      await tester.pumpAndSettle();
      expect(app.location, '/clubs/c01/compose');
      expect(compose().editPostId, isNull);

      expect(await app.systemBack(), isTrue);
      expect(app.location, '/clubs/c01');
      expect(find.byType(ComposeView), findsNothing);

      // T-36 (W-97): `?type=` başlangıç türüdür; tanınmayan değer yok
      // sayılır.
      await app.go('/clubs/c01/compose?type=announcement');
      expect(compose().initialType, PostType.announcement);
      await app.go('/clubs/c01/compose?type=bogus');
      expect(compose().initialType, isNull);

      // Başka kulübün yöneticisi: yazma ekranı açılmaz.
      await app.go('/clubs/c03/compose');
      expect(app.location, '/clubs/c03');
      expect(find.byType(ComposeView), findsNothing);
    });
  });

  group('T-20 · gönderi detayı rotası (FED-02)', () {
    testWidgets('/clubs/:clubId/posts/:postId → PostDetailView(clubId, '
        'postId); üye olmayan kulüp sayfasına yönlenir; geri kulübe '
        'döner', (tester) async {
      final app = await _pump(
        tester,
        session: FakeSessionStates.activeMember('c01'),
        location: '/clubs/c01/posts/p01',
      );
      PostDetailView post() =>
          tester.widget<PostDetailView>(find.byType(PostDetailView));
      expect(app.location, '/clubs/c01/posts/p01');
      expect(post().clubId, 'c01');
      expect(post().postId, 'p01');
      expect(find.byType(GuBottomNav), findsNothing);
      expect(app.stackDepth(GuTab.clubs), 3);

      const PostDetailRoute(
        clubId: 'c01',
        postId: 'p02',
      ).go(tester.element(find.byType(PostDetailView)));
      await tester.pumpAndSettle();
      expect(app.location, '/clubs/c01/posts/p02');
      expect(post().postId, 'p02');

      expect(await app.systemBack(), isTrue);
      expect(app.location, '/clubs/c01');
      expect(find.byType(PostDetailView), findsNothing);

      await app.go('/clubs/c03/posts/p01');
      expect(app.location, '/clubs/c03');
      expect(find.byType(PostDetailView), findsNothing);
    });

    testWidgets('kulüp sayfası yorum sayfasının (SHT-09) gövdesini rotadan '
        'alır: `commentsSheetBuilder` → CommentsSheet(clubId, postId)', (
      tester,
    ) async {
      await _pump(tester, location: '/clubs/c01');
      final builder = _detail(tester).commentsSheetBuilder;
      expect(builder, isNotNull);
      final sheet = builder!('c01', 'p01');
      expect(sheet, isA<CommentsSheet>());
      expect((sheet as CommentsSheet).clubId, 'c01');
      expect(sheet.postId, 'p01');
    });
  });

  group('T-18 · üye listesi ve profil rotaları', () {
    testWidgets('/clubs/:clubId/members → ClubMembersView(clubId); üye '
        'olmayan kulüp sayfasına yönlenir', (tester) async {
      final app = await _pump(
        tester,
        session: FakeSessionStates.activeMember('c01'),
        location: '/clubs/c01/members',
      );
      expect(app.location, '/clubs/c01/members');
      expect(
        tester.widget<ClubMembersView>(find.byType(ClubMembersView)).clubId,
        'c01',
      );

      await app.go('/clubs/c03/members');
      expect(app.location, '/clubs/c03');
      expect(find.byType(ClubMembersView), findsNothing);
    });

    testWidgets('/clubs/user/:userId?clubId= → UserProfileView(userId, '
        'clubId); `user` kulüp kimliği sayılmaz', (tester) async {
      final app = await _pump(tester, location: '/clubs/user/u01');
      UserProfileView profile() =>
          tester.widget<UserProfileView>(find.byType(UserProfileView));
      expect(app.location, '/clubs/user/u01');
      expect(find.byType(ClubDetailView), findsNothing);
      expect(profile().userId, 'u01');
      expect(profile().clubId, isNull);

      const ClubUserProfileRoute(
        userId: 'u02',
        clubId: 'c03',
      ).go(tester.element(find.byType(UserProfileView)));
      await tester.pumpAndSettle();
      expect(app.location, '/clubs/user/u02?clubId=c03');
      expect(profile().userId, 'u02');
      expect(profile().clubId, 'c03');
    });
  });

  group('T-16 · kulüp rotaları · eşleşme', () {
    testWidgets('/clubs/:clubId → ClubDetailView(clubId); sekme verilmezse '
        '`tab` null', (tester) async {
      final app = await _pump(tester, location: '/clubs/c01');
      expect(app.location, '/clubs/c01');
      expect(_detail(tester).clubId, 'c01');
      expect(_detail(tester).tab, isNull);

      await app.go('/clubs/c07');
      expect(_detail(tester).clubId, 'c07');
    });

    testWidgets('`?tab=` her sekme adını ekrana taşır; tanınmayan değer '
        'null (ekran hakkında ile açılır)', (tester) async {
      final app = await _pump(tester);
      for (final tab in ClubDetailTab.values) {
        await app.go('/clubs/c01?tab=${tab.name}');
        expect(app.location, '/clubs/c01?tab=${tab.name}');
        expect(_detail(tester).tab, tab, reason: tab.name);
      }
      await app.go('/clubs/c01?tab=bilinmeyen');
      expect(_detail(tester).clubId, 'c01');
      expect(_detail(tester).tab, isNull);
    });

    testWidgets('/clubs/:clubId/applied → ClubAppliedView(clubId)', (
      tester,
    ) async {
      final app = await _pump(
        tester,
        location: '/clubs/c06/applied',
      );
      expect(app.location, '/clubs/c06/applied');
      expect(
        tester.widget<ClubAppliedView>(find.byType(ClubAppliedView)).clubId,
        'c06',
      );
    });

    testWidgets('/clubs/:clubId/application → ClubApplicationView(clubId)', (
      tester,
    ) async {
      final app = await _pump(
        tester,
        location: '/clubs/c06/application',
      );
      expect(app.location, '/clubs/c06/application');
      expect(
        tester
            .widget<ClubApplicationView>(find.byType(ClubApplicationView))
            .clubId,
        'c06',
      );
    });

    testWidgets('tipli rota `go` ile açılır (ClubDetailRoute, '
        'ClubAppliedRoute, ClubApplicationRoute)', (tester) async {
      final app = await _pump(tester);
      BuildContext context() => tester.element(find.byType(Scaffold).last);

      const ClubDetailRoute(
        clubId: 'c03',
        tab: ClubDetailTab.posts,
      ).go(context());
      await tester.pumpAndSettle();
      expect(app.location, '/clubs/c03?tab=posts');
      expect(_detail(tester).clubId, 'c03');
      expect(_detail(tester).tab, ClubDetailTab.posts);

      const ClubAppliedRoute(clubId: 'c03').go(context());
      await tester.pumpAndSettle();
      expect(app.location, '/clubs/c03/applied');
      expect(find.byType(ClubAppliedView), findsOneWidget);

      const ClubApplicationRoute(clubId: 'c03').go(context());
      await tester.pumpAndSettle();
      expect(app.location, '/clubs/c03/application');
      expect(find.byType(ClubApplicationView), findsOneWidget);
    });
  });

  group('T-16 · kulüp rotaları · yığın ve kabuk', () {
    testWidgets('yığın rota ağacından kurulur: başvuru ekranından geri → '
        'kulüp → Kulüpler kökü', (tester) async {
      for (final leaf in ['applied', 'application']) {
        final app = await _pump(
          tester,
          location: '/clubs/c01/$leaf',
        );
        expect(app.currentTab, GuTab.clubs);
        expect(app.stackDepth(GuTab.clubs), 3, reason: leaf);

        expect(await app.systemBack(), isTrue);
        expect(app.location, '/clubs/c01', reason: leaf);
        expect(find.byType(ClubDetailView), findsOneWidget);
        expect(app.stackDepth(GuTab.clubs), 2);

        expect(await app.systemBack(), isTrue);
        expect(app.location, '/clubs', reason: leaf);
        expect(find.byType(ClubDetailView), findsNothing);
      }
    });

    testWidgets('alt sekme çubuğu yalnızca kökte: kulüp ve başvuru '
        'ekranlarında gizlenir', (tester) async {
      final app = await _pump(tester, location: '/clubs');
      expect(find.byType(GuBottomNav), findsOneWidget);
      for (final location in [
        '/clubs/c01',
        '/clubs/c01?tab=events',
        '/clubs/c01/applied',
        '/clubs/c01/application',
      ]) {
        await app.go(location);
        expect(find.byType(GuBottomNav), findsNothing, reason: location);
      }
      await app.go('/clubs');
      expect(find.byType(GuBottomNav), findsOneWidget);
    });

    testWidgets('başka sekmeden kulübe `go`: Kulüpler sekmesine geçilir, '
        'çağıran sekmenin yığını korunur (Q-20)', (tester) async {
      final app = await _pump(tester, location: '/profile');
      expect(app.currentTab, GuTab.profile);

      await app.go('/clubs/c01');
      expect(app.currentTab, GuTab.clubs);
      expect(app.stackDepth(GuTab.clubs), 2);
      expect(app.stackDepth(GuTab.profile), 1);

      expect(await app.systemBack(), isTrue);
      expect(app.location, '/clubs');
    });

    testWidgets('geçiş platform varsayılanıdır: üç rotanın sayfası '
        'MaterialPage', (tester) async {
      final app = await _pump(tester);
      for (final location in [
        '/clubs/c01',
        '/clubs/c01/applied',
        '/clubs/c01/application',
      ]) {
        await app.go(location);
        final pages = GuTab.clubs.navigatorKey.currentState!.widget.pages;
        expect(pages.last, isA<MaterialPage<void>>(), reason: location);
      }
    });
  });

  group('T-16 · kulüp rotaları · guard (A)', () {
    testWidgets('oturum yokken giriş ekranına yönlenir; dönüş adresi '
        'sorguda taşınır', (tester) async {
      for (final location in [
        '/clubs/c01',
        '/clubs/c01/applied',
        '/clubs/c01/application',
      ]) {
        final app = await _pump(
          tester,
          session: FakeSessionStates.signedOut,
          location: location,
        );
        expect(
          app.location,
          '/login?from=${Uri.encodeQueryComponent(location)}',
          reason: location,
        );
        expect(find.byType(ClubDetailView), findsNothing);
      }
    });

    testWidgets('doğrulanmamış ve profili eksik oturum kulüp rotasına '
        'giremez', (tester) async {
      final unverified = await _pump(
        tester,
        session: FakeSessionStates.unverified,
        location: '/clubs/c01',
      );
      expect(unverified.location, '/verify');

      final incomplete = await _pump(
        tester,
        session: FakeSessionStates.profileIncomplete,
        location: '/clubs/c01/application',
      );
      expect(incomplete.location, '/setup-profile');
    });

    testWidgets('ziyaretçi (kulüpte üyeliği yok) üç rotaya da girer: rota '
        'düzeyinde rol koruması yoktur', (tester) async {
      final app = await _pump(tester);
      expect(app.session.memberships.containsKey('c09'), isFalse);
      for (final location in [
        '/clubs/c09',
        '/clubs/c09?tab=posts',
        '/clubs/c09/applied',
        '/clubs/c09/application',
      ]) {
        await app.go(location);
        expect(app.location, location);
        expect(app.feedback.toasts, isEmpty);
      }
    });
  });
}
