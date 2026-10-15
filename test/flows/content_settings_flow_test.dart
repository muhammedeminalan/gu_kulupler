// T-36 · Uçtan uca içerik yönetimi ve kulüp ayarları akışı: gerçek `GuApp`
// (rota ağacı, guard `V` / `M`, oturum, kabuk, `AppFeedbackService` —
// SHT-16, DLG-25, DLG-10, açılır menü ve toast'lar gerçekten çizilir) +
// sahte servisler. Veri `c03` demo kaydıdır (`seedManage`; p08 sabit duyuru)
// + başkanın yazdığı ikinci duyuru.
//
//   başkan (`u_burak`): CLB-03 → MGT-01 "Kulüp ayarları" (W-40) → MGT-09 →
//   kilitli ad → TST-20 → açıklama → geri → DLG-25 "Kaydet" → TST-21, MGT-01
//   → MGT-09 → başvuruları kapat → TST-21 → TST-54 → logo (SHT-16 galeri) →
//   kaydet → CLB-03 başlığında yüklenen logo; MGT-01 "Bu ay duyuru" (W-40) →
//   MGT-08 duyurular → sabitle (p08'in iğnesi kalkar, TST-53) → sil (DLG-10)
//   → TST-45 → Geri al; MGT-01 "Duyuru yap" (W-97) → FED-03 duyuru seçili.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/bootstrap/gu_app.dart';
import 'package:gu_kulupler/core/constants/app_durations.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/view/widget/club_header.dart';
import 'package:gu_kulupler/features/feed/provider/compose_view_model.dart';
import 'package:gu_kulupler/features/feed/view/compose_view.dart';
import 'package:gu_kulupler/features/management/view/club_settings_view.dart';
import 'package:gu_kulupler/features/management/view/manage_content_view.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/photo_source_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/media/post_image_resolver.dart';
import 'package:gu_kulupler/product/navigation/app_router.dart';
import 'package:gu_kulupler/product/navigation/navigator_keys.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../fakes/fake_app_preferences_store.dart';
import '../fakes/fake_auth_repository.dart';
import '../fakes/fake_club_repository.dart';
import '../fakes/fake_image_picker_service.dart';
import '../fakes/fake_management_repository.dart';
import '../fakes/fake_post_repository.dart';
import '../fakes/fake_user_repository.dart';
import '../fakes/register_fakes.dart';
import '../features/management/manage_test_support.dart';
import '../fixtures/post_model_fixtures.dart';
import '../fixtures/user_model_fixtures.dart';
import '../helpers/test_asset_bundle.dart';

const String _club = '/clubs/$kManageClubId';
const String _manage = '$_club/manage';

/// Başkanın yazdığı ikinci (sabit olmayan) duyuru.
const String _announcementId = 'p_t36';

Key _k(String id) => GuKey.action(id);

/// 1 × 1 saydam PNG: seçilen logo ve Storage görseli (çözülebilir bayt).
final Uint8List _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Ağ ve disk önbelleği olmadan: Storage yolunu taşıyan bellek görseli.
final class _StorageImage extends MemoryImage {
  _StorageImage(this.url, this.path, {this.coverEdgePx}) : super(_png);

  final String url;
  final String path;

  /// Gösterim boyutu ipucu (`BoundedImage.coverEdgePx`).
  final int? coverEdgePx;
}

/// [within] içinde çizilen Storage görsellerinin yolları.
List<String> _drawnPaths(WidgetTester tester, Finder within) => [
  for (final image in tester.widgetList<Image>(
    find.descendant(of: within, matching: find.byType(Image)),
  ))
    if (image.image case final _StorageImage photo) photo.path,
];

FakePostRepository _posts() => GetIt.I<PostRepository>() as FakePostRepository;

FakeManagementRepository _management() =>
    GetIt.I<ManagementRepository>() as FakeManagementRepository;

ClubModel _clubDoc() =>
    (GetIt.I<ClubRepository>() as FakeClubRepository).clubs[kManageClubId]!;

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
  seedManage();
  (GetIt.I<ImagePickerService>() as FakeImagePickerService).nextPick =
      PickedImage(bytes: _png, contentType: 'image/png', width: 1, height: 1);
  final p08 = PostModelFixtures.byId('p08');
  expect(p08.pinned, isTrue);
  _posts().put(
    p08.copyWith(
      id: _announcementId,
      authorId: kManageUid,
      pinned: false,
      createdAt: p08.createdAt?.add(const Duration(hours: 1)),
    ),
  );
  const uid = kManageUid;
  const email = '$uid@ogr.gumushane.edu.tr';
  (GetIt.I<AuthRepository>() as FakeAuthRepository)
    ..service.uid = uid
    ..service.emailVerified = true
    ..currentUser = const AuthUserInfo(
      uid: uid,
      email: email,
      emailVerified: true,
    );
  (GetIt.I<UserRepository>() as FakeUserRepository).putActive(
    uid,
    name: UserModelFixtures.byId(uid).name,
    email: email,
  );
  (GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore)
    ..values[AppPreferenceKeys.onboardingSeen] = true
    ..values[AppPreferenceKeys.notificationPermissionAsked] = true
    // Galeri ön açıklaması (DLG-05) daha önce gösterildi.
    ..values[AppPreferenceKeys.photoAccessExplained] = true;
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(390, 1800);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    DefaultAssetBundle(
      bundle: TestAssetBundle.instance,
      child: ProviderScope(
        overrides: [
          storageImageFactoryProvider.overrideWithValue(_StorageImage.new),
        ],
        child: GuApp(toastController: toasts),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(
    _container(tester).read(sessionViewModelProvider).status,
    AuthStatus.active,
  );
  _router(tester).go(_club);
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

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
    await initializeDateFormatting('en_US');
  });

  testWidgets('başkan: MGT-09 (TST-20, DLG-25 "Kaydet", TST-54, logo → '
      'CLB-03); MGT-08 duyurular (tek sabit, sil → Geri al); "Duyuru yap" → '
      'FED-03 duyuru', (tester) async {
    await _launch(tester);
    final original = _clubDoc();
    expect(original.logoPath, isNull);
    expect(original.applicationsOpen, isTrue);

    // CLB-03 → MGT-01 → "Kulüp ayarları" (W-40) → MGT-09.
    await _tap(tester, _k('CLB-03.openManage'));
    await _tap(tester, _k('MGT-01.quick.settings'));
    expect(_location(tester), '$_manage/settings');
    expect(find.byType(ClubSettingsView), findsOneWidget);

    // Kilitli ad → TST-20; değer değişmez.
    await _tap(tester, _k('MGT-09.lockedName'));
    expect(_toast(ToastId.tst20), findsOneWidget);
    await _dismissToast(tester);

    // Açıklama → geri → DLG-25 "Kaydet" → TST-21, panele dönülür.
    await tester.enterText(find.byKey(_k('MGT-09.about')), 'Yeni açıklama.');
    await tester.pumpAndSettle();
    await _tap(tester, _k('MGT-09.back'));
    expect(find.byKey(FeedbackKeys.of('DLG-25', 'save')), findsOneWidget);
    await _tap(tester, FeedbackKeys.of('DLG-25', 'save'));
    expect(_toast(ToastId.tst21), findsOneWidget);
    expect(_location(tester), _manage);
    expect(_clubDoc().about, 'Yeni açıklama.');
    expect(_clubDoc().name, original.name);
    await _dismissToast(tester);

    // Başvuruları kapat → "Kaydet" → TST-21, ardından TST-54.
    await _tap(tester, _k('MGT-01.quick.settings'));
    await _tap(tester, _k('MGT-09.toggle.applicationsOpen'));
    await _tap(tester, _k('MGT-09.save'));
    expect(_toast(ToastId.tst21), findsOneWidget);
    expect(_clubDoc().applicationsOpen, isFalse);
    await tester.pump(AppDurations.applicationsToastDelay);
    await tester.pumpAndSettle();
    expect(_toast(ToastId.tst54), findsOneWidget);
    expect(_location(tester), '$_manage/settings');
    await _dismissToast(tester);

    // Logo: SHT-16 → galeri → "Kaydet" → yeni dosya + `logoPath`.
    await _tap(tester, _k('MGT-09.logo'));
    await _tap(tester, PhotoSourceSheet.keyOf(PhotoSourceChoice.gallery));
    await _tap(tester, _k('MGT-09.save'));
    expect(_toast(ToastId.tst21), findsOneWidget);
    final upload = _management().mediaUploads.single;
    expect(upload.isLogo, isTrue);
    expect(upload.uploaderId, kManageUid);
    expect(_clubDoc().logoPath, upload.path);
    expect(_clubDoc().coverPath, original.coverPath);
    await _dismissToast(tester);

    // CLB-03 başlığı yüklenen logoyu çizer (dönüşte kulüp yeniden okunur).
    _router(tester).go(_club);
    await tester.pumpAndSettle();
    expect(_drawnPaths(tester, find.byType(ClubHeader)), [upload.path]);

    // MGT-01 "Bu ay duyuru" (W-40) → MGT-08 duyurular sekmesi.
    await _tap(tester, _k('CLB-03.openManage'));
    await _tap(tester, _k('MGT-01.kpi.announcements'));
    expect(_location(tester), '$_manage/content?tab=announcement');
    final content = tester.widget<ManageContentView>(
      find.byType(ManageContentView),
    );
    expect(content.tab, PostType.announcement);
    expect(find.byKey(_k('MGT-08.row.p08')), findsOneWidget);
    expect(find.byKey(_k('MGT-08.row.$_announcementId')), findsOneWidget);
    expect(find.byKey(_k('MGT-08.row.p10')), findsNothing);

    // Sabitle → TST-53; kulüpte tek sabit gönderi kalır.
    await _tap(tester, _k('MGT-08.menu.$_announcementId'));
    await _tap(tester, _k('MGT-08.pin.$_announcementId'));
    expect(_toast(ToastId.tst53), findsOneWidget);
    expect(_posts().posts[_announcementId]!.pinned, isTrue);
    expect(_posts().posts['p08']!.pinned, isFalse);
    await _dismissToast(tester);

    // Sil → DLG-10 → TST-45 → Geri al.
    await _tap(tester, _k('MGT-08.menu.$_announcementId'));
    await _tap(tester, _k('MGT-08.delete.$_announcementId'));
    await _tap(tester, FeedbackKeys.of('DLG-10', 'confirm'));
    expect(_toast(ToastId.tst45), findsOneWidget);
    expect(_posts().posts[_announcementId]!.isDeleted, isTrue);
    expect(find.byKey(_k('MGT-08.row.$_announcementId')), findsNothing);
    await _tap(tester, FeedbackKeys.of('TST-45', 'undo'));
    expect(_posts().posts[_announcementId]!.isDeleted, isFalse);
    expect(find.byKey(_k('MGT-08.row.$_announcementId')), findsOneWidget);
    await _dismissToast(tester);

    // MGT-01 "Duyuru yap" (W-97) → FED-03 duyuru türü seçili.
    await _tap(tester, _k('MGT-08.back'));
    expect(_location(tester), _manage);
    await _tap(tester, _k('MGT-01.quick.announce'));
    expect(_location(tester), '$_club/compose?type=announcement');
    expect(find.byType(ComposeView), findsOneWidget);
    final compose = _container(tester).read(
      composeViewModelProvider(
        clubId: kManageClubId,
        initialType: PostType.announcement,
      ),
    );
    expect(compose.type, PostType.announcement);
  });
}
