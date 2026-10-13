import 'package:equatable/equatable.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/core/base_fields.dart';
import 'package:gu_data/src/utils/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'membership_contact_model.g.dart';

/// Başvuranın iletişim bilgisi ve başvuru notu —
/// `memberships/{id}/private/contact` alt belgesi (PLAN §9.6.5, domain-model
/// §2.4; D-29, CD-137).
///
/// E-posta ve başvuru notu yalnızca burada tutulur: sahibi, kulüp yöneticisi /
/// danışmanı ve süper admin okur; sıradan üyeler okuyamaz. Belge kimliği
/// sabittir (`FirestoreCollections.contactDoc`), bu yüzden modelde `id` alanı
/// yoktur. Hesap silinince üç alan da boş dizgi olur
/// (`Anonymization.contactPayload`).
@JsonSerializable()
final class MembershipContactModel extends Equatable with BaseFields {
  /// İletişim kaydı oluşturur.
  const MembershipContactModel({
    required this.email,
    required this.emailLower,
    this.note = '',
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

  /// Başvuru notu — başvuranın kulüp yöneticilerine yazdığı serbest metin
  /// (≤ `Limits.applicationNoteMax`; kulüp `requireNote` ise boş olamaz).
  ///
  /// Üyelik belgesinde değil burada durur (CD-137): onaydan sonra da yalnızca
  /// sahibi ve kulüp yönetimi görür. Not yazılmamış başvuruda boş dizgidir.
  @JsonKey(name: FirestoreFields.note)
  final String note;

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
    String? note,
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
    note: note ?? this.note,
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
    note,
    createdAt,
    updatedAt,
    isDeleted,
    deletedAt,
    deletedBy,
  ];
}
