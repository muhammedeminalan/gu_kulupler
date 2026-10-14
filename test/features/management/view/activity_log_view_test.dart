// MGT-10 · Faaliyet geçmişi — içerik (başlık, rol rozeti, çipler, gün
// grupları, satır metinleri / zaman), danışman bandı, aksiyon envanteri,
// durumlar (yükleniyor, hata, boş, sonraki sayfa, çevrimdışı yenileme),
// aksiyon sonuçları (geri → MGT-01, süzgeç, satır → EVT-02 / FED-02 / CLB-07,
// kulüp değiştir → SHT-18, yeniden dene), cihaz matrisi, açık + koyu golden.
// Referans: design/reference-shots/screens/MGT-10__*.webp,
// design/prototype/app/screens-manage.js:190–196.
//
// İki kip (CLB-06 testiyle aynı düzen):
// * **Durum kipi**: ViewModel durumu gerçek ViewModel'in demo veriyle
//   ürettiği durumdur (`loadedActivityState`); okuma yapılmaz.
// * **Akış kipi**: gerçek ViewModel, sahte depolar, yer tutucu rotalar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/activity_log_state.dart';
import 'package:gu_kulupler/features/management/provider/activity_log_view_model.dart';
import 'package:gu_kulupler/features/management/view/activity_log_view.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_kulupler/product/widget/manage/activity_row.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_session_states.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/fake_app_clock.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';
import '../activity_log_test_support.dart';

Key _k(String action) => GuKey.action('MGT-10.$action');

/// Envanterdeki 16 satırın çizildiği yükseklik.
const Size _tall = Size(390, 3200);

const String _activityPath = '/clubs/$kActClubId/manage/activity';

final ActivityLogViewModelProvider _provider = activityLogViewModelProvider(
  kActClubId,
);

late ActivityLogState _loaded;

FakeFeedbackService get _feedback =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

List<Override> _overrides({ActivityLogState? state, SessionState? session}) => [
  sessionViewModelProvider.overrideWithBuild(
    (ref, notifier) => session ?? kActSession,
  ),
  _provider.overrideWithBuild((ref, notifier) => state ?? _loaded),
  appClockProvider.overrideWithValue(FakeAppClock(kActNowUtc)),
];

const Widget _view = ActivityLogView(clubId: kActClubId);

Future<void> _pump(
  WidgetTester tester, {
  ActivityLogState? state,
  SessionState? session,
  Size size = const Size(390, 844),
  Locale locale = const Locale('tr'),
}) async {
  await tester.pumpApp(
    _view,
    locale: locale,
    size: size,
    overrides: _overrides(state: state, session: session),
  );
  await tester.pump();
}

/// Akış kipi: gerçek ViewModel ve yer tutucu rotalar; depolar ekran
/// açılmadan önce tohumlanır.
Future<GoRouter> _pumpRoute(
  WidgetTester tester, {
  SessionState? session,
  void Function()? seed,
  Size size = _tall,
}) async {
  GoRouter? created;
  Widget stub(GoRouterState state) => _Stub(state.uri.toString());
  await tester.pumpAppRouter(
    size: size,
    routerOf: (_) => created ??= GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(path: '/start', builder: (_, s) => stub(s)),
        GoRoute(path: '/events/:eventId', builder: (_, s) => stub(s)),
        GoRoute(path: '/clubs/user/:userId', builder: (_, s) => stub(s)),
        GoRoute(
          path: '/clubs/:clubId/posts/:postId',
          builder: (_, s) => stub(s),
        ),
        GoRoute(
          path: '/clubs/:clubId/manage',
          builder: (_, s) => stub(s),
          routes: [
            GoRoute(
              path: 'activity',
              builder: (_, s) =>
                  ActivityLogView(clubId: s.pathParameters['clubId']!),
            ),
          ],
        ),
      ],
    ),
    overrides: [
      sessionViewModelProvider.overrideWithBuild(
        (ref, notifier) => session ?? kActSession,
      ),
      appClockProvider.overrideWithValue(FakeAppClock(kActNowUtc)),
    ],
  );
  final router = created!;
  addTearDown(router.dispose);
  seedActivity();
  seed?.call();
  router.go(_activityPath);
  await tester.pumpAndSettle();
  return router;
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

/// Yer tutucu hedef sayfa: yolunu gösterir.
class _Stub extends StatelessWidget {
  const _Stub(this.path);

  final String path;

  @override
  Widget build(BuildContext context) => Scaffold(body: Text(path));
}

Future<void> _tapKey(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// [count] sentetik gönderi kaydı (saatte bir, en yeni üstte).
List<ActivityModel> _posts(int count) => [
  for (var i = 0; i < count; i++)
    ActivityModel(
      id: 'x${i.toString().padLeft(2, '0')}',
      clubId: kActClubId,
      actorId: 'u151',
      kind: ActivityKind.postCreated,
      refs: ActivityRefsModel(postId: 'p$i'),
      createdAt: kActNowUtc.subtract(Duration(hours: i)),
    ),
];

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
  });

  setUp(() async {
    _loaded = await loadedActivityState();
  });

  group('MGT-10 · Faaliyet geçmişi · içerik', () {
    testWidgets('başlık + kulüp + rozet, çipler, gün grupları, satırlar', (
      tester,
    ) async {
      await _pump(tester, size: _tall);
      final l10n = tester.l10n;
      expect(find.text(l10n.activityTitle), findsOneWidget);
      expect(find.text(_loaded.club!.name), findsOneWidget);
      expect(find.text(l10n.rolePresident), findsOneWidget);
      for (final label in [
        l10n.commonAll,
        l10n.activityCatMembership,
        l10n.activityCatEvent,
        l10n.activityCatContent,
        l10n.activityCatSettings,
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      // Gün başlıkları büyük harfe çevrilmez (`text-transform:none`).
      for (final head in ['12 Ekim Pazartesi', 'Bugün', 'Dün']) {
        expect(find.text(head), findsOneWidget);
      }
      expect(find.text('Furkan Yılmaz bir anket açtı'), findsOneWidget);
      expect(find.text(l10n.timeHoursAgo(20)), findsOneWidget);
      expect(
        find.text("Burak Şahin, Onur Karaca'ın başvurusunu reddetti"),
        findsOneWidget,
      );
      expect(find.byType(ActivityRow), findsNWidgets(kActIds.length));
      expect(find.byType(GuListEnd), findsOneWidget);
      expect(find.text(l10n.mgtReadOnlyBanner), findsNothing);
    });

    testWidgets('danışman: salt okunur bandı', (tester) async {
      await _pump(tester, session: FakeSessionStates.activeAdvisor(kActClubId));
      expect(find.text(tester.l10n.mgtReadOnlyBanner), findsOneWidget);
    });
  });

  group('MGT-10 · Faaliyet geçmişi · aksiyon envanteri', () {
    testWidgets('envanterdeki 22 anahtar birebir', (tester) async {
      await _pump(tester, size: _tall);
      expectActionInventory(tester, 'MGT-10', role: 'manager');
    });
  });

  group('MGT-10 · Faaliyet geçmişi · durumlar', () {
    testWidgets('yükleniyor → iskelet; hata → "Yeniden dene"; boş → '
        'illüstrasyon; sonraki sayfa → liste sonu iskeleti', (tester) async {
      await _pump(tester, state: const ActivityLogState(isFetching: true));
      expect(find.byType(GuSkeletonList), findsOneWidget);
      expect(find.byType(ActivityRow), findsNothing);

      await _pump(tester, state: const ActivityLogState(isError: true));
      expect(find.byKey(_k('retry')), findsOneWidget);

      await _pump(tester, state: const ActivityLogState());
      expect(find.text(tester.l10n.activityEmpty), findsOneWidget);
      expect(find.byType(GuEmptyState), findsOneWidget);

      await _pump(
        tester,
        state: _loaded.copyWith(isLoadingMore: true),
        size: _tall,
      );
      expect(find.byType(GuSkeletonList), findsOneWidget);
      expect(find.byType(GuListEnd), findsNothing);
    });

    testWidgets('çevrimdışı yenileme okunamadı → liste kalır', (tester) async {
      await _pumpRoute(tester);
      actRepo.failNext(FirestoreError.offline);
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 600),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.byType(GuErrorState), findsNothing);
      expect(find.byType(ActivityRow), findsNWidgets(kActIds.length));
    });
  });

  group('MGT-10 · Faaliyet geçmişi · aksiyonlar', () {
    testWidgets('geri → MGT-01', (tester) async {
      final router = await _pumpRoute(tester);
      await _tapKey(tester, _k('back'));
      expect(_location(router), const ManageRoute(clubId: kActClubId).location);
    });

    testWidgets('süzgeç: Etkinlik → 3 satır; Tümü → 16', (tester) async {
      await _pumpRoute(tester);
      await _tapKey(tester, _k('filter.event'));
      expect(find.byType(ActivityRow), findsNWidgets(3));
      expect(find.byKey(_k('row.a105')), findsOneWidget);
      await _tapKey(tester, _k('filter.settings'));
      expect(find.byType(ActivityRow), findsOneWidget);
      await _tapKey(tester, _k('filter.all'));
      expect(find.byType(ActivityRow), findsNWidgets(kActIds.length));
    });

    testWidgets('süzgeç sonucu boş → boş görünüm, çipler kalır', (
      tester,
    ) async {
      await _pumpRoute(
        tester,
        seed: () => actRepo.entries.removeWhere(
          (e) => e.kind == ActivityKind.settingsChanged,
        ),
      );
      await _tapKey(tester, _k('filter.settings'));
      expect(find.text(tester.l10n.activityEmpty), findsOneWidget);
      expect(find.byKey(_k('filter.all')), findsOneWidget);
    });

    for (final (row, target) in [
      ('a105', const EventDetailRoute(eventId: 'e16').location),
      (
        'a062',
        const PostDetailRoute(clubId: kActClubId, postId: 'p09').location,
      ),
      (
        'a118',
        const ClubUserProfileRoute(userId: 'u086', clubId: kActClubId).location,
      ),
    ]) {
      testWidgets('satır $row → $target', (tester) async {
        final router = await _pumpRoute(tester);
        await _tapKey(tester, _k('row.$row'));
        expect(_location(router), target);
      });
    }

    testWidgets('kulüp değiştir (iki kulüp) → SHT-18', (tester) async {
      final base = kActSession;
      final session = base.copyWith(
        memberships: {
          ...base.memberships,
          'c01': base.memberships[kActClubId]!.copyWith(
            id: FirestoreIds.membership('c01', base.uid!),
            clubId: 'c01',
          ),
        },
      );
      await _pump(tester, session: session);
      await tester.tap(find.byKey(_k('switchClub')));
      await tester.pumpAndSettle();
      expect(_feedback.sheets, [SheetId.sht18]);
    });

    testWidgets('hata → "Yeniden dene" → dolu', (tester) async {
      await _pumpRoute(
        tester,
        seed: () => actRepo.failNext(FirestoreError.unavailable),
      );
      expect(find.byKey(_k('retry')), findsOneWidget);
      await _tapKey(tester, _k('retry'));
      expect(find.byType(ActivityRow), findsNWidgets(kActIds.length));
    });

    testWidgets('sayfalama: sona kaydırınca sonraki sayfa', (tester) async {
      await _pumpRoute(
        tester,
        size: const Size(390, 844),
        seed: () => actRepo.entries
          ..clear()
          ..addAll(_posts(55)),
      );
      // İlk sayfa ekranı doldurmuyorsa ikinci sayfa kendiliğinden gelir.
      expect(actRepo.callsTo('listActivity').length, lessThan(3));
      expect(find.byKey(_k('row.x54')), findsNothing);
      for (var i = 0; i < 6; i++) {
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -2000),
        );
        await tester.pumpAndSettle();
      }
      expect(actRepo.callsTo('listActivity'), hasLength(3));
      expect(find.byKey(_k('row.x54')), findsOneWidget);
      expect(find.byType(GuListEnd), findsOneWidget);
    });
  });

  group('MGT-10 · Faaliyet geçmişi · cihaz matrisi', () {
    Widget view(BuildContext context) => _view;

    testWidgets('dolu (güvenli alan); yükleniyor, boş, hata', (tester) async {
      await DeviceMatrix.run(
        tester,
        view,
        overrides: _overrides(),
        safeAreas: true,
      );
      for (final state in const [
        ActivityLogState(isFetching: true),
        ActivityLogState(),
        ActivityLogState(isError: true),
      ]) {
        await DeviceMatrix.run(
          tester,
          view,
          overrides: _overrides(state: state),
        );
      }
    });
  });

  group('MGT-10 · Faaliyet geçmişi · golden', () {
    testWidgets('varsayılan (açık + koyu)', (tester) async {
      await goldenForThemes(tester, 'MGT-10', _view, overrides: _overrides());
    });
  });
}
