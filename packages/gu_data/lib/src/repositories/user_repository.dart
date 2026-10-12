import 'dart:typed_data';

import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/core/media_update_error.dart';
import 'package:gu_data/src/core/storage_error.dart';
import 'package:gu_data/src/models/user_account_model.dart';
import 'package:gu_data/src/models/user_model.dart';
import 'package:gu_data/src/models/user_profile_patch.dart';

/// Kullanıcı profili ve gizli hesap belgesi (PLAN §10.4; rules-spec §3.1,
/// §3.2).
///
/// `users/{uid}` herkese açık profildir; e-posta ve askı gerekçesi
/// `users/{uid}/private/account` belgesindedir (D-29, CD-133). Kimlik
/// parametreleri dış girdi sayılır: geçersiz kimlik (boş, `/` içeren)
/// [FirestoreError.invalidArgument] döner. Belge silme yoktur (D-10).
abstract interface class UserRepository {
  /// [uid] kullanıcısının profili; belge yoksa başarı `null`.
  ///
  /// **Silinmiş (anonimleştirilmiş) kullanıcı da döner** (`isDeleted`,
  /// `status == deleted`): gönderi/yorum yazarı "Silinmiş kullanıcı" olarak
  /// gösterilir (PLAN §10.3 istisnası). Belge modele çevrilemezse
  /// [FirestoreError.parse].
  Future<FirestoreResult<UserModel?>> getUser(String uid);

  /// [uids] kullanıcılarının profilleri (yorum/üye satırı yazarları).
  ///
  /// Sonuç [uids] sırasındadır; tekrarlar tekilleştirilir, belgesi olmayan
  /// kimlik atlanır, silinmiş kullanıcılar dahildir. Boş liste sorgu
  /// yapmadan boş döner.
  Future<FirestoreResult<List<UserModel>>> getUsers(List<String> uids);

  /// Yeni kullanıcının üç belgesini **tek batch** ile oluşturur:
  /// `users/{uid}` (`status: active`, `profileComplete: false`,
  /// `staff: false`, `interests: []`, `bio: ''`), `users/{uid}/private/account`
  /// (`email`, `emailLower`, `fcmTokens: []`) ve `settings/{uid}`
  /// (`UserSettingsModel.defaults`).
  ///
  /// [email] Auth belirtecindeki adrestir (`AuthUserInfo.email`; Rules
  /// eşitliğini denetler), [nameLower] çağıranın ürettiği Türkçe küçük harfli
  /// addır (CD-11). Çağıran, e-postası **doğrulanmış** oturumdur (Rules
  /// `emailOk()`). Alanlar geçersizse yazmadan
  /// [FirestoreError.invalidArgument]. Yeniden deneme güvenlidir: profil
  /// zaten varsa (ör. zaman aşımına düşen ilk çağrı sonradan işlenmişse)
  /// hiçbir belge değişmez ve sonuç başarıdır; profil yokken gelen ret
  /// (doğrulanmamış oturum) [FirestoreError.permissionDenied] olarak döner.
  Future<FirestoreResult<void>> createProfile({
    required String uid,
    required String email,
    required String name,
    required String nameLower,
    required String avatarSeed,
  });

  /// [uid] profilinin [patch] ile verilen alanlarını günceller (+
  /// `updatedAt`).
  ///
  /// Yalnızca sahibinin değiştirebildiği alanlar yazılabilir (`name`,
  /// `nameLower`, `avatarSeed`, `avatarPath`, `department`, `year`,
  /// `interests`, `bio`, `profileComplete`). `name` ve `nameLower` birlikte
  /// verilmelidir. Boş yama ya da geçersiz alan →
  /// [FirestoreError.invalidArgument]; belge yoksa
  /// [FirestoreError.notFound].
  Future<FirestoreResult<void>> updateProfile(
    String uid,
    UserProfilePatch patch,
  );

  /// [uid] kullanıcısının profil fotoğrafını değiştirir: [bytes] görselini
  /// `users/{uid}/{yeni dosya adı}` yoluna yükler (`StoragePaths.userAvatar` +
  /// `StoragePaths.newFileName`), ardından `users/{uid}.avatarPath` alanını
  /// **tek güncellemeyle** yeni yola çeker ve yolu döndürür.
  ///
  /// [contentType] `image/jpeg`, `image/png` ya da `image/webp` olmalıdır ve
  /// boyut `Limits.imageMaxBytes` sınırının altında kalmalıdır
  /// ([StorageError.invalidType], [StorageError.sizeLimit],
  /// [StorageError.noFile] — dosya gönderilmeden döner). Eski dosya silinmez
  /// ve üzerine yazılmaz (D-10); her çağrı yeni bir dosya adı üretir.
  /// [onProgress] yükleme sürerken `0.0–1.0` arası oranla çağrılır.
  ///
  /// **Çağrı kısıtı (W-57; rules-spec §3.1 U):** sahibinin her profil
  /// güncellemesi birleşmiş belgede en az bir ilgi alanı ister (personel
  /// hariç). Bu yüzden metot yalnızca iki biçimde çağrılır:
  ///
  /// - **Tamamlanmış profilde** ([profile] verilmeden — PRF-02): yalnızca
  ///   `avatarPath` yazılır. Profil henüz tamamlanmadıysa (ilgi alanı yok)
  ///   yükleme **yapılmadan** [FirestoreError.failedPrecondition], profil
  ///   belgesi yoksa [FirestoreError.notFound] döner.
  /// - **Profil yamasıyla birlikte** ([profile] — AUT-05): ad, bölüm, sınıf,
  ///   ilgi alanları ve `profileComplete` `avatarPath` ile **aynı
  ///   güncellemede** yazılır; ayrıca `updateProfile` çağrılmaz. [profile]
  ///   `avatarPath` / `clearAvatarPath` taşıyamaz ve `updateProfile`
  ///   kurallarıyla doğrulanır ([FirestoreError.invalidArgument]).
  ///
  /// Hata hangi adımdaysa onu taşır: yükleme [MediaUploadError], kimlik /
  /// yama / ön koşul / yazım [MediaDocumentError]. Yazım adımı başarısızsa
  /// yüklenen dosya yerinde kalır ve `avatarPath` eski değerindedir; yeniden
  /// deneme güvenlidir.
  Future<MediaUpdateResult<String>> updateAvatar(
    String uid, {
    required Uint8List bytes,
    required String contentType,
    UserProfilePatch? profile,
    void Function(double fraction)? onProgress,
  });

  /// [uid] kullanıcısının gizli hesap belgesi (e-posta, askı gerekçesi —
  /// CD-133); belge yoksa başarı `null`. Yalnızca hesabın sahibi ya da süper
  /// admin okuyabilir; başkası [FirestoreError.permissionDenied] alır.
  Future<FirestoreResult<UserAccountModel?>> getPrivateAccount(String uid);

  /// [uid] hesabının `lastLoginAt` alanını sunucu zamanına çeker (+
  /// `updatedAt`); başka alana dokunmaz.
  Future<FirestoreResult<void>> touchLastLogin(String uid);
}
