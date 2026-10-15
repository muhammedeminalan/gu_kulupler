// PRF-04 · Kaydedilenler — kart içeriği ("kulüp · göreli zaman", başlık, 2
// satır metin, yer imi), "İçerik kaldırıldı" satırı, aksiyon envanteri,
// durumlar (yükleniyor, hata, boş, çevrimdışı), aksiyon sonuçları (FED-02
// gezinmesi, kaydı kaldır → TST-11 + "Geri al"), cihaz matrisi, açık + koyu
// golden.
// Referans: design/reference-shots/screens/PRF-04__*.webp, states/PRF-04__*,
// design/prototype/app/screens-profile.js:52–56.
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
import 'package:gu_kulupler/features/profile/provider/saved_state.dart';
import 'package:gu_kulupler/features/profile/provider/saved_view_model.dart';
import 'package:gu_kulupler/features/profile/view/saved_view.dart';
import 'package:gu_kulupler/features/profile/view/widget/saved_post_card.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_saved_post_repository.dart';
import '../../../fakes/fake_session_states.dart';
import '../../../fixtures/club_model_fixtures.dart';
import '../../../helpers/a11y_guidelines.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';
import '../saved_test_support.dart';

Key _k(String action) => GuKey.action('PRF-04.$action');

/// Durum kipi: oturum + ViewModel durumu ezilir.
List<Override> _overrides([SavedState? state]) => [
  sessionViewModelProvider.overrideWithBuild(
    (ref, notifier) => FakeSessionStates.active,
  ),
  savedViewModelProvider.overrideWithBuild(
    (ref, notifier) => state ?? loadedSaved(),
  ),
];

Future<void> _pump(WidgetTester tester, {SavedState? state}) async {
  await tester.pumpApp(const SavedView(), overrides: _overrides(state));
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
          path: '/clubs/:clubId/posts/:postId',
          builder: (_, state) => _Stub(state.uri.path),
        ),
        GoRoute(
          path: '/profile',
          builder: (_, _) => const _Stub('/profile'),
          routes: [
            GoRoute(path: 'saved', builder: (_, _) => const SavedView()),
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
  seedSaved();
  router.go('/profile/saved');
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
  group('PRF-04 · Kaydedilenler · içerik', () {
    testWidgets('kartlar: "kulüp · zaman", başlık, metin, yer imi', (
      tester,
    ) async {
      await _pump(tester);
      final l10n = tester.l10n;
      expect(find.text(l10n.savedTitle), findsOneWidget);
      expect(find.byType(SavedPostCard), findsNWidgets(2));
      final club = ClubModelFixtures.byId('c01').name;
      expect(find.textContaining('$club · '), findsOneWidget);
      expect(find.text(kSavedP01.title!), findsOneWidget);
      expect(find.text(kSavedP21.text), findsOneWidget);
      final text = tester.widget<Text>(find.text(kSavedP21.text));
      expect(text.maxLines, 2);
      final button = tester.widget<GuIconButton>(
        find.byKey(_k('unsave.p01')),
      );
      expect(button.icon, GuIcons.bookmark);
      expect(button.tone, GuIconButtonTone.brand);
      await expectA11yGuidelines(tester);
    });

    testWidgets('kaldırılmış gönderi: "İçerik kaldırıldı", çöp kutusu, '
        'dokunulamaz', (tester) async {
      await _pump(
        tester,
        state: loadedSaved(entries: [(kSavedRecordP01, null)]),
      );
      final l10n = tester.l10n;
      expect(find.text(l10n.savedRemoved), findsOneWidget);
      final button = tester.widget<GuIconButton>(
        find.byKey(_k('unsave.p01')),
      );
      expect(button.icon, GuIcons.trash2);
      final card = tester.widget<GuCard>(find.byKey(_k('post.p01')));
      expect(card.onTap, isNull);
    });

    testWidgets('aksiyon envanteri', (tester) async {
      await _pump(tester);
      expectActionInventory(tester, 'PRF-04');
    });
  });

  group('PRF-04 · Kaydedilenler · durumlar', () {
    testWidgets('yükleniyor → kart iskeleti; hata → "Yeniden dene"; boş → '
        '"Kaydettiğin gönderiler burada görünür"', (tester) async {
      await _pump(tester, state: const SavedState(isFetching: true));
      final l10n = tester.l10n;
      final skeleton = tester.widget<GuSkeletonList>(
        find.byType(GuSkeletonList),
      );
      expect(skeleton.variant, GuSkeletonVariant.card);
      expect(skeleton.count, 3);

      await _pump(tester, state: const SavedState(isError: true));
      expect(find.byKey(_k('retry')), findsOneWidget);

      await _pump(tester, state: const SavedState());
      expect(find.text(l10n.savedEmpty), findsOneWidget);
      expect(find.byType(SavedPostCard), findsNothing);
    });
  });

  group('PRF-04 · Kaydedilenler · aksiyonlar', () {
    testWidgets('kart → FED-02; geri → PRF-01', (tester) async {
      var router = await _pumpRoute(tester);
      await tester.tap(find.byKey(_k('post.p01')));
      await tester.pumpAndSettle();
      expect(_location(router), '/clubs/c01/posts/p01');

      router = await _pumpRoute(tester);
      await tester.tap(find.byKey(_k('back')));
      await tester.pumpAndSettle();
      expect(_location(router), '/profile');
    });

    testWidgets('kaydı kaldır → kart düşer + TST-11; "Geri al" → geri gelir', (
      tester,
    ) async {
      await _pumpRoute(tester);
      final feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
      await tester.tap(find.byKey(_k('unsave.p21')));
      await tester.pumpAndSettle();
      expect(feedback.toasts, [ToastId.tst11]);
      expect(find.byKey(_k('post.p21')), findsNothing);
      feedback.tapToastAction();
      await tester.pumpAndSettle();
      expect(find.byKey(_k('post.p21')), findsOneWidget);
    });

    testWidgets('çevrimdışı: kart kalır; kaldırma TST-24 verir, yazılmaz', (
      tester,
    ) async {
      await _pumpRoute(tester);
      (GetIt.I<ConnectivityService>() as FakeConnectivityService).isOffline =
          true;
      final feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
      await tester.tap(find.byKey(_k('unsave.p01')));
      await tester.pumpAndSettle();
      expect(feedback.toasts, [ToastId.tst24]);
      expect(
        (GetIt.I<SavedPostRepository>() as FakeSavedPostRepository).callsTo(
          'softDeleteSaved',
        ),
        isEmpty,
      );
      expect(find.byKey(_k('post.p01')), findsOneWidget);
    });
  });

  group('PRF-04 · Kaydedilenler · cihaz matrisi', () {
    testWidgets('dolu (güvenli alan); kaldırılmış, boş, hata', (tester) async {
      Widget view(BuildContext context) => const SavedView();
      await DeviceMatrix.run(
        tester,
        view,
        overrides: _overrides(),
        safeAreas: true,
      );
      for (final state in [
        loadedSaved(entries: [(kSavedRecordP01, null)]),
        const SavedState(),
        const SavedState(isError: true),
      ]) {
        await DeviceMatrix.run(tester, view, overrides: _overrides(state));
      }
    });
  });

  group('PRF-04 · Kaydedilenler · golden', () {
    testWidgets('varsayılan (açık + koyu)', (tester) async {
      await goldenForThemes(
        tester,
        'PRF-04',
        const SavedView(),
        overrides: _overrides(),
      );
    });
  });
}
