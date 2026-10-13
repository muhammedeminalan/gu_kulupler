import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/format/relative_time_formatter.dart';
import 'package:gu_kulupler/product/widget/member/member_row.dart';
import 'package:gu_kulupler/product/widget/post/image_grid.dart';
import 'package:gu_kulupler/product/widget/post/poll_block.dart';
import 'package:gu_ui/gu_ui.dart';

/// `PostCard` içindeki etkileşimli öğelerin anahtarları. Çağıran verir (D-18:
/// `GuKey.action` değişmezi çağrı yerinde, CD-86); verilmeyen öğe anahtarsız
/// çizilir.
///
/// ```dart
/// PostCardKeys(
///   author: GuKey.action('FED-01.author.${post.id}'),
///   menu: GuKey.action('FED-01.menu.${post.id}'),
///   post: GuKey.action('FED-01.post.${post.id}'),
///   more: GuKey.action('FED-01.more.${post.id}'),
///   like: GuKey.action('FED-01.like.${post.id}'),
///   comment: GuKey.action('FED-01.comment.${post.id}'),
///   share: GuKey.action('FED-01.share.${post.id}'),
///   save: GuKey.action('FED-01.save.${post.id}'),
///   image: (index) => GuKey.action('FED-01.image.${post.id}.$index'),
///   vote: (optionId) => GuKey.action('FED-01.vote.${post.id}.$optionId'),
/// )
/// ```
@immutable
final class PostCardKeys {
  /// Verilen anahtarlarla küme; hepsi isteğe bağlıdır.
  const PostCardKeys({
    this.author,
    this.menu,
    this.post,
    this.more,
    this.like,
    this.comment,
    this.share,
    this.save,
    this.image,
    this.vote,
  });

  /// Yazar satırı (`<ID>.author.<postId>`).
  final Key? author;

  /// "…" menü düğmesi (`<ID>.menu.<postId>`).
  final Key? menu;

  /// Gönderi metni / gövdesi (`<ID>.post.<postId>`).
  final Key? post;

  /// "Devamı" (`<ID>.more.<postId>`).
  final Key? more;

  /// Beğen (`<ID>.like.<postId>`).
  final Key? like;

  /// Yorum (`<ID>.comment.<postId>`).
  final Key? comment;

  /// Paylaş (`<ID>.share.<postId>`).
  final Key? share;

  /// Kaydet (`<ID>.save.<postId>`).
  final Key? save;

  /// Görsel hücresi (`<ID>.image.<postId>.<index>`).
  final Key? Function(int index)? image;

  /// Anket seçeneği (`<ID>.vote.<postId>.<optionId>`).
  final Key? Function(String optionId)? vote;
}

/// Gönderi kartı — prototip `PostCard` (`cards.js:96–127`): FED-01 akışı,
/// FED-02 gönderi detayı (`expanded`, `showClub`), FED-03 önizleme
/// (`hideActions`); ileride CLB-02, PRF-04, MGT-08, SHT-26.
///
/// Yerleşim (yukarıdan aşağı; gövde öğeleri arasında boşluk yoktur — K-42):
///
/// * **Sabit şeridi** (`post.pinned`): `pin` 14 + "Sabitlenmiş" (`caption`).
/// * **Yazar satırı:** avatar 40 · ad (`labelL` `text.heading`, tek satır +
///   üç nokta) + rol rozeti (sığmazsa alt satıra iner — K-29) · alt satır
///   `caption`: [showClub] ile "kulüp · ", göreli zaman, düzenlendiyse
///   " · düzenlendi" · sağda "…" (SHT-08).
/// * **Tür rozeti:** duyuru `megaphone` "Duyuru" (+ bildirim gönderildiyse
///   `bell-ring` 12 "Bildirim gönderildi"), anket `chart-column` "Anket";
///   sıradan gönderide yok.
/// * **Başlık** (`titleS`) ve **metin** (`bodyM`): [longTextThreshold]
///   karakterden uzun metin [collapsedLines] satıra kırpılır, altında
///   "Devamı" (`labelL` `brand.primaryText`) metni açar.
/// * **`ImageGrid`** ve **`PollBlock`**.
/// * **Eylem satırı:** beğen (`heart` 22 + sayı), yorum (`message-circle` 22
///   + sayı), paylaş; sağda kaydet (`bookmark` 22). Sayı 0 ise yazılmaz.
///
/// Durumlar: [liked] kalp dolu + `brand.primaryText`, beğenildiği anda `pop`
/// (ölçek 1.35, `GuMotion.slow`; hareket azaltılmışsa oynatılmaz) · [saved]
/// yer imi dolu + `brand.primaryText` · [expanded] gönderi detayı: metin
/// kırpılmaz, gövdeye dokunma ve yorum düğmesi bir şey açmaz · [highlight]
/// 1,5 sn vurgu halkası · [hideActions] eylem satırı yok.
///
/// * Girdi alan modelidir: [post] + [author] (güncel kullanıcı belgesi;
///   `null` → "Silinmiş kullanıcı", avatar `?`, rozet yok) + [role] (yazarın
///   kulüpteki rolü; rozet) + [club] ([showClub] ile alt satırda adı; görsel
///   yer tutucusunun paleti).
/// * Kullanıcıya göre durum çağırandan gelir: [liked], [saved], [myOptionId]
///   (anket oyu), [pollResults] (seçenek → oy; `countVotes`).
/// * Kart hiçbir şey yürütmez: dokunuşlar geri çağrılardır ([onOpen] →
///   FED-02, [onAuthor] → CLB-07, [onMenu] → SHT-08, [onLike], [onComment] →
///   SHT-09, [onShare] → SHT-15, [onSave], [onVote], [onImage] → SHT-34).
///   Eylem mantığı `PostActionsMixin`'dedir.
/// * Anahtarları çağıran verir ([keys], [PostCardKeys]).
/// * Erişilebilirlik: kart başlığı (yoksa metnin başı) ile etiketli kaptır;
///   yazar satırı ad + rol + alt satırla okunan düğmedir; beğen ve kaydet
///   "seçili" durumunu taşır.
class PostCard extends ConsumerStatefulWidget {
  /// [post] gönderisinin kartı.
  const PostCard({
    required this.post,
    this.author,
    this.role,
    this.club,
    this.liked = false,
    this.saved = false,
    this.myOptionId,
    this.pollResults = const <String, int>{},
    this.expanded = false,
    this.showClub = false,
    this.highlight = false,
    this.hideActions = false,
    this.keys = const PostCardKeys(),
    this.onOpen,
    this.onAuthor,
    this.onMenu,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onSave,
    this.onVote,
    this.onImage,
    this.imageOf,
    super.key,
  });

  /// Bu uzunluğun üstündeki metin kırpılır (`cards.js:105`
  /// `post.text.length > 280`).
  static const int longTextThreshold = 280;

  /// Kırpılmış metnin satır sayısı (`.clamp5`, css:104).
  static const int collapsedLines = 5;

  /// Başlıksız gönderide kart etiketine alınan metin uzunluğu
  /// (`cards.js:106` `post.text.slice(0, 40)`).
  static const int _labelLength = 40;

  /// Alt satır ayracı (`cards.js:110` `' · '`).
  static const String _separator = ' · ';

  /// Silinmiş kullanıcının avatar metni ve renk tohumu (`art.js:44`).
  static const String _unknown = '?';

  // gu_ui'da `PostCard`'a özgü 10 px token'ı yok (cards.js:107–112 satır içi
  // ölçüler, K-46); aynı değerli kart token'ları kullanılır.

  /// Sabit şeridinin ve gövdenin üst dolgusu (`padding:10px 16px 0`,
  /// `padding:10px 16px 12px`).
  static const double _blockTop = GuSizes.clubCardBodyPaddingTop;

  /// Yazar satırındaki aralık (`gap:10px`).
  static const double _headerGap = GuSizes.clubCardBodyPaddingTop;

  /// Gönderi.
  final PostModel post;

  /// Yazarın güncel belgesi; `null` → "Silinmiş kullanıcı".
  final UserModel? author;

  /// Yazarın kulüpteki rolü (rol rozeti); `null` → rozet yok.
  final ClubRole? role;

  /// Gönderinin kulübü ([showClub] adı, görsel yer tutucusu).
  final ClubModel? club;

  /// Oturumdaki kullanıcı beğenmiş mi?
  final bool liked;

  /// Oturumdaki kullanıcının kaydedilenlerinde mi?
  final bool saved;

  /// Kullanıcının anket oyu; oy vermediyse `null`.
  final String? myOptionId;

  /// Anket sonuçları (seçenek → oy).
  final Map<String, int> pollResults;

  /// Gönderi detayı kipi (metin kırpılmaz, gövde dokunulmaz).
  final bool expanded;

  /// Alt satırda kulüp adı gösterilsin mi?
  final bool showClub;

  /// 1,5 sn vurgu halkası (`GuCard.highlight`).
  final bool highlight;

  /// Eylem satırı gizlensin mi (FED-03 önizleme)?
  final bool hideActions;

  /// Etkileşimli öğelerin anahtarları.
  final PostCardKeys keys;

  /// Gövdeye dokunma → gönderi detayı (FED-02); [expanded] iken çağrılmaz.
  final VoidCallback? onOpen;

  /// Yazar satırı → profil (CLB-07).
  final VoidCallback? onAuthor;

  /// "…" → SHT-08.
  final VoidCallback? onMenu;

  /// Beğen / geri al.
  final VoidCallback? onLike;

  /// Yorum → SHT-09; [expanded] iken çağrılmaz.
  final VoidCallback? onComment;

  /// Paylaş → SHT-15.
  final VoidCallback? onShare;

  /// Kaydet / kaydı kaldır.
  final VoidCallback? onSave;

  /// Anket seçeneği (seçenek kimliği).
  final ValueChanged<String>? onVote;

  /// Görsel hücresi (hücre sırası) → SHT-34.
  final ValueChanged<int>? onImage;

  /// Görsel çözücü (`ImageGrid.imageOf`); `null` → yer tutucu (K-18).
  final PostImageResolver? imageOf;

  /// Sayaç metni: 0 → boş (`post.likes.length || ''`, `cards.js:124`).
  static String countLabel(int count) => count > 0 ? '$count' : '';

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard>
    with SingleTickerProviderStateMixin {
  /// `@keyframes pop` (css:419): %0 1 → %40 1.35 → %100 1; eğri her aralığa
  /// ayrı uygulanır (CSS `animation-timing-function`).
  static const double _popPeakAt = 40;
  static const double _popRest = 60;
  static final Animatable<double> _popScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: GuMotion.heartPopScale,
      ).chain(CurveTween(curve: GuMotion.easeEmphasized)),
      weight: _popPeakAt,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: GuMotion.heartPopScale,
        end: 1,
      ).chain(CurveTween(curve: GuMotion.easeEmphasized)),
      weight: _popRest,
    ),
  ]);

  late final AnimationController _pop;
  late bool _more = widget.expanded;

  @override
  void initState() {
    super.initState();
    // 1 = durağan (animasyon bitmiş).
    _pop = AnimationController(vsync: this, duration: GuMotion.slow, value: 1);
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Liste satırı başka gönderiyle yeniden kullanılırsa kırpma sıfırlanır.
    if (widget.post.id != oldWidget.post.id) {
      _more = widget.expanded;
    } else if (widget.expanded && !oldWidget.expanded) {
      _more = true;
    }
    if (widget.liked && !oldWidget.liked && !context.gu.reduceMotion) {
      unawaited(_pop.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  void _showMore() => setState(() => _more = true);

  void _comment() {
    if (!widget.expanded) widget.onComment?.call();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final title = post.title;
    final hasTitle = title != null && title.isNotEmpty;
    return GuCard(
      highlight: widget.highlight,
      semanticLabel: hasTitle
          ? title
          : String.fromCharCodes(post.text.runes.take(PostCard._labelLength)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (post.pinned) _pinned(context),
          _header(context),
          _body(context),
          if (!widget.hideActions) _actions(context),
        ],
      ),
    );
  }

  /// `cards.js:107`: `row gap4 t-caption`, dolgu 10 / 16 / 0.
  Widget _pinned(BuildContext context) {
    final gu = context.gu;
    return Padding(
      padding: GuInsets.only(
        left: GuSpacing.s16,
        top: PostCard._blockTop,
        right: GuSpacing.s16,
      ),
      child: Row(
        spacing: GuSpacing.s4,
        children: [
          GuIcon(
            GuIcons.pin,
            size: GuSizes.icon14,
            color: gu.colors.textMuted,
          ),
          Flexible(
            child: Text(context.l10n.feedPinned, style: gu.text.caption),
          ),
        ],
      ),
    );
  }

  /// `cards.js:108–112`: dolgu 12 / 8 / 0 / 16, aralık 10, üstten hizalı.
  Widget _header(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final post = widget.post;
    final author = widget.author;
    final club = widget.club;
    final role = author == null ? null : widget.role;
    final created = post.createdAt;
    final name = author?.name ?? l10n.commonDeletedUser;
    final caption = [
      if (widget.showClub && club != null) club.name,
      if (created == null)
        l10n.timeJustNow
      else
        RelativeTimeFormatter(
          l10n,
          ref.watch(appClockProvider),
        ).format(created),
      if (post.editedAt != null) l10n.feedEdited,
    ].join(PostCard._separator);

    final String seed;
    if (author == null) {
      seed = PostCard._unknown;
    } else {
      seed = author.avatarSeed.isEmpty ? author.uid : author.avatarSeed;
    }

    return Padding(
      padding: GuInsets.only(
        left: GuSpacing.s16,
        top: GuSpacing.s12,
        right: GuSpacing.s8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GuTapTarget(
              key: widget.keys.author,
              onTap: widget.onAuthor,
              child: Row(
                children: [
                  GuAvatar(
                    initials: (author?.name ?? PostCard._unknown).initials,
                    seed: seed,
                    // Token açık kalsın (varsayılanla aynı değer).
                    // ignore: avoid_redundant_argument_values
                    size: GuSizes.postAvatar,
                  ),
                  const SizedBox(width: PostCard._headerGap),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: GuSpacing.s6,
                          runSpacing: GuSpacing.s6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              name,
                              style: gu.text.labelL.copyWith(
                                color: gu.colors.textHeading,
                              ),
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (role != null) MemberRow.roleBadge(l10n, role),
                          ],
                        ),
                        Text(caption, style: gu.text.caption),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: PostCard._headerGap),
          GuIconButton(
            key: widget.keys.menu,
            icon: GuIcons.moreHorizontal,
            semanticLabel: l10n.a11yMore,
            onPressed: widget.onMenu,
          ),
        ],
      ),
    );
  }

  /// `cards.js:113–122`: dolgu 10 / 16 / 12; öğeler arasında boşluk yok
  /// (`col gap10` CSS'te tanımsız — K-42). Eylem satırı varsa alt dolguyu o
  /// taşır (`margin:0 -8px -4px`).
  Widget _body(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final post = widget.post;
    final title = post.title;
    final poll = post.poll;
    final clamped = post.text.length > PostCard.longTextThreshold && !_more;

    return Padding(
      padding: GuInsets.only(
        left: GuSpacing.s16,
        top: PostCard._blockTop,
        right: GuSpacing.s16,
        bottom: widget.hideActions ? GuSpacing.s12 : 0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (post.isAnnouncement)
            Row(
              spacing: GuSpacing.s6,
              children: [
                GuBadge(
                  label: l10n.feedTypeAnnouncement,
                  kind: GuBadgeKind.president,
                  icon: GuIcons.megaphone,
                ),
                if (post.pushSent)
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: GuSpacing.s4,
                      children: [
                        GuIcon(
                          GuIcons.bellRing,
                          size: GuSizes.icon12,
                          color: gu.colors.textMuted,
                        ),
                        Flexible(
                          child: Text(
                            l10n.feedPushSent,
                            style: gu.text.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            )
          else if (post.isPoll)
            // Sütunun doğrudan çocuğu: tam genişliğe esner (referans
            // görüntü, `cards.js:114`).
            GuBadge(
              label: l10n.feedTypePoll,
              kind: GuBadgeKind.info,
              icon: GuIcons.chartColumn,
            ),
          if (title != null && title.isNotEmpty)
            Text(title, style: gu.text.titleS),
          GuTapTarget(
            key: widget.keys.post,
            onTap: widget.expanded ? null : widget.onOpen,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.text,
                  style: gu.text.bodyM,
                  maxLines: clamped ? PostCard.collapsedLines : null,
                  overflow: clamped ? TextOverflow.ellipsis : null,
                ),
                if (clamped)
                  Padding(
                    padding: GuInsets.only(top: GuSpacing.s4),
                    child: GuTapTarget(
                      key: widget.keys.more,
                      onTap: _showMore,
                      child: Text(
                        l10n.commonReadMore,
                        style: gu.text.labelL.copyWith(
                          color: gu.colors.brandPrimaryText,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (post.images.isNotEmpty)
            ImageGrid(
              images: post.images,
              club: widget.club,
              onOpen: widget.onImage,
              imageKey: widget.keys.image,
              imageOf: widget.imageOf,
            ),
          if (poll != null)
            PollBlock(
              poll: poll,
              results: widget.pollResults,
              myOptionId: widget.myOptionId,
              onVote: widget.onVote,
              optionKey: widget.keys.vote,
            ),
        ],
      ),
    );
  }

  /// `cards.js:123–129`: `row between`, `margin:0 -8px -4px` → yatay dolgu
  /// 16 − 8, alt dolgu 12 − 4.
  Widget _actions(BuildContext context) {
    final l10n = context.l10n;
    final post = widget.post;
    return Padding(
      padding: GuInsets.only(
        left: GuSpacing.s8,
        right: GuSpacing.s8,
        bottom: GuSpacing.s8,
      ),
      child: Row(
        children: [
          _ToggleAction(
            key: widget.keys.like,
            icon: GuIcons.heart,
            active: widget.liked,
            semanticLabel: l10n.feedLike,
            countLabel: PostCard.countLabel(post.likeCount),
            scale: _popScale.animate(_pop),
            onTap: widget.onLike,
          ),
          const SizedBox(width: GuSpacing.s2),
          GuIconButton(
            key: widget.keys.comment,
            icon: GuIcons.messageCircle,
            iconSize: GuSizes.postActionIcon,
            semanticLabel: l10n.feedComment,
            countLabel: PostCard.countLabel(post.commentCount),
            onPressed: _comment,
          ),
          const SizedBox(width: GuSpacing.s2),
          GuIconButton(
            key: widget.keys.share,
            icon: GuIcons.share2,
            semanticLabel: l10n.commonShare,
            onPressed: widget.onShare,
          ),
          const Spacer(),
          _ToggleAction(
            key: widget.keys.save,
            icon: GuIcons.bookmark,
            active: widget.saved,
            semanticLabel: widget.saved ? l10n.feedUnsave : l10n.feedSave,
            onTap: widget.onSave,
          ),
        ],
      ),
    );
  }
}

/// Aç / kapa eylem düğmesi — beğen ve kaydet (`cards.js:124`, `:128`).
///
/// Ölçüler `.iconbtn` ile aynıdır (`GuIconButton`): 48 yükseklik, basılıyken
/// `bg.surfaceMuted`; [countLabel] verilirse otomatik genişlik, dolgu 10,
/// aralık 6, radius 12 + sayaç (`labelM`, tablo rakamı), verilmezse 48 daire.
/// `GuIconButton` dolu ikon ve ikondan ayrı metin rengi çizemediği için
/// ayrıdır: [active] iken ikon dolu ve `brand.primaryText`, sayaç
/// `text.heading` kalır. [scale] ikonu ölçekler (kalp `pop`).
class _ToggleAction extends StatelessWidget {
  const _ToggleAction({
    required this.icon,
    required this.active,
    required this.semanticLabel,
    required this.onTap,
    this.countLabel,
    this.scale,
    super.key,
  });

  /// Çizgi ikon; [active] iken dolu çizilir.
  final GuIcons icon;

  /// Açık mı (`aria-pressed`)?
  final bool active;

  /// Erişilebilirlik etiketi.
  final String semanticLabel;

  /// Dokunma; `null` → etkileşimsiz.
  final VoidCallback? onTap;

  /// İkonun yanındaki sayaç; `null` → yalnız ikon.
  final String? countLabel;

  /// İkon ölçeği.
  final Animation<double>? scale;

  @override
  Widget build(BuildContext context) {
    final count = countLabel;
    final radius = count == null ? GuRadius.borderFull : GuRadius.borderSm;
    return GuActionSurface(
      onTap: onTap,
      semanticLabel: semanticLabel,
      selected: active,
      borderRadius: radius,
      builder: (context, pressed) {
        final gu = context.gu;
        final colors = gu.colors;
        final scale = this.scale;
        Widget glyph = active
            ? _FilledIcon(icon, color: colors.brandPrimaryText)
            : GuIcon(icon, size: GuSizes.postActionIcon);
        if (scale != null) glyph = ScaleTransition(scale: scale, child: glyph);
        return AnimatedContainer(
          duration: gu.duration(GuMotion.fast),
          curve: GuMotion.easeCss,
          width: count == null ? GuSizes.iconButton : null,
          height: GuSizes.iconButton,
          padding: count == null
              ? null
              : GuInsets.sym(h: GuSizes.iconButtonCountPaddingX),
          decoration: BoxDecoration(
            color: pressed ? colors.bgSurfaceMuted : null,
            borderRadius: radius,
          ),
          child: Center(
            widthFactor: 1,
            child: count == null
                ? glyph
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: GuSizes.iconButtonCountGap,
                    children: [
                      glyph,
                      Text(
                        count,
                        style: gu.text.labelM.copyWith(
                          color: colors.textHeading,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

/// Dolu ikon (`style="fill: currentColor"`, `cards.js:124`, `:128`).
///
/// İkon varlıkları çizgi ikondur (`fill="none"`); ayrı dolu varlık yoktur.
/// Dolu görünüm aynı varlıktan türetilir ([_FilledIconLoader]) ve `GuIcon`
/// gibi `srcIn` ile boyanır. Dekoratiftir.
class _FilledIcon extends StatelessWidget {
  const _FilledIcon(this.icon, {required this.color});

  /// Doldurulacak ikon.
  final GuIcons icon;

  /// Çizgi + dolgu rengi.
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SvgPicture(
      _FilledIconLoader(
        asset: icon.assetPath,
        bundle: DefaultAssetBundle.of(context),
      ),
      width: GuSizes.postActionIcon,
      height: GuSizes.postActionIcon,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      excludeFromSemantics: true,
    ),
  );
}

/// İkon varlığını kök `fill="none"` özniteliği dolguya çevrilmiş olarak
/// yükler; önbellek anahtarı varlık + paket.
class _FilledIconLoader extends SvgLoader<String> {
  const _FilledIconLoader({required this.asset, required this.bundle});

  static const String _strokeOnly = 'fill="none"';
  static const String _filled = 'fill="currentColor"';

  final String asset;
  final AssetBundle bundle;

  @override
  Future<String?> prepareMessage(BuildContext? context) =>
      bundle.loadString(asset);

  @override
  String provideSvg(String? message) =>
      (message ?? '').replaceFirst(_strokeOnly, _filled);

  @override
  bool operator ==(Object other) =>
      other is _FilledIconLoader &&
      other.asset == asset &&
      other.bundle == bundle;

  @override
  int get hashCode => Object.hash(asset, bundle);
}
