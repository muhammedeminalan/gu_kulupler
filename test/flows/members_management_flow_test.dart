// T-33 · Uçtan uca üye yönetimi akışı: gerçek `GuApp` (rota ağacı, guard
// `V`, oturum, kabuk, `AppFeedbackService` — SHT-21 / SHT-22 / SHT-25,
// DLG-19 / DLG-20 / DLG-21 ve toast'lar gerçekten çizilir) + sahte servisler.
// Veri `c03` demo kaydıdır (`seedManage` + `seedApplications`; 21 etkin üye).
//
//   başkan (`u_burak`): CLB-03 → MGT-01 → "Üyeler" (W-37) → MGT-03 → çip →
//   satır menüsü (SHT-21) → "Rolü değiştir" (SHT-22 → DLG-20) → TST-46 →
//   "Üyelikten çıkar" (DLG-19) → TST-47 → Geri al → "Başkanlığı devret"
//   (SHT-25 → DLG-21 "DEVRET") → TST-49 → roller değişti → CSV → TST-29
//   yönetim kurulu (`u032`): başkanın satır menüsü yok; yönetim kurulu
//   üyesini çıkaramaz (SHT-21 satırı devre dışı → TST-X18); CLB-06 yönetici
//   menüsü → SHT-21 (W-20)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/bootstrap/gu_app.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/members_csv.dart';
import 'package:gu_kulupler/features/management/view/manage_members_view.dart';
import 'package:gu_kulupler/features/management/view/mixin/manage_members_view_mixin.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/member_actions_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/president_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/role_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/dialogs/remove_member_dialog.dart';
import 'package:gu_kulupler/product/feedback/dialogs/transfer_presidency_dialog.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/navigation/app_router.dart';
import 'package:gu_kulupler/product/navigation/navigator_keys.dart';
import 'package:gu_kulupler/product/service/file_service.dart';
import 'package:gu_kulupler/product/widget/member/member_row.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../fakes/fake_app_preferences_store.dart';
import '../fakes/fake_auth_repository.dart';
import '../fakes/fake_file_service.dart';
import '../fakes/fake_membership_repository.dart';
import '../fakes/fake_user_repository.dart';
import '../fakes/register_fakes.dart';
import '../features/management/applications_test_support.dart';
import '../features/management/manage_test_support.dart';
import '../fixtures/user_model_fixtures.dart';
import '../helpers/test_asset_bundle.dart';

const String _path = '/clubs/$kManageClubId/manage/members';

/// `c03` yönetim kurulu üyesi (ikinci senaryonun aktörü).
const String _boardUid = 'u032';

Key _k(String id) => GuKey.action(id);

FakeMembershipRepository _memberships() =>
    GetIt.I<MembershipRepository>() as FakeMembershipRepository;

MembershipModel _membership(String uid) =>
    _memberships().memberships[FirestoreIds.membership(kManageClubId, uid)]!;

/// `c03` verisini ve [uid] oturumunu kurar, gerçek `GuApp`'i açar ve `c03`
/// kulüp sayfasına gider.
Future<void> _launch(WidgetTester tester, {String uid = kManageUid}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await GetIt.I.reset();
  registerDefaultFakes();
  addTearDown(GetIt.I.reset);
  final toasts = GuToastController();
  addTearDown(toasts.dispose);
  GetIt.I
    ..unregister<FeedbackService>()
    ..registerSingleton<FeedbackService>(
      AppFeedbackService(
        navigatorKey: rootNavigatorKey,
        toastController: toasts,
      ),
    );
  seedManage();
  seedApplications();
  final email = '$uid@ogr.gumushane.edu.tr';
  (GetIt.I<AuthRepository>() as FakeAuthRepository)
    ..service.uid = uid
    ..service.emailVerified = true
    ..currentUser = AuthUserInfo(uid: uid, email: email, emailVerified: true);
  (GetIt.I<UserRepository>() as FakeUserRepository).putActive(
    uid,
    name: UserModelFixtures.byId(uid).name,
    email: email,
  );
  (GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore)
    ..values[AppPreferenceKeys.onboardingSeen] = true
    ..values[AppPreferenceKeys.notificationPermissionAsked] = true;
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(390, 1800);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    DefaultAssetBundle(
      bundle: TestAssetBundle.instance,
      child: ProviderScope(child: GuApp(toastController: toasts)),
    ),
  );
  await tester.pumpAndSettle();
  expect(
    _container(tester).read(sessionViewModelProvider).status,
    AuthStatus.active,
  );
  _router(tester).go('/clubs/$kManageClubId');
  await tester.pumpAndSettle();
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(GuApp)));

GoRouter _router(WidgetTester tester) =>
    _container(tester).read(appRouterProvider);

String _location(WidgetTester tester) =>
    _router(tester).routerDelegate.currentConfiguration.uri.toString();

Future<void> _tap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _toast(ToastId id) => find.byKey(ValueKey<ToastId>(id));

Future<void> _dismissToast(WidgetTester tester) async {
  await tester.pump(GuMotion.toastUndo);
  await tester.pumpAndSettle();
}

Map<String, ClubRole> _rowRoles(WidgetTester tester) => {
  for (final row in tester.widgetList<MemberRow>(find.byType(MemberRow)))
    row.membership.userId: row.membership.role,
};

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
    await initializeDateFormatting('en_US');
  });

  testWidgets('başkan: MGT-01 → MGT-03 → çip → SHT-21 → SHT-22 → DLG-20 → '
      'TST-46 → DLG-19 → TST-47 → Geri al → SHT-25 → DLG-21 → TST-49 → '
      'CSV → TST-29', (tester) async {
    await _launch(tester);

    // CLB-03 → MGT-01 → "Üyeler" (W-37) → MGT-03.
    await _tap(tester, _k('CLB-03.openManage'));
    await _tap(tester, _k('MGT-01.quick.members'));
    expect(_location(tester), _path);
    expect(find.byType(ManageMembersView), findsOneWidget);
    expect(_rowRoles(tester), hasLength(21));

    // Çip "Üye" → yalnızca sıradan üyeler.
    await _tap(tester, _k('MGT-03.filter.member'));
    expect(_rowRoles(tester).values, everyElement(ClubRole.member));
    expect(_rowRoles(tester), contains('u086'));

    // Satır menüsü → SHT-21 → "Rolü değiştir" → SHT-22 → Yönetim Kurulu →
    // Kaydet → DLG-20 → Onayla → TST-46; satır "Üye" süzgecinden çıkar.
    await _tap(tester, _k('MGT-03.menu.u086'));
    expect(find.byType(MemberActionsSheet), findsOneWidget);
    await _tap(tester, MemberActionsSheet.keyOf(MemberAction.changeRole));
    expect(find.byType(RolePickerSheet), findsOneWidget);
    await _tap(tester, RolePickerSheet.roleKey(ClubRole.board));
    await _tap(tester, RolePickerSheet.saveKey);
    await _tap(tester, FeedbackKeys.of('DLG-20', 'confirm'));
    expect(_toast(ToastId.tst46), findsOneWidget);
    expect(_membership('u086').role, ClubRole.board);
    expect(_rowRoles(tester), isNot(contains('u086')));
    await _dismissToast(tester);

    // "Üyelikten çıkar" → DLG-19 → TST-47; satır düşer → Geri al → geri gelir.
    await _tap(tester, _k('MGT-03.menu.u164'));
    await _tap(tester, MemberActionsSheet.keyOf(MemberAction.remove));
    await _tap(tester, RemoveMemberDialog.confirmKey);
    expect(_toast(ToastId.tst47), findsOneWidget);
    expect(_membership('u164').status, MembershipStatus.removed);
    expect(_rowRoles(tester), isNot(contains('u164')));
    await _tap(tester, FeedbackKeys.of('TST-47', 'undo'));
    expect(_membership('u164').status, MembershipStatus.active);
    expect(_rowRoles(tester), contains('u164'));
    await _dismissToast(tester);

    // "Başkanlığı devret" → SHT-25 → u086 → DLG-21 → "DEVRET" → TST-49.
    await _tap(tester, _k('MGT-03.filter.all'));
    await _tap(tester, _k('MGT-03.transfer'));
    expect(find.byType(PresidentPickerSheet), findsOneWidget);
    expect(
      find.byKey(PresidentPickerSheet.selectKey(kManageUid)),
      findsNothing,
    );
    await _tap(tester, PresidentPickerSheet.selectKey('u086'));
    await _tap(tester, TransferPresidencyDialog.nextKey);
    await tester.enterText(
      find.byKey(TransferPresidencyDialog.wordKey),
      'devret',
    );
    await tester.pumpAndSettle();
    await _tap(tester, TransferPresidencyDialog.confirmKey);
    expect(_toast(ToastId.tst49), findsOneWidget);
    expect(_membership('u086').role, ClubRole.president);
    expect(_membership(kManageUid).role, ClubRole.board);
    expect(_rowRoles(tester), containsPair('u086', ClubRole.president));
    expect(_rowRoles(tester), containsPair(kManageUid, ClubRole.board));
    expect(find.byKey(_k('MGT-03.transfer')), findsNothing);
    await _dismissToast(tester);

    // "⋮" → "Üye listesini dışa aktar (CSV)" → paylaşım → TST-29.
    await _tap(tester, _k('MGT-03.menu'));
    await _tap(tester, ManageMembersViewMixin.exportKey);
    expect(_toast(ToastId.tst29), findsOneWidget);
    final files = GetIt.I<FileService>() as FakeFileService;
    expect(files.written, contains(MembersCsv.fileName));
  });

  testWidgets('yönetim kurulu: başkanın menüsü yok, yönetim kurulu üyesini '
      'çıkaramaz (TST-X18); CLB-06 "⋮" → SHT-21', (tester) async {
    await _launch(tester, uid: _boardUid);
    _router(tester).go(_path);
    await tester.pumpAndSettle();
    expect(find.byType(ManageMembersView), findsOneWidget);
    expect(find.byKey(_k('MGT-03.menu.$kManageUid')), findsNothing);
    expect(find.byKey(_k('MGT-03.transfer')), findsNothing);

    // Yönetim kurulu hedefi: "Üyelikten çıkar" devre dışı → TST-X18, sayfa
    // açık kalır, yazım yok.
    await _tap(tester, _k('MGT-03.menu.u071'));
    await _tap(tester, MemberActionsSheet.keyOf(MemberAction.remove));
    expect(_toast(ToastId.tstX18), findsOneWidget);
    expect(find.byType(MemberActionsSheet), findsOneWidget);
    expect(_membership('u071').status, MembershipStatus.active);
    await _tap(tester, _k('SHT-21.close'));
    await _dismissToast(tester);

    // CLB-06 yönetici menüsü (W-20) → SHT-21.
    _router(tester).go('/clubs/$kManageClubId/members');
    await tester.pumpAndSettle();
    await _tap(tester, _k('CLB-06.menu.u086'));
    expect(find.byType(MemberActionsSheet), findsOneWidget);
    expect(
      find.byKey(MemberActionsSheet.keyOf(MemberAction.remove)),
      findsOneWidget,
    );
  });
}
