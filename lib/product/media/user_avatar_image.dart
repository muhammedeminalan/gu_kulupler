import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/product/media/post_image_resolver.dart';
import 'package:gu_kulupler/product/media/user_avatar_directory_view_model.dart';

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
///
/// Oturumdaki kullanıcının kendi avatarı her yerde oturumun **güncel**
/// belgesinden çözülür (`SessionState.user`; fotoğraf değişince
/// `refreshUser` ile tazelenir): listelerin okuduğu profil önbelleği
/// (`CachePolicy.userTtl`) eski yolu tutsa da kendi gönderin, yorumun ve üye
/// satırın yeni fotoğrafı hemen gösterir.
extension UserAvatarImageRefX on WidgetRef {
  /// [user]'ın profil fotoğrafı (yalnızca bu yolun sağlayıcısı izlenir).
  /// [displaySize] avatarın çapıdır (dp): fotoğraf bu boyutta çözülür
  /// (1600 piksel kaynak 40 dp satırda tam boy çözülmez).
  ImageProvider? userAvatarImage(UserModel? user, {double? displaySize}) {
    if (user == null) return null;
    final self = _selfAvatar(user.uid);
    final path = self.isSelf ? self.path : _avatarPathOf(user);
    return this.storageImage(path, displaySize: displaySize);
  }

  /// Yalnızca kimliği bilinen kullanıcının ([uid]) profil fotoğrafı —
  /// kullanıcı belgesi elde olmayan satırlar (üyelik `applicant` anlık
  /// görüntüsü, danışman bağı, SHT-25 adayı). Yol
  /// [UserAvatarDirectoryViewModel]'den gelir: aynı karede istenen bütün
  /// kimlikler tek toplu okumada çözülür (satır başına okuma yok). Çözülene
  /// dek, hata ya da fotoğraf yoksa `null` (baş harfler). Yalnızca bu
  /// kimliğin yolu izlenir: başka satırın yolu gelince bu widget yeniden
  /// çizilmez.
  ImageProvider? userAvatarImageOf(String? uid, {double? displaySize}) {
    if (uid == null || uid.isEmpty) return null;
    final self = _selfAvatar(uid);
    if (self.isSelf) {
      return this.storageImage(self.path, displaySize: displaySize);
    }
    final path = watch(
      userAvatarDirectoryViewModelProvider.select((s) => s.avatarPathOf(uid)),
    );
    read(userAvatarDirectoryViewModelProvider.notifier).request([uid]);
    return this.storageImage(path, displaySize: displaySize);
  }

  /// [uid] oturumdaki kullanıcıysa güncel belgesinin avatar yolu. Oturum
  /// sağlayıcısı kurulmamışsa (yalın widget testi) oturum aranmaz.
  ({bool isSelf, String? path}) _selfAvatar(String uid) {
    if (!exists(sessionViewModelProvider)) return (isSelf: false, path: null);
    return watch(
      sessionViewModelProvider.select((s) {
        final me = s.user;
        if (s.uid != uid || me == null) return (isSelf: false, path: null);
        return (isSelf: true, path: _avatarPathOf(me));
      }),
    );
  }
}

/// Silinmiş / anonimleştirilmiş kullanıcının fotoğrafı istenmez.
String? _avatarPathOf(UserModel? user) =>
    user == null || user.isDeleted || user.isAnonymized
    ? null
    : user.avatarPath;
