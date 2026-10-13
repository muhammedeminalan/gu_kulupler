import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/widget/post/image_grid.dart';
import 'package:gu_ui/gu_ui.dart';

/// Tam ekran görsel görüntüleyici — SHT-34'ün gövdesi (prototip
/// `SHEETS['SHT-34']`, `sheets.js:155–162`; CSS `.viewer`, css:409).
///
/// * Siyah zemin (`viewerBackground`); durum çubuğu ikonları her iki temada
///   açıktır (`GuSystemUi(lightIcons)` — CD-89, K-49).
/// * Üst satır (dolgu güvenli alan − 4 / 8): kapat ([onClose]), "i/n" sayacı
///   (`labelL`, tablo rakamı) ve paylaş ([onShare] → SHT-15); düğmeler kapak
///   üstü görünümdedir.
/// * [images] yatay sayfalanır ([initialIndex] ilk sayfa); sayfa kare
///   [PostImage]'dır — [imageOf] görsel vermezse [club] paletinden üretilen
///   yer tutucu (K-18; `ImageGrid` ile aynı kaynak).
/// * Çift dokunuş etkin sayfayı 1.8 kat yakınlaştırır / geri alır
///   (`GuMotion.viewerZoom`). Yakınlaştırılmamışken aşağı sürükleme
///   görüntüleyiciyi parmakla taşır ve soldurur (opaklık `1 − dy / 400`);
///   120'den uzun sürükleme kapatır ([onClose]), kısası yerine döner.
/// * Altta ipucu satırı (`caption`, `viewerHintForeground`; alt güvenli alan
///   + 12).
/// * Anahtarları çağıran verir (`ImageViewerSheet`): [closeKey]
///   `SHT-34.close`, [shareKey] `SHT-34.share`, [swipeKey] `SHT-34.swipe`,
///   [zoomKey] `SHT-34.zoom.<index>`.
/// * Erişilebilirlik: "Görsel" adlı rota kapsamı; kapat düğmesi ilk odaktır;
///   her sayfa ipucu metniyle okunan, dokununca yakınlaştıran düğmedir.
///
/// Sınırlı yükseklik ister (tam ekran); `ImageViewerSheet` ekran
/// yüksekliğini verir.
class ImageViewer extends ConsumerStatefulWidget {
  /// [images] görsellerinin görüntüleyicisi.
  const ImageViewer({
    required this.images,
    this.initialIndex = 0,
    this.club,
    this.onClose,
    this.onShare,
    this.closeKey,
    this.shareKey,
    this.swipeKey,
    this.zoomKey,
    this.imageOf,
    super.key,
  });

  /// Sayaç ayracı (`sheets.js:160` `${i + 1}/${n}`).
  static const String _counterSeparator = '/';

  /// Gösterilen görseller (Storage yolu + boyut).
  final List<PostImageModel> images;

  /// İlk açılan sayfa (0'dan).
  final int initialIndex;

  /// Yer tutucu deseninin paleti / deseni; `null` → varsayılan.
  final ClubModel? club;

  /// Kapat (X, aşağı sürükleme).
  final VoidCallback? onClose;

  /// Paylaş → SHT-15; `null` → düğme etkisiz.
  final VoidCallback? onShare;

  /// Kapat düğmesinin anahtarı (`SHT-34.close`).
  final Key? closeKey;

  /// Paylaş düğmesinin anahtarı (`SHT-34.share`).
  final Key? shareKey;

  /// Sayfalayıcının anahtarı (`SHT-34.swipe`).
  final Key? swipeKey;

  /// Sayfanın anahtarı (`SHT-34.zoom.<index>`).
  final Key? Function(int index)? zoomKey;

  /// Görsel çözücü; `null` → sayfalar yer tutucu.
  final PostImageResolver? imageOf;

  @override
  ConsumerState<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends ConsumerState<ImageViewer> {
  late int _index = _clamp(widget.initialIndex);
  late final PageController _pages = PageController(initialPage: _index);
  bool _zoom = false;
  double _dragY = 0;

  int _clamp(int index) =>
      math.max(0, math.min(index, widget.images.length - 1));

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _toggleZoom() => setState(() => _zoom = !_zoom);

  void _onDrag(DragUpdateDetails details) {
    if (_zoom) return;
    setState(() => _dragY = math.max(0, _dragY + details.delta.dy));
  }

  void _endDrag() {
    final close = _dragY > GuSizes.sheetDragCloseThreshold;
    setState(() => _dragY = 0);
    if (close) widget.onClose?.call();
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final safe = MediaQuery.viewPaddingOf(context);
    final onCover = gu.component.onCoverForeground;
    final fade = math
        .max(
          0,
          1 - _dragY / GuSizes.viewerDragFadeDistance,
        )
        .toDouble();

    return GuSystemUi(
      style: GuSystemUiStyle.lightIcons,
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: l10n.sht34Title,
        child: Transform.translate(
          offset: Offset(0, _dragY),
          child: Opacity(
            opacity: fade,
            child: ColoredBox(
              color: gu.component.viewerBackground,
              child: Column(
                children: [
                  Padding(
                    padding: GuInsets.only(
                      left: GuSpacing.s8,
                      top: math.max(
                        0,
                        safe.top - GuSizes.parallaxBarTopOffset,
                      ),
                      right: GuSpacing.s8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GuIconButton(
                          key: widget.closeKey,
                          icon: GuIcons.x,
                          semanticLabel: l10n.a11yClose,
                          onCover: true,
                          autofocus: true,
                          onPressed: widget.onClose,
                        ),
                        Text(
                          [
                            _index + 1,
                            widget.images.length,
                          ].join(ImageViewer._counterSeparator),
                          style: gu.text.labelL.copyWith(
                            color: onCover,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        GuIconButton(
                          key: widget.shareKey,
                          icon: GuIcons.share2,
                          semanticLabel: l10n.commonShare,
                          onCover: true,
                          onPressed: widget.onShare,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onVerticalDragUpdate: _onDrag,
                      onVerticalDragEnd: (_) => _endDrag(),
                      onVerticalDragCancel: _endDrag,
                      child: PageView.builder(
                        key: widget.swipeKey,
                        controller: _pages,
                        itemCount: widget.images.length,
                        onPageChanged: (index) =>
                            setState(() => _index = index),
                        itemBuilder: _page,
                      ),
                    ),
                  ),
                  Padding(
                    padding: GuInsets.only(
                      left: GuSpacing.s16,
                      right: GuSpacing.s16,
                      bottom: safe.bottom + GuSpacing.s12,
                    ),
                    child: Text(
                      l10n.sht34ZoomHint,
                      textAlign: TextAlign.center,
                      style: gu.text.caption.copyWith(
                        color: gu.component.viewerHintForeground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Tek sayfa (`sheets.js:161`): ortada kare görsel; çift dokunuş
  /// yakınlaştırır.
  Widget _page(BuildContext context, int index) {
    final gu = context.gu;
    return Center(
      child: Semantics(
        button: true,
        label: context.l10n.sht34ZoomHint,
        onTap: _toggleZoom,
        child: GestureDetector(
          key: widget.zoomKey?.call(index),
          behavior: HitTestBehavior.opaque,
          onDoubleTap: _toggleZoom,
          child: AnimatedScale(
            scale: _zoom && index == _index ? GuSizes.viewerZoomScale : 1,
            duration: gu.duration(GuMotion.viewerZoom),
            curve: GuMotion.easeEmphasized,
            child: AspectRatio(
              aspectRatio: GuSizes.coverRatio1x1,
              child: PostImage(
                image: widget.images[index],
                club: widget.club,
                imageOf: widget.imageOf,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
