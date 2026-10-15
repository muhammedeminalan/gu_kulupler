// T-38 · Uçtan uca admin genel bakış akışı: gerçek `GuApp` (rota ağacı, guard
// `S`, oturum katmanı, kabuk, `AppFeedbackService`) + sahte servisler. Veri
// demo kayıtlarıdır: tüm kulüpler (askıdaki dahil) ve şikayet belgeleri;
// KPI sayaçları (`AdminRepository.stats`) aynı fixture'lardan sayılır.
//
//   süper admin (`u_admin`, claim `superadmin`): Kulüpler → "Admin" sekmesi →
//   ADM-01 (KPI = fixture sayıları; askıdaki kulüp kulüp listesinden) →
//   "Bekleyen işler" şikayet / askı satırları → en aktif kulüp → CLB-03
//   (Kulüpler yığını) → geri → "Admin" sekmesi → ADM-01 (yığın korunur)
//   süper admin olmayan (`u_ayse`): "Admin" sekmesi yok; `/admin` → `/clubs`
//   + TST-X18
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/admin/view/admin_view.dart';
import 'package:gu_kulupler/features/clubs/view/club_detail_view.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../fixtures/demo_data.dart';
import 'admin_flow_support.dart';

/// Süper admin olmayan öğrenci.
const String _studentUid = 'u_ayse';

Key _k(String id) => GuKey.action(id);

String _kpi(WidgetTester tester, String id) =>
    tester.widget<GuKpi>(find.byKey(_k('ADM-01.kpi.$id'))).value;

int _navItems(WidgetTester tester) =>
    tester.widget<GuBottomNav>(find.byType(GuBottomNav)).items.length;

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
    await initializeDateFormatting('en_US');
  });

  testWidgets('süper admin: Admin sekmesi → ADM-01 (KPI = fixture) → bekleyen '
      'şikayetler → en aktif kulüp CLB-03 → sekmeye dönüş', (tester) async {
    await launchAdminApp(tester, uid: DemoDataFixture.superAdminId);
    final clubs = adminDemoClubs();
    final stats = adminFixtureStats(clubs, adminDemoReports());
    final suspended = clubs.where((c) => c.isSuspended).length;
    expect(stats.openReportCount, greaterThan(0));
    expect(suspended, greaterThan(0));

    // Claim okundu: beşinci sekme "Admin".
    expect(_navItems(tester), GuTab.values.length);
    await flowTap(tester, _k('NAV.tab.admin'));
    expect(flowLocation(tester), '/admin');
    expect(find.byType(AdminView), findsOneWidget);

    // KPI: sayaçlar fixture'larla aynı; askıdaki kulüp kulüp listesinden.
    expect(_kpi(tester, 'clubs'), '${stats.clubCount}');
    expect(_kpi(tester, 'users'), '${stats.userCount}');
    expect(_kpi(tester, 'reports'), '${stats.openReportCount}');
    expect(_kpi(tester, 'suspended'), '$suspended');

    // "Bekleyen işler": açık şikayet ve askıdaki kulüp önizlemesi (uygulamanın
    // etkin dilinde).
    final l10n = AppLocalizations.of(tester.element(find.byType(AdminView)));
    expect(
      find.descendant(
        of: find.byKey(_k('ADM-01.task.reports')),
        matching: find.text(l10n.adminTaskReports(stats.openReportCount)),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(_k('ADM-01.task.suspended')),
        matching: find.text(l10n.adminTaskSuspended(suspended)),
      ),
      findsOneWidget,
    );

    // En aktif kulüp (etkinler `memberCount ↓`) → CLB-03, Kulüpler yığınında.
    final top =
        (clubs.where((c) => c.status == ClubStatus.active).toList()
              ..sort((a, b) => b.memberCount.compareTo(a.memberCount)))
            .first;
    await flowTap(tester, _k('ADM-01.topClub.${top.id}'));
    expect(flowLocation(tester), '/clubs/${top.id}');
    expect(find.byType(ClubDetailView), findsOneWidget);

    // Geri → Kulüpler kökü (alt çubuk yalnızca kökte) → Admin sekmesi: kök
    // ve içerik korunur.
    await flowTap(tester, _k('CLB-03.back'));
    expect(flowLocation(tester), '/clubs');
    await flowTap(tester, _k('NAV.tab.admin'));
    expect(flowLocation(tester), '/admin');
    expect(_kpi(tester, 'reports'), '${stats.openReportCount}');
  });

  testWidgets('süper admin olmayan: Admin sekmesi yok; /admin → /clubs + '
      'TST-X18', (tester) async {
    await launchAdminApp(tester, uid: _studentUid);

    expect(_navItems(tester), GuTab.values.length - 1);
    expect(find.byKey(_k('NAV.tab.admin')), findsNothing);

    flowRouter(tester).go('/admin');
    await tester.pumpAndSettle();
    expect(flowLocation(tester), '/clubs');
    expect(find.byType(AdminView), findsNothing);
    expect(find.byKey(const ValueKey<ToastId>(ToastId.tstX18)), findsOneWidget);
    await tester.pump(GuMotion.toastDefault);
    await tester.pumpAndSettle();
  });
}
