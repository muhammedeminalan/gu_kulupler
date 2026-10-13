import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/widget/club/cover_mapper.dart';
import 'package:gu_ui/gu_ui.dart';

/// Gönderi görselini çizilecek görsele çözen geri çağrı (Storage yolu →
/// indirme adresi + önbellek uygulama katmanındadır). `null` dönerse — ya da
/// hiç verilmezse — hücre yer tutucu desenle çizilir (K-18).
typedef PostImageResolver = ImageProvider? Function(PostImageModel image);

/// Tek gönderi görseli — `ImageGrid` hücresinin ve `ImageViewer` sayfasının
/// ortak çizimi (prototip `coverArtSVG(seed, club.iconName, club.palette)`,
/// `cards.js:94`, `sheets.js:161`).
///
/// Altta her zaman yer tutucu vardır: [club] kulübünün palet × desen şablonu
/// (kulüp yoksa `slate` + `image` ikonu). [imageOf] bir görsel verirse onun
/// üstüne çizilir; görsel yüklenene kadar ve yüklenemezse yer tutucu görünür
/// (Storage `posts/` okuma kuralı T-21'de açılır).
///
/// Üst öğenin verdiği alanı doldurur (`GuCoverRatio.fill`); boyutu çağıran
/// belirler.
class PostImage extends StatelessWidget {
  /// [image] görselinin çizimi.
  const PostImage({required this.image, this.club, this.imageOf, super.key});

  /// Görsel (Storage yolu + boyut).
  final PostImageModel image;

  /// Yer tutucu deseninin paleti / deseni / ikonu; `null` → varsayılan.
  final ClubModel? club;

  /// Görsel çözücü; `null` → yalnızca yer tutucu.
  final PostImageResolver? imageOf;

  static Widget _failed(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) => const SizedBox.shrink();

  @override
  Widget build(BuildContext context) {
    final club = this.club;
    final provider = imageOf?.call(image);
    final overlays = <Widget>[
      if (provider != null)
        Image(
          image: provider,
          fit: BoxFit.cover,
          excludeFromSemantics: true,
          errorBuilder: _failed,
        ),
    ];
    return club == null
        ? GuCover.template(
            palette: GuCoverPalette.slate,
            pattern: GuCoverPattern.dots,
            icon: GuIcons.image,
            ratio: GuCoverRatio.fill,
            overlays: overlays,
          )
        : CoverMapper.club(
            club,
            ratio: GuCoverRatio.fill,
            overlays: overlays,
          );
  }
}

/// Gönderi görselleri ızgarası — prototip `ImageGrid` (`cards.js:92–95`),
/// CSS `.img-grid .n1–.n4` (css:407–408). `PostCard` içinden çizilir.
///
/// * Yerleşim görsel sayısına göredir (en çok [maxCells] hücre): **1** tek
///   hücre 16:9 · **2** yan yana iki kare · **3** solda geniş hücre (2 pay,
///   iki satır) + sağda alt alta iki kare (1 pay) · **4** 2 × 2 kare. Aralık
///   4, dış köşe 14.
/// * [images] gönderinin Storage görselleridir (`posts.images[]`; Q-19).
///   Hücre [PostImage]'dır: [imageOf] görsel vermezse, görsel yüklenene kadar
///   ya da yüklenemezse [club] paletinden üretilen yer tutucu desendir (K-18).
/// * Hücreye dokunma [onOpen] (hücre sırası) → SHT-34 `ImageViewerSheet`.
/// * Anahtarı çağıran verir (D-18, CD-86): [imageKey]
///   `<ID>.image.<postId>.<index>`.
/// * Erişilebilirlik: her hücre "Görseli aç (n)" etiketli düğmedir.
class ImageGrid extends StatelessWidget {
  /// [images] görsellerinin ızgarası.
  const ImageGrid({
    required this.images,
    this.club,
    this.onOpen,
    this.imageKey,
    this.imageOf,
    super.key,
  });

  /// Izgarada çizilen en çok hücre (`cards.js:93` `Math.min(4, …)`).
  static const int maxCells = 4;

  /// İki: `.n2` / `.n4` sütun ve satır sayısı, `.n3` geniş hücrenin sütun
  /// payı ve satır yayılımı (`grid-template-columns:2fr 1fr`,
  /// `grid-row:span 2`; css:407).
  static const int _span = 2;

  /// Gönderinin görselleri (Storage yolu + boyut).
  final List<PostImageModel> images;

  /// Yer tutucu deseninin paleti / deseni; `null` → varsayılan.
  final ClubModel? club;

  /// Hücreye dokunma (hücre sırası, 0'dan).
  final ValueChanged<int>? onOpen;

  /// Hücre düğmesinin anahtarı (`<ID>.image.<postId>.<index>`).
  final Key? Function(int index)? imageKey;

  /// Görsel çözücü; `null` → hücreler yer tutucu.
  final PostImageResolver? imageOf;

  Widget _cell(BuildContext context, int index) {
    final onOpen = this.onOpen;
    return GuTapTarget(
      key: imageKey?.call(index),
      onTap: onOpen == null ? null : () => onOpen(index),
      semanticLabel: context.l10n.a11yOpenImage(index + 1),
      child: PostImage(image: images[index], club: club, imageOf: imageOf),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = images.length < maxCells ? images.length : maxCells;
    if (count == 0) return const SizedBox.shrink();
    const gap = GuSizes.imageGridGap;
    const hGap = SizedBox(width: gap);
    const vGap = SizedBox(height: gap);
    Widget cell(int index) => Expanded(child: _cell(context, index));

    return ClipRRect(
      borderRadius: GuRadius.borderImageGrid,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final half = (width - gap) / _span;
          final third = (width - gap) / (_span + 1);
          return switch (count) {
            1 => AspectRatio(
              aspectRatio: GuSizes.coverRatio16x9,
              child: _cell(context, 0),
            ),
            2 => SizedBox(
              height: half,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [cell(0), hGap, cell(1)],
              ),
            ),
            3 => SizedBox(
              height: third * _span + gap,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: _span, child: _cell(context, 0)),
                  hGap,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [cell(1), vGap, cell(2)],
                    ),
                  ),
                ],
              ),
            ),
            _ => SizedBox(
              height: half * _span + gap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [cell(0), hGap, cell(1)],
                    ),
                  ),
                  vGap,
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [cell(2), hGap, cell(3)],
                    ),
                  ),
                ],
              ),
            ),
          };
        },
      ),
    );
  }
}
