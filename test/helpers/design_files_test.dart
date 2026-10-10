import 'package:flutter_test/flutter_test.dart';

import 'design_files.dart';

void main() {
  group('T-02 · design_files (kök cwd okuyucuları)', () {
    test('repoFile / readJsonMap depo kökünden okur', () {
      expect(repoFile('pubspec.yaml').existsSync(), isTrue);
      expect(repoFile('design/extracted/registry.json').existsSync(), isTrue);
      final registry = readJsonMap('design/extracted/registry.json');
      expect(registry, contains('screens'));
      expect(readText('pubspec.yaml'), startsWith('name: gu_kulupler'));
    });

    test('parsePatterns: # yorum, boş satır ve kenar boşluğu atlanır', () {
      const text = '''
# başlık yorumu
XYZ-01.demoAccount.*   # gerekçe
  XYZ-01.demoToggle

QQ-07.demoScan.*#bitişik yorum
   # yalnızca yorum
''';
      expect(parsePatterns(text), [
        'XYZ-01.demoAccount.*',
        'XYZ-01.demoToggle',
        'QQ-07.demoScan.*',
      ]);
      expect(parsePatterns(''), isEmpty);
    });

    test('readPatterns: tool kalıp dosyaları', () {
      expect(readPatterns('tool/design_exempt_actions.txt'), hasLength(5));
      expect(
        readPatterns('tool/design_dynamic_actions.txt'),
        isA<List<String>>(),
      );
    });

    test('globToRegExp: * joker, tam eşleşme, nokta kaçışlı', () {
      final re = globToRegExp('XYZ-01.myClub.*');
      expect(re.hasMatch('XYZ-01.myClub.c01'), isTrue);
      expect(re.hasMatch('XYZ-01.myClub.'), isTrue);
      expect(re.hasMatch('XYZ-01.myClubX'), isFalse);
      expect(re.hasMatch('XXYZ-01.myClub.c01'), isFalse);
      expect(
        globToRegExp('QQ-*.switchClub').hasMatch('QQ-03.switchClub'),
        isTrue,
      );
      expect(
        globToRegExp('XYZ-01.demoToggle').hasMatch('XYZ-01xdemoToggle'),
        isFalse,
      );
      expect(matchesAnyGlob(['A.*', 'B.x'], 'B.x'), isTrue);
      expect(matchesAnyGlob(const [], 'B.x'), isFalse);
    });

    test('parseEnumDesignTraces: üye → üstündeki kimlik', () {
      const source = '''
/// Başlıktaki `/// Design: QQ-nn` anlatımı iz değildir.
enum QqId {
  /// Design: QQ-01 — Başlık
  qq01,

  /// Design: QQ-X2
  ///
  /// Ek açıklama.
  qqX2('x'),

  /// İzsiz üye.
  qq03;

  String get designId => name;
}
''';
      expect(parseEnumDesignTraces(source), {'qq01': 'QQ-01', 'qqX2': 'QQ-X2'});
      expect(parseEnumDesignTraces('enum A { a, b }'), isEmpty);
    });

    test('pubspecFontFamilies: kök pubspec 2 aile, 4 + 3 yüz', () {
      final families = pubspecFontFamilies(readText('pubspec.yaml'));
      expect(families.keys, ['Montserrat', 'Inter']);
      expect(families['Montserrat'], hasLength(4));
      expect(families['Inter'], hasLength(3));
      for (final asset in families.values.expand((a) => a)) {
        expect(asset, startsWith('assets/fonts/'));
        expect(repoFile(asset).existsSync(), isTrue, reason: asset);
      }
    });

    test('pubspecFontFamilies: girinti dışı sonraki anahtar bloğu bitirir', () {
      const sample = '''
flutter:
  fonts:
    - family: A
      fonts:
        - asset: assets/fonts/A-Regular.ttf
          weight: 400
  assets:
    - assets/fonts/B-Bold.ttf
''';
      expect(pubspecFontFamilies(sample), {
        'A': ['assets/fonts/A-Regular.ttf'],
      });
      expect(
        () => pubspecFontFamilies('flutter:\n  assets: []\n'),
        throwsFormatException,
      );
    });
  });
}
