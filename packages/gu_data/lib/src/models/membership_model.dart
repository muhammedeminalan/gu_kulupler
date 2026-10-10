import 'package:equatable/equatable.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/constants/firestore_ids.dart';
import 'package:gu_data/src/core/app_clock.dart';
import 'package:gu_data/src/core/base_fields.dart';
import 'package:gu_data/src/models/enums/club_role.dart';
import 'package:gu_data/src/models/enums/membership_status.dart';
import 'package:gu_data/src/models/enums/reject_reason.dart';
import 'package:gu_data/src/models/membership_applicant_model.dart';
import 'package:gu_data/src/utils/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'membership_model.g.dart';

/// Kullanıcının bir kulüpteki üyeliği / başvurusu —
/// `memberships/{clubId}_{userId}` belgesi (PLAN §9.6.4, domain-model §2.4,
/// §5).
///
/// Üyelik hiç soft delete edilmez: ayrılma, çıkarma ve geri çekme birer
/// **durum geçişidir** ([status]). E-posta bu belgede yoktur (D-29).
/// Belge kimliği [id] JSON'a girmez.
@JsonSerializable()
final class MembershipModel extends Equatable with BaseFields {
  /// Üyelik oluşturur.
  ///
  /// [id] verilmezse `FirestoreIds.membership(clubId, userId)` değeridir.
  const MembershipModel({
    required this.clubId,
    required this.userId,
    required this.applicant,
    this._id,
    this.status = MembershipStatus.pending,
    this.role = ClubRole.member,
    this.note = '',
    this.appliedAt,
    this.decidedAt,
    this.decidedBy,
    this.retryAfter,
    this.rejectReason,
    this.rejectNote,
    this.priorCount = 0,
    this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
  });

  /// Firestore belge verisinden üretir; [id] belge kimliğidir (veride
  /// `id` anahtarı olsa da okunmaz).
  factory MembershipModel.fromJson(
    Map<String, Object?> json, {
    required String id,
  }) => _$MembershipModelFromJson(json).copyWith(id: id);

  /// Açıkça verilmiş belge kimliği; `null` ise [id] alanlardan türer.
  final String? _id;

  /// Belge kimliği (JSON'a yazılmaz); verilmediyse
  /// `FirestoreIds.membership(clubId, userId)`.
  @JsonKey(includeFromJson: false, includeToJson: false)
  String get id => _id ?? FirestoreIds.membership(clubId, userId);

  /// Kulübün kimliği.
  @JsonKey(name: FirestoreFields.clubId)
  final String clubId;

  /// Üyenin / başvuranın uid'i.
  @JsonKey(name: FirestoreFields.userId)
  final String userId;

  /// Üyelik durumu.
  @JsonKey(name: FirestoreFields.status)
  final MembershipStatus status;

  /// Kulüp rolü; yalnızca [status] `active` iken anlamlıdır.
  @JsonKey(name: FirestoreFields.role)
  final ClubRole role;

  /// Başvuru notu.
  @JsonKey(name: FirestoreFields.note)
  final String note;

  /// Başvuranın başvuru anındaki anlık görüntüsü.
  @JsonKey(name: FirestoreFields.applicant)
  final MembershipApplicantModel applicant;

  /// Başvuru anı (sunucu zamanı, UTC).
  @JsonKey(name: FirestoreFields.appliedAt)
  @TimestampConverter()
  final DateTime? appliedAt;

  /// Karar anı — onay, ret ya da çıkarma (sunucu zamanı, UTC).
  @JsonKey(name: FirestoreFields.decidedAt)
  @TimestampConverter()
  final DateTime? decidedAt;

  /// Kararı veren kullanıcının uid'i.
  @JsonKey(name: FirestoreFields.decidedBy)
  final String? decidedBy;

  /// Yeniden başvurunun açılacağı an (ret / çıkarma + bekleme süresi, UTC).
  @JsonKey(name: FirestoreFields.retryAfter)
  @TimestampConverter()
  final DateTime? retryAfter;

  /// Ret nedeni; bilinmeyen ya da eksik değer `null` okunur.
  @JsonKey(
    name: FirestoreFields.rejectReason,
    unknownEnumValue: JsonKey.nullForUndefinedEnumValue,
  )
  final RejectReason? rejectReason;

  /// Ret / çıkarma açıklaması.
  @JsonKey(name: FirestoreFields.rejectNote)
  final String? rejectNote;

  /// Önceki başvuru sayısı; yeniden başvuruda bir artar.
  @JsonKey(name: FirestoreFields.priorCount)
  final int priorCount;

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

  /// Üyelik belgesi `createdBy` taşımaz (sahibi [userId]).
  @override
  String? get createdBy => null;

  /// Kullanıcı kulübün aktif üyesi mi?
  bool get isActiveMember => status == MembershipStatus.active;

  /// Bu üyelik `clubs.memberCount` sayacına dahil mi? Danışman sayılmaz.
  bool get countsTowardMemberCount =>
      status == MembershipStatus.active && role != ClubRole.advisor;

  /// Kullanıcı [clock] anında yeniden başvurabilir mi?
  ///
  /// Yalnızca kapanmış üyeliklerde (`rejected`, `removed`, `left`,
  /// `cancelled`) ve [retryAfter] yoksa ya da dolduysa `true` (Rules M3 / M4:
  /// `request.time >= retryAfter`). `pending` ve `active` için `false`.
  bool canReapplyAt(AppClock clock) {
    final isClosed = switch (status) {
      MembershipStatus.rejected ||
      MembershipStatus.removed ||
      MembershipStatus.left ||
      MembershipStatus.cancelled => true,
      MembershipStatus.pending || MembershipStatus.active => false,
    };
    final retryAfter = this.retryAfter;
    return isClosed &&
        (retryAfter == null || !clock.nowUtc().isBefore(retryAfter));
  }

  /// Firestore'a yazılacak harita ([id] hariç).
  Map<String, Object?> toJson() => _$MembershipModelToJson(this);

  /// Verilen alanları değişmiş kopya; `clear*` bayrağı alanı `null` yapar.
  ///
  /// [id] açıkça verilmediyse türetilmiş kalır ve yeni [clubId] / [userId]
  /// değerlerini izler.
  MembershipModel copyWith({
    String? id,
    String? clubId,
    String? userId,
    MembershipStatus? status,
    ClubRole? role,
    String? note,
    MembershipApplicantModel? applicant,
    DateTime? appliedAt,
    bool clearAppliedAt = false,
    DateTime? decidedAt,
    bool clearDecidedAt = false,
    String? decidedBy,
    bool clearDecidedBy = false,
    DateTime? retryAfter,
    bool clearRetryAfter = false,
    RejectReason? rejectReason,
    bool clearRejectReason = false,
    String? rejectNote,
    bool clearRejectNote = false,
    int? priorCount,
    DateTime? createdAt,
    bool clearCreatedAt = false,
    DateTime? updatedAt,
    bool clearUpdatedAt = false,
    bool? isDeleted,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    String? deletedBy,
    bool clearDeletedBy = false,
  }) => MembershipModel(
    id: id ?? _id,
    clubId: clubId ?? this.clubId,
    userId: userId ?? this.userId,
    status: status ?? this.status,
    role: role ?? this.role,
    note: note ?? this.note,
    applicant: applicant ?? this.applicant,
    appliedAt: clearAppliedAt ? null : (appliedAt ?? this.appliedAt),
    decidedAt: clearDecidedAt ? null : (decidedAt ?? this.decidedAt),
    decidedBy: clearDecidedBy ? null : (decidedBy ?? this.decidedBy),
    retryAfter: clearRetryAfter ? null : (retryAfter ?? this.retryAfter),
    rejectReason: clearRejectReason
        ? null
        : (rejectReason ?? this.rejectReason),
    rejectNote: clearRejectNote ? null : (rejectNote ?? this.rejectNote),
    priorCount: priorCount ?? this.priorCount,
    createdAt: clearCreatedAt ? null : (createdAt ?? this.createdAt),
    updatedAt: clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    deletedBy: clearDeletedBy ? null : (deletedBy ?? this.deletedBy),
  );

  @override
  List<Object?> get props => [
    id,
    clubId,
    userId,
    status,
    role,
    note,
    applicant,
    appliedAt,
    decidedAt,
    decidedBy,
    retryAfter,
    rejectReason,
    rejectNote,
    priorCount,
    createdAt,
    updatedAt,
    isDeleted,
    deletedAt,
    deletedBy,
  ];
}
