// SET-02 · Engellenen kullanıcılar — açıklama, satır ("Bölüm · N. sınıf",
// "Engeli kaldır"), aksiyon envanteri, durumlar (yükleniyor, hata, boş,
// çevrimdışı), aksiyon sonuçları (CLB-07, geri, engeli kaldır → TST-09 +
// "Geri al"), cihaz matrisi, açık + koyu golden.
// Referans: design/reference-shots/screens/SET-02__*.webp,
// design/prototype/app/screens-profile.js:73–76.
//
// * Durum kipi: ViewModel durumu ezilir (okuma yok).
// * Akış kipi: gerçek ViewModel + sahte depolar + yer tutucu rotalar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/settings/provider/blocked_users_state.dart';
import 'package:gu_kulupler/features/settings/provider/blocked_users_view_model.dart';
import 'package:gu_kulupler/features/settings/view/blocked_users_view.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_kulupler/product/widget/member/user_row.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_block_repository.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../helpers/a11y_guidelines.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';
import '../blocked_users_test_support.dart';

Key _k(String action) => GuKey.action('SET-02.$action');

/// Durum kipi: oturum + ViewModel durumu ezilir.
List<Override> _overrides([BlockedUsersState? state]) => [
  sessionViewModelProvider.overrideWithBuild(
    (ref, notifier) => blockedSession(),
  ),
  blockedUsersViewModelProvider.overrideWithBuild(
    (ref, notifier) => state ?? loadedBlocked(),
  ),
];

Future<void> _pump(WidgetTester tester, {BlockedUsersState? state}) async {
  await tester.pumpApp(const BlockedUsersView(), overrides: _overrides(state));
  await tester.pump();
}

/// Akış kipi: gerçek ViewModel ve yer tutucu rotalar.
Future<GoRouter> _pumpRoute(WidgetTester tester) async {
  GoRouter? created;
  await tester.pumpAppRouter(
    routerOf: (_) => created ??= GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(path: '/start', builder: (_, _) => const _Stub('/start')),
        GoRoute(
          path: '/profile/settings',
          builder: (_, _) => const _Stub('/profile/settings'),
          routes: [
            GoRoute(
              path: 'blocked',
              builder: (_, _) => const BlockedUsersView(),
              routes: [
                GoRoute(
                  path: ':userId',
                  builder: (_, state) => _Stub(state.uri.path),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    overrides: [
      sessionViewModelProvider.overrideWithBuild(
        (ref, notifier) => blockedSession(),
      ),
    ],
  );
  final router = created!;
  addTearDown(router.dispose);
  seedBlocked();
  router.go('/profile/settings/blocked');
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
  group('SET-02 · Engellenenler · içerik', () {
    testWidgets('açıklama + satır: ad, "Kimya · 2. sınıf", "Engeli kaldır"', (
      tester,
    ) async {
      await _pump(tester);
      final l10n = tester.l10n;
      expect(find.text(l10n.blockedTitle), findsOneWidget);
      expect(find.text(l10n.blockedDesc), findsOneWidget);
      expect(find.text(kBlockedEren.name), findsOneWidget);
      expect(find.text('Kimya · 2. sınıf'), findsOneWidget);
      final button = tester.widget<GuButton>(find.byKey(_k('unblock.u042')));
      expect(button.label, l10n.userprofileUnblock);
      expect(button.variant, GuButtonVariant.outline);
      expect(button.size, GuButtonSize.sm);
      await expectA11yGuidelines(tester);
    });

    testWidgets('aksiyon envanteri', (tester) async {
      await _pump(tester);
      expectActionInventory(tester, 'SET-02');
    });
  });

  group('SET-02 · Engellenenler · durumlar', () {
    testWidgets('yükleniyor → iskelet; hata → "Yeniden dene"; boş → '
        '"Kimseyi engellemedin." (illüstrasyon)', (tester) async {
      await _pump(tester, state: const BlockedUsersState(isFetching: true));
      final l10n = tester.l10n;
      expect(find.byType(GuSkeletonList), findsOneWidget);
      expect(find.byType(UserRow), findsNothing);

      await _pump(tester, state: const BlockedUsersState(isError: true));
      expect(find.byKey(_k('retry')), findsOneWidget);

      await _pump(tester, state: const BlockedUsersState());
      expect(find.text(l10n.blockedEmpty), findsOneWidget);
      final empty = tester.widget<GuEmptyState>(find.byType(GuEmptyState));
      expect(empty.illustration, GuIllustrations.emptyClubs);
      expect(find.text(l10n.blockedDesc), findsOneWidget);
    });
  });

  group('SET-02 · Engellenenler · aksiyonlar', () {
    testWidgets('satır → CLB-07; geri → SET-01', (tester) async {
      var router = await _pumpRoute(tester);
      await tester.tap(find.byKey(_k('user.u042')));
      await tester.pumpAndSettle();
      expect(_location(router), '/profile/settings/blocked/u042');

      router = await _pumpRoute(tester);
      await tester.tap(find.byKey(_k('back')));
      await tester.pumpAndSettle();
      expect(_location(router), '/profile/settings');
    });

    testWidgets('engeli kaldır → satır düşer + TST-09; "Geri al" → geri '
        'gelir', (tester) async {
      await _pumpRoute(tester);
      final feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
      await tester.tap(find.byKey(_k('unblock.u042')));
      await tester.pumpAndSettle();
      expect(feedback.toasts, [ToastId.tst09]);
      expect(find.byKey(_k('user.u042')), findsNothing);
      expect(find.text(tester.l10n.blockedEmpty), findsOneWidget);
      feedback.tapToastAction();
      await tester.pumpAndSettle();
      expect(find.byKey(_k('user.u042')), findsOneWidget);
    });

    testWidgets('çevrimdışı: satır kalır; kaldırma TST-24 verir, yazılmaz', (
      tester,
    ) async {
      await _pumpRoute(tester);
      (GetIt.I<ConnectivityService>() as FakeConnectivityService).isOffline =
          true;
      final feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
      await tester.tap(find.byKey(_k('unblock.u042')));
      await tester.pumpAndSettle();
      expect(feedback.toasts, [ToastId.tst24]);
      expect(
        (GetIt.I<BlockRepository>() as FakeBlockRepository).callsTo(
          'softDeleteBlock',
        ),
        isEmpty,
      );
      expect(find.byKey(_k('user.u042')), findsOneWidget);
    });
  });

  group('SET-02 · Engellenenler · cihaz matrisi', () {
    testWidgets('dolu (güvenli alan); boş, hata', (tester) async {
      Widget view(BuildContext context) => const BlockedUsersView();
      await DeviceMatrix.run(
        tester,
        view,
        overrides: _overrides(loadedBlocked([kBlockedEren, kBlockedAyse])),
        safeAreas: true,
      );
      for (final state in [
        const BlockedUsersState(),
        const BlockedUsersState(isError: true),
      ]) {
        await DeviceMatrix.run(tester, view, overrides: _overrides(state));
      }
    });
  });

  group('SET-02 · Engellenenler · golden', () {
    testWidgets('varsayılan (açık + koyu)', (tester) async {
      await goldenForThemes(
        tester,
        'SET-02',
        const BlockedUsersView(),
        overrides: _overrides(),
      );
    });
  });
}
