// ADM-02 · Admin kulüpler — içerik (tasarım yakalaması: u_admin; 13 etkin
// kulüp ada göre, "Başkan: Burak Şahin · 231 üye", Aktif rozeti), durumlar
// (yükleniyor, boş, hata), aksiyon envanteri (34 anahtar), temel aksiyon
// sonuçları (satır → CLB-03, "Kulüp oluştur" → ADM-03, bölme "Genel" →
// ADM-01, sekme / arama, menü → DLG-28 → askı + TST-50, menü "Düzenle" →
// ADM-03 düzenleme), DLG-28 (neden zorunlu), cihaz matrisi, açık + koyu
// golden.
// Referans: design/reference-shots/screens/ADM-02__*.webp,
// states/ADM-02__*.webp, dialogs/DLG-28__*.webp;
// design/prototype/app/screens-admin.js:29–35, dialogs.js:46–47.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/admin/provider/admin_clubs_state.dart';
import 'package:gu_kulupler/features/admin/provider/admin_clubs_view_model.dart';
import 'package:gu_kulupler/features/admin/view/admin_clubs_view.dart';
import 'package:gu_kulupler/features/admin/view/widget/admin_club_menu.dart';
import 'package:gu_kulupler/features/admin/view/widget/admin_club_row.dart';
import 'package:gu_kulupler/features/admin/view/widget/admin_segment_bar.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/dialogs/suspend_club_dialog.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/navigation/admin_clubs_tab.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_admin_repository.dart';
import '../../../fakes/fake_club_repository.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_session_states.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';
import '../admin_clubs_test_support.dart';

Key _k(String id) => GuKey.action(id);

/// Tüm satırlar kurulsun diye uzun yüzey.
const Size _tall = Size(390, 2000);

const Widget _view = AdminClubsView();

/// Durum kipi: oturum + ViewModel durumu ezilir.
List<Override> _overrides({AdminClubsState? state}) => [
  sessionViewModelProvider.overrideWithBuild(
    (ref, notifier) => FakeSessionStates.activeSuper,
  ),
  adminClubsViewModelProvider.overrideWithBuild(
    (ref, notifier) => state ?? loadedAdminClubsState(),
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  AdminClubsState? state,
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
Future<GoRouter> _pumpRoute(WidgetTester tester, {String tab = ''}) async {
  GoRouter? created;
  Widget stub(GoRouterState state) => _Stub(state.uri.toString());
  await tester.pumpAppRouter(
    size: _tall,
    routerOf: (_) => created ??= GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(path: '/start', builder: (_, s) => stub(s)),
        GoRoute(path: '/admin', builder: (_, s) => stub(s)),
        GoRoute(
          path: '/admin/clubs',
          builder: (_, s) => AdminClubsView(
            tab: switch (s.uri.queryParameters['tab']) {
              'suspended' => AdminClubsTab.suspended,
              _ => null,
            },
          ),
        ),
        GoRoute(path: '/admin/clubs/new', builder: (_, s) => stub(s)),
        GoRoute(path: '/admin/clubs/:clubId/edit', builder: (_, s) => stub(s)),
        GoRoute(path: '/clubs/:clubId', builder: (_, s) => stub(s)),
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
  seedAdminClubs();
  final clubs = (GetIt.I<ClubRepository>() as FakeClubRepository).clubs;
  clubs[kAdminSuspendedClubId] = clubs[kAdminSuspendedClubId]!.copyWith(
    status: ClubStatus.suspended,
  );
  router.go(tab.isEmpty ? '/admin/clubs' : '/admin/clubs?tab=$tab');
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

void main() {
  group('ADM-02 · Admin kulüpler · içerik', () {
    for (final locale in const [Locale('tr'), Locale('en')]) {
      testWidgets('dolu (${locale.languageCode}): başlık + rozet, bölmeli '
          'geçiş (Kulüpler), sekmeler, arama, 13 etkin satır ada göre, FAB', (
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
          AdminSegmentBar.clubs,
        );
        expect(find.text(l10n.statusActive), findsWidgets);
        expect(find.text(l10n.statusSuspended), findsOneWidget);
        expect(find.byType(GuSearchField), findsOneWidget);

        final rows = tester
            .widgetList<AdminClubRow>(find.byType(AdminClubRow))
            .toList();
        expect(rows, hasLength(13));
        expect(rows.first.club.id, kFirstClubId);
        expect(
          find.text(
            '${l10n.adminClubsPresident('Burak Şahin')} · '
            '${l10n.clubsCardMembers(231)}',
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(_k('ADM-02.row.$kAdminSuspendedClubId')),
          findsNothing,
        );
        expect(find.text(l10n.adminClubsCreate), findsOneWidget);
      });
    }

    testWidgets('askıda sekmesi: c14 + "Askıda" rozeti', (tester) async {
      await _pump(
        tester,
        state: loadedAdminClubsState().copyWith(tab: AdminClubsTab.suspended),
      );
      final rows = tester.widgetList<AdminClubRow>(find.byType(AdminClubRow));
      expect(rows.map((r) => r.club.id), [kAdminSuspendedClubId]);
      final badge = tester.widget<GuStatusBadge>(find.byType(GuStatusBadge));
      expect(badge.kind, GuStatusBadgeKind.suspended);
    });

    testWidgets('yükleniyor → iskelet; boş → "Kulüp yok"; hata → "Yeniden '
        'dene"', (tester) async {
      await _pump(tester, state: const AdminClubsState(isFetching: true));
      expect(find.byType(GuSkeletonList), findsOneWidget);
      expect(find.byType(AdminSegmentBar), findsOneWidget);
      expect(find.byKey(_k('ADM-02.create')), findsOneWidget);

      await _pump(
        tester,
        state: loadedAdminClubsState().copyWith(query: 'zzz'),
      );
      expect(find.text(tester.l10n.adminClubsEmpty), findsOneWidget);
      expect(find.byType(AdminClubRow), findsNothing);

      await _pump(tester, state: const AdminClubsState(isError: true));
      expect(find.byKey(_k('ADM-02.retry')), findsOneWidget);
      expect(find.byType(AdminClubRow), findsNothing);
    });
  });

  group('ADM-02 · Admin kulüpler · envanter', () {
    testWidgets('34 anahtar (süper admin, etkin sekme)', (tester) async {
      await _pump(tester);
      expectActionInventory(tester, 'ADM-02', role: 'admin');
    });
  });

  group('ADM-02 · Admin kulüpler · aksiyonlar', () {
    testWidgets('satır → CLB-03', (tester) async {
      final router = await _pumpRoute(tester);
      await _tapKey(tester, _k('ADM-02.row.c03'));
      expect(_location(router), '/clubs/c03');
    });

    testWidgets('"Kulüp oluştur" → ADM-03', (tester) async {
      final router = await _pumpRoute(tester);
      await _tapKey(tester, _k('ADM-02.create'));
      expect(_location(router), '/admin/clubs/new');
    });

    testWidgets('bölme "Genel" → ADM-01', (tester) async {
      final router = await _pumpRoute(tester);
      await _tapKey(tester, _k('ADM-02.seg.ADM-01'));
      expect(_location(router), '/admin');
    });

    testWidgets('?tab=suspended → askıda sekmesi; sekme ve arama süzer', (
      tester,
    ) async {
      await _pumpRoute(tester, tab: 'suspended');
      expect(
        find.byKey(_k('ADM-02.row.$kAdminSuspendedClubId')),
        findsOneWidget,
      );

      await _tapKey(tester, _k('ADM-02.tab.active'));
      expect(find.byType(AdminClubRow), findsNWidgets(13));

      await tester.enterText(find.byKey(_k('ADM-02.search')), 'e-spor');
      await tester.pumpAndSettle();
      final rows = tester.widgetList<AdminClubRow>(find.byType(AdminClubRow));
      expect(rows.map((r) => r.club.id), ['c10']);
    });

    testWidgets('menü "Düzenle" → ADM-03 düzenleme', (tester) async {
      final router = await _pumpRoute(tester);
      _feedback.nextMenuResult = AdminClubMenuAction.edit;
      await _tapKey(tester, _k('ADM-02.menu.c03'));
      expect(_feedback.callsTo('showMenu'), hasLength(1));
      expect(_location(router), '/admin/clubs/c03/edit');
    });

    testWidgets('menü öğeleri: Görüntüle · Düzenle · Başkanı değiştir · '
        'Askıya al (etkin) / Etkinleştir (askıda)', (tester) async {
      await _pumpRoute(tester);
      await _tapKey(tester, _k('ADM-02.menu.c03'));
      final l10n = tester.l10n;
      final items = _feedback.lastMenuItems.cast<GuPopMenuItem>();
      expect(items.map((i) => i.label), [
        l10n.commonView,
        l10n.commonEdit,
        l10n.adminClubsChangePresident,
        l10n.adminClubsSuspend,
      ]);
      expect(items.last.danger, isTrue);
      expect(items.last.key, _k('ADM-02.menu.c03.suspend'));

      final suspended = AdminClubMenu.items(
        l10n,
        adminClub(
          kAdminSuspendedClubId,
        ).copyWith(status: ClubStatus.suspended),
      );
      expect(suspended.last.label, l10n.adminClubsActivate);
      expect(suspended.last.danger, isFalse);
    });

    testWidgets('menü "Askıya al" → DLG-28 (neden) → askı, satır askıdakilere '
        'geçer, TST-50', (tester) async {
      await _pumpRoute(tester);
      _feedback
        ..nextMenuResult = AdminClubMenuAction.suspend
        ..nextDialogResult = 'Kural ihlali';
      await _tapKey(tester, _k('ADM-02.menu.c03'));

      expect(_feedback.dialogs, [DialogId.dlg28]);
      final admin = GetIt.I<AdminRepository>() as FakeAdminRepository;
      expect(admin.callsTo('suspendClub').single.args, ['c03', 'Kural ihlali']);
      expect(find.byKey(_k('ADM-02.row.c03')), findsNothing);
      expect(_feedback.toasts, [ToastId.tst50]);
    });

    testWidgets('menü "Askıya al" → DLG-28 vazgeç → yazım yok', (tester) async {
      await _pumpRoute(tester);
      _feedback.nextMenuResult = AdminClubMenuAction.suspend;
      await _tapKey(tester, _k('ADM-02.menu.c03'));
      final admin = GetIt.I<AdminRepository>() as FakeAdminRepository;
      expect(admin.callsTo('suspendClub'), isEmpty);
      expect(find.byKey(_k('ADM-02.row.c03')), findsOneWidget);
    });
  });

  group('DLG-28 · Kulübü askıya al', () {
    Future<void> pumpDialog(WidgetTester tester, {required bool suspending}) =>
        tester.pumpApp(
          Builder(
            builder: (context) => Center(
              child: GuButton(
                label: 'open',
                onPressed: () => showDialog<String>(
                  context: context,
                  builder: (_) => Dialog(
                    child: SuspendClubDialog(
                      clubName: 'E-Spor Kulübü',
                      suspending: suspending,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

    testWidgets('askı: neden zorunlu ("Bu alan zorunlu"); doluyken kapanır', (
      tester,
    ) async {
      await pumpDialog(tester, suspending: true);
      await tester.tap(find.byType(GuButton));
      await tester.pumpAndSettle();
      final l10n = tester.l10n;
      expect(find.text(l10n.dlg28Title('E-Spor Kulübü')), findsOneWidget);
      expect(find.text(l10n.dlg28Body), findsOneWidget);
      expect(find.byKey(SuspendClubDialog.reasonKey), findsOneWidget);

      await tester.tap(find.byKey(SuspendClubDialog.confirmKey));
      await tester.pumpAndSettle();
      expect(find.text(l10n.authErrRequired), findsOneWidget);
      expect(find.byType(SuspendClubDialog), findsOneWidget);

      await tester.enterText(
        find.byKey(SuspendClubDialog.reasonKey),
        'Kural ihlali',
      );
      await tester.pump();
      expect(find.text(l10n.authErrRequired), findsNothing);
      await tester.tap(find.byKey(SuspendClubDialog.confirmKey));
      await tester.pumpAndSettle();
      expect(find.byType(SuspendClubDialog), findsNothing);
    });

    testWidgets('etkinleştirme: girdi yok, "Etkinleştir"', (tester) async {
      await pumpDialog(tester, suspending: false);
      await tester.tap(find.byType(GuButton));
      await tester.pumpAndSettle();
      final l10n = tester.l10n;
      expect(
        find.text(l10n.dlg28TitleActivate('E-Spor Kulübü')),
        findsOneWidget,
      );
      expect(find.byKey(SuspendClubDialog.reasonKey), findsNothing);
      expect(find.text(l10n.adminClubsActivate), findsOneWidget);
    });
  });

  group('ADM-02 · Admin kulüpler · matris', () {
    testWidgets('dolu görünüm', (tester) async {
      await DeviceMatrix.run(tester, (_) => _view, overrides: _overrides());
    });
  });

  group('ADM-02 · Admin kulüpler · golden', () {
    testWidgets('varsayılan açık + koyu', (tester) async {
      await goldenForThemes(tester, 'ADM-02', _view, overrides: _overrides());
    });
  });
}
