import 'package:equatable/equatable.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/core/base_fields.dart';
import 'package:gu_data/src/models/enums/notification_category.dart';
import 'package:gu_data/src/models/enums/notification_type.dart';
import 'package:gu_data/src/models/notification_refs_model.dart';
import 'package:gu_data/src/utils/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'notification_model.g.dart';

/// Uygulama içi bildirim — `notifications/{id}` (PLAN §9.6.11, domain-model
/// §2.9, §6; rules-spec §3.9).
///
/// Metin saklanmaz: [type] ve [refs] üzerinden uygulama katmanında ARB'den
/// üretilir. Kaydırarak silme soft delete'tir, "Geri al" geri yükler. Tüm
/// zamanlar UTC'dir (D-26).
///
/// Belge kimliği ([id]) JSON'a yazılmaz; okurken [NotificationModel.fromJson]
/// çağrısına ayrıca verilir.
@JsonSerializable()
final class NotificationModel extends Equatable with BaseFields {
  /// Bildirim oluşturur.
  const NotificationModel({
    required this.userId,
    required this.type,
    this.id = '',
    this.refs = const NotificationRefsModel(),
    this.read = false,
    this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
  });

  /// Firestore belge verisinden ([json]) ve belge kimliğinden ([id]) bildirim
  /// üretir.
  ///
  /// Zaman alanları `Timestamp`, [DateTime] ya da ISO-8601 dizgisi olabilir;
  /// hepsi UTC'ye çevrilir. Tanınmayan anahtarlar yok sayılır; bu istemcinin
  /// tanımadığı tür [NotificationType.unknown] olur. Eksik zorunlu alan
  /// `CheckedFromJsonException` fırlatır (alan adıyla).
  factory NotificationModel.fromJson(
    Map<String, Object?> json, {
    required String id,
  }) => _$NotificationModelFromJson(json).copyWith(id: id);

  /// Belge kimliği (`notifications/{id}`); JSON'a yazılmaz ve JSON'dan
  /// okunmaz.
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String id;

  /// Alıcının uid'i.
  @JsonKey(name: FirestoreFields.userId)
  final String userId;

  /// Bildirim türü; tanınmayan değer [NotificationType.unknown] okunur.
  @JsonKey(
    name: FirestoreFields.type,
    unknownEnumValue: NotificationType.unknown,
  )
  final NotificationType type;

  /// Bildirimin gösterdiği kayıtlar (kulüp, etkinlik, gönderi …).
  @JsonKey(name: FirestoreFields.refs)
  final NotificationRefsModel refs;

  /// Okundu mu?
  @JsonKey(name: FirestoreFields.read)
  final bool read;

  @override
  @TimestampConverter()
  @JsonKey(name: FirestoreFields.createdAt)
  final DateTime? createdAt;

  @override
  @TimestampConverter()
  @JsonKey(name: FirestoreFields.updatedAt)
  final DateTime? updatedAt;

  @override
  @JsonKey(name: FirestoreFields.isDeleted)
  final bool isDeleted;

  @override
  @TimestampConverter()
  @JsonKey(name: FirestoreFields.deletedAt)
  final DateTime? deletedAt;

  @override
  @JsonKey(name: FirestoreFields.deletedBy)
  final String? deletedBy;

  /// Bildirim `createdBy` taşımaz (alıcısı [userId]).
  @override
  String? get createdBy => null;

  /// NTF-01 süzgeç kategorisi; tanınmayan türde `null` (satır gizlenir).
  NotificationCategory? get category => type.category;

  /// Firestore'a yazılacak alanlar; [id] ve `null` değerler yer almaz, zaman
  /// alanları `Timestamp`, [refs] ise map olur.
  Map<String, Object?> toJson() => _$NotificationModelToJson(this);

  /// Verilen alanları değiştirilmiş kopya döner.
  ///
  /// Null olabilen bir alanı `null` yapmak için ilgili `clear…` bayrağı
  /// verilir; bayrak, aynı alan için verilen değerden önce gelir.
  NotificationModel copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    NotificationRefsModel? refs,
    bool? read,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
    String? deletedBy,
    bool clearCreatedAt = false,
    bool clearUpdatedAt = false,
    bool clearDeletedAt = false,
    bool clearDeletedBy = false,
  }) => NotificationModel(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    type: type ?? this.type,
    refs: refs ?? this.refs,
    read: read ?? this.read,
    createdAt: clearCreatedAt ? null : createdAt ?? this.createdAt,
    updatedAt: clearUpdatedAt ? null : updatedAt ?? this.updatedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
    deletedBy: clearDeletedBy ? null : deletedBy ?? this.deletedBy,
  );

  @override
  List<Object?> get props => [
    id,
    userId,
    type,
    refs,
    read,
    createdAt,
    updatedAt,
    isDeleted,
    deletedAt,
    deletedBy,
  ];
}
