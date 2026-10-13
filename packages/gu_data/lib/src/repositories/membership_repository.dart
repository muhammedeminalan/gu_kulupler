import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/core/firestore_failure_detail.dart';
import 'package:gu_data/src/core/page_request.dart';
import 'package:gu_data/src/core/page_result.dart';
import 'package:gu_data/src/models/enums/club_role.dart';
import 'package:gu_data/src/models/enums/membership_status.dart';
import 'package:gu_data/src/models/membership_contact_model.dart';
import 'package:gu_data/src/models/membership_model.dart';
import 'package:gu_data/src/models/user_model.dart';

/// Kulüp üyeliği ve başvurular — `memberships/{clubId}_{userId}` ve
/// `memberships/{id}/private/contact` (PLAN §10.4; rules-spec §3.4,
/// domain-model §5).
///
/// Bu sürüm **başvuran / üye tarafını** taşır: başvur, anında katıl, yeniden
/// başvur, isteği iptal et, başvuru notunu düzenle, ayrıl ve okumalar.
/// Yönetici geçişleri (onay, ret, çıkarma, rol, devir) sonraki sürümlerde
/// eklenir.
///
/// **Durum makinesi:** her geçiş bir transaction içinde üyeliğin *beklenen
/// önceki durumunu* okur. Durum tutmuyorsa hiçbir şey yazılmaz ve sonuç
/// [FirestoreError.conflict] olur (liste yenilenmeli); bir iş kuralı
/// reddediyorsa [FirestoreError.ruleViolation] döner ve hangi kural olduğu
/// `FirebaseFailure.detail` içindeki [FirestoreFailureDetail] ile taşınır.
/// Üyelik belgesi, `memberCount` sayacı ve günlük kaydı **aynı işlemde**
/// yazılır (ya hepsi ya hiçbiri).
///
/// **Gizlilik:** e-posta ve başvuru notu üyelik belgesinde değil, yalnızca
/// sahibinin ve kulüp yönetiminin okuduğu `private/contact` belgesindedir
/// (D-29, CD-137). Üyelik hiç silinmez; ayrılma ve iptal birer durum
/// geçişidir (D-10). Kimlik parametreleri dış girdi sayılır: geçersiz kimlik
/// [FirestoreError.invalidArgument] döner.
abstract interface class MembershipRepository {
  /// [uid] kullanıcısının tüm üyelik belgelerini (her durumda) canlı dinler —
  /// oturumun tek üyelik dinleyicisi (PLAN §10.6).
  ///
  /// Hata olayı akışı kapatmaz; geçersiz [uid] tek bir
  /// [FirestoreError.invalidArgument] olayı yayar.
  Stream<FirestoreResult<List<MembershipModel>>> watchMyMemberships(String uid);

  /// [userId] kullanıcısının [clubId] kulübündeki üyelik belgesi; belge yoksa
  /// başarı `null`.
  Future<FirestoreResult<MembershipModel?>> getMembership(
    String clubId,
    String userId,
  );

  /// [applicant] kullanıcısı için [clubId] kulübüne başvuru açar: üyelik
  /// `pending` olur (ilk başvuru ya da yeniden başvuru; yeniden başvuruda
  /// `priorCount` bir artar).
  ///
  /// [email] oturumun e-postasıdır (Rules belirteçle eşitliğini denetler) ve
  /// [note] ile birlikte yalnızca `private/contact` belgesine yazılır. Aynı
  /// işlemde günlüğe `application_received` kaydı düşer; işlem kesinleşince
  /// kulüp yöneticilerine bildirim istenir (bildirim hatası sonucu bozmaz).
  ///
  /// [applicant] başvuranın kimliğini taşır; üyeliğe yazılan profil anlık
  /// görüntüsü (ad, bölüm, sınıf, avatar tohumu) işlem içinde **güncel**
  /// kullanıcı belgesinden okunur — oturumdaki model eski kalmış olsa da
  /// başvuru reddedilmez.
  ///
  /// Dönen modelin zaman alanları istemci saatinden yaklaşık değerdir;
  /// sunucu zamanı bir sonraki okumada gelir.
  ///
  /// Hatalar:
  /// - kulüp ya da başvuranın kullanıcı belgesi yok / kulüp silinmiş →
  ///   [FirestoreError.notFound];
  /// - kulüp askıda ya da başvuruya kapalı →
  ///   [FirestoreRuleCode.applicationsClosed];
  /// - reddedilmiş / çıkarılmış kullanıcının bekleme süresi dolmamış →
  ///   [FirestoreRuleCode.retryCooldown] (`detail.retryAfter` dolu);
  /// - üyelik zaten `pending` / `active`, ya da kulüp artık onaysız katılıma
  ///   açık ([joinInstant] kullanılmalı) → [FirestoreError.conflict].
  ///   İstisna: reddedilmiş / çıkarılmış kullanıcı ve **iptal edilmiş
  ///   başvurunun** sahibi onaysız kulüpte de buradan başvurur (yönetici
  ///   onayına gider);
  /// - kulüp not istiyor ve [note] boş, [note] çok uzun ya da [email]
  ///   geçersiz → [FirestoreError.invalidArgument].
  Future<FirestoreResult<MembershipModel>> apply({
    required String clubId,
    required UserModel applicant,
    required String email,
    required String note,
  });

  /// [applicant] kullanıcısını onay gerektirmeyen [clubId] kulübüne doğrudan
  /// üye yapar: üyelik `active`, rol `member`; aynı işlemde `memberCount`
  /// bir artar ve günlüğe `member_joined` kaydı düşer.
  ///
  /// [email] `private/contact` belgesine yazılır (not boş).
  ///
  /// Hatalar ([apply] ile aynı; farklar):
  /// - reddedilmiş / çıkarılmış kullanıcı anında katılamaz: bekleme süresi
  ///   dolmamışsa [FirestoreRuleCode.retryCooldown], dolmuşsa
  ///   [FirestoreRuleCode.reapplyNeedsReview] ([apply] ile başvurmalı);
  /// - başvurusunu iptal etmiş kullanıcı anında katılamaz →
  ///   [FirestoreRuleCode.reapplyNeedsReview]. İptal edilen başvuru bir
  ///   ret / çıkarma sonrasına ait olabilir; anında katılım yönetici onayını
  ///   dolanmaya yarardı. Kulüpten kendi ayrılan (`left`) üye katılabilir;
  /// - kulüp artık onay istiyor ([apply] kullanılmalı) →
  ///   [FirestoreError.conflict].
  Future<FirestoreResult<MembershipModel>> joinInstant({
    required String clubId,
    required UserModel applicant,
    required String email,
  });

  /// [userId] kullanıcısının [clubId] kulübündeki bekleyen başvurusunu geri
  /// çeker (`pending → cancelled`). Başvuru `pending` değilse (ya da hiç
  /// yoksa) [FirestoreError.conflict].
  Future<FirestoreResult<void>> cancelApplication({
    required String clubId,
    required String userId,
  });

  /// [userId] kullanıcısının [clubId] kulübündeki **bekleyen** başvurusunun
  /// notunu [note] ile değiştirir (CLB-05). Yalnızca `private/contact`
  /// belgesinin `note` alanı yazılır; üyelik belgesine dokunulmaz, sayaç ve
  /// günlük kaydı yoktur (not düzenleme bir üyelik geçişi değildir — CD-137).
  ///
  /// Hatalar:
  /// - başvuru `pending` değil (onaylanmış, reddedilmiş, iptal edilmiş) ya da
  ///   hiç yok → [FirestoreError.conflict];
  /// - kulüp belgesi yok / kulüp silinmiş → [FirestoreError.notFound];
  /// - [note] çok uzun, ya da kulüp not istiyor ve [note] boş →
  ///   [FirestoreError.invalidArgument].
  Future<FirestoreResult<void>> updateApplicationNote({
    required String clubId,
    required String userId,
    required String note,
  });

  /// [userId] üyesini [clubId] kulübünden ayırır (`active → left`); aynı
  /// işlemde `memberCount` bir azalır ve günlüğe `member_left` kaydı düşer.
  ///
  /// Üyelik `active` değilse [FirestoreError.conflict]. Başkan devretmeden
  /// ayrılamaz ([FirestoreRuleCode.presidentCannotLeave]); danışman üye
  /// sayılmaz ve ayrılamaz ([FirestoreRuleCode.notMember]).
  Future<FirestoreResult<void>> leave({
    required String clubId,
    required String userId,
  });

  /// [clubId] kulübünün aktif üyelerinden bir sayfa (CLB-06, MGT-03).
  ///
  /// [role] verilmezse en yeni üye üstte (`appliedAt` azalan); verilirse
  /// yalnızca o roldeki üyeler döner ve sıra belge kimliğine göredir
  /// (rol süzgeçli sorgunun indeksi `appliedAt` taşımaz — rules-spec §8).
  Future<FirestoreResult<PageResult<MembershipModel>>> listActiveMembers(
    String clubId,
    PageRequest page, {
    ClubRole? role,
  });

  /// [clubId] kulübünün yöneticileri (aktif `board` ve `president`
  /// üyelikleri) — `application_received` bildiriminin alıcıları.
  Future<FirestoreResult<List<MembershipModel>>> listManagers(String clubId);

  /// [clubId] kulübünün bekleyen başvurularından bir sayfa, en yeni başvuru
  /// üstte (MGT-02).
  Future<FirestoreResult<PageResult<MembershipModel>>> listPending(
    String clubId,
    PageRequest page,
  );

  /// [uid] kullanıcısının üyelik belgeleri (PRF-03: aktif / bekleyen /
  /// geçmiş). [statuses] verilirse yalnızca o durumlar; boş küme sorgu
  /// yapmadan boş liste döner.
  Future<FirestoreResult<List<MembershipModel>>> listMine(
    String uid, {
    Set<MembershipStatus>? statuses,
  });

  /// [userId] kullanıcısının [clubId] üyeliğine bağlı iletişim belgesi
  /// (e-posta ve başvuru notu); belge yoksa başarı `null`.
  ///
  /// Yalnızca sahibi, kulüp yöneticisi / danışmanı ve süper admin
  /// okuyabilir; başkası için [FirestoreError.permissionDenied].
  Future<FirestoreResult<MembershipContactModel?>> readContact(
    String clubId,
    String userId,
  );
}
