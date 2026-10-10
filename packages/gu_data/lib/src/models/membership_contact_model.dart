import 'package:equatable/equatable.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/core/base_fields.dart';
import 'package:gu_data/src/utils/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'membership_contact_model.g.dart';

/// Başvuranın iletişim bilgisi — `memberships/{id}/private/contact` alt
/// belgesi (PLAN §9.6.5, domain-model §2.4; D-29).
///
/// E-posta yalnızca burada tutulur: sahibi, kulüp yöneticisi / danışmanı ve
/// süper admin okur; sıradan üyeler okuyamaz. Belge kimliği sabittir
/// (`FirestoreCollections.contactDoc`), bu yüzden modelde `id` alanı yoktur.
/// Hesap silinince iki alan da boş dizgi olur (`Anonymization.contactPayload`).
@JsonSerializable()
final class MembershipContactModel extends Equatable with BaseFields {
  /// İletişim kaydı oluşturur.
  const MembershipContactModel({
    required this.email,
    required this.emailLower,
    this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
  });

  /// Firestore belge verisinden üretir.
  factory MembershipContactModel.fromJson(Map<String, Object?> json) =>
      _$MembershipContactModelFromJson(json);

  /// Başvuranın e-postası (başvuru anındaki oturum e-postası).
  @JsonKey(name: FirestoreFields.email)
  final String email;

  /// [email]'in küçük harfli kopyası (arama).
  @JsonKey(name: FirestoreFields.emailLower)
  final String emailLower;

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

  /// İletişim belgesi `createdBy` taşımaz (sahibi üyeliğin kullanıcısı).
  @override
  String? get createdBy => null;

  /// Firestore'a yazılacak harita.
  Map<String, Object?> toJson() => _$MembershipContactModelToJson(this);

  /// Verilen alanları değişmiş kopya; `clear*` bayrağı alanı `null` yapar.
  MembershipContactModel copyWith({
    String? email,
    String? emailLower,
    DateTime? createdAt,
    bool clearCreatedAt = false,
    DateTime? updatedAt,
    bool clearUpdatedAt = false,
    bool? isDeleted,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    String? deletedBy,
    bool clearDeletedBy = false,
  }) => MembershipContactModel(
    email: email ?? this.email,
    emailLower: emailLower ?? this.emailLower,
    createdAt: clearCreatedAt ? null : (createdAt ?? this.createdAt),
    updatedAt: clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    deletedBy: clearDeletedBy ? null : (deletedBy ?? this.deletedBy),
  );

  @override
  List<Object?> get props => [
    email,
    emailLower,
    createdAt,
    updatedAt,
    isDeleted,
    deletedAt,
    deletedBy,
  ];
}
