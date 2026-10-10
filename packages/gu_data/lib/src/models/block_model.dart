import 'package:equatable/equatable.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/constants/firestore_ids.dart';
import 'package:gu_data/src/core/base_fields.dart';
import 'package:gu_data/src/utils/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'block_model.g.dart';

/// Bir kullanıcının başka bir kullanıcıyı engellemesi —
/// `blocks/{blockerId}_{blockedId}` (PLAN §9.6.15, domain-model §2.13).
///
/// Engeli kaldırmak soft delete'tir ([isDeleted]); yeniden engellemek ve
/// "Geri al" aynı belgeyi geri yükler. Belgeyi yalnızca sahibi
/// ([blockerId]) okur ve yazar.
///
/// Belge kimliği ([id]) JSON'a yazılmaz ve JSON'dan okunmaz: okurken
/// [BlockModel.fromJson] çağrısına verilir.
@JsonSerializable()
final class BlockModel extends Equatable with BaseFields {
  /// Engel kaydı oluşturur. [id] verilmezse belge kimliği [blockerId] ve
  /// [blockedId] alanlarından türetilir (`FirestoreIds.block`).
  const BlockModel({
    required this.blockerId,
    required this.blockedId,
    this._id,
    this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
  });

  /// Firestore map'inden model üretir; [id] belgenin kimliğidir.
  ///
  /// Eksik alanlar yapıcı varsayılanını alır, tanınmayan anahtarlar yok
  /// sayılır. Zorunlu alan eksikse `CheckedFromJsonException` fırlatır.
  factory BlockModel.fromJson(
    Map<String, Object?> json, {
    required String id,
  }) => _$BlockModelFromJson(json).copyWith(id: id);

  /// Açıkça verilen belge kimliği; verilmediyse `null` ([id] türetilir).
  final String? _id;

  /// Belge kimliği: `{blockerId}_{blockedId}`. JSON'a yazılmaz ve JSON'dan
  /// okunmaz. Açıkça verilmediyse `FirestoreIds.block(blockerId, blockedId)`
  /// değeridir.
  @JsonKey(includeFromJson: false, includeToJson: false)
  String get id => _id ?? FirestoreIds.block(blockerId, blockedId);

  /// Engelleyen kullanıcının `uid`'i (belgenin sahibi).
  @JsonKey(name: FirestoreFields.blockerId)
  final String blockerId;

  /// Engellenen kullanıcının `uid`'i; [blockerId] ile aynı olamaz.
  @JsonKey(name: FirestoreFields.blockedId)
  final String blockedId;

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

  /// Bu belge `createdBy` taşımaz; sahibi [blockerId] alanıdır.
  @override
  String? get createdBy => null;

  /// Firestore'a yazılacak map. Belge kimliği ve `null` alanlar yazılmaz;
  /// zaman alanları `Timestamp` olur.
  Map<String, Object?> toJson() => _$BlockModelToJson(this);

  /// Verilen alanları değiştirilmiş kopya.
  ///
  /// Belge kimliği açıkça verilmemişse kopyada da türetilmeye devam eder
  /// ([blockerId] ya da [blockedId] değişirse [id] de değişir). `null`
  /// olabilen bir alanı `null` yapmak için ilgili `clear…` bayrağı `true`
  /// verilir; bayrak aynı alan için verilen değerden önce gelir.
  BlockModel copyWith({
    String? id,
    String? blockerId,
    String? blockedId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
    String? deletedBy,
    bool clearCreatedAt = false,
    bool clearUpdatedAt = false,
    bool clearDeletedAt = false,
    bool clearDeletedBy = false,
  }) => BlockModel(
    id: id ?? _id,
    blockerId: blockerId ?? this.blockerId,
    blockedId: blockedId ?? this.blockedId,
    createdAt: clearCreatedAt ? null : createdAt ?? this.createdAt,
    updatedAt: clearUpdatedAt ? null : updatedAt ?? this.updatedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
    deletedBy: clearDeletedBy ? null : deletedBy ?? this.deletedBy,
  );

  @override
  List<Object?> get props => [
    id,
    blockerId,
    blockedId,
    createdAt,
    updatedAt,
    isDeleted,
    deletedAt,
    deletedBy,
  ];
}
