import 'package:cloud_firestore/cloud_firestore.dart' show WriteBatch;
import 'package:equatable/equatable.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/models/enums/club_role.dart';

/// Uygulama içi bildirimlerin üretim kapısı (PLAN §10.5, §15.2; CD-36).
///
/// Bildirimi **eylemi yapan repository** üretir (ViewModel değil) ve bunu
/// yalnızca bu arayüz üzerinden yapar. İki tür üye vardır:
///
/// - **`batch` alan üyeler** — tek alıcılı, kritik bildirim: çağıranın asıl
///   yazımıyla aynı batch'e eklenir (ya hepsi ya hiçbiri). Metot commit
///   çağırmaz.
/// - **`batch` almayan üyeler** — çok alıcılı (fan-out) bildirim: asıl yazım
///   kesinleştikten **sonra**, parçalı ve en iyi çabayla yazılır. Başarısız
///   parça çağıranın sonucunu bozmaz; kullanıcıya hata gösterilmez.
///
/// Her üye [DispatchReport] döner; hata istisna olarak sızmaz.
abstract interface class NotificationDispatcher {
  /// `application_received` — [clubId] kulübünün yöneticilerine,
  /// [applicantId] başvurdu (fan-out; alıcıları dağıtıcı çözer).
  Future<FirestoreResult<DispatchReport>> notifyApplicationReceived({
    required String clubId,
    required String applicantId,
  });

  /// `application_approved` / `application_rejected` — [applicantId]
  /// başvuranına, [approved] kararı; [batch] karar yazımının batch'idir.
  Future<FirestoreResult<DispatchReport>> notifyApplicationDecided({
    required String clubId,
    required String applicantId,
    required bool approved,
    required WriteBatch batch,
  });

  /// `removed_from_club` — kulüpten çıkarılan [userId] üyesine (tercihe
  /// bakılmaz); [batch] çıkarma yazımının batch'idir.
  Future<FirestoreResult<DispatchReport>> notifyRemoved({
    required String clubId,
    required String userId,
    required WriteBatch batch,
  });

  /// `role_changed` — rolü [role] olan [userId] üyesine (tercihe bakılmaz);
  /// [batch] rol yazımının batch'idir.
  Future<FirestoreResult<DispatchReport>> notifyRoleChanged({
    required String clubId,
    required String userId,
    required ClubRole role,
    required WriteBatch batch,
  });

  /// `announcement` — [postId] duyurusu [recipients] alıcılarına (fan-out).
  Future<FirestoreResult<DispatchReport>> notifyAnnouncement({
    required String postId,
    required String clubId,
    required List<String> recipients,
  });

  /// `event_new` — [eventId] etkinliği [recipients] alıcılarına (fan-out).
  Future<FirestoreResult<DispatchReport>> notifyEventNew({
    required String eventId,
    required String clubId,
    required List<String> recipients,
  });

  /// `event_cancelled` — [eventId] iptali [recipients] kayıtlılarına
  /// (fan-out; tercihe bakılmaz).
  Future<FirestoreResult<DispatchReport>> notifyEventCancelled({
    required String eventId,
    required String clubId,
    required List<String> recipients,
  });

  /// `waitlist_promoted` — bekleme listesinden alınan [userId] kullanıcısına;
  /// [batch] terfi yazımının batch'idir.
  Future<FirestoreResult<DispatchReport>> notifyWaitlistPromoted({
    required String eventId,
    required String clubId,
    required String userId,
    required WriteBatch batch,
  });

  /// `report_resolved` — [reportGroupKey] grubunun [reporterIds]
  /// şikayetçilerine (alıcı başına bir belge); [batch] çözüm yazımının
  /// batch'idir.
  Future<FirestoreResult<DispatchReport>> notifyReportResolved({
    required String reportGroupKey,
    required List<String> reporterIds,
    required WriteBatch batch,
  });

  /// `new_report` — [reportId] şikayeti süper adminlere. İstemci dağıtımında
  /// **üretilmez** (süper admin kümesi istemcide bilinemez — CD-37): sonuç
  /// boş rapordur.
  Future<FirestoreResult<DispatchReport>> notifyNewReport({
    required String reportId,
  });

  /// `system` — [textKey] metni [userIds] kullanıcılarına. Uygulama içi
  /// çağıranı yoktur (yönetim betiği yazar).
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

  /// Hedeflenen alıcı sayısı.
  final int requested;

  /// Bildirimi yazılan alıcı sayısı.
  final int written;

  /// Yazılamayan parça sayısı.
  final int failedChunks;

  @override
  List<Object?> get props => [requested, written, failedChunks];
}
