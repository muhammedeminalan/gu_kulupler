import 'package:equatable/equatable.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/models/activity_refs_model.dart';
import 'package:gu_data/src/models/enums/activity_category.dart';
import 'package:gu_data/src/models/enums/activity_kind.dart';
import 'package:gu_data/src/utils/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'activity_model.g.dart';

/// Kulüp etkinlik günlüğü kaydı — `activity/{id}` belgesi (PLAN §9.6.13,
/// domain-model §2.11).
///
/// **Değiştirilemez günlük:** `BaseFields` taşımaz (yalnızca [createdAt]),
/// güncellenmez ve soft delete edilmez; bu yüzden `isDeleted` alanı yoktur.
/// Belge kimliği [id] JSON'a girmez.
@JsonSerializable()
final class ActivityModel extends Equatable {
  /// Günlük kaydı oluşturur.
  ///
  /// [id] verilmezse boş dizgidir (henüz yazılmamış belge; kimlik Firestore
  /// otomatik kimliğidir).
  const ActivityModel({
    required this.clubId,
    required this.actorId,
    required this.kind,
    this.id = '',
    this.refs = const ActivityRefsModel(),
    this.createdAt,
  });

  /// Firestore belge verisinden üretir; [id] belge kimliğidir (veride
  /// `id` anahtarı olsa da okunmaz).
  factory ActivityModel.fromJson(
    Map<String, Object?> json, {
    required String id,
  }) => _$ActivityModelFromJson(json).copyWith(id: id);

  /// Belge kimliği (JSON'a yazılmaz).
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String id;

  /// Kaydın ait olduğu kulüp.
  @JsonKey(name: FirestoreFields.clubId)
  final String clubId;

  /// Eylemi yapan kullanıcının uid'i.
  @JsonKey(name: FirestoreFields.actorId)
  final String actorId;

  /// Kaydın türü; bu istemcinin tanımadığı değer [ActivityKind.unknown]
  /// okunur (ileri uyumluluk).
  @JsonKey(
    name: FirestoreFields.kind,
    unknownEnumValue: ActivityKind.unknown,
  )
  final ActivityKind kind;

  /// Kaydın işaret ettiği belgeler (türe göre dolu).
  @JsonKey(name: FirestoreFields.refs)
  final ActivityRefsModel refs;

  /// Kaydın yazıldığı an (sunucu zamanı, UTC); güncellenemez.
  @JsonKey(name: FirestoreFields.createdAt)
  @TimestampConverter()
  final DateTime? createdAt;

  /// MGT-10 süzgeç kategorisi; [ActivityKind.unknown] için `null`.
  ActivityCategory? get category => kind.category;

  /// Firestore'a yazılacak harita ([id] hariç).
  Map<String, Object?> toJson() => _$ActivityModelToJson(this);

  /// Verilen alanları değişmiş kopya; `clearCreatedAt` zamanı `null` yapar.
  ActivityModel copyWith({
    String? id,
    String? clubId,
    String? actorId,
    ActivityKind? kind,
    ActivityRefsModel? refs,
    DateTime? createdAt,
    bool clearCreatedAt = false,
  }) => ActivityModel(
    id: id ?? this.id,
    clubId: clubId ?? this.clubId,
    actorId: actorId ?? this.actorId,
    kind: kind ?? this.kind,
    refs: refs ?? this.refs,
    createdAt: clearCreatedAt ? null : (createdAt ?? this.createdAt),
  );

  @override
  List<Object?> get props => [id, clubId, actorId, kind, refs, createdAt];
}
