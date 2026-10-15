// MGT-01 · Yönetim paneli — içerik (tasarım yakalaması: u_burak → c03),
// durumlar (yükleniyor, hata, "Henüz üyen yok", danışman salt okunur bandı),
// aksiyon envanteri (28 anahtar), temel aksiyon sonuçları (MGT-10, FED-03,
// FED-02, EVT-02, CLB-03 geri; danışman → TST-26; yoklama → TST-X12; SHT-18),
// cihaz matrisi, açık + koyu golden.
// Referans: design/reference-shots/screens/MGT-01__*.webp,
// design/prototype/app/screens-manage.js:16–31.
//
// İki kip (CLB-06 testleriyle aynı düzen):
// * **Durum kipi**: ekran `pumpApp` ile çizilir, ViewModel durumu ezilir.
// * **Akış kipi**: gerçek ViewModel, sahte depolar ve yer tutucu rotalar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/manage_state.dart';
import 'package:gu_kulupler/features/management/provider/manage_view_model.dart';
import 'package:gu_kulupler/features/management/view/manage_view.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/widget/manage/activity_row.dart';
import 'package:gu_kulupler/product/widget/manage/manage_header.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_feedback_service.dart';
import '../../../fixtures/membership_model_fixtures.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';
import '../manage_test_support.dart';

final Key _back = GuKey.action('MGT-01.back');
final Key _retry = GuKey.action('MGT-01.retry');
final Key _share = GuKey.action('MGT-01.share');
final Key _switchClub = GuKey.action('MGT-01.switchClub');
final Key _activityAll = GuKey.action('MGT-01.activityAll');
final Key _quickPost = GuKey.action('MGT-01.quick.post');
final Key _quickAttendance = GuKey.action('MGT-01.quick.attendance');

Key _row(String id) => GuKey.action('MGT-01.row.$id');

/// Tüm bölümler kurulsun diye uzun yüzey.
const Size _tall = Size(390, 2400);

const String _managePath = '/clubs/$kManageClubId/manage';

final ManageViewModelProvider _provider = manageViewModelProvider(
  kManageClubId,
);

const Widget _view = ManageView(clubId: kManageClubId);

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

/// Durum kipi: oturum + ViewModel durumu ezilir.
List<Override> _overrides({SessionState? session, ManageState? state}) => [
  sessionViewModelProvider.overrideWithBuild(
    (ref, notifier) => session ?? manageSession(),
  ),
  _provider.overrideWithBuild((ref, notifier) => state ?? loadedManageState()),
];

Future<void> _pump(
  WidgetTester tester, {
  SessionState? session,
  ManageState? state,
  Locale locale = const Locale('tr'),
  Size size = _tall,
}) async {
  await tester.pumpApp(
    _view,
    locale: locale,
    size: size,
    overrides: _overrides(session: session, state: state),
  );
  await tester.pump();
}

/// Akış kipi: gerçek ViewModel + yer tutucu rotalar.
Future<GoRouter> _pumpRoute(WidgetTester tester) async {
  GoRouter? created;
  Widget stub(GoRouterState state) => _Stub(state.uri.toString());
  await tester.pumpAppRouter(
    size: _tall,
    routerOf: (_) => created ??= GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(path: '/start', builder: (_, s) => stub(s)),
        GoRoute(path: '/events/:eventId', builder: (_, s) => stub(s)),
        GoRoute(path: '/clubs/user/:userId', builder: (_, s) => stub(s)),
        GoRoute(
          path: '/clubs/:clubId',
          builder: (_, s) => stub(s),
          routes: [
            GoRoute(path: 'compose', builder: (_, s) => stub(s)),
            GoRoute(path: 'posts/:postId', builder: (_, s) => stub(s)),
            GoRoute(
              path: 'manage',
              builder: (_, s) =>
                  ManageView(clubId: s.pathParameters['clubId']!),
              routes: [
                GoRoute(path: 'activity', builder: (_, s) => stub(s)),
                GoRoute(
                  path: 'events',
                  builder: (_, s) => stub(s),
                  routes: [
                    GoRoute(path: 'new', builder: (_, s) => stub(s)),
                    GoRoute(
                      path: ':eventId/attendance',
                      builder: (_, s) => stub(s),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    overrides: [
      sessionViewModelProvider.overrideWithBuild(
        (ref, notifier) => manageSession(),
      ),
    ],
  );
  final router = created!;
  addTearDown(router.dispose);
  seedManage();
  router.go(_managePath);
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

Future<void> _tapKey(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('MGT-01 · Yönetim paneli · içerik', () {
    for (final locale in const [Locale('tr'), Locale('en')]) {
      testWidgets('dolu (${locale.languageCode}): başlık, KPI, hızlı '
          'işlemler, grafik, hak, yaklaşan, son hareketler', (tester) async {
        await _pump(tester, locale: locale);
        final l10n = tester.l10n;
        final header = tester.widget<ManageHeader>(find.byType(ManageHeader));
        expect(header.title, l10n.mgtTitle);
        expect(header.club, kManageClub);
        expect(header.role, ClubRole.president);
        expect(header.onSwitchClub, isNull);

        final kpis = tester.widgetList<GuKpi>(find.byType(GuKpi)).toList();
        expect(
          [for (final k in kpis) (k.label, k.value, k.accent)],
          [
            (l10n.mgtKpiMembers, '${kManageClub.memberCount}', false),
            (l10n.mgtKpiPending, '9', true),
            (l10n.mgtKpiEvents, '2', false),
            (l10n.mgtKpiAnnouncements, '1', false),
          ],
        );
        expect(kpis.first.subtitle, l10n.mgtKpiNewThisMonth(0));

        final quick = tester
            .widgetList<GuQuickAction>(find.byType(GuQuickAction))
            .toList();
        expect(quick.map((q) => q.label), [
          l10n.mgtQuickPost,
          l10n.mgtQuickAnnounce,
          l10n.mgtQuickEvent,
          l10n.mgtQuickAttendance,
          l10n.mgtQuickMembers,
          l10n.mgtQuickSettings,
        ]);
        expect(quick.any((q) => q.disabled), isFalse);
        expect(find.text(l10n.mgtGrowth), findsOneWidget);
        expect(find.text(l10n.mgtWeeks8), findsOneWidget);
        expect(find.byType(GuMiniLineChart), findsOneWidget);
        expect(find.text(l10n.composeDailyQuota), findsOneWidget);
        expect(find.text(kUpcomingEvents.first.title), findsOneWidget);
        expect(
          tester
              .widgetList<ActivityRow>(find.byType(ActivityRow))
              .map((r) => r.activity.id),
          kRecentIds,
        );
        expect(find.byType(GuBanner), findsNothing);
        expect(find.byKey(_share), findsNothing);
      });
    }

    testWidgets('danışman: salt okunur bandı, yazan hızlı işlemler devre dışı '
        '→ TST-26', (tester) async {
      await _pump(
        tester,
        session: manageSession(role: ClubRole.advisor),
        state: loadedManageState(
          access: ClubAccess.advisor,
          role: ClubRole.advisor,
        ),
      );
      final banner = tester.widget<GuBanner>(find.byType(GuBanner));
      expect(banner.kind, GuBannerKind.readonly);
      expect(banner.text, tester.l10n.mgtReadOnlyBanner);
      final disabled = tester
          .widgetList<GuQuickAction>(find.byType(GuQuickAction))
          .where((q) => q.disabled);
      expect(disabled, hasLength(3));
      await _tapKey(tester, _quickPost);
      expect(_feedback().toasts, [ToastId.tst26]);
    });

    testWidgets('yükleniyor → iskelet; hata → "Yeniden dene"', (tester) async {
      await _pump(tester, state: const ManageState(isFetching: true));
      expect(find.byType(GuSkeletonList), findsOneWidget);
      expect(find.byType(GuKpi), findsNothing);
      await _pump(tester, state: const ManageState(isError: true));
      expect(find.byKey(_retry), findsOneWidget);
      expect(find.byType(GuKpi), findsNothing);
    });

    testWidgets('sıradan üye yok → "Henüz üyen yok" + Paylaş → SHT-15', (
      tester,
    ) async {
      await _pump(tester, state: loadedManageState(hasMembers: false));
      expect(find.text(tester.l10n.mgtNewClubTitle), findsOneWidget);
      await _tapKey(tester, _share);
      expect(_feedback().sheets, [SheetId.sht15]);
    });

    testWidgets('yoklama hedefi yok → TST-X12', (tester) async {
      await _pump(
        tester,
        state: loadedManageState(upcoming: const []).copyWith(
          clearAttendanceEventId: true,
        ),
      );
      expect(find.text(tester.l10n.mgtNoUpcoming), findsOneWidget);
      await _tapKey(tester, _quickAttendance);
      expect(_feedback().toasts, [ToastId.tstX12]);
    });

    testWidgets('birden çok yönetilen kulüp → kulüp değiştir → SHT-18', (
      tester,
    ) async {
      final session = manageSession();
      final second = MembershipModelFixtures.c01Mehmet.copyWith(
        id: FirestoreIds.membership('c01', kManageUid),
        clubId: 'c01',
        userId: kManageUid,
        status: MembershipStatus.active,
        role: ClubRole.board,
      );
      await _pump(
        tester,
        session: session.copyWith(
          memberships: {...session.memberships, 'c01': second},
        ),
      );
      final header = tester.widget<ManageHeader>(find.byType(ManageHeader));
      expect(header.onSwitchClub, isNotNull);
      expect(header.switchClubKey, _switchClub);
      await tester.tap(find.byKey(_switchClub));
      await tester.pump();
      expect(_feedback().sheets, [SheetId.sht18]);
    });
  });

  group('MGT-01 · Yönetim paneli · envanter', () {
    testWidgets('28 anahtar (yönetici bakışı)', (tester) async {
      await _pump(tester);
      expectActionInventory(tester, 'MGT-01', role: 'manager');
    });
  });

  group('MGT-01 · Yönetim paneli · aksiyonlar', () {
    testWidgets('"Yaklaşan etkinlik" → MGT-04; "Etkinlik oluştur" → MGT-05 '
        '(W-38)', (tester) async {
      final router = await _pumpRoute(tester);
      await _tapKey(tester, GuKey.action('MGT-01.kpi.events'));
      expect(_location(router), '$_managePath/events');
      router.go(_managePath);
      await tester.pumpAndSettle();
      await _tapKey(tester, GuKey.action('MGT-01.quick.event'));
      expect(_location(router), '$_managePath/events/new');
    });

    testWidgets('"Yoklama al" → en yakın etkinliğin MGT-06\'sı (W-39)', (
      tester,
    ) async {
      final router = await _pumpRoute(tester);
      await _tapKey(tester, _quickAttendance);
      expect(
        _location(router),
        matches(RegExp('^$_managePath/events/[^/]+/attendance\$')),
      );
    });

    testWidgets('"Tümü" → MGT-10; geri → CLB-03', (tester) async {
      final router = await _pumpRoute(tester);
      await _tapKey(tester, _activityAll);
      expect(_location(router), '$_managePath/activity');
      router.go(_managePath);
      await tester.pumpAndSettle();
      await _tapKey(tester, _back);
      expect(_location(router), '/clubs/$kManageClubId');
    });

    testWidgets('"Gönderi yaz" → FED-03; satır: duyuru → FED-02, etkinlik → '
        'EVT-02', (tester) async {
      final router = await _pumpRoute(tester);
      await _tapKey(tester, _quickPost);
      expect(_location(router), '/clubs/$kManageClubId/compose');
      router.go(_managePath);
      await tester.pumpAndSettle();
      await _tapKey(tester, _row('a061'));
      expect(_location(router), '/clubs/$kManageClubId/posts/p08');
      router.go(_managePath);
      await tester.pumpAndSettle();
      await _tapKey(tester, _row('a105'));
      expect(_location(router), '/events/e16');
    });
  });

  group('MGT-01 · Yönetim paneli · matris', () {
    testWidgets('yönetici + danışman bakışı', (tester) async {
      await DeviceMatrix.run(tester, (_) => _view, overrides: _overrides());
      await DeviceMatrix.run(
        tester,
        (_) => _view,
        overrides: _overrides(
          session: manageSession(role: ClubRole.advisor),
          state: loadedManageState(
            access: ClubAccess.advisor,
            role: ClubRole.advisor,
            hasMembers: false,
          ),
        ),
      );
    });
  });

  group('MGT-01 · Yönetim paneli · golden', () {
    testWidgets('varsayılan açık + koyu', (tester) async {
      await goldenForThemes(tester, 'MGT-01', _view, overrides: _overrides());
    });
  });
}
