// ClubLookPicker (MGT-09 "Görünüm", ADM-03 logo + kapak): görsel yoksa
// ikonlu amblem + şablon kapak, görsel verilince görsel; iki dokunma hedefi
// etiketli ve geri çağrılı; satır yüksekliği amblem (72). Golden kapsamı
// MGT-09 ve ADM-03 ekran golden'larındadır.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/widget/club/club_look_picker.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_image_picker_service.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';

final Key _logo = GuKey.action('ADM-03.logo');
final Key _cover = GuKey.action('ADM-03.cover');

void main() {
  group('ClubLookPicker', () {
    testWidgets('şablon: amblem ikonu + şablon kapak; dokunmalar ve '
        'etiketler', (tester) async {
      final taps = <String>[];
      await tester.pumpApp(
        Align(
          alignment: Alignment.topCenter,
          child: ClubLookPicker(
            icon: GuIcons.sparkles,
            palette: ClubPalette.red,
            pattern: ClubPattern.mountain,
            logoKey: _logo,
            coverKey: _cover,
            onLogoTap: () => taps.add('logo'),
            onCoverTap: () => taps.add('cover'),
          ),
        ),
      );
      final l10n = tester.l10n;
      expect(find.byType(GuEmblem), findsOneWidget);
      expect(
        tester.widget<GuCover>(find.byType(GuCover)).image,
        isNull,
      );
      expect(
        tester.getSize(find.byKey(_cover)).height,
        GuEmblemSize.lg.dimension,
      );
      expect(find.bySemanticsLabel(l10n.clubSettingsLogo), findsOneWidget);
      expect(find.bySemanticsLabel(l10n.clubSettingsCover), findsOneWidget);

      await tester.tap(find.byKey(_logo));
      await tester.tap(find.byKey(_cover));
      expect(taps, ['logo', 'cover']);
    });

    testWidgets('görsel verilince logo ve kapak görseli çizilir', (
      tester,
    ) async {
      final image = MemoryImage(Uint8List.fromList(kFakeJpeg.bytes));
      await tester.pumpApp(
        ClubLookPicker(
          icon: GuIcons.sparkles,
          palette: ClubPalette.red,
          pattern: ClubPattern.mountain,
          logo: image,
          cover: image,
          logoKey: _logo,
          coverKey: _cover,
          onLogoTap: () {},
          onCoverTap: () {},
        ),
      );
      expect(tester.widget<GuCover>(find.byType(GuCover)).image, image);
      expect(
        find.descendant(of: find.byKey(_logo), matching: find.byType(Image)),
        findsOneWidget,
      );
    });
  });
}
