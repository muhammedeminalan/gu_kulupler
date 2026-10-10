import 'package:equatable/equatable.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/models/enums/club_role.dart';
import 'package:json_annotation/json_annotation.dart';

part 'activity_refs_model.g.dart';

/// Günlük kaydının işaret ettiği belgeler — `activity.refs` gömülü nesnesi
/// (PLAN §9.6.13, domain-model §2.11).
///
/// Hangi alanın dolu olduğu türe bağlıdır: üyelik türleri [userId]
/// (`role_changed` ayrıca [role]), etkinlik türleri [eventId], içerik türleri
/// [postId] taşır; `settings_changed` hiçbirini taşımaz.
@JsonSerializable()
final class ActivityRefsModel extends Equatable {
  /// Referans kümesi oluşturur; verilmeyen alan `null` kalır.
  const ActivityRefsModel({this.userId, this.eventId, this.postId, this.role});

  /// Firestore haritasından üretir.
  factory ActivityRefsModel.fromJson(Map<String, Object?> json) =>
      _$ActivityRefsModelFromJson(json);

  /// Eylemin hedefi olan kullanıcı (başvuran / üye).
  @JsonKey(name: FirestoreFields.userId)
  final String? userId;

  /// İlgili etkinlik.
  @JsonKey(name: FirestoreFields.eventId)
  final String? eventId;

  /// İlgili gönderi.
  @JsonKey(name: FirestoreFields.postId)
  final String? postId;

  /// Atanan yeni rol (`role_changed`); bilinmeyen değer `null` okunur.
  @JsonKey(
    name: FirestoreFields.role,
    unknownEnumValue: JsonKey.nullForUndefinedEnumValue,
  )
  final ClubRole? role;

  /// Firestore haritası.
  Map<String, Object?> toJson() => _$ActivityRefsModelToJson(this);

  /// Verilen alanları değişmiş kopya; `clear*` bayrağı alanı `null` yapar.
  ActivityRefsModel copyWith({
    String? userId,
    bool clearUserId = false,
    String? eventId,
    bool clearEventId = false,
    String? postId,
    bool clearPostId = false,
    ClubRole? role,
    bool clearRole = false,
  }) => ActivityRefsModel(
    userId: clearUserId ? null : (userId ?? this.userId),
    eventId: clearEventId ? null : (eventId ?? this.eventId),
    postId: clearPostId ? null : (postId ?? this.postId),
    role: clearRole ? null : (role ?? this.role),
  );

  @override
  List<Object?> get props => [userId, eventId, postId, role];
}
