// T-03 · GuClubPalettes (PLAN §4.3; token-map §2 "Kapak paletleri").
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../helpers/design_sources.dart';

void main() {
  group('T-03 · GuClubPalettes', () {
    test('renkler art.js PALETTES satırlarından (3 palet)', () {
      final art = prototypeJs('art.js');
      for (final palette in GuCoverPalette.values) {
        final m = RegExp(
          "${palette.name}: \\{ id: '${palette.name}', name: \\[[^\\]]*\\], "
          r"stops: \['(#\w+)', '(#\w+)', '(#\w+)'\], ink: '(#\w+)', "
          r"pattern: 'rgba\(255,255,255,([\d.]+)\)' \}",
        ).firstMatch(art);
        expect(m, isNotNull, reason: palette.name);
        final colors = GuClubPalettes.of(palette);
        expect(colors.start.toARGB32(), parseCssColor(m!.group(1)!));
        expect(colors.middle.toARGB32(), parseCssColor(m.group(2)!));
        expect(colors.end.toARGB32(), parseCssColor(m.group(3)!));
        expect(colors.ink.toARGB32(), parseCssColor(m.group(4)!));
        expect(colors.patternOpacity, double.parse(m.group(5)!));
      }
    });

    test('of() her paleti kendi sabitine eşler', () {
      expect(GuClubPalettes.of(GuCoverPalette.red), same(GuClubPalettes.red));
      expect(
        GuClubPalettes.of(GuCoverPalette.slate),
        same(GuClubPalettes.slate),
      );
      expect(
        GuClubPalettes.of(GuCoverPalette.bordeaux),
        same(GuClubPalettes.bordeaux),
      );
    });
  });
}
