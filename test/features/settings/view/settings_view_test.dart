// SET-01 · Ayarlar — içerik (beş grup, büyük harfli başlıklar, seçili tema /
// dil, yazı boyutu bölmesi, sürüm satırı), aksiyon envanteri, aksiyon
// sonuçları (SHT-17 / SHT-01 / SHT-32, NTF-02 / SET-02 / SET-04 / SET-05
// `go`, AUT-06 `push`, DLG-06 çıkış, geri, "Hesabı sil" T-29 borcu), yazı
// boyutu kalıcılığı (yeniden açılış), cihaz matrisi, açık + koyu golden.
// Ekranın yükleniyor / boş / hata durumu yoktur (yerel tercihler).
// Referans: design/reference-shots/screens/SET-01__*.webp,
// design/prototype/app/screens-profile.js:60–70.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/settings/view/settings_view.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/init/app_preferences_view_model.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_app_preferences_store.dart';
import '../../../fakes/fake_auth_repository.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_session_states.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/semantics_scan.dart';
import '../../../helpers/test_container.dart';
import '../../../helpers/test_l10n.dart';

Key _k(String action) => GuKey.action('SET-01.$action');

/// Tüm satırların çizildiği uzun görünüm (envanter, içerik).
const Size _tall = Size(390, 1800);

final List<Override> _overrides = [
  sessionViewModelProvider.overrideWithBuild(
    (_, _) => FakeSessionStates.active,
  ),
];

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

FakeAppPreferencesStore _store() =>
    GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore;

Future<void> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('tr'),
}) async {
  await tester.pumpApp(
    const SettingsView(),
    size: _tall,
    locale: locale,
    overrides: _overrides,
  );
  await tester.pump();
}

/// Akış kipi: `/profile/settings` + yer tutucu hedef rotalar.
Future<GoRouter> _pumpRoute(WidgetTester tester) async {
  GoRouter? created;
  GoRoute stub(String path) =>
      GoRoute(path: path, builder: (_, state) => _Stub(state.uri.toString()));
  await tester.pumpAppRouter(
    size: _tall,
    routerOf: (_) => created ??= GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (_, state) => _Stub(state.uri.toString()),
          routes: [
            GoRoute(
              path: 'settings',
              builder: (_, _) => const SettingsView(),
              routes: [
                stub('notifications'),
                stub('blocked'),
                stub('about'),
                stub('support'),
                stub('delete'),
              ],
            ),
          ],
        ),
        stub('/legal/:tip'),
      ],
    ),
    overrides: _overrides,
  );
  final router = created!;
  addTearDown(router.dispose);
  router.go('/profile/settings');
  await tester.pumpAndSettle();
  return router;
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

class _Stub extends StatelessWidget {
  const _Stub(this.path);

  final String path;

  @override
  Widget build(BuildContext context) => Scaffold(body: Text(path));
}

void main() {
  group('SET-01 · Ayarlar · içerik', () {
    testWidgets('TR: başlık, büyük harfli beş grup, satırlar, seçili tema / '
        'dil, yazı boyutu, sürüm', (tester) async {
      await _pump(tester);
      final l10n = tester.l10n;
      expect(find.text(l10n.settingsTitle), findsOneWidget);
      for (final title in [
        'GÖRÜNÜM',
        'BİLDİRİMLER',
        'GİZLİLİK VE GÜVENLİK',
        'DESTEK',
        'HESAP',
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      for (final label in [
        l10n.settingsTheme,
        l10n.settingsLanguage,
        l10n.settingsTextSize,
        l10n.settingsTextPreview,
        l10n.notifPrefsTitle,
        l10n.blockedTitle,
        l10n.settingsPrivacyPolicy,
        l10n.settingsChangePassword,
        l10n.supportTitle,
        l10n.aboutTitle,
        l10n.authLogout,
        l10n.deleteAccountTitle,
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      // Tercih yok: sistem teması; etkin dil Türkçe.
      expect(find.text(l10n.themeSystem), findsOneWidget);
      expect(find.text('Türkçe'), findsOneWidget);
      for (final label in ['%100', '%130', '%160']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Aa'), findsOneWidget);
      expect(find.text('v1.0.0'), findsOneWidget);
      // Çıkışta ok yok; "Hesabı sil" yıkıcı.
      expect(
        tester
            .widget<GuTile>(
              find.descendant(
                of: find.byKey(_k('logout')),
                matching: find.byType(GuTile),
              ),
            )
            .chevron,
        isFalse,
      );
      expect(
        tester
            .widget<GuTile>(
              find.descendant(
                of: find.byKey(_k('delete')),
                matching: find.byType(GuTile),
              ),
            )
            .danger,
        isTrue,
      );
    });

    testWidgets('EN: yüzdeler yerel ayara göre, dil "English"', (
      tester,
    ) async {
      await _pump(tester, locale: const Locale('en'));
      expect(find.text('APPEARANCE'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      for (final label in ['100%', '130%', '160%']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('kayıtlı tercih: tema "Koyu", ölçek %130 seçili', (
      tester,
    ) async {
      await _pump(tester);
      _store().values
        ..[AppPreferenceKeys.themeMode] = 'dark'
        ..[AppPreferenceKeys.textScale] = 's130';
      await ProviderScope.containerOf(
        tester.element(find.byType(SettingsView)),
      ).read(appPreferencesViewModelProvider.notifier).load();
      await tester.pump();
      expect(find.text(tester.l10n.themeDark), findsOneWidget);
      expect(
        tester.widget<GuSegmented>(find.byType(GuSegmented)).value,
        GuTextScaleLevel.s130.name,
      );
    });
  });

  group('SET-01 · Ayarlar · aksiyon envanteri', () {
    testWidgets('envanterdeki anahtarlar birebir', (tester) async {
      await _pump(tester);
      expectActionInventory(tester, 'SET-01');
    });
  });

  group('SET-01 · Ayarlar · aksiyonlar', () {
    for (final (action, location) in [
      ('notifications', '/profile/settings/notifications'),
      ('blocked', '/profile/settings/blocked'),
      ('support', '/profile/settings/support'),
      ('about', '/profile/settings/about'),
      // T-29 · W-33: "Hesabı sil" → SET-03.
      ('delete', '/profile/settings/delete'),
      ('back', '/profile'),
    ]) {
      testWidgets('$action → $location', (tester) async {
        final router = await _pumpRoute(tester);
        await tester.tap(find.byKey(_k(action)));
        await tester.pumpAndSettle();
        expect(_location(router), location);
      });
    }

    testWidgets('privacy → AUT-06 gizlilik sekmesi, geçici sayfa (push): '
        'geri SET-01’e döner', (tester) async {
      final router = await _pumpRoute(tester);
      await tester.tap(find.byKey(_k('privacy')));
      await tester.pumpAndSettle();
      expect(find.text('/legal/gizlilik'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(_location(router), '/profile/settings');
      expect(find.byType(SettingsView), findsOneWidget);
    });

    for (final (action, sheet) in [
      ('theme', SheetId.sht17),
      ('language', SheetId.sht01),
      ('password', SheetId.sht32),
    ]) {
      testWidgets('$action → ${sheet.designId}', (tester) async {
        await _pump(tester);
        await tester.tap(find.byKey(_k(action)));
        await tester.pumpAndSettle();
        expect(_feedback().sheets, [sheet]);
      });
    }

    testWidgets('çıkış → DLG-06; onayda oturum kapanır', (tester) async {
      await _pump(tester);
      final auth = GetIt.I<AuthRepository>() as FakeAuthRepository;
      _feedback().nextDialogResult = false;
      await tester.tap(find.byKey(_k('logout')));
      await tester.pumpAndSettle();
      expect(_feedback().dialogs, [DialogId.dlg06]);
      expect(auth.callsTo('signOut'), isEmpty);
      _feedback().nextDialogResult = true;
      await tester.tap(find.byKey(_k('logout')));
      await tester.pumpAndSettle();
      expect(auth.callsTo('signOut'), hasLength(1));
    });
  });

  group('SET-01 · Ayarlar · yazı boyutu kalıcılığı', () {
    testWidgets('%160 → hemen uygulanır, depoya yazılır, yeniden açılışta '
        'korunur', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(_k('textScale.1.6')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<GuSegmented>(find.byType(GuSegmented)).value,
        GuTextScaleLevel.s160.name,
      );
      expect(_store().values[AppPreferenceKeys.textScale], 's160');
      final reopened = createContainer();
      expect(
        reopened.read(appPreferencesViewModelProvider).textScale,
        GuTextScaleLevel.s160,
      );
      await tester.tap(find.byKey(_k('textScale.1')));
      await tester.pumpAndSettle();
      expect(_store().values[AppPreferenceKeys.textScale], 's100');
    });
  });

  group('SET-01 · Ayarlar · cihaz matrisi', () {
    testWidgets('taşma yok (güvenli alan dahil)', (tester) async {
      await DeviceMatrix.run(
        tester,
        (_) => const SettingsView(),
        overrides: _overrides,
        safeAreas: true,
      );
    });

    testWidgets('semantik: kaydırma boyunca rol doğrulaması hatasız '
        '(yazı boyutu GuSegmented; iOS + Android)', (tester) async {
      await expectSemanticsCleanWhileScrolling(
        tester,
        // `CustomScrollView` + kısa görünüm + 1.6: önbellek kenarı bölmenin
        // içinden geçer (eski kodda iOS'ta "a TabBar cannot be empty").
        (platform) => tester.pumpApp(
          const SettingsView(),
          overrides: _overrides,
          size: const Size(320, 568),
          textScale: 1.6,
          platform: platform,
        ),
      );
    });
  });

  group('SET-01 · Ayarlar · golden', () {
    testWidgets('varsayılan (açık + koyu)', (tester) async {
      await goldenForThemes(
        tester,
        'SET-01',
        const SettingsView(),
        overrides: _overrides,
      );
    });
  });
}
