import 'package:flutter_test/flutter_test.dart';

import 'design_sources.dart';

void main() {
  group('T-01 · parseCssColor (design_sources)', () {
    test('kısa #RGB biçimi açılır (#fff, #000, #4a5)', () {
      expect(parseCssColor('#fff'), 0xFFFFFFFF);
      expect(parseCssColor('#FFF'), 0xFFFFFFFF);
      expect(parseCssColor('#000'), 0xFF000000);
      expect(parseCssColor('#4a5'), 0xFF44AA55);
    });

    test('#RRGGBB (büyük/küçük harf, çevre boşluğu)', () {
      expect(parseCssColor('#4A5362'), 0xFF4A5362);
      expect(parseCssColor('#2a2f3a'), 0xFF2A2F3A);
      expect(parseCssColor('  #D00A2D '), 0xFFD00A2D);
    });

    test('rgba: AA = round(a × 255)', () {
      expect(parseCssColor('rgba(0,0,0,.28)'), 0x47000000);
      expect(parseCssColor('rgba(16,24,40,.48)'), 0x7A101828);
      expect(parseCssColor('rgba(255,255,255,.12)'), 0x1FFFFFFF);
      expect(parseCssColor('rgba(0, 0, 0, 0.60)'), 0x99000000);
      expect(parseCssColor('rgba(0,0,0,1)'), 0xFF000000);
      expect(parseCssColor('rgba(0,0,0,0)'), 0x00000000);
    });

    test('alfa yuvarlaması: .48 → 0x7A, .12 → 0x1F (round, kesme değil)', () {
      expect(parseCssColor('rgba(0,0,0,.48)') >>> 24, 0x7A);
      expect(parseCssColor('rgba(0,0,0,.12)') >>> 24, 0x1F);
      expect((0.48 * 255).round(), 0x7A);
      expect((0.12 * 255).round(), 0x1F);
    });

    test('geçersiz biçim → FormatException', () {
      for (final bad in [
        'red',
        '#ff',
        '#ffff',
        '#fffff',
        '#gggggg',
        'rgb(0,0,0)',
        'rgba(0,0,0)',
        'var(--text-heading)',
        '',
      ]) {
        expect(() => parseCssColor(bad), throwsFormatException, reason: bad);
      }
    });
  });

  group('T-01 · design_sources okuyucuları', () {
    test('prototypeAppFiles dosyaları okunur ve tekildir', () {
      expect(prototypeAppFiles.toSet(), hasLength(prototypeAppFiles.length));
      for (final f in prototypeAppFiles) {
        expect(prototypeJs(f), isNotEmpty, reason: f);
      }
    });

    test('kök pubspec.yaml okunur (flutter: fonts: bloğu var)', () {
      expect(rootPubspec(), contains('\n  fonts:\n'));
    });
  });
}
