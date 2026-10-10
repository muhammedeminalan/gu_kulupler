import 'package:equatable/equatable.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/constants/limits.dart';
import 'package:gu_data/src/models/club_notification_prefs_model.dart';
import 'package:gu_data/src/models/enums/reminder_option.dart';
import 'package:gu_data/src/utils/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user_settings_model.g.dart';

/// Kullanıcının bildirim ayarları — `settings/{uid}` (PLAN §9.6.14,
/// domain-model §2.12).
///
/// `BaseFields` taşımaz: yalnızca [updatedAt] vardır, soft delete yoktur.
/// Belge kayıt sırasında [UserSettingsModel.defaults] ile oluşturulur;
/// varsayılan değerler başka hiçbir yerde yazılmaz.
///
/// Belge kimliği ([uid]) JSON'a yazılmaz ve JSON'dan okunmaz: okurken
/// [UserSettingsModel.fromJson] çağrısına `id` olarak verilir.
@JsonSerializable()
final class UserSettingsModel extends Equatable {
  /// Ayar belgesi oluşturur.
  const UserSettingsModel({
    this.uid = '',
    this.announcements = true,
    this.eventReminders = true,
    this.newEvents = true,
    this.applicationResults = true,
    this.management = true,
    this.system = true,
    this.reminderTime = ReminderOption.oneHour,
    this.quiet = false,
    this.quietFrom = Limits.quietFromDefault,
    this.quietTo = Limits.quietToDefault,
    this.clubs = const {},
    this.updatedAt,
  });

  /// Yeni kullanıcının varsayılan ayarları: altı tür açık, hatırlatıcı 1 saat
  /// önce, sessiz saatler kapalı (22:00–08:00), kulübe özgü tercih yok.
  const UserSettingsModel.defaults(String uid) : this(uid: uid);

  /// Firestore map'inden model üretir; [id] belgenin kimliğidir (`uid`).
  ///
  /// Eksik alanlar yapıcı varsayılanını alır, tanınmayan anahtarlar yok
  /// sayılır. `reminderTime` bilinmeyen bir değerse
  /// `CheckedFromJsonException` fırlatır.
  factory UserSettingsModel.fromJson(
    Map<String, Object?> json, {
    required String id,
  }) => _$UserSettingsModelFromJson(json).copyWith(uid: id);

  /// Belge kimliği: ayarların sahibi olan kullanıcının `uid`'i.
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String uid;

  /// Duyuru bildirimleri açık mı?
  @JsonKey(name: FirestoreFields.announcements)
  final bool announcements;

  /// Etkinlik hatırlatıcıları açık mı?
  @JsonKey(name: FirestoreFields.eventReminders)
  final bool eventReminders;

  /// Yeni etkinlik bildirimleri açık mı?
  @JsonKey(name: FirestoreFields.newEvents)
  final bool newEvents;

  /// Başvuru sonucu bildirimleri açık mı?
  @JsonKey(name: FirestoreFields.applicationResults)
  final bool applicationResults;

  /// Yönetim bildirimleri (başvuru, şikayet) açık mı?
  @JsonKey(name: FirestoreFields.management)
  final bool management;

  /// Sistem bildirimleri açık mı?
  @JsonKey(name: FirestoreFields.system)
  final bool system;

  /// Varsayılan etkinlik hatırlatma zamanı. Yalnızca
  /// [ReminderOption.oneHour] ve [ReminderOption.oneDay] geçerlidir (CD-34).
  @JsonKey(name: FirestoreFields.reminderTime)
  final ReminderOption reminderTime;

  /// Sessiz saatler açık mı?
  @JsonKey(name: FirestoreFields.quiet)
  final bool quiet;

  /// Sessiz saatlerin başlangıcı, `HH:mm` (`Limits.timeOfDayPattern`).
  @JsonKey(name: FirestoreFields.quietFrom)
  final String quietFrom;

  /// Sessiz saatlerin bitişi, `HH:mm` (`Limits.timeOfDayPattern`).
  @JsonKey(name: FirestoreFields.quietTo)
  final String quietTo;

  /// Kulübe özgü tercihler; anahtar kulüp kimliğidir. Kaydı olmayan kulüp
  /// için [ClubNotificationPrefsModel] varsayılanları geçerlidir.
  @JsonKey(name: FirestoreFields.clubs)
  final Map<String, ClubNotificationPrefsModel> clubs;

  /// Son güncelleme anı (sunucu zamanı, UTC).
  @JsonKey(name: FirestoreFields.updatedAt)
  @TimestampConverter()
  final DateTime? updatedAt;

  /// Firestore'a yazılacak map. Belge kimliği ve `null` alanlar yazılmaz;
  /// [clubs] değerleri map olur.
  Map<String, Object?> toJson() => _$UserSettingsModelToJson(this);

  /// Verilen alanları değiştirilmiş kopya.
  ///
  /// [updatedAt] alanını `null` yapmak için [clearUpdatedAt] `true` verilir;
  /// bayrak verilen değerden önce gelir.
  UserSettingsModel copyWith({
    String? uid,
    bool? announcements,
    bool? eventReminders,
    bool? newEvents,
    bool? applicationResults,
    bool? management,
    bool? system,
    ReminderOption? reminderTime,
    bool? quiet,
    String? quietFrom,
    String? quietTo,
    Map<String, ClubNotificationPrefsModel>? clubs,
    DateTime? updatedAt,
    bool clearUpdatedAt = false,
  }) => UserSettingsModel(
    uid: uid ?? this.uid,
    announcements: announcements ?? this.announcements,
    eventReminders: eventReminders ?? this.eventReminders,
    newEvents: newEvents ?? this.newEvents,
    applicationResults: applicationResults ?? this.applicationResults,
    management: management ?? this.management,
    system: system ?? this.system,
    reminderTime: reminderTime ?? this.reminderTime,
    quiet: quiet ?? this.quiet,
    quietFrom: quietFrom ?? this.quietFrom,
    quietTo: quietTo ?? this.quietTo,
    clubs: clubs ?? this.clubs,
    updatedAt: clearUpdatedAt ? null : updatedAt ?? this.updatedAt,
  );

  @override
  List<Object?> get props => [
    uid,
    announcements,
    eventReminders,
    newEvents,
    applicationResults,
    management,
    system,
    reminderTime,
    quiet,
    quietFrom,
    quietTo,
    clubs,
    updatedAt,
  ];
}
