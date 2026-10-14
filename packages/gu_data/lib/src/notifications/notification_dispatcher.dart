import 'package:cloud_firestore/cloud_firestore.dart' show WriteBatch;
import 'package:equatable/equatable.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/models/enums/club_role.dart';

/// Uygulama içi bildirimlerin üretim kapısı (PLAN §10.5, §15.2–§15.4; CD-36,
/// CD-147; `docs/plans/T-25.md` §6).
///
/// Bildirimi **eylemi yapan repository** üretir (ViewModel değil) ve bunu
/// yalnızca bu arayüz üzerinden yapar. Uygulamalar değiştirilebilirdir:
/// `ClientFanOutDispatcher` (Mod C, istemci yazar), `NoopNotificationDispatcher`
/// ve ileride `ServerSideDispatcher` (Mod F: sunucu tetikleyicisi aynı şemayı
/// yazar, istemci tarafı no-op — CD-147). İki tür üye vardır:
///
/// - **`batch` alan üyeler** — tek alıcılı, **kritik** bildirim: çağıranın
///   asıl yazımıyla (durum geçişi + sayaç + günlük) aynı batch'e **bir**
///   `notifications` belgesi eklenir (ya hepsi ya hiçbiri; Rules olayı
///   `getAfter` ile aynı batch'te arar). Metot commit çağırmaz, ağ çağrısı
///   yapmaz ve **eşzamanlı** çalışır: `commitBatch` gövdesi dönen sonucu
///   bekleyemediği için geçersiz girdi (kimlik, zorunlu referans) dönen
///   sonuca değil, `invalid-argument` kodlu `FirebaseException` olarak
///   **çağrı anında fırlatılır** — `FirestoreService.commitBatch` bunu
///   `FirestoreError.invalidArgument`'a çevirir ve batch'in hiçbir yazımı
///   uygulanmaz (asıl yazım bildirimsiz kesinleşmez — T-25 güvenlik
///   incelemesi).
/// - **`batch` almayan üyeler** — çok alıcılı (fan-out) bildirim: asıl yazım
///   kesinleştikten **sonra**, alıcılar tekilleştirilip
///   `Limits.notificationFanOutChunkSize` boyutlu parçalara bölünür; her
///   parça tek batch'tir, `aborted` / `unavailable` hatası `RetryPolicy` ile
///   yeniden denenir. Başarısız parça çağıranın sonucunu bozmaz; kullanıcıya
///   hata gösterilmez (rules-spec §5). Bu üyeler fırlatmaz.
///
/// **Kimlik (W-49, CD-148):** her çağrı tek bir olaydır ve bir olay anahtarı
/// alır; belge kimliği `{type}_{eventKey}_{recipientId}` olur. Tek seferlik
/// olaylarda anahtar olayın kendi kimliğidir (duyuru → `postId`, iptal →
/// `eventId`, başvuru → `FirestoreIds.applicationEventKey`); tekrarlanabilen
/// olaylarda (yeniden yayın, terfi, karar) çağrı başına rastgele üretilir.
/// Aynı olayın yeniden denemesi aynı belgeye düşer (çift belge yok;
/// kesinleşmiş belgeye ikinci `set` Rules'ta güncelleme sayılır ve
/// `permissionDenied` döner — belge zaten yazılmıştır), olayın tekrarı yeni
/// belge üretir. **Tercih ve sessiz saat** yazarken uygulanmaz: belge tüm
/// alıcılara yazılır, okuyan taraf süzer (`NotificationPreferenceFilter`).
///
/// Her üye [DispatchReport] döner; fan-out hataları istisna olarak sızmaz.
abstract interface class NotificationDispatcher {
  /// `application_received` — [applicantId] başvuranının [clubId] kulübüne
  /// başvurusu, kulübün etkin yöneticilerine (`board` + `president`).
  ///
  /// Başvuru transaction'ı kesinleştikten sonra **başvuranın istemcisinde**
  /// çağrılır (`MembershipRepository.apply`). Alıcıları dağıtıcı çözer
  /// (`RecipientResolver.managersOf` — yönetici üyelikleri her etkin
  /// kullanıcıya açıktır, CD-139). Rules her belgede alıcının yönetici
  /// üyeliğini okuduğundan yazım **alıcı başına ayrı batch**'tir (parça
  /// boyu 1). [sequence] başvurudan sonraki üyelik belgesinin `priorCount`
  /// değeridir (`MembershipModel.priorCount`): olay anahtarı
  /// `FirestoreIds.applicationEventKey(clubId, applicantId, sequence)`,
  /// Rules aynı anahtarı başvuranın `pending` üyeliğinden kurar (bir
  /// başvuru = yönetici başına en çok bir belge — CD-148). `refs`: `clubId`,
  /// `applicantId`.
  Future<FirestoreResult<DispatchReport>> notifyApplicationReceived({
    required String clubId,
    required String applicantId,
    required int sequence,
  });

  /// `application_approved` / `application_rejected` — [approved] kararı
  /// [applicantId] başvuranına; [batch] karar yazımının batch'idir (kritik).
  /// `refs`: `clubId`.
  Future<FirestoreResult<DispatchReport>> notifyApplicationDecided({
    required String clubId,
    required String applicantId,
    required bool approved,
    required WriteBatch batch,
  });

  /// `removed_from_club` — kulüpten çıkarılan [userId] üyesine (tercihe
  /// bakılmaz); [batch] çıkarma yazımının batch'idir (kritik). `refs`:
  /// `clubId`.
  Future<FirestoreResult<DispatchReport>> notifyRemoved({
    required String clubId,
    required String userId,
    required WriteBatch batch,
  });

  /// `role_changed` — rolü [role] olan [userId] üyesine (tercihe bakılmaz);
  /// [batch] rol yazımının batch'idir (kritik; devirde iki çağrı, iki ayrı
  /// olay anahtarı). `refs`: `clubId`, `role`.
  Future<FirestoreResult<DispatchReport>> notifyRoleChanged({
    required String clubId,
    required String userId,
    required ClubRole role,
    required WriteBatch batch,
  });

  /// `announcement` — bildirimli (`posts.pushSent`) [postId] duyurusu
  /// [recipients] alıcılarına (fan-out; çağıran
  /// `RecipientResolver.membersOf(clubId, excludeUserId: yazar)` verir).
  /// `refs`: `clubId`, `postId`.
  Future<FirestoreResult<DispatchReport>> notifyAnnouncement({
    required String postId,
    required String clubId,
    required List<String> recipients,
  });

  /// `event_new` — yayımlanan [eventId] etkinliği [recipients] alıcılarına
  /// (fan-out; çağıran `RecipientResolver.eventNew(...).ids` verir).
  /// `refs`: `clubId`, `eventId`.
  Future<FirestoreResult<DispatchReport>> notifyEventNew({
    required String eventId,
    required String clubId,
    required List<String> recipients,
  });

  /// `event_cancelled` — iptal edilen [eventId] etkinliğinin [recipients]
  /// kayıtlılarına (fan-out; tercihe bakılmaz; çağıran
  /// `RecipientResolver.rsvpUsersOf(..., {going, waitlist})` verir).
  /// `refs`: `clubId`, `eventId`.
  Future<FirestoreResult<DispatchReport>> notifyEventCancelled({
    required String eventId,
    required String clubId,
    required List<String> recipients,
  });

  /// `waitlist_promoted` — bekleme listesinden alınan [userId] kullanıcısına;
  /// [batch] terfi yazımının batch'idir (kritik). `refs`: `clubId`,
  /// `eventId`.
  Future<FirestoreResult<DispatchReport>> notifyWaitlistPromoted({
    required String eventId,
    required String clubId,
    required String userId,
    required WriteBatch batch,
  });

  /// `report_resolved` — [reportGroupKey] grubunun [reporterIds]
  /// şikayetçilerine (alıcı başına bir belge, tek olay anahtarı); [batch]
  /// çözüm yazımının batch'idir (kritik). `refs`: `reportId`.
  Future<FirestoreResult<DispatchReport>> notifyReportResolved({
    required String reportGroupKey,
    required List<String> reporterIds,
    required WriteBatch batch,
  });

  /// `new_report` — [reportId] şikayeti süper adminlere. İstemci dağıtımında
  /// **üretilmez** (süper admin kümesi istemcide bilinemez — CD-37): sonuç
  /// `requested: 0` boş rapordur.
  Future<FirestoreResult<DispatchReport>> notifyNewReport({
    required String reportId,
  });

  /// `system` — [textKey] metni [userIds] kullanıcılarına. Uygulama içi
  /// çağıranı yoktur (Mod C'de yönetim betiği Admin SDK ile yazar); istemci
  /// dağıtımında yazım yapılmaz (`written: 0`; Rules istemciye kapalı).
  Future<FirestoreResult<DispatchReport>> notifySystem({
    required List<String> userIds,
    required String textKey,
  });
}

/// Bir bildirim dağıtımının özeti (PLAN §10.5).
///
/// Başarısız parça kullanıcıya gösterilmez; uygulama katmanı [failedChunks]
/// sıfır değilse günlüğe yazar.
final class DispatchReport extends Equatable {
  /// [requested] alıcıdan [written] tanesine yazıldı; [failedChunks] parça
  /// yeniden denemelere rağmen yazılamadı.
  const DispatchReport({
    required this.requested,
    required this.written,
    required this.failedChunks,
  });

  /// Hedeflenen alıcı sayısı (tekilleştirmeden sonra).
  final int requested;

  /// Bildirimi yazılan (ya da `batch` alan üyelerde batch'e eklenen) alıcı
  /// sayısı.
  final int written;

  /// Yazılamayan parça sayısı.
  final int failedChunks;

  @override
  List<Object?> get props => [requested, written, failedChunks];
}
