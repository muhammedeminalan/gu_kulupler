// T-40 · Uçtan uca admin şikayetler akışı: gerçek `GuApp` (rota ağacı, guard
// `S`, oturum katmanı, kabuk, `AppFeedbackService`) + sahte servisler; demo
// şikayetleri ve hedefleri (`seedAdminReports`).
//
//   süper admin (`u_admin`): Admin sekmesi → ADM-01 "Bekleyen işler"
//   şikayet satırı → ADM-04 (W-46) → "Genel" → ADM-01 bölme "Şikayetler" →
//   ADM-04 → süzgeç "Gönderi" → p17'nin 3 şikayeti tek satır → SHT-26 →
//   "İçeriği kaldır" → DLG-29 → TST-51 → gönderi gizli, 3 şikayet çözüldü,
//   3 şikayetçiye `report_resolved` (fake çözüm kaydı) → "Çözüldü"
//   sekmesinde grup → "Açık" + süzgeç "Kullanıcı" → SHT-26 → "Kullanıcıyı
//   askıya al" → DLG-30 (neden) → TST-52 → hesap askıda.
//   Bildirim `new_report` (2026-10-16 tek sayfa): Admin › Kullanıcılar →
//   Kulüpler sekmesi → bildirim hedefi → Admin sekmesi, Şikayetler bölmesi
//   (alt çubuk görünür) → gecikmeyle grubun SHT-26'sı.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/constants/app_durations.dart';
import 'package:gu_kulupler/features/admin/view/admin_reports_view.dart';
import 'package:gu_kulupler/features/admin/view/admin_users_view.dart';
import 'package:gu_kulupler/features/admin/view/admin_view.dart';
import 'package:gu_kulupler/features/admin/view/widget/report_detail_sheet.dart';
import 'package:gu_kulupler/features/admin/view/widget/report_group_row.dart';
import 'package:gu_kulupler/product/feedback/dialogs/suspend_user_dialog.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/navigation/notification_navigator.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../fakes/fake_admin_repository.dart';
import '../fakes/fake_post_repository.dart';
import '../fakes/fake_user_repository.dart';
import '../features/admin/admin_reports_test_support.dart';
import '../fixtures/demo_data.dart';
import 'admin_flow_support.dart';

Key _k(String id) => GuKey.action(id);

List<ReportGroupRow> _rows(WidgetTester tester) =>
    tester.widgetList<ReportGroupRow>(find.byType(ReportGroupRow)).toList();

List<String> _rowKeys(WidgetTester tester) => [
  for (final row in _rows(tester)) row.group.key,
];

Future<void> _clearToast(WidgetTester tester) async {
  await tester.pump(GuMotion.toastDefault);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
    await initializeDateFormatting('en_US');
  });

  testWidgets('süper admin: ADM-01 → Şikayetler → süzgeç → 3 şikayet tek '
      'grup → SHT-26 → içeriği kaldır (DLG-29, TST-51) → "Çözüldü" → '
      'kullanıcı askısı (DLG-30, TST-52)', (tester) async {
    await launchAdminApp(tester, uid: DemoDataFixture.superAdminId);
    seedAdminReports();
    final admin = GetIt.I<AdminRepository>() as FakeAdminRepository;
    final posts = GetIt.I<PostRepository>() as FakePostRepository;
    final users = GetIt.I<UserRepository>() as FakeUserRepository;
    bool isP17(ReportModel r) =>
        r.targetType == ReportTargetType.post && r.targetId == 'p17';
    final p17Reports = admin.reports.values.where(isP17).toList();
    expect(p17Reports, hasLength(3));
    expect(p17Reports.every((r) => r.status == ReportStatus.open), isTrue);

    // ADM-01 → "Bekleyen işler" şikayet satırı → ADM-04 (W-46).
    await flowTap(tester, _k('NAV.tab.admin'));
    expect(find.byType(AdminView), findsOneWidget);
    await flowTap(tester, _k('ADM-01.task.reports'));
    expect(flowLocation(tester), '/admin?tab=reports');
    expect(find.byType(AdminReportsView), findsOneWidget);
    expect(_rowKeys(tester), kOpenGroupKeys);

    // "Genel" → ADM-01 → bölme "Şikayetler" → ADM-04 (W-46; tek sayfa, alt
    // çubuk görünür — kullanıcı kararı 2026-10-16).
    await flowTap(tester, _k('ADM-04.seg.ADM-01'));
    expect(flowLocation(tester), '/admin');
    await flowTap(tester, _k('ADM-01.seg.ADM-04'));
    expect(flowLocation(tester), '/admin?tab=reports');
    expect(find.byType(GuBottomNav), findsOneWidget);

    // Süzgeç "Gönderi": yalnızca gönderi grupları; p17'nin 3 şikayeti tek
    // satır.
    await flowTap(tester, _k('ADM-04.filter.post'));
    expect(_rowKeys(tester), ['post_p24', 'post_p17']);
    final row = _rows(tester).firstWhere((r) => r.group.key == 'post_p17');
    expect(row.group.count, 3);

    // Satır → SHT-26 → "İçeriği kaldır" → DLG-29 "Kaldır" → TST-51.
    await flowTap(tester, _k('ADM-04.row.post_p17'));
    expect(find.byType(ReportDetailSheet), findsOneWidget);
    await flowTap(tester, ReportDetailSheet.removeContentKey);
    await flowTap(tester, FeedbackKeys.of('DLG-29', 'confirm'));
    expect(find.byKey(const ValueKey<ToastId>(ToastId.tst51)), findsOneWidget);
    expect(find.byType(ReportDetailSheet), findsNothing);
    expect(_rowKeys(tester), ['post_p24']);

    // Gönderi gizlendi; grubun 3 şikayetinin hepsi `removed` ile çözüldü;
    // 3 şikayetçiye `report_resolved` (fake çözüm kaydının alıcıları).
    expect(posts.posts['p17']!.isHidden, isTrue);
    final resolved = admin.reports.values.where(isP17).toList();
    expect(resolved, hasLength(3));
    for (final report in resolved) {
      expect(report.status, ReportStatus.resolved);
      expect(report.action, ReportAction.removed);
      expect(report.resolvedBy, DemoDataFixture.superAdminId);
    }
    final removal = admin.resolutions.single;
    expect(removal.groupKey, 'post_p17');
    expect(removal.reportIds, hasLength(3));
    expect(
      removal.reporterIds,
      unorderedEquals({for (final r in p17Reports) r.reporterId}),
    );
    expect(removal.reporterIds, hasLength(3));
    expect(removal.hidden, isTrue);
    await _clearToast(tester);

    // "Çözüldü" sekmesi (süzgeç korunur): grup orada, 3 şikayetiyle.
    await flowTap(tester, _k('ADM-04.tab.resolved'));
    expect(_rowKeys(tester), contains('post_p17'));
    final done = _rows(tester).firstWhere((r) => r.group.key == 'post_p17');
    expect(done.group.count, 3);
    expect(done.group.isOpen, isFalse);

    // "Açık" + süzgeç "Kullanıcı" → SHT-26 → "Kullanıcıyı askıya al" →
    // DLG-30 (neden) → TST-52.
    await flowTap(tester, _k('ADM-04.tab.open'));
    await flowTap(tester, _k('ADM-04.filter.user'));
    expect(_rowKeys(tester), ['user_u077']);
    await flowTap(tester, _k('ADM-04.row.user_u077'));
    expect(find.byType(ReportDetailSheet), findsOneWidget);
    await flowTap(tester, ReportDetailSheet.suspendUserKey);
    await tester.enterText(
      find.byKey(SuspendUserDialog.reasonKey),
      'Taciz içerikli mesajlar',
    );
    await tester.pumpAndSettle();
    await flowTap(tester, SuspendUserDialog.confirmKey);
    expect(find.byKey(const ValueKey<ToastId>(ToastId.tst52)), findsOneWidget);
    expect(find.byType(ReportDetailSheet), findsNothing);
    expect(_rowKeys(tester), isEmpty);

    expect(users.users['u077']!.status, UserStatus.suspended);
    expect(admin.callsTo('suspendUser').single.args, [
      'u077',
      'Taciz içerikli mesajlar',
    ]);
    final suspension = admin.resolutions.last;
    expect(suspension.groupKey, 'user_u077');
    expect(suspension.action, ReportAction.suspended);
    await _clearToast(tester);
  });

  testWidgets('bildirim new_report: başka sekme / bölmedeyken Admin › '
      'Şikayetler açılır, gecikmeyle SHT-26 (W-29)', (tester) async {
    await launchAdminApp(tester, uid: DemoDataFixture.superAdminId);
    seedAdminReports();
    await flowTap(tester, _k('NAV.tab.admin'));
    await flowTap(tester, _k('ADM-01.seg.ADM-05'));
    expect(find.byType(AdminUsersView), findsOneWidget);
    await flowTap(tester, _k('NAV.tab.clubs'));
    expect(flowLocation(tester), '/clubs');

    final location = NotificationTargets.locationFor(
      NotificationType.newReport,
      const NotificationRefsModel(reportId: 'post_p17'),
      hasTicket: false,
    )!;
    expect(location, '/admin?tab=reports&reportId=post_p17');
    flowRouter(tester).go(location);
    await tester.pumpAndSettle();
    expect(flowLocation(tester), location);
    expect(find.byType(AdminReportsView), findsOneWidget);
    expect(find.byType(AdminUsersView), findsNothing);
    expect(find.byType(GuBottomNav), findsOneWidget);
    await tester.pump(AppDurations.postNavigationSheetDelay);
    await tester.pumpAndSettle();
    expect(find.byType(ReportDetailSheet), findsOneWidget);
  });
}
