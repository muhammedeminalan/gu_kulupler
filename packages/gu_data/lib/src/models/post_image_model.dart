import 'package:equatable/equatable.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:json_annotation/json_annotation.dart';

part 'post_image_model.g.dart';

/// Gönderi görseli — `posts.images[]` elemanı (PLAN §9.6.6, K-B,
/// domain-model §2.5).
///
/// Gömülü modeldir: kendi belgesi ve `BaseFields` alanları yoktur. Boyutlar
/// yükleme anında kaydedilir; liste görsel yüklenmeden doğru en-boy oranıyla
/// yer ayırabilir.
@JsonSerializable()
final class PostImageModel extends Equatable {
  /// Gönderi görseli oluşturur.
  const PostImageModel({required this.path, required this.w, required this.h});

  /// Firestore map'inden model üretir. Eksik alan
  /// `CheckedFromJsonException` fırlatır.
  factory PostImageModel.fromJson(Map<String, Object?> json) =>
      _$PostImageModelFromJson(json);

  /// Storage yolu (`posts/{postId}/{file}`).
  @JsonKey(name: FirestoreFields.path)
  final String path;

  /// Genişlik, piksel (≥ 1).
  @JsonKey(name: FirestoreFields.w)
  final int w;

  /// Yükseklik, piksel (≥ 1).
  @JsonKey(name: FirestoreFields.h)
  final int h;

  /// Firestore'a yazılacak map.
  Map<String, Object?> toJson() => _$PostImageModelToJson(this);

  /// Verilen alanları değiştirilmiş kopya.
  PostImageModel copyWith({String? path, int? w, int? h}) => PostImageModel(
    path: path ?? this.path,
    w: w ?? this.w,
    h: h ?? this.h,
  );

  @override
  List<Object?> get props => [path, w, h];
}
