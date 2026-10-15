import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/widget/club/cover_mapper.dart';
import 'package:gu_ui/gu_ui.dart';

/// Kulübün görünüm satırı — logo amblemi + kapak (prototip
/// `screens-manage.js:179` MGT-09 "Görünüm", `screens-admin.js:54` ADM-03):
///
/// * logo: `.emblem` 72 (ikon 30); [logo] verilirse görsel amblemi kaplar
///   (seçilmiş / yüklenmiş logo), yoksa [icon];
/// * kapak: kalan genişlik, logonun yüksekliği (`height:72px`), radius 16;
///   [cover] verilirse yüklenmiş / seçilmiş görsel, yoksa [palette] ×
///   [pattern] şablonu ([icon] gömülü); sağ altta `bg.surface` zeminli
///   "Kapak" rozeti (inset 8).
///
/// İki dokunma hedefi de semantik etiketlidir (`clubSettings.logo` /
/// `clubSettings.cover`); anahtarları çağıran verir ([logoKey] /
/// [coverKey] — `MGT-09.logo`, `ADM-03.logo` …). Görselleri çağıran çözer
/// (`ref.clubLogoImage`, `storageImageResolverProvider`, `MemoryImage`).
class ClubLookPicker extends StatelessWidget {
  /// Logo + kapak satırı.
  const ClubLookPicker({
    required this.icon,
    required this.palette,
    required this.pattern,
    required this.logoKey,
    required this.coverKey,
    required this.onLogoTap,
    required this.onCoverTap,
    this.logo,
    this.cover,
    super.key,
  });

  /// Amblemdeki ve şablon kapaktaki kulüp ikonu.
  final GuIcons icon;

  /// Şablon kapağın paleti.
  final ClubPalette palette;

  /// Şablon kapağın deseni.
  final ClubPattern pattern;

  /// Logo görseli; `null` → ikonlu amblem.
  final ImageProvider? logo;

  /// Kapak görseli; `null` → şablon.
  final ImageProvider? cover;

  /// Logo düğmesinin anahtarı.
  final Key logoKey;

  /// Kapak düğmesinin anahtarı.
  final Key coverKey;

  /// Logoya dokunuldu.
  final VoidCallback onLogoTap;

  /// Kapağa dokunuldu.
  final VoidCallback onCoverTap;

  Widget _cover(BuildContext context, String label) {
    final overlays = <Widget>[
      Positioned(
        right: GuSpacing.s8,
        bottom: GuSpacing.s8,
        // Görsel etiket; semantik kapak düğmesindedir.
        child: ExcludeSemantics(
          child: GuBadge(label: label, background: context.gu.colors.bgSurface),
        ),
      ),
    ];
    final image = cover;
    return image != null
        ? GuCover.image(
            image: image,
            ratio: GuCoverRatio.fill,
            borderRadius: GuRadius.borderMd,
            overlays: overlays,
          )
        : GuCover.template(
            palette: CoverMapper.palette(palette),
            pattern: CoverMapper.pattern(pattern),
            icon: icon,
            ratio: GuCoverRatio.fill,
            borderRadius: GuRadius.borderMd,
            overlays: overlays,
          );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      // Kapak satırı logonun yüksekliğindedir (`height:72px` = `.emblem`).
      height: GuEmblemSize.lg.dimension,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: GuSpacing.s12,
        children: [
          GuActionSurface(
            key: logoKey,
            borderRadius: GuEmblemSize.lg.borderRadius,
            semanticLabel: l10n.clubSettingsLogo,
            onTap: onLogoTap,
            builder: (context, _) => CoverMapper.emblem(
              icon: icon,
              logo: logo,
              size: GuEmblemSize.lg,
              iconSize: GuSizes.icon30,
            ),
          ),
          Expanded(
            child: GuActionSurface(
              key: coverKey,
              borderRadius: GuRadius.borderMd,
              semanticLabel: l10n.clubSettingsCover,
              onTap: onCoverTap,
              builder: (context, _) => _cover(context, l10n.clubSettingsCover),
            ),
          ),
        ],
      ),
    );
  }
}
