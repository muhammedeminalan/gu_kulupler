// T-16 · TestAssetBundle: depo kökündeki varlığı eşzamanlı okur (50 KB üstü
// kapak şablonu dahil), dosyası olmayan anahtarı `rootBundle`'a devreder ve
// `pumpApp` ağacının varsayılan paketidir.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import 'pump_app.dart';
import 'test_asset_bundle.dart';

void main() {
  group('T-16 · TestAssetBundle', () {
    final bundle = TestAssetBundle.instance;

    test('her kapak şablonu eşzamanlı okunur; en az biri 50 KB üstündedir '
        '(`rootBundle` bunu ayrı yalıtımda çözer)', () {
      final patterns = Directory('assets/covers')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.svg'))
          .toList();
      expect(patterns, isNotEmpty);
      expect(
        patterns.any((file) => file.lengthSync() > 50 * 1024),
        isTrue,
        reason: 'büyük şablon kalmadıysa bu paket gereksizdir',
      );
      for (final file in patterns) {
        final key = file.path.replaceAll(r'\', '/');
        final text = bundle.loadString(key);
        expect(text, isA<SynchronousFuture<String>>(), reason: key);
        final bytes = bundle.load(key);
        expect(bytes, isA<SynchronousFuture<ByteData>>(), reason: key);
      }
    });

    test('içerik dosyayla aynıdır ve önbellekten aynı baytlar döner', () async {
      final key = Directory('assets/covers')
          .listSync()
          .whereType<File>()
          .map((file) => file.path.replaceAll(r'\', '/'))
          .firstWhere((path) => path.endsWith('.svg'));
      expect(await bundle.loadString(key), File(key).readAsStringSync());
      expect(identical(await bundle.load(key), await bundle.load(key)), isTrue);
    });

    testWidgets("dosyası olmayan anahtar `rootBundle`'a devredilir", (
      tester,
    ) async {
      // Depo kökünde yoktur; test derlemesi üretir.
      const key = 'AssetManifest.bin';
      expect(File(key).existsSync(), isFalse);
      final data = await tester.runAsync(() => bundle.load(key));
      expect(data, isNotNull);
      expect(data!.lengthInBytes, greaterThan(0));
    });

    testWidgets('`pumpApp` ağacının varsayılan paketidir: kapak tek karede '
        'çizilir', (tester) async {
      await tester.pumpApp(
        const Scaffold(
          body: GuCover.template(
            palette: GuCoverPalette.bordeaux,
            pattern: GuCoverPattern.dots,
          ),
        ),
      );
      final context = tester.element(find.byType(GuCover));
      expect(DefaultAssetBundle.of(context), same(bundle));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
