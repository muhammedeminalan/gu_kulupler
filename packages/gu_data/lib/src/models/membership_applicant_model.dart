import 'package:equatable/equatable.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/models/enums/year_level.dart';
import 'package:json_annotation/json_annotation.dart';

part 'membership_applicant_model.g.dart';

/// Başvuranın **başvuru anındaki** anlık görüntüsü — `memberships.applicant`
/// gömülü nesnesi (PLAN §9.6.4, domain-model §2.4).
///
/// E-posta taşımaz (D-29): e-posta yalnızca
/// `memberships/{id}/private/contact` alt belgesindedir. Hesap silinince
/// anlık görüntü bütünüyle anonimleştirilir (`Anonymization.applicantPayload`).
@JsonSerializable()
final class MembershipApplicantModel extends Equatable {
  /// Anlık görüntü oluşturur.
  const MembershipApplicantModel({
    required this.name,
    required this.avatarSeed,
    this.department,
    this.year,
  });

  /// Firestore haritasından üretir.
  factory MembershipApplicantModel.fromJson(Map<String, Object?> json) =>
      _$MembershipApplicantModelFromJson(json);

  /// Ad soyad (`users.name` kopyası).
  @JsonKey(name: FirestoreFields.name)
  final String name;

  /// Bölüm kimliği; personelde ya da anonimleştirmede `null`.
  @JsonKey(name: FirestoreFields.department)
  final String? department;

  /// Sınıf düzeyi; bilinmeyen ya da eksik değer `null` okunur.
  @JsonKey(
    name: FirestoreFields.year,
    unknownEnumValue: JsonKey.nullForUndefinedEnumValue,
  )
  final YearLevel? year;

  /// Avatar tohumu (zorunlu; anonimleştirmede sabit değer alır).
  @JsonKey(name: FirestoreFields.avatarSeed)
  final String avatarSeed;

  /// Firestore haritası.
  Map<String, Object?> toJson() => _$MembershipApplicantModelToJson(this);

  /// Verilen alanları değişmiş kopya; `clear*` bayrağı alanı `null` yapar.
  MembershipApplicantModel copyWith({
    String? name,
    String? department,
    bool clearDepartment = false,
    YearLevel? year,
    bool clearYear = false,
    String? avatarSeed,
  }) => MembershipApplicantModel(
    name: name ?? this.name,
    department: clearDepartment ? null : (department ?? this.department),
    year: clearYear ? null : (year ?? this.year),
    avatarSeed: avatarSeed ?? this.avatarSeed,
  );

  @override
  List<Object?> get props => [name, department, year, avatarSeed];
}
