// ADM-05 · Admin kullanıcılar — içerik (tasarım yakalaması: u_admin; demo
// kullanıcılarının ada göre ilk 80'i, "Bölüm · N. sınıf · {n} kulüp",
// askıdakinde "Askıda" rozeti), durumlar (yükleniyor, boş, hata), aksiyon
// envanteri (168 anahtar), temel aksiyon sonuçları (satır → CLB-07, bölme →
// ADM-01 / ADM-02, süzgeç, `?filter=`, menü "Profili gör" → CLB-07, menü
// "Askıya al" → DLG-30 → askı + TST-52, kendi satırında askı öğesi yok —
// W-101 b), cihaz matrisi, açık + koyu golden (kabukta, alt çubuk görünür).
// 2026-10-16'dan beri ADM-05 admin kökünün (`AdminView`, `/admin?tab=users`)
// Kullanıcılar bölmesidir (kullanıcı kararı; tek sayfa); CLB-07 alt sayfasından
// geri aynı bölmeye (arama korunur) döner.
// Referans: design/reference-shots/screens/ADM-05__*.webp,
// states/ADM-05__*.webp; design/prototype/app/screens-admin.js:72–78,
// dialogs.js:49–50.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/admin/provider/admin_users_state.dart';
import 'package:gu_kulupler/features/admin/provider/admin_users_view_model.dart';
import 'package:gu_kulupler/features/admin/view/admin_overview_view.dart';
import 'package:gu_kulupler/features/admin/view/admin_users_view.dart';
import 'package:gu_kulupler/features/admin/view/admin_view.dart';
import 'package:gu_kulupler/features/admin/view/widget/admin_segment_bar.dart';
import 'package:gu_kulupler/features/admin/view/widget/admin_user_menu.dart';
import 'package:gu_kulupler/features/admin/view/widget/admin_user_row.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/navigation/admin_tab.dart';
import 'package:gu_kulupler/product/navigation/admin_users_filter.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_admin_repository.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_session_states.dart';
import '../../../fixtures/user_model_fixtures.dart';
import '../../../helpers/a11y_guidelines.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';
import '../admin_test_support.dart';
import '../admin_users_test_support.dart';

Key _k(String id) => GuKey.action(id);

/// Tüm satırlar (80) kurulsun diye uzun yüzey.
const Size _tall = Size(390, 8000);

/// Admin kökü, Kullanıcılar bölmesi açık.
const Widget _view = AdminView(tab: AdminTab.users);

/// Durum kipi: oturum + ViewModel durumu ezilir.
List<Override> _overrides({AdminUsersState? state}) => [
  sessionViewModelProvider.overrideWithBuild(
    (ref, notifier) => FakeSessionStates.activeSuper,
  ),
  adminUsersViewModelProvider.overrideWithBuild(
    (ref, notifier) => state ?? loadedAdminUsersState(),
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  AdminUsersState? state,
  Locale locale = const Locale('tr'),
  Size size = _tall,
}) async {
  await tester.pumpApp(
    _view,
    locale: locale,
    size: size,
    overrides: _overrides(state: state),
  );
  await tester.pump();
}

/// Akış kipi: gerçek ViewModel + yer tutucu rotalar.
Future<GoRouter> _pumpRoute(WidgetTester tester, {String filter = ''}) async {
  GoRouter? created;
  Widget stub(GoRouterState state) => _Stub(state.uri.toString());
  await tester.pumpAppRouter(
    size: const Size(390, 4000),
    routerOf: (_) => created ??= GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(path: '/start', builder: (_, s) => stub(s)),
        GoRoute(
          path: '/admin',
          builder: (_, s) => adminViewOf(s),
          routes: [GoRoute(path: 'users/:userId', builder: (_, s) => stub(s))],
        ),
      ],
    ),
    overrides: [
      sessionViewModelProvider.overrideWithBuild(
        (ref, notifier) => FakeSessionStates.activeSuper,
      ),
    ],
  );
  final router = created!;
  addTearDown(router.dispose);
  seedAdminUsers();
  router.go(
    filter.isEmpty ? '/admin?tab=users' : '/admin?tab=users&filter=$filter',
  );
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

FakeFeedbackService get _feedback =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

/// Akış kipindeki ilk satır ("Alp Aksoy").
String get _firstUid => adminUsersShown().first.uid;

void main() {
  group('ADM-05 · Admin kullanıcılar · içerik', () {
    for (final locale in const [Locale('tr'), Locale('en')]) {
      testWidgets('dolu (${locale.languageCode}): başlık + rozet, bölmeli '
          'geçiş (Kullanıcılar), arama, süzgeçler, 80 satır ada göre', (
        tester,
      ) async {
        await _pump(tester, locale: locale);
        final l10n = tester.l10n;

        final bar = tester.widget<GuAppBar>(find.byType(GuAppBar));
        expect(bar.title, l10n.navAdmin);
        expect(bar.large, isTrue);
        expect(find.byType(GuRoleBadge), findsOneWidget);
        expect(
          tester.widget<AdminSegmentBar>(find.byType(AdminSegmentBar)).current,
          AdminSegmentBar.users,
        );
        expect(find.text(l10n.adminUsersSearch), findsOneWidget);
        final chips = tester.widgetList<GuChip>(find.byType(GuChip)).toList();
        expect(chips.map((c) => c.label), [
          l10n.commonAll,
          l10n.statusSuspended,
          l10n.adminUsersManagers,
        ]);
        expect(chips.first.selected, isTrue);

        final rows = tester
            .widgetList<AdminUserRow>(find.byType(AdminUserRow))
            .toList();
        expect(rows, hasLength(kAdminUsersShown));
        expect(rows.first.user.name, kFirstUserName);
        expect(rows.first.clubCount, demoClubCounts()[rows.first.user.uid]);
        final suspended = rows.singleWhere(
          (r) => r.user.status == UserStatus.suspended,
        );
        expect(suspended.user.uid, kSuspendedUserId);
        expect(
          find.descendant(
            of: find.byKey(_k('ADM-05.row.$kSuspendedUserId')),
            matching: find.byType(GuStatusBadge),
          ),
          findsOneWidget,
        );
        expect(find.text(l10n.adminUsersClubCount(3)), findsNothing);
        expect(find.textContaining(l10n.adminUsersClubCount(3)), findsWidgets);
        await expectA11yGuidelines(tester);
      });
    }

    testWidgets('askıda süzgeci: yalnızca askıdaki kullanıcı', (tester) async {
      await _pump(
        tester,
        state: loadedAdminUsersState().copyWith(
          filter: AdminUsersFilter.suspended,
        ),
      );
      final rows = tester.widgetList<AdminUserRow>(find.byType(AdminUserRow));
      expect(rows.map((r) => r.user.uid), [kSuspendedUserId]);
    });

    testWidgets('yükleniyor → iskelet; boş → "Eşleşen üye yok"; hata → '
        '"Yeniden dene"', (tester) async {
      await _pump(tester, state: const AdminUsersState(isFetching: true));
      expect(find.byType(GuSkeletonList), findsOneWidget);
      expect(find.byType(AdminSegmentBar), findsOneWidget);
      expect(find.byKey(_k('ADM-05.search')), findsOneWidget);

      await _pump(tester, state: loadedAdminUsersState(users: const []));
      expect(find.text(tester.l10n.membersNoResults), findsOneWidget);
      expect(find.byType(AdminUserRow), findsNothing);

      await _pump(tester, state: const AdminUsersState(isError: true));
      expect(find.byKey(_k('ADM-05.retry')), findsOneWidget);
      expect(find.byType(AdminUserRow), findsNothing);
    });
  });

  group('ADM-05 · Admin kullanıcılar · envanter', () {
    testWidgets('168 anahtar (süper admin, tümü)', (tester) async {
      await _pump(tester);
      expectActionInventory(tester, 'ADM-05', role: 'admin');
    });
  });

  group('ADM-05 · Admin kullanıcılar · aksiyonlar', () {
    testWidgets('satır → CLB-07 (`/admin/users/:id`); geri → Kullanıcılar '
        'bölmesi (arama korunur)', (tester) async {
      final router = await _pumpRoute(tester);
      await tester.enterText(find.byKey(_k('ADM-05.search')), kFirstUserName);
      await tester.pump(Limits.searchDebounce);
      await tester.pumpAndSettle();
      await _tapKey(tester, _k('ADM-05.row.$_firstUid'));
      expect(_location(router), '/admin/users/$_firstUid');

      router.pop();
      await tester.pumpAndSettle();
      expect(_location(router), '/admin');
      expect(find.byType(AdminUsersView), findsOneWidget);
      expect(
        tester.widget<AdminSegmentBar>(find.byType(AdminSegmentBar)).current,
        AdminSegmentBar.users,
      );
      expect(
        find.descendant(
          of: find.byKey(_k('ADM-05.search')),
          matching: find.text(kFirstUserName),
        ),
        findsOneWidget,
      );
      expect(find.byKey(_k('ADM-05.row.$_firstUid')), findsOneWidget);
    });

    testWidgets('bölme "Genel" → ADM-01; "Kulüpler" → ADM-02 (aynı sayfa)', (
      tester,
    ) async {
      final router = await _pumpRoute(tester);
      await _tapKey(tester, _k('ADM-05.seg.ADM-02'));
      expect(_location(router), '/admin?tab=clubs');

      await _tapKey(tester, _k('ADM-02.seg.ADM-01'));
      expect(_location(router), '/admin');
      expect(find.byType(AdminOverviewView), findsOneWidget);
    });

    testWidgets('?filter=suspended → askıda süzgeci; "Tümü" çipi geri alır; '
        'arama ad önekiyle daraltır', (
      tester,
    ) async {
      await _pumpRoute(tester, filter: 'suspended');
      List<String> shown() => [
        for (final row in tester.widgetList<AdminUserRow>(
          find.byType(AdminUserRow),
        ))
          row.user.uid,
      ];
      expect(shown(), [kSuspendedUserId]);

      await _tapKey(tester, _k('ADM-05.filter.all'));
      expect(shown().length, greaterThan(1));

      await tester.enterText(find.byKey(_k('ADM-05.search')), 'Alp');
      await tester.pump(Limits.searchDebounce);
      await tester.pumpAndSettle();
      expect(shown().map((id) => id), hasLength(3));
    });

    testWidgets('menü "Profili gör" → CLB-07', (tester) async {
      final router = await _pumpRoute(tester);
      _feedback.nextMenuResult = AdminUserMenuAction.profile;
      await _tapKey(tester, _k('ADM-05.menu.$_firstUid'));
      expect(_feedback.callsTo('showMenu'), hasLength(1));
      expect(_location(router), '/admin/users/$_firstUid');
    });

    testWidgets('menü öğeleri: Profili gör · Askıya al (etkin) / Askıyı '
        'kaldır (askıda); kendi satırında askı öğesi yok (W-101 b)', (
      tester,
    ) async {
      final self = UserModelFixtures.byId(FakeSessionStates.uid);
      await _pump(
        tester,
        state: loadedAdminUsersState(users: [...adminUsersShown(), self]),
      );
      final l10n = tester.l10n;

      await _tapKey(tester, _k('ADM-05.menu.$_firstUid'));
      var items = _feedback.lastMenuItems.cast<GuPopMenuItem>();
      expect(items.map((i) => i.label), [
        l10n.userprofileView,
        l10n.adminUsersSuspend,
      ]);
      expect(items.last.danger, isTrue);
      expect(items.last.key, _k('ADM-05.menu.$_firstUid.suspend'));

      await _tapKey(tester, _k('ADM-05.menu.$kSuspendedUserId'));
      items = _feedback.lastMenuItems.cast<GuPopMenuItem>();
      expect(items.last.label, l10n.adminUsersUnsuspend);
      expect(items.last.danger, isFalse);

      await _tapKey(tester, _k('ADM-05.menu.${FakeSessionStates.uid}'));
      items = _feedback.lastMenuItems.cast<GuPopMenuItem>();
      expect(items.map((i) => i.label), [l10n.userprofileView]);
    });

    testWidgets('menü "Askıya al" → DLG-30 (neden) → askı, "Askıda" rozeti, '
        'TST-52', (tester) async {
      await _pumpRoute(tester);
      _feedback
        ..nextMenuResult = AdminUserMenuAction.suspend
        ..nextDialogResult = 'Kural ihlali';
      await _tapKey(tester, _k('ADM-05.menu.$_firstUid'));

      expect(_feedback.dialogs, [DialogId.dlg30]);
      final admin = GetIt.I<AdminRepository>() as FakeAdminRepository;
      expect(admin.callsTo('suspendUser').single.args, [
        _firstUid,
        'Kural ihlali',
      ]);
      expect(
        find.descendant(
          of: find.byKey(_k('ADM-05.row.$_firstUid')),
          matching: find.byType(GuStatusBadge),
        ),
        findsOneWidget,
      );
      expect(_feedback.toasts, [ToastId.tst52]);
    });

    testWidgets('menü "Askıya al" → DLG-30 vazgeç → yazım yok', (tester) async {
      await _pumpRoute(tester);
      _feedback.nextMenuResult = AdminUserMenuAction.suspend;
      await _tapKey(tester, _k('ADM-05.menu.$_firstUid'));
      final admin = GetIt.I<AdminRepository>() as FakeAdminRepository;
      expect(admin.callsTo('suspendUser'), isEmpty);
    });
  });

  group('ADM-05 · Admin kullanıcılar · matris', () {
    testWidgets('dolu görünüm', (tester) async {
      await DeviceMatrix.run(tester, (_) => _view, overrides: _overrides());
    });
  });

  group('ADM-05 · Admin kullanıcılar · golden', () {
    testWidgets('varsayılan açık + koyu', (tester) async {
      await goldenForThemes(
        tester,
        'ADM-05',
        _view,
        overrides: _overrides(),
        wrapInShell: true,
        shellTab: GuTab.admin,
      );
    });
  });
}
