// T-17 · Uçtan uca kulüp listesi ve arama akışı: gerçek `GuApp` (rota ağacı,
// yönlendirme, oturum katmanı, `AppFeedbackService`) + sahte servisler.
// Oturum hazırdır (aktif öğrenci, hiçbir kulüpte üyeliği yok).
//
//   giriş → CLB-01 (/clubs) → kategori çipi (liste süzülür) → kart → CLB-03
//   → geri → CLB-01 (süzgeç yerinde)
//   CLB-01 → ara → CLB-02 (/clubs/search) → yaz → sonuç satırı → CLB-03
//   (terim son aramalara yazılır)
//   CLB-02 → önerilen kulüpte "Katıl" (onay gerekli) → SHT-05 → gönder →
//   CLB-04
//   CLB-01 → "Filtre / Sırala" → SHT-04 → "Yalnızca anında katılım" →
//   "Sonuçları göster" → liste süzülür
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/bootstrap/gu_app.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/club_filters.dart';
import 'package:gu_kulupler/features/clubs/provider/club_list_state.dart';
import 'package:gu_kulupler/features/clubs/provider/club_list_view_model.dart';
import 'package:gu_kulupler/features/clubs/view/club_applied_view.dart';
import 'package:gu_kulupler/features/clubs/view/club_detail_view.dart';
import 'package:gu_kulupler/features/clubs/view/club_list_view.dart';
import 'package:gu_kulupler/features/clubs/view/widget/club_filter_sheet.dart';
import 'package:gu_kulupler/features/clubs/view/widget/join_application_sheet.dart';
import 'package:gu_kulupler/features/search/view/search_view.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/navigation/app_router.dart';
import 'package:gu_kulupler/product/navigation/navigator_keys.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../fakes/fake_app_preferences_store.dart';
import '../fakes/fake_auth_repository.dart';
import '../fakes/fake_club_repository.dart';
import '../fakes/fake_membership_repository.dart';
import '../fakes/fake_user_repository.dart';
import '../fakes/register_fakes.dart';
import '../fixtures/club_model_fixtures.dart';
import '../helpers/test_asset_bundle.dart';

/// Oturumdaki öğrenci: demo veride aşağıdaki kulüplerde üyeliği yoktur.
const String _uid = 'u_ayse';
const String _email = 'ayse.demir@ogr.gumushane.edu.tr';
const String _name = 'Ayşe Demir';

/// Onay gerekli + not zorunlu kulüp (Spor ve Doğa).
const String _approvalClub = 'c03';

/// Onaysız (anında katılım) kulüpler.
const String _instantClub = 'c07';
const String _otherInstantClub = 'c09';

/// Başvuruya kapalı kulüp.
const String _closedClub = 'c05';

const List<String> _clubIds = [
  _approvalClub,
  _closedClub,
  _instantClub,
  _otherInstantClub,
];

const String _note = 'Dağ yürüyüşlerine katılmak istiyorum.';

Key _k(String id) => GuKey.action(id);

FakeAuthRepository _auth() => GetIt.I<AuthRepository>() as FakeAuthRepository;

FakeUserRepository _users() => GetIt.I<UserRepository>() as FakeUserRepository;

FakeClubRepository _clubs() => GetIt.I<ClubRepository>() as FakeClubRepository;

FakeMembershipRepository _memberships() =>
    GetIt.I<MembershipRepository>() as FakeMembershipRepository;

FakeAppPreferencesStore _preferences() =>
    GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore;

/// Sahte servisleri kaydeder, hazır oturumu ve demo kulüpleri kurar, gerçek
/// `GuApp`'i açar: yönlendirme oturumu Kulüpler sekmesinin köküne (CLB-01)
/// götürür.
Future<void> _launch(WidgetTester tester) async {
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
  _auth()
    ..service.uid = _uid
    ..service.emailVerified = true
    ..currentUser = const AuthUserInfo(
      uid: _uid,
      email: _email,
      emailVerified: true,
    );
  _users().putActive(_uid, name: _name, email: _email);
  _preferences()
    ..values[AppPreferenceKeys.onboardingSeen] = true
    ..values[AppPreferenceKeys.notificationPermissionAsked] = true;
  for (final id in _clubIds) {
    _clubs().clubs[id] = ClubModelFixtures.byId(id);
  }
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
  expect(
    _container(tester).read(sessionViewModelProvider).status,
    AuthStatus.active,
  );
  expect(_location(tester), '/clubs');
  expect(find.byType(ClubListView), findsOneWidget);
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(GuApp)));

GoRouter _router(WidgetTester tester) =>
    _container(tester).read(appRouterProvider);

String _location(WidgetTester tester) =>
    _router(tester).routerDelegate.currentConfiguration.uri.toString();

ClubListState _list(WidgetTester tester) =>
    _container(tester).read(clubListViewModelProvider);

List<String> _visibleIds(WidgetTester tester) => [
  for (final club in _list(tester).visible) club.id,
];

Future<void> _tap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// CLB-01'den aramayı açar ve otomatik odağın yerleşmesini bekler.
Future<void> _openSearch(WidgetTester tester) async {
  await _tap(tester, _k('CLB-01.search'));
  expect(_location(tester), '/clubs/search');
  expect(find.byType(SearchView), findsOneWidget);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
    await initializeDateFormatting('en_US');
  });

  group('T-17 · akış · kulüp listesi ve arama (CLB-01, CLB-02, SHT-04)', () {
    testWidgets('giriş → CLB-01: kategori çipi listeyi süzer → kart → CLB-03 '
        '→ geri → CLB-01 (süzgeç yerinde)', (tester) async {
      await _launch(tester);
      expect(_visibleIds(tester), unorderedEquals(_clubIds));

      final category = ClubModelFixtures.byId(_approvalClub).categoryId;
      await _tap(tester, _k('CLB-01.category.$category'));
      expect(_visibleIds(tester), [_approvalClub]);
      expect(find.byKey(_k('CLB-01.card.$_approvalClub')), findsOneWidget);
      expect(find.byKey(_k('CLB-01.card.$_instantClub')), findsNothing);

      await _tap(tester, _k('CLB-01.card.$_approvalClub'));
      expect(_location(tester), '/clubs/$_approvalClub');
      expect(find.byType(ClubDetailView), findsOneWidget);

      await _tap(tester, _k('CLB-03.back'));
      expect(_location(tester), '/clubs');
      expect(find.byType(ClubDetailView), findsNothing);
      expect(_list(tester).filters.singleCategoryId, category);
      expect(_visibleIds(tester), [_approvalClub]);
    });

    testWidgets('ara → CLB-02: yaz → sonuç satırı → CLB-03 (terim son '
        'aramalara yazılır); önerilen kulüpte "Katıl" → SHT-05 → CLB-04', (
      tester,
    ) async {
      await _launch(tester);
      await _openSearch(tester);

      // Terim bekleme süresinden (250 ms) sonra aranır; TR küçük harf
      // eşleşmesi ("FOTO" → "Fotoğraf …").
      await tester.enterText(find.byKey(_k('CLB-02.input')), 'FOTO');
      await tester.pump();
      await tester.pump(Limits.searchDebounce);
      await tester.pumpAndSettle();
      final result = _k('CLB-02.result.club.$_instantClub');
      expect(find.byKey(result), findsOneWidget);
      expect(
        find.byKey(_k('CLB-02.result.club.$_approvalClub')),
        findsNothing,
      );

      await _tap(tester, result);
      expect(_location(tester), '/clubs/$_instantClub');
      expect(find.byType(ClubDetailView), findsOneWidget);
      expect(_preferences().recentSearches, ['FOTO']);

      // Geri → CLB-01; arama yeniden açılır: önerilen kulüp kartı.
      await _tap(tester, _k('CLB-03.back'));
      expect(_location(tester), '/clubs');
      await _openSearch(tester);
      await _tap(tester, _k('CLB-02.join.$_approvalClub'));
      expect(find.byType(JoinApplicationSheet), findsOneWidget);
      expect(_location(tester), '/clubs/search');

      await tester.enterText(find.byKey(_k('SHT-05.note')), _note);
      await tester.pump();
      await _tap(tester, _k('SHT-05.submit'));
      expect(_memberships().applied.single.clubId, _approvalClub);
      expect(find.byType(JoinApplicationSheet), findsNothing);
      expect(_location(tester), '/clubs/$_approvalClub/applied');
      expect(find.byType(ClubAppliedView), findsOneWidget);
    });

    testWidgets('"Filtre / Sırala" → SHT-04: "Yalnızca anında katılım" → '
        '"Sonuçları göster" → liste süzülür, rozet 1', (tester) async {
      await _launch(tester);
      await _tap(tester, _k('CLB-01.filter'));
      expect(find.byType(ClubFilterSheet), findsOneWidget);

      await _tap(tester, _k('SHT-04.toggle.instantOnly'));
      // Kapanmadan önce liste değişmez.
      expect(_list(tester).filters, ClubFilters.none);

      await _tap(tester, _k('SHT-04.apply'));
      expect(find.byType(ClubFilterSheet), findsNothing);
      expect(_list(tester).filters.instantOnly, isTrue);
      expect(_list(tester).activeFilterCount, 1);
      expect(
        _visibleIds(tester),
        unorderedEquals([_instantClub, _otherInstantClub]),
      );
      expect(find.byKey(_k('CLB-01.card.$_approvalClub')), findsNothing);
      expect(find.byKey(_k('CLB-01.card.$_instantClub')), findsOneWidget);
    });
  });
}
