// T-21 · Uçtan uca gönderi / duyuru oluşturma: gerçek `GuApp` (rota ağacı,
// yönlendirme, oturum katmanı, `AppFeedbackService`) + sahte servisler.
//
//   yönetici girişi (`u_mehmet`, `c01` yönetim kurulu) → CLB-03 → "Gönderiler"
//   (FED-01) → "Kulübüne bir şey yaz…" → FED-03 (/clubs/c01/compose) → tür =
//   duyuru → başlık + metin → bildirim açık → "Yayınla" → TST-14 → akışta
//   görünür → "Görüntüle" → FED-02
//   günün hakkı dolmuşken bildirimli duyuru → DLG-24 → "Bildirimsiz yayınla"
//   SHT-08 "Düzenle" → FED-03 düzenleme kipi (?edit=) → "Kaydet" → akıştaki
//   kart güncel
//   kapatırken kaydedilmemiş değişiklik → DLG-25
//   gönderi görselleri (K-18): Storage'daki dosya FED-01 kartında, SHT-34'te
//   ve FED-02'de çizilir; dosyası olmayan görsel yer tutucu kalır
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/bootstrap/gu_app.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/club_feed_state.dart';
import 'package:gu_kulupler/features/clubs/provider/club_feed_view_model.dart';
import 'package:gu_kulupler/features/clubs/view/club_detail_view.dart';
import 'package:gu_kulupler/features/feed/provider/compose_state.dart';
import 'package:gu_kulupler/features/feed/provider/compose_view_model.dart';
import 'package:gu_kulupler/features/feed/view/compose_view.dart';
import 'package:gu_kulupler/features/feed/view/post_detail_view.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/image_viewer_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/post_menu.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/media/post_image_resolver.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/app_router.dart';
import 'package:gu_kulupler/product/navigation/navigator_keys.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../fakes/fake_announcement_counter_repository.dart';
import '../fakes/fake_app_preferences_store.dart';
import '../fakes/fake_auth_repository.dart';
import '../fakes/fake_membership_repository.dart';
import '../fakes/fake_storage_service.dart';
import '../fakes/register_fakes.dart';
import '../features/clubs/club_feed_test_support.dart';
import '../fixtures/membership_model_fixtures.dart';
import '../helpers/test_asset_bundle.dart';

const String _clubPath = '${AppPaths.clubs}/$kFeedClubId';
const String _composePath = '$_clubPath/compose';

const String _title = 'Hackathon kayıtları açıldı';
const String _text = 'Takımını kur, cumaya kadar başvur.';
const String _editedText = 'Takımını kur, pazartesiye kadar başvur.';

Key _k(String id) => GuKey.action(id);

/// Ağ ve disk önbelleği olmadan: Storage yolunu taşıyan bellek görseli
/// (baytlar 1 × 1 saydam PNG).
final class _StorageImage extends MemoryImage {
  _StorageImage(this.url, this.path) : super(_png);

  final String url;
  final String path;

  static final Uint8List _png = Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);
}

/// Ekranda çizilen Storage görsellerinin yolları ([within] içinde).
List<String> _drawnPaths(WidgetTester tester, Finder within) => [
  for (final image in tester.widgetList<Image>(
    find.descendant(of: within, matching: find.byType(Image)),
  ))
    if (image.image case final _StorageImage photo) photo.path,
];

FakeAnnouncementCounterRepository _counters() =>
    GetIt.I<AnnouncementCounterRepository>()
        as FakeAnnouncementCounterRepository;

/// Sahte servisleri kaydeder, `c01` kulübünü yedi gönderisiyle kurar ve
/// gerçek `GuApp`'i `u_mehmet` oturumuyla açar; `u_mehmet` bu akışta kulübün
/// yönetim kurulu üyesidir. [seed] uygulama açılmadan önce çağrılır.
Future<void> _launch(
  WidgetTester tester, {
  List<Override> overrides = const [],
  Future<void> Function()? seed,
}) async {
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
  seedFeed();
  await seed?.call();
  (GetIt.I<MembershipRepository>() as FakeMembershipRepository).put(
    MembershipModelFixtures.c01Mehmet.copyWith(role: ClubRole.board),
  );
  (GetIt.I<AuthRepository>() as FakeAuthRepository).service.emailVerified =
      true;
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
      child: ProviderScope(
        overrides: overrides,
        child: GuApp(toastController: toasts),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final session = _container(tester).read(sessionViewModelProvider);
  expect(session.status, AuthStatus.active);
  expect(session.accessTo(kFeedClubId), ClubAccess.manager);
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(GuApp)));

GoRouter _router(WidgetTester tester) =>
    _container(tester).read(appRouterProvider);

String _location(WidgetTester tester) =>
    _router(tester).routerDelegate.currentConfiguration.uri.toString();

ClubFeedState _feed(WidgetTester tester) =>
    _container(tester).read(clubFeedViewModelProvider(kFeedClubId));

ComposeState _compose(WidgetTester tester, {String? edit}) => _container(
  tester,
).read(composeViewModelProvider(clubId: kFeedClubId, editPostId: edit));

Future<void> _tap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String id, String text) async {
  await tester.enterText(find.byKey(_k(id)), text);
  await tester.pump();
}

Finder _toast(ToastId id) => find.byKey(ValueKey<ToastId>(id));

/// Toast'ın kapanmasını bekler (sıradaki adımın toast'ı karışmasın).
Future<void> _dismissToast(WidgetTester tester) async {
  await tester.pump(GuMotion.toastUndo);
  await tester.pumpAndSettle();
}

/// CLB-03 → "Gönderiler" → "Kulübüne bir şey yaz…" → FED-03.
Future<void> _openCompose(WidgetTester tester) async {
  await _tap(tester, _k('FED-01.compose'));
  expect(_location(tester), _composePath);
  expect(find.byType(ComposeView), findsOneWidget);
}

/// Duyuru formunu doldurur (bildirim anahtarı varsayılan olarak açıktır).
Future<void> _fillAnnouncement(
  WidgetTester tester, {
  required String title,
}) async {
  await _tap(tester, _k('FED-03.type.announcement'));
  await _type(tester, 'FED-03.title', title);
  await _type(tester, 'FED-03.text', _text);
  expect(_compose(tester).type, PostType.announcement);
  expect(_compose(tester).pushEnabled, isTrue);
  expect(_compose(tester).isValid, isTrue);
}

/// Depoda [title] başlığıyla yayınlanmış duyuru.
PostModel _published(String title) =>
    feedPosts().posts.values.singleWhere((post) => post.title == title);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
    await initializeDateFormatting('en_US');
  });

  group('T-21 · akış · gönderi / duyuru oluşturma (FED-03, DLG-24, DLG-25, '
      'TST-14, SHT-08)', () {
    testWidgets('yönetici: CLB-03 → "Gönderiler" → "yazı oluştur" → duyuru + '
        'bildirim → "Yayınla" → TST-14 → akışta görünür → "Görüntüle" → '
        'FED-02; hakkı dolunca DLG-24 → bildirimsiz', (tester) async {
      await _launch(tester);
      _router(tester).go(_clubPath);
      await tester.pumpAndSettle();
      expect(find.byType(ClubDetailView), findsOneWidget);
      await _tap(tester, _k('CLB-03.tab.posts'));
      final before = _feed(tester).posts.length;

      // "Kulübüne bir şey yaz…" → FED-03 → duyuru, bildirim açık → "Yayınla".
      await _openCompose(tester);
      await _fillAnnouncement(tester, title: _title);
      expect(_compose(tester).quotaUsed, 0);
      await _tap(tester, _k('FED-03.publish'));

      // Yazıldı: bildirimli duyuru, yazarı oturumdaki yönetici; günün hakkı
      // bir azaldı.
      final post = _published(_title);
      expect(post.type, PostType.announcement);
      expect(post.text, _text);
      expect(post.authorId, kMembersUid);
      expect(post.clubId, kFeedClubId);
      expect(post.pushSent, isTrue);
      expect(_counters().counts[_counters().keyOf(kFeedClubId)], 1);

      // CLB-03 "Gönderiler" sekmesine dönüldü; akış yenilendi ve yeni duyuru
      // listede; TST-14 ekranda.
      expect(find.byType(ComposeView), findsNothing);
      expect(find.byType(ClubDetailView), findsOneWidget);
      expect(_location(tester), '$_clubPath?tab=posts');
      expect(_feed(tester).posts, hasLength(before + 1));
      expect(_feed(tester).postById(post.id)?.title, _title);
      expect(find.byKey(_k('FED-01.post.${post.id}')), findsOneWidget);
      expect(_toast(ToastId.tst14), findsOneWidget);

      // TST-14 "Görüntüle" → FED-02.
      await _tap(tester, _k('TST-14.action'));
      expect(_location(tester), '$_clubPath/posts/${post.id}');
      expect(find.byType(PostDetailView), findsOneWidget);
      await _tap(tester, _k('FED-02.back'));
      expect(find.byType(ClubDetailView), findsOneWidget);
      await _dismissToast(tester);

      // Günün hakkı doldu (2/2): bildirimli duyuru DLG-24'ü açar; "Vazgeç"
      // hiçbir şey yazmaz, "Bildirimsiz yayınla" bildirimsiz yayınlar.
      _counters().counts[_counters().keyOf(kFeedClubId)] =
          Limits.announcementDailyLimit;
      const silentTitle = 'Salon değişti';
      await _openCompose(tester);
      await _fillAnnouncement(tester, title: silentTitle);
      expect(_compose(tester).limitReached, isTrue);
      await _tap(tester, _k('FED-03.publish'));
      expect(find.byKey(_k('DLG-24.silent')), findsOneWidget);
      await _tap(tester, _k('DLG-24.cancel'));
      expect(find.byKey(_k('DLG-24.silent')), findsNothing);
      expect(find.byType(ComposeView), findsOneWidget);
      expect(
        feedPosts().posts.values.any((post) => post.title == silentTitle),
        isFalse,
      );

      await _tap(tester, _k('FED-03.publish'));
      await _tap(tester, _k('DLG-24.silent'));
      final silent = _published(silentTitle);
      expect(silent.pushSent, isFalse);
      expect(
        _counters().counts[_counters().keyOf(kFeedClubId)],
        Limits.announcementDailyLimit,
      );
      expect(find.byType(ComposeView), findsNothing);
      expect(_feed(tester).postById(silent.id), isNotNull);
      expect(_toast(ToastId.tst14), findsOneWidget);
      await _dismissToast(tester);
    });

    testWidgets('SHT-08 "Düzenle" → FED-03 düzenleme kipi → "Kaydet" → '
        'akıştaki kart güncel; kapatırken kaydedilmemiş değişiklik → DLG-25', (
      tester,
    ) async {
      await _launch(tester);
      _router(tester).go(_clubPath);
      await tester.pumpAndSettle();
      await _tap(tester, _k('CLB-03.tab.posts'));

      // Düzenlenecek duyuru: oturumdaki yöneticinin kendi yazısı.
      await _openCompose(tester);
      await _fillAnnouncement(tester, title: _title);
      await _tap(tester, _k('FED-03.publish'));
      final post = _published(_title);
      await _dismissToast(tester);

      // "…" → SHT-08 → "Düzenle" → FED-03 düzenleme kipi (form dolu).
      await _tap(tester, _k('FED-01.menu.${post.id}'));
      expect(find.byType(PostMenu), findsOneWidget);
      await _tap(tester, PostMenu.keyOf(PostMenuAction.edit));
      expect(_location(tester), '$_composePath?edit=${post.id}');
      expect(find.byType(ComposeView), findsOneWidget);
      expect(_compose(tester, edit: post.id).editPost?.id, post.id);
      expect(_compose(tester, edit: post.id).title, _title);
      expect(_compose(tester, edit: post.id).text, _text);

      // Değişiklik yokken kapat: soru sorulmaz, kulübün "Gönderiler"
      // sekmesine dönülür ve konumda `?edit=` kalmaz.
      await _tap(tester, _k('FED-03.close'));
      expect(find.byType(ComposeView), findsNothing);
      expect(_location(tester), '$_clubPath?tab=posts');
      await _tap(tester, _k('FED-01.menu.${post.id}'));
      await _tap(tester, PostMenu.keyOf(PostMenuAction.edit));
      expect(_location(tester), '$_composePath?edit=${post.id}');

      // Metni değiştir → "Kaydet": yalnızca değişen alan yazılır; akıştaki
      // kart yeniden okunur.
      await _type(tester, 'FED-03.text', _editedText);
      await _tap(tester, _k('FED-03.publish'));
      expect(feedPosts().posts[post.id]!.text, _editedText);
      expect(feedPosts().posts[post.id]!.title, _title);
      expect(feedPosts().posts[post.id]!.editedAt, isNotNull);
      expect(find.byType(ComposeView), findsNothing);
      expect(find.byType(ClubDetailView), findsOneWidget);
      expect(_feed(tester).postById(post.id)!.text, _editedText);
      expect(_toast(ToastId.tst14), findsOneWidget);
      await _dismissToast(tester);

      // Yeni yazı: değişiklik varken kapat → DLG-25. "Düzenlemeye devam et"
      // ekranda kalır; "Kaydetmeden çık" kulübe döner, hiçbir şey yazılmaz.
      final count = feedPosts().posts.length;
      await _openCompose(tester);
      await _type(tester, 'FED-03.text', 'Yarım kalan yazı');
      expect(_compose(tester).isDirty, isTrue);
      await _tap(tester, _k('FED-03.close'));
      expect(find.byKey(_k('DLG-25.discard')), findsOneWidget);
      await _tap(tester, _k('DLG-25.keep'));
      expect(find.byType(ComposeView), findsOneWidget);

      await _tap(tester, _k('FED-03.close'));
      await _tap(tester, _k('DLG-25.discard'));
      expect(find.byType(ComposeView), findsNothing);
      expect(find.byType(ClubDetailView), findsOneWidget);
      expect(_location(tester), startsWith(_clubPath));
      expect(_location(tester), isNot(contains('/compose')));
      expect(feedPosts().posts, hasLength(count));
    });

    testWidgets('gönderi görselleri Storage üzerinden çözülür (K-18): dosyası '
        'olan görsel FED-01 kartında, SHT-34 sayfasında ve FED-02 ekranında '
        'çizilir; olmayan yer tutucu kalır', (tester) async {
      // İki görselli gönderinin (`p02`) yalnızca ilk dosyası Storage'da.
      final uploaded = kImagePost.images.first.path;
      await _launch(
        tester,
        overrides: [
          storageImageFactoryProvider.overrideWithValue(_StorageImage.new),
        ],
        seed: () => (GetIt.I<StorageService>() as FakeStorageService).upload(
          path: uploaded,
          bytes: Uint8List(3),
          contentType: 'image/png',
        ),
      );
      _router(tester).go(_clubPath);
      await tester.pumpAndSettle();
      await _tap(tester, _k('CLB-03.tab.posts'));

      // FED-01: adres gelince kart yeniden çizilir.
      final card = find.byKey(ValueKey<String>(kImagePost.id));
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      expect(_drawnPaths(tester, card), [uploaded]);

      // SHT-34: aynı çözücü.
      await _tap(tester, _k('FED-01.image.${kImagePost.id}.0'));
      final viewer = find.byType(ImageViewerSheet);
      expect(viewer, findsOneWidget);
      expect(_drawnPaths(tester, viewer), contains(uploaded));
      await _tap(tester, ImageViewerSheet.closeKey);
      expect(viewer, findsNothing);

      // FED-02.
      await _tap(tester, _k('FED-01.post.${kImagePost.id}'));
      expect(find.byType(PostDetailView), findsOneWidget);
      expect(_drawnPaths(tester, find.byType(PostDetailView)), [uploaded]);
    });
  });
}
