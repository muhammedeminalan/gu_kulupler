// T-39 · Uçtan uca admin kulüpler akışı: gerçek `GuApp` (rota ağacı, guard
// `S`, kabuk, `AppFeedbackService` — gerçek menü / dialog / sheet) + sahte
// servisler (`admin_flow_support.dart`).
//
//   süper admin: ADM-01 "Aktif kulüp" KPI'ı (W-45) → ADM-02 → c03 menüsü
//   "Askıya al" → DLG-28 (neden) → TST-50 → "Genel" → CLB-01'de c03 yok →
//   ADM-01 "Askıdaki kulüp" KPI'ı (W-45) → ADM-02 askıdakiler →
//   "Etkinleştir" → DLG-28 → TST-50 → "Kulüp oluştur" (ADM-03)
//   → var olan ad + kategori (SHT-33) + başkan (SHT-25) → ad alanında
//   "zaten var" (CD-63) → yeni ad → TST-33 → ADM-02 (liste yenilendi) →
//   satır → CLB-03 (başkan yönetim kartında) → ADM-02 menü "Düzenle" →
//   danışman (ad + unvan, K-A) → TST-21 → kulüp belgesinde danışman.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/admin/view/admin_club_form_view.dart';
import 'package:gu_kulupler/features/admin/view/admin_clubs_view.dart';
import 'package:gu_kulupler/features/clubs/provider/club_list_view_model.dart';
import 'package:gu_kulupler/features/clubs/view/club_detail_view.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/category_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/president_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/dialogs/suspend_club_dialog.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../fakes/fake_club_repository.dart';
import '../fakes/fake_user_repository.dart';
import '../fixtures/club_model_fixtures.dart';
import '../fixtures/demo_data.dart';
import 'admin_flow_support.dart';

/// Askıya alınıp etkinleştirilen demo kulüp.
const String _clubId = 'c03';

/// Yeni kulübün başkanı.
const String _presidentId = 'u_flow_pres';

Key _k(String id) => GuKey.action(id);

Finder _toast(ToastId id) => find.byKey(ValueKey<ToastId>(id));

/// Toast görünür; süresi dolana dek beklenir (sonraki dokunuşları örtmez).
Future<void> _expectToast(WidgetTester tester, ToastId id) async {
  expect(_toast(id), findsOneWidget);
  await tester.pump(GuMotion.toastDefault);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, Key key, String text) async {
  final field = find.descendant(
    of: find.byKey(key),
    matching: find.byType(EditableText),
  );
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

FakeClubRepository get _clubs =>
    GetIt.I<ClubRepository>() as FakeClubRepository;

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
    await initializeDateFormatting('en_US');
  });

  testWidgets('süper admin: askı / etkinleştirme → kulüp oluştur (ad '
      'çakışması, kategori, başkan) → CLB-03 → düzenle (danışman)', (
    tester,
  ) async {
    await launchAdminApp(tester, uid: DemoDataFixture.superAdminId);
    (GetIt.I<UserRepository>() as FakeUserRepository).putActive(
      _presidentId,
      name: 'Ece Başkan',
      email: 'ece@ogr.gumushane.edu.tr',
    );

    // ADM-01 "Aktif kulüp" KPI'ı → ADM-02 (W-45).
    await flowTap(tester, _k('NAV.tab.admin'));
    await flowTap(tester, _k('ADM-01.kpi.clubs'));
    expect(flowLocation(tester), '/admin/clubs');
    expect(find.byType(AdminClubsView), findsOneWidget);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(AdminClubsView)),
    );

    // Askıya al → DLG-28 (neden zorunlu) → TST-50; satır aktiflerden çıkar.
    await flowTap(tester, _k('ADM-02.menu.$_clubId'));
    await flowTap(tester, _k('ADM-02.menu.$_clubId.suspend'));
    expect(find.byType(SuspendClubDialog), findsOneWidget);
    await _enter(tester, SuspendClubDialog.reasonKey, 'Kural ihlali');
    await flowTap(tester, SuspendClubDialog.confirmKey);
    await _expectToast(tester, ToastId.tst50);
    expect(_clubs.clubs[_clubId]!.isSuspended, isTrue);
    expect(find.byKey(_k('ADM-02.row.$_clubId')), findsNothing);

    // "Genel" → ADM-01 (alt çubuk kökte) → CLB-01 (çek-yenile): askıdaki
    // kulüp kartı yok.
    await flowTap(tester, _k('ADM-02.seg.ADM-01'));
    expect(flowLocation(tester), '/admin');
    await flowTap(tester, _k('NAV.tab.clubs'));
    expect(flowLocation(tester), '/clubs');
    await flowContainer(
      tester,
    ).read(clubListViewModelProvider.notifier).refresh();
    await tester.pumpAndSettle();
    final visible = flowContainer(tester).read(clubListViewModelProvider);
    expect([for (final c in visible.visible) c.id], isNot(contains(_clubId)));
    expect(find.byKey(_k('CLB-01.card.$_clubId')), findsNothing);

    // ADM-01 "Askıdaki kulüp" KPI'ı → ADM-02 askıdakiler (W-45) →
    // "Etkinleştir" → DLG-28 → TST-50.
    await flowTap(tester, _k('NAV.tab.admin'));
    await flowTap(tester, _k('ADM-01.kpi.suspended'));
    expect(flowLocation(tester), '/admin/clubs?tab=suspended');
    expect(find.byKey(_k('ADM-02.row.$_clubId')), findsOneWidget);
    await flowTap(tester, _k('ADM-02.menu.$_clubId'));
    await flowTap(tester, _k('ADM-02.menu.$_clubId.suspend'));
    await flowTap(tester, SuspendClubDialog.confirmKey);
    await _expectToast(tester, ToastId.tst50);
    expect(_clubs.clubs[_clubId]!.isSuspended, isFalse);
    await flowTap(tester, _k('ADM-02.tab.active'));
    expect(find.byKey(_k('ADM-02.row.$_clubId')), findsOneWidget);

    // Kulüp oluştur: var olan ad + kategori + başkan → ad alanında hata.
    await flowTap(tester, _k('ADM-02.create'));
    expect(flowLocation(tester), '/admin/clubs/new');
    expect(find.byType(AdminClubFormView), findsOneWidget);
    await _enter(
      tester,
      _k('ADM-03.name'),
      ClubModelFixtures.byId('c01').name,
    );
    await flowTap(tester, _k('ADM-03.category'));
    await flowTap(tester, CategoryPickerSheet.keyOf('k07'));
    expect(find.text(l10n.catK07), findsOneWidget);
    await flowTap(tester, _k('ADM-03.assignPresident'));
    await flowTap(tester, PresidentPickerSheet.selectKey(_presidentId));
    expect(find.text('Ece Başkan'), findsOneWidget);
    await flowTap(tester, _k('ADM-03.save'));
    expect(find.text(l10n.clubFormErrUnique), findsOneWidget);
    expect(flowLocation(tester), '/admin/clubs/new');

    // Yeni ad → TST-33 → ADM-02; liste yeni kulüple yenilendi.
    await _enter(tester, _k('ADM-03.name'), 'Satranç Kulübü');
    await flowTap(tester, _k('ADM-03.save'));
    await _expectToast(tester, ToastId.tst33);
    expect(flowLocation(tester), '/admin/clubs');
    final created = _clubs.clubs.values.singleWhere(
      (c) => c.name == 'Satranç Kulübü',
    );
    expect(created.categoryId, 'k07');
    expect(created.presidentId, _presidentId);
    // Liste yenilendi (`_refreshList`): aramada yeni kulüp satırı var.
    await _enter(tester, _k('ADM-02.search'), 'satranç');
    expect(find.byKey(_k('ADM-02.row.${created.id}')), findsOneWidget);

    // Satır → CLB-03: başkan yönetim kartında.
    await flowTap(tester, _k('ADM-02.row.${created.id}'));
    expect(flowLocation(tester), '/clubs/${created.id}');
    expect(find.byType(ClubDetailView), findsOneWidget);
    expect(
      find.byKey(_k('CLB-03.about.person.$_presidentId')),
      findsOneWidget,
    );

    // Admin sekmesi → menü "Düzenle" → danışman (ad + unvan) → TST-21.
    await flowTap(tester, _k('CLB-03.back'));
    await flowTap(tester, _k('NAV.tab.admin'));
    expect(flowLocation(tester), '/admin/clubs');
    await flowTap(tester, _k('ADM-02.menu.${created.id}'));
    await flowTap(tester, _k('ADM-02.menu.${created.id}.edit'));
    expect(flowLocation(tester), '/admin/clubs/${created.id}/edit');
    await _enter(tester, _k('ADM-03.advisorTitle'), 'Dr.');
    await _enter(tester, _k('ADM-03.advisorName'), 'Ayşe Kaya');
    await flowTap(tester, _k('ADM-03.save'));
    await _expectToast(tester, ToastId.tst21);
    expect(flowLocation(tester), '/admin/clubs');
    final advisor = _clubs.clubs[created.id]!.advisor;
    expect(advisor?.name, 'Ayşe Kaya');
    expect(advisor?.title, 'Dr.');
    expect(_clubs.clubs[created.id]!.presidentId, _presidentId);
  });
}
