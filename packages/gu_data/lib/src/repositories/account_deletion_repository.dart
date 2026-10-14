import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/models/account_deletion_plan.dart';
import 'package:gu_data/src/models/membership_model.dart';
import 'package:gu_data/src/models/rsvp_model.dart';

/// Hesap silme (SET-03) — anonimleştirme + soft delete işlem dizisi, parçalı
/// ve yeniden başlatılabilir (PLAN §10.4; domain-model §11; Q-11, D-10;
/// sözleşme `docs/plans/T-29.md` §4).
///
/// **Sıra sabittir:** [precheck] (başkanlık engeli) → kimlik yeniden
/// doğrulama (`AuthRepository.reauthenticate`, çağıranda) → [markDeleted]
/// (`users.status: active → deleted`, profil + `private/account`
/// anonimleştirmesi; tek batch) → [resumeCleanup] (planı güncel durumdan
/// çıkarır; [cancelRsvpChunk] ×m → [cancelUnreadableRsvp] ×u →
/// [anonymizeMembershipChunk] ×k → [softDeletePersonalChunk] ×p). Oturumu kapatmak çağıranın işidir
/// (`SessionViewModel.signOut`); repository oturuma dokunmaz.
///
/// **Yeniden başlatma:** [markDeleted] kesinleştiyse `users.status ==
/// deleted` kalıcıdır; yarıda kalan dizi bir sonraki girişte (oturum
/// çözümü) [resumeCleanup] ile kaldığı yerden sürer. Her adım idempotenttir:
/// tamamlanmış iş [buildPlan]'a girmez, tekrar yazılan değerler aynıdır.
///
/// **Silinmez:** hiçbir belge ve Auth kimliği silinmez (Q-11); gönderi /
/// yorum içerikleri, destek talepleri (CD-151), `settings/{uid}`, geçmiş
/// etkinlik kayıtları (W-80) ve Storage avatar dosyası (D-10) olduğu gibi
/// kalır. Yetki Rules'tadır (rules-spec §3.1, §3.2, §3.4 M14, §3.8, §3.13,
/// §3.14); erişim çağrısı bütçesi `Limits.accountDeletionChunk` ile
/// sınırlıdır (RP06, `firebase/test/budget/account_deletion_result.json`).
abstract interface class AccountDeletionRepository {
  /// Adım 0 — [uid] kullanıcısı bir kulübün etkin başkanı mı?
  ///
  /// `MembershipRepository.listMine(uid, statuses: {active})` içinde
  /// `role == president` olan varsa [DeletionPrecheck.blockedByPresidency]
  /// (TST-X10), yoksa [DeletionPrecheck.ready]. Yazım yapmaz.
  Future<FirestoreResult<DeletionPrecheck>> precheck(String uid);

  /// Adım 1 — tek batch: `users/{uid}` anonimleştirme yükü
  /// (`Anonymization.userPayload`: `status: deleted` + soft delete alanları)
  /// ve `users/{uid}/private/account` (`Anonymization.accountPayload`).
  ///
  /// Yalnızca `status == active` hesapta geçer; zaten `deleted` ise yazmadan
  /// başarı döner (idempotent), `suspended` ise
  /// [FirestoreError.failedPrecondition].
  Future<FirestoreResult<void>> markDeleted(String uid);

  /// Kalan temizlik işlerini **güncel durumdan** çıkarır (yalnızca okuma).
  ///
  /// `users.status == deleted` değilse [FirestoreError.failedPrecondition].
  /// Boş plan = temizlik bitti.
  Future<FirestoreResult<DeletionPlan>> buildPlan(String uid);

  /// ≤ `Limits.accountDeletionChunk` katılım kaydını vazgeçirir: her kayıt
  /// `going | waitlist → cancelled` + etkinliğin `goingCount` /
  /// `waitlistCount` sayacı `−1`, **aynı işlemde** (transaction; kayıt
  /// durumu işlem içinde yeniden okunur, zaten `cancelled` olan atlanır).
  Future<FirestoreResult<void>> cancelRsvpChunk(
    String uid,
    List<RsvpModel> chunk,
  );

  /// Etkinliği okunamayan tek açık kaydı ([DeletionPlan.unreadableRsvps])
  /// etkinliği **okumadan** vazgeçirir: tek batch'te `rsvps/{id}`
  /// `going | waitlist → cancelled` + etkinliğin ilgili sayacı `−1` (sayaç
  /// [rsvp] durumundan seçilir; Rules `canCancelRsvp` okuma izni istemez,
  /// çift `−1`'i reddeder).
  ///
  /// Rules reddi (`permissionDenied` — etkinlik bitmiş: W-80, ya da kayıt
  /// artık açık değil) ve var olmayan etkinlik (`notFound`) **başarı**
  /// sayılır: kayıt olduğu gibi korunur. [rsvp] [uid]'e ait değilse
  /// [FirestoreError.invalidArgument].
  Future<FirestoreResult<void>> cancelUnreadableRsvp(
    String uid,
    RsvpModel rsvp,
  );

  /// ≤ `Limits.accountDeletionChunk` üyeliği anonimleştirir —
  /// `MembershipRepository.anonymizeChunk` (M14) çağrısıdır.
  Future<FirestoreResult<void>> anonymizeMembershipChunk(
    String uid,
    List<MembershipModel> chunk,
  );

  /// ≤ `Limits.batchMaxWrites` kişisel belgeyi tek batch'te soft delete eder
  /// (`SoftDelete.payload(actorId: uid)`; zaten silinmiş belge plana
  /// girmez).
  Future<FirestoreResult<void>> softDeletePersonalChunk(
    String uid,
    List<PersonalDocRef> refs,
  );

  /// Adım 2…son — [buildPlan] + sırayla [cancelRsvpChunk],
  /// [cancelUnreadableRsvp], [anonymizeMembershipChunk],
  /// [softDeletePersonalChunk]; her kesinleşen parçada [onProgress].
  ///
  /// **En iyi çaba, bağımsız parçalar** (T-29 güvenlik incelemesi): geçici
  /// hata (`aborted` / `unavailable`) parça başına `RetryPolicy` ile yeniden
  /// denenir; kalıcı hata veren çok öğeli parça öğe öğe yeniden koşulur (tek
  /// bozuk öğe — ör. kaymış sayaç — diğerlerinin kişisel verisini kilitlemez).
  /// Başarısız parça diziyi **durdurmaz**; dizi sonunda ilk hata döner
  /// (sonraki çağrı planı güncel durumdan yeniden çıkarır). Hem SET-03 akışı
  /// ([markDeleted] sonrası) hem oturum çözümü (`status == deleted` görülen
  /// giriş) bunu çağırır.
  Future<FirestoreResult<void>> resumeCleanup(
    String uid, {
    DeleteProgressCallback? onProgress,
  });
}
