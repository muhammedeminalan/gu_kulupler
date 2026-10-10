import 'package:collection/collection.dart';
import 'package:gu_data/src/models/enums/notification_category.dart';
import 'package:json_annotation/json_annotation.dart';

/// Bildirim türü (`notifications.type`; PLAN §9.7, domain-model §6).
///
/// 13 tür + ileri uyumluluk için [unknown]: eski istemci tanımadığı yeni türü
/// [unknown] olarak okur ve satırı gizler (model alanında
/// `@JsonKey(unknownEnumValue: NotificationType.unknown)`).
@JsonEnum(valueField: 'json')
enum NotificationType {
  /// Kulübe yeni başvuru geldi (yöneticilere).
  applicationReceived('application_received', NotificationCategory.clubs),

  /// Başvuru onaylandı (başvurana).
  applicationApproved('application_approved', NotificationCategory.clubs),

  /// Başvuru reddedildi (başvurana).
  applicationRejected('application_rejected', NotificationCategory.clubs),

  /// Üye kulüpten çıkarıldı (üyeye).
  removedFromClub('removed_from_club', NotificationCategory.clubs),

  /// Üyenin rolü değişti (üyeye).
  roleChanged('role_changed', NotificationCategory.clubs),

  /// Kulüp duyurusu yayımlandı.
  announcement('announcement', NotificationCategory.clubs),

  /// Yeni etkinlik yayımlandı.
  eventNew('event_new', NotificationCategory.events),

  /// Etkinlik hatırlatıcısı.
  eventReminder('event_reminder', NotificationCategory.events),

  /// Etkinlik iptal edildi.
  eventCancelled('event_cancelled', NotificationCategory.events),

  /// Bekleme listesinden katılımcılığa geçildi.
  waitlistPromoted('waitlist_promoted', NotificationCategory.events),

  /// Şikayet sonuçlandı (şikayetçiye).
  reportResolved('report_resolved', NotificationCategory.clubs),

  /// Yeni şikayet geldi (süper admine).
  newReport('new_report', NotificationCategory.clubs),

  /// Sistem bildirimi (`refs.textKey` metni seçer).
  system('system', NotificationCategory.system),

  /// Bu istemcinin tanımadığı tür (ileri uyumluluk); kategorisi yoktur.
  unknown('unknown', null);

  const NotificationType(this.json, this.category);

  /// Firestore'daki dizgi karşılığı.
  final String json;

  /// NTF-01 süzgeç kategorisi (`registry.json#notifCat`).
  ///
  /// [unknown] için `null`: registry'de karşılığı yoktur, hiçbir kategori
  /// süzgecine girmez.
  final NotificationCategory? category;

  /// Firestore dizgisinden tür üretir.
  ///
  /// Eşleşme birebirdir (büyük/küçük harf ve boşluk duyarlı). Bilinmeyen
  /// değer hata fırlatmaz, [unknown] döner (ileri uyumluluk).
  static NotificationType fromJson(String json) =>
      values.firstWhereOrNull((type) => type.json == json) ?? unknown;
}
