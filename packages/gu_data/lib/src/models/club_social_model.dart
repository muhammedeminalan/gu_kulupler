import 'package:equatable/equatable.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:json_annotation/json_annotation.dart';

part 'club_social_model.g.dart';

/// Kulübün iletişim bağlantıları — `clubs.social` gömülü nesnesi
/// (PLAN §9.6.3, domain-model §2.3).
///
/// Üç alan da isteğe bağlıdır; kulüp hiç bağlantı girmediyse nesne boş
/// (`const ClubSocialModel()`) yazılır.
@JsonSerializable()
final class ClubSocialModel extends Equatable {
  /// Bağlantı kümesi oluşturur; verilmeyen alan `null` kalır.
  const ClubSocialModel({this.email, this.instagram, this.web});

  /// Firestore haritasından üretir.
  factory ClubSocialModel.fromJson(Map<String, Object?> json) =>
      _$ClubSocialModelFromJson(json);

  /// İletişim e-postası (biçim denetlenir, alan adı kısıtı yoktur).
  @JsonKey(name: FirestoreFields.email)
  final String? email;

  /// Instagram kullanıcı adı; baştaki `@` saklanır.
  @JsonKey(name: FirestoreFields.instagram)
  final String? instagram;

  /// Web sitesi adresi (`http` / `https`).
  @JsonKey(name: FirestoreFields.web)
  final String? web;

  /// Firestore haritası.
  Map<String, Object?> toJson() => _$ClubSocialModelToJson(this);

  /// Verilen alanları değişmiş kopya; `clear*` bayrağı alanı `null` yapar.
  ClubSocialModel copyWith({
    String? email,
    bool clearEmail = false,
    String? instagram,
    bool clearInstagram = false,
    String? web,
    bool clearWeb = false,
  }) => ClubSocialModel(
    email: clearEmail ? null : (email ?? this.email),
    instagram: clearInstagram ? null : (instagram ?? this.instagram),
    web: clearWeb ? null : (web ?? this.web),
  );

  @override
  List<Object?> get props => [email, instagram, web];
}
