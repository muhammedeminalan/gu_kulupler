// Testlerde yüklenen paketli font yüzleri (PLAN §7.10, D-12).
//
// Tek liste: `flutter_test_config.dart` (FontLoader) ve
// `tokens/gu_fonts_glyph_golden_test.dart` (glif golden'ı) buradan okur;
// `helpers/test_fonts_test.dart` listeyi kök `pubspec.yaml` `flutter: fonts:`
// bloğuyla karşılaştırır.
import 'package:flutter/painting.dart';

/// Paketli bir font yüzü: aile, `assets/fonts/<file>.ttf`, ağırlık.
typedef TestFontFace = ({String family, String file, FontWeight weight});

/// Kök `pubspec.yaml` `flutter: fonts:` sırasıyla 7 yüz: Montserrat
/// 400/500/600/700 + Inter 400/500/600.
const List<TestFontFace> testFontFaces = [
  (family: 'Montserrat', file: 'Montserrat-Regular', weight: FontWeight.w400),
  (family: 'Montserrat', file: 'Montserrat-Medium', weight: FontWeight.w500),
  (family: 'Montserrat', file: 'Montserrat-SemiBold', weight: FontWeight.w600),
  (family: 'Montserrat', file: 'Montserrat-Bold', weight: FontWeight.w700),
  (family: 'Inter', file: 'Inter-Regular', weight: FontWeight.w400),
  (family: 'Inter', file: 'Inter-Medium', weight: FontWeight.w500),
  (family: 'Inter', file: 'Inter-SemiBold', weight: FontWeight.w600),
];
