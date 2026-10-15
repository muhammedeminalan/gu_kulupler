import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/media/post_image_resolver.dart';

/// Kullanıcının profil fotoğrafı (`users.avatarPath`, `users/{uid}/{file}`)
/// → çizilecek görsel (T-27). Tek yardımcıdır: PRF-01 / PRF-02 başlığı,
/// CLB-07 `UserProfileHeader`, `UserRow` / `MemberRow`, `CommentRow` ve
/// `PostCard` yazar satırı aynı yoldan çözer.
///
/// `null` döner (çağıran baş harfleri çizer): kullanıcı yok, silinmiş ya da
/// anonimleştirilmiş, fotoğraf yok ya da indirme adresi henüz gelmedi
/// (adres gelince yalnızca o yolu izleyen widget yeniden çizilir —
/// [StorageImageRefX.storageImage]). Ortak widget'lar saf kalır: görseli
/// çağıran çözer ve `ImageProvider?` olarak verir.
///
/// Okuma yetkisi Storage Rules'tadır (`users/` — doğrulanmış kullanıcı, tek
/// dosya `get`; D-29: avatar `users/{uid}` ile aynı görünürlüktedir).
extension UserAvatarResolverX on StorageImageResolver {
  /// [user]'ın profil fotoğrafı; yoksa `null`. [coverEdgePx] avatarın
  /// cihaz pikseli çapıdır ([decodePx]).
  ImageProvider? userAvatar(UserModel? user, {int? coverEdgePx}) {
    if (user == null || user.isDeleted || user.isAnonymized) return null;
    return this(user.avatarPath, coverEdgePx: coverEdgePx);
  }
}

/// `build` içinde kısa yol:
/// `UserRow(user: user, avatarImage: ref.userAvatarImage(user,
/// displaySize: GuSizes.avatar))`.
extension UserAvatarImageRefX on WidgetRef {
  /// [user]'ın profil fotoğrafı (yalnızca bu yolun sağlayıcısı izlenir).
  /// [displaySize] avatarın çapıdır (dp): fotoğraf bu boyutta çözülür
  /// (1600 piksel kaynak 40 dp satırda tam boy çözülmez).
  ImageProvider? userAvatarImage(UserModel? user, {double? displaySize}) =>
      this.storageImage(_avatarPathOf(user), displaySize: displaySize);
}

/// Silinmiş / anonimleştirilmiş kullanıcının fotoğrafı istenmez.
String? _avatarPathOf(UserModel? user) =>
    user == null || user.isDeleted || user.isAnonymized
    ? null
    : user.avatarPath;
