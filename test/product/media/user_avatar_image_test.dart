// T-27 · profil fotoğrafı çözümü: `users.avatarPath` → görsel; silinmiş /
// anonimleştirilmiş kullanıcı ya da fotoğrafsız kullanıcı → `null` (baş
// harfler). `UserRow` görseli avatara geçirir.
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/media/user_avatar_image.dart';
import 'package:gu_kulupler/product/widget/member/user_row.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fixtures/user_model_fixtures.dart';
import '../../helpers/pump_app.dart';

final ImageProvider _image = MemoryImage(Uint8List(0));

void main() {
  final requested = <String?>[];
  ImageProvider? resolve(String? path) {
    requested.add(path);
    return path == null ? null : _image;
  }

  setUp(requested.clear);

  final resolver = resolve;
  final withPhoto = UserModelFixtures.ayse.copyWith(
    avatarPath: 'users/u_ayse/a.jpg',
  );

  test('fotoğraflı kullanıcı → çözücünün görseli (avatarPath yolu)', () {
    expect(resolver.userAvatar(withPhoto), same(_image));
    expect(requested, ['users/u_ayse/a.jpg']);
  });

  test('kullanıcı yok, fotoğraf yok, silinmiş ya da anonim → null', () {
    expect(resolver.userAvatar(null), isNull);
    expect(resolver.userAvatar(UserModelFixtures.ayse), isNull);
    expect(resolver.userAvatar(withPhoto.copyWith(isDeleted: true)), isNull);
    expect(
      resolver.userAvatar(withPhoto.copyWith(status: UserStatus.deleted)),
      isNull,
    );
    // Silinmiş / anonim kullanıcı için istek de atılmaz.
    expect(requested, [null]);
  });

  testWidgets('UserRow görseli avatara geçirir; yoksa baş harfler', (
    tester,
  ) async {
    await tester.pumpApp(
      Column(
        children: [
          UserRow(user: withPhoto, avatarImage: _image),
          UserRow(user: UserModelFixtures.ayse),
        ],
      ),
    );
    final avatars = tester.widgetList<GuAvatar>(find.byType(GuAvatar));
    expect(avatars.map((avatar) => avatar.image), [same(_image), isNull]);
  });
}
