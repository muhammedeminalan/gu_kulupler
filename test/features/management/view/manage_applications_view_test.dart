// MGT-02 · Başvurular — içerik (tasarım yakalaması: u_burak → c03, 9
// bekleyen), durumlar (yükleniyor, hata, boş, danışman bandı, başvurular
// kapalı bandı, seçim çubuğu), aksiyon envanteri (33 anahtar), temel
// aksiyon sonuçları (onay → TST-27, ret → SHT-20 → TST-28, satır → SHT-19,
// toplu onay → DLG-17, sekme, geri → MGT-01; danışman → TST-26), cihaz
// matrisi, açık + koyu golden.
// Referans: design/reference-shots/screens/MGT-02__*.webp,
// design/prototype/app/screens-manage.js:43–51.
//
// İki kip (MGT-01 testleriyle aynı düzen):
// * **Durum kipi**: ekran `pumpApp` ile çizilir, ViewModel durumu ezilir.
// * **Akış kipi**: gerçek ViewModel, sahte depolar ve yer tutucu rotalar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/constants/app_durations.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/manage_applications_state.dart';
import 'package:gu_kulupler/features/management/provider/manage_applications_view_model.dart';
import 'package:gu_kulupler/features/management/view/manage_applications_view.dart';
import 'package:gu_kulupler/features/management/view/widget/reject_reason_sheet.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/navigation/applications_tab.dart';
import 'package:gu_kulupler/product/widget/manage/manage_header.dart';
import 'package:gu_kulupler/product/widget/member/application_row.dart';
import 'package:gu_kulupler/product/widget/member/user_row.dart';
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
import '../applications_test_support.dart';
import '../manage_test_support.dart';

final Key _back = GuKey.action('MGT-02.back');
final Key _retry = GuKey.action('MGT-02.retry');
final Key _sort = GuKey.action('MGT-02.sort');
final Key _toggleOpen = GuKey.action('MGT-02.toggleOpen');
final Key _selectAll = GuKey.action('MGT-02.selectAll');
final Key _bulkApprove = GuKey.action('MGT-02.bulkApprove');
final Key _tabApproved = GuKey.action('MGT-02.tab.approved');

Key _row(String id) => GuKey.action('MGT-02.row.$id');
Key _approve(String id) => GuKey.action('MGT-02.approve.$id');
Key _reject(String id) => GuKey.action('MGT-02.reject.$id');

/// Dokuz satırın hepsi kurulsun diye uzun yüzey.
const Size _tall = Size(390, 1800);

const String _managePath = '/clubs/$kManageClubId/manage';
const String _path = '$_managePath/applications';

final ManageApplicationsViewModelProvider _provider =
    manageApplicationsViewModelProvider(kManageClubId);

const Widget _view = ManageApplicationsView(clubId: kManageClubId);

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

/// Durum kipi: oturum + ViewModel durumu ezilir.
List<Override> _overrides({
  SessionState? session,
  ManageApplicationsState? state,
}) => [
  // Tasarım yakalamasının anı: göreli zamanlar ("3 saat önce") birebir.
  appClockProvider.overrideWithValue(FakeAppClock(DemoDataFixture.today)),
  sessionViewModelProvider.overrideWithBuild(
    (ref, notifier) => session ?? manageSession(),
  ),
  _provider.overrideWithBuild(
    (ref, notifier) => state ?? loadedApplicationsState(),
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  SessionState? session,
  ManageApplicationsState? state,
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
Future<GoRouter> _pumpRoute(
  WidgetTester tester, {
  SessionState? session,
}) async {
  GoRouter? created;
  Widget stub(GoRouterState state) => _Stub(state.uri.toString());
  await tester.pumpAppRouter(
    size: _tall,
    routerOf: (_) => created ??= GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(path: '/start', builder: (_, s) => stub(s)),
        GoRoute(path: '/clubs/user/:userId', builder: (_, s) => stub(s)),
        GoRoute(
          path: '/clubs/:clubId',
          builder: (_, s) => stub(s),
          routes: [
            GoRoute(
              path: 'manage',
              builder: (_, s) => stub(s),
              routes: [
                GoRoute(
                  path: 'applications',
                  builder: (_, s) => ManageApplicationsView(
                    clubId: s.pathParameters['clubId']!,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    overrides: [
      sessionViewModelProvider.overrideWithBuild(
        (ref, notifier) => session ?? manageSession(),
      ),
    ],
  );
  final router = created!;
  addTearDown(router.dispose);
  seedApplications();
  router.go(_path);
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

List<String> _rowIds(WidgetTester tester) => [
  for (final row in tester.widgetList<ApplicationRow>(
    find.byType(ApplicationRow),
  ))
    row.application.userId,
];

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
  });

  group('MGT-02 · Başvurular · içerik', () {
    for (final locale in const [Locale('tr'), Locale('en')]) {
      testWidgets('dolu (${locale.languageCode}): başlık, sekmeler (Bekleyen '
          '9), arama, ipucu, 9 satır en yeni üstte', (tester) async {
        await _pump(tester, locale: locale);
        final l10n = tester.l10n;
        final header = tester.widget<ManageHeader>(find.byType(ManageHeader));
        expect(header.title, l10n.applicationsTitle);
        expect(header.club, kManageClub);
        expect(header.role, ClubRole.president);
        final tabs = tester.widget<GuTabs>(find.byType(GuTabs));
        expect(
          [for (final t in tabs.tabs) (t.label, t.count)],
          [
            (l10n.applicationsTabPending, 9),
            (l10n.applicationsTabApproved, null),
            (l10n.applicationsTabRejected, null),
          ],
        );
        expect(find.text(l10n.applicationsHint), findsOneWidget);
        final ids = _rowIds(tester);
        expect(ids.toSet(), kPendingIds.toSet());
        final applied = [
          for (final id in ids) applicationOf(id).appliedAt!,
        ];
        for (var i = 1; i < applied.length; i++) {
          expect(applied[i].isAfter(applied[i - 1]), isFalse);
        }
        expect(find.byType(GuBanner), findsNothing);
      });
    }

    testWidgets('danışman: salt okunur bandı; onay → TST-26', (tester) async {
      await _pump(
        tester,
        session: manageSession(role: ClubRole.advisor),
        state: loadedApplicationsState(
          access: ClubAccess.advisor,
          role: ClubRole.advisor,
        ),
      );
      final banner = tester.widget<GuBanner>(find.byType(GuBanner));
      expect(banner.kind, GuBannerKind.readonly);
      await _tapKey(tester, _approve('u_cem'));
      expect(_feedback().toasts, [ToastId.tst26]);
    });

    testWidgets('başvurular kapalı → bilgi bandı + "Başvuruları aç"', (
      tester,
    ) async {
      await _pump(
        tester,
        state: loadedApplicationsState(
          club: kManageClub.copyWith(applicationsOpen: false),
        ),
      );
      final banner = tester.widget<GuBanner>(find.byType(GuBanner));
      expect(banner.text, tester.l10n.applicationsClosedBanner);
      expect(banner.icon, GuIcons.lock);
      expect(find.byKey(_toggleOpen), findsOneWidget);
    });

    testWidgets('seçim kipi: seçim çubuğu ("{n} seçili", Hepsini seç, toplu '
        'onay / ret), onay kutuları', (tester) async {
      await _pump(
        tester,
        state: loadedApplicationsState(
          selecting: true,
          selectedIds: {'u_cem', 'u043'},
        ),
      );
      expect(find.byType(ManageHeader), findsNothing);
      expect(find.text(tester.l10n.applicationsSelected(2)), findsOneWidget);
      expect(find.byKey(_selectAll), findsOneWidget);
      expect(find.byKey(_bulkApprove), findsOneWidget);
      expect(find.byType(GuCheckbox), findsNWidgets(kPendingIds.length));
      expect(find.byKey(_approve('u_cem')), findsNothing);
    });

    testWidgets('"Reddedilen" sekmesi: ret nedeni + durum rozeti', (
      tester,
    ) async {
      await _pump(
        tester,
        state: loadedApplicationsState(tab: ApplicationsTab.rejected),
      );
      expect(find.byType(ApplicationRow), findsNothing);
      expect(find.byType(UserRow), findsNWidgets(4));
      expect(find.text(tester.l10n.statusRejected), findsNWidgets(4));
      expect(find.text(tester.l10n.applicationsHint), findsNothing);
    });

    testWidgets('yükleniyor → iskelet; hata → "Yeniden dene"; boş → "Bekleyen '
        'başvuru yok"', (tester) async {
      await _pump(
        tester,
        state: const ManageApplicationsState(isFetching: true),
      );
      expect(find.byType(GuSkeletonList), findsOneWidget);
      await _pump(tester, state: const ManageApplicationsState(isError: true));
      expect(find.byKey(_retry), findsOneWidget);
      await _pump(
        tester,
        state: ManageApplicationsState(
          club: kManageClub,
          loadedTabs: const {ApplicationsTab.pending},
        ),
      );
      expect(find.byType(GuEmptyState), findsOneWidget);
      expect(find.text(tester.l10n.applicationsEmptyPending), findsOneWidget);
    });
  });

  group('MGT-02 · Başvurular · envanter', () {
    testWidgets('33 anahtar (yönetici bakışı)', (tester) async {
      await _pump(tester);
      expectActionInventory(tester, 'MGT-02', role: 'manager');
    });
  });

  group('MGT-02 · Başvurular · aksiyonlar', () {
    testWidgets('onay → satır kalkar + TST-27; ret → SHT-20 → TST-28', (
      tester,
    ) async {
      await _pumpRoute(tester);
      expect(_rowIds(tester), hasLength(kPendingIds.length));
      await _tapKey(tester, _approve('u_cem'));
      expect(_rowIds(tester), isNot(contains('u_cem')));
      expect(_feedback().toasts, [ToastId.tst27]);

      const RejectDecision decision = (RejectReason.quota, null);
      _feedback().nextSheetResult = decision;
      await _tapKey(tester, _reject('u043'));
      expect(_feedback().sheets, [SheetId.sht20]);
      expect(_rowIds(tester), isNot(contains('u043')));
      expect(_feedback().toasts.last, ToastId.tst28);
    });

    testWidgets('satır → SHT-19; sırala; "Onaylanan" sekmesi; geri → MGT-01', (
      tester,
    ) async {
      final router = await _pumpRoute(tester);
      await _tapKey(tester, _row('u_cem'));
      expect(_feedback().sheets, [SheetId.sht19]);

      final first = _rowIds(tester).first;
      await _tapKey(tester, _sort);
      expect(_rowIds(tester).last, first);

      await _tapKey(tester, _tabApproved);
      expect(find.byType(ApplicationRow), findsNothing);
      expect(find.byType(UserRow), findsWidgets);

      await _tapKey(tester, _back);
      expect(_location(router), _managePath);
    });

    testWidgets('uzun basış → seçim; Hepsini seç; toplu onay → DLG-17', (
      tester,
    ) async {
      await _pumpRoute(tester);
      await tester.longPress(find.byKey(_row('u_cem')));
      await tester.pumpAndSettle();
      expect(find.text(tester.l10n.applicationsSelected(1)), findsOneWidget);
      await _tapKey(tester, _selectAll);
      expect(
        find.text(tester.l10n.applicationsSelected(kPendingIds.length)),
        findsOneWidget,
      );
      await _tapKey(tester, _bulkApprove);
      expect(_feedback().dialogs, [DialogId.dlg17]);
    });
  });

  group('MGT-02 · Başvurular · açılış parametreleri', () {
    testWidgets('?tab=approved → "Onaylanan"; ?applicant= → 250 ms sonra '
        'SHT-19 (W-28)', (tester) async {
      await tester.pumpApp(
        const ManageApplicationsView(
          clubId: kManageClubId,
          tab: ApplicationsTab.approved,
          applicantId: 'u_cem',
        ),
        size: _tall,
        overrides: _overrides(),
      );
      await tester.pump();
      expect(
        tester.widget<GuTabs>(find.byType(GuTabs)).value,
        ApplicationsTab.approved.name,
      );
      expect(_feedback().sheets, isEmpty);
      await tester.pump(AppDurations.postNavigationSheetDelay);
      await tester.pump();
      expect(_feedback().sheets, [SheetId.sht19]);
    });
  });

  group('MGT-02 · Başvurular · matris', () {
    testWidgets('yönetici + danışman bakışı', (tester) async {
      await DeviceMatrix.run(tester, (_) => _view, overrides: _overrides());
      await DeviceMatrix.run(
        tester,
        (_) => _view,
        overrides: _overrides(
          session: manageSession(role: ClubRole.advisor),
          state: loadedApplicationsState(
            access: ClubAccess.advisor,
            role: ClubRole.advisor,
            club: kManageClub.copyWith(applicationsOpen: false),
          ),
        ),
      );
    });
  });

  group('MGT-02 · Başvurular · golden', () {
    testWidgets('varsayılan açık + koyu', (tester) async {
      await goldenForThemes(tester, 'MGT-02', _view, overrides: _overrides());
    });
  });
}
