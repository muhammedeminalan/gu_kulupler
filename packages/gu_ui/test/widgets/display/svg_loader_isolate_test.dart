// SVG yükleyicilerinin isolate'e gönderilebilirliği (cihaz hatası, 2026-10-16).
//
// `SvgLoader` SVG'yi `compute` ile ayrı isolate'te çözer ve yükleyici
// nesnesini oraya gönderir. Yükleyici alanında önbellekli bir `AssetBundle`
// (`CachingAssetBundle` → `SynchronousFuture`) tutarsa gönderim
// "object is unsendable" ile düşer: release / profil derlemede ikonlar,
// illüstrasyonlar ve kapaklar hiç çizilmez (Crashlytics, vector_graphics
// `_loadPicture`). Bu test her gu_ui SVG widget'ının yükleyicisini önbelleği
// dolu bir paketle kurar ve gerçek bir `Isolate.run` ile gönderir.
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_asset_bundle.dart';

Future<void> _expectSendable(WidgetTester tester) async {
  final pictures = tester.widgetList<SvgPicture>(find.byType(SvgPicture));
  expect(pictures, isNotEmpty);
  for (final picture in pictures) {
    final loader = picture.bytesLoader;
    final sent = await tester.runAsync(
      () => Isolate.run(() => loader.runtimeType.toString()),
    );
    expect(sent, isNotNull, reason: '${loader.runtimeType} gönderilemedi');
  }
}

void main() {
  setUp(() async {
    // Paketin dize önbelleğini doldur: `CachingAssetBundle` tamamlanan okumayı
    // `SynchronousFuture` olarak saklar — yükleyici paketi tutarsa gönderilemez.
    await GuTestAssetBundle.instance.loadString(GuIcons.arrowLeft.assetPath);
  });

  test('önkoşul: önbellekli paketi tutan yükleyici gönderilemez', () async {
    final loader = SvgAssetLoader(
      GuIcons.arrowLeft.assetPath,
      assetBundle: GuTestAssetBundle.instance,
    );
    await expectLater(
      Isolate.run(() => loader.runtimeType.toString()),
      throwsArgumentError,
    );
  });

  testWidgets("GuIcon yükleyicisi isolate'e gönderilebilir", (tester) async {
    await tester.pumpApp(const Center(child: GuIcon(GuIcons.arrowLeft)));
    await _expectSendable(tester);
  });

  testWidgets("GuIllustration yükleyicisi isolate'e gönderilebilir", (
    tester,
  ) async {
    await tester.pumpApp(
      const Center(child: GuIllustration(GuIllustrations.emptyClubs)),
    );
    await _expectSendable(tester);
  });

  testWidgets('GuLogo amblem yükleyicisi gönderilebilir', (
    tester,
  ) async {
    await tester.pumpApp(
      const Center(child: GuLogo(size: 40)),
    );
    await _expectSendable(tester);
  });

  testWidgets(
    'GuCover şablon (ikonsuz + ikonlu) yükleyicileri gönderilebilir',
    (
      tester,
    ) async {
      await tester.pumpApp(
        const Column(
          children: [
            GuCover.template(
              palette: GuCoverPalette.red,
              pattern: GuCoverPattern.mountain,
              size: 160,
            ),
            GuCover.template(
              palette: GuCoverPalette.slate,
              pattern: GuCoverPattern.lines,
              icon: GuIcons.camera,
              size: 160,
            ),
          ],
        ),
      );
      await _expectSendable(tester);
    },
  );
}
