// SET-04 · Hakkında — başlık (amblem, ad, "v{sürüm} · Demo sürümü",
// açıklama), ekip, lisanslar (açılır + "Lisansı görüntüle" → DLG-32), sürüm
// notları (açılır), koşullar / gizlilik (AUT-06 push) / destek (SET-05),
// geri, aksiyon envanteri, cihaz matrisi, açık + koyu golden.
// Referans: design/reference-shots/screens/SET-04__*.webp,
// design/prototype/app/screens-profile.js:95–103.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/settings/constants/about_content.dart';
import 'package:gu_kulupler/features/settings/provider/about_state.dart';
import 'package:gu_kulupler/features/settings/provider/about_view_model.dart';
import 'package:gu_kulupler/features/settings/view/about_view.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_session_states.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';

Key _k(String action) => GuKey.action('SET-04.$action');

const AboutState _expanded = AboutState(
  version: '1.0.0',
  buildNumber: '1',
  openLicenses: {
    AboutLicense.lucide,
    AboutLicense.montserrat,
    AboutLicense.inter,
  },
  isReleaseNotesOpen: true,
);

List<Override> _overrides([AboutState? state]) => [
  if (state != null)
    aboutViewModelProvider.overrideWithBuild((ref, notifier) => state),
];

Future<void> _pump(WidgetTester tester, {AboutState? state}) async {
  await tester.pumpApp(const AboutView(), overrides: _overrides(state));
  await tester.pump();
}

Future<GoRouter> _pumpRoute(WidgetTester tester) async {
  GoRouter? created;
  await tester.pumpAppRouter(
    routerOf: (_) => created ??= GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(path: '/start', builder: (_, _) => const _Stub('/start')),
        GoRoute(
          path: '/legal/:tip',
          builder: (_, state) => _Stub(state.uri.path),
        ),
        GoRoute(
          path: '/profile/settings',
          builder: (_, _) => const _Stub('/profile/settings'),
          routes: [
            GoRoute(path: 'about', builder: (_, _) => const AboutView()),
            GoRoute(
              path: 'support',
              builder: (_, state) => _Stub(state.uri.path),
            ),
          ],
        ),
      ],
    ),
    overrides: [
      sessionViewModelProvider.overrideWithBuild(
        (ref, notifier) => FakeSessionStates.active,
      ),
    ],
  );
  final router = created!;
  addTearDown(router.dispose);
  router.go('/profile/settings/about');
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
  group('SET-04 · Hakkında · içerik', () {
    testWidgets('başlık, ekip, lisanslar, sürüm notları, bağlantılar', (
      tester,
    ) async {
      await _pump(tester);
      final l10n = tester.l10n;
      expect(find.byType(GuLogo), findsOneWidget);
      expect(find.text(AppConstants.appName), findsOneWidget);
      expect(find.text('v1.0.0 · ${l10n.aboutBuild}'), findsOneWidget);
      expect(find.text(l10n.aboutDesc), findsOneWidget);
      for (final member in AboutContent.team) {
        expect(find.text(member.name), findsOneWidget);
      }
      for (final license in AboutLicense.values) {
        expect(find.text(license.title), findsOneWidget);
      }
      expect(find.text(l10n.aboutLicenseLucide), findsNothing);
      expect(find.text(l10n.aboutNote1), findsNothing);
      expect(find.text(l10n.legalKosullarTitle), findsOneWidget);
      expect(find.text(l10n.supportTitle), findsOneWidget);
    });

    testWidgets('aksiyon envanteri', (tester) async {
      await _pump(tester);
      expectActionInventory(tester, 'SET-04');
    });
  });

  group('SET-04 · Hakkında · aksiyonlar', () {
    testWidgets('lisans satırı açılır → açıklama + "Lisansı görüntüle" → '
        'DLG-32; sürüm notları açılır', (tester) async {
      await _pump(tester);
      final l10n = tester.l10n;
      await tester.tap(find.byKey(_k('license.lucide')));
      await tester.pump();
      expect(find.text(l10n.aboutLicenseLucide), findsOneWidget);
      await tester.ensureVisible(find.byKey(_k('licenseLink.lucide')));
      await tester.tap(find.byKey(_k('licenseLink.lucide')));
      await tester.pump();
      final feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
      expect(feedback.dialogs, [DialogId.dlg32]);

      await tester.ensureVisible(find.byKey(_k('releaseNotes')));
      await tester.tap(find.byKey(_k('releaseNotes')));
      await tester.pump();
      expect(find.text(l10n.aboutNote4), findsOneWidget);
    });

    testWidgets('koşullar / gizlilik → AUT-06 (push); destek → SET-05; '
        'geri → SET-01', (tester) async {
      Future<void> tapAt(String action) async {
        await tester.ensureVisible(find.byKey(_k(action)));
        await tester.tap(find.byKey(_k(action)));
        await tester.pumpAndSettle();
      }

      // `push`: yığına eklenir, temel konum değişmez; geri AboutView'a döner.
      var router = await _pumpRoute(tester);
      for (final (action, path) in [
        ('terms', '/legal/kosullar'),
        ('privacy', '/legal/gizlilik'),
      ]) {
        await tapAt(action);
        expect(find.text(path), findsOneWidget, reason: path);
        expect(router.canPop(), isTrue);
        router.pop();
        await tester.pumpAndSettle();
        expect(find.byType(AboutView), findsOneWidget);
      }

      router = await _pumpRoute(tester);
      await tapAt('support');
      expect(_location(router), '/profile/settings/support');

      router = await _pumpRoute(tester);
      await tester.tap(find.byKey(_k('back')));
      await tester.pumpAndSettle();
      expect(_location(router), '/profile/settings');
    });
  });

  group('SET-04 · Hakkında · cihaz matrisi', () {
    testWidgets('kapalı (güvenli alan) ve tüm satırlar açık', (tester) async {
      Widget view(BuildContext context) => const AboutView();
      await DeviceMatrix.run(tester, view, safeAreas: true);
      await DeviceMatrix.run(tester, view, overrides: _overrides(_expanded));
    });
  });

  group('SET-04 · Hakkında · golden', () {
    // Amblem PNG'si çözülmüş hâlde (kod çözme motor tarafındadır →
    // `runAsync`; AUT-01 kalıbı).
    testWidgets('varsayılan (açık + koyu)', (tester) async {
      const locale = Locale('tr');
      for (final theme in kGoldenThemes) {
        await tester.pumpApp(const AboutView(), theme: theme);
        final logo = find.descendant(
          of: find.byType(GuLogo),
          matching: find.byType(Image),
        );
        final image = tester.widget<Image>(logo);
        await tester.runAsync(
          () => precacheImage(image.image, tester.element(logo)),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(kPumpAppBoundaryKey),
          matchesGoldenFile(goldenUri(goldenPath('SET-04', theme, locale))),
        );
      }
    });
  });
}
