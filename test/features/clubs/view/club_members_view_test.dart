// CLB-06 · Üyeler — içerik (üye / yönetici bakışı), durumlar (yükleniyor,
// hata, boş, sonraki sayfa, çevrimdışı), aksiyon envanteri (84 anahtar), her
// aksiyonun sonucu (CLB-03 / CLB-07 gezinmesi, süzgeç, arama, sayfalama,
// çek-yenile, SHT-27 → DLG-13 → TST-09 → Geri al, SHT-10), engellenenlerin
// süzülmesi, cihaz matrisi, açık + koyu golden.
// Referans: design/reference-shots/screens/CLB-06__*.webp,
// design/prototype/app/screens-clubs.js:141–148.
//
// İki kip (CLB-01 / CLB-03 testleriyle aynı düzen):
// * **Durum kipi** (içerik, durumlar, matris, envanter, golden): ekran
//   `pumpApp` ile çizilir, ViewModel durumu ezilir (okuma yapılmaz).
// * **Akış kipi** (aksiyon sonuçları): ekran gerçek ViewModel, sahte depolar
//   ve yer tutucu hedef rotalarla açılır.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/club_members_state.dart';
import 'package:gu_kulupler/features/clubs/provider/club_members_view_model.dart';
import 'package:gu_kulupler/features/clubs/view/club_members_view.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/user_menu_sheet.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_kulupler/product/widget/member/member_row.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_block_repository.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_membership_repository.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';
import '../club_members_test_support.dart';

final Key _back = GuKey.action('CLB-06.back');
final Key _search = GuKey.action('CLB-06.search');
final Key _retry = GuKey.action('CLB-06.retry');
final Key _filterAll = GuKey.action('CLB-06.filter.all');
final Key _filterBoard = GuKey.action('CLB-06.filter.board');
final Key _filterMember = GuKey.action('CLB-06.filter.member');

Key _member(String userId) => GuKey.action('CLB-06.member.$userId');
Key _menu(String userId) => GuKey.action('CLB-06.menu.$userId');

/// Tembel listenin 79 satırı da kurulsun diye uzun yüzey.
const Size _tall = Size(390, 6400);

const String _membersPath = '/clubs/$kMembersClubId/members';

final ClubMembersViewModelProvider _provider = clubMembersViewModelProvider(
  kMembersClubId,
);

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

FakeMembershipRepository _memberships() =>
    GetIt.I<MembershipRepository>() as FakeMembershipRepository;

FakeBlockRepository _blocks() =>
    GetIt.I<BlockRepository>() as FakeBlockRepository;

FakeConnectivityService _connectivity() =>
    GetIt.I<ConnectivityService>() as FakeConnectivityService;

/// Durum kipi: oturum + ViewModel durumu ezilir.
List<Override> _overrides({SessionState? session, ClubMembersState? state}) => [
  sessionViewModelProvider.overrideWithBuild(
    (ref, notifier) => session ?? membersSession(),
  ),
  _provider.overrideWithBuild(
    (ref, notifier) => state ?? loadedMembersState(session: session),
  ),
];

/// Ekranı dolu durumla (ya da [state] ile) çizer.
Future<void> _pump(
  WidgetTester tester, {
  SessionState? session,
  ClubMembersState? state,
  Locale locale = const Locale('tr'),
  ThemeMode theme = ThemeMode.light,
  Size size = const Size(390, 844),
}) async {
  await tester.pumpApp(
    const ClubMembersView(clubId: kMembersClubId),
    locale: locale,
    theme: theme,
    size: size,
    overrides: _overrides(session: session, state: state),
  );
  await tester.pump();
}

/// Akış kipi: ekranı gerçek ViewModel ve yer tutucu rotalarla açar. Depolar
/// ekran açılmadan önce tohumlanır ([seed] ek değişiklik içindir).
Future<GoRouter> _pumpRoute(
  WidgetTester tester, {
  SessionState? session,
  void Function()? seed,
  Size size = _tall,
}) async {
  GoRouter? created;
  await tester.pumpAppRouter(
    size: size,
    routerOf: (_) => created ??= GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(path: '/start', builder: (_, _) => const _Stub('/start')),
        GoRoute(
          path: '/clubs/user/:userId',
          builder: (_, state) => _Stub(state.uri.toString()),
        ),
        GoRoute(
          path: '/clubs/:clubId',
          builder: (_, state) => _Stub(state.uri.toString()),
          routes: [
            GoRoute(
              path: 'members',
              builder: (_, state) =>
                  ClubMembersView(clubId: state.pathParameters['clubId']!),
            ),
          ],
        ),
      ],
    ),
    overrides: [
      sessionViewModelProvider.overrideWithBuild(
        (ref, notifier) => session ?? membersSession(),
      ),
    ],
  );
  final router = created!;
  addTearDown(router.dispose);
  seedMembers();
  seed?.call();
  router.go(_membersPath);
  await tester.pumpAndSettle();
  return router;
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

/// Yer tutucu hedef sayfa: yolunu gösterir.
class _Stub extends StatelessWidget {
  const _Stub(this.path);

  final String path;

  @override
  Widget build(BuildContext context) => Scaffold(body: Text(path));
}

ClubMembersState _stateOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(ClubMembersView, skipOffstage: false)),
).read(_provider);

Iterable<String> _rowIds(WidgetTester tester) => tester
    .widgetList<MemberRow>(find.byType(MemberRow))
    .map((row) => row.membership.userId);

Future<void> _tapKey(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(
    find.descendant(
      of: find.byType(ClubMembersView),
      matching: find.byType(EditableText),
    ),
    text,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('CLB-06 · Üyeler · içerik', () {
    for (final locale in const [Locale('tr'), Locale('en')]) {
      testWidgets('üye bakışı (${locale.languageCode}): başlık + kulüp adı, '
          'arama, çipler, toplam, dört rol grubu; satır menüsü yok', (
        tester,
      ) async {
        await _pump(tester, locale: locale, size: _tall);
        final l10n = tester.l10n;
        final bar = tester.widget<GuAppBar>(find.byType(GuAppBar));
        expect(bar.title, l10n.membersTitle);
        expect(bar.subtitle, kMembersClub.name);
        expect(find.byKey(_back), findsOneWidget);
        final input = tester.widget<GuInput>(find.byType(GuInput));
        expect(input.placeholder, l10n.membersSearch);
        expect(input.icon, GuIcons.search);

        final chips = tester.widgetList<GuChip>(find.byType(GuChip)).toList();
        expect(chips.map((chip) => chip.label), [
          l10n.commonAll,
          l10n.membersFilterBoard,
          l10n.roleMember,
        ]);
        expect(chips.map((chip) => chip.selected), [true, false, false]);
        expect(
          find.text(l10n.membersTotal(kClubMemberships.length)),
          findsOneWidget,
        );

        final headers = tester
            .widgetList<GuGroupHeader>(find.byType(GuGroupHeader))
            .toList();
        expect(
          [for (final header in headers) (header.title, header.trailingText)],
          [
            (l10n.rolePresident.upperFor(locale), '1'),
            (l10n.roleBoard.upperFor(locale), '5'),
            (l10n.roleAdvisor.upperFor(locale), '1'),
            (l10n.roleMember.upperFor(locale), '72'),
          ],
        );
        expect(headers.every((header) => header.sticky), isTrue);

        final rows = tester
            .widgetList<MemberRow>(find.byType(MemberRow))
            .toList();
        expect(rows, hasLength(kClubMemberships.length));
        expect(rows.first.membership.role, ClubRole.president);
        expect(rows.first.user, kClubUsers[rows.first.membership.userId]);
        expect(rows.every((row) => row.onMenu == null), isTrue);
      });
    }

    testWidgets(
      'yönetici bakışı: "⋮" başkan ve danışman dışındaki satırlarda',
      (
        tester,
      ) async {
        final session = membersSession(role: ClubRole.board);
        await _pump(tester, session: session, size: _tall);
        for (final membership in kClubMemberships) {
          final hasMenu =
              membership.role == ClubRole.board ||
              membership.role == ClubRole.member;
          expect(
            find.byKey(_menu(membership.userId)),
            hasMenu ? findsOneWidget : findsNothing,
            reason: '${membership.role.name} ${membership.userId}',
          );
        }
      },
    );

    testWidgets('oturumda engellenen kullanıcı listede çizilmez', (
      tester,
    ) async {
      final blocked = kOtherMember.userId;
      await _pump(
        tester,
        session: membersSession(blocked: {blocked}),
        size: _tall,
      );
      expect(find.byKey(_member(blocked)), findsNothing);
      expect(_rowIds(tester), hasLength(kClubMemberships.length - 1));
      expect(
        find.text(tester.l10n.membersTotal(kClubMemberships.length - 1)),
        findsOneWidget,
      );
    });
  });

  group('CLB-06 · Üyeler · durumlar', () {
    testWidgets('yükleniyor: 6 satır iskeleti; arama ve çipler yerinde', (
      tester,
    ) async {
      await _pump(tester, state: const ClubMembersState(isFetching: true));
      final skeleton = tester.widget<GuSkeletonList>(
        find.byType(GuSkeletonList),
      );
      expect(skeleton.count, 6);
      expect(skeleton.variant, GuSkeletonVariant.tile);
      expect(skeleton.semanticLabel, tester.l10n.commonLoading);
      expect(find.byKey(_search), findsOneWidget);
      expect(find.byKey(_filterAll), findsOneWidget);
      expect(find.byType(MemberRow), findsNothing);
    });

    testWidgets('hata: "Bir şeyler ters gitti" + "Yeniden dene" (satır içi)', (
      tester,
    ) async {
      await _pump(tester, state: const ClubMembersState(isError: true));
      final l10n = tester.l10n;
      final error = tester.widget<GuErrorState>(find.byType(GuErrorState));
      expect(error.title, l10n.sysErrorTitle);
      expect(error.description, l10n.sysErrorDesc);
      expect(error.retryLabel, l10n.commonRetry);
      expect(error.inline, isTrue);
      expect(find.byKey(_retry), findsOneWidget);
      expect(find.byKey(_filterAll), findsOneWidget);
    });

    testWidgets('boş: "Eşleşen üye yok" (küçük boş durum)', (tester) async {
      await _pump(
        tester,
        state: loadedMembersState(base: const ClubMembersState(query: 'qqqq')),
      );
      final empty = tester.widget<GuEmptyState>(find.byType(GuEmptyState));
      expect(empty.illustration, GuIllustrations.emptyClubs);
      expect(empty.title, tester.l10n.membersNoResults);
      expect(empty.layout, GuEmptyStateLayout.compact);
      expect(find.byType(GuGroupHeader), findsNothing);
    });

    testWidgets('sonraki sayfa okunurken liste sonunda 3 satır iskeleti', (
      tester,
    ) async {
      await _pump(
        tester,
        size: _tall,
        state: loadedMembersState(
          base: const ClubMembersState(isLoadingMore: true),
        ),
      );
      expect(
        tester.widget<GuSkeletonList>(find.byType(GuSkeletonList)).count,
        3,
      );
      expect(find.byType(MemberRow), findsWidgets);
    });

    testWidgets('hata → "Yeniden dene" üyeleri yükler', (tester) async {
      await _pumpRoute(
        tester,
        seed: () => _memberships().failNext(FirestoreError.unavailable),
      );
      expect(find.byType(GuErrorState), findsOneWidget);
      await _tapKey(tester, _retry);
      await tester.pumpAndSettle();
      expect(find.byType(GuErrorState), findsNothing);
      expect(_rowIds(tester), hasLength(kClubMemberships.length));
    });

    testWidgets('çevrimdışı: liste ekranda kalır; engelle TST-24 verir, '
        'yazılmaz', (tester) async {
      await _pumpRoute(tester, session: membersSession(role: ClubRole.board));
      _connectivity().isOffline = true;
      _feedback()
        ..nextSheetResult = UserMenuAction.block
        ..dialogResults[DialogId.dlg13] = true;
      await _tapKey(tester, _menu(kOtherMember.userId));
      await tester.pumpAndSettle();
      expect(_feedback().toasts, [ToastId.tst24]);
      expect(_blocks().callsTo('block'), isEmpty);
      expect(_rowIds(tester), hasLength(kClubMemberships.length));
    });
  });

  group('CLB-06 · Üyeler · aksiyon envanteri', () {
    testWidgets('üye bakışı: envanterdeki 84 anahtar birebir', (tester) async {
      await _pump(tester, size: _tall);
      expectActionInventory(tester, 'CLB-06', role: 'member');
    });

    testWidgets('yönetici bakışı: "⋮" anahtarları envanter dışı fazlalık '
        'üretmez', (tester) async {
      await _pump(
        tester,
        session: membersSession(role: ClubRole.board),
        size: _tall,
      );
      expectActionInventory(tester, 'CLB-06');
      expect(find.byKey(_menu(kOtherMember.userId)), findsOneWidget);
    });
  });

  group('CLB-06 · Üyeler · aksiyonlar', () {
    testWidgets('geri → CLB-03 (/clubs/c01); satır → CLB-07 '
        '(kulüp bağlamıyla)', (tester) async {
      final router = await _pumpRoute(tester);
      final userId = kBoardMember.userId;
      await _tapKey(tester, _member(userId));
      await tester.pumpAndSettle();
      expect(_location(router), '/clubs/user/$userId?clubId=$kMembersClubId');

      router.go(_membersPath);
      await tester.pumpAndSettle();
      await _tapKey(tester, _back);
      await tester.pumpAndSettle();
      expect(_location(router), '/clubs/$kMembersClubId');
    });

    testWidgets('rol çipleri listeyi süzer: "Yönetim" başkan + yönetim '
        'kurulu, "Üye" yalnızca üyeler, "Tümü" hepsi', (tester) async {
      await _pumpRoute(tester);
      await _tapKey(tester, _filterBoard);
      expect(_stateOf(tester).roleFilter, MemberRoleFilter.board);
      expect(
        _rowIds(tester),
        unorderedEquals(kClubManagers.map((membership) => membership.userId)),
      );
      expect(
        find.text(tester.l10n.membersTotal(kClubManagers.length)),
        findsOneWidget,
      );

      await _tapKey(tester, _filterMember);
      expect(
        _rowIds(tester),
        unorderedEquals(kClubMembers.map((membership) => membership.userId)),
      );

      await _tapKey(tester, _filterAll);
      expect(_rowIds(tester), hasLength(kClubMemberships.length));
    });

    testWidgets('arama adı süzer (Türkçe küçük harf); eşleşme yoksa "Eşleşen '
        'üye yok"', (tester) async {
      await _pumpRoute(tester);
      final name = kClubUsers[kBoardMember.userId]!.name;
      await _type(tester, name.trUpper());
      expect(_stateOf(tester).query, name.trUpper());
      expect(_rowIds(tester), contains(kBoardMember.userId));
      expect(
        _rowIds(tester).length,
        lessThan(kClubMemberships.length),
      );

      await _type(tester, 'qqqq');
      expect(find.byType(MemberRow), findsNothing);
      expect(find.text(tester.l10n.membersNoResults), findsOneWidget);
    });

    testWidgets('sayfalama: ilk sayfa 20 üye; sona kaydırınca sonraki sayfa '
        'okunur', (tester) async {
      await _pumpRoute(tester, size: const Size(390, 844));
      expect(_stateOf(tester).members, hasLength(Limits.pageSize));
      expect(_stateOf(tester).hasMore, isTrue);
      expect(_memberships().callsTo('listActiveMembers'), hasLength(2));

      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        ),
      );
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(_stateOf(tester).members, hasLength(Limits.pageSize * 2));
      expect(_memberships().callsTo('listActiveMembers'), hasLength(3));
    });

    testWidgets('liste ekranı doldurmuyorsa kalan sayfalar kendiliğinden '
        'okunur (uzun yüzey: 79 satır)', (tester) async {
      await _pumpRoute(tester);
      expect(_stateOf(tester).hasMore, isFalse);
      expect(_rowIds(tester), hasLength(kClubMemberships.length));
    });

    testWidgets('çek-yenile üyeleri yeniden okur', (tester) async {
      await _pumpRoute(tester, size: const Size(390, 844));
      _memberships().calls.clear();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 220));
      await tester.pumpAndSettle();
      expect(_memberships().callsTo('listManagers'), hasLength(1));
      expect(_stateOf(tester).isRefreshing, isFalse);
    });

    testWidgets('"⋮" → SHT-27; "Engelle" → DLG-13 → satır kaybolur + TST-09; '
        '"Geri al" → satır geri gelir', (tester) async {
      await _pumpRoute(tester, session: membersSession(role: ClubRole.board));
      final userId = kOtherMember.userId;
      _feedback()
        ..nextSheetResult = UserMenuAction.block
        ..dialogResults[DialogId.dlg13] = true;
      await _tapKey(tester, _menu(userId));
      await tester.pumpAndSettle();
      expect(_feedback().sheets, [SheetId.sht27]);
      expect(_feedback().dialogs, [DialogId.dlg13]);
      expect(_feedback().toasts, [ToastId.tst09]);
      expect(_blocks().callsTo('block'), hasLength(1));
      expect(find.byKey(_member(userId)), findsNothing);

      _feedback().tapToastAction();
      await tester.pumpAndSettle();
      expect(_blocks().callsTo('softDeleteBlock'), hasLength(1));
      expect(find.byKey(_member(userId)), findsOneWidget);
    });

    testWidgets('SHT-27 "Profili gör" → CLB-07; "Kullanıcıyı şikayet et" → '
        'SHT-10', (tester) async {
      final router = await _pumpRoute(
        tester,
        session: membersSession(role: ClubRole.board),
      );
      final userId = kOtherMember.userId;
      _feedback().nextSheetResult = UserMenuAction.report;
      await _tapKey(tester, _menu(userId));
      await tester.pumpAndSettle();
      expect(_feedback().sheets, [SheetId.sht27, SheetId.sht10]);

      _feedback().nextSheetResult = UserMenuAction.viewProfile;
      await _tapKey(tester, _menu(userId));
      await tester.pumpAndSettle();
      expect(_location(router), '/clubs/user/$userId?clubId=$kMembersClubId');
    });
  });

  group('CLB-06 · Üyeler · cihaz matrisi', () {
    Widget view(BuildContext context) =>
        const ClubMembersView(clubId: kMembersClubId);

    testWidgets('üye bakışı (dolu liste)', (tester) async {
      await DeviceMatrix.run(
        tester,
        view,
        overrides: _overrides(),
        keyboard: true,
        safeAreas: true,
      );
    });

    testWidgets('yönetici bakışı ("⋮"); yükleniyor, hata, boş', (tester) async {
      final manager = membersSession(role: ClubRole.board);
      await DeviceMatrix.run(
        tester,
        view,
        overrides: _overrides(session: manager),
      );
      for (final state in [
        const ClubMembersState(isFetching: true),
        const ClubMembersState(isError: true),
        loadedMembersState(base: const ClubMembersState(query: 'qqqq')),
      ]) {
        await DeviceMatrix.run(
          tester,
          view,
          overrides: _overrides(state: state),
        );
      }
    });
  });

  group('CLB-06 · Üyeler · golden', () {
    testWidgets('varsayılan (üye bakışı) açık + koyu', (tester) async {
      await goldenForThemes(
        tester,
        'CLB-06',
        const ClubMembersView(clubId: kMembersClubId),
        overrides: _overrides(),
      );
    });
  });
}
