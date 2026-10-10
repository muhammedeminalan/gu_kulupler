import 'package:equatable/equatable.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/constants/firestore_ids.dart';
import 'package:gu_data/src/core/base_fields.dart';
import 'package:gu_data/src/utils/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'saved_post_model.g.dart';

/// Kaydedilen gönderi — `savedPosts/{userId}_{postId}` (PLAN §9.6.16,
/// domain-model §2.14).
///
/// Kaydı yalnızca sahibi okur ve yazar. Kaydı kaldırmak soft delete'tir;
/// "Geri al" belgeyi geri yükler. [clubId] gönderiden kopyalanır (Security
/// Rules gönderinin kulübüne erişimi bununla denetler). `createdBy` taşımaz;
/// sahibi [userId] alanındadır. Zaman alanları UTC'dir (D-26).
@JsonSerializable()
final class SavedPostModel extends Equatable with BaseFields {
  /// Kayıt oluşturur. [id] verilmezse belge kimliği [userId] ve [postId]
  /// alanlarından türetilir (`FirestoreIds.savedPost`).
  const SavedPostModel({
    required this.userId,
    required this.postId,
    required this.clubId,
    this._id,
    this.savedAt,
    this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
  });

  /// Firestore belge verisinden model üretir; [id] belge kimliğidir (JSON'da
  /// yer almaz).
  ///
  /// Eksik anahtarlar kurucu varsayılanlarını alır; tanınmayan anahtarlar yok
  /// sayılır. Eksik zorunlu alan ([userId], [postId], [clubId])
  /// `CheckedFromJsonException` fırlatır.
  factory SavedPostModel.fromJson(
    Map<String, Object?> json, {
    required String id,
  }) => _$SavedPostModelFromJson(json).copyWith(id: id);

  /// Açıkça verilen belge kimliği; verilmediyse `null` ([id] türetilir).
  final String? _id;

  /// Belge kimliği. JSON'a yazılmaz. Açıkça verilmediyse
  /// `FirestoreIds.savedPost(userId, postId)` değeridir.
  @JsonKey(includeFromJson: false, includeToJson: false)
  String get id => _id ?? FirestoreIds.savedPost(userId, postId);

  /// Kaydın sahibi.
  @JsonKey(name: FirestoreFields.userId)
  final String userId;

  /// Kaydedilen gönderi.
  @JsonKey(name: FirestoreFields.postId)
  final String postId;

  /// Gönderinin kulübü (gönderideki değerin kopyası).
  @JsonKey(name: FirestoreFields.clubId)
  final String clubId;

  /// Kaydetme anı (sunucu zamanı, UTC); bekleyen yazımda `null`. Kaydedilenler
  /// listesi buna göre sıralanır.
  @JsonKey(name: FirestoreFields.savedAt)
  @TimestampConverter()
  final DateTime? savedAt;

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

  /// Kayıt `createdBy` taşımaz; sahibi [userId] alanındadır.
  @override
  String? get createdBy => null;

  /// Firestore'a yazılacak map. Belge kimliği ve `null` alanlar yer almaz;
  /// zaman alanları `Timestamp` olur (yazarken servis sunucu zamanı
  /// alanlarını ezer).
  Map<String, Object?> toJson() => _$SavedPostModelToJson(this);

  /// Verilen alanları değiştirilmiş kopya. `null` olabilen bir alanı `null`
  /// yapmak için ilgili `clear…` bayrağı verilir.
  ///
  /// Belge kimliği açıkça verilmemişse kopyada da türetilmeye devam eder
  /// ([userId] ya da [postId] değişirse [id] de değişir).
  SavedPostModel copyWith({
    String? id,
    String? userId,
    String? postId,
    String? clubId,
    DateTime? savedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
    String? deletedBy,
    bool clearSavedAt = false,
    bool clearCreatedAt = false,
    bool clearUpdatedAt = false,
    bool clearDeletedAt = false,
    bool clearDeletedBy = false,
  }) => SavedPostModel(
    id: id ?? _id,
    userId: userId ?? this.userId,
    postId: postId ?? this.postId,
    clubId: clubId ?? this.clubId,
    savedAt: clearSavedAt ? null : (savedAt ?? this.savedAt),
    createdAt: clearCreatedAt ? null : (createdAt ?? this.createdAt),
    updatedAt: clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    deletedBy: clearDeletedBy ? null : (deletedBy ?? this.deletedBy),
  );

  @override
  List<Object?> get props => [
    id,
    userId,
    postId,
    clubId,
    savedAt,
    createdAt,
    updatedAt,
    isDeleted,
    deletedAt,
    deletedBy,
  ];
}
