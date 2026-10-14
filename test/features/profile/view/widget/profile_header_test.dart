// PRF-01 · ProfileHeader — avatar 96 + kamera rozeti (xs, brand.primary,
// kenarlık 2 bg.canvas), ad, "bölüm · sınıf", süper admin rozeti, "Profili
// düzenle" (sm, outline, pencil), dokunmalar ve anahtarlar çağırandan;
// çözülmüş görsel GuAvatar'a geçer. Referans: screens-profile.js:11.
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/features/profile/view/widget/profile_header.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_l10n.dart';
import '../../profile_test_support.dart';

const Key _avatarKey = ValueKey<String>('avatar');
const Key _editKey = ValueKey<String>('edit');

void main() {
  Future<({List<String> taps})> pump(
    WidgetTester tester, {
    bool isSuperAdmin = false,
    ImageProvider? image,
  }) async {
    final taps = <String>[];
    await tester.pumpApp(
      Padding(
        padding: GuInsets.all16,
        child: ProfileHeader(
          user: kProfileUser,
          avatarImage: image,
          isSuperAdmin: isSuperAdmin,
          onAvatar: () => taps.add('avatar'),
          onEdit: () => taps.add('edit'),
          avatarKey: _avatarKey,
          editKey: _editKey,
        ),
      ),
    );
    return (taps: taps);
  }

  testWidgets('ad, bölüm · sınıf, düzenle düğmesi; rozet yok', (tester) async {
    await pump(tester);
    final l10n = tester.l10n;
    expect(find.text(kProfileUser.name), findsOneWidget);
    expect(
      find.text('Elektrik-Elektronik Mühendisliği · 3. sınıf'),
      findsOneWidget,
    );
    final edit = tester.widget<GuButton>(find.byKey(_editKey));
    expect(edit.label, l10n.profileEdit);
    expect(edit.icon, GuIcons.pencil);
    expect(edit.variant, GuButtonVariant.outline);
    expect(edit.size, GuButtonSize.sm);
    expect(find.byType(GuRoleBadge), findsNothing);
  });

  testWidgets('avatar 96 (baş harfler) + kamera rozeti', (tester) async {
    await pump(tester);
    final colors = tester.element(find.byType(ProfileHeader)).gu.colors;
    final avatar = tester.widget<GuAvatar>(find.byType(GuAvatar));
    expect(avatar.size, 96);
    expect(avatar.initials, 'MK');
    expect(avatar.image, isNull);
    final badge = tester.widget<GuEmblem>(find.byType(GuEmblem));
    expect(badge.icon, GuIcons.camera);
    expect(badge.size, GuEmblemSize.xs);
    expect(badge.iconSize, 14);
    expect(badge.background, colors.brandPrimary);
    expect(badge.borderColor, colors.bgCanvas);
    expect(badge.borderWidth, GuSizes.avatarBadgeBorder);
    expect(
      find.bySemanticsLabel(tester.l10n.profileChangePhoto),
      findsOneWidget,
    );
  });

  testWidgets('süper admin rozeti; çözülmüş görsel avatara geçer', (
    tester,
  ) async {
    final image = MemoryImage(Uint8List(0));
    await pump(tester, isSuperAdmin: true, image: image);
    final badge = tester.widget<GuRoleBadge>(find.byType(GuRoleBadge));
    expect(badge.kind, GuRoleBadgeKind.superadmin);
    expect(badge.label, tester.l10n.roleSuperadmin);
    expect(tester.widget<GuAvatar>(find.byType(GuAvatar)).image, same(image));
  });

  testWidgets('dokunmalar: avatar → onAvatar, düzenle → onEdit', (
    tester,
  ) async {
    final result = await pump(tester);
    await tester.tap(find.byKey(_avatarKey));
    await tester.tap(find.byKey(_editKey));
    expect(result.taps, ['avatar', 'edit']);
  });
}
