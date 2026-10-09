import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/src/tokens/gu_typography.dart';

import 'design_sources.dart';
import 'test_fonts.dart';

/// Kök `pubspec.yaml` `flutter: fonts:` bloğu → yüz listesi (yaml paketi
/// olmadan; blok, 2 boşluk girintili `fonts:` satırından bir sonraki aynı ya
/// da daha az girintili satıra kadar).
List<TestFontFace> _pubspecFaces(String pubspec) {
  final start = RegExp(r'^  fonts:\s*$', multiLine: true).firstMatch(pubspec);
  expect(start, isNotNull, reason: 'pubspec flutter: fonts: bloğu yok');
  final rest = pubspec.substring(start!.end);
  final end = RegExp(r'^ {0,2}\S', multiLine: true).firstMatch(rest);
  final block = end == null ? rest : rest.substring(0, end.start);
  final faces = <TestFontFace>[];
  String? family;
  final line = RegExp(
    r'^\s*-\s*family:\s*(\S+)\s*$|'
    r'^\s*-\s*asset:\s*assets/fonts/([\w-]+)\.ttf\s*\n\s*weight:\s*(\d+)',
    multiLine: true,
  );
  for (final m in line.allMatches(block)) {
    if (m.group(1) != null) {
      family = m.group(1);
      continue;
    }
    expect(family, isNotNull, reason: 'asset ailesiz: ${m.group(2)}');
    final weight = int.parse(m.group(3)!);
    faces.add((
      family: family!,
      file: m.group(2)!,
      weight: FontWeight.values.firstWhere((w) => w.value == weight),
    ));
  }
  return faces;
}

void main() {
  group('T-01 · test fontları = kök pubspec.yaml fonts: (D-12)', () {
    late List<TestFontFace> faces;

    setUpAll(() => faces = _pubspecFaces(rootPubspec()));

    test('pubspec bloğu 7 yüz (4 Montserrat + 3 Inter)', () {
      expect(faces, hasLength(7));
      expect(faces.map((f) => f.family).toSet(), {
        GuTypography.fontFamilyMontserrat,
        GuTypography.fontFamilyInter,
      });
    });

    test('testFontFaces (flutter_test_config + glif golden) == pubspec', () {
      expect(testFontFaces, faces);
    });

    test('ayrıştırıcı: girinti dışı sonraki anahtar bloğu bitirir', () {
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
      expect(_pubspecFaces(sample), [
        (family: 'A', file: 'A-Regular', weight: FontWeight.w400),
      ]);
    });
  });
}
