// PRF-01 · Profil — içerik (başlık, istatistikler, Kulüplerim, kısayollar,
// ilgi alanları), koşullu bölümler (yönetilen kulüpler kartı, kulüpsüz kart,
// süper admin rozeti), durumlar (yükleniyor, hata), aksiyon envanteri,
// aksiyon sonuçları (PRF-02 / PRF-03 / PRF-04 / EVT-04 / CLB-03 / CLB-01
// gezinmesi, SHT-16 → TST-57, SHT-18), cihaz matrisi, açık + koyu golden.
// Referans: design/reference-shots/screens/PRF-01__*.webp,
// design/prototype/app/screens-profile.js:6–15.
//
// * Durum kipi: ViewModel durumu ezilir (okuma yok).
// * Akış kipi: gerçek ViewModel + sahte depolar + yer tutucu rotalar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/profile/provider/profile_state.dart';
import 'package:gu_kulupler/features/profile/provider/profile_view_model.dart';
import 'package:gu_kulupler/features/profile/view/profile_view.dart';
import 'package:gu_kulupler/features/profile/view/widget/profile_header.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/photo_source_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/club_category_request.dart';
import 'package:gu_kulupler/product/widget/club/my_club_row.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_app_preferences_store.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';
import '../profile_test_support.dart';

Key _k(String action) => GuKey.action('PRF-01.$action');

/// Durum kipi: oturum + ViewModel durumu ezilir.
List<Override> _overrides([ProfileState? state]) => [
  sessionViewModelProvider.overrideWithBuild(
    (ref, notifier) => profileSession(),
  ),
  profileViewModelProvider.overrideWithBuild(
    (ref, notifier) => state ?? loadedProfile(),
  ),
];

Future<void> _pump(WidgetTester tester, {ProfileState? state}) async {
  await tester.pumpApp(const ProfileView(), overrides: _overrides(state));
  await tester.pump();
}

/// Akış kipi: gerçek ViewModel ve yer tutucu rotalar.
Future<GoRouter> _pumpRoute(
  WidgetTester tester, {
  Size size = const Size(390, 844),
}) async {
  GoRouter? created;
  GoRoute stub(String path, {List<RouteBase> routes = const []}) => GoRoute(
    path: path,
    builder: (_, state) => _Stub(state.uri.toString()),
    routes: routes,
  );
  await tester.pumpAppRouter(
    size: size,
    routerOf: (_) => created ??= GoRouter(
      initialLocation: '/start',
      routes: [
        stub('/start'),
        GoRoute(
          path: '/profile',
          builder: (_, _) => const ProfileView(),
          routes: [stub('edit'), stub('clubs'), stub('saved')],
        ),
        stub('/events', routes: [stub('mine')]),
        stub('/clubs', routes: [stub(':clubId')]),
      ],
    ),
    overrides: [
      sessionViewModelProvider.overrideWithBuild(
        (ref, notifier) => profileSession(),
      ),
    ],
  );
  final router = created!;
  addTearDown(router.dispose);
  seedProfile();
  router.go('/profile');
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

/// c01 başkan, c07 danışman — "Yönettiğim kulüpler" kartı.
ProfileState _managerState() => loadedProfile(
  memberships: profileMembershipsWithRoles({
    'c01': ClubRole.president,
    'c07': ClubRole.advisor,
  }),
);

/// Aktif üyeliği olmayan kullanıcı (yalnızca bekleyen / reddedilen).
ProfileState _noClubsState() => loadedProfile(
  memberships: [
    for (final m in kProfileMemberships)
      if (!m.isActiveMember) m,
  ],
);

void main() {
  group('PRF-01 · Profil · içerik', () {
    testWidgets('başlık, istatistikler 2 · 1 · 1, Kulüplerim (2 satır + '
        'Tümü), kısayollar, 4 ilgi alanı çipi', (tester) async {
      await _pump(tester);
      final l10n = tester.l10n;
      expect(find.text(l10n.navProfile), findsOneWidget);
      expect(find.text(kProfileUser.name), findsOneWidget);
      expect(
        find.text('Elektrik-Elektronik Mühendisliği · 3. sınıf'),
        findsOneWidget,
      );
      expect(find.text(l10n.profileEdit), findsOneWidget);
      final values = [
        for (final key in ['clubs', 'events', 'pending'])
          tester.widget<GuKpi>(find.byKey(_k('stat.$key'))).value,
      ];
      expect(values, ['2', '1', '1']);
      expect(find.text(l10n.clubsMyTitle), findsOneWidget);
      expect(find.byType(MyClubRow), findsNWidgets(2));
      expect(find.byKey(_k('allClubs')), findsOneWidget);
      for (final label in [
        l10n.eventsTickets,
        l10n.savedTitle,
        l10n.settingsTitle,
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text(l10n.profileInterests), findsOneWidget);
      expect(find.byType(GuChip), findsNWidgets(4));
      // Yönetilen kulüp ve süper admin yok.
      expect(find.text(l10n.profileManaged), findsNothing);
      expect(
        find.descendant(
          of: find.byType(ProfileHeader),
          matching: find.byType(GuRoleBadge),
        ),
        findsNothing,
      );
    });

    testWidgets('yönetici: "Yönettiğim kulüpler" kartı (satırlar + Yönetim '
        'paneli); süper admin rozeti', (tester) async {
      await _pump(
        tester,
        state: _managerState().copyWith(isSuperAdmin: true),
      );
      final l10n = tester.l10n;
      expect(find.text(l10n.profileManaged), findsOneWidget);
      expect(find.byKey(_k('managed.c01')), findsOneWidget);
      expect(find.byKey(_k('managed.c07')), findsOneWidget);
      expect(find.byKey(_k('managedAll')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ProfileHeader),
          matching: find.text(l10n.roleSuperadmin),
        ),
        findsOneWidget,
      );
    });

    testWidgets('kulüpsüz: soluk kart + "Etkinlikleri keşfet"; "Tümü" yok', (
      tester,
    ) async {
      await _pump(tester, state: _noClubsState());
      final l10n = tester.l10n;
      expect(find.text(l10n.profileNoClubs), findsOneWidget);
      expect(find.byKey(_k('discover')), findsOneWidget);
      expect(find.byKey(_k('allClubs')), findsNothing);
      expect(find.byType(MyClubRow), findsNothing);
      expect(tester.widget<GuKpi>(find.byKey(_k('stat.clubs'))).value, '0');
    });
  });

  group('PRF-01 · Profil · durumlar', () {
    testWidgets('yükleniyor: başlık + satır iskeleti', (tester) async {
      await _pump(
        tester,
        state: ProfileState(user: kProfileUser, isFetching: true),
      );
      expect(find.byType(ProfileHeader), findsOneWidget);
      expect(find.byType(GuSkeletonList), findsOneWidget);
      expect(find.byType(GuKpi), findsNothing);
    });

    testWidgets('hata: "Bir şeyler ters gitti" + "Yeniden dene"', (
      tester,
    ) async {
      await _pump(
        tester,
        state: ProfileState(user: kProfileUser, isError: true),
      );
      expect(find.text(tester.l10n.sysErrorTitle), findsOneWidget);
      expect(find.byKey(_k('retry')), findsOneWidget);
      expect(find.byType(GuKpi), findsNothing);
    });
  });

  group('PRF-01 · Profil · aksiyon envanteri', () {
    testWidgets('envanterdeki anahtarlar birebir', (tester) async {
      await _pump(tester);
      expectActionInventory(tester, 'PRF-01');
    });
  });

  group('PRF-01 · Profil · aksiyonlar', () {
    for (final (action, location) in [
      ('edit', '/profile/edit'),
      ('stat.clubs', '/profile/clubs'),
      ('stat.pending', '/profile/clubs?tab=pending'),
      ('stat.events', '/events/mine?tab=past'),
      ('allClubs', '/profile/clubs'),
      ('club.c01', '/clubs/c01'),
      ('tickets', '/events/mine'),
      ('saved', '/profile/saved'),
      ('interest.i01', '/clubs'),
      // W-32 (T-28): ayarlar girişleri → SET-01.
      ('settings', '/profile/settings'),
      ('settingsRow', '/profile/settings'),
    ]) {
      testWidgets('$action → $location', (tester) async {
        final router = await _pumpRoute(tester);
        await tester.scrollUntilVisible(
          find.byKey(_k(action)),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.byKey(_k(action)));
        await tester.pumpAndSettle();
        expect(_location(router), location);
      });
    }

    testWidgets('ilgi alanı çipi CLB-01 süzgecine kategorisini ister '
        '(i01 → k01)', (tester) async {
      await _pumpRoute(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byKey(_k('edit'))),
      );
      await tester.scrollUntilVisible(
        find.byKey(_k('interest.i01')),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(_k('interest.i01')));
      await tester.pumpAndSettle();
      expect(container.read(clubCategoryRequestProvider), 'k01');
    });

    testWidgets('avatar → SHT-16 → galeri → TST-57', (tester) async {
      await _pumpRoute(tester);
      (GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore)
              .values[AppPreferenceKeys.photoAccessExplained] =
          true;
      final feedback = GetIt.I<FeedbackService>() as FakeFeedbackService
        ..nextSheetResult = PhotoSourceChoice.gallery;
      await tester.tap(find.byKey(_k('avatar')));
      await tester.pumpAndSettle();
      expect(feedback.sheets, [SheetId.sht16]);
      expect(feedback.toasts, [ToastId.tst57]);
    });

    testWidgets('etkin sekmeye yeniden dokunma başa kaydırır', (tester) async {
      await _pumpRoute(tester, size: const Size(390, 600));
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -400));
      await tester.pumpAndSettle();
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.pixels, greaterThan(0));
      ProviderScope.containerOf(
        tester.element(find.byType(ProfileView)),
      ).read(scrollTopRequestProvider(GuTab.profile).notifier).request();
      await tester.pumpAndSettle();
      expect(position.pixels, 0);
    });
  });

  group('PRF-01 · Profil · cihaz matrisi', () {
    Widget view(BuildContext context) => const ProfileView();

    testWidgets('dolu (güvenli alan, kabuk); yönetici, kulüpsüz, yükleniyor, '
        'hata', (tester) async {
      await DeviceMatrix.run(
        tester,
        view,
        overrides: _overrides(),
        safeAreas: true,
        wrapInShell: true,
        shellTab: GuTab.profile,
      );
      for (final state in [
        _managerState().copyWith(isSuperAdmin: true),
        _noClubsState(),
        ProfileState(user: kProfileUser, isFetching: true),
        ProfileState(user: kProfileUser, isError: true),
      ]) {
        await DeviceMatrix.run(tester, view, overrides: _overrides(state));
      }
    });
  });

  group('PRF-01 · Profil · golden', () {
    testWidgets('varsayılan (açık + koyu)', (tester) async {
      await goldenForThemes(
        tester,
        'PRF-01',
        const ProfileView(),
        overrides: _overrides(),
      );
    });
  });
}
