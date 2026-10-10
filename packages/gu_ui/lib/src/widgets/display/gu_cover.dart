import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/widgets/display/gu_covers.dart';

/// Kapak oranı (CSS `.cover.r16-9 / .r3-2 / .r1-1`, css:209).
enum GuCoverRatio {
  /// 16:9 — ClubCard liste, MyClubChip, SHT-31 önizleme.
  r16x9(GuSizes.coverRatio16x9),

  /// 3:2 — ClubCard ızgara.
  r3x2(GuSizes.coverRatio3x2),

  /// 1:1 — EventCard küçük kapak, SHT-31 şablon hücresi.
  r1x1(GuSizes.coverRatio1x1),

  /// Oransız: üst öğenin verdiği alanı doldurur (`.parallax .cover{inset:0}`,
  /// css:396; CLB-03 / EVT-02 220 px başlık).
  fill(null);

  const GuCoverRatio(this.aspectRatio);

  /// Genişlik / yükseklik; [fill] için `null`.
  final double? aspectRatio;
}

/// Kapak görseli (prototip `Cover`, `art.js:36`; CSS `.cover`, css:209).
///
/// Üç kaynak: [GuCover.template] (palet × desen şablonu), [GuCover.demo]
/// (demo kulüp kapağı) ve [GuCover.image] (Storage görseli, Q-19). Görsel
/// alanı kırparak doldurur (`preserveAspectRatio="xMidYMid slice"` →
/// `BoxFit.cover`); yüklenene kadar, görsel yükleme hatasında ve kayıtsız
/// demo kapağında zemin `bg.surfaceMuted` görünür.
///
/// * [size] genişliktir; yükseklik [ratio]'dan gelir. Verilmezse üst öğenin
///   genişliği kullanılır.
/// * [borderRadius] yalnızca `GuRadius` sabiti alır (EventCard küçük kapağı
///   `GuRadius.borderChip`, K-35); verilmezse kırpmayı kart yapar.
/// * [overlays] kapağın üstüne binen çocuklardır (`Positioned` ile; amblem,
///   durum rozeti, `on-cover` düğmeler); kapak sınırında kırpılır.
///
/// Dekoratiftir: görsel semantik ağacına girmez, [overlays] kendi
/// semantiğini korur. Ağır SVG'ler (~60 KB, ~700 `<circle>`) için tüm gövde
/// `RepaintBoundary` içindedir (K-12).
///
/// CD-26: `assets/covers` SVG'lerinin tümünde ikon katmanı gömülüdür
/// (şablonlarda `sparkles`), bu yüzden ayrı widget katmanı çizilmez. Şablonda
/// [icon] verilirse gömülü katmanın çizimleri o ikonla değiştirilir
/// (`GuCovers.composeTemplate`; prototip `coverArtSVG(seed, iconName, …)`).
class GuCover extends StatelessWidget {
  /// Şablon kapak: `assets/covers/template-<palet>-<desen>.svg`.
  const GuCover.template({
    required GuCoverPalette this.palette,
    required GuCoverPattern this.pattern,
    this.ratio = GuCoverRatio.r16x9,
    this.icon,
    this.size,
    this.borderRadius,
    this.overlays = const [],
    super.key,
  }) : image = null,
       slug = null;

  /// Yüklenmiş görsel (Storage; `ImageGrid` hücresi).
  const GuCover.image({
    required ImageProvider this.image,
    this.ratio = GuCoverRatio.r16x9,
    this.size,
    this.borderRadius,
    this.overlays = const [],
    super.key,
  }) : palette = null,
       pattern = null,
       icon = null,
       slug = null;

  /// Demo kulüp kapağı: `assets/covers/<slug>.svg` (`GuCovers.demoSlugs`).
  const GuCover.demo({
    required String this.slug,
    this.ratio = GuCoverRatio.r16x9,
    this.size,
    this.borderRadius,
    this.overlays = const [],
    super.key,
  }) : palette = null,
       pattern = null,
       icon = null,
       image = null;

  /// Şablon paleti ([GuCover.template]).
  final GuCoverPalette? palette;

  /// Şablon deseni ([GuCover.template]).
  final GuCoverPattern? pattern;

  /// Kulüp ikonu ([GuCover.template]); gömülü `sparkles` katmanının yerine
  /// çizilir. `null` → şablon olduğu gibi.
  final GuIcons? icon;

  /// Görsel sağlayıcı ([GuCover.image]).
  final ImageProvider? image;

  /// Demo kapak dosya adı ([GuCover.demo]).
  final String? slug;

  /// Oran; [GuCoverRatio.fill] üst öğeyi doldurur.
  final GuCoverRatio ratio;

  /// Genişlik (dp); `null` → üst öğenin genişliği.
  final double? size;

  /// Köşe kırpması (`GuRadius` sabiti); `null` → kırpma yok.
  final BorderRadius? borderRadius;

  /// Kapak üstü katman çocukları.
  final List<Widget> overlays;

  /// Varlık anahtarı; [GuCover.image] ve `GuCovers.demoSlugs` içinde
  /// olmayan [slug] için `null` (yalnızca zemin çizilir).
  String? get assetPath {
    final demoSlug = slug;
    if (demoSlug != null) {
      return GuCovers.demoSlugs.contains(demoSlug)
          ? GuCovers.demo(demoSlug)
          : null;
    }
    final templatePalette = palette;
    final templatePattern = pattern;
    if (templatePalette == null || templatePattern == null) return null;
    return GuCovers.template(templatePalette, templatePattern);
  }

  static Widget _imageError(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) => const SizedBox.shrink();

  @override
  Widget build(BuildContext context) {
    final provider = image;
    final asset = assetPath;
    final Widget? art;
    if (provider != null) {
      art = Image(
        image: provider,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        errorBuilder: _imageError,
      );
    } else if (asset != null) {
      final bundle = DefaultAssetBundle.of(context);
      final clubIcon = icon;
      art = clubIcon == null || clubIcon == GuIcons.sparkles
          ? SvgPicture.asset(
              asset,
              fit: BoxFit.cover,
              bundle: bundle,
              excludeFromSemantics: true,
            )
          : SvgPicture(
              _TemplateIconLoader(
                templateAsset: asset,
                iconAsset: clubIcon.assetPath,
                bundle: bundle,
              ),
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            );
    } else {
      art = null;
    }

    Widget cover = ColoredBox(
      color: context.gu.colors.bgSurfaceMuted,
      child: Stack(fit: StackFit.expand, children: [?art, ...overlays]),
    );
    final radius = borderRadius;
    if (radius != null) cover = ClipRRect(borderRadius: radius, child: cover);
    final aspectRatio = ratio.aspectRatio;
    if (aspectRatio != null) {
      cover = AspectRatio(aspectRatio: aspectRatio, child: cover);
    }
    final width = size;
    if (width != null) cover = SizedBox(width: width, child: cover);
    return RepaintBoundary(child: cover);
  }
}

/// Şablon SVG'sini kulüp ikonuyla birleştirerek yükler
/// (`GuCovers.composeTemplate`); önbellek anahtarı şablon + ikon + paket.
class _TemplateIconLoader extends SvgLoader<(String, String)> {
  const _TemplateIconLoader({
    required this.templateAsset,
    required this.iconAsset,
    required this.bundle,
  });

  final String templateAsset;
  final String iconAsset;
  final AssetBundle bundle;

  @override
  Future<(String, String)?> prepareMessage(BuildContext? context) async => (
    await bundle.loadString(templateAsset),
    await bundle.loadString(iconAsset),
  );

  @override
  String provideSvg((String, String)? message) =>
      message == null ? '' : GuCovers.composeTemplate(message.$1, message.$2);

  @override
  bool operator ==(Object other) =>
      other is _TemplateIconLoader &&
      other.templateAsset == templateAsset &&
      other.iconAsset == iconAsset &&
      other.bundle == bundle;

  @override
  int get hashCode => Object.hash(templateAsset, iconAsset, bundle);
}
