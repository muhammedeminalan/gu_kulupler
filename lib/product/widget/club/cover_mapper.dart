import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_ui/gu_ui.dart';

/// Kulüp kapağı eşlemeleri: gu_data alan değerleri → gu_ui kapak girdileri.
///
/// gu_ui gu_data'yı görmez (B01), bu yüzden aynı kümeler iki adla yaşar:
/// `ClubPalette` ↔ `GuCoverPalette`, `ClubPattern` ↔ `GuCoverPattern`
/// (design-analysis §I). Eşleme yalnızca buradadır; `switch`'ler tüketicidir —
/// enum'lardan birine üye eklenirse bu dosya derlenmez.
abstract final class CoverMapper {
  /// [palette] → şablon kapak paleti.
  static GuCoverPalette palette(ClubPalette palette) => switch (palette) {
    ClubPalette.red => GuCoverPalette.red,
    ClubPalette.slate => GuCoverPalette.slate,
    ClubPalette.bordeaux => GuCoverPalette.bordeaux,
  };

  /// [pattern] → şablon kapak deseni.
  static GuCoverPattern pattern(ClubPattern pattern) => switch (pattern) {
    ClubPattern.dots => GuCoverPattern.dots,
    ClubPattern.lines => GuCoverPattern.lines,
    ClubPattern.mountain => GuCoverPattern.mountain,
    ClubPattern.waves => GuCoverPattern.waves,
  };

  /// [iconName] (`clubs.iconName`, Lucide adı — `code-xml`, `mountain` …) →
  /// ikon kaydı; kayıtta olmayan ad `null` (kapak şablonun kendi ikonuyla
  /// çizilir, amblem çağıranın yedeğine düşer). Daha yeni bir sürümün yazdığı
  /// ad eski istemcide ekranı düşürmez.
  static GuIcons? icon(String iconName) => _iconsByName[iconName];

  static final Map<String, GuIcons> _iconsByName = <String, GuIcons>{
    for (final icon in GuIcons.values) icon.fileName: icon,
  };

  /// Kulüp amblemi (CSS `.emblem`): [logo] verilirse yüklenmiş logo
  /// (`clubs.logoPath`, T-36) amblem kutusunu kaplar; verilmezse — logo yok
  /// ya da henüz çözülmedi — ya da logo yüklenemezse tasarımdaki ikonlu
  /// amblem ([icon]). Çağıran logoyu `ref.clubLogoImage(club)` ile çözer
  /// (gu_ui ağ bilmez).
  ///
  /// [size], [iconSize] ve [background] `GuEmblem`'e aynen geçer.
  static GuEmblem emblem({
    required GuIcons icon,
    ImageProvider? logo,
    GuEmblemSize size = GuEmblemSize.sm,
    double? iconSize,
    Color? background,
    Key? key,
  }) => logo == null
      ? GuEmblem(
          icon: icon,
          size: size,
          iconSize: iconSize,
          background: background,
          key: key,
        )
      : GuEmblem(
          size: size,
          background: background,
          key: key,
          child: ClipRRect(
            borderRadius: size.borderRadius,
            child: SizedBox.expand(
              child: Image(
                image: logo,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                // Yüklenemeyen logo (çevrimdışı, süresi geçmiş adres,
                // ImageTooLargeException) → tasarımdaki ikonlu amblem
                // (GuEmblem'in ikon dalıyla aynı ikon / boyut / renk); hata
                // çerçeveye / Crashlytics'e raporlanmaz (T-44 · D2-07).
                errorBuilder: (context, _, _) => Center(
                  child: GuIcon(
                    icon,
                    size: iconSize ?? size.iconSize,
                    color: context.gu.colors.brandPrimaryText,
                  ),
                ),
              ),
            ),
          ),
        );

  /// [club] kulübünün kapağı (prototip `Cover`, `cards.js:31,34`,
  /// `screens-clubs.js:86`; CD-124, K-C).
  ///
  /// * [image] verilirse yüklenmiş kapak çizilir (`GuCover.image`): çağıran
  ///   `club.coverPath` Storage yolunu görsele çözer (indirme adresi +
  ///   önbellek uygulama katmanındadır; gu_ui ağ bilmez — PLAN §7).
  /// * Verilmezse — kulübün kapağı yok ya da henüz çözülmedi — tasarım
  ///   kapağı: `palette` × `pattern` şablonu, gömülü ikon katmanı kulübün
  ///   ikonuyla ([icon]) değiştirilir.
  ///
  /// [ratio], [size], [borderRadius] ve [overlays] `GuCover`'a aynen geçer.
  static GuCover club(
    ClubModel club, {
    ImageProvider? image,
    GuCoverRatio ratio = GuCoverRatio.r16x9,
    double? size,
    BorderRadius? borderRadius,
    List<Widget> overlays = const [],
    Key? key,
  }) => image != null
      ? GuCover.image(
          image: image,
          ratio: ratio,
          size: size,
          borderRadius: borderRadius,
          overlays: overlays,
          key: key,
        )
      : GuCover.template(
          palette: palette(club.palette),
          pattern: pattern(club.pattern),
          icon: icon(club.iconName),
          ratio: ratio,
          size: size,
          borderRadius: borderRadius,
          overlays: overlays,
          key: key,
        );
}
