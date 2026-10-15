// T-18 · Uçtan uca üye listesi ve kullanıcı profili akışı: gerçek `GuApp`
// (rota ağacı, yönlendirme, oturum katmanı, `AppFeedbackService`) + sahte
// servisler.
//
//   üye girişi (`u_mehmet`, `c01` üyesi) → CLB-03 → "Üyeler" sekmesi → "Tüm
//   üyeler" → CLB-06 (/clubs/c01/members) → "Yönetim" çipi (liste süzülür) →
//   üye satırı → CLB-07 (/clubs/c01/members/:id — K-69) → "⋮" → SHT-27 →
//   "Engelle" → DLG-13 onay → engel yazılır, TST-09 → "Geri al" → engel
//   kaldırılır
//   üye olmayan (`u_ayse`) /clubs/c01/members → kulüp sayfasına yönlenir
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/bootstrap/gu_app.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/club_members_state.dart';
import 'package:gu_kulupler/features/clubs/provider/club_members_view_model.dart';
import 'package:gu_kulupler/features/clubs/view/club_detail_view.dart';
import 'package:gu_kulupler/features/clubs/view/club_members_view.dart';
import 'package:gu_kulupler/features/clubs/view/user_profile_view.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/user_menu_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/navigation/app_router.dart';
import 'package:gu_kulupler/product/navigation/navigator_keys.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../fakes/fake_app_preferences_store.dart';
import '../fakes/fake_auth_repository.dart';
import '../fakes/fake_block_repository.dart';
import '../fakes/fake_user_repository.dart';
import '../fakes/register_fakes.dart';
import '../features/clubs/club_members_test_support.dart';
import '../helpers/test_asset_bundle.dart';

/// `c01` üyesi olmayan öğrenci.
const String _outsiderUid = 'u_ayse';
const String _outsiderEmail = 'ayse.demir@ogr.gumushane.edu.tr';

/// Profili açılan yönetim kurulu üyesi (oturumdaki kullanıcı değil).
final String _target = kBoardMember.userId;

Key _k(String id) => GuKey.action(id);

FakeAuthRepository _auth() => GetIt.I<AuthRepository>() as FakeAuthRepository;

FakeBlockRepository _blocks() =>
    GetIt.I<BlockRepository>() as FakeBlockRepository;

/// Sahte servisleri kaydeder, `c01` kulübünü 79 üyeliğiyle kurar ve gerçek
/// `GuApp`'i açar. [outsider] `true` ise oturum `c01` üyesi olmayan
/// öğrencinindir; değilse `u_mehmet` (`c01` üyesi).
Future<void> _launch(WidgetTester tester, {bool outsider = false}) async {
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
  seedMembers();
  _auth().service.emailVerified = true;
  if (outsider) {
    _auth()
      ..service.uid = _outsiderUid
      ..currentUser = const AuthUserInfo(
        uid: _outsiderUid,
        email: _outsiderEmail,
        emailVerified: true,
      );
    (GetIt.I<UserRepository>() as FakeUserRepository).putActive(
      _outsiderUid,
      email: _outsiderEmail,
    );
  }
  (GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore)
    ..values[AppPreferenceKeys.onboardingSeen] = true
    ..values[AppPreferenceKeys.notificationPermissionAsked] = true;
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    // Kapak şablonları depo kökünden eşzamanlı okunur (> 50 KB).
    DefaultAssetBundle(
      bundle: TestAssetBundle.instance,
      child: ProviderScope(child: GuApp(toastController: toasts)),
    ),
  );
  await tester.pumpAndSettle();
  expect(_session(tester).status, AuthStatus.active);
  expect(_location(tester), '/clubs');
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(GuApp)));

GoRouter _router(WidgetTester tester) =>
    _container(tester).read(appRouterProvider);

String _location(WidgetTester tester) =>
    _router(tester).routerDelegate.currentConfiguration.uri.toString();

SessionState _session(WidgetTester tester) =>
    _container(tester).read(sessionViewModelProvider);

ClubMembersState _members(WidgetTester tester) =>
    _container(tester).read(clubMembersViewModelProvider(kMembersClubId));

Future<void> _go(WidgetTester tester, String location) async {
  _router(tester).go(location);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _toast(ToastId id) => find.byKey(ValueKey<ToastId>(id));

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
    await initializeDateFormatting('en_US');
  });

  group('T-18 · akış · üye listesi ve kullanıcı profili (CLB-06, CLB-07, '
      'SHT-27, DLG-13, TST-09)', () {
    testWidgets('üye: CLB-03 → "Tüm üyeler" → CLB-06 → "Yönetim" çipi → üye '
        'satırı → CLB-07 → menü → "Engelle" (DLG-13) → TST-09 → "Geri al"', (
      tester,
    ) async {
      await _launch(tester);
      await _go(tester, '/clubs/$kMembersClubId');
      expect(find.byType(ClubDetailView), findsOneWidget);

      // CLB-03 "Üyeler" sekmesi → "Tüm üyeler" → CLB-06.
      await _tap(tester, _k('CLB-03.tab.members'));
      await _tap(tester, _k('CLB-03.allMembers'));
      expect(_location(tester), '/clubs/$kMembersClubId/members');
      expect(find.byType(ClubMembersView), findsOneWidget);
      expect(_members(tester).managers, hasLength(kClubManagers.length));

      // "Yönetim" çipi: yalnızca başkan + yönetim kurulu kalır.
      await _tap(tester, _k('CLB-06.filter.board'));
      expect(_members(tester).roleFilter, MemberRoleFilter.board);
      expect(_members(tester).visible, hasLength(kClubManagers.length));
      expect(find.byKey(_k('CLB-06.member.$_target')), findsOneWidget);
      expect(
        find.byKey(_k('CLB-06.member.${kOtherMember.userId}')),
        findsNothing,
      );

      // Üye satırı → CLB-07 (CLB-06 altında, K-69); ortak kulüp olduğundan
      // profil görünür.
      await _tap(tester, _k('CLB-06.member.$_target'));
      expect(_location(tester), '/clubs/$kMembersClubId/members/$_target');
      expect(find.byType(UserProfileView), findsOneWidget);
      expect(find.byKey(_k('CLB-07.club.$kMembersClubId')), findsOneWidget);

      // "⋮" → SHT-27 → "Engelle" → DLG-13: "Vazgeç" hiçbir şey yazmaz.
      await _tap(tester, _k('CLB-07.menu'));
      expect(find.byType(UserMenuSheet), findsOneWidget);
      await _tap(tester, UserMenuSheet.keyOf(UserMenuAction.block));
      expect(find.byType(UserMenuSheet), findsNothing);
      await _tap(tester, FeedbackKeys.of('DLG-13', 'cancel'));
      expect(_blocks().blocks, isEmpty);
      expect(_session(tester).isBlocked(_target), isFalse);

      // Onay → engel yazılır, oturumdaki küme güncellenir, bant + TST-09.
      await _tap(tester, _k('CLB-07.menu'));
      await _tap(tester, UserMenuSheet.keyOf(UserMenuAction.block));
      await _tap(tester, FeedbackKeys.of('DLG-13', 'confirm'));
      expect(_blocks().blocks.values.single.blockedId, _target);
      expect(_blocks().blocks.values.single.isDeleted, isFalse);
      expect(_session(tester).blockedUserIds, {_target});
      expect(find.byKey(_k('CLB-07.unblock')), findsOneWidget);
      expect(_toast(ToastId.tst09), findsOneWidget);

      // "Geri al" → kayıt silinmiş olarak işaretlenir (hard delete yok), bant
      // kalkar.
      await _tap(tester, FeedbackKeys.of('TST-09', 'undo'));
      expect(_blocks().blocks.values.single.isDeleted, isTrue);
      expect(_session(tester).blockedUserIds, isEmpty);
      expect(find.byKey(_k('CLB-07.unblock')), findsNothing);

      await tester.pump(GuMotion.toastUndo);
      await tester.pumpAndSettle();

      // Geri → geldiği üye listesi (K-69, kullanıcı kararı 2026-10-15).
      await _tap(tester, _k('CLB-07.back'));
      expect(_location(tester), '/clubs/$kMembersClubId/members');
      expect(find.byType(UserProfileView), findsNothing);
    });

    testWidgets('T-43 · K-69: CLB-03 yönetim kurulu satırı → CLB-07 → geri → '
        'CLB-03; CLB-06 üye satırı → CLB-07 → geri → CLB-06', (tester) async {
      await _launch(tester);
      await _go(tester, '/clubs/$kMembersClubId');
      expect(find.byType(ClubDetailView), findsOneWidget);

      // "Hakkında" sekmesi yönetim kurulu satırı → CLB-07 (CLB-03 altında).
      await _tap(tester, _k('CLB-03.about.person.$_target'));
      expect(_location(tester), '/clubs/$kMembersClubId/user/$_target');
      expect(find.byType(UserProfileView), findsOneWidget);

      // Geri → geldiği kulüp sayfası (kullanıcı kararı 2026-10-15).
      await _tap(tester, _k('CLB-07.back'));
      expect(_location(tester), '/clubs/$kMembersClubId');
      expect(find.byType(UserProfileView), findsNothing);
      expect(find.byType(ClubDetailView), findsOneWidget);

      // CLB-06 → üye satırı → CLB-07 (CLB-06 altında) → geri → CLB-06.
      await _tap(tester, _k('CLB-03.tab.members'));
      await _tap(tester, _k('CLB-03.allMembers'));
      expect(_location(tester), '/clubs/$kMembersClubId/members');
      await _tap(tester, _k('CLB-06.member.$_target'));
      expect(_location(tester), '/clubs/$kMembersClubId/members/$_target');
      expect(find.byType(UserProfileView), findsOneWidget);

      await _tap(tester, _k('CLB-07.back'));
      expect(_location(tester), '/clubs/$kMembersClubId/members');
      expect(find.byType(UserProfileView), findsNothing);
      expect(find.byType(ClubMembersView), findsOneWidget);
    });

    testWidgets('üye olmayan: /clubs/:id/members → kulüp sayfasına '
        'yönlenir', (tester) async {
      await _launch(tester, outsider: true);
      expect(_session(tester).memberships[kMembersClubId], isNull);

      await _go(tester, '/clubs/$kMembersClubId/members');
      expect(_location(tester), '/clubs/$kMembersClubId');
      expect(find.byType(ClubDetailView), findsOneWidget);
      expect(find.byType(ClubMembersView), findsNothing);
    });
  });
}
