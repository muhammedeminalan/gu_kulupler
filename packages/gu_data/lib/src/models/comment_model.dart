import 'package:equatable/equatable.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/core/base_fields.dart';
import 'package:gu_data/src/utils/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'comment_model.g.dart';

/// Gönderi yorumu — `comments/{commentId}` (PLAN §9.6.8, domain-model §2.6).
///
/// Yorumlar tek seviyedir (yanıt yok). [clubId] gönderiden kopyalanır
/// (sorgu ve Security Rules için). `createdBy` taşımaz; yazar [authorId]
/// alanındadır. Yorum silinince/geri alınınca gönderinin `commentCount`
/// sayacı aynı yazımda değişir. Zaman alanları UTC'dir (D-26).
@JsonSerializable()
final class CommentModel extends Equatable with BaseFields {
  /// Yorum oluşturur. [id] verilmezse boş dizgidir; okunan belgelerde
  /// [CommentModel.fromJson] belge kimliğini verir.
  const CommentModel({
    required this.postId,
    required this.clubId,
    required this.authorId,
    required this.text,
    this.id = '',
    this.isHidden = false,
    this.hiddenBy,
    this.hiddenAt,
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
  /// sayılır. Eksik zorunlu alan ([postId], [clubId], [authorId], [text])
  /// `CheckedFromJsonException` fırlatır.
  factory CommentModel.fromJson(
    Map<String, Object?> json, {
    required String id,
  }) => _$CommentModelFromJson(json).copyWith(id: id);

  /// Belge kimliği (`comments/{commentId}`). JSON'a yazılmaz.
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String id;

  /// Yorumun yazıldığı gönderi.
  @JsonKey(name: FirestoreFields.postId)
  final String postId;

  /// Gönderinin kulübü (gönderideki değerin kopyası).
  @JsonKey(name: FirestoreFields.clubId)
  final String clubId;

  /// Yazarın uid'i.
  @JsonKey(name: FirestoreFields.authorId)
  final String authorId;

  /// Yorum metni (1 – `Limits.commentMax`).
  @JsonKey(name: FirestoreFields.text)
  final String text;

  /// Moderasyonla gizlendi mi? (süper admin)
  @JsonKey(name: FirestoreFields.isHidden)
  final bool isHidden;

  /// Gizleyen süper adminin uid'i; gizli değilse `null`.
  @JsonKey(name: FirestoreFields.hiddenBy)
  final String? hiddenBy;

  /// Gizlenme anı (sunucu zamanı, UTC); gizli değilse `null`.
  @JsonKey(name: FirestoreFields.hiddenAt)
  @TimestampConverter()
  final DateTime? hiddenAt;

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

  /// Yorum `createdBy` taşımaz; yazar [authorId] alanındadır.
  @override
  String? get createdBy => null;

  /// Firestore'a yazılacak map. Belge kimliği ve `null` alanlar yer almaz;
  /// zaman alanları `Timestamp` olur (yazarken servis sunucu zamanı
  /// alanlarını ezer).
  Map<String, Object?> toJson() => _$CommentModelToJson(this);

  /// Verilen alanları değiştirilmiş kopya. `null` olabilen bir alanı `null`
  /// yapmak için ilgili `clear…` bayrağı verilir.
  CommentModel copyWith({
    String? id,
    String? postId,
    String? clubId,
    String? authorId,
    String? text,
    bool? isHidden,
    String? hiddenBy,
    DateTime? hiddenAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
    String? deletedBy,
    bool clearHiddenBy = false,
    bool clearHiddenAt = false,
    bool clearCreatedAt = false,
    bool clearUpdatedAt = false,
    bool clearDeletedAt = false,
    bool clearDeletedBy = false,
  }) => CommentModel(
    id: id ?? this.id,
    postId: postId ?? this.postId,
    clubId: clubId ?? this.clubId,
    authorId: authorId ?? this.authorId,
    text: text ?? this.text,
    isHidden: isHidden ?? this.isHidden,
    hiddenBy: clearHiddenBy ? null : (hiddenBy ?? this.hiddenBy),
    hiddenAt: clearHiddenAt ? null : (hiddenAt ?? this.hiddenAt),
    createdAt: clearCreatedAt ? null : (createdAt ?? this.createdAt),
    updatedAt: clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    deletedBy: clearDeletedBy ? null : (deletedBy ?? this.deletedBy),
  );

  @override
  List<Object?> get props => [
    id,
    postId,
    clubId,
    authorId,
    text,
    isHidden,
    hiddenBy,
    hiddenAt,
    createdAt,
    updatedAt,
    isDeleted,
    deletedAt,
    deletedBy,
  ];
}
