// MGT-03 · Üye yönetimi — içerik (tasarım yakalaması: u_burak → c03, 21
// etkin üye, ada göre), durumlar (yükleniyor, hata, boş, danışman bandı),
// aksiyon envanteri (50 anahtar), temel aksiyon sonuçları (satır menüsü →
// SHT-21 → DLG-19 → TST-47 / SHT-22; devir → SHT-25 → DLG-21 → TST-49;
// "⋮" → CSV → TST-29; sırala; satır → CLB-07; geri → MGT-01; ?transfer →
// SHT-25), cihaz matrisi, açık + koyu golden.
// Referans: design/reference-shots/screens/MGT-03__*.webp,
// design/reference-shots/states/MGT-03__*.webp,
// design/prototype/app/screens-manage.js:61–74.
//
// İki kip (MGT-02 testleriyle aynı düzen):
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
import 'package:gu_kulupler/features/management/provider/manage_members_state.dart';
import 'package:gu_kulupler/features/management/provider/manage_members_view_model.dart';
import 'package:gu_kulupler/features/management/view/manage_members_view.dart';
import 'package:gu_kulupler/features/management/view/mixin/manage_members_view_mixin.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/member_actions_sheet.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/widget/manage/manage_header.dart';
import 'package:gu_kulupler/product/widget/member/member_row.dart';
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
import '../members_test_support.dart';

final Key _back = GuKey.action('MGT-03.back');
final Key _retry = GuKey.action('MGT-03.retry');
final Key _sort = GuKey.action('MGT-03.sort');
final Key _menu = GuKey.action('MGT-03.menu');
final Key _transfer = GuKey.action('MGT-03.transfer');

Key _member(String id) => GuKey.action('MGT-03.member.$id');
Key _rowMenu(String id) => GuKey.action('MGT-03.menu.$id');
Key _filter(String id) => GuKey.action('MGT-03.filter.$id');

/// 21 satırın hepsi kurulsun diye uzun yüzey.
const Size _tall = Size(390, 2600);

const String _managePath = '/clubs/$kManageClubId/manage';
const String _path = '$_managePath/members';

final ManageMembersViewModelProvider _provider = manageMembersViewModelProvider(
  kManageClubId,
);

const Widget _view = ManageMembersView(clubId: kManageClubId);

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

/// Durum kipi: oturum + ViewModel durumu ezilir.
List<Override> _overrides({
  SessionState? session,
  ManageMembersState? state,
}) => [
  appClockProvider.overrideWithValue(FakeAppClock(DemoDataFixture.today)),
  sessionViewModelProvider.overrideWithBuild(
    (ref, notifier) => session ?? manageSession(),
  ),
  _provider.overrideWithBuild((ref, notifier) => state ?? loadedMembersState()),
];

Future<void> _pump(
  WidgetTester tester, {
  SessionState? session,
  ManageMembersState? state,
  Widget view = _view,
  Locale locale = const Locale('tr'),
}) async {
  await tester.pumpApp(
    view,
    locale: locale,
    size: _tall,
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
                  path: 'members',
                  builder: (_, s) =>
                      ManageMembersView(clubId: s.pathParameters['clubId']!),
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
  for (final row in tester.widgetList<MemberRow>(find.byType(MemberRow)))
    row.membership.userId,
];

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
  });

  group('MGT-03 · Üye yönetimi · içerik', () {
    testWidgets('dolu: başlık, 5 rol çipi, "21 kişi", "Ada göre", satırlar '
        'ada göre, başkan / danışman satırında menü yok, devir kartı', (
      tester,
    ) async {
      await _pump(tester);
      final l10n = tester.l10n;
      final header = tester.widget<ManageHeader>(find.byType(ManageHeader));
      expect(header.title, l10n.mgtMembersTitle);
      expect(header.club, kManageClub);
      expect(header.role, ClubRole.president);
      expect(find.byType(GuChip), findsNWidgets(5));
      expect(find.text(l10n.membersTotal(21)), findsOneWidget);
      expect(find.text(l10n.mgtMembersSortName), findsOneWidget);
      final ids = _rowIds(tester);
      expect(ids, hasLength(21));
      expect(ids.take(3), ['u_burak', 'u133', 'u_a_c03']);
      for (final id in ids) {
        expect(
          find.byKey(_rowMenu(id)),
          kNoMenuIds.contains(id) ? findsNothing : findsOneWidget,
        );
      }
      expect(find.byKey(_transfer), findsOneWidget);
      expect(find.text(l10n.mgtMembersTransferDesc), findsOneWidget);
      expect(find.byType(GuBanner), findsNothing);
    });

    testWidgets('danışman: salt okunur bandı, satır menüsü ve devir kartı yok; '
        'dışa aktar → TST-26', (tester) async {
      await _pump(
        tester,
        session: manageSession(role: ClubRole.advisor),
        state: loadedMembersState(
          access: ClubAccess.advisor,
          role: ClubRole.advisor,
        ),
      );
      final banner = tester.widget<GuBanner>(find.byType(GuBanner));
      expect(banner.kind, GuBannerKind.readonly);
      expect(find.byKey(_rowMenu('u086')), findsNothing);
      expect(find.byKey(_transfer), findsNothing);
      _feedback().nextMenuResult = ManageMembersMenuAction.export;
      await _tapKey(tester, _menu);
      expect(_feedback().toasts, [ToastId.tst26]);
    });

    testWidgets('yönetim kurulu: devir kartı yok; menü yine açılır', (
      tester,
    ) async {
      await _pump(
        tester,
        session: manageSession(role: ClubRole.board),
        state: loadedMembersState(role: ClubRole.board),
      );
      expect(find.byKey(_transfer), findsNothing);
      expect(find.byKey(_rowMenu('u032')), findsOneWidget);
    });

    testWidgets('yükleniyor → iskelet; hata → "Yeniden dene"; boş → "Eşleşen '
        'üye yok"', (tester) async {
      await _pump(tester, state: const ManageMembersState(isFetching: true));
      expect(find.byType(GuSkeletonList), findsOneWidget);
      await _pump(tester, state: const ManageMembersState(isError: true));
      expect(find.byKey(_retry), findsOneWidget);
      await _pump(tester, state: ManageMembersState(club: kManageClub));
      expect(find.byType(GuEmptyState), findsOneWidget);
      expect(find.text(tester.l10n.membersNoResults), findsOneWidget);
    });
  });

  group('MGT-03 · Üye yönetimi · envanter', () {
    testWidgets('50 anahtar (yönetici bakışı)', (tester) async {
      await _pump(tester);
      expectActionInventory(tester, 'MGT-03', role: 'manager');
    });
  });

  group('MGT-03 · Üye yönetimi · aksiyonlar', () {
    testWidgets('satır menüsü → SHT-21 → DLG-19 → satır düşer + TST-47', (
      tester,
    ) async {
      await _pumpRoute(tester);
      _feedback()
        ..nextSheetResult = MemberAction.remove
        ..dialogResults[DialogId.dlg19] = '';
      await _tapKey(tester, _rowMenu('u086'));
      expect(_feedback().sheets, [SheetId.sht21]);
      expect(_feedback().dialogs, [DialogId.dlg19]);
      expect(_rowIds(tester), isNot(contains('u086')));
      expect(_feedback().toasts, [ToastId.tst47]);
    });

    testWidgets('SHT-21 "Rolü değiştir" → SHT-22 (vazgeç → yazım yok)', (
      tester,
    ) async {
      await _pumpRoute(tester);
      _feedback().nextSheetResult = MemberAction.changeRole;
      await _tapKey(tester, _rowMenu('u086'));
      expect(_feedback().sheets, [SheetId.sht21, SheetId.sht22]);
      expect(_feedback().dialogs, isEmpty);
    });

    testWidgets('devir → SHT-25 → DLG-21 → TST-49; kart kalkar, rozetler '
        'güncellenir', (tester) async {
      await _pumpRoute(tester);
      _feedback()
        ..nextSheetResult = 'u086'
        ..dialogResults[DialogId.dlg21] = true;
      await _tapKey(tester, _transfer);
      expect(_feedback().sheets, [SheetId.sht25]);
      expect(_feedback().dialogs, [DialogId.dlg21]);
      expect(_feedback().toasts, [ToastId.tst49]);
      expect(find.byKey(_transfer), findsNothing);
      final rows = tester.widgetList<MemberRow>(find.byType(MemberRow));
      expect(
        {for (final r in rows) r.membership.userId: r.membership.role},
        containsPair('u086', ClubRole.president),
      );
    });

    testWidgets('"⋮" → dışa aktar → TST-29; sırala → katılım tarihi', (
      tester,
    ) async {
      await _pumpRoute(tester);
      _feedback().nextMenuResult = ManageMembersMenuAction.export;
      await _tapKey(tester, _menu);
      expect(_feedback().toasts, [ToastId.tst29]);

      _feedback().nextMenuResult = MemberSort.joined;
      await _tapKey(tester, _sort);
      expect(find.text(tester.l10n.mgtMembersSortJoined), findsOneWidget);
      expect(_rowIds(tester).first, isNot('u_burak'));

      await _tapKey(tester, _filter('advisor'));
      expect(_rowIds(tester), ['u_a_c03']);
    });

    testWidgets('satır → CLB-07; geri → MGT-01', (tester) async {
      final router = await _pumpRoute(tester);
      await _tapKey(tester, _member('u086'));
      expect(_location(router), startsWith('/clubs/user/u086'));
      router.go(_path);
      await tester.pumpAndSettle();
      await _tapKey(tester, _back);
      expect(_location(router), _managePath);
    });

    testWidgets('?transfer=true → 250 ms sonra SHT-25 (W-14 / W-34)', (
      tester,
    ) async {
      await _pump(
        tester,
        view: const ManageMembersView(
          clubId: kManageClubId,
          openTransfer: true,
        ),
      );
      expect(_feedback().sheets, isEmpty);
      await tester.pump(AppDurations.postNavigationSheetDelay);
      await tester.pump();
      expect(_feedback().sheets, [SheetId.sht25]);
    });
  });

  group('MGT-03 · Üye yönetimi · matris', () {
    testWidgets('yönetici + danışman bakışı', (tester) async {
      await DeviceMatrix.run(tester, (_) => _view, overrides: _overrides());
      await DeviceMatrix.run(
        tester,
        (_) => _view,
        overrides: _overrides(
          session: manageSession(role: ClubRole.advisor),
          state: loadedMembersState(
            access: ClubAccess.advisor,
            role: ClubRole.advisor,
          ),
        ),
      );
    });
  });

  group('MGT-03 · Üye yönetimi · golden', () {
    testWidgets('varsayılan açık + koyu', (tester) async {
      await goldenForThemes(tester, 'MGT-03', _view, overrides: _overrides());
    });
  });
}
