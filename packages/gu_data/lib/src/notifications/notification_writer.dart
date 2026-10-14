import 'package:cloud_firestore/cloud_firestore.dart' show WriteBatch;
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/models/notification_draft.dart';

/// Dağıtıcının başkası adına bildirim yazma kapısı (PLAN §10.4
/// `addToBatch` / `createMany`; `docs/plans/T-25.md` §6).
///
/// `NotificationRepository` arayüzü Firebase SDK tipi taşıyamadığı için
/// (CD-06, `check_boundaries` B08) bu üyeler ayrı arayüzdedir;
/// `FirebaseNotificationRepository` ikisini birden uygular. Yalnızca
/// `ClientFanOutDispatcher` kullanır — sunucu tarafı dağıtıcı (Mod F,
/// CD-147) bu kapıya ihtiyaç duymaz, aynı şemayı Admin SDK ile yazar.
///
/// Her belge `notifications/{type}_{eventKey}_{recipientId}` kimliğiyle
/// (`FirestoreIds.notification`) ve `userId`, `type`, `refs` (yalnızca dolu
/// referanslar — W-51), `read: false`, sunucu zamanlı `createdAt` /
/// `updatedAt`, `isDeleted: false` alanlarıyla yazılır.
abstract interface class NotificationWriter {
  /// Yeni bir olay anahtarı (`NotificationDraft.eventKey`): 20 karakter
  /// `[A-Za-z0-9]` (Firestore otomatik kimliği), istemcide üretilir, ağ
  /// çağrısı yapmaz.
  ///
  /// Dağıtıcı tekrarlanabilen olayın her `notifyX` çağrısında **bir kez**
  /// üretir; olayın tüm alıcıları ve parça yeniden denemeleri aynı anahtarı
  /// kullanır (aynı olayın çift yazımı aynı belgeye düşer), olayın tekrarı
  /// yeni anahtar alır (W-49). Tek seferlik olaylarda (duyuru, iptal,
  /// başvuru) anahtar olayın kimliğidir, bu metot çağrılmaz (CD-148).
  String newEventKey();

  /// [draft] bildirimini [recipientId] alıcısı için [batch]'e ekler
  /// (`set`; commit çağırmaz).
  ///
  /// Tek alıcılı **kritik** bildirimler içindir: asıl yazım, sayaç ve
  /// günlükle aynı batch'te yazılır (biri reddedilirse hepsi düşer).
  void addToBatch(
    WriteBatch batch,
    NotificationDraft draft, {
    required String recipientId,
  });

  /// [draft] bildirimini [recipientIds] alıcılarının her birine **tek
  /// batch'te** yazar (fan-out parçası); döner: yazılan belge sayısı.
  ///
  /// Parçalama ve yeniden deneme çağıranındır (dağıtıcı). Liste
  /// `Limits.batchMaxWrites`'ı aşarsa ya da geçersiz kimlik içerirse yazım
  /// yapılmadan [FirestoreError.invalidArgument]; boş liste yazım yapmadan
  /// `0`. Belge kimlikleri olay anahtarından türediğinden aynı parçanın
  /// yeniden denenmesi çift belge üretmez — ama idempotent **değildir**:
  /// parça zaten kesinleşmişse ikinci gönderim Rules'ta güncelleme sayılır
  /// ve [FirestoreError.permissionDenied] döner (belgeler yazılmıştır;
  /// dağıtıcı ilk denemeden sonraki bu hatayı "yazıldı" sayar).
  Future<FirestoreResult<int>> createMany(
    NotificationDraft draft,
    List<String> recipientIds,
  );
}
