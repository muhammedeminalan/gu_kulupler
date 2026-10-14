// MGT-04 · Etkinlik yönetimi — içerik (tasarım yakalaması: u_burak → c03,
// "Yayında": e03 30/30 · e16 11/25 "Sadece üyeler"), sekmeler (Taslak ·
// Yayında · Geçmiş · İptal), durumlar (yükleniyor, hata, boş, danışman
// bandı — FAB yok), aksiyon envanteri, temel aksiyon sonuçları (satır →
// EVT-02; "⋮" → SHT-23 → düzenle → MGT-05 / taslak sil → DLG-31 → TST-45;
// FAB → MGT-05; geri → MGT-01; `?tab=draft`), cihaz matrisi, açık + koyu
// golden. Referans: design/reference-shots/screens/MGT-04__*.webp,
// design/reference-shots/states/MGT-04__*.webp,
// design/prototype/app/screens-manage.js:77–83.
//
// İki kip (MGT-03 testleriyle aynı düzen): durum kipi (`pumpApp`, ViewModel
// durumu ezilir) · akış kipi (gerçek ViewModel, sahte depolar, yer tutucu
// rotalar).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/manage_events_state.dart';
import 'package:gu_kulupler/features/management/provider/manage_events_view_model.dart';
import 'package:gu_kulupler/features/management/view/manage_events_view.dart';
import 'package:gu_kulupler/features/management/view/widget/manage_event_row.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/event_menu_sheet.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/navigation/manage_events_tab.dart';
import 'package:gu_kulupler/product/widget/manage/manage_header.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../fakes/fake_feedback_service.dart';
import '../../../fixtures/demo_data.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/fake_app_clock.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';
import '../events_test_support.dart';
import '../manage_test_support.dart';

final Key _back = GuKey.action('MGT-04.back');
final Key _create = GuKey.action('MGT-04.create');
final Key _retry = GuKey.action('MGT-04.retry');

Key _event(String id) => GuKey.action('MGT-04.event.$id');
Key _menu(String id) => GuKey.action('MGT-04.menu.$id');
Key _tab(ManageEventsTab tab) => GuKey.action('MGT-04.tab.${tab.name}');

const String _managePath = '/clubs/$kManageClubId/manage';
const String _path = '$_managePath/events';

final ManageEventsViewModelProvider _provider = manageEventsViewModelProvider(
  kManageClubId,
);

const Widget _view = ManageEventsView(clubId: kManageClubId);

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

/// Durum kipi: oturum + ViewModel durumu ezilir.
List<Override> _overrides({
  SessionState? session,
  ManageEventsState? state,
}) => [
  appClockProvider.overrideWithValue(FakeAppClock(DemoDataFixture.today)),
  sessionViewModelProvider.overrideWithBuild(
    (ref, notifier) => session ?? manageSession(),
  ),
  _provider.overrideWithBuild((ref, notifier) => state ?? loadedEventsState()),
];

Future<void> _pump(
  WidgetTester tester, {
  SessionState? session,
  ManageEventsState? state,
  Widget view = _view,
}) async {
  await tester.pumpApp(
    view,
    overrides: _overrides(session: session, state: state),
  );
  await tester.pump();
}

/// Akış kipi: gerçek ViewModel + yer tutucu rotalar.
Future<GoRouter> _pumpRoute(WidgetTester tester, {String path = _path}) async {
  GoRouter? created;
  Widget stub(GoRouterState state) => _Stub(state.uri.toString());
  await tester.pumpAppRouter(
    routerOf: (_) => created ??= GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(path: '/start', builder: (_, s) => stub(s)),
        GoRoute(path: '/events/:eventId', builder: (_, s) => stub(s)),
        GoRoute(
          path: '/clubs/:clubId',
          builder: (_, s) => stub(s),
          routes: [
            GoRoute(
              path: 'manage',
              builder: (_, s) => stub(s),
              routes: [
                GoRoute(
                  path: 'events',
                  builder: (_, s) => ManageEventsView(
                    clubId: s.pathParameters['clubId']!,
                    tab: switch (s.uri.queryParameters['tab']) {
                      final String name => ManageEventsTab.values.byName(name),
                      null => null,
                    },
                  ),
                  routes: [
                    GoRoute(path: 'new', builder: (_, s) => stub(s)),
                    GoRoute(
                      path: ':eventId/edit',
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
      appClockProvider.overrideWithValue(FakeAppClock(DemoDataFixture.today)),
      sessionViewModelProvider.overrideWithBuild(
        (ref, notifier) => manageSession(),
      ),
    ],
  );
  final router = created!;
  addTearDown(router.dispose);
  seedManage();
  router.go(path);
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
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

List<String> _rowIds(WidgetTester tester) => [
  for (final row in tester.widgetList<ManageEventRow>(
    find.byType(ManageEventRow),
  ))
    row.event.id,
];

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
  });

  group('MGT-04 · Etkinlik yönetimi · içerik', () {
    testWidgets('dolu: başlık, 4 sekme (Taslak · Yayında · Geçmiş · İptal), '
        '"Yayında" e03 30/30 · e16 11/25 + "Sadece üyeler", FAB', (
      tester,
    ) async {
      await _pump(tester);
      final l10n = tester.l10n;
      final header = tester.widget<ManageHeader>(find.byType(ManageHeader));
      expect(header.title, l10n.mgtEventsTitle);
      expect(header.club, kManageClub);
      expect(header.role, ClubRole.president);
      final segmented = tester.widget<GuSegmented>(find.byType(GuSegmented));
      expect(
        [for (final o in segmented.options) o.label],
        [
          l10n.statusDraft,
          l10n.statusPublished,
          l10n.eventPast,
          l10n.statusCancelled,
        ],
      );
      expect(segmented.value, ManageEventsTab.published.name);
      expect(_rowIds(tester), ['e03', 'e16']);
      expect(find.textContaining('30/30'), findsOneWidget);
      expect(find.textContaining('11/25'), findsOneWidget);
      expect(find.text(l10n.eventVisibilityMembers), findsOneWidget);
      expect(find.text(l10n.statusPublished), findsNWidgets(3));
      expect(find.byKey(_create), findsOneWidget);
      expect(find.byType(GuBanner), findsNothing);
    });

    testWidgets('sekme: Taslak → e22 "Taslak"; Geçmiş → e19; İptal → boş '
        '"İptal edilen etkinlik yok"', (tester) async {
      await _pump(tester, state: loadedEventsState(tab: ManageEventsTab.draft));
      expect(_rowIds(tester), ['e22']);
      await _pump(tester, state: loadedEventsState(tab: ManageEventsTab.past));
      expect(_rowIds(tester), ['e19']);
      await _pump(
        tester,
        state: loadedEventsState(tab: ManageEventsTab.cancelled),
      );
      expect(find.byType(GuEmptyState), findsOneWidget);
      expect(find.text(tester.l10n.mgtEventsEmptyCancelled), findsOneWidget);
    });

    testWidgets('danışman: salt okunur bandı, FAB yok', (tester) async {
      await _pump(
        tester,
        session: manageSession(role: ClubRole.advisor),
        state: loadedEventsState(
          access: ClubAccess.advisor,
          role: ClubRole.advisor,
        ),
      );
      final banner = tester.widget<GuBanner>(find.byType(GuBanner));
      expect(banner.kind, GuBannerKind.readonly);
      expect(find.byKey(_create), findsNothing);
      expect(find.byKey(_menu('e03')), findsOneWidget);
    });

    testWidgets('yükleniyor → iskelet; hata → "Yeniden dene"; boş → '
        '"Yayında etkinlik yok"', (tester) async {
      await _pump(tester, state: const ManageEventsState(isFetching: true));
      expect(find.byType(GuSkeletonList), findsOneWidget);
      await _pump(tester, state: const ManageEventsState(isError: true));
      expect(find.byKey(_retry), findsOneWidget);
      await _pump(tester, state: ManageEventsState(club: kManageClub));
      expect(find.byType(GuEmptyState), findsOneWidget);
      expect(find.text(tester.l10n.mgtEventsEmptyPublished), findsOneWidget);
    });
  });

  group('MGT-04 · Etkinlik yönetimi · envanter', () {
    testWidgets('10 anahtar (yönetici bakışı)', (tester) async {
      await _pump(tester);
      expectActionInventory(tester, 'MGT-04', role: 'manager');
    });
  });

  group('MGT-04 · Etkinlik yönetimi · aksiyonlar', () {
    testWidgets('sekme dokunuşu → Taslak listesi', (tester) async {
      await _pumpRoute(tester);
      await _tapKey(tester, _tab(ManageEventsTab.draft));
      expect(_rowIds(tester), ['e22']);
    });

    testWidgets('?tab=draft → Taslak sekmesiyle açılır', (tester) async {
      await _pumpRoute(tester, path: '$_path?tab=draft');
      expect(_rowIds(tester), ['e22']);
    });

    testWidgets('"⋮" → SHT-23 → Düzenle → MGT-05 (düzenleme)', (tester) async {
      final router = await _pumpRoute(tester);
      _feedback().nextSheetResult = EventMenuAction.edit;
      await _tapKey(tester, _menu('e03'));
      expect(_feedback().sheets, [SheetId.sht23]);
      expect(_location(router), '$_path/e03/edit');
    });

    testWidgets('Taslak "⋮" → Sil → DLG-31 → satır düşer + TST-45', (
      tester,
    ) async {
      await _pumpRoute(tester, path: '$_path?tab=draft');
      _feedback()
        ..nextSheetResult = EventMenuAction.delete
        ..dialogResults[DialogId.dlg31] = true;
      await _tapKey(tester, _menu('e22'));
      expect(_feedback().dialogs, [DialogId.dlg31]);
      expect(_rowIds(tester), isEmpty);
      expect(_feedback().toasts, [ToastId.tst45]);
    });

    testWidgets('satır → EVT-02; FAB → MGT-05; geri → MGT-01', (tester) async {
      final router = await _pumpRoute(tester);
      await _tapKey(tester, _event('e16'));
      expect(_location(router), '/events/e16');
      router.go(_path);
      await tester.pumpAndSettle();
      await _tapKey(tester, _create);
      expect(_location(router), '$_path/new');
      router.go(_path);
      await tester.pumpAndSettle();
      await _tapKey(tester, _back);
      expect(_location(router), _managePath);
    });
  });

  group('MGT-04 · Etkinlik yönetimi · matris', () {
    testWidgets('yönetici + danışman bakışı', (tester) async {
      await DeviceMatrix.run(tester, (_) => _view, overrides: _overrides());
      await DeviceMatrix.run(
        tester,
        (_) => _view,
        overrides: _overrides(
          session: manageSession(role: ClubRole.advisor),
          state: loadedEventsState(
            access: ClubAccess.advisor,
            role: ClubRole.advisor,
          ),
        ),
      );
    });
  });

  group('MGT-04 · Etkinlik yönetimi · golden', () {
    testWidgets('varsayılan açık + koyu', (tester) async {
      await goldenForThemes(tester, 'MGT-04', _view, overrides: _overrides());
    });
  });
}
