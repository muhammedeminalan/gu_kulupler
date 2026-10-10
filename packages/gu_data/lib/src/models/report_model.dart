import 'package:equatable/equatable.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/constants/firestore_ids.dart';
import 'package:gu_data/src/core/base_fields.dart';
import 'package:gu_data/src/models/enums/report_action.dart';
import 'package:gu_data/src/models/enums/report_reason.dart';
import 'package:gu_data/src/models/enums/report_status.dart';
import 'package:gu_data/src/models/enums/report_target_type.dart';
import 'package:gu_data/src/utils/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'report_model.g.dart';

/// Tek bir kullanıcının tek bir hedef için şikayeti —
/// `reports/{reporterId}_{targetType}_{targetId}` belgesi (PLAN §9.6.12,
/// domain-model §2.10; CD-33).
///
/// Her şikayet ayrı belgedir; aynı hedefin şikayetleri yönetim ekranında
/// istemcide gruplanır (`(targetType, targetId)`). Belge kimliği [id] JSON'a
/// girmez.
@JsonSerializable()
final class ReportModel extends Equatable with BaseFields {
  /// Şikayet oluşturur.
  ///
  /// [id] verilmezse
  /// `FirestoreIds.report(reporterId, targetType.json, targetId)` değeridir.
  const ReportModel({
    required this.targetType,
    required this.targetId,
    required this.reporterId,
    required this.reason,
    this._id,
    this.targetClubId,
    this.note = '',
    this.status = ReportStatus.open,
    this.action,
    this.resolvedAt,
    this.resolvedBy,
    this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
  });

  /// Firestore belge verisinden üretir; [id] belge kimliğidir (veride
  /// `id` anahtarı olsa da okunmaz).
  factory ReportModel.fromJson(
    Map<String, Object?> json, {
    required String id,
  }) => _$ReportModelFromJson(json).copyWith(id: id);

  /// Açıkça verilmiş belge kimliği; `null` ise [id] alanlardan türer.
  final String? _id;

  /// Belge kimliği (JSON'a yazılmaz); verilmediyse
  /// `FirestoreIds.report(reporterId, targetType.json, targetId)`.
  @JsonKey(includeFromJson: false, includeToJson: false)
  String get id =>
      _id ?? FirestoreIds.report(reporterId, targetType.json, targetId);

  /// Şikayet edilen şeyin türü.
  @JsonKey(name: FirestoreFields.targetType)
  final ReportTargetType targetType;

  /// Şikayet edilen belgenin kimliği.
  @JsonKey(name: FirestoreFields.targetId)
  final String targetId;

  /// Hedefin ait olduğu kulüp; hedef kullanıcıysa `null`.
  @JsonKey(name: FirestoreFields.targetClubId)
  final String? targetClubId;

  /// Şikayet edenin uid'i.
  @JsonKey(name: FirestoreFields.reporterId)
  final String reporterId;

  /// Şikayet nedeni.
  @JsonKey(name: FirestoreFields.reason)
  final ReportReason reason;

  /// Şikayet edenin açıklaması.
  @JsonKey(name: FirestoreFields.note)
  final String note;

  /// Şikayetin durumu.
  @JsonKey(name: FirestoreFields.status)
  final ReportStatus status;

  /// Çözümde uygulanan işlem; açık şikayette ya da bilinmeyen değerde `null`.
  @JsonKey(
    name: FirestoreFields.action,
    unknownEnumValue: JsonKey.nullForUndefinedEnumValue,
  )
  final ReportAction? action;

  /// Çözüm anı (sunucu zamanı, UTC).
  @JsonKey(name: FirestoreFields.resolvedAt)
  @TimestampConverter()
  final DateTime? resolvedAt;

  /// Çözen süper adminin uid'i.
  @JsonKey(name: FirestoreFields.resolvedBy)
  final String? resolvedBy;

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

  /// Şikayet belgesi `createdBy` taşımaz (sahibi [reporterId]).
  @override
  String? get createdBy => null;

  /// Firestore'a yazılacak harita ([id] hariç).
  Map<String, Object?> toJson() => _$ReportModelToJson(this);

  /// Verilen alanları değişmiş kopya; `clear*` bayrağı alanı `null` yapar.
  ///
  /// [id] açıkça verilmediyse türetilmiş kalır ve yeni [reporterId] /
  /// [targetType] / [targetId] değerlerini izler.
  ReportModel copyWith({
    String? id,
    ReportTargetType? targetType,
    String? targetId,
    String? targetClubId,
    bool clearTargetClubId = false,
    String? reporterId,
    ReportReason? reason,
    String? note,
    ReportStatus? status,
    ReportAction? action,
    bool clearAction = false,
    DateTime? resolvedAt,
    bool clearResolvedAt = false,
    String? resolvedBy,
    bool clearResolvedBy = false,
    DateTime? createdAt,
    bool clearCreatedAt = false,
    DateTime? updatedAt,
    bool clearUpdatedAt = false,
    bool? isDeleted,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    String? deletedBy,
    bool clearDeletedBy = false,
  }) => ReportModel(
    id: id ?? _id,
    targetType: targetType ?? this.targetType,
    targetId: targetId ?? this.targetId,
    targetClubId: clearTargetClubId
        ? null
        : (targetClubId ?? this.targetClubId),
    reporterId: reporterId ?? this.reporterId,
    reason: reason ?? this.reason,
    note: note ?? this.note,
    status: status ?? this.status,
    action: clearAction ? null : (action ?? this.action),
    resolvedAt: clearResolvedAt ? null : (resolvedAt ?? this.resolvedAt),
    resolvedBy: clearResolvedBy ? null : (resolvedBy ?? this.resolvedBy),
    createdAt: clearCreatedAt ? null : (createdAt ?? this.createdAt),
    updatedAt: clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    deletedBy: clearDeletedBy ? null : (deletedBy ?? this.deletedBy),
  );

  @override
  List<Object?> get props => [
    id,
    targetType,
    targetId,
    targetClubId,
    reporterId,
    reason,
    note,
    status,
    action,
    resolvedAt,
    resolvedBy,
    createdAt,
    updatedAt,
    isDeleted,
    deletedAt,
    deletedBy,
  ];
}
