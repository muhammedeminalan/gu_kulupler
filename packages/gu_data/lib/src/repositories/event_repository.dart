import 'dart:typed_data';

import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/core/media_update_error.dart';
import 'package:gu_data/src/core/page_request.dart';
import 'package:gu_data/src/core/page_result.dart';
import 'package:gu_data/src/models/enums/event_status.dart';
import 'package:gu_data/src/models/event_draft.dart';
import 'package:gu_data/src/models/event_model.dart';

/// Kulüp etkinlikleri — `events/{eventId}` (PLAN §10.4; rules-spec §3.7,
/// domain-model §2.7, §8; sözleşme `docs/plans/T-22.md §6`).
///
/// Etkinliği yalnızca kulüp yönetimi (yönetim kurulu, başkan) oluşturur,
/// düzenler, yayınlar ve iptal eder; danışman ve süper admin salt okur.
/// Durum makinesi: `draft → published → cancelled`; `published → draft`
/// yalnızca kayıtlı yokken (K-F); `cancelled` geri dönmez. **Belge silme
/// yoktur (D-10):** yalnızca taslak [softDeleteEvent] ile kaldırılır,
/// [restoreEvent] ile geri alınır; yayındaki etkinlik [cancel] edilir.
///
/// Sayaçlar (`goingCount`, `waitlistCount`, `attendedCount`) bu arayüzden
/// **yazılmaz** — yalnızca katılım kaydıyla aynı işlemde ±1 değişir
/// (`RsvpRepository`). Bildirim dağıtımı da burada yapılmaz (çağıran yapar —
/// `ManagementRepository`, PLAN §10.5); yayın ve iptalin günlük kaydı
/// (`activity`) ise asıl yazımla **aynı işlemde** yazılır.
///
/// Yetki arayüzde değil Security Rules'ta uygulanır: yetkisiz çağrı
/// [FirestoreError.permissionDenied] döner. Kimlik parametreleri dış girdi
/// sayılır: geçersiz kimlik (boş, `/` içeren)
/// [FirestoreError.invalidArgument] döner. Durum makinesine uymayan geçiş
/// (ör. taslak olmayan etkinliği yayınlamak) [FirestoreError.failedPrecondition]
/// döner.
abstract interface class EventRepository {
  /// [clubId] kulübünde [createdBy] adına [draft] taslağını oluşturur
  /// (MGT-05, CD-47): [create] çağrısının `status: EventStatus.draft` hâlidir.
  ///
  /// Özel kapak akışı: `createDraft` → dönen kimlikle [uploadCover] →
  /// [publish].
  Future<FirestoreResult<EventModel>> createDraft(
    EventDraft draft, {
    required String clubId,
    required String createdBy,
  });

  /// [clubId] kulübünde [createdBy] adına [draft] etkinliğini [status]
  /// durumunda oluşturur ve yazılan modeli döner.
  ///
  /// Tek işlemde (batch) yazılır:
  /// - `events/{yeni kimlik}` — taslaktaki içerik alanları, `clubId`,
  ///   `createdBy`, `status`, `coverSeed` (`FirestoreIds.eventCoverSeed`),
  ///   üç sayaç `0`, temel alanlar; `publishedAt` (sunucu zamanı) yalnızca
  ///   `published` iken. `coverPath`, `cancelReason` yazılmaz;
  /// - yalnızca `status == EventStatus.published` iken: günlük kaydı
  ///   `activity/{clubId}_{createdBy}_event_published_{eventId}`
  ///   (`FirestoreIds.eventActivity`).
  ///
  /// Dönen modelin zaman alanları istemci saatinden yaklaşık değerdir.
  ///
  /// Hatalar:
  /// - [status] `cancelled` ya da taslak alan kurallarına uymuyor →
  ///   [FirestoreError.invalidArgument];
  /// - `published` iken başlangıç geçmişte (`startsAt <= şimdi`) →
  ///   [FirestoreRuleCode.eventEnded];
  /// - yönetici olmayan çağıran, askıdaki / silinmiş kulüp →
  ///   [FirestoreError.permissionDenied] (Rules).
  Future<FirestoreResult<EventModel>> create(
    EventDraft draft, {
    required String clubId,
    required String createdBy,
    required EventStatus status,
  });

  /// [eventId] etkinliğinde [patch] içerik alanlarını değiştirir.
  ///
  /// Transaction: etkinlik okunur → tek güncelleme (verilen alanlar +
  /// `updatedAt`). Sayaçlara ve duruma dokunulmaz.
  ///
  /// Hatalar:
  /// - etkinlik yok ya da silinmiş → [FirestoreError.notFound];
  /// - iptal edilmiş etkinlik → [FirestoreError.failedPrecondition];
  /// - boş yama, sınır dışı alan, değer + `clear…` birlikte, yazım-sonrası
  ///   `endsAt <= startsAt` ya da etkinliğin kendi klasörü dışında
  ///   `coverPath` → [FirestoreError.invalidArgument];
  /// - yayındaki etkinlikte yeni kontenjan kayıtlı sayısından küçük →
  ///   [FirestoreRuleCode.capacityFull] (düzenleme sırasında biri katıldı);
  /// - yayındaki etkinliğin zamanı (`startsAt` / `endsAt`) değişiyor ama
  ///   etkinlik başlamış ya da yeni başlangıç geçmişte →
  ///   [FirestoreRuleCode.eventEnded] (domain-model §2.7 "yayında başlangıç
  ///   gelecekte"; bitmiş etkinliğin katılım / yoklama penceresi yeniden
  ///   açılamaz). Değeri aynı kalan zaman alanı değişiklik sayılmaz.
  Future<FirestoreResult<void>> update(String eventId, EventEditPatch patch);

  /// [eventId] taslağını [actorId] adına yayınlar.
  ///
  /// Transaction: etkinlik okunur → `status: published`, `publishedAt` sunucu
  /// zamanı, `updatedAt`; etkinlik **ilk kez** yayınlanıyorsa (önceki
  /// `publishedAt` boş) aynı işlemde günlük kaydı
  /// `activity/{clubId}_{actorId}_event_published_{eventId}`. Yayından çekilip
  /// yeniden yayınlanan etkinlik ikinci günlük üretmez (kimlik sabittir).
  ///
  /// Hatalar: yok / silinmiş → [FirestoreError.notFound]; taslak değil →
  /// [FirestoreError.failedPrecondition]; başlangıç geçmişte →
  /// [FirestoreRuleCode.eventEnded].
  Future<FirestoreResult<void>> publish(
    String eventId, {
    required String actorId,
  });

  /// Yayındaki [eventId] etkinliğini taslağa çeker (TST-X19).
  ///
  /// Transaction: etkinlik okunur → `status: draft`, `updatedAt`
  /// (`publishedAt` **korunur**: son yayın anı). Kayıtlı varken
  /// (`goingCount != 0`) reddedilir (K-F). Bekleme listesindeki kayıtlar
  /// yerinde kalır.
  ///
  /// Hatalar: yok / silinmiş → [FirestoreError.notFound]; yayında değil →
  /// [FirestoreError.failedPrecondition]; kayıtlı var →
  /// [FirestoreRuleCode.eventHasRegistrations].
  Future<FirestoreResult<void>> unpublish(String eventId);

  /// Yayındaki [eventId] etkinliğini [actorId] adına [reason] nedeniyle iptal
  /// eder (DLG-23). İptal geri alınamaz; katılım kayıtları ve sayaçlar
  /// değişmez (biletler "İptal" görünür).
  ///
  /// Transaction: etkinlik okunur → `status: cancelled`, `cancelReason`
  /// (kırpılmış), `updatedAt` + günlük kaydı
  /// `activity/{clubId}_{actorId}_event_cancelled_{eventId}`.
  ///
  /// Hatalar: [reason] boş ya da `Limits.adminReasonMax` üstü →
  /// [FirestoreError.invalidArgument]; yok / silinmiş →
  /// [FirestoreError.notFound]; yayında değil →
  /// [FirestoreError.failedPrecondition].
  Future<FirestoreResult<void>> cancel(
    String eventId, {
    required String reason,
    required String actorId,
  });

  /// [eventId] etkinliğini [createdBy] adına yeni bir **taslak** olarak
  /// kopyalar (MGT-04 "Kopyala") ve yeni modeli döner.
  ///
  /// Kaynak okunur, sonra [create] ile aynı yazım yapılır: içerik alanları
  /// aynen, başlangıç ve bitiş `Limits.eventCopyShift` (7 gün) ileri, başlık
  /// kaynağın başlığı + [copyTitleSuffix] (toplam `Limits.eventTitleMax`
  /// sınırına sığacak şekilde kaynak başlık kısaltılır). Özel kapak
  /// (`coverPath`) **kopyalanmaz** (yol etkinliğin kendi klasörüne bağlıdır);
  /// şablon palet / desen kopyalanır. Sayaçlar sıfırdır.
  ///
  /// Kaynak yok ya da silinmiş → [FirestoreError.notFound].
  Future<FirestoreResult<EventModel>> duplicate(
    String eventId, {
    required String createdBy,
    required String copyTitleSuffix,
  });

  /// [eventId] etkinliğinde kaydı açar ya da kapatır: tek yazım
  /// (`registrationOpen`, `updatedAt`); önce okuma yapılmaz. İptal edilmiş /
  /// silinmiş etkinlikte Security Rules reddeder
  /// ([FirestoreError.permissionDenied]).
  Future<FirestoreResult<void>> setRegistrationOpen(String eventId, bool open);

  /// [eventId] **taslağını** [actorId] adına kaldırır (DLG-31): belge silinmiş
  /// olarak işaretlenir, yerinde kalır.
  ///
  /// Transaction: etkinlik okunur → soft delete alanları (`isDeleted`,
  /// `deletedAt`, `deletedBy`, `updatedAt`).
  ///
  /// Hatalar: yok ya da zaten silinmiş → [FirestoreError.notFound]; taslak
  /// değil → [FirestoreError.failedPrecondition] (yayındaki etkinlik iptal
  /// edilir).
  Future<FirestoreResult<void>> softDeleteEvent(
    String eventId, {
    required String actorId,
  });

  /// Kaldırılmış [eventId] taslağını geri yükler (TST-45 "Geri al"): tek
  /// yazım, yalnızca silme alanları geri alınır. Security Rules yalnızca
  /// kaldıran yöneticiye (hâlâ yöneticiyken) izin verir.
  Future<FirestoreResult<void>> restoreEvent(String eventId);

  /// [clubId] kulübünün [eventId] etkinliğine özel kapak görseli yükler ve
  /// yüklenen dosyanın Storage yolunu döner (K-C, CD-47).
  ///
  /// Sırayla: (1) [bytes] `events/{eventId}/{yeni dosya adı}` yoluna
  /// (`StoragePaths.eventCover` + `StoragePaths.newFileName`; sabit ad yok),
  /// `customMetadata: {'clubId': clubId, 'uploaderId': uploaderId}` ile
  /// yüklenir — Storage Rules yükleyenin o kulübün etkin yöneticisi olduğunu
  /// ve [uploaderId] değerinin oturumdaki kullanıcı olduğunu doğrular; (2)
  /// `events/{eventId}.coverPath` bu yola çekilir (tek yazım, `updatedAt`
  /// ile). Var olan dosyanın üzerine yazılmaz, eski kapak silinmez (D-10):
  /// kapak değişimi = yeni dosya + `coverPath`.
  ///
  /// [bytes] yeniden kodlanmış görseldir (uygulamanın görsel seçicisinin
  /// çıktısı — CD-135); [contentType] `StoragePaths.extensionByContentType`
  /// anahtarlarından biridir.
  ///
  /// Hatalar:
  /// - ön denetim (dosya gönderilmeden): geçersiz kimlik →
  ///   [MediaDocumentError] ([FirestoreError.invalidArgument]); izinsiz tür →
  ///   [MediaUploadError] (`StorageError.invalidType`); boş bayt →
  ///   `StorageError.noFile`; `Limits.imageMaxBytes` sınırında ya da üstünde
  ///   → `StorageError.sizeLimit`;
  /// - yükleme reddi (yönetici olmayan, askıdaki hesap) →
  ///   [MediaUploadError] (`StorageError.unauthorized`);
  /// - dosya yüklendi ama `coverPath` yazılamadı → [MediaDocumentError]
  ///   (dosya yetim kalır, silinmez; yeniden deneme yeni dosya yükler).
  Future<MediaUpdateResult<String>> uploadCover(
    String eventId,
    Uint8List bytes, {
    required String contentType,
    required String clubId,
    required String uploaderId,
  });

  /// [eventId] etkinliği.
  ///
  /// Okunan belge silinmişse [FirestoreError.notFound] (SYS-04). Security
  /// Rules görünürlüğü uygular: taslağı ve silinmiş taslağı yalnızca kulüp
  /// yönetimi, danışman ve süper admin; `members` görünürlüklü etkinliği
  /// kulübün içini gören okur. Göremeyen çağıran ve var olmayan etkinliği
  /// soran [FirestoreError.permissionDenied] alır (çağıran ikisini de
  /// "bulunamadı" sayar). Security Rules kapalıyken var olmayan belge
  /// [FirestoreError.notFound].
  Future<FirestoreResult<EventModel>> getEvent(String eventId);

  /// Herkese açık yaklaşan etkinlikler (EVT-01), en yakın üstte.
  ///
  /// Sorgu: `visibility == public`, `status ∈ {published, cancelled}`,
  /// `isDeleted == false`, `startsAt >= fromUtc`, `orderBy startsAt ↑`,
  /// `limit Limits.upcomingEventsFetchMax`. Askıdaki kulübün etkinliği
  /// sunucuda süzülmez (çağıran süzer — rules-spec §9.5).
  Future<FirestoreResult<List<EventModel>>> listPublicUpcoming({
    required DateTime fromUtc,
  });

  /// [clubId] kulübünün yalnızca üyelere açık yaklaşan etkinlikleri (EVT-01),
  /// en yakın üstte. Çağıran, üye olunan **her kulüp için ayrı** çağırır ve
  /// sonuçları birleştirir.
  ///
  /// Sorgu: `clubId == clubId`, `visibility == members`,
  /// `status ∈ {published, cancelled}`, `isDeleted == false`,
  /// `startsAt >= fromUtc`, `orderBy startsAt ↑`,
  /// `limit Limits.upcomingEventsFetchMax`. Kulübün içini görmeyen çağıran
  /// [FirestoreError.permissionDenied] alır.
  Future<FirestoreResult<List<EventModel>>> listMembersUpcoming(
    String clubId, {
    required DateTime fromUtc,
  });

  /// [clubId] kulübünün etkinliklerinden bir sayfa, en yeni başlangıç üstte
  /// (CLB-03 etkinlikler sekmesi, MGT-04).
  ///
  /// Security Rules süzgeç değildir; sorgu çağıranın görebildiği kümeyi
  /// **kendisi** sınırlamalıdır:
  /// - [includeDrafts] `true` (kulüp yönetimi, danışman, süper admin):
  ///   `clubId`, `isDeleted == false`, `orderBy startsAt ↓` — taslaklar ve
  ///   her görünürlük dahil;
  /// - varsayılan (kulübün içini gören: üye, süper admin): ek olarak
  ///   `status ∈ {published, cancelled}`;
  /// - [publicOnly] `true` (kulübün üyesi olmayan ziyaretçi): ek olarak
  ///   `visibility == public`.
  ///
  /// [includeDrafts] ve [publicOnly] birlikte verilemez
  /// ([FirestoreError.invalidArgument]). Yetkisinden geniş sorgu yapan
  /// çağıran [FirestoreError.permissionDenied] alır.
  Future<FirestoreResult<PageResult<EventModel>>> listClubEvents(
    String clubId,
    PageRequest page, {
    bool includeDrafts = false,
    bool publicOnly = false,
  });

  /// [eventIds] etkinlikleri, **girdi sırasıyla** (EVT-04: katılım
  /// kayıtlarından).
  ///
  /// Her etkinlik **tekil okumayla** alınır (liste sorgusu değil: görünürlük
  /// kuralı belge başına değerlendirilir), en çok
  /// `RepositoryHelpers.whereInMax` (30) okuma aynı anda. Kimlikler
  /// tekilleştirilir. Çağıranın **göremediği** (taslağa çekilmiş, üyelikten
  /// çıkılan kulübün üyelere özel etkinliği), var olmayan ve silinmiş
  /// etkinlikler sonuçta **yer almaz** (hata sayılmaz). Başka bir hata (ağ,
  /// zaman aşımı) tüm çağrıyı başarısız kılar. Boş liste okuma yapmadan
  /// başarı (boş liste) döner.
  Future<FirestoreResult<List<EventModel>>> getEvents(List<String> eventIds);
}
