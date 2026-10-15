// T-11 · AppRouter (gerçek rota ağacı + AppRedirect + oturum dinleyicisi):
// açılış, oturum durumuna göre yönlendirme, bilinmeyen yol, geçişler ve yer
// tutucular (PLAN §13.1, §13.4, §13.6; navigation.md §1, §3, §5).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/admin/view/admin_view.dart';
import 'package:gu_kulupler/features/auth/view/legal_view.dart';
import 'package:gu_kulupler/features/auth/view/login_view.dart';
import 'package:gu_kulupler/features/auth/view/register_view.dart';
import 'package:gu_kulupler/features/auth/view/reset_password_view.dart';
import 'package:gu_kulupler/features/auth/view/setup_profile_view.dart';
import 'package:gu_kulupler/features/auth/view/verify_email_view.dart';
import 'package:gu_kulupler/features/clubs/view/club_list_view.dart';
import 'package:gu_kulupler/features/events/view/event_list_view.dart';
import 'package:gu_kulupler/features/notifications/view/notifications_view.dart';
import 'package:gu_kulupler/features/onboarding/view/onboarding_view.dart';
import 'package:gu_kulupler/features/profile/view/profile_view.dart';
import 'package:gu_kulupler/features/system/debug_menu/view/debug_menu_view.dart';
import 'package:gu_kulupler/features/system/view/error_view.dart';
import 'package:gu_kulupler/features/system/view/not_found_view.dart';
import 'package:gu_kulupler/features/system/view/offline_view.dart';
import 'package:gu_kulupler/features/system/view/splash_view.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/app_router.dart';
import 'package:gu_kulupler/product/navigation/navigator_keys.dart';
import 'package:gu_kulupler/product/navigation/routes/auth_routes.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_kulupler/product/navigation/routes/system_routes.dart';
import 'package:gu_kulupler/product/navigation/session_refresh_listenable.dart';
import 'package:gu_kulupler/product/navigation/shell/app_shell_view.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fakes/fake_auth_service.dart';
import '../../fakes/fake_session_states.dart';
import '../../fakes/fake_user_repository.dart';
import '../../fakes/register_fakes.dart';
import '../../fakes/test_router.dart';
import '../../helpers/design_files.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/test_container.dart';

/// Kök gezgindeki en üst sayfa (kabuk ya da kabuksuz rota).
Page<Object?> _topRootPage() =>
    rootNavigatorKey.currentState!.widget.pages.last;

/// Admin sekme kökünün (ADM-01, T-38) başlığı.
String _adminTitle(WidgetTester tester) => tester
    .widget<GuAppBar>(
      find.descendant(
        of: find.byType(AdminView),
        matching: find.byType(GuAppBar),
      ),
    )
    .title!;

void main() {
  final tr = lookupAppLocalizations(const Locale('tr'));

  group('T-11 · AppRouter · kurulum', () {
    setUp(() async {
      await GetIt.I.reset();
      registerDefaultFakes();
      addTearDown(GetIt.I.reset);
    });

    test('açılış yolu /splash; kök gezgin rootNavigatorKey', () {
      final container = createContainer();
      final router = container.read(appRouterProvider);
      expect(
        router.routeInformationProvider.value.uri.toString(),
        AppPaths.splash,
      );
      expect(router.configuration.navigatorKey, same(rootNavigatorKey));
    });

    test('uygulama ömrü boyunca tek router; oturum dinleyicisine bağlı', () {
      final container = createContainer();
      final router = container.read(appRouterProvider);
      expect(container.read(appRouterProvider), same(router));
      expect(
        AppRouter.create(
          container.read(sessionRefreshListenableProvider),
        ).configuration.routes,
        hasLength(router.configuration.routes.length),
      );
    });

    test('feature import etmez (B07): bilinmeyen yol rota sınıfı üzerinden '
        'kurulur', () {
      final source = readText('lib/product/navigation/app_router.dart');
      expect(source, isNot(contains('/features/')));
      expect(source, contains('NotFoundRoute().buildPage'));
    });
  });

  group('T-11 · AppRouter · açılış ve oturum yönlendirmesi', () {
    testWidgets('oturum çözülmeden /splash’te bekler (SYS-01)', (tester) async {
      final app = await TestRouter.pump(
        tester,
        session: FakeSessionStates.unknown,
      );
      expect(app.location, '/splash');
      expect(find.byType(SplashView), findsOneWidget);

      await app.go('/clubs');
      expect(app.location, '/splash');
    });

    testWidgets('çözülünce: aktif → /clubs (kabuk)', (tester) async {
      final app = await TestRouter.pump(
        tester,
        session: FakeSessionStates.unknown,
      );
      app.session = FakeSessionStates.active;
      await tester.pumpAndSettle();
      expect(app.location, '/clubs');
      expect(find.byType(AppShellView), findsOneWidget);
      expect(find.byType(SplashView), findsNothing);
      expect(find.byType(ClubListView), findsOneWidget);
    });

    testWidgets('çözülünce: ilk açılış → /onboarding; tanıtım görülünce → '
        '/login', (tester) async {
      final app = await TestRouter.pump(
        tester,
        session: FakeSessionStates.unknown,
      );
      app.session = FakeSessionStates.signedOutFirstRun;
      await tester.pumpAndSettle();
      expect(app.location, '/onboarding');
      expect(find.byType(OnboardingView), findsOneWidget);

      // ONB-01 "Başla": bayrak yazılır (CD-52).
      app.session = FakeSessionStates.signedOut;
      await tester.pumpAndSettle();
      expect(app.location, '/login');
      expect(find.byType(LoginView), findsOneWidget);
      expect(find.byType(OnboardingView), findsNothing);
      expect(find.byType(AppShellView), findsNothing);
    });

    testWidgets('unverified → /verify; profileIncomplete → /setup-profile', (
      tester,
    ) async {
      final app = await TestRouter.pump(
        tester,
        session: FakeSessionStates.unverified,
      );
      expect(app.location, '/verify');
      expect(find.byType(VerifyEmailView), findsOneWidget);

      app.session = FakeSessionStates.profileIncomplete;
      await tester.pumpAndSettle();
      expect(app.location, '/setup-profile');
      expect(find.byType(SetupProfileView), findsOneWidget);
      expect(find.byType(VerifyEmailView), findsNothing);

      app.session = FakeSessionStates.active;
      await tester.pumpAndSettle();
      expect(app.location, '/clubs');
    });

    testWidgets('oturum kapanınca dönüş adresiyle /login; yeniden girişte '
        'aynı sekmeye döner', (tester) async {
      final app = await TestRouter.pump(tester, location: '/profile');
      expect(app.location, '/profile');

      app.session = FakeSessionStates.signedOut;
      await tester.pumpAndSettle();
      expect(app.location, '/login?from=%2Fprofile');
      expect(find.byType(AppShellView), findsNothing);

      app.session = FakeSessionStates.active;
      await tester.pumpAndSettle();
      expect(app.location, '/profile');
      expect(app.currentTab, GuTab.profile);
      expect(find.byType(ProfileView), findsOneWidget);
    });

    testWidgets('askıya alınınca /login', (tester) async {
      final app = await TestRouter.pump(tester);
      app.session = FakeSessionStates.suspended;
      await tester.pumpAndSettle();
      expect(app.location, '/login');
    });

    testWidgets('aktif oturum oturum-öncesi yola gidemez', (tester) async {
      final app = await TestRouter.pump(tester);
      for (final location in ['/login', '/onboarding', '/verify', '/splash']) {
        await app.go(location);
        expect(app.location, '/clubs', reason: location);
      }
    });

    testWidgets('konum günlüğü: /splash → /clubs', (tester) async {
      final app = await TestRouter.pump(
        tester,
        session: FakeSessionStates.unknown,
      );
      app.session = FakeSessionStates.active;
      await tester.pumpAndSettle();
      expect(app.locationLog, ['/splash', '/clubs']);
    });
  });

  group('T-11 · AppRouter · gerçek SessionViewModel ile uçtan uca', () {
    testWidgets(
      'ilk açılış → tanıtım → giriş → doğrulama → profil → kabuk → çıkış',
      (tester) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAppRouter();
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        final router = container.read(appRouterProvider);
        String location() =>
            router.routerDelegate.currentConfiguration.uri.toString();
        final auth = GetIt.I<AuthService>() as FakeAuthService;
        final users = GetIt.I<UserRepository>() as FakeUserRepository;
        final session = container.read(sessionViewModelProvider.notifier);

        // Oturum yok, tanıtım görülmedi (R2).
        expect(location(), '/onboarding');

        // ONB-01 "Başla" (CD-52) → R3.
        await session.markOnboardingSeen();
        await tester.pumpAndSettle();
        expect(location(), '/login');

        // Doğrulanmamış hesapla giriş → R4.
        await auth.signIn(email: 'a@ogr.gumushane.edu.tr', password: 'Parola1');
        await tester.pumpAndSettle();
        expect(location(), '/verify');

        // "Doğruladım": reload + resolve; profil belgesi henüz yok → R5.
        auth.emailVerified = true;
        await auth.reload();
        await session.resolve();
        await tester.pumpAndSettle();
        expect(location(), '/setup-profile');
        expect(find.byType(AppShellView), findsNothing);

        // AUT-05 bitti: profil tamam → refreshUser → R7.
        users.putActive(auth.uid);
        await session.refreshUser();
        await tester.pumpAndSettle();
        expect(location(), '/clubs');
        expect(find.byType(AppShellView), findsOneWidget);

        // Çıkış → dönüş adresiyle giriş (R3).
        await session.signOut();
        await tester.pumpAndSettle();
        expect(location(), '/login?from=%2Fclubs');
        expect(find.byType(AppShellView), findsNothing);
      },
    );

    testWidgets('açılışta doğrulanmış oturum varsa doğrudan kabuk', (
      tester,
    ) async {
      await tester.pumpWidget(const SizedBox.shrink());
      // Fake'ler `pumpAppRouter` içinde kaydedilir; oturum ilk kareden sonra
      // açılır ve oturum akışı router'ı yeniden değerlendirtir.
      await tester.pumpAppRouter();
      final auth = GetIt.I<AuthService>() as FakeAuthService
        ..emailVerified = true
        ..claims = {RoleCodes.superadmin: true};
      (GetIt.I<UserRepository>() as FakeUserRepository).putActive(auth.uid);
      await auth.signIn(email: 'a@gumushane.edu.tr', password: 'Parola1');
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      expect(
        container
            .read(appRouterProvider)
            .routerDelegate
            .currentConfiguration
            .uri
            .toString(),
        '/clubs',
      );
      // Claim okundu: admin sekmesi görünür.
      expect(
        tester.widget<GuBottomNav>(find.byType(GuBottomNav)).items,
        hasLength(5),
      );
    });
  });

  group('T-11 · AppRouter · rol ve yol guard’ları', () {
    testWidgets('süper admin değil: /admin → /clubs + TST-X18', (tester) async {
      final app = await TestRouter.pump(tester);
      await app.go('/admin');
      expect(app.location, '/clubs');
      expect(app.feedback.toasts, [ToastId.tstX18]);
    });

    testWidgets('süper admin: /admin kökü açılır, admin sekmesi seçili', (
      tester,
    ) async {
      final app = await TestRouter.pump(
        tester,
        session: FakeSessionStates.activeSuper,
        location: '/admin',
      );
      expect(app.location, '/admin');
      expect(_adminTitle(tester), tr.navAdmin);
      final nav = tester.widget<GuBottomNav>(find.byType(GuBottomNav));
      expect(nav.items, hasLength(5));
      expect(nav.currentIndex, GuTab.admin.index);
      expect(app.feedback.toasts, isEmpty);
    });

    testWidgets('bilinmeyen yol → SYS-04 (errorBuilder)', (tester) async {
      final app = await TestRouter.pump(tester);
      await app.go('/boyle-bir-yol-yok');
      expect(find.byType(NotFoundView), findsOneWidget);
      expect(find.byType(AppShellView), findsNothing);
    });

    testWidgets('geçersiz /legal/:tip → /not-found (R12)', (tester) async {
      final app = await TestRouter.pump(
        tester,
        session: FakeSessionStates.signedOut,
      );
      await app.go('/legal/terms');
      expect(app.location, '/not-found');
      expect(find.byType(NotFoundView), findsOneWidget);
    });

    testWidgets('T-13 · /login/register AUT-01’in alt rotasıdır: `go` yığını '
        '[giriş, kayıt] kurar; geri AUT-01’e döner', (tester) async {
      final app = await TestRouter.pump(
        tester,
        session: FakeSessionStates.signedOut,
      );
      const RegisterRoute().go(rootNavigatorKey.currentContext!);
      await tester.pumpAndSettle();

      expect(app.location, '/login/register');
      expect(find.byType(RegisterView), findsOneWidget);
      expect(rootNavigatorKey.currentState!.widget.pages, hasLength(2));
      expect(_topRootPage(), isA<MaterialPage<void>>());

      expect(await app.systemBack(), isTrue);
      expect(app.location, '/login');
      expect(find.byType(LoginView), findsOneWidget);
      expect(find.byType(RegisterView), findsNothing);
    });

    testWidgets('T-14 · /login/reset AUT-01’in alt rotasıdır: `go` yığını '
        '[giriş, sıfırlama] kurar; geri AUT-01’e döner', (tester) async {
      final app = await TestRouter.pump(
        tester,
        session: FakeSessionStates.signedOut,
      );
      expect(const ResetPasswordRoute().location, '/login/reset');
      const ResetPasswordRoute().go(rootNavigatorKey.currentContext!);
      await tester.pumpAndSettle();

      expect(app.location, '/login/reset');
      expect(find.byType(ResetPasswordView), findsOneWidget);
      expect(rootNavigatorKey.currentState!.widget.pages, hasLength(2));
      expect(_topRootPage(), isA<MaterialPage<void>>());

      expect(await app.systemBack(), isTrue);
      expect(app.location, '/login');
      expect(find.byType(LoginView), findsOneWidget);
      expect(find.byType(ResetPasswordView), findsNothing);
    });

    testWidgets('T-14 · /login/reset yalnızca oturumsuzken açılır: etkin '
        'oturum ana sayfaya yönlenir (R7)', (tester) async {
      final app = await TestRouter.pump(tester);
      await app.go('/login/reset');
      expect(app.location, '/clubs');
      expect(find.byType(ResetPasswordView), findsNothing);
    });

    testWidgets('T-13 · LegalRoute `push` ile açılır: açan ekran yığında '
        'kalır, geri ona döner; `tip` yoldan okunur', (tester) async {
      final app = await TestRouter.pump(
        tester,
        session: FakeSessionStates.signedOut,
      );
      for (final tab in LegalTab.values) {
        final closed = LegalRoute(
          tip: tab,
        ).push<void>(rootNavigatorKey.currentContext!);
        await tester.pumpAndSettle();

        // `push` adres çubuğunu değiştirmez: taban konum açan ekrandır,
        // yasal metin onun üstüne itilir.
        expect(app.location, '/login');
        expect(
          GoRouterState.of(tester.element(find.byType(LegalView))).uri.path,
          '/legal/${tab.name}',
        );
        expect(tester.widget<LegalView>(find.byType(LegalView)).tip, tab);
        expect(_topRootPage(), isA<MaterialPage<void>>());
        expect(rootNavigatorKey.currentState!.widget.pages, hasLength(2));
        // Giriş ekranı yığında (altta) durur.
        expect(find.byType(LoginView, skipOffstage: false), findsOneWidget);

        expect(await app.systemBack(), isTrue);
        await closed;
        expect(app.location, '/login');
        expect(find.byType(LegalView), findsNothing);
      }
    });

    testWidgets('T-13 · /legal/:tip her oturum durumunda açılır (guard yok)', (
      tester,
    ) async {
      for (final session in [
        FakeSessionStates.signedOut,
        FakeSessionStates.unverified,
        FakeSessionStates.profileIncomplete,
        FakeSessionStates.active,
      ]) {
        final app = await TestRouter.pump(tester, session: session);
        await app.go('/legal/gizlilik');
        expect(app.location, '/legal/gizlilik', reason: '${session.status}');
        expect(
          tester.widget<LegalView>(find.byType(LegalView)).tip,
          LegalTab.gizlilik,
        );
      }
    });

    testWidgets('/debug bayrak kapalıyken → /not-found (R14); DebugMenuView '
        'ağaca girmez', (tester) async {
      final app = await TestRouter.pump(tester);
      await app.go('/debug');
      expect(app.location, '/not-found');
      expect(find.byType(NotFoundView), findsOneWidget);
      expect(find.byType(DebugMenuView), findsNothing);
    });

    testWidgets('DebugMenuRoute gövdesi derleme sabitiyle seçilir: bayrak '
        'kapalıyken SYS-04', (tester) async {
      await TestRouter.pump(tester);
      final context = tester.element(find.byType(ClubListView));
      expect(
        const DebugMenuRoute().build(context, GoRouterState.of(context)),
        isA<NotFoundView>(),
      );
    });

    testWidgets('sistem ekranları her oturum durumunda açılır', (tester) async {
      for (final session in [
        FakeSessionStates.unknown,
        FakeSessionStates.signedOut,
        FakeSessionStates.active,
      ]) {
        final app = await TestRouter.pump(tester, session: session);
        await app.go('/error?from=%2Fclubs');
        expect(app.location, '/error?from=%2Fclubs');
        expect(tester.widget<ErrorView>(find.byType(ErrorView)).from, '/clubs');
        await app.go('/offline');
        expect(find.byType(OfflineView), findsOneWidget);
        await app.go('/not-found');
        expect(find.byType(NotFoundView), findsOneWidget);
      }
    });
  });

  group('T-11 · AppRouter · sekmeler (gerçek ağaç)', () {
    testWidgets('Kulüpler kökü CLB-01 (T-17), Etkinlikler kökü EVT-01 '
        '(T-24), Bildirimler kökü NTF-01 (T-26), Profil kökü PRF-01 (T-27), '
        'Admin kökü ADM-01 (T-38)', (
      tester,
    ) async {
      final app = await TestRouter.pump(
        tester,
        session: FakeSessionStates.activeSuper,
      );
      for (final tab in GuTab.values) {
        await app.tapTab(tab);
        expect(app.location, tab.rootPath, reason: tab.name);
        if (tab == GuTab.clubs) {
          expect(find.byType(ClubListView), findsOneWidget);
          continue;
        }
        if (tab == GuTab.events) {
          expect(find.byType(EventListView), findsOneWidget);
          continue;
        }
        if (tab == GuTab.notifications) {
          expect(find.byType(NotificationsView), findsOneWidget);
          continue;
        }
        if (tab == GuTab.profile) {
          expect(find.byType(ProfileView), findsOneWidget);
          continue;
        }
        expect(find.byType(AdminView), findsOneWidget, reason: tab.name);
        expect(_adminTitle(tester), tr.navAdmin);
      }
    });

    testWidgets('typed route `go`: sekme kökleri arasında geçiş', (
      tester,
    ) async {
      final app = await TestRouter.pump(tester);
      final context = tester.element(find.byType(AppShellView));
      const EventsRoute().go(context);
      await tester.pumpAndSettle();
      expect(app.location, '/events');
      const ProfileRoute().go(context);
      await tester.pumpAndSettle();
      expect(app.location, '/profile');
      const NotificationsRoute().go(context);
      await tester.pumpAndSettle();
      expect(app.location, '/notifications');
      const ClubsRoute().go(context);
      await tester.pumpAndSettle();
      expect(app.location, '/clubs');
    });

    testWidgets('Admin kökü (ADM-01) EN başlığı', (tester) async {
      final en = lookupAppLocalizations(const Locale('en'));
      await tester.pumpWidget(const SizedBox.shrink());
      final container = ProviderContainer(
        overrides: [
          sessionViewModelProvider.overrideWithBuild(
            (ref, notifier) => FakeSessionStates.activeSuper,
          ),
        ],
      );
      addTearDown(container.dispose);
      await GetIt.I.reset();
      registerDefaultFakes();
      addTearDown(GetIt.I.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            locale: const Locale('en'),
            theme: GuTheme.light(),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            routerConfig: container.read(appRouterProvider),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Tüm sekme kökleri gerçek ekrandır; Admin kökü ADM-01 (T-38).
      container.read(appRouterProvider).go(AppPaths.admin);
      await tester.pumpAndSettle();
      expect(_adminTitle(tester), en.navAdmin);
      expect(
        tester.widget<GuBottomNav>(find.byType(GuBottomNav)).semanticLabel,
        en.a11yMainNav,
      );
    });
  });

  group('T-11 · AppRouter · geçişler (navigation.md §5)', () {
    testWidgets('açılış, oturum öncesi rotalar ve kabuk solar', (tester) async {
      final app = await TestRouter.pump(
        tester,
        session: FakeSessionStates.unknown,
      );
      expect(_topRootPage(), isA<CustomTransitionPage<void>>());

      for (final (session, location) in [
        (FakeSessionStates.signedOutFirstRun, '/onboarding'),
        (FakeSessionStates.signedOut, '/login'),
        (FakeSessionStates.unverified, '/verify'),
        (FakeSessionStates.profileIncomplete, '/setup-profile'),
        (FakeSessionStates.active, '/clubs'),
      ]) {
        app.session = session;
        await tester.pumpAndSettle();
        expect(app.location, location);
        expect(
          _topRootPage(),
          isA<CustomTransitionPage<void>>(),
          reason: location,
        );
      }
    });

    testWidgets('diğer rotalar platform geçişini kullanır (MaterialPage)', (
      tester,
    ) async {
      final app = await TestRouter.pump(tester);
      // Sekme kökü dal gezgininde platform sayfasıdır.
      expect(
        clubsNavigatorKey.currentState!.widget.pages.single,
        isA<MaterialPage<void>>(),
      );
      for (final location in [
        '/error',
        '/offline',
        '/not-found',
        '/legal/kvkk',
      ]) {
        await app.go(location);
        expect(_topRootPage(), isA<MaterialPage<void>>(), reason: location);
      }
    });

    testWidgets('giriş → kabuk geçişi FadeTransition ile, GuMotion.base '
        'sürede çizilir', (tester) async {
      final app = await TestRouter.pump(
        tester,
        session: FakeSessionStates.signedOut,
        location: '/login',
      );
      app.session = FakeSessionStates.active;
      await tester.pump();
      await tester.pump(GuMotion.base ~/ 2);
      expect(
        find.ancestor(
          of: find.byType(AppShellView),
          matching: find.byType(FadeTransition),
        ),
        findsWidgets,
      );
      await tester.pumpAndSettle();
      final page = _topRootPage() as CustomTransitionPage<void>;
      expect(page.transitionDuration, GuMotion.base);
      expect(page.reverseTransitionDuration, GuMotion.base);
    });
  });

  group('T-11 · typed route sınıfları', () {
    test('sekme kökleri ve sistem rotaları sabit kurulur', () {
      expect(const SplashRoute().location, '/splash');
      expect(const OfflineRoute().location, '/offline');
      expect(const NotFoundRoute().location, '/not-found');
      expect(const DebugMenuRoute().location, '/debug');
      expect(const OnboardingRoute().location, '/onboarding');
      expect(const VerifyEmailRoute().location, '/verify');
      expect(const SetupProfileRoute().location, '/setup-profile');
      expect(const AdminRoute().location, '/admin');
    });

    test('dal verileri kendi gezgin anahtarını taşır', () {
      expect(ClubsBranchData.$navigatorKey, same(clubsNavigatorKey));
      expect(EventsBranchData.$navigatorKey, same(eventsNavigatorKey));
      expect(
        NotificationsBranchData.$navigatorKey,
        same(notificationsNavigatorKey),
      );
      expect(AdminBranchData.$navigatorKey, same(adminNavigatorKey));
      expect(ProfileBranchData.$navigatorKey, same(profileNavigatorKey));
    });
  });
}
