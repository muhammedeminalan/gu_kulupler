// T-11 · DebugMenuView iskeleti (K-E, CD-69): tema / dil / metin ölçeği
// seçicileri tercihlere yazar; anahtarlar `debug.*` (tasarım envanteri
// dışı); cihaz matrisi. Köşe düğmesi (DebugMenuCornerButton) ayrıca.
// T-11 · DebugMenu · demo hesaplar (CD-132 (23)): yalnızca emülatörde altı
// hesap satırı → `signIn(e-posta, demo parolası)` + uygulamaya gidiş; hata
// satırı; "Çıkış yap"; SYS-02 / 03 / 04 kısayolları.
// T-16 · DebugMenu · demo kulüpler: yalnızca emülatörde üç kulüp satırı →
// CLB-03 (`ClubDetailRoute.go`); T-17'de kaldırılır.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/auth/view/login_view.dart';
import 'package:gu_kulupler/features/onboarding/view/onboarding_view.dart';
import 'package:gu_kulupler/features/system/debug_menu/provider/debug_demo_accounts.dart';
import 'package:gu_kulupler/features/system/debug_menu/provider/debug_demo_clubs.dart';
import 'package:gu_kulupler/features/system/debug_menu/view/debug_menu_view.dart';
import 'package:gu_kulupler/features/system/debug_menu/view/widget/debug_menu_corner_button.dart';
import 'package:gu_kulupler/product/init/app_preferences_state.dart';
import 'package:gu_kulupler/product/init/app_preferences_view_model.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../../fakes/fake_auth_service.dart';
import '../../../../fakes/fake_base.dart';
import '../../../../fakes/fake_session_states.dart';
import '../../../../fakes/test_router.dart';
import '../../../../helpers/action_inventory.dart';
import '../../../../helpers/device_matrix.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_l10n.dart';

AppPreferencesState _preferences(WidgetTester tester) =>
    ProviderScope.containerOf(
      tester.element(find.byType(DebugMenuView)),
    ).read(appPreferencesViewModelProvider);

FakeAuthService _auth() => GetIt.I<AuthService>() as FakeAuthService;

/// Tüm bölümlerin tek ekrana sığdığı boyut (liste tembel kurulur; kaydırma
/// gerekmez).
const Size _tall = Size(390, 1600);

/// `/debug` (emülatör kipinde DebugMenu) + [paths] sayfalarından oluşan
/// router.
GoRouter _debugRouter(List<String> paths) {
  final router = GoRouter(
    initialLocation: AppPaths.debug,
    routes: [
      GoRoute(
        path: AppPaths.debug,
        builder: (_, _) => const DebugMenuView(isEmulator: true),
      ),
      for (final path in paths)
        GoRoute(path: path, builder: (_, _) => TestPage(path)),
    ],
  );
  addTearDown(router.dispose);
  return router;
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

void main() {
  group('T-11 · DebugMenuView', () {
    testWidgets('üç bölüm: tema, dil, yazı boyutu', (tester) async {
      await tester.pumpApp(const DebugMenuView());
      final l10n = tester.l10n;
      expect(find.text(l10n.settingsGroupAppearance), findsOneWidget);
      expect(find.text(l10n.settingsTheme), findsOneWidget);
      expect(find.text(l10n.settingsLanguage), findsOneWidget);
      expect(find.text(l10n.settingsTextSize), findsOneWidget);
      expect(find.byType(GuSegmented), findsNWidgets(3));
      expect(find.text(l10n.themeDark), findsOneWidget);
      expect(find.text(l10n.themeLight), findsOneWidget);
      // Sistem seçeneği temada ve dilde vardır.
      expect(find.text(l10n.themeSystem), findsNWidgets(2));
    });

    testWidgets('tema seçimi tercihe yazılır', (tester) async {
      await tester.pumpApp(const DebugMenuView());
      await tester.tap(find.byKey(DebugMenuView.themeKey(ThemeMode.dark)));
      await tester.pumpAndSettle();
      expect(_preferences(tester).themeMode, ThemeMode.dark);
      await tester.tap(find.byKey(DebugMenuView.themeKey(ThemeMode.system)));
      await tester.pumpAndSettle();
      expect(_preferences(tester).themeMode, ThemeMode.system);
    });

    testWidgets('dil seçimi tercihe yazılır; "Sistem" dili sıfırlar', (
      tester,
    ) async {
      await tester.pumpApp(const DebugMenuView());
      await tester.tap(find.byKey(DebugMenuView.localeKey('en')));
      await tester.pumpAndSettle();
      expect(_preferences(tester).locale, const Locale('en'));
      await tester.tap(
        find.byKey(DebugMenuView.localeKey(DebugMenuView.systemLocaleId)),
      );
      await tester.pumpAndSettle();
      expect(_preferences(tester).locale, isNull);
    });

    testWidgets('metin ölçeği seçimi tercihe yazılır', (tester) async {
      await tester.pumpApp(const DebugMenuView());
      await tester.tap(
        find.byKey(DebugMenuView.textScaleKey(GuTextScaleLevel.s160)),
      );
      await tester.pumpAndSettle();
      expect(_preferences(tester).textScale, GuTextScaleLevel.s160);
    });

    testWidgets('anahtarlar tasarım aksiyon envanterine girmez', (
      tester,
    ) async {
      await tester.pumpApp(const DebugMenuView());
      expect(ActionInventory.found(tester), isEmpty);
    });

    testWidgets('geri: yığında sayfa varsa döner, yoksa ana sayfa', (
      tester,
    ) async {
      for (final (start, expected) in [
        ('/debug', '/clubs'),
        ('/clubs/debug', '/clubs'),
        ('/profile/debug', '/profile'),
      ]) {
        final router = GoRouter(
          initialLocation: start,
          routes: [
            GoRoute(path: '/debug', builder: (_, _) => const DebugMenuView()),
            for (final root in ['/clubs', '/profile'])
              GoRoute(
                path: root,
                builder: (_, _) => TestPage(root),
                routes: [
                  GoRoute(
                    path: 'debug',
                    builder: (_, _) => const DebugMenuView(),
                  ),
                ],
              ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAppRouter(routerOf: (_) => router);
        await tester.pumpAndSettle();
        expect(find.byType(DebugMenuView), findsOneWidget);

        await tester.tap(find.byKey(DebugMenuView.backKey));
        await tester.pumpAndSettle();
        expect(
          router.routerDelegate.currentConfiguration.uri.toString(),
          expected,
          reason: start,
        );
        expect(find.byType(DebugMenuView), findsNothing);
      }
    });

    testWidgets('cihaz matrisi: taşma yok', (tester) async {
      await DeviceMatrix.run(
        tester,
        (_) => const DebugMenuView(),
        safeAreas: true,
      );
    });
  });

  group('T-11 · DebugMenu · demo hesaplar', () {
    testWidgets('emülatör değilken bölüm yok; kısayollar durur', (
      tester,
    ) async {
      await tester.pumpApp(const DebugMenuView(), size: _tall);
      final l10n = tester.l10n;
      expect(find.text(l10n.debugMenuDemoAccounts), findsNothing);
      for (final account in DebugDemoAccounts.all) {
        expect(
          find.byKey(DebugMenuView.demoAccountKey(account.id)),
          findsNothing,
        );
        expect(find.text(account.email), findsNothing);
      }
      expect(find.text(l10n.debugMenuSystemScreens), findsOneWidget);
      // Oturum yok → "Çıkış yap" da yok.
      expect(find.byKey(DebugMenuView.signOutKey), findsNothing);
    });

    testWidgets('emülatörde altı hesap satırı: rol + e-posta; anahtarlar '
        '`debug.demo.<id>` (tasarım envanteri dışı)', (tester) async {
      await tester.pumpApp(const DebugMenuView(isEmulator: true), size: _tall);
      final l10n = tester.l10n;
      expect(find.text(l10n.debugMenuDemoAccounts), findsOneWidget);
      final roles = [
        l10n.roleStudent,
        l10n.roleMember,
        l10n.roleBoard,
        l10n.rolePresident,
        l10n.roleAdvisor,
        l10n.roleSuperadmin,
      ];
      for (final (index, account) in DebugDemoAccounts.all.indexed) {
        final row = find.byKey(DebugMenuView.demoAccountKey(account.id));
        expect(row, findsOneWidget);
        expect(
          DebugMenuView.demoAccountKey(account.id),
          ValueKey<String>('debug.demo.${account.id}'),
        );
        final tile = tester.widget<GuTile>(row);
        expect(tile.title, roles[index]);
        expect(tile.subtitle, account.email);
        expect(tile.trailing, isNull);
      }
      expect(find.byKey(DebugMenuView.demoErrorKey), findsNothing);
      expect(ActionInventory.found(tester), isEmpty);
    });

    testWidgets('hesaba dokunma → signIn(e-posta, demo parolası) ve '
        'uygulamaya gidiş', (tester) async {
      final account = DebugDemoAccounts.all[3];
      final router = _debugRouter([AppPaths.clubs]);
      await tester.pumpAppRouter(routerOf: (_) => router, size: _tall);
      await tester.pumpAndSettle();
      _auth()
        ..emailVerified = true
        ..uid = account.id;

      await tester.tap(find.byKey(DebugMenuView.demoAccountKey(account.id)));
      await tester.pumpAndSettle();

      expect(_auth().callsTo('signIn'), [
        FakeCall('signIn', [account.email, DebugDemoAccounts.password]),
      ]);
      expect(_location(router), AppPaths.clubs);
      expect(find.byType(DebugMenuView), findsNothing);
    });

    testWidgets('giriş hatası → hata satırı (kod ile); yönlendirme yok', (
      tester,
    ) async {
      final account = DebugDemoAccounts.all.first;
      await tester.pumpApp(const DebugMenuView(isEmulator: true), size: _tall);
      _auth().failNext(AuthError.network);

      await tester.tap(find.byKey(DebugMenuView.demoAccountKey(account.id)));
      await tester.pumpAndSettle();

      expect(_auth().callsTo('signIn'), hasLength(1));
      expect(find.byKey(DebugMenuView.demoErrorKey), findsOneWidget);
      expect(
        find.text(tester.l10n.debugMenuSignInError(AuthError.network.name)),
        findsOneWidget,
      );
      expect(find.byType(DebugMenuView), findsOneWidget);
      // Satırlar yeniden dokunulabilir.
      expect(
        tester
            .widget<GuTile>(
              find.byKey(DebugMenuView.demoAccountKey(account.id)),
            )
            .disabled,
        isFalse,
      );
    });

    testWidgets('oturumdaki hesap işaretlenir; "Çıkış yap" oturumu kapatır', (
      tester,
    ) async {
      final account = DebugDemoAccounts.all[4];
      await tester.pumpApp(const DebugMenuView(isEmulator: true), size: _tall);
      expect(find.byKey(DebugMenuView.signOutKey), findsNothing);

      _auth()
        ..emailVerified = true
        ..uid = account.id;
      await _auth().signIn(
        email: account.email,
        password: DebugDemoAccounts.password,
      );
      await tester.pumpAndSettle();

      final row = find.byKey(DebugMenuView.demoAccountKey(account.id));
      expect(
        find.descendant(of: row, matching: find.byType(GuIcon)),
        findsOneWidget,
      );
      expect(find.text(tester.l10n.settingsGroupAccount), findsOneWidget);
      expect(find.text(tester.l10n.authLogout), findsOneWidget);

      await tester.tap(find.byKey(DebugMenuView.signOutKey));
      await tester.pumpAndSettle();

      expect(_auth().callsTo('signOut'), hasLength(1));
      expect(find.byKey(DebugMenuView.signOutKey), findsNothing);
      expect(
        find.descendant(of: row, matching: find.byType(GuIcon)),
        findsNothing,
      );
    });

    testWidgets('kısayollar: SYS-02 / SYS-03 / SYS-04 rotalarına `go`', (
      tester,
    ) async {
      for (final (key, expected) in [
        (DebugMenuView.errorScreenKey, AppPaths.error),
        (DebugMenuView.offlineScreenKey, AppPaths.offline),
        (DebugMenuView.notFoundScreenKey, AppPaths.notFound),
      ]) {
        final router = _debugRouter([
          AppPaths.error,
          AppPaths.offline,
          AppPaths.notFound,
        ]);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAppRouter(routerOf: (_) => router, size: _tall);
        await tester.pumpAndSettle();
        expect(
          tester.widget<GuTile>(find.byKey(key)).subtitle,
          expected,
        );

        await tester.tap(find.byKey(key));
        await tester.pumpAndSettle();
        expect(_location(router), expected);
        // `go`: yığın değişir, DebugMenu altta kalmaz (push yok).
        expect(router.canPop(), isFalse, reason: expected);
        expect(find.byType(DebugMenuView), findsNothing);
      }
    });

    testWidgets('cihaz matrisi (emülatör, oturum açık): taşma yok', (
      tester,
    ) async {
      await DeviceMatrix.run(
        tester,
        (_) => const DebugMenuView(isEmulator: true),
        overrides: [
          sessionViewModelProvider.overrideWithBuild(
            (ref, notifier) => FakeSessionStates.active,
          ),
        ],
        safeAreas: true,
      );
    });
  });

  group('T-16 · DebugMenu · demo kulüpler', () {
    // TODO(T-17): Kulüpler listesi gelince bölüm ve bu grup kaldırılır.
    testWidgets('emülatör değilken bölüm yok', (tester) async {
      await tester.pumpApp(const DebugMenuView(), size: _tall);
      expect(find.text(tester.l10n.debugMenuDemoClubs), findsNothing);
      for (final club in DebugDemoClubs.all) {
        expect(find.byKey(DebugMenuView.demoClubKey(club.id)), findsNothing);
      }
    });

    testWidgets('emülatörde üç kulüp satırı: katılım biçimi + yol; '
        'anahtarlar `debug.club.<id>` (tasarım envanteri dışı)', (
      tester,
    ) async {
      await tester.pumpApp(const DebugMenuView(isEmulator: true), size: _tall);
      final l10n = tester.l10n;
      expect(find.text(l10n.debugMenuDemoClubs), findsOneWidget);
      final labels = {
        DebugDemoClubKind.instant: l10n.clubTypeInstant,
        DebugDemoClubKind.approval: l10n.clubTypeApproval,
        DebugDemoClubKind.closed: l10n.clubsCardClosed,
      };
      expect(DebugDemoClubs.all, hasLength(3));
      for (final club in DebugDemoClubs.all) {
        final row = find.byKey(DebugMenuView.demoClubKey(club.id));
        expect(row, findsOneWidget);
        expect(
          DebugMenuView.demoClubKey(club.id),
          ValueKey<String>('debug.club.${club.id}'),
        );
        final tile = tester.widget<GuTile>(row);
        expect(tile.title, labels[club.kind]);
        expect(tile.subtitle, '${AppPaths.clubs}/${club.id}');
        expect(tile.chevron, isTrue);
      }
      expect(ActionInventory.found(tester), isEmpty);
    });

    testWidgets('satıra dokunma → kulüp sayfasına `go` (CLB-03, '
        '`/clubs/<id>`)', (tester) async {
      for (final club in DebugDemoClubs.all) {
        final path = '${AppPaths.clubs}/${club.id}';
        final router = _debugRouter([path]);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAppRouter(routerOf: (_) => router, size: _tall);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(DebugMenuView.demoClubKey(club.id)));
        await tester.pumpAndSettle();

        expect(_location(router), path, reason: club.id);
        // `go`: DebugMenu yığında kalmaz (guard'lı rotaya push yok).
        expect(router.canPop(), isFalse, reason: club.id);
        expect(find.byType(DebugMenuView), findsNothing);
      }
    });
  });

  group('T-11 · DebugMenuCornerButton', () {
    Rect handleRect(WidgetTester tester) =>
        tester.getRect(find.byKey(DebugMenuCornerButton.openKey));

    /// [position] noktasındaki vuruş yolunda [finder]'ın öğesi var mı?
    bool hits(WidgetTester tester, Offset position, Finder finder) {
      final target = tester.renderObject(finder);
      return tester
          .hitTestOnBinding(position)
          .path
          .map((entry) => entry.target)
          .whereType<RenderObject>()
          .any((node) => _isWithin(node, target));
    }

    bool hitsHandle(WidgetTester tester, Offset position) =>
        hits(tester, position, find.byKey(DebugMenuCornerButton.openKey));

    testWidgets('sağ kenarda, dikeyde ~%45’te 16 × 48 dp yarı saydam tutamaç; '
        'anahtar `debug.open`; dokunma geri çağrıyı tetikler', (tester) async {
      var opened = 0;
      await tester.pumpApp(
        DebugMenuCornerButton(
          onPressed: () => opened++,
          child: const SizedBox.expand(key: ValueKey<String>('corner.child')),
        ),
        viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
      );
      expect(
        DebugMenuCornerButton.openKey,
        const ValueKey<String>('debug.open'),
      );
      // Sağ kenara yapışık; genişlik sayfa kenar boşluğu kadar.
      final rect = handleRect(tester);
      expect(rect.size, const Size(16, 48));
      expect(rect.right, 390);
      expect(rect.top, closeTo((844 - 48) * 0.45, 0.01));
      // Etkin dokunma alanı görselin dışına taşmaz.
      expect(hitsHandle(tester, rect.center), isTrue);
      expect(hitsHandle(tester, rect.centerLeft - const Offset(2, 0)), isFalse);
      expect(hitsHandle(tester, rect.topCenter - const Offset(0, 2)), isFalse);
      expect(
        hitsHandle(tester, rect.bottomCenter + const Offset(0, 2)),
        isFalse,
      );
      // Yarı saydam.
      expect(
        tester
            .widget<Opacity>(
              find.ancestor(
                of: find.byKey(DebugMenuCornerButton.openKey),
                matching: find.byType(Opacity),
              ),
            )
            .opacity,
        GuOpacity.disabled,
      );
      // Erişilebilirlik: etiketli düğme.
      final handle = find.byKey(DebugMenuCornerButton.openKey);
      expect(
        tester.getSemantics(handle),
        isSemantics(
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          label: tester.l10n.settingsGroupAppearance,
        ),
      );
      // İçerik tüm alanı doldurur.
      expect(
        tester.getSize(find.byKey(const ValueKey<String>('corner.child'))),
        const Size(390, 844),
      );
      // Tasarım aksiyonu değildir.
      expect(ActionInventory.found(tester), isEmpty);

      await tester.tap(find.byKey(DebugMenuCornerButton.openKey));
      expect(opened, 1);
    });

    testWidgets('üst çubuk ve alt sekme çubuğu bölgesinin dışında kalır — '
        'tüm cihaz boyutları, güvenli alanlı', (tester) async {
      const padding = EdgeInsets.only(top: 59, bottom: 34);
      for (final size in MatrixSize.values) {
        await tester.pumpApp(
          DebugMenuCornerButton(
            onPressed: () {},
            child: const SizedBox.expand(),
          ),
          size: size.size,
          viewPadding: padding,
        );
        final rect = handleRect(tester);
        final height = size.size.height;
        expect(rect.right, size.size.width, reason: size.name);
        // Üst çubuk: güvenli alan + çubuk yüksekliği.
        expect(
          rect.top,
          greaterThan(padding.top + kToolbarHeight),
          reason: size.name,
        );
        // Alt sekme çubuğu: çubuk yüksekliği + güvenli alan.
        expect(
          rect.bottom,
          lessThan(height - GuSizes.bottomNavHeight - padding.bottom),
          reason: size.name,
        );
      }
    });

    testWidgets('yatay güvenli alan (çentik) kadar içeri kayar', (
      tester,
    ) async {
      await tester.pumpApp(
        DebugMenuCornerButton(onPressed: () {}, child: const SizedBox.expand()),
        viewPadding: const EdgeInsets.only(right: 44),
      );
      expect(handleRect(tester).right, 390 - 44);
    });

    for (final (name, screen, actions) in <(String, Widget, List<String>)>[
      ('ONB-01', const OnboardingView(), ['ONB-01.skip', 'ONB-01.lang']),
      ('AUT-01', const LoginView(), ['AUT-01.lang']),
    ]) {
      testWidgets('$name sağ üst eylemleriyle çakışmaz: kutular kesişmez, '
          'eylemin ortası eylemi vurur — tüm cihaz boyutları', (tester) async {
        for (final size in MatrixSize.values) {
          await tester.pumpApp(
            DebugMenuCornerButton(onPressed: () {}, child: screen),
            size: size.size,
            viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
          );
          await tester.pump();
          final handle = handleRect(tester);
          for (final action in actions) {
            final finder = find.byKey(GuKey.action(action));
            expect(finder, findsOneWidget, reason: '$action ${size.name}');
            // Etkin dokunma alanı (≥ 48 dp) dahil kesişme yok.
            final target = tester.getRect(finder).inflate(8);
            expect(
              handle.overlaps(target),
              isFalse,
              reason: '$action ${size.name}: $handle ↔ $target',
            );
            expect(
              hitsHandle(tester, tester.getCenter(finder)),
              isFalse,
              reason: '$action ${size.name}',
            );
            // Eylemin ortasına dokunma eylemin kendisine ulaşır.
            expect(
              hits(tester, tester.getCenter(finder), finder),
              isTrue,
              reason: '$action ${size.name}',
            );
          }
        }
      });
    }
  });
}

/// [node], [ancestor]'ın kendisi ya da torunu mu?
bool _isWithin(RenderObject node, RenderObject ancestor) {
  RenderObject? current = node;
  while (current != null) {
    if (current == ancestor) return true;
    current = current.parent;
  }
  return false;
}
