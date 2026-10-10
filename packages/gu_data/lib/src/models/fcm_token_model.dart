import 'package:equatable/equatable.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/utils/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'fcm_token_model.g.dart';

/// Bir cihazın anlık bildirim belirteci — `account.fcmTokens[]` elemanı
/// (PLAN §9.6.2, domain-model §2.2).
///
/// Gömülü modeldir: kendi belgesi ve `BaseFields` alanları yoktur. Mod C'de
/// (Q-02) liste hep boştur; model Mod F geçişi için hazırdır.
@JsonSerializable()
final class FcmTokenModel extends Equatable {
  /// Belirteç kaydı oluşturur.
  const FcmTokenModel({
    required this.token,
    required this.platform,
    required this.updatedAt,
  });

  /// Firestore map'inden model üretir. Eksik ya da `null` [updatedAt]
  /// `CheckedFromJsonException` fırlatır.
  factory FcmTokenModel.fromJson(Map<String, Object?> json) =>
      _$FcmTokenModelFromJson(json);

  /// FCM kayıt belirteci (boş olamaz).
  @JsonKey(name: FirestoreFields.token)
  final String token;

  /// Cihaz platformu: `'ios'` ya da `'android'` (`Limits.platforms`).
  @JsonKey(name: FirestoreFields.platform)
  final String platform;

  /// Belirtecin son yazıldığı an (UTC). Dizi elemanı olduğu için sunucu
  /// zamanı kullanılamaz; **istemci** zamanıdır ve zorunludur.
  @JsonKey(name: FirestoreFields.updatedAt)
  @RequiredTimestampConverter()
  final DateTime updatedAt;

  /// Firestore'a yazılacak map.
  Map<String, Object?> toJson() => _$FcmTokenModelToJson(this);

  /// Verilen alanları değiştirilmiş kopya.
  FcmTokenModel copyWith({
    String? token,
    String? platform,
    DateTime? updatedAt,
  }) => FcmTokenModel(
    token: token ?? this.token,
    platform: platform ?? this.platform,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  List<Object?> get props => [token, platform, updatedAt];
}
