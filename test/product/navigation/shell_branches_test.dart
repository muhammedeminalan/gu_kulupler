// T-11 · Kabuk dalları ve alt sekme çubuğu: dal sırası, görünür sekmeler
// (admin yalnızca süper admin), sekme ↔ dal eşlemesi, `NAV.tab.*` aksiyon
// anahtarları (K-17), etiketler (PLAN §13.2, §13.5; navigation.md §2).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/shell/app_shell_view.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fakes/fake_session_states.dart';
import '../../fakes/test_router.dart';
import '../../helpers/action_inventory.dart';
import '../../helpers/design_files.dart';
import '../../helpers/design_ids.dart';
import '../../helpers/device_matrix.dart';
import '../../helpers/pump_app.dart';

/// Envanterde [screenId] sekme kökünün beklediği kabuk anahtarları.
Set<String> _navKeysOf(String screenId) => {
  for (final action in DesignIds.screenMeta[screenId]!.actions)
    if (action.startsWith('$kNavPrefix.')) action,
};

void main() {
  group('T-11 · kabuk dalları', () {
    test('dal sırası registry.json#tabs ile aynıdır', () {
      final registry = readJsonMap('design/extracted/registry.json');
      expect(
        GuTab.values.map((tab) => tab.name),
        (registry['tabs'] as List<dynamic>).cast<String>(),
      );
    });

    test('görünür sekmeler: süper admin değilse 4, süper adminde 5', () {
      expect(AppShellView.visibleTabs(isSuperAdmin: false), [
        GuTab.clubs,
        GuTab.events,
        GuTab.notifications,
        GuTab.profile,
      ]);
      expect(AppShellView.visibleTabs(isSuperAdmin: true), GuTab.values);
    });

    test('NAV.tab.* anahtarları tek tanımdır ve sekme adıyla eşleşir', () {
      expect(AppShellView.tabKeys.keys, GuTab.values);
      for (final tab in GuTab.values) {
        expect(AppShellView.tabKeys[tab], GuKey.action('NAV.tab.${tab.name}'));
      }
    });

    test('NAV.tab.* literalleri yalnızca kabuk dosyasındadır (K-17)', () {
      final files = [
        for (final entity in Directory('$repoRoot/lib').listSync(
          recursive: true,
        ))
          if (entity is File &&
              entity.path.endsWith('.dart') &&
              !entity.path.endsWith('.g.dart') &&
              entity.readAsStringSync().contains("'NAV."))
            entity.path.substring(repoRoot.length + 1),
      ];
      expect(files, ['lib/product/navigation/shell/app_shell_view.dart']);
    });
  });

  group('T-11 · AppShellView · alt sekme çubuğu', () {
    Future<TestRouter> pump(
      WidgetTester tester, {
      SessionState session = FakeSessionStates.active,
      String location = AppPaths.clubs,
    }) => TestRouter.pumpShell(tester, session: session, location: location);

    testWidgets('süper admin değil: 4 sekme, admin anahtarı yok', (
      tester,
    ) async {
      await pump(tester);
      expect(ActionInventory.found(tester), {
        'NAV.tab.clubs',
        'NAV.tab.events',
        'NAV.tab.notifications',
        'NAV.tab.profile',
      });
      expect(find.byKey(GuKey.action('NAV.tab.admin')), findsNothing);
      // Envanter: sıradan kullanıcının sekme kökü (CLB-01).
      expect(ActionInventory.found(tester), _navKeysOf('CLB-01'));
    });

    testWidgets('süper admin: 5 sekme, admin anahtarı var', (tester) async {
      await pump(tester, session: FakeSessionStates.activeSuper);
      expect(ActionInventory.found(tester), {
        'NAV.tab.clubs',
        'NAV.tab.events',
        'NAV.tab.notifications',
        'NAV.tab.admin',
        'NAV.tab.profile',
      });
      // Envanter: süper adminin sekme kökü (ADM-01).
      expect(ActionInventory.found(tester), _navKeysOf('ADM-01'));
    });

    testWidgets('kulüp yöneticisi ve danışman admin sekmesini görmez', (
      tester,
    ) async {
      for (final session in [
        FakeSessionStates.activeManager('c01'),
        FakeSessionStates.activeAdvisor('c01'),
      ]) {
        await pump(tester, session: session);
        expect(find.byKey(GuKey.action('NAV.tab.admin')), findsNothing);
        expect(
          tester.widget<GuBottomNav>(find.byType(GuBottomNav)).items,
          hasLength(4),
        );
      }
    });

    testWidgets('claim değişince admin sekmesi eklenir / kalkar', (
      tester,
    ) async {
      final app = await pump(tester);
      expect(find.byKey(GuKey.action('NAV.tab.admin')), findsNothing);

      app.session = FakeSessionStates.activeSuper;
      await tester.pumpAndSettle();
      expect(find.byKey(GuKey.action('NAV.tab.admin')), findsOneWidget);

      app.session = FakeSessionStates.active;
      await tester.pumpAndSettle();
      expect(find.byKey(GuKey.action('NAV.tab.admin')), findsNothing);
    });

    testWidgets('sekme ↔ dal eşlemesi: her sekme kendi köküne götürür '
        '(4 sekme)', (tester) async {
      final app = await pump(tester);
      for (final tab in AppShellView.visibleTabs(isSuperAdmin: false)) {
        await app.tapTab(tab);
        expect(app.location, tab.rootPath, reason: tab.name);
        expect(app.currentTab, tab, reason: tab.name);
        expect(find.text(tab.rootPath), findsOneWidget, reason: tab.name);
      }
    });

    testWidgets('sekme ↔ dal eşlemesi: admin araya girince sıra kaymaz '
        '(5 sekme)', (tester) async {
      final app = await pump(tester, session: FakeSessionStates.activeSuper);
      for (final tab in GuTab.values) {
        await app.tapTab(tab);
        expect(app.location, tab.rootPath, reason: tab.name);
        final nav = tester.widget<GuBottomNav>(find.byType(GuBottomNav));
        expect(nav.currentIndex, tab.index, reason: tab.name);
      }
    });

    testWidgets('seçili sekme etkin dalı izler (4 sekmede profil = 3)', (
      tester,
    ) async {
      final app = await pump(tester, location: '/profile');
      GuBottomNav nav() => tester.widget<GuBottomNav>(find.byType(GuBottomNav));
      expect(nav().currentIndex, 3);
      await app.tapTab(GuTab.events);
      expect(nav().currentIndex, 1);
    });

    testWidgets('etiketler ve erişilebilirlik adı ARB’den (TR / EN)', (
      tester,
    ) async {
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = lookupAppLocalizations(locale);
        await tester.pumpApp(
          const SizedBox.shrink(),
          wrapInShell: true,
          locale: locale,
        );
        await tester.pumpAndSettle();
        final nav = tester.widget<GuBottomNav>(find.byType(GuBottomNav));
        expect(nav.items.map((item) => item.label), [
          l10n.navClubs,
          l10n.navEvents,
          l10n.navNotifications,
          l10n.navProfile,
        ]);
        expect(nav.semanticLabel, l10n.a11yMainNav);
      }
    });

    testWidgets('ikonlar tasarımdaki sekme ikonlarıdır', (tester) async {
      await pump(tester, session: FakeSessionStates.activeSuper);
      final nav = tester.widget<GuBottomNav>(find.byType(GuBottomNav));
      expect(nav.items.map((item) => item.icon), [
        GuIcons.usersRound,
        GuIcons.calendar,
        GuIcons.bell,
        GuIcons.shieldCheck,
        GuIcons.user,
      ]);
    });

    testWidgets('okunmamış sayısı bağlanana kadar rozet yoktur', (
      tester,
    ) async {
      await pump(tester);
      final nav = tester.widget<GuBottomNav>(find.byType(GuBottomNav));
      expect(nav.items.map((item) => item.badge), everyElement(isNull));
    });

    testWidgets('seçili sekme semantikte işaretlidir', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, location: '/events');
      final l10n = lookupAppLocalizations(const Locale('tr'));
      expect(
        tester.getSemantics(find.byKey(GuKey.action('NAV.tab.events'))),
        isSemantics(
          label: l10n.navEvents,
          isSelected: true,
          isButton: true,
        ),
      );
      expect(
        tester.getSemantics(find.byKey(GuKey.action('NAV.tab.clubs'))),
        isSemantics(label: l10n.navClubs, isSelected: false),
      );
      handle.dispose();
    });
  });

  group('T-11 · AppShellView · cihaz matrisi', () {
    testWidgets('4 sekme her boyut / tema / dil / ölçekte taşmadan sığar', (
      tester,
    ) async {
      await DeviceMatrix.run(
        tester,
        (context) => const SizedBox.expand(),
        wrapInShell: true,
        safeAreas: true,
      );
    });

    testWidgets('5 sekme (süper admin) her boyut / tema / dil / ölçekte '
        'taşmadan sığar', (tester) async {
      await DeviceMatrix.run(
        tester,
        (context) => const SizedBox.expand(),
        wrapInShell: true,
        shellTab: GuTab.admin,
        safeAreas: true,
        overrides: [
          sessionViewModelProvider.overrideWithBuild(
            (ref, notifier) => FakeSessionStates.activeSuper,
          ),
        ],
      );
      expect(
        tester.widget<GuBottomNav>(find.byType(GuBottomNav)).items,
        hasLength(5),
      );
    });
  });
}
