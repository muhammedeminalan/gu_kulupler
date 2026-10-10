import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/core/soft_delete.dart';

/// Hesap silme (SET-03) anonimleştirme sabitleri ve yükleri (PLAN §9.1, §9.5,
/// §10.4; domain-model §11).
///
/// Hesap silme kişiyi **anonimleştirir**, belgeyi kaldırmaz (D-10, Q-11):
/// kişisel alanlar boşaltılır, `users/{uid}` soft delete edilir. Bu sınıf
/// yalnızca yükleri üretir; yazım sırası, parçalama ve sayaçlar
/// `AccountDeletionRepository` / `MembershipRepository.anonymizeChunk`
/// sorumluluğundadır (T-29). Yükler `update` çağrısına verilir; servis
/// `updatedAt`'i her güncellemede ayrıca ekler.
abstract final class Anonymization {
  /// Anonimleştirilen kullanıcının `users.name` ve `applicant.name` alanlarına
  /// yazılan ad.
  ///
  /// Security Rules'taki hesap silme dalı aynı literal'i bekler
  /// (`name == 'Silinmiş kullanıcı'`; rules-spec §3.1, M14), bu yüzden değer
  /// yerelleştirilmez. Arayüzde gösterilen metin ARB `commonDeletedUser`
  /// anahtarından gelir; bu sabit yalnızca veriye yazılır.
  static const String deletedUserName = 'Silinmiş kullanıcı';

  /// `users/{uid}` anonimleştirme yükü (domain-model §11 adım 3, PLAN §10.4
  /// `markDeleted`).
  ///
  /// `name` → [deletedUserName] (+ küçük harfli kopyası `nameLower`),
  /// `bio` → `''`, `interests` → `[]`, `avatarPath` / `department` / `year` →
  /// `null`, `status` → `'deleted'` ve soft delete alanları
  /// (`SoftDelete.payload(actorId: uid)`: silen kişi hesabın sahibidir).
  /// `avatarSeed`, `staff` ve `profileComplete` alanlarına dokunulmaz.
  ///
  /// [uid] hesabı silinen kullanıcıdır; boş olamaz ([ArgumentError]).
  static Map<String, Object?> userPayload(String uid) => {
    FirestoreFields.name: deletedUserName,
    FirestoreFields.nameLower: _deletedUserNameLower,
    FirestoreFields.bio: '',
    FirestoreFields.interests: <String>[],
    FirestoreFields.avatarPath: null,
    FirestoreFields.department: null,
    FirestoreFields.year: null,
    FirestoreFields.status: _deletedStatus,
    ...SoftDelete.payload(actorId: uid),
  };

  /// `users/{uid}/private/account` anonimleştirme yükü: `email` ve
  /// `emailLower` → `''`, `fcmTokens` → `[]`.
  static Map<String, Object?> accountPayload() => {
    FirestoreFields.email: '',
    FirestoreFields.emailLower: '',
    FirestoreFields.fcmTokens: <Object?>[],
  };

  /// `memberships/{id}/private/contact` anonimleştirme yükü: `email` ve
  /// `emailLower` → `''` (Rules: yalnızca `email == ''` güncellemesi izinli).
  static Map<String, Object?> contactPayload() => {
    FirestoreFields.email: '',
    FirestoreFields.emailLower: '',
  };

  /// `memberships/{id}` belgesindeki başvuran anlık görüntüsünün
  /// anonimleştirme yükü: `applicant` alanı **bütünüyle** değiştirilir —
  /// `name` → [deletedUserName], `department` / `year` → `null`,
  /// `avatarSeed` → `'deleted'` (PLAN §9.6.4, §10.4 `anonymizeChunk`; Rules
  /// M14).
  ///
  /// Anlık görüntü boşaltılır (domain-model §2.4); `avatarSeed` zorunlu ve boş
  /// olamayan bir alan olduğu için sabit değer alır. Bu, [userPayload]'dan
  /// bilinçli olarak farklıdır: `users.avatarSeed`'e dokunulmaz (domain-model
  /// §11 alan listesi ve Rules §3.1 `deleted` dalı onu içermez) — CD-129.
  ///
  /// Üyelik durum geçişi (`active → left`, `pending → cancelled`) ve
  /// `memberCount` bu yükte **yoktur**; çağıran aynı güncellemede ekler.
  static Map<String, Object?> applicantPayload() => {
    FirestoreFields.applicant: <String, Object?>{
      FirestoreFields.name: deletedUserName,
      FirestoreFields.department: null,
      FirestoreFields.year: null,
      FirestoreFields.avatarSeed: _deletedAvatarSeed,
    },
  };

  /// [deletedUserName] değerinin Türkçe küçük harfli kopyası (`nameLower`).
  /// `gu_data` harf dönüşümü yapmaz (CD-11), bu yüzden literal'dir.
  static const String _deletedUserNameLower = 'silinmiş kullanıcı';

  /// `users.status` — `UserStatus.deleted` JSON değeri (enum T-09'da).
  static const String _deletedStatus = 'deleted';

  /// Anonimleştirilen başvuran anlık görüntüsünün avatar tohumu.
  static const String _deletedAvatarSeed = 'deleted';
}
