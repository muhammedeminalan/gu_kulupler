import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/core/media_update_error.dart';
import 'package:gu_data/src/core/page_request.dart';
import 'package:gu_data/src/core/page_result.dart';
import 'package:gu_data/src/models/admin_stats.dart';
import 'package:gu_data/src/models/club_create_input.dart';
import 'package:gu_data/src/models/club_identity_patch.dart';
import 'package:gu_data/src/models/club_media_upload.dart';
import 'package:gu_data/src/models/club_model.dart';
import 'package:gu_data/src/models/enums/report_action.dart';
import 'package:gu_data/src/models/enums/report_status.dart';
import 'package:gu_data/src/models/enums/report_target_type.dart';
import 'package:gu_data/src/models/report_model.dart';
import 'package:gu_data/src/models/user_model.dart';
import 'package:gu_data/src/repositories/report_repository.dart';

/// Süper admin (ADM-01…05) yazımlarının ve okumalarının tek kapısı — PLAN
/// §10.4 `AdminRepository`; sözleşme `docs/plans/T-37.md` §4.
///
/// **Yetki yalnızca custom claim'dir** (D-28): Security Rules her dalda
/// `request.auth.token.superadmin == true` ister; claim'siz çağrı hiçbir
/// belgeyi değiştirmez ve [FirestoreError.permissionDenied] döner. Arayüzde
/// gizlemek yetki değildir — repository claim'i denetlemez, Rules uygular.
///
/// **Kompozisyondur:** başkanlık devri `MembershipRepository`
/// (`transferPresidency`, M11), danışman bağlama
/// `MembershipRepository.setAdvisor` (M13), içerik gizleme gönderi / yorum
/// repository'lerinin batch üyeleri, şikayetçi bildirimi
/// `NotificationDispatcher.notifyReportResolved` iledir. Sayaçlar (`memberCount`)
/// ve sayaç işaretçisi yan belgesi (`clubs/{clubId}/private/counter`, W-64 /
/// W-94) asıl yazımla **aynı işlemdedir** (ya hepsi ya hiçbiri).
///
/// Kimlik parametreleri dış girdi sayılır: geçersiz kimlik (boş, `/` içeren)
/// ağ çağrısı yapılmadan [FirestoreError.invalidArgument] döner. Belge silme
/// yoktur (D-10); süper admin kulüp adına gönderi / etkinlik oluşturmaz
/// (domain-model §3).
abstract interface class AdminRepository {
  // ── Kulüp ──────────────────────────────────────────────────────────────

  /// ADM-03 — yeni kulübü [presidentUserId] başkanıyla **tek batch'te**
  /// oluşturur: `clubs/{yeni}` (`memberCount: 1`, `status: active`,
  /// `presidentId`, `createdBy`; [advisor] verilirse `advisor: {name, title,
  /// userId: null}`), başkanın `memberships/{c}_{başkan}` belgesi (`active`,
  /// `president`, [presidentUser]'dan `applicant` anlık görüntüsü,
  /// `decidedAt` / `decidedBy` aktör) ve `private/contact` belgesi
  /// ([presidentEmail]; not boş). Kulüp belgesinde sayaç işaretçisi yoktur;
  /// oluşturmada yan belge de yazılmaz (`presidentId` sayılan üyeliği
  /// gösterir — §4 a).
  ///
  /// Önce `nameLower` eşitlik sorgusu koşulur (CD-63); ad alınmışsa yazmadan
  /// [FirestoreError.alreadyExists]. Başkanın hesabı etkin değilse
  /// (askıda / silinmiş) [FirestoreError.conflict]. Geçersiz alan
  /// [FirestoreError.invalidArgument]. Döner: yazılan kulüp (kimliği dolu).
  /// Logo / kapak dosyası bu çağrıda yüklenmez ([updateClubMedia]).
  Future<FirestoreResult<ClubModel>> createClub(
    ClubCreateInput input, {
    required String presidentUserId,
    required UserModel presidentUser,
    required String presidentEmail,
    AdvisorInput? advisor,
  });

  /// ADM-03 düzenleme — [clubId] kulübünün [patch] alanlarını yazar (+
  /// `updatedAt`). Ad değişiyorsa önce `nameLower` eşitlik sorgusu
  /// (kulübün kendisi hariç) koşulur → alınmışsa [FirestoreError.alreadyExists].
  /// [ClubIdentityPatch.advisor] bağlı hesabı (`advisor.userId`) korur;
  /// hesabı bağlı danışman [ClubIdentityPatch.clearAdvisor] ile kaldırılamaz
  /// → [FirestoreError.failedPrecondition] (önce `setAdvisor(active: false)`).
  /// Boş yama [FirestoreError.invalidArgument]; kulüp yoksa / silinmişse
  /// [FirestoreError.notFound].
  Future<FirestoreResult<void>> updateClubIdentity(
    String clubId,
    ClubIdentityPatch patch,
  );

  /// ADM-03 — [clubId] kulübünün logosunu ve / veya kapağını yükler
  /// (`clubs/{clubId}/{yeni dosya adı}`, `customMetadata: {clubId,
  /// uploaderId}`) ve `logoPath` / `coverPath` alanlarını tek güncellemeyle
  /// yeni yollara çeker. `ManagementRepository.updateClubMedia` ile aynı
  /// sözleşmedir (ön denetim, hata türleri, eski dosya silinmez — D-10);
  /// yalnızca aktör süper admindir (yönetim dalı süper admine kapalıdır —
  /// Q-09). [uploaderId] oturumdaki uid'dir. İkisi de `null` ise yükleme ve
  /// yazım yapılmadan `MediaDocumentError(invalidArgument)`.
  Future<MediaUpdateResult<ClubMediaPaths>> updateClubMedia(
    String clubId, {
    required String uploaderId,
    ClubMediaUpload? logo,
    ClubMediaUpload? cover,
  });

  /// DLG-28 — [clubId] kulübünü askıya alır: tek güncellemede `status:
  /// suspended`, `suspendReason: reason` (`FieldValidators.adminReason`, 1 –
  /// `Limits.adminReasonMax`; geçersizse [FirestoreError.invalidArgument]).
  /// Askıdaki kulüpte gerekçe yeniden yazılabilir (yeniden deneme güvenli).
  Future<FirestoreResult<void>> suspendClub(
    String clubId, {
    required String reason,
  });

  /// DLG-28 / TST-50 — askıdaki [clubId] kulübünü etkinleştirir: `status:
  /// active`, `suspendReason: null`.
  Future<FirestoreResult<void>> activateClub(String clubId);

  /// ADM-03 / SHT-25 — [clubId] kulübünün başkanlığını [toUserId]
  /// kullanıcısına verir (**tek transaction**; eski başkan `board` olur,
  /// `clubs.presidentId`, `role_changed` günlüğü ve iki `role_changed`
  /// bildirimi aynı işlemdedir):
  ///
  /// - hedef etkin `member` / `board` → `MembershipRepository
  ///   .transferPresidency` (M11, sayaç değişmez);
  /// - hedefin üyeliği yok ya da `left` / `cancelled` / `rejected` /
  ///   `removed` → hedef üyelik doğrudan `active` + `president` yazılır
  ///   ([UserModel]'den `applicant`, `private/contact` hedefin hesap
  ///   e-postasıyla), `clubs.memberCount +1` ve `clubs/{c}/private/counter`
  ///   işaretçisi hedefi gösterir (W-94).
  ///
  /// Silinmiş eski başkan (W-90) da `board` olur; üyeliği sonradan M9
  /// (süper admin, MGT-03) ya da `tool/admin/finish_account_deletion.js`
  /// (W-91) ile kapanır.
  ///
  /// Hatalar: hedef zaten başkan → [FirestoreError.invalidArgument]; hedefin
  /// hesabı etkin değil ya da üyeliği `pending` → [FirestoreError.conflict];
  /// hedef danışman → [FirestoreError.ruleViolation]
  /// (`FirestoreFailureDetail.notMember`).
  Future<FirestoreResult<void>> assignPresident({
    required String clubId,
    required String toUserId,
    required String actorId,
  });

  /// M13 — `MembershipRepository.setAdvisor`'a devreder (danışman hesabını
  /// bağlar / bağı kaldırır).
  Future<FirestoreResult<void>> setAdvisor({
    required String clubId,
    required String userId,
    required bool active,
  });

  // ── Şikayet ────────────────────────────────────────────────────────────

  /// ADM-04 / ADM-01 — açık şikayetlerden bir sayfa, en yeni üstte;
  /// [listReports]'un `open` kısayolu. Gruplama (aynı `targetType` +
  /// `targetId`) istemcidedir (`ReportGroup`, T-40).
  Future<FirestoreResult<PageResult<ReportModel>>> listOpenReports(
    PageRequest page,
  );

  /// ADM-04 sekmeleri — [status] durumundaki şikayetlerden bir sayfa
  /// (`createdAt` azalan; indeks `reports (status, createdAt↓)`).
  Future<FirestoreResult<PageResult<ReportModel>>> listReports(
    ReportStatus status,
    PageRequest page,
  );

  /// SHT-26 — [type] / [targetId] hedefinin **açık** şikayetlerinin tamamı
  /// (indeks `reports (targetType, targetId, status)`).
  Future<FirestoreResult<List<ReportModel>>> listReportsForTarget({
    required ReportTargetType type,
    required String targetId,
  });

  /// DLG-29 / SHT-26 / DLG-28 / DLG-30 — aynı hedefin açık şikayet grubunu
  /// [action] ile çözer.
  ///
  /// Grup = hedefin **o anki** açık şikayetleri ([target] verilirse
  /// `listReportsForTarget` ile yeniden okunur; [reportIds] o hedefe ait
  /// olmalıdır, açık olmayanı atlanır). **Tek batch:** her şikayet `status:
  /// resolved`, `action`, `resolvedAt` (sunucu), `resolvedBy: actorId`; [action]
  /// `removed` ise hedef gönderi / yorum gizlenir (`isHidden`, `hiddenBy`,
  /// `hiddenAt` — yalnızca `post` / `comment` hedefi; başka hedefte
  /// [FirestoreError.invalidArgument]); her şikayetçiye bir
  /// `report_resolved` bildirimi (tek olay anahtarı, `refs.reportId` = grup
  /// anahtarı `{targetType}_{targetId}`). Toplam yazım
  /// `Limits.batchMaxWrites`'ı aşarsa parçalanır: ilk parça gizlemeyi taşır.
  ///
  /// [action] `suspended` askıyı **yazmaz**: çağıran önce [suspendUser] /
  /// [suspendClub] (gerekçeli) çağırır, sonra grubu bununla çözer (§4 a).
  /// Açık şikayet kalmadıysa (başka süper admin çözdü) yazmadan
  /// [FirestoreError.conflict].
  Future<FirestoreResult<void>> resolveReports({
    required List<String> reportIds,
    required ReportAction action,
    required String actorId,
    ReportTarget? target,
  });

  // ── Kullanıcı ──────────────────────────────────────────────────────────

  /// DLG-30 — [uid] hesabını askıya alır (**tek batch**, CD-133):
  /// `users/{uid}.status: suspended` + `users/{uid}/private/account
  /// .suspendReason: reason` (`FieldValidators.adminReason`). Gerekçe
  /// `users` belgesine yazılmaz. Silinmiş hesap → [FirestoreError.conflict];
  /// askıdaki hesapta gerekçe yeniden yazılabilir. Oturumdaki süper adminin
  /// kendi hesabı → [FirestoreError.invalidArgument] (Rules da reddeder;
  /// süper adminin askısı claim geri alımıyla yapılır — `tool/admin`).
  Future<FirestoreResult<void>> suspendUser(
    String uid, {
    required String reason,
  });

  /// DLG-30 / TST-52 — askıdaki [uid] hesabını etkinleştirir (tek batch):
  /// `status: active` + `suspendReason: null`. Kendi hesabı →
  /// [FirestoreError.invalidArgument].
  Future<FirestoreResult<void>> activateUser(String uid);

  /// ADM-05 — adı [prefixLower] ile başlayan silinmemiş kullanıcılar
  /// (`nameLower` aralığı, `nameLower` artan; indeks `users (isDeleted,
  /// nameLower)`). [prefixLower] çağıranın `trLower()` çıktısıdır (CD-11);
  /// boş önek ilk sayfayı döndürür.
  Future<FirestoreResult<PageResult<UserModel>>> listUsersByName(
    String prefixLower,
    PageRequest page,
  );

  /// ADM-05 — e-postası [emailLower] ile başlayan kullanıcılar
  /// (`collectionGroup('private')` `emailLower` aralığı, yalnızca süper
  /// admin; yalnızca `users/{uid}/private/account` sonuçları alınır,
  /// üyelik iletişim belgeleri atlanır, uid'ler tekilleştirilir) →
  /// profiller. Silinmiş hesabın e-postası boştur, aramada çıkmaz.
  Future<FirestoreResult<List<UserModel>>> findUserByEmail(String emailLower);

  /// ADM-05 `managers` süzgeci — herhangi bir kulüpte etkin `board` /
  /// `president` üyeliği olan kullanıcıların kimlikleri (tek sorgu).
  Future<FirestoreResult<Set<String>>> listManagerUserIds();

  // ── Genel bakış ────────────────────────────────────────────────────────

  /// ADM-01 KPI'ları — dört `count()` sorgusu ([AdminStats]).
  Future<FirestoreResult<AdminStats>> stats();
}
