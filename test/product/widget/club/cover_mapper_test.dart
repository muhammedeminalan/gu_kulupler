// T-16 · CoverMapper — gu_data kapak alanları → gu_ui kapak girdileri
// (design-analysis §I; CD-124, K-C): `ClubPalette` → `GuCoverPalette`,
// `ClubPattern` → `GuCoverPattern`, `iconName` → `GuIcons`, kulüp kapağı
// (yüklenmiş görsel ya da şablon + kulüp ikonu).
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/widget/club/cover_mapper.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fixtures/club_model_fixtures.dart';
import '../../../fixtures/demo_data.dart';
import '../../../helpers/pump_app.dart';

/// 1×1 saydam PNG (kapak görseli yerine).
final Uint8List _pixel = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  group('T-16 · CoverMapper · enum eşlemeleri', () {
    test('palet: her `ClubPalette` aynı adlı `GuCoverPalette`e gider; iki '
        'küme birebir', () {
      for (final palette in ClubPalette.values) {
        expect(CoverMapper.palette(palette).name, palette.name);
      }
      expect(
        {
          for (final palette in ClubPalette.values)
            CoverMapper.palette(palette),
        },
        GuCoverPalette.values.toSet(),
      );
    });

    test('desen: her `ClubPattern` aynı adlı `GuCoverPattern`e gider; iki '
        'küme birebir', () {
      for (final pattern in ClubPattern.values) {
        expect(CoverMapper.pattern(pattern).name, pattern.name);
      }
      expect(
        {
          for (final pattern in ClubPattern.values)
            CoverMapper.pattern(pattern),
        },
        GuCoverPattern.values.toSet(),
      );
    });

    test('eşlenen her palet × desen çifti kayıtlı bir şablon varlığıdır', () {
      for (final palette in ClubPalette.values) {
        for (final pattern in ClubPattern.values) {
          expect(
            GuCovers.templateAssets,
            contains(
              GuCovers.template(
                CoverMapper.palette(palette),
                CoverMapper.pattern(pattern),
              ),
            ),
          );
        }
      }
    });
  });

  group('T-16 · CoverMapper · ikon', () {
    test('Lucide adı (kebab-case) ikon kaydına çözülür', () {
      expect(CoverMapper.icon('code-xml'), GuIcons.codeXml);
      expect(CoverMapper.icon('mountain'), GuIcons.mountain);
      expect(CoverMapper.icon('share-2'), GuIcons.share2);
      for (final icon in GuIcons.values) {
        expect(CoverMapper.icon(icon.fileName), icon, reason: icon.fileName);
      }
    });

    test('kayıtta olmayan ad `null`dır (boş, camelCase, bilinmeyen)', () {
      expect(CoverMapper.icon(''), isNull);
      expect(CoverMapper.icon('codeXml'), isNull);
      expect(CoverMapper.icon('not-an-icon'), isNull);
      expect(CoverMapper.icon(' mountain'), isNull);
    });

    test('demo verideki her kulübün ikonu kayıtlıdır', () {
      final ids = DemoDataFixture.ids(FirestoreCollections.clubs);
      expect(ids, isNotEmpty);
      for (final id in ids) {
        final club = ClubModelFixtures.byId(id);
        expect(CoverMapper.icon(club.iconName), isNotNull, reason: id);
      }
    });
  });

  group('T-16 · CoverMapper · kulüp kapağı', () {
    final club = ClubModelFixtures.c01;

    test('görsel yoksa şablon: kulübün paleti × deseni + kulüp ikonu', () {
      final cover = CoverMapper.club(club);
      expect(cover.image, isNull);
      expect(cover.slug, isNull);
      expect(cover.palette, CoverMapper.palette(club.palette));
      expect(cover.pattern, CoverMapper.pattern(club.pattern));
      expect(cover.icon, CoverMapper.icon(club.iconName));
      expect(cover.icon, isNotNull);
      expect(
        cover.assetPath,
        GuCovers.template(
          CoverMapper.palette(club.palette),
          CoverMapper.pattern(club.pattern),
        ),
      );
      expect(cover.ratio, GuCoverRatio.r16x9);
      expect(cover.overlays, isEmpty);
    });

    test('her palet × desen kendi şablonunu seçer', () {
      for (final palette in ClubPalette.values) {
        for (final pattern in ClubPattern.values) {
          final cover = CoverMapper.club(
            club.copyWith(palette: palette, pattern: pattern),
          );
          expect(cover.palette!.name, palette.name);
          expect(cover.pattern!.name, pattern.name);
        }
      }
    });

    test('bilinmeyen ikon adı şablonu kendi ikonuyla bırakır', () {
      final cover = CoverMapper.club(club.copyWith(iconName: 'not-an-icon'));
      expect(cover.icon, isNull);
      expect(cover.palette, isNotNull);
    });

    test('görsel verilirse yüklenmiş kapak çizilir (şablon alanları boş)', () {
      final image = MemoryImage(_pixel);
      final cover = CoverMapper.club(
        club.copyWith(coverPath: 'clubs/c01/cover.jpg'),
        image: image,
      );
      expect(cover.image, same(image));
      expect(cover.palette, isNull);
      expect(cover.pattern, isNull);
      expect(cover.icon, isNull);
      expect(cover.assetPath, isNull);
    });

    test('kapağı olan ama görseli henüz çözülmemiş kulüp şablonla çizilir', () {
      final cover = CoverMapper.club(
        club.copyWith(coverPath: 'clubs/c01/cover.jpg'),
      );
      expect(cover.image, isNull);
      expect(cover.palette, CoverMapper.palette(club.palette));
    });

    test('oran, genişlik, köşe, katmanlar ve anahtar `GuCover`a aynen '
        'geçer', () {
      const overlay = Positioned(left: 0, top: 0, child: SizedBox.shrink());
      const key = ValueKey<String>('cover');
      for (final image in <ImageProvider?>[null, MemoryImage(_pixel)]) {
        final cover = CoverMapper.club(
          club,
          image: image,
          ratio: GuCoverRatio.r3x2,
          size: GuSizes.buttonHeight,
          borderRadius: GuRadius.borderChip,
          overlays: const [overlay],
          key: key,
        );
        expect(cover.ratio, GuCoverRatio.r3x2);
        expect(cover.size, GuSizes.buttonHeight);
        expect(cover.borderRadius, GuRadius.borderChip);
        expect(cover.overlays, [overlay]);
        expect(cover.key, key);
      }
    });

    testWidgets('çizilir: şablon kapak 16:9, taşma ve hata yok', (
      tester,
    ) async {
      await tester.pumpApp(
        Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: CoverMapper.club(club),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final size = tester.getSize(find.byType(GuCover));
      expect(size.width, 390);
      expect(size.height, closeTo(390 * 9 / 16, 0.01));
      expect(tester.takeException(), isNull);
    });
  });
}
