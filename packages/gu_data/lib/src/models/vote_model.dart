import 'package:equatable/equatable.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/utils/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'vote_model.g.dart';

/// Anket oyu — `posts/{postId}/votes/{uid}` (PLAN §9.6.7, domain-model §2.5).
///
/// Belge kimliği oy verenin uid'idir: bir kullanıcı bir ankette tek oy
/// verir. Oy **değiştirilemez ve silinemez**; bu yüzden `BaseFields` taşımaz
/// (yalnızca [createdAt]) ve `isDeleted` alanı yoktur.
@JsonSerializable()
final class VoteModel extends Equatable {
  /// Oy oluşturur. [uid] verilmezse boş dizgidir; okunan belgelerde
  /// [VoteModel.fromJson] belge kimliğini verir.
  const VoteModel({required this.optionId, this.uid = '', this.createdAt});

  /// Firestore belge verisinden model üretir; [id] belge kimliğidir — oy
  /// verenin uid'i ([uid]); JSON'da yer almaz. Eksik [optionId]
  /// `CheckedFromJsonException` fırlatır.
  factory VoteModel.fromJson(Map<String, Object?> json, {required String id}) =>
      _$VoteModelFromJson(json).copyWith(uid: id);

  /// Oy verenin uid'i (belge kimliği). JSON'a yazılmaz.
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String uid;

  /// Seçilen seçeneğin kimliği (`poll.options[].id`).
  @JsonKey(name: FirestoreFields.optionId)
  final String optionId;

  /// Oyun verildiği an (sunucu zamanı, UTC); bekleyen yazımda `null`.
  @JsonKey(name: FirestoreFields.createdAt)
  @TimestampConverter()
  final DateTime? createdAt;

  /// Firestore'a yazılacak map. Belge kimliği ve `null` alanlar yer almaz.
  Map<String, Object?> toJson() => _$VoteModelToJson(this);

  /// Verilen alanları değiştirilmiş kopya. [createdAt] alanını `null` yapmak
  /// için [clearCreatedAt] verilir.
  VoteModel copyWith({
    String? uid,
    String? optionId,
    DateTime? createdAt,
    bool clearCreatedAt = false,
  }) => VoteModel(
    uid: uid ?? this.uid,
    optionId: optionId ?? this.optionId,
    createdAt: clearCreatedAt ? null : (createdAt ?? this.createdAt),
  );

  @override
  List<Object?> get props => [uid, optionId, createdAt];
}
