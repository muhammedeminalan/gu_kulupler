import 'package:equatable/equatable.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/core/base_fields.dart';
import 'package:gu_data/src/models/enums/support_subject.dart';
import 'package:gu_data/src/models/enums/ticket_status.dart';
import 'package:gu_data/src/utils/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'support_ticket_model.g.dart';

/// Destek talebi — `supportTickets/{id}` (PLAN §9.6.17, domain-model §2.15).
///
/// Talebi sahibi oluşturur ve okur; süper admin okur ve kapatır.
///
/// Belge kimliği ([id]) JSON'a yazılmaz ve JSON'dan okunmaz: okurken
/// [SupportTicketModel.fromJson] çağrısına verilir.
@JsonSerializable()
final class SupportTicketModel extends Equatable with BaseFields {
  /// Destek talebi oluşturur.
  const SupportTicketModel({
    required this.ticketNo,
    required this.userId,
    required this.subject,
    required this.message,
    this.id = '',
    this.attachmentPaths = const [],
    this.status = TicketStatus.open,
    this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
  });

  /// Firestore map'inden model üretir; [id] belgenin kimliğidir.
  ///
  /// Eksik alanlar yapıcı varsayılanını alır, tanınmayan anahtarlar yok
  /// sayılır. Zorunlu alan eksikse ya da `subject` / `status` bilinmeyen bir
  /// değerse `CheckedFromJsonException` fırlatır.
  factory SupportTicketModel.fromJson(
    Map<String, Object?> json, {
    required String id,
  }) => _$SupportTicketModelFromJson(json).copyWith(id: id);

  /// Belge kimliği (Firestore otomatik kimliği).
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String id;

  /// Kullanıcıya gösterilen talep numarası: `GU-XXXXXX`
  /// (`FirestoreIds.supportTicketNoPattern`).
  @JsonKey(name: FirestoreFields.ticketNo)
  final String ticketNo;

  /// Talebi açan kullanıcının `uid`'i.
  @JsonKey(name: FirestoreFields.userId)
  final String userId;

  /// Talebin konusu.
  @JsonKey(name: FirestoreFields.subject)
  final SupportSubject subject;

  /// Kullanıcının mesajı (1–`Limits.supportMessageMax` karakter).
  @JsonKey(name: FirestoreFields.message)
  final String message;

  /// Ek dosyaların Storage yolları (`support/{ticketNo}/{file}`; en çok
  /// `Limits.supportAttachmentsMax`).
  @JsonKey(name: FirestoreFields.attachmentPaths)
  final List<String> attachmentPaths;

  /// Talebin durumu; yalnızca süper admin kapatır.
  @JsonKey(name: FirestoreFields.status)
  final TicketStatus status;

  @override
  @JsonKey(name: FirestoreFields.createdAt)
  @TimestampConverter()
  final DateTime? createdAt;

  @override
  @JsonKey(name: FirestoreFields.updatedAt)
  @TimestampConverter()
  final DateTime? updatedAt;

  @override
  @JsonKey(name: FirestoreFields.isDeleted)
  final bool isDeleted;

  @override
  @JsonKey(name: FirestoreFields.deletedAt)
  @TimestampConverter()
  final DateTime? deletedAt;

  @override
  @JsonKey(name: FirestoreFields.deletedBy)
  final String? deletedBy;

  /// Bu belge `createdBy` taşımaz; sahibi [userId] alanıdır.
  @override
  String? get createdBy => null;

  /// Firestore'a yazılacak map. Belge kimliği ve `null` alanlar yazılmaz;
  /// zaman alanları `Timestamp` olur.
  Map<String, Object?> toJson() => _$SupportTicketModelToJson(this);

  /// Verilen alanları değiştirilmiş kopya.
  ///
  /// `null` olabilen bir alanı `null` yapmak için ilgili `clear…` bayrağı
  /// `true` verilir; bayrak aynı alan için verilen değerden önce gelir.
  SupportTicketModel copyWith({
    String? id,
    String? ticketNo,
    String? userId,
    SupportSubject? subject,
    String? message,
    List<String>? attachmentPaths,
    TicketStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
    String? deletedBy,
    bool clearCreatedAt = false,
    bool clearUpdatedAt = false,
    bool clearDeletedAt = false,
    bool clearDeletedBy = false,
  }) => SupportTicketModel(
    id: id ?? this.id,
    ticketNo: ticketNo ?? this.ticketNo,
    userId: userId ?? this.userId,
    subject: subject ?? this.subject,
    message: message ?? this.message,
    attachmentPaths: attachmentPaths ?? this.attachmentPaths,
    status: status ?? this.status,
    createdAt: clearCreatedAt ? null : createdAt ?? this.createdAt,
    updatedAt: clearUpdatedAt ? null : updatedAt ?? this.updatedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
    deletedBy: clearDeletedBy ? null : deletedBy ?? this.deletedBy,
  );

  @override
  List<Object?> get props => [
    id,
    ticketNo,
    userId,
    subject,
    message,
    attachmentPaths,
    status,
    createdAt,
    updatedAt,
    isDeleted,
    deletedAt,
    deletedBy,
  ];
}
