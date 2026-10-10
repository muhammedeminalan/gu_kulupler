// T-03 · Varlık kayıtları ↔ kök assets/ birebirliği (PLAN §7.11; D-13,
// CD-23): illüstrasyon 12, kapak 26 (12 şablon + 14 demo), desen 4, logo.
// İkon paritesi: `icons/gu_icons_test.dart`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../helpers/design_sources.dart';
import '../helpers/svg_probe.dart';

/// `assets/<dir>` altındaki dosyaların varlık anahtarları.
Set<String> _keys(String dir) => Directory('$repoRoot/assets/$dir')
    .listSync()
    .whereType<File>()
    .map((f) => 'assets/$dir/${f.uri.pathSegments.last}')
    .toSet();

/// `assets/` altındaki tüm SVG dosyaları (özyinelemeli).
List<File> _allSvgFiles() => Directory('$repoRoot/assets')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.svg'))
    .toList();

void main() {
  group('T-03 · varlık kaydı paritesi', () {
    test('GuIllustrations 12 = assets/illustrations (sıra registry)', () {
      final names = (registry()['illustrations'] as List).cast<String>();
      expect(GuIllustrations.values, hasLength(12));
      expect(GuIllustrations.values.map((i) => i.fileName).toList(), names);
      expect(
        GuIllustrations.values.map((i) => i.assetPath).toSet(),
        _keys('illustrations'),
      );
      expect(
        GuIllustrations.emailVerify.assetPath,
        'assets/illustrations/email-verify.svg',
      );
    });

    test('GuCoverPalette / GuCoverPattern = registry palettes / patterns', () {
      expect(
        GuCoverPalette.values.map((p) => p.name).toList(),
        (registry()['palettes'] as List).cast<String>(),
      );
      expect(
        GuCoverPattern.values.map((p) => p.name).toList(),
        (registry()['patterns'] as Map<String, dynamic>).keys.toList(),
      );
    });

    test('GuCovers 26 = assets/covers (12 şablon + 14 demo)', () {
      expect(GuCovers.templateAssets, hasLength(12));
      expect(GuCovers.demoAssets, hasLength(14));
      expect(GuCovers.all.toSet(), hasLength(26));
      expect(GuCovers.all.toSet(), _keys('covers'));
      expect(
        GuCovers.template(GuCoverPalette.slate, GuCoverPattern.dots),
        'assets/covers/template-slate-dots.svg',
      );
      expect(
        GuCovers.demo('tiyatro-kulubu'),
        'assets/covers/tiyatro-kulubu.svg',
      );
    });

    test('GuPatterns 4 = assets/patterns', () {
      expect(GuPatterns.all, hasLength(4));
      expect(GuPatterns.all.toSet(), _keys('patterns'));
      expect(
        GuPatterns.asset(GuCoverPattern.waves),
        'assets/patterns/waves.svg',
      );
    });

    test('GuLogoAssets 4 dosya ⊂ assets/logo (9 dosya)', () {
      final onDisk = _keys('logo');
      expect(onDisk, hasLength(9));
      expect(GuLogoAssets.all.toSet(), hasLength(4));
      expect(onDisk.containsAll(GuLogoAssets.all), isTrue);
      expect(GuLogoAssets.logo, 'assets/logo/gu-logo.png');
    });

    test('kök pubspec 5 varlık klasörünü kaydeder', () {
      final pubspec = rootPubspec();
      for (final dir in [
        'icons',
        'illustrations',
        'covers',
        'patterns',
        'logo',
      ]) {
        expect(pubspec, contains('    - assets/$dir/\n'), reason: dir);
      }
    });
  });

  group('T-03 · SVG varlıkları yüklenir', () {
    testWidgets('12 illüstrasyon', (tester) async {
      final failures = await pumpSvgAssets(
        tester,
        GuIllustrations.values.map((i) => i.assetPath),
      );
      expect(tester.takeException(), isNull);
      expect(failures, isEmpty);
    });

    testWidgets('26 kapak', (tester) async {
      final failures = await pumpSvgAssets(tester, GuCovers.all);
      expect(tester.takeException(), isNull);
      expect(failures, isEmpty);
    });

    testWidgets('4 desen + 2 yer tutucu amblem', (tester) async {
      final failures = await pumpSvgAssets(tester, [
        ...GuPatterns.all,
        GuLogoAssets.placeholderEmblem,
        GuLogoAssets.placeholderEmblemDark,
      ]);
      expect(tester.takeException(), isNull);
      expect(failures, isEmpty);
    });

    test('hiçbir SVG rgba( içermez (K-12, HC22)', () {
      final files = _allSvgFiles();
      // 130 ikon + 12 illüstrasyon + 26 kapak + 4 desen + 3 logo SVG'si.
      expect(files, hasLength(175));
      final offenders = [
        for (final file in files)
          if (file.readAsStringSync().contains('rgba(')) file.path,
      ];
      expect(offenders, isEmpty);
    });

    test('CD-26: 26 kapağın tümünde ikon katmanı gömülü', () {
      const iconLayer =
          '<g transform="translate(395.2 100.8) scale(12.00)" fill="none" '
          'stroke="#FFFFFF" stroke-width="1.1" stroke-linecap="round" '
          'stroke-linejoin="round" opacity=".12">';
      for (final asset in GuCovers.all) {
        final svg = File('$repoRoot/$asset').readAsStringSync();
        expect(svg, contains(iconLayer), reason: asset);
      }
    });
  });
}
