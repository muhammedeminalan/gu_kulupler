import 'package:equatable/equatable.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/core/base_fields.dart';
import 'package:gu_data/src/models/fcm_token_model.dart';
import 'package:gu_data/src/utils/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user_account_model.g.dart';

/// Kullanıcının gizli hesap bilgileri — `users/{uid}/private/account`
/// (PLAN §9.6.2, domain-model §2.2).
///
/// E-posta yalnızca burada tutulur (D-29); belgeyi sahibi ve (ADM-05 e-posta
/// araması için) süper admin okur. Belge kimliği sabittir
/// (`FirestoreCollections.accountDoc`), bu yüzden modelde kimlik alanı yoktur.
@JsonSerializable()
final class UserAccountModel extends Equatable with BaseFields {
  /// Hesap belgesi oluşturur.
  const UserAccountModel({
    required this.email,
    required this.emailLower,
    this.fcmTokens = const [],
    this.lastLoginAt,
    this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
  });

  /// Firestore map'inden model üretir.
  ///
  /// Eksik alanlar yapıcı varsayılanını alır, tanınmayan anahtarlar yok
  /// sayılır. Zorunlu alan eksikse `CheckedFromJsonException` fırlatır.
  factory UserAccountModel.fromJson(Map<String, Object?> json) =>
      _$UserAccountModelFromJson(json);

  /// Kurumsal e-posta adresi (Auth belirtecindeki adresle aynı). Hesap
  /// silindiğinde boş dizgi olur.
  @JsonKey(name: FirestoreFields.email)
  final String email;

  /// [email] alanının ASCII küçük harfli hali; e-postaya göre aralık sorgusu
  /// içindir (ADM-05).
  @JsonKey(name: FirestoreFields.emailLower)
  final String emailLower;

  /// Cihaz bildirim belirteçleri (en çok `Limits.fcmTokensMax`). Mod C'de hep
  /// boştur (Q-02).
  @JsonKey(name: FirestoreFields.fcmTokens)
  final List<FcmTokenModel> fcmTokens;

  /// Son oturum açma anı (sunucu zamanı, UTC).
  @JsonKey(name: FirestoreFields.lastLoginAt)
  @TimestampConverter()
  final DateTime? lastLoginAt;

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

  /// Bu belge `createdBy` taşımaz; sahibi üst belgenin `uid`'idir.
  @override
  String? get createdBy => null;

  /// Firestore'a yazılacak map. `null` alanlar yazılmaz; zaman alanları
  /// `Timestamp`, [fcmTokens] elemanları map olur.
  Map<String, Object?> toJson() => _$UserAccountModelToJson(this);

  /// Verilen alanları değiştirilmiş kopya.
  ///
  /// `null` olabilen bir alanı `null` yapmak için ilgili `clear…` bayrağı
  /// `true` verilir; bayrak aynı alan için verilen değerden önce gelir.
  UserAccountModel copyWith({
    String? email,
    String? emailLower,
    List<FcmTokenModel>? fcmTokens,
    DateTime? lastLoginAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
    String? deletedBy,
    bool clearLastLoginAt = false,
    bool clearCreatedAt = false,
    bool clearUpdatedAt = false,
    bool clearDeletedAt = false,
    bool clearDeletedBy = false,
  }) => UserAccountModel(
    email: email ?? this.email,
    emailLower: emailLower ?? this.emailLower,
    fcmTokens: fcmTokens ?? this.fcmTokens,
    lastLoginAt: clearLastLoginAt ? null : lastLoginAt ?? this.lastLoginAt,
    createdAt: clearCreatedAt ? null : createdAt ?? this.createdAt,
    updatedAt: clearUpdatedAt ? null : updatedAt ?? this.updatedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
    deletedBy: clearDeletedBy ? null : deletedBy ?? this.deletedBy,
  );

  @override
  List<Object?> get props => [
    email,
    emailLower,
    fcmTokens,
    lastLoginAt,
    createdAt,
    updatedAt,
    isDeleted,
    deletedAt,
    deletedBy,
  ];
}
