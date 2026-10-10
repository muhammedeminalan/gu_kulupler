// T-03 · GuIcons ↔ assets/icons birebirliği (PLAN §7.11; D-13, CD-23).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../helpers/design_sources.dart';
import '../helpers/svg_probe.dart';

/// `assets/icons` altındaki dosya adları (uzantılı).
List<String> _iconFiles() =>
    Directory('$repoRoot/assets/icons')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .toList()
      ..sort();

/// kebab → camelCase, rakam korunur (`share-2` → `share2`).
String _camel(String kebab) => kebab.replaceAllMapped(
  RegExp('-([a-z0-9])'),
  (m) => m.group(1)!.toUpperCase(),
);

void main() {
  group('T-03 · GuIcons ↔ assets/icons parite', () {
    test('130 üye = 130 dosya; iki yön birebir', () {
      final files = _iconFiles();
      expect(GuIcons.values, hasLength(130));
      expect(files, hasLength(130));
      expect(files.every((f) => f.endsWith('.svg')), isTrue);

      final onDisk = files.map((f) => f.substring(0, f.length - 4)).toSet();
      final registered = GuIcons.values.map((i) => i.fileName).toSet();
      expect(registered, hasLength(130), reason: 'yinelenen fileName');
      expect(registered.difference(onDisk), isEmpty, reason: 'dosyası yok');
      expect(onDisk.difference(registered), isEmpty, reason: 'kaydı yok');
    });

    test('sıra registry.json#iconNames ile aynı', () {
      final names = (registry()['iconNames'] as List).cast<String>();
      expect(GuIcons.values.map((i) => i.fileName).toList(), names);
    });

    test('ad kuralı kebab → camelCase; assetPath biçimi', () {
      for (final icon in GuIcons.values) {
        expect(icon.name, _camel(icon.fileName), reason: icon.fileName);
        expect(icon.assetPath, 'assets/icons/${icon.fileName}.svg');
      }
      expect(GuIcons.share2.fileName, 'share-2');
      expect(GuIcons.codeXml.fileName, 'code-xml');
      expect(GuIcons.gamepad2.fileName, 'gamepad-2');
      expect(GuIcons.usersRound.fileName, 'users-round');
      expect(GuIcons.x.assetPath, 'assets/icons/x.svg');
    });

    test('SVG gerçekleri: 24 × 24, stroke #1D293D 1.75, fill none (CD-21)', () {
      for (final icon in GuIcons.values) {
        final svg = File('$repoRoot/${icon.assetPath}').readAsStringSync();
        expect(svg, contains('viewBox="0 0 24 24"'), reason: icon.fileName);
        expect(svg, contains('stroke="#1D293D"'), reason: icon.fileName);
        expect(svg, contains('stroke-width="1.75"'), reason: icon.fileName);
        expect(svg, contains('fill="none"'), reason: icon.fileName);
      }
    });

    testWidgets('130 SVG yüklenir (istisna yok)', (tester) async {
      final failures = await pumpSvgAssets(
        tester,
        GuIcons.values.map((i) => i.assetPath),
      );
      expect(tester.takeException(), isNull);
      expect(failures, isEmpty);
    });
  });
}
