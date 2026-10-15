// T-41 · Uçtan uca admin kullanıcılar akışı: gerçek `GuApp` (rota ağacı,
// guard `S`, oturum katmanı, kabuk, `AppFeedbackService`) + sahte servisler;
// demo kullanıcıları, e-posta hesapları ve etkin üyelikler
// (`seedAdminUsers`).
//
//   süper admin (`u_admin`): Admin sekmesi → ADM-01 "Toplam kullanıcı" →
//   ADM-05 (W-47) → büyük harfli e-posta araması → satır → admin CLB-07
//   (e-posta kartı, D-29) → geri → menü "Askıya al" → DLG-30 (neden) →
//   TST-52 → süzgeç "Askıda"da görünür → menü "Askıyı kaldır" → DLG-30 →
//   TST-52 → süzgeçten düşer; kendi satırında askı öğesi yok (W-101 b).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/admin/view/admin_users_view.dart';
import 'package:gu_kulupler/features/admin/view/widget/admin_user_menu.dart';
import 'package:gu_kulupler/features/clubs/view/user_profile_view.dart';
import 'package:gu_kulupler/product/feedback/dialogs/suspend_user_dialog.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../fakes/fake_admin_repository.dart';
import '../fakes/fake_user_repository.dart';
import '../features/admin/admin_users_test_support.dart';
import '../fixtures/demo_data.dart';
import 'admin_flow_support.dart';

/// Askıya alınan öğrenci ("Alp Korkmaz").
const String _uid = 'u153';
const String _email = 'alp.korkmaz@ogr.gumushane.edu.tr';
const String _reason = 'Kural ihlali';

Key _k(String id) => GuKey.action(id);

Finder _row(String uid) => find.byKey(_k('ADM-05.row.$uid'));

Future<void> _search(WidgetTester tester, String query) async {
  await tester.enterText(find.byKey(_k('ADM-05.search')), query);
  await tester.pump(Limits.searchDebounce);
  await tester.pumpAndSettle();
}

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

  testWidgets('süper admin: ADM-01 → Kullanıcılar → e-posta araması → CLB-07 '
      '(e-posta) → askıya al (DLG-30, TST-52) → "Askıda" süzgeci → askıyı '
      'kaldır; kendi satırında askı yok', (tester) async {
    await launchAdminApp(tester, uid: DemoDataFixture.superAdminId);
    seedAdminUsers();
    final admin = GetIt.I<AdminRepository>() as FakeAdminRepository;
    final users = GetIt.I<UserRepository>() as FakeUserRepository;

    // ADM-01 "Toplam kullanıcı" → ADM-05 (W-47).
    await flowTap(tester, _k('NAV.tab.admin'));
    await flowTap(tester, _k('ADM-01.kpi.users'));
    expect(flowLocation(tester), '/admin/users');
    expect(find.byType(AdminUsersView), findsOneWidget);

    // E-posta araması (`@` → `findUserByEmail`, küçük harfe çevrilir).
    await _search(tester, _email.toUpperCase());
    expect(admin.callsTo('findUserByEmail').last.args, [_email]);
    expect(_row(_uid), findsOneWidget);

    // Satır → admin CLB-07: kulüp bağlamı yok, e-posta kartı görünür (D-29).
    await flowTap(tester, _k('ADM-05.row.$_uid'));
    expect(flowLocation(tester), '/admin/users/$_uid');
    expect(find.byType(UserProfileView), findsOneWidget);
    expect(find.text(_email), findsOneWidget);
    expect(find.byKey(_k('CLB-07.copyEmail')), findsOneWidget);

    // Geri → ADM-05 (arama korunur).
    await flowTap(tester, _k('CLB-07.back'));
    expect(flowLocation(tester), '/admin/users');
    expect(_row(_uid), findsOneWidget);

    // Menü "Askıya al" → DLG-30 (neden) → TST-52.
    await flowTap(tester, _k('ADM-05.menu.$_uid'));
    await flowTap(
      tester,
      AdminUserMenu.keyOf(_uid, AdminUserMenuAction.suspend),
    );
    await tester.enterText(find.byKey(SuspendUserDialog.reasonKey), _reason);
    await tester.pumpAndSettle();
    await flowTap(tester, SuspendUserDialog.confirmKey);
    expect(find.byKey(const ValueKey<ToastId>(ToastId.tst52)), findsOneWidget);
    expect(admin.callsTo('suspendUser').single.args, [_uid, _reason]);
    expect(users.users[_uid]!.status, UserStatus.suspended);
    expect(users.accounts[_uid]!.suspendReason, _reason);
    await _clearToast(tester);

    // Süzgeç "Askıda": askıya alınan kullanıcı listede.
    await flowTap(tester, _k('ADM-05.filter.suspended'));
    expect(_row(_uid), findsOneWidget);

    // Menü "Askıyı kaldır" → DLG-30 (neden yok) → TST-52 → süzgeçten düşer.
    await flowTap(tester, _k('ADM-05.menu.$_uid'));
    await flowTap(
      tester,
      AdminUserMenu.keyOf(_uid, AdminUserMenuAction.suspend),
    );
    expect(find.byKey(SuspendUserDialog.reasonKey), findsNothing);
    await flowTap(tester, SuspendUserDialog.confirmKey);
    expect(find.byKey(const ValueKey<ToastId>(ToastId.tst52)), findsOneWidget);
    expect(admin.callsTo('activateUser').single.args, [_uid]);
    expect(users.users[_uid]!.status, UserStatus.active);
    expect(_row(_uid), findsNothing);
    await _clearToast(tester);

    // Kendi satırı: menüde yalnızca "Profili gör" (W-101 b).
    const self = DemoDataFixture.superAdminId;
    await flowTap(tester, _k('ADM-05.filter.all'));
    await _search(tester, 'Kampüs');
    expect(_row(self), findsOneWidget);
    await flowTap(tester, _k('ADM-05.menu.$self'));
    expect(
      find.byKey(AdminUserMenu.keyOf(self, AdminUserMenuAction.profile)),
      findsOneWidget,
    );
    expect(
      find.byKey(AdminUserMenu.keyOf(self, AdminUserMenuAction.suspend)),
      findsNothing,
    );
    await flowTap(tester, AdminUserMenu.scrimKey);
    expect(admin.callsTo('suspendUser'), hasLength(1));
  });
}
