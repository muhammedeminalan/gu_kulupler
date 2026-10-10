/// Kapak paleti (`registry.json#palettes`; prototip `art.js:4 PALETTES`).
///
/// gu_data'daki `ClubPalette` ile aynı üyeler; gu_ui gu_data'yı görmediği
/// için ad farklıdır, eşleme `lib/product/widget/club/cover_mapper.dart`
/// (T-16). Renk değerleri: `GuClubPalettes.of`.
enum GuCoverPalette { red, slate, bordeaux }

/// Kapak deseni (`registry.json#patterns`; prototip `art.js:9 PATTERNS`).
enum GuCoverPattern { mountain, lines, dots, waves }

/// Kapak varlık kaydı — `assets/covers` (26 dosya: 12 şablon + 14 demo).
///
/// Çalışma zamanında kapak üretilmez (prototip `coverArtSVG`, `art.js:29`):
/// `GuCover.template` / `GuCover.demo` yalnızca varlık seçer. SVG'lerde
/// `rgba()` yoktur (K-12, HC22).
///
/// CD-26 denetimi (T-03): 26 dosyanın tümünde ikon katmanı gömülüdür —
/// `<g transform="translate(395.2 100.8) scale(12.00)" … opacity=".12">`;
/// 12 şablonda prototip varsayılanı `sparkles`, demo kapaklarda kulübün
/// kendi ikonu.
abstract final class GuCovers {
  static const String _dir = 'assets/covers';

  /// Şablon kapak: `assets/covers/template-<palet>-<desen>.svg`
  /// (3 palet × 4 desen = 12; SHT-31, K-C).
  static String template(GuCoverPalette palette, GuCoverPattern pattern) =>
      '$_dir/template-${palette.name}-${pattern.name}.svg';

  /// Demo kulüp kapağı: `assets/covers/<slug>.svg` ([demoSlugs]).
  static String demo(String slug) => '$_dir/$slug.svg';

  /// 14 demo kulüp kapağının dosya adları (demo tohum verisi; `tool/seed`).
  static const List<String> demoSlugs = [
    'doga-sporlari-ve-dagcilik-kulubu',
    'e-spor-kulubu',
    'fotograf-ve-sinema-kulubu',
    'girisimcilik-ve-i-novasyon-kulubu',
    'gonulluluk-ve-sosyal-sorumluluk-kulubu',
    'havacilik-ve-uzay-teknolojileri-kulubu',
    'kariyer-ve-mezunlar-kulubu',
    'kitap-ve-edebiyat-kulubu',
    'maden-ve-yer-bilimleri-toplulugu',
    'muzik-ve-sahne-sanatlari-kulubu',
    'satranc-ve-zek-oyunlari-kulubu',
    'tiyatro-kulubu',
    'yazilim-ve-yapay-zek-toplulugu',
    'yerel-kultur-ve-halk-oyunlari-kulubu',
  ];

  static final RegExp _bakedIcon = RegExp(
    r'(<g transform="translate\([^"]*\) scale\([^"]*\)"[^>]*opacity="\.12">)'
    r'(.*)(</g>\s*</svg>\s*)$',
    dotAll: true,
  );
  static final RegExp _svgBody = RegExp('<svg[^>]*>(.*)</svg>', dotAll: true);

  /// Şablon SVG'sindeki gömülü ikon katmanını ([templateSvg] sonundaki
  /// `<g … opacity=".12">`, şablonlarda `sparkles`) [iconSvg] ikonunun
  /// çizimleriyle değiştirir (prototip `coverArtSVG(seed, iconName, …)`,
  /// `art.js:29`: kulüp ikonu sağ altta, beyaz, %12). Katman ya da ikon
  /// gövdesi bulunamazsa [templateSvg] aynen döner.
  static String composeTemplate(String templateSvg, String iconSvg) {
    final iconBody = _svgBody.firstMatch(iconSvg)?.group(1);
    final baked = _bakedIcon.firstMatch(templateSvg);
    if (iconBody == null || baked == null) return templateSvg;
    return templateSvg.replaceRange(
      baked.start,
      baked.end,
      '${baked.group(1)}$iconBody${baked.group(3)}',
    );
  }

  /// 12 şablonun varlık anahtarları (palet × desen sırasıyla).
  static List<String> get templateAssets => [
    for (final palette in GuCoverPalette.values)
      for (final pattern in GuCoverPattern.values) template(palette, pattern),
  ];

  /// 14 demo kapağın varlık anahtarları.
  static List<String> get demoAssets => [
    for (final slug in demoSlugs) demo(slug),
  ];

  /// Kayıtlı 26 kapağın tümü (şablonlar + demolar).
  static List<String> get all => [...templateAssets, ...demoAssets];
}

/// Desen varlık kaydı — `assets/patterns/<desen>.svg` (4 dosya).
///
/// Yalnızca kayıt (prototip `patternSVG`, `art.js:104`; Assets sayfası
/// önizlemesi); bileşeni yoktur.
abstract final class GuPatterns {
  /// `assets/patterns/<desen>.svg`.
  static String asset(GuCoverPattern pattern) =>
      'assets/patterns/${pattern.name}.svg';

  /// Kayıtlı 4 desenin tümü.
  static List<String> get all => [
    for (final pattern in GuCoverPattern.values) asset(pattern),
  ];
}
