// T-20 · PostCard (widget-catalog P12) + gönderi kartları galerisi — tür
// (gönderi / duyuru / anket / görselli), sabit şeridi, yazar satırı (rol
// rozeti, kulüp bağlamı, düzenlendi, silinmiş yazar), metin kırpma + "Devamı",
// eylem satırı (sayaçlar, beğenildi / kaydedildi, kalp `pop`), gönderi detayı
// kipi (`expanded`), önizleme (`hideActions`), çağıranın verdiği anahtarlar,
// erişilebilirlik, cihaz matrisi ve galeri golden'ı (açık + koyu). Kaynak:
// prototip `cards.js:96–127`; referans `screens/FED-01__*.webp`,
// `FED-02__*.webp`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/widget/post/image_grid.dart';
import 'package:gu_kulupler/product/widget/post/poll_block.dart';
import 'package:gu_kulupler/product/widget/post/post_card.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/test_l10n.dart';
import 'post_test_support.dart';

PostCardKeys _keys(PostModel post, {String screen = 'FED-01'}) => PostCardKeys(
  author: GuKey.action('$screen.author.${post.id}'),
  menu: GuKey.action('$screen.menu.${post.id}'),
  post: GuKey.action('$screen.post.${post.id}'),
  more: GuKey.action('$screen.more.${post.id}'),
  like: GuKey.action('$screen.like.${post.id}'),
  comment: GuKey.action('$screen.comment.${post.id}'),
  share: GuKey.action('$screen.share.${post.id}'),
  save: GuKey.action('$screen.save.${post.id}'),
  image: (index) => GuKey.action('$screen.image.${post.id}.$index'),
  vote: (optionId) => GuKey.action('$screen.vote.${post.id}.$optionId'),
);

Key _key(PostModel post, String action) =>
    GuKey.action('FED-01.$action.${post.id}');

/// 5 satırdan uzun süren, 280 karakteri aşan metin.
final String _longText = List.filled(
  12,
  'Hackathon ekipleri bu hafta kuruluyor, mentor desteği olacak.',
).join(' ');

/// Çağrılan geri çağrıların adları.
class _Calls {
  final List<String> log = [];

  PostCard card(
    PostModel post, {
    bool expanded = false,
    bool liked = false,
    bool saved = false,
  }) => PostCard(
    post: post,
    author: authorOf(post),
    role: ClubRole.president,
    club: kClub,
    liked: liked,
    saved: saved,
    expanded: expanded,
    pollResults: kPollResults,
    keys: _keys(post),
    onOpen: () => log.add('open'),
    onAuthor: () => log.add('author'),
    onMenu: () => log.add('menu'),
    onLike: () => log.add('like'),
    onComment: () => log.add('comment'),
    onShare: () => log.add('share'),
    onSave: () => log.add('save'),
    onVote: (id) => log.add('vote.$id'),
    onImage: (index) => log.add('image.$index'),
  );
}

bool _hasStrokeIcon(WidgetTester tester, Key button, GuIcons icon) => tester
    .widgetList<GuIcon>(
      find.descendant(of: find.byKey(button), matching: find.byType(GuIcon)),
    )
    .any((glyph) => glyph.icon == icon);

/// Galeri: duyuru (sabit, beğenilmiş + kayıtlı), görselli gönderi, anket (oy
/// verilmiş).
Widget _gallery(BuildContext context) => Scaffold(
  backgroundColor: context.gu.colors.bgCanvas,
  body: SafeArea(
    child: SingleChildScrollView(
      padding: GuInsets.all16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: GuSpacing.s12,
        children: [
          PostCard(
            post: kAnnouncement,
            author: authorOf(kAnnouncement),
            role: ClubRole.president,
            club: kClub,
            liked: true,
            saved: true,
            onAuthor: () {},
            onMenu: () {},
            onLike: () {},
            onComment: () {},
            onShare: () {},
            onSave: () {},
          ),
          PostCard(
            post: kImagePost,
            author: authorOf(kImagePost),
            role: ClubRole.board,
            club: kClub,
            onAuthor: () {},
            onMenu: () {},
            onLike: () {},
            onComment: () {},
            onShare: () {},
            onSave: () {},
            onImage: (_) {},
          ),
          PostCard(
            post: kPollPost,
            author: authorOf(kPollPost),
            role: ClubRole.board,
            club: kClub,
            myOptionId: 'o4',
            pollResults: kPollResults,
            onAuthor: () {},
            onMenu: () {},
            onLike: () {},
            onComment: () {},
            onShare: () {},
            onSave: () {},
            onVote: (_) {},
          ),
          PostCard(
            post: kImagePost.copyWith(text: _longText, images: const []),
            showClub: true,
            club: kClub,
            hideActions: true,
            onMenu: () {},
          ),
        ],
      ),
    ),
  ),
);

void main() {
  group('T-20 · PostCard · içerik', () {
    testWidgets('duyuru: sabit şeridi, yazar + rol rozeti + göreli zaman, '
        '"Duyuru" rozeti + "Bildirim gönderildi", başlık, metin, sayaçlar — '
        'TR ve EN', (tester) async {
      for (final locale in [kTr, kEn]) {
        final calls = _Calls();
        await pumpPost(tester, calls.card(kAnnouncement), locale: locale);
        final l10n = tester.l10nFor(locale);
        final gu = tester.element(find.byType(PostCard)).gu;
        final author = authorOf(kAnnouncement);

        expect(find.text(l10n.feedPinned), findsOneWidget);
        expect(find.text(author.name), findsOneWidget);
        final avatar = tester.widget<GuAvatar>(find.byType(GuAvatar));
        expect(avatar.size, GuSizes.postAvatar);
        expect(avatar.seed, author.avatarSeed);
        expect(
          tester.widget<GuRoleBadge>(find.byType(GuRoleBadge)).kind,
          GuRoleBadgeKind.president,
        );
        // `p01` 26 Eyl 19:00, saat 7 Eki 21:00 → 11 gün → 1 hafta.
        expect(find.text(l10n.timeWeeksAgo(1)), findsOneWidget);

        final badge = tester.widget<GuBadge>(
          find.widgetWithText(GuBadge, l10n.feedTypeAnnouncement),
        );
        expect(badge.kind, GuBadgeKind.president);
        expect(badge.icon, GuIcons.megaphone);
        expect(find.text(l10n.feedPushSent), findsOneWidget);
        expect(
          tester.widget<Text>(find.text(kAnnouncement.title!)).style,
          gu.text.titleS,
        );
        final body = tester.widget<Text>(find.text(kAnnouncement.text));
        expect(body.style, gu.text.bodyM);
        expect(body.maxLines, isNull);
        expect(find.text(l10n.commonReadMore), findsNothing);
        expect(find.byType(ImageGrid), findsNothing);
        expect(find.byType(PollBlock), findsNothing);

        // Sayaçlar: 46 beğeni, 3 yorum.
        expect(find.text('${kAnnouncement.likeCount}'), findsOneWidget);
        final comment = tester.widget<GuIconButton>(
          find.byKey(_key(kAnnouncement, 'comment')),
        );
        expect(comment.countLabel, '${kAnnouncement.commentCount}');
        expect(comment.iconSize, GuSizes.postActionIcon);
        expect(comment.icon, GuIcons.messageCircle);
        expect(
          tester
              .widget<GuIconButton>(find.byKey(_key(kAnnouncement, 'menu')))
              .icon,
          GuIcons.moreHorizontal,
        );
      }
    });

    testWidgets('yerleşim (390 dp): sabit şeridi 10, yazar satırı 12 / 16, '
        '"…" sağdan 8, gövde 10 / 16, eylem satırı yatay 8 + alt 8; gövde '
        'öğeleri arasında boşluk yok (K-42)', (tester) async {
      await pumpPost(tester, _Calls().card(kAnnouncement));
      final l10n = tester.l10n;
      // Kart 1 px kenarlıklıdır.
      final card = tester.getRect(find.byType(PostCard)).deflate(1);
      final pinned = tester.getRect(find.text(l10n.feedPinned));
      final avatar = tester.getRect(find.byType(GuAvatar));
      final menu = tester.getRect(find.byKey(_key(kAnnouncement, 'menu')));
      final badge = tester.getRect(
        find.widgetWithText(GuBadge, l10n.feedTypeAnnouncement),
      );
      final title = tester.getRect(find.text(kAnnouncement.title!));
      final body = tester.getRect(find.text(kAnnouncement.text));
      final like = tester.getRect(find.byKey(_key(kAnnouncement, 'like')));
      final save = tester.getRect(find.byKey(_key(kAnnouncement, 'save')));

      expect(pinned.top - card.top, 10);
      expect(avatar.top - pinned.bottom, GuSpacing.s12);
      expect(avatar.left - card.left, GuSpacing.s16);
      expect(card.right - menu.right, GuSpacing.s8);
      expect(menu.top, avatar.top);
      expect(
        tester.getRect(find.text(authorOf(kAnnouncement).name)).left -
            avatar.right,
        10,
      );
      // "…" 48 yüksekliğindedir: yazar satırı 48, gövde 10 aşağıda başlar.
      expect(badge.top - menu.bottom, 10);
      expect(badge.left - card.left, GuSpacing.s16);
      expect(title.top, badge.bottom);
      expect(body.top, title.bottom);
      expect(like.top, body.bottom);
      expect(like.left - card.left, GuSpacing.s8);
      expect(like.height, GuSizes.iconButton);
      expect(card.right - save.right, GuSpacing.s8);
      expect(save.size, const Size.square(GuSizes.iconButton));
      expect(card.bottom - like.bottom, GuSpacing.s8);
    });

    testWidgets('anket: "Anket" rozeti + PollBlock (oy, sonuçlar, anahtar); '
        'görselli: ImageGrid (kulüp, anahtar); sıradan gönderide tür rozeti '
        'yok, 0 sayaç yazılmaz', (tester) async {
      final calls = _Calls();
      await pumpPost(tester, calls.card(kPollPost));
      final l10n = tester.l10n;
      final badge = tester.widget<GuBadge>(
        find.widgetWithText(GuBadge, l10n.feedTypePoll),
      );
      expect((badge.kind, badge.icon), (GuBadgeKind.info, GuIcons.chartColumn));
      final poll = tester.widget<PollBlock>(find.byType(PollBlock));
      expect(poll.poll, kPoll);
      expect(poll.results, kPollResults);
      await tester.tap(find.byKey(GuKey.action('FED-01.vote.p04.o2')));
      expect(calls.log, ['vote.o2']);
      // `p04` yorumsuz: yorum sayacı boş.
      expect(
        tester
            .widget<GuIconButton>(find.byKey(_key(kPollPost, 'comment')))
            .countLabel,
        isEmpty,
      );

      await pumpPost(tester, calls.card(kImagePost));
      // Tür rozeti yok (rol rozeti de bir `GuBadge`'dir).
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is GuBadge &&
              (w.icon == GuIcons.megaphone || w.icon == GuIcons.chartColumn),
        ),
        findsNothing,
      );
      final grid = tester.widget<ImageGrid>(find.byType(ImageGrid));
      expect(grid.images, kImagePost.images);
      expect(grid.club, kClub);
      await tester.tap(find.byKey(GuKey.action('FED-01.image.p02.1')));
      expect(calls.log.last, 'image.1');
    });

    testWidgets('kulüp bağlamı + düzenlendi alt satırda; silinmiş yazar: ad, '
        '`?` avatar, rozet yok; sunucu zamanı gelmemiş gönderi "Az önce"', (
      tester,
    ) async {
      final edited = kAnnouncement.copyWith(
        editedAt: kAnnouncement.createdAt!.add(const Duration(hours: 1)),
      );
      await pumpPost(
        tester,
        PostCard(
          post: edited,
          author: authorOf(edited),
          club: kClub,
          showClub: true,
        ),
      );
      final l10n = tester.l10n;
      expect(
        find.text(
          '${kClub.name} · ${l10n.timeWeeksAgo(1)} · ${l10n.feedEdited}',
        ),
        findsOneWidget,
      );

      await pumpPost(
        tester,
        PostCard(
          post: PostModel(
            id: 'yeni',
            clubId: kClub.id,
            authorId: 'silinmis',
            text: 'Merhaba',
          ),
          role: ClubRole.board,
          club: kClub,
        ),
      );
      expect(find.text(l10n.commonDeletedUser), findsOneWidget);
      final avatar = tester.widget<GuAvatar>(find.byType(GuAvatar));
      expect((avatar.initials, avatar.seed), ('?', '?'));
      expect(find.byType(GuRoleBadge), findsNothing);
      expect(find.text(l10n.timeJustNow), findsOneWidget);
    });

    testWidgets('uzun metin (> 280 karakter): 5 satıra kırpılır + "Devamı"; '
        '"Devamı" metni açar ve gönderiyi açmaz; `expanded` kırpmaz', (
      tester,
    ) async {
      final calls = _Calls();
      final long = kAnnouncement.copyWith(text: _longText);
      expect(_longText.length, greaterThan(PostCard.longTextThreshold));
      await pumpPost(tester, calls.card(long));
      final l10n = tester.l10n;
      final gu = tester.element(find.byType(PostCard)).gu;

      var body = tester.widget<Text>(find.text(_longText));
      expect(body.maxLines, PostCard.collapsedLines);
      expect(body.overflow, TextOverflow.ellipsis);
      final more = tester.widget<Text>(find.text(l10n.commonReadMore));
      expect(
        more.style,
        gu.text.labelL.copyWith(color: gu.colors.brandPrimaryText),
      );
      expect(
        tester.getRect(find.text(l10n.commonReadMore)).top -
            tester.getRect(find.text(_longText)).bottom,
        GuSpacing.s4,
      );
      final collapsed = tester.getSize(find.byType(PostCard)).height;

      await tester.tap(find.byKey(_key(long, 'more')));
      await tester.pump();
      expect(calls.log, isEmpty);
      body = tester.widget<Text>(find.text(_longText));
      expect(body.maxLines, isNull);
      expect(find.text(l10n.commonReadMore), findsNothing);
      expect(
        tester.getSize(find.byType(PostCard)).height,
        greaterThan(collapsed),
      );

      // Tam 280 karakter kırpılmaz.
      final edge = 'a' * PostCard.longTextThreshold;
      await pumpPost(tester, calls.card(kAnnouncement.copyWith(text: edge)));
      expect(find.text(l10n.commonReadMore), findsNothing);

      await pumpPost(tester, calls.card(long, expanded: true));
      expect(tester.widget<Text>(find.text(_longText)).maxLines, isNull);
      expect(find.text(l10n.commonReadMore), findsNothing);
    });
    testWidgets('satır başka gönderiyle yeniden kullanılınca açılmış metin '
        'yeniden kırpılır', (tester) async {
      final calls = _Calls();
      final first = kAnnouncement.copyWith(text: _longText);
      final second = kImagePost.copyWith(text: _longText, images: const []);
      final post = ValueNotifier<PostModel>(first);
      addTearDown(post.dispose);
      await pumpPost(
        tester,
        ValueListenableBuilder<PostModel>(
          valueListenable: post,
          builder: (_, value, _) => calls.card(value),
        ),
      );
      final l10n = tester.l10n;

      await tester.tap(find.byKey(_key(first, 'more')));
      await tester.pump();
      expect(find.text(l10n.commonReadMore), findsNothing);

      post.value = second;
      await tester.pump();
      expect(find.text(l10n.commonReadMore), findsOneWidget);
      expect(find.byKey(_key(second, 'more')), findsOneWidget);
    });
  });

  group('T-20 · PostCard · eylemler', () {
    testWidgets('her öğe kendi geri çağrısını çağırır; anahtarlar çağırandan '
        '(envanter adları)', (tester) async {
      final calls = _Calls();
      await pumpPost(tester, calls.card(kAnnouncement));

      for (final action in [
        'author',
        'menu',
        'like',
        'comment',
        'share',
        'save',
      ]) {
        await tester.tap(find.byKey(_key(kAnnouncement, action)));
        await tester.pump();
      }
      await tester.tap(find.text(kAnnouncement.text));
      expect(calls.log, [
        'author',
        'menu',
        'like',
        'comment',
        'share',
        'save',
        'open',
      ]);
      expect(ActionInventory.found(tester), {
        for (final action in [
          'author',
          'menu',
          'post',
          'like',
          'comment',
          'share',
          'save',
        ])
          'FED-01.$action.p01',
      });
    });

    testWidgets('gönderi detayı (`expanded`): gövde ve yorum düğmesi bir şey '
        'açmaz ama anahtarları ve olağan görünümleri kalır', (tester) async {
      final calls = _Calls();
      await pumpPost(tester, calls.card(kAnnouncement, expanded: true));

      await tester.tap(find.text(kAnnouncement.text));
      await tester.tap(find.byKey(_key(kAnnouncement, 'comment')));
      expect(calls.log, isEmpty);
      expect(find.byKey(_key(kAnnouncement, 'post')), findsOneWidget);
      final comment = tester.widget<GuIconButton>(
        find.byKey(_key(kAnnouncement, 'comment')),
      );
      expect(comment.onPressed, isNotNull);
      expect(comment.disabled, isFalse);

      await tester.tap(find.byKey(_key(kAnnouncement, 'like')));
      expect(calls.log, ['like']);
    });

    testWidgets('`hideActions`: eylem satırı yok, gövde alt dolgusu 12', (
      tester,
    ) async {
      await pumpPost(
        tester,
        PostCard(
          post: kAnnouncement,
          author: authorOf(kAnnouncement),
          hideActions: true,
          keys: _keys(kAnnouncement),
        ),
      );
      expect(find.byKey(_key(kAnnouncement, 'like')), findsNothing);
      expect(find.byKey(_key(kAnnouncement, 'save')), findsNothing);
      expect(find.byKey(_key(kAnnouncement, 'share')), findsNothing);
      final card = tester.getRect(find.byType(PostCard)).deflate(1);
      expect(
        card.bottom - tester.getRect(find.text(kAnnouncement.text)).bottom,
        GuSpacing.s12,
      );
    });
  });

  group('T-20 · PostCard · beğenildi / kaydedildi', () {
    testWidgets('beğenilmemiş + kayıtsız: çizgi ikonlar; beğenilmiş + kayıtlı: '
        'dolu ikon (çizgi ikon yok), "seçili" okunur; kaydet etiketi değişir', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final calls = _Calls();
      final likeKey = _key(kAnnouncement, 'like');
      final saveKey = _key(kAnnouncement, 'save');
      await pumpPost(tester, calls.card(kAnnouncement));
      final l10n = tester.l10n;

      expect(_hasStrokeIcon(tester, likeKey, GuIcons.heart), isTrue);
      expect(_hasStrokeIcon(tester, saveKey, GuIcons.bookmark), isTrue);
      expect(
        tester.getSemantics(find.byKey(likeKey)),
        isSemantics(
          label: l10n.feedLike,
          isButton: true,
          hasSelectedState: true,
          isSelected: false,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          isFocusable: true,
        ),
      );
      expect(find.bySemanticsLabel(l10n.feedSave), findsOneWidget);

      await pumpPost(
        tester,
        calls.card(kAnnouncement, liked: true, saved: true),
      );
      await tester.pumpAndSettle();
      expect(_hasStrokeIcon(tester, likeKey, GuIcons.heart), isFalse);
      expect(_hasStrokeIcon(tester, saveKey, GuIcons.bookmark), isFalse);
      expect(
        tester.getSemantics(find.byKey(likeKey)),
        isSemantics(
          label: l10n.feedLike,
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          isFocusable: true,
        ),
      );
      expect(find.bySemanticsLabel(l10n.feedUnsave), findsOneWidget);
      expect(find.bySemanticsLabel(l10n.feedSave), findsNothing);
      // Sayaç rengi değişmez.
      final gu = tester.element(find.byType(PostCard)).gu;
      expect(
        tester
            .widget<Text>(find.text('${kAnnouncement.likeCount}'))
            .style!
            .color,
        gu.colors.textHeading,
      );
      handle.dispose();
    });

    testWidgets('kalp `pop`: beğenildiği anda ikon 1.35 olup 1 ölçeğine döner '
        '(`GuMotion.slow`); beğeni geri alınınca oynatılmaz', (tester) async {
      final calls = _Calls();
      final likeKey = _key(kAnnouncement, 'like');
      double scale() => tester
          .widget<ScaleTransition>(
            find.descendant(
              of: find.byKey(likeKey),
              matching: find.byType(ScaleTransition),
            ),
          )
          .scale
          .value;

      final liked = ValueNotifier<bool>(false);
      addTearDown(liked.dispose);
      await pumpPost(
        tester,
        ValueListenableBuilder<bool>(
          valueListenable: liked,
          builder: (_, value, _) => calls.card(kAnnouncement, liked: value),
        ),
      );
      expect(scale(), 1);

      liked.value = true;
      await tester.pump();
      await tester.pump(GuMotion.slow * 0.4);
      expect(scale(), closeTo(GuMotion.heartPopScale, 0.001));
      await tester.pump(GuMotion.slow);
      expect(scale(), 1);

      liked.value = false;
      await tester.pump();
      await tester.pump(GuMotion.slow * 0.4);
      expect(scale(), 1);
    });
  });

  group('T-20 · PostCard · erişilebilirlik', () {
    testWidgets('kart başlıkla (yoksa metnin ilk 40 karakteriyle) etiketlidir; '
        'yazar satırı ad + rol + alt satırla okunan düğmedir', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPost(tester, _Calls().card(kAnnouncement));
      final l10n = tester.l10n;
      expect(
        find.bySemanticsLabel(
          RegExp('^${RegExp.escape(kAnnouncement.title!)}'),
        ),
        findsWidgets,
      );
      final author = tester
          .getSemantics(find.byKey(_key(kAnnouncement, 'author')))
          .getSemanticsData();
      expect(author.flagsCollection.isButton, isTrue);
      expect(author.label, contains(authorOf(kAnnouncement).name));
      expect(author.label, contains(l10n.rolePresident));
      expect(author.label, contains(l10n.timeWeeksAgo(1)));

      await pumpPost(tester, _Calls().card(kImagePost));
      final prefix = kImagePost.text.substring(0, 40);
      expect(
        tester.widget<GuCard>(find.byType(GuCard)).semanticLabel,
        prefix,
      );
      handle.dispose();
    });
  });

  group('T-20 · gönderi kartları · galeri', () {
    testWidgets('cihaz matrisi: galeri taşmaz (320 dp, ölçek 1.6, TR / EN)', (
      tester,
    ) async {
      await DeviceMatrix.run(
        tester,
        _gallery,
        overrides: [clockAt(kPostNow)],
      );
    });

    testWidgets('golden: galeri — açık + koyu (TR)', (tester) async {
      await goldenForThemes(
        tester,
        'post_cards',
        const Builder(builder: _gallery),
        size: const Size(390, 1560),
        overrides: [clockAt(kPostNow)],
      );
    });
  });
}
