import 'package:flutter/painting.dart';
import 'package:gu_ui/src/widgets/display/gu_covers.dart';

/// Bir kapak paletinin renkleri (prototip `art.js:4–8 PALETTES`).
final class GuClubPaletteColors {
  const GuClubPaletteColors({
    required this.start,
    required this.middle,
    required this.end,
    required this.ink,
    required this.patternOpacity,
  });

  /// Gradyan durağı `offset 0` (`stops[0]`).
  final Color start;

  /// Gradyan durağı `offset .55` (`stops[1]`).
  final Color middle;

  /// Gradyan durağı `offset 1` (`stops[2]`).
  final Color end;

  /// Kapak üstü çizim/ikon rengi (`ink`).
  final Color ink;

  /// Desen beyazının alfa değeri (`pattern: rgba(255,255,255,a)`).
  final double patternOpacity;
}

/// Kulüp kapak paletleri — renk literallerinin tek kaynağı (PLAN §4.3, §7.3;
/// `docs/token-map.md §2` "Kapak paletleri").
///
/// Değerler `assets/covers` SVG'lerinde gömülüdür; kodda yalnızca palet
/// önizlemesi/çipi gibi varlık dışı kullanımlar buradan okur. Token testi
/// değerleri `art.js` `PALETTES` satırlarından doğrular.
abstract final class GuClubPalettes {
  /// JS-derived · art.js:5 `red` — `#A80824 / #D00A2D / #F3B8C2`, desen .55.
  static const GuClubPaletteColors red = GuClubPaletteColors(
    start: Color(0xFFA80824),
    middle: Color(0xFFD00A2D),
    end: Color(0xFFF3B8C2),
    ink: Color(0xFFFFFFFF),
    patternOpacity: 0.55,
  );

  /// JS-derived · art.js:6 `slate` — `#14213A / #1D293D / #3F5F8F`, desen .45.
  static const GuClubPaletteColors slate = GuClubPaletteColors(
    start: Color(0xFF14213A),
    middle: Color(0xFF1D293D),
    end: Color(0xFF3F5F8F),
    ink: Color(0xFFFFFFFF),
    patternOpacity: 0.45,
  );

  /// JS-derived · art.js:7 `bordeaux` — `#4A0C19 / #7A1F30 / #D9BC8C`,
  /// desen .5.
  static const GuClubPaletteColors bordeaux = GuClubPaletteColors(
    start: Color(0xFF4A0C19),
    middle: Color(0xFF7A1F30),
    end: Color(0xFFD9BC8C),
    ink: Color(0xFFFFFFFF),
    patternOpacity: 0.5,
  );

  /// [palette] paletinin renkleri.
  static GuClubPaletteColors of(GuCoverPalette palette) => switch (palette) {
    GuCoverPalette.red => red,
    GuCoverPalette.slate => slate,
    GuCoverPalette.bordeaux => bordeaux,
  };
}
