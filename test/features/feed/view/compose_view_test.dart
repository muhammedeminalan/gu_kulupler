// FED-03 · Yeni gönderi — içerik (gönderi / duyuru / anket alanları, TR + EN),
// durumlar (düzenlemede yükleniyor ve hata, yetkisiz, önizleme, hata bandı),
// aksiyon envanteri (9 anahtar), aksiyon sonuçları (kapat → DLG-25, görsel
// ekle → SHT-16 / TST-X5, yayınla → TST-14 → FED-02, menü → TST-13, kulüp
// değiştir → SHT-18, hakkı dolmuş anahtar → DLG-24), cihaz matrisi, açık +
// koyu golden.
// Referans: design/reference-shots/screens/FED-03__*.webp,
// design/prototype/app/screens-clubs.js:181–215.
//
// İki kip (FED-02 testleriyle aynı düzen):
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
import 'package:gu_kulupler/features/feed/provider/compose_state.dart';
import 'package:gu_kulupler/features/feed/provider/compose_view_model.dart';
import 'package:gu_kulupler/features/feed/view/compose_view.dart';
import 'package:gu_kulupler/features/feed/view/widget/compose_form.dart';
import 'package:gu_kulupler/features/feed/view/widget/poll_editor.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/managed_club_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/photo_source_sheet.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/mixin/unsaved_changes_mixin.dart';
import 'package:gu_kulupler/product/widget/post/announcement_quota_bar.dart';
import 'package:gu_kulupler/product/widget/post/post_card.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_announcement_counter_repository.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_post_repository.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';
import '../compose_test_support.dart';

final Key _close = GuKey.action('FED-03.close');
final Key _back = GuKey.action('FED-03.back');
final Key _retry = GuKey.action('FED-03.retry');
final Key _menu = GuKey.action('FED-03.menu');
final Key _publish = GuKey.action('FED-03.publish');
final Key _text = GuKey.action('FED-03.text');
final Key _title = GuKey.action('FED-03.title');
final Key _addImage = GuKey.action('FED-03.addImage');
final Key _pin = GuKey.action('FED-03.pin');
final Key _push = GuKey.action('FED-03.pushToggle');
final Key _preview = GuKey.action('FED-03.preview');
final Key _switchClub = GuKey.action('FED-03.switchClub');
final Key _typeAnnouncement = GuKey.action('FED-03.type.announcement');
final Key _typePoll = GuKey.action('FED-03.type.poll');

/// İçeriğin tamamı kurulsun diye uzun yüzey.
const Size _tall = Size(390, 1400);

const String _clubPath = '/clubs/$kComposeClubId';
const String _composePath = '$_clubPath/compose';

final ComposeViewModelProvider _provider = composeViewModelProvider(
  clubId: kComposeClubId,
);

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

FakePostRepository _posts() => GetIt.I<PostRepository>() as FakePostRepository;

/// Durum kipi: oturum + ViewModel durumu ezilir.
List<Override> _overrides({
  SessionState? session,
  ComposeState? state,
  ComposeViewModelProvider? of,
}) => [
  sessionViewModelProvider.overrideWithBuild(
    (ref, notifier) => session ?? composeSession(),
  ),
  (of ?? _provider).overrideWithBuild(
    (ref, notifier) => state ?? loadedComposeState(),
  ),
];

/// Ekranı boş formla (ya da [state] ile) çizer; [edit] verilirse düzenleme
/// kipinde.
Future<void> _pump(
  WidgetTester tester, {
  SessionState? session,
  ComposeState? state,
  PostModel? edit,
  Locale locale = const Locale('tr'),
  Size size = const Size(390, 844),
}) async {
  await tester.pumpApp(
    ComposeView(clubId: kComposeClubId, editPostId: edit?.id),
    locale: locale,
    size: size,
    overrides: _overrides(
      session: session,
      state: state,
      of: edit == null
          ? null
          : composeViewModelProvider(
              clubId: kComposeClubId,
              editPostId: edit.id,
            ),
    ),
  );
  await tester.pump();
}

/// Düzenleme kipinin dolu durumu ([post] yüklenmiş).
ComposeState _editState(PostModel post) => loadedComposeState().copyWith(
  editPost: post,
  type: post.type,
  title: post.title ?? '',
  text: post.text,
  images: [for (final image in post.images) ComposeImage.remote(image)],
  pollOptions: post.poll == null
      ? null
      : [for (final option in post.poll!.options) option.text],
  pinAfterPublish: post.pinned,
  pushEnabled: post.pushSent,
);

/// Akış kipi: ekranı gerçek ViewModel ve yer tutucu rotalarla açar.
Future<GoRouter> _pumpRoute(
  WidgetTester tester, {
  SessionState? session,
  String path = _composePath,
  void Function()? seed,
}) async {
  GoRouter? created;
  await tester.pumpAppRouter(
    size: _tall,
    routerOf: (_) => created ??= GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(path: '/start', builder: (_, _) => const _Stub('/start')),
        GoRoute(
          path: '/clubs/:clubId',
          builder: (_, state) => _Stub(state.uri.toString()),
          routes: [
            GoRoute(
              path: 'compose',
              builder: (_, state) => ComposeView(
                clubId: state.pathParameters['clubId']!,
                editPostId: state.uri.queryParameters['edit'],
              ),
            ),
            GoRoute(
              path: 'posts/:postId',
              builder: (_, state) => _Stub(state.uri.toString()),
            ),
          ],
        ),
      ],
    ),
    overrides: [
      sessionViewModelProvider.overrideWithBuild(
        (ref, notifier) => session ?? composeSession(),
      ),
    ],
  );
  final router = created!;
  addTearDown(router.dispose);
  seedCompose();
  seed?.call();
  router.go(path);
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

ComposeState _stateOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(ComposeView, skipOffstage: false)),
).read(_provider);

Future<void> _tapKey(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, Key key, String text) async {
  await tester.enterText(find.byKey(key), text);
  await tester.pumpAndSettle();
}

GuButton _publishButton(WidgetTester tester) =>
    tester.widget<GuButton>(find.byKey(_publish));

void main() {
  group('FED-03 · Yeni gönderi · içerik', () {
    for (final locale in const [Locale('tr'), Locale('en')]) {
      testWidgets('gönderi (${locale.languageCode}): kapat + başlık + "⋮" + '
          'kapalı "Yayınla"; tür dilimi, yazar satırı, metin, "Görseller '
          '(0/4)" + "Görsel ekle", "Sabitle"', (tester) async {
        await _pump(tester, locale: locale);
        final l10n = tester.l10n;
        final bar = tester.widget<GuAppBar>(find.byType(GuAppBar));
        expect(bar.title, l10n.composeTitle);
        expect(bar.closeIcon, isTrue);
        expect(bar.backSemanticLabel, l10n.a11yClose);
        expect(find.byKey(_close), findsOneWidget);
        final menu = tester.widget<GuIconButton>(find.byKey(_menu));
        expect(menu.icon, GuIcons.moreVertical);
        expect(menu.semanticLabel, l10n.a11yMore);
        final publish = _publishButton(tester);
        expect(publish.label, l10n.composePublish);
        expect(publish.size, GuButtonSize.sm);
        expect(publish.disabled, isTrue);
        expect(publish.loading, isFalse);

        final types = tester.widget<GuSegmented>(find.byType(GuSegmented));
        expect(types.value, PostType.post.name);
        expect(
          [for (final option in types.options) (option.label, option.icon)],
          [
            (l10n.feedTypePost, GuIcons.fileText),
            (l10n.feedTypeAnnouncement, GuIcons.megaphone),
            (l10n.feedTypePoll, GuIcons.chartColumn),
          ],
        );

        final avatar = tester.widget<GuAvatar>(find.byType(GuAvatar));
        expect(avatar.initials, 'BŞ');
        expect(avatar.size, 36);
        expect(find.text(kComposeUser.name), findsOneWidget);
        expect(find.text(kComposeClub.name), findsOneWidget);
        expect(find.byKey(_switchClub), findsNothing);

        final input = tester.widget<GuInput>(find.byType(GuInput));
        expect(input.label, l10n.composeText);
        expect(input.placeholder, l10n.feedComposePlaceholder);
        expect(input.multiline, isTrue);
        expect(input.rows, 5);
        expect(input.maxLength, Limits.postTextMax);
        expect(input.showCounter, isTrue);
        expect(find.byKey(_text), findsOneWidget);
        expect(find.byKey(_title), findsNothing);

        expect(
          find.text(
            l10n.composeImagesCount(
              l10n.composeImages,
              0,
              Limits.postImagesMax,
            ),
          ),
          findsOneWidget,
        );
        final add = tester.widget<GuButton>(find.byKey(_addImage));
        expect(add.label, l10n.composeAddImage);
        expect(add.icon, GuIcons.image);
        expect(add.variant, GuButtonVariant.tonal);
        expect(add.size, GuButtonSize.sm);
        expect(add.disabled, isFalse);
        final pin = tester.widget<GuSwitch>(find.byKey(_pin));
        expect(pin.value, isFalse);
        expect(pin.semanticLabel, l10n.composePin);
        expect(find.text(l10n.composePin), findsOneWidget);
        expect(find.byType(AnnouncementQuotaBar), findsNothing);
        expect(find.byType(PollEditor), findsNothing);
      });
    }

    testWidgets('duyuru: başlık alanı, bildirim anahtarı + yardım, "1/2" '
        'çubuğu, "Sabitle", bildirim önizlemesi; hak dolunca anahtar kapalı '
        've uyarı çubuğu', (tester) async {
      await _pump(
        tester,
        size: _tall,
        state: loadedComposeState().copyWith(
          type: PostType.announcement,
          title: 'Zirve tırmanışı',
          text: 'Cumartesi buluşuyoruz.',
          quotaUsed: 1,
        ),
      );
      final l10n = tester.l10n;
      final title = tester.widget<GuInput>(
        find.ancestor(of: find.byKey(_title), matching: find.byType(GuInput)),
      );
      expect(title.label, l10n.composeAnnouncementTitle);
      expect(title.maxLength, Limits.postTitleMax);
      expect(_publishButton(tester).disabled, isFalse);
      final push = tester.widget<GuSwitch>(find.byKey(_push));
      expect(push.value, isTrue);
      expect(push.disabled, isFalse);
      expect(find.text(l10n.composePushHelp), findsOneWidget);
      final quota = tester.widget<AnnouncementQuotaBar>(
        find.byType(AnnouncementQuotaBar),
      );
      expect((quota.used, quota.limit, quota.card), (1, 2, false));
      expect(find.text('1/2'), findsOneWidget);
      expect(
        tester.widget<GuProgress>(find.byType(GuProgress)).kind,
        GuProgressKind.brand,
      );
      expect(find.byKey(_pin), findsOneWidget);
      expect(find.text(l10n.composeNotifPreview), findsOneWidget);
      expect(find.text(l10n.timeJustNow), findsOneWidget);
      // Başlık ve metin: alan + bildirim önizlemesi.
      expect(find.text('Zirve tırmanışı'), findsNWidgets(2));
      expect(find.text('Cumartesi buluşuyoruz.'), findsNWidgets(2));
      expect(find.byKey(_addImage), findsNothing);

      await _pump(
        tester,
        size: _tall,
        state: loadedComposeState().copyWith(
          type: PostType.announcement,
          quotaUsed: 2,
        ),
      );
      final blocked = tester.widget<GuSwitch>(find.byKey(_push));
      expect(blocked.value, isFalse);
      expect(blocked.disabled, isTrue);
      expect(find.text(l10n.composeLimitReached), findsOneWidget);
      expect(find.text('2/2'), findsOneWidget);
      expect(
        tester.widget<GuProgress>(find.byType(GuProgress)).kind,
        GuProgressKind.warning,
      );
      // Boş alanlar önizlemede etiketleriyle çizilir.
      expect(find.text(l10n.composeAnnouncementTitle), findsNWidgets(2));
    });

    testWidgets('anket: soru (2 satır), seçenek alanları, "Seçenek ekle", '
        'süre dilimi (1 / 3 / 7 gün), sonuç anahtarı; hata satırı', (
      tester,
    ) async {
      await _pump(
        tester,
        size: _tall,
        state: loadedComposeState().copyWith(
          type: PostType.poll,
          pollOptions: const ['Cumartesi', 'Pazar', ''],
          errors: const {ComposeField.options: FormFieldError.invalidFormat},
        ),
      );
      final l10n = tester.l10n;
      final question = tester.widget<GuInput>(
        find.ancestor(of: find.byKey(_text), matching: find.byType(GuInput)),
      );
      expect(question.label, l10n.composeQuestion);
      expect(question.rows, 2);
      expect(find.text(l10n.composeOptions), findsOneWidget);
      for (var index = 0; index < 3; index++) {
        expect(
          find.byKey(GuKey.action('FED-03.option.$index')),
          findsOneWidget,
        );
        expect(
          find.byKey(GuKey.action('FED-03.removeOption.$index')),
          findsOneWidget,
        );
      }
      expect(find.text('Cumartesi'), findsOneWidget);
      expect(find.text(l10n.composeOptionN(3)), findsOneWidget);
      expect(find.text(l10n.composeErrDupOptions), findsOneWidget);
      expect(find.byKey(GuKey.action('FED-03.addOption')), findsOneWidget);
      final duration = tester.widget<GuSegmented>(
        find.descendant(
          of: find.byType(PollEditor),
          matching: find.byType(GuSegmented),
        ),
      );
      expect(duration.value, PollDuration.d3.name);
      expect(
        [for (final option in duration.options) option.label],
        [
          l10n.timeDays(1),
          l10n.timeDays(3),
          l10n.timeDays(7),
        ],
      );
      for (final days in Limits.pollDurationsDays) {
        expect(
          find.byKey(GuKey.action('FED-03.duration.$days')),
          findsOneWidget,
        );
      }
      expect(
        tester
            .widget<GuSwitch>(
              find.byKey(GuKey.action('FED-03.showAfterVote')),
            )
            .value,
        isTrue,
      );
      expect(find.byKey(_pin), findsNothing);
    });

    testWidgets('görseller: küçük önizleme + "Kaldır"; dört görselde "Görsel '
        'ekle" kapalı', (tester) async {
      await _pump(
        tester,
        state: loadedComposeState().copyWith(
          text: 'Zirve',
          images: [
            for (final image in kEditPost.images) ComposeImage.remote(image),
            ComposeImage.remote(kEditPost.images.first),
          ],
        ),
      );
      final l10n = tester.l10n;
      expect(
        find.text(l10n.composeImagesCount(l10n.composeImages, 4, 4)),
        findsOneWidget,
      );
      for (var index = 0; index < 4; index++) {
        final remove = tester.widget<GuIconButton>(
          find.byKey(GuKey.action('FED-03.removeImage.$index')),
        );
        expect(remove.icon, GuIcons.x);
        expect(remove.onCover, isTrue);
        expect(remove.semanticLabel, l10n.commonRemove);
      }
      expect(tester.widget<GuButton>(find.byKey(_addImage)).disabled, isTrue);
    });
  });

  group('FED-03 · Yeni gönderi · durumlar', () {
    testWidgets('düzenleme: "Gönderiyi düzenle" + "Kaydet"; tür dilimi '
        'dokunulmaz; ankette soru ve seçenekler salt okunur, süre ve ekle / '
        'kaldır yok', (tester) async {
      await _pump(
        tester,
        edit: kEditPoll,
        state: _editState(kEditPoll),
        size: _tall,
      );
      final l10n = tester.l10n;
      expect(
        tester.widget<GuAppBar>(find.byType(GuAppBar)).title,
        l10n.composeEditTitle,
      );
      expect(_publishButton(tester).label, l10n.commonSave);
      expect(
        find.ancestor(
          of: find.byKey(_typePoll),
          matching: find.byWidgetPredicate(
            (widget) => widget is IgnorePointer && widget.ignoring,
          ),
        ),
        findsWidgets,
      );
      final inputs = tester.widgetList<GuInput>(find.byType(GuInput));
      expect(inputs.every((input) => input.readOnly), isTrue);
      expect(inputs, hasLength(1 + kEditPoll.poll!.options.length));
      expect(find.byKey(GuKey.action('FED-03.addOption')), findsNothing);
      expect(find.byKey(GuKey.action('FED-03.removeOption.0')), findsNothing);
      expect(find.byKey(GuKey.action('FED-03.duration.3')), findsNothing);
      expect(
        tester
            .widget<GuSwitch>(
              find.byKey(GuKey.action('FED-03.showAfterVote')),
            )
            .disabled,
        isTrue,
      );
    });

    testWidgets('düzenleme · duyuru: bildirim anahtarı, hak çubuğu ve '
        'bildirim önizlemesi çizilmez', (tester) async {
      await _pump(
        tester,
        edit: kEditAnnouncement,
        state: _editState(kEditAnnouncement),
        size: _tall,
      );
      expect(find.byKey(_title), findsOneWidget);
      expect(find.byKey(_push), findsNothing);
      expect(find.byType(AnnouncementQuotaBar), findsNothing);
      expect(find.text(tester.l10n.composeNotifPreview), findsNothing);
      expect(tester.widget<GuSwitch>(find.byKey(_pin)).value, isTrue);
    });

    testWidgets('düzenleme · yükleniyor: iskelet; "⋮" ve "Kaydet" yok', (
      tester,
    ) async {
      await _pump(
        tester,
        edit: kEditPost,
        state: const ComposeState(isLoadingEdit: true),
      );
      expect(find.byType(GuSkeletonList), findsOneWidget);
      expect(find.byType(ComposeForm), findsNothing);
      expect(find.byKey(_menu), findsNothing);
      expect(find.byKey(_publish), findsNothing);
      expect(find.byKey(_close), findsOneWidget);
    });

    testWidgets('düzenleme · hata: "Bir şeyler ters gitti" + "Yeniden dene"', (
      tester,
    ) async {
      await _pump(
        tester,
        edit: kEditPost,
        state: const ComposeState(isError: true),
      );
      final l10n = tester.l10n;
      final error = tester.widget<GuErrorState>(find.byType(GuErrorState));
      expect(error.title, l10n.sysErrorTitle);
      expect(error.retryLabel, l10n.commonRetry);
      expect(find.byKey(_retry), findsOneWidget);
      expect(find.byType(ComposeForm), findsNothing);
      expect(find.byKey(_publish), findsNothing);
    });

    testWidgets('yönetici olmayan (üye, danışman, kulüpte yönetici olmayan '
        'süper admin): kilit çizimi + "Gönderi oluşturma yetkin yok."; form '
        'yok', (tester) async {
      for (final session in [
        composeSession(role: ClubRole.member),
        composeSession(role: ClubRole.advisor),
        // Rules: gönderiyi yalnızca kulübün yöneticisi yazar.
        composeSession(role: ClubRole.member).copyWith(isSuperAdmin: true),
      ]) {
        await _pump(tester, session: session);
        final empty = tester.widget<GuEmptyState>(find.byType(GuEmptyState));
        expect(empty.illustration, GuIllustrations.locked);
        expect(empty.description, tester.l10n.composeNoAccess);
        expect(find.byKey(_back), findsOneWidget);
        expect(find.byType(ComposeForm), findsNothing);
        expect(find.byKey(_publish), findsNothing);
      }
    });

    testWidgets('kulübün yöneticisi olan süper admin formu görür', (
      tester,
    ) async {
      await _pump(
        tester,
        session: composeSession(role: ClubRole.board).copyWith(
          isSuperAdmin: true,
        ),
      );
      expect(find.byType(ComposeForm), findsOneWidget);
      expect(find.byKey(_publish), findsOneWidget);
    });

    testWidgets('önizleme: bilgi bandı ("Düzenlemeye dön") + eylemsiz gönderi '
        'kartı; bant önizlemeyi kapatır', (tester) async {
      await _pump(
        tester,
        state: loadedComposeState().copyWith(text: 'Zirve tırmanışı'),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ComposeView)),
      );
      container.read(_provider.notifier).togglePreview();
      await tester.pumpAndSettle();
      final l10n = tester.l10n;
      final banner = tester.widget<GuBanner>(find.byType(GuBanner));
      expect(banner.text, l10n.composePreviewNote);
      expect(banner.actionLabel, l10n.composeEdit);
      expect(banner.icon, GuIcons.eye);
      final card = tester.widget<PostCard>(find.byType(PostCard));
      expect(card.post.text, 'Zirve tırmanışı');
      expect(card.author, kComposeUser);
      expect(card.role, ClubRole.president);
      expect(card.club, kComposeClub);
      expect(card.hideActions, isTrue);
      expect(find.byType(ComposeForm), findsNothing);

      await _tapKey(tester, _preview);
      expect(find.byType(PostCard), findsNothing);
      expect(find.byType(ComposeForm), findsOneWidget);
    });

    testWidgets('gönderim: "Yayınla" döner; toast\'sız hata form üstünde '
        'bant olur', (tester) async {
      await _pump(
        tester,
        state: loadedComposeState().copyWith(
          text: 'Zirve',
          isSubmitting: true,
        ),
      );
      expect(_publishButton(tester).loading, isTrue);

      await _pump(
        tester,
        state: loadedComposeState().copyWith(
          text: 'Zirve',
          isSubmitError: true,
        ),
      );
      final banner = tester.widget<GuBanner>(find.byType(GuBanner));
      expect(banner.kind, GuBannerKind.danger);
      expect(banner.text, tester.l10n.sysErrorTitle);
    });
  });

  group('FED-03 · Yeni gönderi · aksiyon envanteri', () {
    testWidgets('yönetici bakışı: envanterdeki 9 anahtar birebir', (
      tester,
    ) async {
      await _pump(tester);
      expectActionInventory(tester, 'FED-03', role: 'manager');
    });
  });

  group('FED-03 · Yeni gönderi · aksiyonlar', () {
    testWidgets('kapat: değişiklik yokken doğrudan CLB-03; kaydedilmemiş '
        'değişiklik varken DLG-25 — "devam" ekranda tutar, "Kaydetmeden '
        'çık" çıkar', (tester) async {
      var router = await _pumpRoute(tester);
      await _tapKey(tester, _close);
      expect(_location(router), _clubPath);
      expect(_feedback().dialogs, isEmpty);

      router = await _pumpRoute(tester);
      await _type(tester, _text, 'Zirve tırmanışı');
      expect(_stateOf(tester).isDirty, isTrue);
      await _tapKey(tester, _close);
      expect(_feedback().dialogs, [DialogId.dlg25]);
      expect(_location(router), _composePath);

      // Sistem geri tuşu da aynı soruyu sorar.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_feedback().dialogs, [DialogId.dlg25, DialogId.dlg25]);
      expect(_location(router), _composePath);

      _feedback().nextDialogResult = UnsavedChangesResult.discard;
      await _tapKey(tester, _close);
      expect(_location(router), _clubPath);
      expect(_feedback().toasts, isEmpty);
    });

    testWidgets('DLG-25 "Kaydet": taslak cihaza yazılır (TST-13) ve çıkılır; '
        'ekran taslakla yeniden açılır', (tester) async {
      final router = await _pumpRoute(tester);
      await _type(tester, _text, 'Zirve tırmanışı');
      _feedback().nextDialogResult = UnsavedChangesResult.save;
      await _tapKey(tester, _close);
      expect(_feedback().toasts, [ToastId.tst13]);
      expect(_location(router), _clubPath);
      expect(
        GetIt.I<AppPreferencesStore>().composeDraft(kComposeClubId),
        isNotNull,
      );

      router.go(_composePath);
      await tester.pumpAndSettle();
      expect(find.text('Zirve tırmanışı'), findsOneWidget);
      expect(_stateOf(tester).hasDraft, isTrue);
      expect(_stateOf(tester).isDirty, isFalse);
    });

    testWidgets('"Görsel ekle" → SHT-16 → galeri → küçük önizleme; dört '
        'görselden sonra dokunuş TST-X5 verir (görsel ≤ 4)', (tester) async {
      await _pumpRoute(tester);
      for (var count = 1; count <= Limits.postImagesMax; count++) {
        _feedback().nextSheetResult = PhotoSourceChoice.gallery;
        await _tapKey(tester, _addImage);
        expect(_stateOf(tester).images, hasLength(count));
        expect(
          find.byKey(GuKey.action('FED-03.removeImage.${count - 1}')),
          findsOneWidget,
        );
      }
      expect(_feedback().sheets, List.filled(4, SheetId.sht16));
      expect(_feedback().toasts, isEmpty);

      await _tapKey(tester, _addImage);
      expect(_feedback().toasts, [ToastId.tstX5]);
      expect(_feedback().sheets, hasLength(4));
      expect(_stateOf(tester).images, hasLength(4));

      await _tapKey(tester, GuKey.action('FED-03.removeImage.0'));
      expect(_stateOf(tester).images, hasLength(3));
    });

    testWidgets('kapalı "Yayınla" eksik alanı gösterir; dolu formda yayınlar '
        '→ CLB-03 "Gönderiler" + TST-14; "Görüntüle" → FED-02', (
      tester,
    ) async {
      final router = await _pumpRoute(tester);
      _posts().newPostIdQueue.add('p_new');
      await _tapKey(tester, _publish);
      expect(find.text(tester.l10n.authErrRequired), findsOneWidget);
      expect(_posts().callsTo('create'), isEmpty);

      await _type(tester, _text, 'Zirve tırmanışı');
      expect(find.text(tester.l10n.authErrRequired), findsNothing);
      await _tapKey(tester, _pin);
      await _tapKey(tester, _publish);
      expect(_posts().posts['p_new']!.text, 'Zirve tırmanışı');
      expect(_posts().posts['p_new']!.pinned, isTrue);
      expect(_location(router), '$_clubPath?tab=posts');
      expect(_feedback().toasts, [ToastId.tst14]);
      expect(_feedback().dialogs, isEmpty);

      _feedback().tapToastAction();
      await tester.pumpAndSettle();
      expect(_location(router), '$_clubPath/posts/p_new');
    });

    testWidgets('duyuru: hak doluyken bildirim anahtarına dokunuş ve '
        'bildirimli yayın DLG-24 açar; "Bildirimsiz yayınla" yayınlar', (
      tester,
    ) async {
      final router = await _pumpRoute(
        tester,
        seed: () {
          final counters =
              GetIt.I<AnnouncementCounterRepository>()
                  as FakeAnnouncementCounterRepository;
          counters.counts[counters.keyOf(kComposeClubId)] =
              Limits.announcementDailyLimit;
        },
      );
      await _tapKey(tester, _typeAnnouncement);
      await _type(tester, _title, 'Zirve');
      await _type(tester, _text, 'Cumartesi buluşuyoruz.');
      expect(find.text('2/2'), findsOneWidget);
      await _tapKey(tester, _push);
      expect(_feedback().dialogs, [DialogId.dlg24]);
      expect(_stateOf(tester).pushEnabled, isTrue);

      await _tapKey(tester, _publish);
      expect(_feedback().dialogs, [DialogId.dlg24, DialogId.dlg24]);
      expect(_posts().callsTo('create'), isEmpty);
      expect(_location(router), _composePath);

      _feedback().nextDialogResult = true;
      await _tapKey(tester, _publish);
      final post = _posts().posts.values.last;
      expect(post.isAnnouncement, isTrue);
      expect(post.pushSent, isFalse);
      expect(_location(router), '$_clubPath?tab=posts');
    });

    testWidgets('"⋮" menüsü: "Taslak kaydet" → TST-13, "Önizle", "Temizle"', (
      tester,
    ) async {
      await _pumpRoute(tester);
      await _type(tester, _text, 'Zirve tırmanışı');
      await _tapKey(tester, _menu);
      final l10n = tester.l10n;
      final items = _feedback().lastMenuItems.cast<GuPopMenuItem>();
      expect(
        [for (final item in items) (item.key, item.label, item.icon)],
        [
          (
            GuKey.action('FED-03.saveDraft'),
            l10n.composeSaveDraft,
            GuIcons.fileText,
          ),
          (GuKey.action('FED-03.preview'), l10n.composePreview, GuIcons.eye),
          (GuKey.action('FED-03.clear'), l10n.composeClear, GuIcons.trash2),
        ],
      );
      expect(items.last.danger, isTrue);

      items[0].onTap!();
      await tester.pumpAndSettle();
      expect(_feedback().toasts, [ToastId.tst13]);
      expect(_stateOf(tester).isDirty, isFalse);

      items[1].onTap!();
      await tester.pumpAndSettle();
      expect(find.byType(PostCard), findsOneWidget);
      items[1].onTap!();
      await tester.pumpAndSettle();

      items[2].onTap!();
      await tester.pumpAndSettle();
      expect(_stateOf(tester).text, isEmpty);
      expect(find.text('Zirve tırmanışı'), findsNothing);
    });

    testWidgets('birden çok kulüp yöneten: kulüp adı → SHT-18 → seçilen '
        'kulübün yazı ekranı', (tester) async {
      final router = await _pumpRoute(
        tester,
        session: composeSession(alsoManages: 'c01'),
      );
      expect(find.byKey(_switchClub), findsOneWidget);
      await _tapKey(tester, _switchClub);
      expect(_feedback().sheets, [SheetId.sht18]);
      // Seçim `onSelect` ile gelir (sheet'in MGT-01 varsayılanı bastırılır).
      final sheet =
          _feedback().lastSheetBuilder!(
                tester.element(find.byType(ComposeView)),
              )
              as ManagedClubPickerSheet;
      sheet.onSelect!('c01');
      await tester.pumpAndSettle();
      expect(_location(router), '/clubs/c01/compose');
    });

    testWidgets('düzenleme (`?edit=`): gönderi yüklenir, "Kaydet" değişen '
        'metni yazar → CLB-03 + TST-14', (tester) async {
      final router = await _pumpRoute(
        tester,
        path: '$_composePath?edit=${kEditAnnouncement.id}',
      );
      expect(find.text(kEditAnnouncement.title!), findsOneWidget);
      await _type(tester, _title, 'Yeni başlık');
      await _tapKey(tester, _publish);
      expect(_posts().posts[kEditAnnouncement.id]!.title, 'Yeni başlık');
      expect(_feedback().toasts, [ToastId.tst14]);
      expect(_location(router), startsWith(_clubPath));
      expect(_location(router), isNot(contains('compose')));
    });
  });

  group('FED-03 · Yeni gönderi · cihaz matrisi', () {
    Widget view(BuildContext context) =>
        const ComposeView(clubId: kComposeClubId);

    testWidgets('gönderi (boş form; klavye + güvenli alan)', (tester) async {
      await DeviceMatrix.run(
        tester,
        view,
        overrides: _overrides(),
        keyboard: true,
        safeAreas: true,
      );
    });

    testWidgets('duyuru (hak dolu), anket (hata), görselli gönderi, yetkisiz', (
      tester,
    ) async {
      for (final state in [
        loadedComposeState().copyWith(
          type: PostType.announcement,
          title: 'Zirve tırmanışı için son çağrı',
          text: 'Cumartesi 07.00’de kampüs kapısında buluşuyoruz.',
          quotaUsed: 2,
          errors: const {ComposeField.title: FormFieldError.required},
        ),
        loadedComposeState().copyWith(
          type: PostType.poll,
          pollOptions: const ['Cumartesi', 'Pazar', '', ''],
          errors: const {ComposeField.options: FormFieldError.tooShort},
        ),
        loadedComposeState().copyWith(
          text: 'Zirve',
          images: [
            for (final image in kEditPost.images) ComposeImage.remote(image),
          ],
          isSubmitError: true,
        ),
      ]) {
        await DeviceMatrix.run(
          tester,
          view,
          overrides: _overrides(state: state),
        );
      }
      await DeviceMatrix.run(
        tester,
        view,
        overrides: _overrides(session: composeSession(role: ClubRole.member)),
      );
    });
  });

  group('FED-03 · Yeni gönderi · golden', () {
    testWidgets('varsayılan (boş gönderi formu) açık + koyu', (tester) async {
      await goldenForThemes(
        tester,
        'FED-03',
        const ComposeView(clubId: kComposeClubId),
        overrides: _overrides(),
      );
    });
  });
}
