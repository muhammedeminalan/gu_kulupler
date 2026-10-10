import 'package:equatable/equatable.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:json_annotation/json_annotation.dart';

part 'club_advisor_model.g.dart';

/// Kulüp danışmanı — `clubs.advisor` gömülü nesnesi (PLAN §9.6.3, K-A).
///
/// Danışman bir hesaba bağlanmamış olabilir: o durumda [userId] `null`'dır
/// ve yalnızca ad / ünvan gösterilir.
@JsonSerializable()
final class ClubAdvisorModel extends Equatable {
  /// Danışman kaydı oluşturur.
  const ClubAdvisorModel({
    required this.name,
    required this.title,
    this.userId,
  });

  /// Firestore haritasından üretir.
  factory ClubAdvisorModel.fromJson(Map<String, Object?> json) =>
      _$ClubAdvisorModelFromJson(json);

  /// Ad soyad (ünvansız).
  @JsonKey(name: FirestoreFields.name)
  final String name;

  /// Akademik ünvan; boş dizgi olabilir.
  @JsonKey(name: FirestoreFields.title)
  final String title;

  /// Bağlı kullanıcının uid'i; hesap bağlanmamışsa `null`.
  @JsonKey(name: FirestoreFields.userId)
  final String? userId;

  /// Firestore haritası.
  Map<String, Object?> toJson() => _$ClubAdvisorModelToJson(this);

  /// Verilen alanları değişmiş kopya; `clearUserId` hesabı ayırır.
  ClubAdvisorModel copyWith({
    String? name,
    String? title,
    String? userId,
    bool clearUserId = false,
  }) => ClubAdvisorModel(
    name: name ?? this.name,
    title: title ?? this.title,
    userId: clearUserId ? null : (userId ?? this.userId),
  );

  @override
  List<Object?> get props => [name, title, userId];
}
