import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/core/firestore_failure_detail.dart';
import 'package:gu_data/src/core/page_request.dart';
import 'package:gu_data/src/core/page_result.dart';
import 'package:gu_data/src/core/role_policy.dart';
import 'package:gu_data/src/models/enums/club_role.dart';
import 'package:gu_data/src/models/enums/membership_status.dart';
import 'package:gu_data/src/models/enums/reject_reason.dart';
import 'package:gu_data/src/models/membership_contact_model.dart';
import 'package:gu_data/src/models/membership_model.dart';
import 'package:gu_data/src/models/user_model.dart';

/// Kulüp üyeliği ve başvurular — `memberships/{clubId}_{userId}` ve
/// `memberships/{id}/private/contact` (PLAN §10.4; rules-spec §3.4,
/// domain-model §5).
///
/// Başvuran / üye tarafı (T-15: başvur, anında katıl, yeniden başvur, isteği
/// iptal et, başvuru notunu düzenle, ayrıl, okumalar), hesap silme (T-29) ve
/// **yönetici geçişleri** (T-30: onay, ret, kararı geri al, çıkar, çıkarmayı
/// geri al, rol, başkanlık devri — M5, M6, M9–M12; sözleşme
/// `docs/plans/T-30.md` §4). Danışman ataması (M13) T-37'dedir.
///
/// **Yönetici geçişleri:** `actorId` oturumdaki yöneticidir; yetki ve
/// hiyerarşiyi Security Rules uygular (başkan > yönetim kurulu > üye;
/// danışman hiçbir yönetici yazımı yapamaz), repository aynı kuralları
/// önceden denetleyip ağ çağrısı yapmadan reddeder. Kararın, sayacın,
/// sayaç işaretçisi yan belgesinin (`clubs/{clubId}/private/counter`),
/// günlük kaydının ve hedefe giden kritik bildirimin **hepsi aynı
/// transaction'dadır**.
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

  /// Hesap silme (M14, T-29): [uid] kullanıcısının ≤
  /// `Limits.accountDeletionChunk` üyeliğini **tek transaction'da**
  /// anonimleştirir (sözleşme `docs/plans/T-29.md` §4 a).
  ///
  /// Her üyelik işlem içinde yeniden okunur ve güncel durumuna göre yazılır:
  /// `active → left` (üye / yönetim kurulunda aynı işlemde
  /// `clubs.memberCount −1`; danışman sayılmaz, sayaç oynamaz),
  /// `pending → cancelled`, diğer durumlar değişmez; hepsinde `applicant`
  /// `Anonymization.applicantPayload` ile değiştirilir ve var olan
  /// `private/contact` belgesi `Anonymization.contactPayload` ile boşaltılır.
  /// Zaten anonimleşmiş ve terminal durumdaki üyelik yazılmaz (idempotent).
  /// `users/{uid}` yazılmaz; `clubs.lastMembershipRef` yazılmaz (CD-137
  /// madde 8q).
  ///
  /// **Etkin başkan** üyeliği `left` yapılmaz (önce devir — M11; Rules da
  /// reddeder): durumu `active` kalır, yalnızca `applicant` ve `private/contact`
  /// anonimleşir, sayaç oynamaz (T-29 güvenlik incelemesi; kulübün devri
  /// W-90). [memberships] [uid]'e ait değilse ya da
  /// `Limits.accountDeletionChunk`'ı aşıyorsa
  /// [FirestoreError.invalidArgument]; boş liste yazmadan başarı döner.
  Future<FirestoreResult<void>> anonymizeChunk({
    required String uid,
    required List<MembershipModel> memberships,
  });

  /// M5 — [userId] başvuranının [clubId] kulübüne bekleyen başvurusunu
  /// [actorId] yöneticisi onaylar (`pending → active`, rol `member`,
  /// `decidedAt` sunucu zamanı, `decidedBy`). Aynı işlemde `memberCount +1`,
  /// sayaç işaretçisi, `application_approved` günlüğü ve başvurana
  /// `application_approved` bildirimi yazılır.
  ///
  /// Hatalar: başvuru `pending` değil ya da yok, başvuranın hesabı silinmiş
  /// (W-89) → [FirestoreError.conflict] (DLG-18, liste yenilenmeli);
  /// [actorId] başvuranın kendisi → [FirestoreError.permissionDenied];
  /// geçersiz kimlik → [FirestoreError.invalidArgument]. Yönetici olmayan
  /// (danışman dahil) aktörü Rules reddeder
  /// ([FirestoreError.permissionDenied]).
  Future<FirestoreResult<void>> approve({
    required String clubId,
    required String userId,
    required String actorId,
  });

  /// M6 — bekleyen başvuruyu [reason] nedeniyle reddeder
  /// (`pending → rejected`; `decidedAt`, `decidedBy`, `rejectReason`,
  /// `rejectNote`, `retryAfter` = şimdi + `Limits.reapplyCooldown`). Aynı
  /// işlemde `application_rejected` günlüğü ve bildirimi yazılır; sayaç
  /// oynamaz.
  ///
  /// Hatalar ([approve] ile aynı); ayrıca [rejectNote]
  /// `Limits.rejectNoteMax`'ı aşarsa [FirestoreError.invalidArgument].
  Future<FirestoreResult<void>> reject({
    required String clubId,
    required String userId,
    required String actorId,
    required RejectReason reason,
    String rejectNote = '',
  });

  /// M12 (a) — [actorId] yöneticisinin kendi verdiği onay / ret kararını
  /// `Limits.managerUndoWindow` (30 sn) içinde geri alır (`active | rejected
  /// → pending`, karar alanları boşalır; onay geri alınırsa aynı işlemde
  /// `memberCount −1` ve sayaç işaretçisi). Günlük ve bildirim yazılmaz;
  /// verilmiş karar bildirimi geri çekilmez (sözleşme §4 d).
  ///
  /// Hatalar: üyelik `active` / `rejected` değil → [FirestoreError.conflict];
  /// kararı başka biri vermiş ya da pencere geçmiş →
  /// [FirestoreError.ruleViolation] (kural kodu yok — TST-X17).
  Future<FirestoreResult<void>> undoDecision({
    required String clubId,
    required String userId,
    required String actorId,
  });

  /// M12 (b) — [actorId] yöneticisinin kendi yaptığı çıkarmayı
  /// `Limits.managerUndoWindow` içinde geri alır (`removed → active`, rol
  /// `member`, karar alanları boşalır; aynı işlemde `memberCount +1` ve
  /// sayaç işaretçisi — TST-47 "Geri al"). Günlük ve bildirim yazılmaz.
  ///
  /// Hatalar ([undoDecision] ile aynı; önceki durum `removed` değilse
  /// [FirestoreError.conflict]).
  Future<FirestoreResult<void>> undoRemoval({
    required String clubId,
    required String userId,
    required String actorId,
  });

  /// M9 — [userId] üyesini [clubId] kulübünden çıkarır (`active → removed`;
  /// `decidedAt`, `decidedBy`, `rejectReason: other`, [rejectNote],
  /// `retryAfter` = şimdi + `Limits.reapplyCooldown`). Aynı işlemde
  /// `memberCount −1`, sayaç işaretçisi, `member_removed` günlüğü ve
  /// çıkarılana `removed_from_club` bildirimi (tercihe bakılmaz) yazılır.
  ///
  /// Hiyerarşi ([RolePolicy.canRemove]): başkan ve süper admin ([actorIsSuper])
  /// `member` ve `board` üyeyi, yönetim kurulu yalnızca `member` üyeyi
  /// çıkarır. Hesabı silinmiş üye de çıkarılabilir (W-89).
  ///
  /// Hatalar: hedef `active` değil → [FirestoreError.conflict]; hedef başkan →
  /// [FirestoreRuleCode.presidentCannotBeRemoved]; hedef danışman ya da
  /// [actorRole] danışman → [FirestoreRuleCode.notMember]; hiyerarşi dışı →
  /// [FirestoreError.permissionDenied]; [userId] == [actorId] ya da
  /// [rejectNote] çok uzun → [FirestoreError.invalidArgument].
  Future<FirestoreResult<void>> remove({
    required String clubId,
    required String userId,
    required String actorId,
    required ClubRole actorRole,
    bool actorIsSuper = false,
    String rejectNote = '',
  });

  /// M10 — [userId] üyesinin rolünü [role] yapar (yalnızca `member` ↔
  /// `board`; başkan ya da süper admin — [RolePolicy.canAssignRole]). Aynı
  /// işlemde `role_changed` günlüğü ve hedefe `role_changed` bildirimi
  /// (tercihe bakılmaz) yazılır; sayaç oynamaz.
  ///
  /// Hatalar: hedef `active` değil → [FirestoreError.conflict]; hedef başkan
  /// → [FirestoreRuleCode.presidentCannotBeRemoved] (başkanın rolü yalnızca
  /// devirle düşer — M11); hedef danışman → [FirestoreRuleCode.notMember]
  /// (danışman M13); [role] `president` / `advisor` ya da
  /// hedefin mevcut rolüyle aynı → [FirestoreError.invalidArgument]; başkan
  /// olmayan aktörü Rules reddeder ([FirestoreError.permissionDenied]).
  Future<FirestoreResult<void>> changeRole({
    required String clubId,
    required String userId,
    required ClubRole role,
    required String actorId,
  });

  /// M11 — başkanlığı [fromUserId] başkanından [toUserId] üyesine devreder
  /// (**tek işlem**: eski başkan `board`, yeni `president`,
  /// `clubs.presidentId = toUserId`, `role_changed` günlüğü, iki üyeye
  /// `role_changed` bildirimi). Kulüp hiçbir an başkansız kalmaz. Aktör
  /// başkanın kendisi ya da süper admindir ([RolePolicy.canTransfer]).
  ///
  /// Hatalar: [fromUserId] etkin başkan değil, [toUserId] etkin `member` /
  /// `board` değil ya da hesabı etkin değil (silinmiş / askıda — W-89) →
  /// [FirestoreError.conflict]; [fromUserId] == [toUserId] →
  /// [FirestoreError.invalidArgument].
  Future<FirestoreResult<void>> transferPresidency({
    required String clubId,
    required String fromUserId,
    required String toUserId,
    required String actorId,
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
