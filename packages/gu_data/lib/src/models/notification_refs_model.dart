import 'package:equatable/equatable.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/models/enums/club_role.dart';
import 'package:gu_data/src/models/enums/notification_type.dart';
import 'package:json_annotation/json_annotation.dart';

part 'notification_refs_model.g.dart';

/// Bildirimin gösterdiği kayıtlar — `notifications.refs` gömülü nesnesi
/// (PLAN §9.6.11, domain-model §2.9, §6).
///
/// Bildirim metni ve dokununca açılacak hedef bu referanslardan çözülür. Her
/// alan isteğe bağlıdır; hangi türün hangi referansı zorunlu taşıdığını
/// [requiredFor] verir.
@JsonSerializable()
final class NotificationRefsModel extends Equatable {
  /// Referans nesnesi oluşturur; verilmeyen her alan `null`'dır.
  const NotificationRefsModel({
    this.clubId,
    this.eventId,
    this.postId,
    this.applicantId,
    this.reportId,
    this.role,
    this.textKey,
  });

  /// Firestore map'inden ([json]) referans nesnesi üretir.
  ///
  /// Tanınmayan anahtarlar yok sayılır; bilinmeyen [role] değeri `null` olur
  /// (ileri uyumluluk).
  factory NotificationRefsModel.fromJson(Map<String, Object?> json) =>
      _$NotificationRefsModelFromJson(json);

  /// [type] türündeki bildirimin taşımak zorunda olduğu referans alanları
  /// (`FirestoreFields` adlarıyla).
  ///
  /// Tanınmayan tür ([NotificationType.unknown]) için küme boştur.
  static Set<String> requiredFor(NotificationType type) => switch (type) {
    NotificationType.applicationReceived => const {
      FirestoreFields.clubId,
      FirestoreFields.applicantId,
    },
    NotificationType.applicationApproved ||
    NotificationType.applicationRejected ||
    NotificationType.removedFromClub => const {FirestoreFields.clubId},
    NotificationType.roleChanged => const {
      FirestoreFields.clubId,
      FirestoreFields.role,
    },
    NotificationType.announcement => const {
      FirestoreFields.clubId,
      FirestoreFields.postId,
    },
    NotificationType.eventNew ||
    NotificationType.eventReminder ||
    NotificationType.eventCancelled ||
    NotificationType.waitlistPromoted => const {
      FirestoreFields.clubId,
      FirestoreFields.eventId,
    },
    NotificationType.reportResolved ||
    NotificationType.newReport => const {FirestoreFields.reportId},
    NotificationType.system => const {FirestoreFields.textKey},
    NotificationType.unknown => const {},
  };

  /// İlgili kulübün kimliği.
  @JsonKey(name: FirestoreFields.clubId)
  final String? clubId;

  /// İlgili etkinliğin kimliği.
  @JsonKey(name: FirestoreFields.eventId)
  final String? eventId;

  /// İlgili gönderinin kimliği.
  @JsonKey(name: FirestoreFields.postId)
  final String? postId;

  /// Başvuranın uid'i (`application_received`).
  @JsonKey(name: FirestoreFields.applicantId)
  final String? applicantId;

  /// İlgili şikayetin kimliği.
  @JsonKey(name: FirestoreFields.reportId)
  final String? reportId;

  /// Atanan yeni rol (`role_changed`).
  @JsonKey(
    name: FirestoreFields.role,
    unknownEnumValue: JsonKey.nullForUndefinedEnumValue,
  )
  final ClubRole? role;

  /// Sistem bildirimi metin anahtarı (`welcome`, `maintenance`); metin
  /// uygulama katmanında ARB'den çözülür.
  @JsonKey(name: FirestoreFields.textKey)
  final String? textKey;

  /// Firestore'a yazılacak map; `null` alanlar yer almaz.
  Map<String, Object?> toJson() => _$NotificationRefsModelToJson(this);

  /// Verilen alanları değiştirilmiş kopya döner.
  ///
  /// Null olabilen bir alanı `null` yapmak için ilgili `clear…` bayrağı
  /// verilir; bayrak, aynı alan için verilen değerden önce gelir.
  NotificationRefsModel copyWith({
    String? clubId,
    String? eventId,
    String? postId,
    String? applicantId,
    String? reportId,
    ClubRole? role,
    String? textKey,
    bool clearClubId = false,
    bool clearEventId = false,
    bool clearPostId = false,
    bool clearApplicantId = false,
    bool clearReportId = false,
    bool clearRole = false,
    bool clearTextKey = false,
  }) => NotificationRefsModel(
    clubId: clearClubId ? null : clubId ?? this.clubId,
    eventId: clearEventId ? null : eventId ?? this.eventId,
    postId: clearPostId ? null : postId ?? this.postId,
    applicantId: clearApplicantId ? null : applicantId ?? this.applicantId,
    reportId: clearReportId ? null : reportId ?? this.reportId,
    role: clearRole ? null : role ?? this.role,
    textKey: clearTextKey ? null : textKey ?? this.textKey,
  );

  @override
  List<Object?> get props => [
    clubId,
    eventId,
    postId,
    applicantId,
    reportId,
    role,
    textKey,
  ];
}
