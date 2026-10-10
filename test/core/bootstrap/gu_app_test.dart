// T-11 · GuApp: MaterialApp.router + kök katman zinciri (PLAN §4.4, §15.11).
// Zincir sırası, tema / dil / metin ölçeği (AppPreferencesViewModel), cihaz
// dili çözümü, 480 dp sütun, toast alt boşluğu, çevrimdışı bandı (SYS-03) +
// TST-25, bakım bandı, DLG-26 / DLG-27 kapıları ve durum çubuğu stili.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/bootstrap/gu_app.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/system/debug_menu/view/widget/debug_menu_corner_button.dart';
import 'package:gu_kulupler/features/system/view/splash_view.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/init/app_gate_view_model.dart';
import 'package:gu_kulupler/product/init/app_preferences_state.dart';
import 'package:gu_kulupler/product/init/app_preferences_view_model.dart';
import 'package:gu_kulupler/product/navigation/app_router.dart';
import 'package:gu_kulupler/product/navigation/navigator_keys.dart';
import 'package:gu_kulupler/product/navigation/shell/app_shell_view.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_kulupler/product/widget/system/app_gate.dart';
import 'package:gu_kulupler/product/widget/system/maintenance_banner.dart';
import 'package:gu_kulupler/product/widget/system/offline_banner.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fakes/fake_connectivity_service.dart';
import '../../fakes/fake_feedback_service.dart';
import '../../fakes/fake_remote_config_service.dart';
import '../../fakes/fake_session_states.dart';
import '../../fakes/register_fakes.dart';
import '../../helpers/content_width_check.dart';
import '../../helpers/design_files.dart';

Override _session(SessionState state) =>
    sessionViewModelProvider.overrideWithBuild((ref, notifier) => state);

Override _preferences(AppPreferencesState state) =>
    appPreferencesViewModelProvider.overrideWithBuild((ref, notifier) => state);

/// Gerçek `GuApp`'i sahte servislerle çizer (varsayılan: aktif oturum →
/// `/clubs`).
Future<GuToastController> _pumpGuApp(
  WidgetTester tester, {
  SessionState session = FakeSessionStates.active,
  List<Override> overrides = const [],
  Size size = const Size(390, 844),
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await GetIt.I.reset();
  registerDefaultFakes();
  addTearDown(GetIt.I.reset);
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);
  final controller = GuToastController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [_session(session), ...overrides],
      child: GuApp(toastController: controller),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(GuApp)));

GoRouter _router(WidgetTester tester) =>
    _container(tester).read(appRouterProvider);

Future<void> _go(WidgetTester tester, String location) async {
  _router(tester).go(location);
  await tester.pumpAndSettle();
}

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

FakeConnectivityService _connectivity() =>
    GetIt.I<ConnectivityService>() as FakeConnectivityService;

void main() {
  group('T-11 · GuApp · builder zinciri', () {
    testWidgets('tek sıra (dıştan içe): GuTextScale → GuSystemUi → '
        'GuToastHost → GuContentColumn → OfflineBanner → MaintenanceBanner → '
        'AppGate → gezgin', (tester) async {
      await _pumpGuApp(tester);
      final chain = <Finder>[
        find.byType(GuTextScale),
        find.byType(GuSystemUi).first,
        find.byType(GuToastHost),
        find.byType(GuContentColumn).first,
        find.byType(OfflineBanner),
        find.byType(MaintenanceBanner),
        find.byType(AppGate),
        find.byKey(rootNavigatorKey),
      ];
      for (final layer in chain) {
        expect(layer, findsOneWidget);
      }
      for (var i = 0; i < chain.length - 1; i++) {
        expect(
          find.descendant(of: chain[i], matching: chain[i + 1]),
          findsOneWidget,
          reason: 'katman $i, katman ${i + 1}’i sarmalı',
        );
      }
      // Zincirin her katmanı tektir (ekranların kendi GuSystemUi'si hariç).
      expect(find.byType(GuTextScale), findsOneWidget);
      expect(find.byType(GuToastHost), findsOneWidget);
      // Metin ölçeği en dışta: MaterialApp'in hemen altında.
      expect(
        find.descendant(
          of: find.byType(MaterialApp),
          matching: find.byType(GuTextScale),
        ),
        findsOneWidget,
      );
    });

    testWidgets('kök metin stili (`.gu-root`): gezgin ve bantlar Material’in '
        '"stil yok" uyarı stilini (sarı alt çizgi) devralmaz', (tester) async {
      await _pumpGuApp(tester);
      _connectivity().emit(true);
      await tester.pumpAndSettle();
      for (final finder in [
        find.byKey(rootNavigatorKey),
        find.byType(GuBanner),
      ]) {
        final context = tester.element(finder);
        final style = DefaultTextStyle.of(context).style;
        expect(style, context.gu.text.bodyM);
        expect(style.decoration, isNot(TextDecoration.underline));
      }
      // Kök stil metin ölçeğinin ve durum çubuğu katmanının içindedir.
      expect(
        find.descendant(
          of: find.byType(GuSystemUi).first,
          matching: find.byType(GuToastHost),
        ),
        findsOneWidget,
      );
    });

    testWidgets('DebugMenu köşe düğmesi yalnızca debugMenuEnabled iken '
        '(test koşusunda kapalı)', (tester) async {
      await _pumpGuApp(tester);
      expect(find.byType(DebugMenuCornerButton), findsNothing);
      expect(find.byKey(DebugMenuCornerButton.openKey), findsNothing);
      // Koşul derleme sabitidir (release'te dal ağaçtan düşer).
      final source = readText('lib/core/bootstrap/gu_app.dart');
      expect(source, contains('if (AppEnvironment.debugMenuEnabled) {'));
    });

    testWidgets('MaterialApp.router: uygulama router’ı, tema çifti, başlık, '
        'hata ayıklama bandı yok', (tester) async {
      await _pumpGuApp(tester);
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.routerConfig, same(_router(tester)));
      expect(app.title, AppConstants.appName);
      expect(app.debugShowCheckedModeBanner, isFalse);
      expect(app.theme!.brightness, Brightness.light);
      expect(app.darkTheme!.brightness, Brightness.dark);
      expect(app.supportedLocales, AppLocalizations.supportedLocales);
      expect(find.byType(AppShellView), findsOneWidget);
    });

    testWidgets('oturum çözülmeden açılış ekranı (SYS-01)', (tester) async {
      await _pumpGuApp(tester, session: FakeSessionStates.unknown);
      expect(find.byType(SplashView), findsOneWidget);
      expect(
        _router(tester).routerDelegate.currentConfiguration.uri.toString(),
        '/splash',
      );
    });

    test('main.dart kökü GuApp ile kurar', () {
      final source = readText('lib/main.dart');
      expect(source, contains('GuApp(toastController: toastController)'));
      expect(source, isNot(contains('class GuApp')));
    });
  });

  group('T-11 · GuApp · tema, dil, metin ölçeği', () {
    testWidgets('tercihler uygulanır: koyu tema, İngilizce, %130', (
      tester,
    ) async {
      await _pumpGuApp(
        tester,
        overrides: [
          _preferences(
            const AppPreferencesState(
              themeMode: ThemeMode.dark,
              locale: Locale('en'),
              textScale: GuTextScaleLevel.s130,
              isLoaded: true,
            ),
          ),
        ],
      );
      final context = tester.element(find.byType(AppShellView));
      expect(context.gu.isDark, isTrue);
      expect(Localizations.localeOf(context), const Locale('en'));
      expect(AppLocalizations.of(context).localeName, 'en');
      expect(MediaQuery.textScalerOf(context).scale(10), closeTo(13, 1e-9));
    });

    testWidgets('varsayılan: sistem teması (açık), sistem dili, %100', (
      tester,
    ) async {
      await _pumpGuApp(tester);
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.system);
      expect(app.locale, isNull);
      final context = tester.element(find.byType(AppShellView));
      expect(context.gu.isDark, isFalse);
      expect(MediaQuery.textScalerOf(context).scale(10), 10);
    });

    testWidgets('tercih değişince anında yansır', (tester) async {
      await _pumpGuApp(tester);
      final preferences = _container(
        tester,
      ).read(appPreferencesViewModelProvider.notifier);
      await preferences.setThemeMode(ThemeMode.dark);
      await preferences.setLocale(const Locale('en'));
      await preferences.setTextScale(GuTextScaleLevel.s160);
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(AppShellView));
      expect(context.gu.isDark, isTrue);
      expect(Localizations.localeOf(context), const Locale('en'));
      expect(MediaQuery.textScalerOf(context).scale(10), closeTo(16, 1e-9));
    });

    testWidgets('metin ölçeği sistem ölçeğiyle çarpılır, tavan 1.6', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pumpGuApp(
        tester,
        overrides: [
          _preferences(
            const AppPreferencesState(textScale: GuTextScaleLevel.s130),
          ),
        ],
      );
      final context = tester.element(find.byType(AppShellView));
      expect(
        MediaQuery.textScalerOf(context).scale(10),
        closeTo(10 * GuTextScale.maxScale, 1e-9),
      );
    });

    testWidgets('cihaz dili desteklenmiyorsa Türkçe; İngilizce ise İngilizce', (
      tester,
    ) async {
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      for (final (device, expected) in const [
        (Locale('de', 'DE'), Locale('tr')),
        (Locale('en', 'US'), Locale('en')),
        (Locale('tr', 'TR'), Locale('tr')),
      ]) {
        tester.platformDispatcher.localesTestValue = [device];
        await _pumpGuApp(tester);
        expect(
          Localizations.localeOf(tester.element(find.byType(AppShellView))),
          expected,
          reason: '$device',
        );
      }
    });

    test('resolveLocale: en* → en, diğer her şey → tr', () {
      const supported = AppLocalizations.supportedLocales;
      Locale of(Locale? device) => GuApp.resolveLocale(device, supported);
      expect(of(const Locale('en')), const Locale('en'));
      expect(of(const Locale('en', 'GB')), const Locale('en'));
      expect(of(const Locale('tr', 'TR')), const Locale('tr'));
      expect(of(const Locale('fr')), GuApp.fallbackLocale);
      expect(of(null), GuApp.fallbackLocale);
      expect(GuApp.fallbackLocale, const Locale('tr'));
      expect(supported, contains(GuApp.fallbackLocale));
    });
  });

  group('T-11 · GuApp · yerleşim', () {
    testWidgets('telefon: gövde ekranı doldurur', (tester) async {
      await _pumpGuApp(tester);
      expectContentColumn(tester);
      expect(
        tester.getSize(find.byKey(rootNavigatorKey)),
        const Size(390, 844),
      );
    });

    testWidgets('tablet: gövde 480 dp ortalı sütunda (Q-13, CD-29)', (
      tester,
    ) async {
      await _pumpGuApp(tester, size: const Size(768, 1024));
      expectContentColumn(tester);
      final navigator = tester.getRect(find.byKey(rootNavigatorKey));
      expect(navigator.width, GuBreakpoints.maxContentWidth);
      expect(navigator.left, (768 - GuBreakpoints.maxContentWidth) / 2);
      expect(navigator.height, 1024);
    });

    testWidgets('480 dp eşiği aşılınca gövde yeniden kurulmaz (konum ve '
        'gezgin korunur)', (tester) async {
      await _pumpGuApp(tester);
      await _go(tester, '/not-found');
      final navigator = rootNavigatorKey.currentState;
      final router = tester.state(find.byType(Router<Object>));

      tester.view.physicalSize = const Size(768, 1024);
      await tester.pumpAndSettle();
      expect(rootNavigatorKey.currentState, same(navigator));
      expect(tester.state(find.byType(Router<Object>)), same(router));
      expect(
        _router(tester).routerDelegate.currentConfiguration.uri.toString(),
        '/not-found',
      );
      expect(
        tester.getSize(find.byKey(rootNavigatorKey)).width,
        GuBreakpoints.maxContentWidth,
      );
    });

    testWidgets('toast alt boşluğu: sekme kökünde alt çubuk kadar, diğer '
        'ekranlarda sıfır', (tester) async {
      await _pumpGuApp(tester);
      double inset() =>
          tester.widget<GuToastHost>(find.byType(GuToastHost)).bottomInset;
      expect(inset(), GuSizes.bottomNavHeight);

      await _go(tester, '/not-found');
      expect(inset(), 0);

      await _go(tester, '/profile');
      expect(inset(), GuSizes.bottomNavHeight);
    });

    testWidgets('toast denetleyicisi kökteki GuToastHost’a bağlıdır', (
      tester,
    ) async {
      final controller = await _pumpGuApp(tester);
      expect(
        tester.widget<GuToastHost>(find.byType(GuToastHost)).controller,
        same(controller),
      );
    });

    testWidgets('durum çubuğu stili kökten gelir: açık temada koyu ikon, '
        'şeffaf çubuk (D-20)', (tester) async {
      await _pumpGuApp(tester, session: FakeSessionStates.unknown);
      final style = SystemChrome.latestStyle!;
      expect(style.statusBarColor, Colors.transparent);
      expect(style.statusBarIconBrightness, Brightness.dark);
      expect(style.statusBarBrightness, Brightness.light);
    });
  });

  group('SYS-03 · GuApp · çevrimdışı bandı ve TST-25', () {
    testWidgets('kabukta: bağlantı kopunca bant gelir; dönünce kalkar ve '
        'TST-25 gösterilir', (tester) async {
      await _pumpGuApp(tester);
      expect(find.byType(GuBanner), findsNothing);

      _connectivity().emit(true);
      await tester.pumpAndSettle();
      final banner = tester.widget<GuBanner>(find.byType(GuBanner));
      expect(banner.kind, GuBannerKind.offline);
      expect(
        banner.text,
        AppLocalizations.of(
          tester.element(find.byType(AppShellView)),
        ).sysOfflineBanner,
      );
      // Bant gövdenin üstünde; gezgin bandın altından başlar.
      expect(
        tester.getRect(find.byKey(rootNavigatorKey)).top,
        tester.getRect(find.byType(GuBanner)).bottom,
      );
      expect(_feedback().toasts, isEmpty);

      _connectivity().emit(false);
      await tester.pumpAndSettle();
      expect(find.byType(GuBanner), findsNothing);
      expect(_feedback().toasts, [ToastId.tst25]);
    });

    testWidgets('kabuk dışında (açılış, sistem ekranları) bant gösterilmez', (
      tester,
    ) async {
      await _pumpGuApp(tester);
      _connectivity().emit(true);
      await tester.pumpAndSettle();
      expect(find.byType(GuBanner), findsOneWidget);

      await _go(tester, '/offline');
      expect(find.byType(GuBanner), findsNothing);

      await _go(tester, '/profile');
      expect(find.byType(GuBanner), findsOneWidget);
    });
  });

  group('T-11 · GuApp · bakım bandı (CD-48)', () {
    testWidgets('Remote Config mesajı çevrimdışı bandının altında gösterilir', (
      tester,
    ) async {
      await _pumpGuApp(tester);
      final config = GetIt.I<RemoteConfigService>() as FakeRemoteConfigService;
      config.values[RemoteConfigKeys.maintenanceMessage] = 'Bakım var';
      config.configUpdatedController.add(null);
      _connectivity().emit(true);
      await tester.pumpAndSettle();
      expect(
        tester.widgetList<GuBanner>(find.byType(GuBanner)).map((b) => b.kind),
        [GuBannerKind.offline, GuBannerKind.info],
      );
      expect(
        tester.getRect(find.byType(GuBanner).last).top,
        tester.getRect(find.byType(GuBanner).first).bottom,
      );
    });
  });

  group('DLG-26 · DLG-27 · GuApp · kök kapılar', () {
    testWidgets('güncelleme zorunlu olunca DLG-26 istenir', (tester) async {
      await _pumpGuApp(tester);
      expect(_feedback().dialogs, isEmpty);
      final config = GetIt.I<RemoteConfigService>() as FakeRemoteConfigService;
      config.values[RemoteConfigKeys.minSupportedBuild] = 99;
      config.configUpdatedController.add(null);
      await tester.pumpAndSettle();
      expect(_feedback().dialogs, [DialogId.dlg26]);
    });

    testWidgets('oturum sona erince DLG-27 istenir', (tester) async {
      await _pumpGuApp(tester);
      _container(
        tester,
      ).read(appGateViewModelProvider.notifier).onSessionExpired();
      await tester.pumpAndSettle();
      expect(_feedback().dialogs, [DialogId.dlg27]);
    });
  });
}
