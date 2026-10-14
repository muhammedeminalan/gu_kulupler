import 'package:gu_data/src/constants/limits.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/models/notification_model.dart';

/// Uygulama içi bildirimler — `notifications/{id}` (PLAN §10.4; rules-spec
/// §3.9, domain-model §2.9, §6; `docs/plans/T-25.md` §6).
///
/// **Okuma / güncelleme yalnızca sahibine** (`userId == uid`) açıktır:
/// gelen kutusu, okundu işareti, kaydırarak silme (soft delete) ve "Geri al"
/// (restore). **Belge silme yoktur (D-10).** Tercih ve sessiz saat süzgeci
/// burada değil, okuyan tarafta (`NotificationPreferenceFilter`, ViewModel)
/// uygulanır; okunmamış sayısı da aynı akıştan ViewModel'de sayılır (ayrı
/// dinleyici yok — PLAN §10.6).
///
/// **Yazım** iki yoldandır: cihaz kendi hatırlatıcı belgesini [createSelf]
/// ile yazar (CD-44); başkası için yazım yalnızca dağıtıcının yazma
/// kapısındadır (`NotificationWriter` — `addToBatch`, `createMany`,
/// `newEventKey`; Firebase SDK tipi taşıdığı için bu arayüzde değildir,
/// CD-06 / B08). `FirebaseNotificationRepository` ikisini birden uygular.
/// Belge kimliği `FirestoreIds.notification(type, eventKey, recipientId)`
/// olur; metin yazılmaz. Yetki arayüzde değil Security Rules'ta uygulanır: yetkisiz
/// çağrı [FirestoreError.permissionDenied] döner. Kimlik parametreleri dış
/// girdi sayılır: geçersiz kimlik [FirestoreError.invalidArgument] döner.
abstract interface class NotificationRepository {
  /// [userId] kullanıcısının silinmemiş bildirimlerini en yeni üstte, en çok
  /// [limit] belge olarak **canlı** dinler (NTF-01 listesi + rozet; PLAN
  /// §10.6 dinleyici 2).
  ///
  /// Sorgu `userId == userId ∧ isDeleted == false`, `createdAt` azalan
  /// (indeks `userId ↑, isDeleted ↑, createdAt ↓`). Okunamayan (bozuk)
  /// belge akışı düşürmez, [FirestoreError.parse] olur. Hata olayı akışı
  /// kapatmaz; geçersiz [userId] tek bir [FirestoreError.invalidArgument]
  /// olayı yayar.
  Stream<FirestoreResult<List<NotificationModel>>> watchInbox(
    String userId, {
    int limit = Limits.notificationInboxLimit,
  });

  /// [notificationId] bildirimini okundu işaretler (tek güncelleme
  /// `read: true` + `updatedAt`). Zaten okunmuşsa da başarıdır; okunmamışa
  /// geri döndürme yoktur.
  Future<FirestoreResult<void>> markRead(String notificationId);

  /// [userId] kullanıcısının [unreadIds] bildirimlerini okundu işaretler
  /// (TST-18 "Tümünü okundu say").
  ///
  /// Kimlikler `Limits.batchMaxWrites` boyutlu parçalara bölünür, her parça
  /// tek batch'tir; boş liste yazım yapmadan başarıdır. İlk başarısız parça
  /// hatasıyla döner (önceki parçalar yazılmış kalır — okundu işareti
  /// geri alınmaz, yeniden çağrı güvenlidir).
  Future<FirestoreResult<void>> markAllRead(
    String userId,
    List<String> unreadIds,
  );

  /// [notificationId] bildirimini [actorId] (sahibi) adına soft delete eder
  /// (kaydırarak sil, TST-16).
  Future<FirestoreResult<void>> softDeleteNotification(
    String notificationId, {
    required String actorId,
  });

  /// Soft delete edilmiş [notificationId] bildirimini geri yükler (TST-16
  /// "Geri al"; yalnızca silen sahibi).
  Future<FirestoreResult<void>> restoreNotification(String notificationId);

  /// Cihazın **kendi** [userId]'si için [eventId] etkinliğinin
  /// `event_reminder` belgesini yazar (CD-44; yerel hatırlatıcıya dokunma).
  ///
  /// Kimlik `event_reminder_{eventId}_{userId}`'dir: önce tekil okuma
  /// yapılır, belge varsa (silinmiş olsa da) yazım yapılmadan başarı döner —
  /// aynı hatırlatıcı ikinci belge üretmez. Çağıran sonucu yalnızca
  /// günlüğe yazar (en iyi çaba).
  Future<FirestoreResult<void>> createSelf({
    required String userId,
    required String eventId,
    required String clubId,
  });
}
