// MGT-08 · İçerik yönetimi — içerik (tasarım yakalaması: u_burak → c03,
// "Gönderiler": p11 · p12 · p10 · p13), sekmeler (Gönderiler · Duyurular ·
// Anketler; duyuruda sabit p08 iğnesi), durumlar (yükleniyor, hata, boş,
// danışman bandı — FAB yok, menü satırları devre dışı), aksiyon envanteri,
// temel aksiyon sonuçları (satır → FED-02; FAB → FED-03 `?type=` seçili
// sekme; "⋮" → sabitle → tek sabit · düzenle → FED-03 `?edit=` (yalnızca
// yazar) · sil → DLG-10 → TST-45; geri → MGT-01), cihaz matrisi, açık + koyu
// golden. Referans: design/reference-shots/screens/MGT-08__*.webp,
// design/prototype/app/screens-manage.js:159–167.
//
// İki kip (MGT-04 testleriyle aynı düzen): durum kipi (`pumpApp`, ViewModel
// durumu ezilir) · akış kipi (gerçek ViewModel, sahte depolar, yer tutucu
// rotalar).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/manage_content_state.dart';
import 'package:gu_kulupler/features/management/provider/manage_content_view_model.dart';
import 'package:gu_kulupler/features/management/view/manage_content_view.dart';
import 'package:gu_kulupler/features/management/view/widget/manage_content_row.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/post_menu.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/widget/manage/manage_header.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_post_repository.dart';
import '../../../fixtures/demo_data.dart';
import '../../../fixtures/post_model_fixtures.dart';
import '../../../helpers/a11y_guidelines.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/fake_app_clock.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';
import '../manage_test_support.dart';

final Key _back = GuKey.action('MGT-08.back');
final Key _create = GuKey.action('MGT-08.create');
final Key _retry = GuKey.action('MGT-08.retry');

Key _row(String id) => GuKey.action('MGT-08.row.$id');
Key _menu(String id) => GuKey.action('MGT-08.menu.$id');
Key _tab(String name) => GuKey.action('MGT-08.tab.$name');

const String _managePath = '/clubs/$kManageClubId/manage';
const String _path = '$_managePath/content';

final ManageContentViewModelProvider _provider = manageContentViewModelProvider(
  kManageClubId,
);

const Widget _view = ManageContentView(clubId: kManageClubId);

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

FakePostRepository _posts() => GetIt.I<PostRepository>() as FakePostRepository;

/// `c03`'ün demo gönderileri (`createdAt ↓`, repository sırası).
List<PostModel> _clubPosts() => PostModelFixtures.ofClub(kManageClubId);

/// Tasarımdaki dolu durum (ViewModel'in üreteceği biçimde).
ManageContentState _loaded({
  ClubAccess access = ClubAccess.manager,
  ClubRole? role = ClubRole.president,
  PostType tab = PostType.post,
  List<PostModel>? items,
  bool isFetching = false,
  bool isError = false,
}) => ManageContentState(
  access: access,
  role: role,
  uid: kManageUid,
  club: kManageClub,
  tab: tab,
  items: items ?? _clubPosts(),
  isFetching: isFetching,
  isError: isError,
);

/// Durum kipi: oturum + ViewModel durumu ezilir.
List<Override> _overrides({
  SessionState? session,
  ManageContentState? state,
}) => [
  appClockProvider.overrideWithValue(FakeAppClock(DemoDataFixture.today)),
  sessionViewModelProvider.overrideWithBuild(
    (ref, notifier) => session ?? manageSession(),
  ),
  _provider.overrideWithBuild((ref, notifier) => state ?? _loaded()),
];

Future<void> _pump(
  WidgetTester tester, {
  SessionState? session,
  ManageContentState? state,
}) async {
  await tester.pumpApp(
    _view,
    overrides: _overrides(session: session, state: state),
  );
  await tester.pump();
}

/// Akış kipi: gerçek ViewModel + yer tutucu rotalar.
Future<GoRouter> _pumpRoute(
  WidgetTester tester, {
  String path = _path,
  void Function()? seed,
}) async {
  GoRouter? created;
  Widget stub(GoRouterState state) => _Stub(state.uri.toString());
  await tester.pumpAppRouter(
    routerOf: (_) => created ??= GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(path: '/start', builder: (_, s) => stub(s)),
        GoRoute(
          path: '/clubs/:clubId',
          builder: (_, s) => stub(s),
          routes: [
            GoRoute(path: 'compose', builder: (_, s) => stub(s)),
            GoRoute(path: 'posts/:postId', builder: (_, s) => stub(s)),
            GoRoute(
              path: 'manage',
              builder: (_, s) => stub(s),
              routes: [
                GoRoute(
                  path: 'content',
                  builder: (_, s) =>
                      ManageContentView(clubId: s.pathParameters['clubId']!),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    overrides: [
      appClockProvider.overrideWithValue(FakeAppClock(DemoDataFixture.today)),
      sessionViewModelProvider.overrideWithBuild(
        (ref, notifier) => manageSession(),
      ),
    ],
  );
  final router = created!;
  addTearDown(router.dispose);
  seedManage();
  seed?.call();
  router.go(path);
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
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

List<String> _rowIds(WidgetTester tester) => [
  for (final row in tester.widgetList<ManageContentRow>(
    find.byType(ManageContentRow),
  ))
    row.post.id,
];

List<String> _pinnedRowIds(WidgetTester tester) => [
  for (final row in tester.widgetList<ManageContentRow>(
    find.byType(ManageContentRow),
  ))
    if (row.post.pinned) row.post.id,
];

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
  });

  group('MGT-08 · İçerik yönetimi · içerik', () {
    testWidgets('dolu: başlık, 3 sekme, arama, "Gönderiler" p11 · p12 · p10 · '
        'p13 + "3 gün önce · 26 beğeni · 2 yorum", FAB "Gönderi"', (
      tester,
    ) async {
      await _pump(tester);
      final l10n = tester.l10n;
      final header = tester.widget<ManageHeader>(find.byType(ManageHeader));
      expect(header.title, l10n.contentTitle);
      expect(header.club, kManageClub);
      expect(header.role, ClubRole.president);
      final segmented = tester.widget<GuSegmented>(find.byType(GuSegmented));
      expect(
        [for (final o in segmented.options) o.label],
        [
          l10n.contentTabPosts,
          l10n.contentTabAnnouncements,
          l10n.contentTabPolls,
        ],
      );
      expect(find.text(l10n.commonSearch), findsOneWidget);
      expect(_rowIds(tester), ['p11', 'p12', 'p10', 'p13']);
      expect(find.text('3 gün önce · 26 beğeni · 2 yorum'), findsOneWidget);
      final fab = tester.widget<GuFab>(find.byKey(_create));
      expect(fab.label, l10n.feedTypePost);
      await expectA11yGuidelines(tester);
    });

    testWidgets('duyurular: sabit p08 iğneli (megaphone); gizli satır '
        '"· gizlendi"', (tester) async {
      final hidden = PostModelFixtures.byId('p10').copyWith(isHidden: true);
      await _pump(
        tester,
        state: _loaded(
          items: [
            for (final p in _clubPosts()) p.id == 'p10' ? hidden : p,
          ],
        ),
      );
      expect(find.textContaining(tester.l10n.contentHidden), findsOneWidget);
      await _pump(tester, state: _loaded(tab: PostType.announcement));
      expect(_rowIds(tester), ['p08']);
      expect(
        find.descendant(
          of: find.byKey(_row('p08')),
          matching: find.byWidgetPredicate(
            (w) => w is GuIcon && w.icon == GuIcons.pin,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('danışman: salt okunur bandı, FAB yok', (tester) async {
      await _pump(
        tester,
        session: manageSession(role: ClubRole.advisor),
        state: _loaded(access: ClubAccess.advisor, role: ClubRole.advisor),
      );
      expect(find.text(tester.l10n.mgtReadOnlyBanner), findsOneWidget);
      expect(find.byKey(_create), findsNothing);
      expect(_rowIds(tester), hasLength(4));
    });

    testWidgets('yükleniyor → iskelet; hata → "Yeniden dene"; boş → '
        '"İçerik yok"', (tester) async {
      await _pump(tester, state: _loaded(items: const [], isFetching: true));
      expect(find.byType(GuSkeletonList), findsOneWidget);
      await _pump(tester, state: _loaded(items: const [], isError: true));
      expect(find.byKey(_retry), findsOneWidget);
      await _pump(tester, state: _loaded(items: const []));
      expect(find.byType(GuEmptyState), findsOneWidget);
      expect(find.text(tester.l10n.contentEmpty), findsOneWidget);
    });
  });

  group('MGT-08 · İçerik yönetimi · envanter', () {
    testWidgets('14 anahtar (yönetici bakışı; DLG-04 yakalama artığı hariç)', (
      tester,
    ) async {
      await _pump(tester);
      // Envanterdeki DLG-04 yakalama sızıntısı muaf listesindedir (K-86).
      expectActionInventory(tester, 'MGT-08', role: 'manager');
    });
  });

  group('MGT-08 · İçerik yönetimi · aksiyonlar', () {
    testWidgets('sekme → Duyurular; FAB → FED-03 `?type=announcement`', (
      tester,
    ) async {
      final router = await _pumpRoute(tester);
      await _tapKey(tester, _tab('announcements'));
      expect(_rowIds(tester), ['p08']);
      await _tapKey(tester, _create);
      expect(
        _location(router),
        '/clubs/$kManageClubId/compose?type=announcement',
      );
    });

    testWidgets('arama: "bakım" → p12', (tester) async {
      await _pumpRoute(tester);
      await tester.enterText(
        find.byKey(GuKey.action('MGT-08.search')),
        'bakım',
      );
      await tester.pumpAndSettle();
      expect(_rowIds(tester), ['p12']);
    });

    testWidgets('"⋮" menüsü: sabitle · düzenle (başkasının — devre dışı) · '
        'sil; sabitle → tek sabit + TST-53', (tester) async {
      await _pumpRoute(tester);
      final feedback = _feedback()..nextMenuResult = PostMenuAction.pin;
      await _tapKey(tester, _menu('p10'));
      final items = feedback.lastMenuItems.cast<GuPopMenuItem>();
      expect(
        [for (final i in items) i.key],
        [
          GuKey.action('MGT-08.pin.p10'),
          GuKey.action('MGT-08.edit.p10'),
          GuKey.action('MGT-08.delete.p10'),
        ],
      );
      expect([for (final i in items) i.disabled], [false, true, false]);
      expect(items.last.danger, isTrue);
      expect(_pinnedRowIds(tester), ['p10']);
      expect(_posts().pinnedByClub[kManageClubId], 'p10');
      expect(_posts().posts['p08']!.pinned, isFalse);
      expect(feedback.toasts, [ToastId.tst53]);
    });

    testWidgets('"⋮" → Sil → DLG-10 → satır düşer + TST-45', (tester) async {
      await _pumpRoute(tester);
      final feedback = _feedback()
        ..nextMenuResult = PostMenuAction.remove
        ..nextDialogResult = true;
      await _tapKey(tester, _menu('p12'));
      expect(feedback.dialogs, [DialogId.dlg10]);
      expect(_rowIds(tester), ['p11', 'p10', 'p13']);
      expect(feedback.toasts, [ToastId.tst45]);
    });

    testWidgets('"⋮" → Düzenle (yazar) → FED-03 `?edit=`', (tester) async {
      final router = await _pumpRoute(
        tester,
        seed: () => _posts().put(
          PostModelFixtures.byId(
            'p13',
          ).copyWith(id: 'mine', authorId: kManageUid),
        ),
      );
      final feedback = _feedback()..nextMenuResult = PostMenuAction.edit;
      await _tapKey(tester, _menu('mine'));
      final edit = feedback.lastMenuItems.cast<GuPopMenuItem>()[1];
      expect(edit.disabled, isFalse);
      expect(_location(router), '/clubs/$kManageClubId/compose?edit=mine');
    });

    testWidgets('satır → FED-02; geri → MGT-01', (tester) async {
      final router = await _pumpRoute(tester);
      await _tapKey(tester, _row('p11'));
      expect(_location(router), '/clubs/$kManageClubId/posts/p11');
      router.go(_path);
      await tester.pumpAndSettle();
      await _tapKey(tester, _back);
      expect(_location(router), _managePath);
    });
  });

  group('MGT-08 · İçerik yönetimi · matris', () {
    testWidgets('yönetici + danışman bakışı', (tester) async {
      await DeviceMatrix.run(tester, (_) => _view, overrides: _overrides());
      await DeviceMatrix.run(
        tester,
        (_) => _view,
        overrides: _overrides(
          session: manageSession(role: ClubRole.advisor),
          state: _loaded(access: ClubAccess.advisor, role: ClubRole.advisor),
        ),
      );
    });
  });

  group('MGT-08 · İçerik yönetimi · golden', () {
    testWidgets('varsayılan açık + koyu', (tester) async {
      await goldenForThemes(tester, 'MGT-08', _view, overrides: _overrides());
    });
  });
}
