import 'package:collection/collection.dart';
import 'package:gu_data/src/models/enums/activity_category.dart';
import 'package:json_annotation/json_annotation.dart';

/// Kulüp etkinlik günlüğü kaydının türü (`activity.kind`; PLAN §9.7,
/// domain-model §2.11).
///
/// 13 tür + ileri uyumluluk için [unknown]: eski istemci tanımadığı yeni türü
/// [unknown] olarak okur (model alanında
/// `@JsonKey(unknownEnumValue: ActivityKind.unknown)`).
@JsonEnum(valueField: 'json')
enum ActivityKind {
  /// Kulübe başvuru geldi.
  applicationReceived('application_received', ActivityCategory.membership),

  /// Başvuru onaylandı.
  applicationApproved('application_approved', ActivityCategory.membership),

  /// Başvuru reddedildi.
  applicationRejected('application_rejected', ActivityCategory.membership),

  /// Üye katıldı.
  memberJoined('member_joined', ActivityCategory.membership),

  /// Üye ayrıldı.
  memberLeft('member_left', ActivityCategory.membership),

  /// Üye çıkarıldı.
  memberRemoved('member_removed', ActivityCategory.membership),

  /// Üyenin rolü değişti.
  roleChanged('role_changed', ActivityCategory.membership),

  /// Etkinlik yayımlandı.
  eventPublished('event_published', ActivityCategory.event),

  /// Etkinlik iptal edildi.
  eventCancelled('event_cancelled', ActivityCategory.event),

  /// Gönderi paylaşıldı.
  postCreated('post_created', ActivityCategory.content),

  /// Duyuru yayımlandı.
  announcement('announcement', ActivityCategory.content),

  /// Anket açıldı.
  poll('poll', ActivityCategory.content),

  /// Kulüp ayarları değişti.
  settingsChanged('settings_changed', ActivityCategory.settings),

  /// Bu istemcinin tanımadığı tür (ileri uyumluluk); kategorisi yoktur.
  unknown('unknown', null);

  const ActivityKind(this.json, this.category);

  /// Firestore'daki dizgi karşılığı.
  final String json;

  /// MGT-10 süzgeç kategorisi (`registry.json#actCat`).
  ///
  /// [unknown] için `null`: registry'de karşılığı yoktur, hiçbir kategori
  /// süzgecine girmez.
  final ActivityCategory? category;

  /// Firestore dizgisinden tür üretir.
  ///
  /// Eşleşme birebirdir (büyük/küçük harf ve boşluk duyarlı). Bilinmeyen
  /// değer hata fırlatmaz, [unknown] döner (ileri uyumluluk).
  static ActivityKind fromJson(String json) =>
      values.firstWhereOrNull((kind) => kind.json == json) ?? unknown;
}
