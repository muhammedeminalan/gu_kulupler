import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/app_router.dart';
import 'package:gu_kulupler/product/navigation/shell/app_shell_view.dart';
import 'package:gu_ui/gu_ui.dart';

import 'action_inventory.dart';
import 'pump_app.dart';
import 'test_l10n.dart';

/// Çocuğun bağlamını yakalar.
class _Probe extends StatelessWidget {
  const _Probe(this.onBuild);

  final void Function(BuildContext context) onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild(context);
    return const SizedBox.shrink();
  }
}

final class _Marker {}

final Provider<String> _probeProvider = Provider<String>((ref) => 'gerçek');

void main() {
  group('T-02 · pumpApp (kök, PLAN §16.2)', () {
    testWidgets('varsayılanlar: TR · açık · 1.0 · 390×844 · Android', (
      tester,
    ) async {
      late BuildContext ctx;
      await tester.pumpApp(_Probe((c) => ctx = c));

      final mq = MediaQuery.of(ctx);
      expect(Localizations.localeOf(ctx), const Locale('tr'));
      expect(AppLocalizations.of(ctx).localeName, 'tr');
      expect(ctx.gu.isDark, isFalse);
      expect(ctx.gu.colors, GuColors.light);
      expect(mq.textScaler, TextScaler.noScaling);
      expect(mq.size, const Size(390, 844));
      expect(mq.viewPadding, EdgeInsets.zero);
      expect(mq.viewInsets, EdgeInsets.zero);
      expect(defaultTargetPlatform, TargetPlatform.android);
      expect(Theme.of(ctx).platform, TargetPlatform.android);
      expect(find.byKey(kPumpAppChildKey), findsOneWidget);
      expect(find.byKey(kPumpAppBoundaryKey), findsOneWidget);
      expect(find.byType(ProviderScope), findsOneWidget);
    });

    testWidgets('parametreler MediaQuery / tema / dil / platforma yansır', (
      tester,
    ) async {
      late BuildContext ctx;
      const padding = EdgeInsets.only(top: 59, bottom: 34);
      await tester.pumpApp(
        _Probe((c) => ctx = c),
        locale: const Locale('en'),
        theme: ThemeMode.dark,
        textScale: 1.3,
        size: const Size(430, 932),
        platform: TargetPlatform.iOS,
        viewPadding: padding,
        keyboardInset: 320,
      );

      final mq = MediaQuery.of(ctx);
      expect(Localizations.localeOf(ctx), const Locale('en'));
      expect(AppLocalizations.of(ctx).localeName, 'en');
      expect(ctx.gu.isDark, isTrue);
      expect(ctx.gu.colors, GuColors.dark);
      expect(mq.textScaler, const TextScaler.linear(1.3));
      expect(ctx.gu.textScaler, const TextScaler.linear(1.3));
      expect(mq.size, const Size(430, 932));
      expect(mq.viewPadding, padding);
      expect(mq.viewInsets, const EdgeInsets.only(bottom: 320));
      expect(mq.padding, const EdgeInsets.only(top: 59));
      expect(defaultTargetPlatform, TargetPlatform.iOS);
      expect(Theme.of(ctx).platform, TargetPlatform.iOS);
    });

    testWidgets("overrides ProviderScope'a geçer", (tester) async {
      late BuildContext ctx;
      await tester.pumpApp(
        _Probe((c) => ctx = c),
        overrides: [_probeProvider.overrideWithValue('sahte')],
      );
      final container = ProviderScope.containerOf(ctx);
      expect(container.read(_probeProvider), 'sahte');
    });

    testWidgets('GetIt her çağrıda sıfırlanır (+ registerDefaultFakes)', (
      tester,
    ) async {
      GetIt.I.registerSingleton<_Marker>(_Marker());
      expect(GetIt.I.isRegistered<_Marker>(), isTrue);
      await tester.pumpApp(const SizedBox.shrink());
      expect(GetIt.I.isRegistered<_Marker>(), isFalse);

      GetIt.I.registerSingleton<_Marker>(_Marker());
      await tester.pumpApp(const SizedBox.shrink());
      expect(GetIt.I.isRegistered<_Marker>(), isFalse);
    });

    testWidgets('görünüm boyutu, platform ve GetIt test sonunda geri alınır', (
      tester,
    ) async {
      final initialSize = tester.view.physicalSize;
      final initialRatio = tester.view.devicePixelRatio;
      // addTearDown LIFO: bu kontrol pumpApp'ın sıfırlamalarından sonra koşar.
      addTearDown(() {
        expect(tester.view.physicalSize, initialSize);
        expect(tester.view.devicePixelRatio, initialRatio);
        expect(debugDefaultTargetPlatformOverride, isNull);
        expect(GetIt.I.isRegistered<_Marker>(), isFalse);
      });
      await tester.pumpApp(
        const SizedBox.shrink(),
        size: const Size(320, 640),
        platform: TargetPlatform.iOS,
      );
      GetIt.I.registerSingleton<_Marker>(_Marker());
      expect(tester.view.physicalSize, const Size(320, 640));
      expect(tester.view.devicePixelRatio, kPumpAppDevicePixelRatio);
    });

    testWidgets('art arda çağrıda son platform geçerli', (tester) async {
      await tester.pumpApp(
        const SizedBox.shrink(),
        platform: TargetPlatform.iOS,
      );
      expect(defaultTargetPlatform, TargetPlatform.iOS);
      await tester.pumpApp(const SizedBox.shrink());
      expect(defaultTargetPlatform, TargetPlatform.android);
    });

    test('testMediaQuery: klavye alt dolguyu sıfırın altına indirmez', () {
      final data = testMediaQuery(
        const MediaQueryData(),
        textScale: 1.6,
        viewPadding: const EdgeInsets.only(top: 24, bottom: 48),
        keyboardInset: 20,
      );
      expect(data.padding, const EdgeInsets.only(top: 24, bottom: 28));
      expect(data.viewInsets, const EdgeInsets.only(bottom: 20));
      expect(data.textScaler, const TextScaler.linear(1.6));
    });
  });

  group('T-11 · pumpApp(wrapInShell:) ve pumpAppRouter (PLAN §16.2)', () {
    testWidgets('wrapInShell: çocuk gerçek kabukta, seçilen sekmenin kökü '
        'olarak çizilir', (tester) async {
      await tester.pumpApp(const Text('kök'), wrapInShell: true);
      await tester.pumpAndSettle();
      expect(find.byType(AppShellView), findsOneWidget);
      expect(find.text('kök'), findsOneWidget);
      expect(find.byKey(kPumpAppChildKey), findsOneWidget);
      final nav = tester.widget<GuBottomNav>(find.byType(GuBottomNav));
      expect(nav.items, hasLength(4));
      expect(nav.currentIndex, 0);
      expect(ActionInventory.found(tester), {
        'NAV.tab.clubs',
        'NAV.tab.events',
        'NAV.tab.notifications',
        'NAV.tab.profile',
      });
      // Çocuğun bağlamı yerelleştirmeyi görür (`tester.l10n`).
      expect(tester.l10n.navClubs, isNotEmpty);
    });

    testWidgets('wrapInShell + shellTab: seçili sekme o daldır', (
      tester,
    ) async {
      await tester.pumpApp(
        const Text('profil'),
        wrapInShell: true,
        shellTab: GuTab.profile,
      );
      await tester.pumpAndSettle();
      expect(find.text('profil'), findsOneWidget);
      // 4 sekmede profil son sıradadır.
      expect(
        tester.widget<GuBottomNav>(find.byType(GuBottomNav)).currentIndex,
        3,
      );
    });

    testWidgets('wrapInShell: parametreler (dil, boyut, güvenli alan) '
        'kabuğa da yansır', (tester) async {
      await tester.pumpApp(
        const SizedBox.expand(),
        wrapInShell: true,
        locale: const Locale('en'),
        size: const Size(320, 640),
        viewPadding: const EdgeInsets.only(bottom: 34),
      );
      await tester.pumpAndSettle();
      final nav = find.byType(GuBottomNav);
      expect(
        tester.widget<GuBottomNav>(nav).items.first.label,
        lookupAppLocalizations(const Locale('en')).navClubs,
      );
      expect(tester.getRect(nav).width, 320);
      expect(tester.getRect(nav).bottom, 640);
      // Çubuk gerçek alt güvenli alanı içerir (K-07).
      expect(tester.getRect(nav).height, GuSizes.bottomNavHeight + 34);
    });

    testWidgets('wrapInShell olmadan kabuk yoktur', (tester) async {
      await tester.pumpApp(const Text('düz'));
      expect(find.byType(AppShellView), findsNothing);
      expect(find.byType(GuBottomNav), findsNothing);
    });

    testWidgets('art arda wrapInShell çağrısı ağacı baştan kurar', (
      tester,
    ) async {
      await tester.pumpApp(const Text('bir'), wrapInShell: true);
      await tester.pumpApp(
        const Text('iki'),
        wrapInShell: true,
        shellTab: GuTab.events,
      );
      await tester.pumpAndSettle();
      expect(find.text('bir'), findsNothing);
      expect(find.text('iki'), findsOneWidget);
      expect(
        tester.widget<GuBottomNav>(find.byType(GuBottomNav)).currentIndex,
        1,
      );
    });

    testWidgets('pumpAppRouter: verilen router çizilir; fake kayıtları ve '
        'görünüm ayarları pumpApp ile aynıdır', (tester) async {
      final router = GoRouter(
        initialLocation: '/a',
        routes: [
          GoRoute(path: '/a', builder: (context, state) => const Text('A')),
          GoRoute(path: '/b', builder: (context, state) => const Text('B')),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpAppRouter(
        routerOf: (ref) => router,
        size: const Size(430, 932),
        theme: ThemeMode.dark,
      );
      expect(find.text('A'), findsOneWidget);
      expect(tester.view.physicalSize, const Size(430, 932));
      expect(
        Theme.of(tester.element(find.text('A'))).brightness,
        Brightness.dark,
      );
      expect(GetIt.I.isRegistered<FeedbackService>(), isTrue);

      router.go('/b');
      await tester.pumpAndSettle();
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('pumpAppRouter: router verilmezse uygulamanın gerçek '
        'router’ı açılış yolundan başlar', (tester) async {
      await tester.pumpAppRouter();
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      final router = container.read(appRouterProvider);
      // Varsayılan fake oturum yoktur: ilk açılış → tanıtım.
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        AppPaths.onboarding,
      );
    });
  });
}
