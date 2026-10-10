// T-11 · DebugMenuView iskeleti (K-E, CD-69): tema / dil / metin ölçeği
// seçicileri tercihlere yazar; anahtarlar `debug.*` (tasarım envanteri
// dışı); cihaz matrisi. Köşe düğmesi (DebugMenuCornerButton) ayrıca.
// T-11 · DebugMenu · demo hesaplar (CD-132 (23)): yalnızca emülatörde altı
// hesap satırı → `signIn(e-posta, demo parolası)` + uygulamaya gidiş; hata
// satırı; "Çıkış yap"; SYS-02 / 03 / 04 kısayolları.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/system/debug_menu/provider/debug_demo_accounts.dart';
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

  group('T-11 · DebugMenuCornerButton', () {
    testWidgets('sağ üst köşede 32 dp düğme; anahtar `debug.open`; dokunma '
        'geri çağrıyı tetikler', (tester) async {
      var opened = 0;
      await tester.pumpApp(
        DebugMenuCornerButton(
          onPressed: () => opened++,
          child: const SizedBox.expand(key: ValueKey<String>('corner.child')),
        ),
        viewPadding: const EdgeInsets.only(top: 47),
      );
      expect(
        DebugMenuCornerButton.openKey,
        const ValueKey<String>('debug.open'),
      );
      final button = tester.widget<GuIconButton>(
        find.byKey(DebugMenuCornerButton.openKey),
      );
      expect(button.size, GuIconButtonSize.xs);
      // Üst güvenli alanın altında, sağ kenara yakın.
      final rect = tester.getRect(find.byKey(DebugMenuCornerButton.openKey));
      expect(rect.top, greaterThanOrEqualTo(47));
      expect(rect.right, lessThanOrEqualTo(390));
      expect(rect.left, greaterThan(390 / 2));
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
  });
}
