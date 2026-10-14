import 'package:equatable/equatable.dart';
import 'package:gu_data/src/models/enums/notification_type.dart';
import 'package:gu_data/src/models/notification_refs_model.dart';

/// Henüz yazılmamış bildirim (PLAN §10.4 `NotificationRepository`, §10.5;
/// `docs/plans/T-25.md` §6).
///
/// Bir **olayın** (bir başvuru, bir onay, bir duyuru yayını …) bildirimini
/// alıcıdan bağımsız tarif eder; alıcı yazım anında verilir
/// (`NotificationRepository.addToBatch` / `createMany`). Belge her alıcı
/// için `notifications/{type}_{eventKey}_{recipientId}` kimliğiyle,
/// `read: false` ve sunucu zamanlı `createdAt` / `updatedAt` ile yazılır;
/// metin yazılmaz (okuyan istemci [type] + [refs]'ten kendi dilinde üretir).
final class NotificationDraft extends Equatable {
  /// [type] türünde, [refs] referanslı ve [eventKey] olay anahtarlı bildirim.
  ///
  /// [refs] türün zorunlu referanslarını taşır
  /// (`NotificationRefsModel.requiredFor`); diğer referanslar `null` kalır.
  const NotificationDraft({
    required this.type,
    required this.eventKey,
    this.refs = const NotificationRefsModel(),
  });

  /// Bildirim türü.
  final NotificationType type;

  /// Bildirimin gösterdiği kayıtlar.
  final NotificationRefsModel refs;

  /// Belge kimliğinin olay parçası (W-49, CD-129): bir olayın **tüm**
  /// alıcıları ve tüm yeniden denemeleri aynı anahtarı paylaşır; olay
  /// tekrarlanırsa (onayla → geri al → yeniden onayla, yeniden başvuru,
  /// yeniden yayın …) yeni anahtar üretilir.
  ///
  /// Tekrarlanabilen olaylarda `NotificationWriter.newEventKey()` çıktısıdır
  /// (20 karakter `[A-Za-z0-9]`, tahmin edilemez); tek seferlik olaylarda
  /// olayın kimliğidir — `announcement` → `postId`, `event_cancelled` →
  /// `eventId`, `application_received` → `FirestoreIds.applicationEventKey`
  /// (CD-148); `event_reminder` türünde etkinlik kimliğidir (`createSelf`,
  /// cihaz başına bir belge).
  final String eventKey;

  @override
  List<Object?> get props => [type, refs, eventKey];
}
