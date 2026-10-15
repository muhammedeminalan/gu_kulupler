// T-36 · kulüp logo / kapak çözümü: `clubs.logoPath` / `coverPath` → görsel;
// kulüp yok, silinmiş ya da görsel yüklenmemiş → `null` (şablon kapak /
// ikonlu amblem). `CoverMapper.emblem` ve `ClubCard` görselleri çizer.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/media/club_media_image.dart';
import 'package:gu_kulupler/product/widget/club/club_card.dart';
import 'package:gu_kulupler/product/widget/club/cover_mapper.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fixtures/club_model_fixtures.dart';
import '../../helpers/pump_app.dart';

/// 1 × 1 saydam PNG.
final ImageProvider _image = MemoryImage(
  Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]),
);

const String _logo = 'clubs/c01/20261012T163000Z_0123456789abcdef.png';
const String _cover = 'clubs/c01/20261012T163000Z_fedcba9876543210.png';

void main() {
  final requested = <String?>[];
  ImageProvider? resolve(String? path) {
    requested.add(path);
    return path == null ? null : _image;
  }

  setUp(requested.clear);

  final resolver = resolve;
  final withMedia = ClubModelFixtures.c01.copyWith(
    logoPath: _logo,
    coverPath: _cover,
  );

  test('logolu / kapaklı kulüp → çözücünün görseli (yol alanları)', () {
    expect(resolver.clubLogo(withMedia), same(_image));
    expect(resolver.clubCover(withMedia), same(_image));
    expect(requested, [_logo, _cover]);
  });

  test('kulüp yok, görsel yok ya da silinmiş kulüp → null', () {
    expect(resolver.clubLogo(null), isNull);
    expect(resolver.clubCover(ClubModelFixtures.c01), isNull);
    expect(resolver.clubLogo(withMedia.copyWith(isDeleted: true)), isNull);
    // Silinmiş kulüp için istek atılmaz.
    expect(requested, [null]);
  });

  testWidgets('CoverMapper.emblem: logo varsa kutuyu kaplar, yoksa ikon', (
    tester,
  ) async {
    await tester.pumpApp(
      Row(
        children: [
          CoverMapper.emblem(icon: GuIcons.users, logo: _image),
          CoverMapper.emblem(icon: GuIcons.users),
        ],
      ),
    );
    final emblems = tester.widgetList<GuEmblem>(find.byType(GuEmblem)).toList();
    expect(emblems.first.icon, isNull);
    expect(emblems.last.icon, GuIcons.users);
    final image = tester.widget<Image>(
      find.descendant(
        of: find.byWidget(emblems.first),
        matching: find.byType(Image),
      ),
    );
    expect(image.image, same(_image));
    expect(image.fit, BoxFit.cover);
    expect(
      tester.getSize(find.byWidget(emblems.first)),
      Size.square(GuEmblemSize.sm.dimension),
    );
  });

  testWidgets('ClubCard liste + ızgara: yüklenmiş kapak ve logo çizilir', (
    tester,
  ) async {
    Widget card({required bool grid}) => ClubCard(
      club: withMedia,
      access: ClubAccess.visitor,
      grid: grid,
      coverImage: _image,
      logoImage: _image,
      onOpen: () {},
      onJoin: () {},
      onClosedTap: () {},
      onStatus: () {},
    );
    for (final grid in [false, true]) {
      await tester.pumpApp(
        SingleChildScrollView(
          child: SizedBox(width: 240, child: card(grid: grid)),
        ),
      );
      await tester.pumpAndSettle();
      final cover = tester.widget<GuCover>(find.byType(GuCover));
      expect(cover.image, same(_image), reason: 'grid: $grid');
      final emblem = tester.widget<GuEmblem>(find.byType(GuEmblem));
      expect(emblem.icon, isNull, reason: 'grid: $grid');
      expect(tester.takeException(), isNull);
    }
  });
}
