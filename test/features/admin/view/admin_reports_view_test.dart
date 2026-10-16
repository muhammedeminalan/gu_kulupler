// ADM-04 · Admin şikayetler — içerik (tasarım yakalaması: u_admin; 5 açık
// grup son şikayete göre, "Açık 5" sayacı, neden rozeti, "3 şikayet"
// rozeti, göreli zaman), durumlar (yükleniyor, boş, hata), aksiyon envanteri
// (17 anahtar), temel aksiyon sonuçları (bölme "Genel" / "Kulüpler" → ADM-01
// / ADM-02, sekme / süzgeç, satır → SHT-26, `?reportId=` → SHT-26, SHT-26
// eylemleri → DLG-29 / DLG-30 → çözüm + TST-51 / TST-52, ihlal yok →
// TST-56), ReportGroupRow, cihaz matrisi, açık + koyu golden (kabukta, alt
// çubuk görünür).
// 2026-10-16'dan beri ADM-04 admin kökünün (`AdminView`, `/admin?tab=reports`)
// Şikayetler bölmesidir (kullanıcı kararı; tek sayfa). Bildirim `new_report`
// → `/admin?tab=reports&reportId=` başka bölmedeyken de Şikayetler'i açar.
// Referans: design/reference-shots/screens/ADM-04__*.webp,
// states/ADM-04__*.webp; design/prototype/app/screens-admin.js:61–66,
// sheets.js:120–128, dialogs.js:48–50.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/constants/app_durations.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/admin/provider/admin_reports_state.dart';
import 'package:gu_kulupler/features/admin/provider/admin_reports_view_model.dart';
import 'package:gu_kulupler/features/admin/provider/report_target_preview.dart';
import 'package:gu_kulupler/features/admin/view/admin_overview_view.dart';
import 'package:gu_kulupler/features/admin/view/admin_reports_view.dart';
import 'package:gu_kulupler/features/admin/view/admin_view.dart';
import 'package:gu_kulupler/features/admin/view/mixin/admin_reports_view_mixin.dart';
import 'package:gu_kulupler/features/admin/view/widget/admin_segment_bar.dart';
import 'package:gu_kulupler/features/admin/view/widget/report_detail_sheet.dart';
import 'package:gu_kulupler/features/admin/view/widget/report_group_row.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_admin_repository.dart';
import '../../../fakes/fake_auth_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_session_states.dart';
import '../../../helpers/a11y_guidelines.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';
import '../admin_reports_test_support.dart';
import '../admin_test_support.dart';

Key _k(String id) => GuKey.action(id);

/// Tüm satırlar kurulsun diye uzun yüzey.
const Size _tall = Size(390, 1400);

/// Admin kökü, Şikayetler bölmesi açık.
const Widget _view = AdminView(tab: AdminTab.reports);

/// Durum kipi: oturum + ViewModel durumu ezilir.
List<Override> _overrides({AdminReportsState? state}) => [
  sessionViewModelProvider.overrideWithBuild(
    (ref, notifier) => FakeSessionStates.activeSuper,
  ),
  adminReportsViewModelProvider.overrideWithBuild(
    (ref, notifier) => state ?? loadedAdminReportsState(),
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  AdminReportsState? state,
  Locale locale = const Locale('tr'),
}) async {
  await tester.pumpApp(
    _view,
    locale: locale,
    size: _tall,
    overrides: _overrides(state: state),
  );
  await tester.pump();
}

/// Akış kipi: gerçek ViewModel + yer tutucu rotalar.
Future<GoRouter> _pumpRoute(WidgetTester tester, {String query = ''}) async {
  GoRouter? created;
  Widget stub(GoRouterState state) => _Stub(state.uri.toString());
  await tester.pumpAppRouter(
    size: _tall,
    routerOf: (_) => created ??= GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(path: '/start', builder: (_, s) => stub(s)),
        GoRoute(path: '/admin', builder: (_, s) => adminViewOf(s)),
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
  seedAdminReports();
  (GetIt.I<AuthService>() as FakeAuthService).currentUser = const AuthUserInfo(
    uid: FakeSessionStates.uid,
    email: 'mehmet@ogr.gumushane.edu.tr',
    emailVerified: true,
    displayName: 'Mehmet',
  );
  router.go('/admin?tab=reports$query');
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

List<String> _rowKeys(WidgetTester tester) => [
  for (final row in tester.widgetList<ReportGroupRow>(
    find.byType(ReportGroupRow),
  ))
    row.group.key,
];

FakeFeedbackService get _feedback =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

FakeAdminRepository get _admin =>
    GetIt.I<AdminRepository>() as FakeAdminRepository;

AdminReportsViewMixin _mixin(WidgetTester tester) =>
    tester.state<AdminReportsViewMixin>(find.byType(AdminReportsView));

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(AdminReportsView)));

void main() {
  group('ADM-04 · Admin şikayetler · içerik', () {
    for (final locale in const [Locale('tr'), Locale('en')]) {
      testWidgets('dolu (${locale.languageCode}): başlık + rozet, bölmeli '
          'geçiş (Şikayetler), "Açık 5", 6 süzgeç, 5 grup son şikayete '
          'göre', (tester) async {
        await _pump(tester, locale: locale);
        final l10n = tester.l10n;

        final bar = tester.widget<GuAppBar>(find.byType(GuAppBar));
        expect(bar.title, l10n.navAdmin);
        expect(find.byType(GuRoleBadge), findsOneWidget);
        expect(
          tester.widget<AdminSegmentBar>(find.byType(AdminSegmentBar)).current,
          AdminSegmentBar.reports,
        );
        final tabs = tester.widget<GuTabs>(find.byType(GuTabs));
        expect(tabs.tabs.map((t) => t.label), [
          l10n.reportsTabOpen,
          l10n.reportsTabResolved,
        ]);
        expect(tabs.tabs.first.count, 5);
        expect(find.byType(GuChip), findsNWidgets(6));

        expect(_rowKeys(tester), kOpenGroupKeys);
        expect(find.text(l10n.reportReasonHarassment), findsOneWidget);
        expect(find.text(l10n.contentReports(3)), findsOneWidget);
        expect(find.text('Nisa Yıldırım'), findsOneWidget);
        expect(find.text('E-Spor Kulübü'), findsOneWidget);
        await expectA11yGuidelines(tester);
      });
    }

    testWidgets('çözüldü sekmesi: 3 grup, başarı tonu', (tester) async {
      await _pump(
        tester,
        state: loadedAdminReportsState(tab: AdminReportsTab.resolved),
      );
      expect(_rowKeys(tester), kResolvedGroupKeys);
      final box = tester.widget<GuIconBox>(find.byType(GuIconBox).first);
      expect(box.tone, GuIconBoxTone.success);
    });

    testWidgets('yükleniyor → iskelet; boş → "Açık şikayet yok"; hata → '
        '"Yeniden dene"', (tester) async {
      await _pump(tester, state: const AdminReportsState(isFetching: true));
      expect(find.byType(GuSkeletonList), findsOneWidget);
      expect(find.byType(GuTabs), findsOneWidget);

      await _pump(
        tester,
        state: loadedAdminReportsState().copyWith(
          typeFilter: ReportTargetFilter.event,
        ),
      );
      expect(find.text(tester.l10n.reportsEmptyOpen), findsOneWidget);
      expect(find.byType(ReportGroupRow), findsNothing);

      await _pump(tester, state: const AdminReportsState(isError: true));
      expect(find.byKey(_k('ADM-04.retry')), findsOneWidget);
      expect(find.byType(ReportGroupRow), findsNothing);
    });
  });

  group('ADM-04 · ReportGroupRow', () {
    testWidgets('ikon, neden rozeti, çoklu şikayette "{n} şikayet", '
        'başlık; okunamayan / silinmiş hedef başlığı', (tester) async {
      await _pump(tester);
      final l10n = tester.l10n;
      final p17 = tester.widget<ReportGroupRow>(
        find.byKey(const ValueKey<String>('post_p17')),
      );
      expect(p17.title, startsWith('Geçen haftaki iş modeli'));
      final badges = tester
          .widgetList<GuBadge>(
            find.descendant(
              of: find.byKey(_k('ADM-04.row.post_p17')),
              matching: find.byType(GuBadge),
            ),
          )
          .toList();
      expect(badges.map((b) => b.kind), [
        GuBadgeKind.danger,
        GuBadgeKind.pending,
      ]);
      expect(badges.first.label, l10n.reportReasonSpam);
      expect(
        find.descendant(
          of: find.byKey(_k('ADM-04.row.user_u077')),
          matching: find.byType(GuBadge),
        ),
        findsOneWidget,
      );
      expect(
        ReportGroupRow.iconOf(ReportTargetType.comment),
        GuIcons.messageCircle,
      );

      final group = demoGroup('post_p24');
      expect(
        ReportGroupRow.titleOf(l10n, group, const ReportTargetPreview()),
        l10n.savedRemoved,
      );
      expect(ReportGroupRow.titleOf(l10n, group, null), l10n.reportsTargetPost);
    });
  });

  group('ADM-04 · Admin şikayetler · envanter', () {
    testWidgets('17 anahtar (süper admin, açık sekme)', (tester) async {
      await _pump(tester);
      // Satır anahtarı grup anahtarıdır (`ADM-04.row.{type}_{id}`), prototipin
      // grup belgesi kimliği değil (design_dynamic_actions `ADM-04.row.*`).
      expectActionInventory(
        tester,
        'ADM-04',
        role: 'admin',
        extraExempt: {for (var i = 1; i <= 5; i++) 'ADM-04.row.r0$i'},
      );
    });
  });

  group('ADM-04 · Admin şikayetler · aksiyonlar', () {
    testWidgets('bölme "Genel" → ADM-01; "Kulüpler" → ADM-02; "Kullanıcılar" → '
        'ADM-05 (aynı sayfa, adres eşitlenir)', (tester) async {
      final router = await _pumpRoute(tester);
      await _tapKey(tester, _k('ADM-04.seg.ADM-01'));
      expect(_location(router), '/admin');
      expect(find.byType(AdminOverviewView), findsOneWidget);

      await _tapKey(tester, _k('ADM-01.seg.ADM-04'));
      await _tapKey(tester, _k('ADM-04.seg.ADM-02'));
      expect(_location(router), '/admin?tab=clubs');

      await _tapKey(tester, _k('ADM-02.seg.ADM-04'));
      expect(_location(router), '/admin?tab=reports');
      expect(find.byType(AdminReportsView), findsOneWidget);
      await _tapKey(tester, _k('ADM-04.seg.ADM-05'));
      expect(_location(router), '/admin?tab=users');
    });

    testWidgets('bildirim `new_report` başka bölmedeyken: Şikayetler açılır, '
        'gecikmeyle SHT-26 (W-29)', (tester) async {
      final router = await _pumpRoute(tester);
      await _tapKey(tester, _k('ADM-04.seg.ADM-05'));
      expect(find.byType(AdminReportsView), findsNothing);
      router.go(
        const AdminRoute(
          tab: AdminTab.reports,
          reportId: 'user_u077',
        ).location,
      );
      await tester.pumpAndSettle();
      expect(find.byType(AdminReportsView), findsOneWidget);
      expect(
        tester.widget<AdminSegmentBar>(find.byType(AdminSegmentBar)).current,
        AdminSegmentBar.reports,
      );
      await tester.pump(AppDurations.postNavigationSheetDelay);
      await tester.pumpAndSettle();
      expect(_feedback.sheets, [SheetId.sht26]);
    });

    testWidgets('sekme "Çözüldü" ve süzgeç "Kullanıcı"', (tester) async {
      await _pumpRoute(tester);
      expect(_rowKeys(tester), kOpenGroupKeys);

      await _tapKey(tester, _k('ADM-04.filter.user'));
      expect(_rowKeys(tester), ['user_u077']);

      await _tapKey(tester, _k('ADM-04.tab.resolved'));
      expect(_rowKeys(tester), ['user_u007']);

      await _tapKey(tester, _k('ADM-04.filter.all'));
      expect(_rowKeys(tester), kResolvedGroupKeys);
    });

    testWidgets('satır → SHT-26 (grup okunur)', (tester) async {
      await _pumpRoute(tester);
      await _tapKey(tester, _k('ADM-04.row.post_p17'));
      expect(_feedback.sheets, [SheetId.sht26]);
      expect(_feedback.lastSheetBuilder, isNotNull);
    });

    testWidgets('?reportId= → gecikmeyle SHT-26 (listede olmayan grup da)', (
      tester,
    ) async {
      await _pumpRoute(tester, query: '&reportId=user_u077');
      await tester.pump(AppDurations.postNavigationSheetDelay);
      await tester.pumpAndSettle();
      expect(_feedback.sheets, [SheetId.sht26]);
    });

    testWidgets('SHT-26 "İçeriği kaldır" → DLG-29 → removed çözüm, satır '
        'kalkar, TST-51, sheet kapanır', (tester) async {
      await _pumpRoute(tester);
      _feedback.nextDialogResult = true;
      var closed = false;

      await _mixin(tester).onSheetAction(
        'post_p24',
        ReportDetailAction.removeContent,
        close: () => closed = true,
      );
      await tester.pumpAndSettle();

      expect(_feedback.dialogs, [DialogId.dlg29]);
      expect(_admin.resolutions.single.action, ReportAction.removed);
      expect(find.byKey(_k('ADM-04.row.post_p24')), findsNothing);
      expect(_feedback.toasts, [ToastId.tst51]);
      expect(closed, isTrue);
    });

    testWidgets('SHT-26 "İçeriği kaldır" → DLG-29 vazgeç → yazım yok', (
      tester,
    ) async {
      await _pumpRoute(tester);
      await _mixin(
        tester,
      ).onSheetAction('post_p24', ReportDetailAction.removeContent);
      await tester.pumpAndSettle();
      expect(_admin.callsTo('resolveReports'), isEmpty);
      expect(find.byKey(_k('ADM-04.row.post_p24')), findsOneWidget);
    });

    testWidgets('SHT-26 "Kullanıcıyı askıya al" → DLG-30 (neden) → askı + '
        'çözüm, TST-52', (tester) async {
      await _pumpRoute(tester);
      await _container(
        tester,
      ).read(adminReportsViewModelProvider.notifier).openGroup('user_u077');
      await tester.pumpAndSettle();
      _feedback.nextDialogResult = 'Taciz';

      await _mixin(
        tester,
      ).onSheetAction('user_u077', ReportDetailAction.suspendUser);
      await tester.pumpAndSettle();

      expect(_feedback.dialogs, [DialogId.dlg30]);
      expect(_admin.callsTo('suspendUser').single.args, ['u077', 'Taciz']);
      expect(_admin.resolutions.single.action, ReportAction.suspended);
      expect(_feedback.toasts, [ToastId.tst52]);
    });

    testWidgets('SHT-26 "Şikayeti kapat" → dismissed, TST-56', (tester) async {
      await _pumpRoute(tester);
      await _mixin(
        tester,
      ).onSheetAction('club_c10', ReportDetailAction.dismiss);
      await tester.pumpAndSettle();
      expect(_feedback.dialogs, isEmpty);
      expect(_admin.resolutions.single.action, ReportAction.dismissed);
      expect(_feedback.toasts, [ToastId.tst56]);
    });
  });

  group('ADM-04 · Admin şikayetler · matris', () {
    testWidgets('dolu görünüm', (tester) async {
      await DeviceMatrix.run(tester, (_) => _view, overrides: _overrides());
    });
  });

  group('ADM-04 · Admin şikayetler · golden', () {
    testWidgets('varsayılan açık + koyu', (tester) async {
      await goldenForThemes(
        tester,
        'ADM-04',
        _view,
        overrides: _overrides(),
        wrapInShell: true,
        shellTab: GuTab.admin,
      );
    });
  });
}
