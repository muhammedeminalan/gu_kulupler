import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';

/// Logo varlık kaydı — `assets/logo` (PLAN §7.11; K-10).
///
/// Klasördeki diğer dosyalar (`app-icon-1024.svg`, `placeholder-emblem@64…512.png`)
/// dışa aktarım ekleridir; uygulama kodu kullanmaz.
abstract final class GuLogoAssets {
  /// Üniversite logosu (1854 × 1854 PNG; daire kırpılarak çizilir).
  static const String logo = 'assets/logo/gu-logo.png';

  /// Yer tutucu amblem — açık tema (K-10).
  static const String placeholderEmblem = 'assets/logo/placeholder-emblem.svg';

  /// Yer tutucu amblem — koyu tema (K-10).
  static const String placeholderEmblemDark =
      'assets/logo/placeholder-emblem-dark.svg';

  /// Uygulama ikonu kaynağı (launcher üretimi; widget'ta çizilmez).
  static const String appIcon = 'assets/logo/app-icon-1024.png';

  /// Kayıtlı 4 dosyanın tümü.
  static const List<String> all = [
    logo,
    placeholderEmblem,
    placeholderEmblemDark,
    appIcon,
  ];
}

/// Logo amblemi (prototip `Logo`, `art.js:63`; `.logo`).
///
/// Yalnızca amblem çizer (CD-90): yatay/dikey varyant ve yazı işareti
/// yoktur; "GÜ Kulüpler" yazısı ekranda ayrı `Text`'tir. [size] kare
/// kenardır (`GuSizes.logoSizes`: FED-03 20, AUT-01 72, SET-04 80, SYS-01 96).
///
/// * [placeholder] `false` → `gu-logo.png`, daire kırpılmış (`art.js:65`
///   `border-radius:50%`); `true` → yer tutucu amblem SVG'si (K-10; resmî
///   logo geldiğinde yalnızca dosya değişir).
/// * [semanticLabel] verilmezse dekoratiftir; verilirse
///   `Semantics(label:, image: true)` (prototip `alt="Gümüşhane Üniversitesi"`;
///   metni çağıran ARB'den verir).
class GuLogo extends StatelessWidget {
  const GuLogo({
    required this.size,
    this.placeholder = false,
    this.semanticLabel,
    super.key,
  });

  /// Kare kenar (dp).
  final double size;

  /// Yer tutucu amblemi çiz (K-10).
  final bool placeholder;

  /// Erişilebilirlik etiketi; `null` → dekoratif.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final bundle = DefaultAssetBundle.of(context);
    final Widget mark;
    if (placeholder) {
      mark = SvgPicture.asset(
        context.gu.isDark
            ? GuLogoAssets.placeholderEmblemDark
            : GuLogoAssets.placeholderEmblem,
        width: size,
        height: size,
        bundle: bundle,
        excludeFromSemantics: true,
      );
    } else {
      final pixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
      mark = ClipOval(
        child: Image.asset(
          GuLogoAssets.logo,
          width: size,
          height: size,
          fit: BoxFit.cover,
          bundle: bundle,
          // Kaynak 1854 px; hedef piksel boyutunda çözülür (bellek).
          cacheWidth: (size * pixelRatio).round(),
          excludeFromSemantics: true,
        ),
      );
    }
    final label = semanticLabel;
    if (label == null) return ExcludeSemantics(child: mark);
    return Semantics(label: label, image: true, child: mark);
  }
}
