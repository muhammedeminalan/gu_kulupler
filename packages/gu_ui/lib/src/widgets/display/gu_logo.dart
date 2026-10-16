import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';

/// Logo varlık kaydı — `assets/logo` (PLAN §7.11; K-10).
///
/// Klasördeki diğer dosyalar (`app-icon-1024.svg`, `app-icon-*-1024.png`,
/// `placeholder-emblem@64…512.png`) dışa aktarım / launcher ekleridir;
/// uygulama kodu kullanmaz. `gu-logo.png`
/// (üniversite mührü) kullanıcı kararıyla (2026-10-16) hiçbir yerde
/// çizilmez; dosya depoda kalır, koddan referansı yoktur.
abstract final class GuLogoAssets {
  /// Uygulama amblemi — açık tema (kırmızı çatı + üç nokta; K-10).
  static const String emblem = 'assets/logo/placeholder-emblem.svg';

  /// Uygulama amblemi — koyu tema (K-10).
  static const String emblemDark = 'assets/logo/placeholder-emblem-dark.svg';

  /// Uygulama ikonu kaynağı (launcher üretimi; widget'ta çizilmez).
  static const String appIcon = 'assets/logo/app-icon-1024.png';

  /// Kayıtlı 3 dosyanın tümü.
  static const List<String> all = [emblem, emblemDark, appIcon];
}

/// Logo amblemi (prototip `Logo`, `art.js:63`; `.logo`).
///
/// Yalnızca uygulama amblemini çizer (CD-90): yatay/dikey varyant ve yazı
/// işareti yoktur; "GÜ Kulüpler" yazısı ekranda ayrı `Text`'tir. [size]
/// kare kenardır (`GuSizes.logoSizes`: FED-03 20, AUT-01 72, SET-04 80,
/// SYS-01 96).
///
/// * Kullanıcı kararı 2026-10-16: üniversite mührü (`gu-logo.png`) yerine
///   her yerde amblem SVG'si — açık temada [GuLogoAssets.emblem], koyuda
///   [GuLogoAssets.emblemDark].
/// * [semanticLabel] verilmezse dekoratiftir; verilirse
///   `Semantics(label:, image: true)` (metni çağıran ARB'den verir).
class GuLogo extends StatelessWidget {
  const GuLogo({required this.size, this.semanticLabel, super.key});

  /// Kare kenar (dp).
  final double size;

  /// Erişilebilirlik etiketi; `null` → dekoratif.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final mark = SvgPicture.asset(
      context.gu.isDark ? GuLogoAssets.emblemDark : GuLogoAssets.emblem,
      width: size,
      height: size,
      // `bundle:` verilmez — GuIcon'daki isolate notu (paket yükleyicide durmaz).
      excludeFromSemantics: true,
    );
    final label = semanticLabel;
    if (label == null) return ExcludeSemantics(child: mark);
    return Semantics(label: label, image: true, child: mark);
  }
}
