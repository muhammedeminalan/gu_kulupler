import 'package:equatable/equatable.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/constants/firestore_ids.dart';
import 'package:gu_data/src/core/base_fields.dart';
import 'package:gu_data/src/models/club_advisor_model.dart';
import 'package:gu_data/src/models/club_social_model.dart';
import 'package:gu_data/src/models/enums/club_palette.dart';
import 'package:gu_data/src/models/enums/club_pattern.dart';
import 'package:gu_data/src/models/enums/club_status.dart';
import 'package:gu_data/src/utils/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'club_model.g.dart';

/// Öğrenci kulübü — `clubs/{clubId}` belgesi (PLAN §9.6.3,
/// domain-model §2.3).
///
/// Belge kimliği [id] JSON'a girmez: okurken `fromJson(json, id: …)` ile
/// verilir, yazarken belge yolundan gelir. Zaman alanları UTC'dir ve sunucu
/// zamanı beklenirken `null` olabilir (PLAN §9.2).
@JsonSerializable()
final class ClubModel extends Equatable with BaseFields {
  /// Kulüp oluşturur.
  ///
  /// [id] verilmezse boş dizgidir (henüz yazılmamış belge); [coverSeed]
  /// verilmezse [id]'den türetilir (`FirestoreIds.clubCoverSeed`).
  const ClubModel({
    required this.name,
    required this.nameLower,
    required this.categoryId,
    required this.iconName,
    required this.palette,
    required this.pattern,
    required this.founded,
    required this.presidentId,
    this.id = '',
    this._coverSeed,
    this.logoPath,
    this.coverPath,
    this.memberCount = 0,
    this.approvalRequired = true,
    this.applicationsOpen = true,
    this.requireNote = false,
    this.summary = '',
    this.about = '',
    this.conditions = const [],
    this.social = const ClubSocialModel(),
    this.pinnedPostId,
    this.advisor,
    this.status = ClubStatus.active,
    this.suspendReason,
    this.lastMembershipRef,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
  });

  /// Firestore belge verisinden üretir; [id] belge kimliğidir (veride
  /// `id` anahtarı olsa da okunmaz).
  factory ClubModel.fromJson(
    Map<String, Object?> json, {
    required String id,
  }) => _$ClubModelFromJson(json).copyWith(id: id);

  /// Belge kimliği (JSON'a yazılmaz).
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String id;

  /// Kulüp adı; yalnızca süper admin değiştirir.
  @JsonKey(name: FirestoreFields.name)
  final String name;

  /// Adın Türkçe küçük harfli kopyası (arama ve benzersizlik sorgusu);
  /// değeri uygulama katmanı üretir (CD-11).
  @JsonKey(name: FirestoreFields.nameLower)
  final String nameLower;

  /// Kategori kimliği (`StaticTables` — `k01`…`k08`).
  @JsonKey(name: FirestoreFields.categoryId)
  final String categoryId;

  /// Kulüp ikonunun adı (Lucide).
  @JsonKey(name: FirestoreFields.iconName)
  final String iconName;

  /// Kapak renk paleti.
  @JsonKey(name: FirestoreFields.palette)
  final ClubPalette palette;

  /// Kapak deseni.
  @JsonKey(name: FirestoreFields.pattern)
  final ClubPattern pattern;

  /// Açıkça verilmiş kapak tohumu; `null` ise [coverSeed] [id]'den türer.
  final String? _coverSeed;

  /// Kapak deseni tohumu; verilmediyse `FirestoreIds.clubCoverSeed(id)`.
  @JsonKey(name: FirestoreFields.coverSeed)
  String get coverSeed => _coverSeed ?? FirestoreIds.clubCoverSeed(id);

  /// Logo dosyasının Storage yolu; yoksa `null`.
  @JsonKey(name: FirestoreFields.logoPath)
  final String? logoPath;

  /// Yüklenmiş kapak görselinin Storage yolu; yoksa tasarım kapağı çizilir.
  @JsonKey(name: FirestoreFields.coverPath)
  final String? coverPath;

  /// Aktif üye sayısı (danışman hariç); yalnızca ±1 batch'iyle değişir.
  @JsonKey(name: FirestoreFields.memberCount)
  final int memberCount;

  /// Katılım yönetici onayı gerektiriyor mu?
  @JsonKey(name: FirestoreFields.approvalRequired)
  final bool approvalRequired;

  /// Başvurular açık mı?
  @JsonKey(name: FirestoreFields.applicationsOpen)
  final bool applicationsOpen;

  /// Başvuruda not zorunlu mu?
  @JsonKey(name: FirestoreFields.requireNote)
  final bool requireNote;

  /// Kuruluş yılı.
  @JsonKey(name: FirestoreFields.founded)
  final int founded;

  /// Kısa tanıtım.
  @JsonKey(name: FirestoreFields.summary)
  final String summary;

  /// Uzun tanıtım.
  @JsonKey(name: FirestoreFields.about)
  final String about;

  /// Katılım koşulları.
  @JsonKey(name: FirestoreFields.conditions)
  final List<String> conditions;

  /// İletişim bağlantıları.
  @JsonKey(name: FirestoreFields.social)
  final ClubSocialModel social;

  /// Başkanın uid'i; üyelik belgesindeki `president` rolüyle tutarlıdır.
  @JsonKey(name: FirestoreFields.presidentId)
  final String presidentId;

  /// Sabitlenmiş gönderinin kimliği (kulüp başına en çok bir); yoksa `null`.
  @JsonKey(name: FirestoreFields.pinnedPostId)
  final String? pinnedPostId;

  /// Danışman; atanmadıysa `null`.
  @JsonKey(name: FirestoreFields.advisor)
  final ClubAdvisorModel? advisor;

  /// Kulübün durumu.
  @JsonKey(name: FirestoreFields.status)
  final ClubStatus status;

  /// Askıya alma gerekçesi; yalnızca askıdayken dolu.
  @JsonKey(name: FirestoreFields.suspendReason)
  final String? suspendReason;

  /// `memberCount`'u son değiştiren batch'teki üyelik belgesinin yolu
  /// (CD-41); sayaç hiç değişmediyse `null`.
  @JsonKey(name: FirestoreFields.lastMembershipRef)
  final String? lastMembershipRef;

  @override
  @JsonKey(name: FirestoreFields.createdBy)
  final String? createdBy;

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

  /// Kulüp askıya alınmış mı?
  bool get isSuspended => status == ClubStatus.suspended;

  /// Kulübün yüklenmiş bir kapak görseli var mı?
  bool get hasCustomCover => coverPath != null;

  /// Firestore'a yazılacak harita ([id] hariç).
  Map<String, Object?> toJson() => _$ClubModelToJson(this);

  /// Verilen alanları değişmiş kopya; `clear*` bayrağı alanı `null` yapar.
  ///
  /// [coverSeed] açıkça verilmediyse türetilmiş kalır ve yeni [id]'yi izler.
  ClubModel copyWith({
    String? id,
    String? name,
    String? nameLower,
    String? categoryId,
    String? iconName,
    ClubPalette? palette,
    ClubPattern? pattern,
    String? coverSeed,
    String? logoPath,
    bool clearLogoPath = false,
    String? coverPath,
    bool clearCoverPath = false,
    int? memberCount,
    bool? approvalRequired,
    bool? applicationsOpen,
    bool? requireNote,
    int? founded,
    String? summary,
    String? about,
    List<String>? conditions,
    ClubSocialModel? social,
    String? presidentId,
    String? pinnedPostId,
    bool clearPinnedPostId = false,
    ClubAdvisorModel? advisor,
    bool clearAdvisor = false,
    ClubStatus? status,
    String? suspendReason,
    bool clearSuspendReason = false,
    String? lastMembershipRef,
    bool clearLastMembershipRef = false,
    String? createdBy,
    bool clearCreatedBy = false,
    DateTime? createdAt,
    bool clearCreatedAt = false,
    DateTime? updatedAt,
    bool clearUpdatedAt = false,
    bool? isDeleted,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    String? deletedBy,
    bool clearDeletedBy = false,
  }) => ClubModel(
    id: id ?? this.id,
    name: name ?? this.name,
    nameLower: nameLower ?? this.nameLower,
    categoryId: categoryId ?? this.categoryId,
    iconName: iconName ?? this.iconName,
    palette: palette ?? this.palette,
    pattern: pattern ?? this.pattern,
    coverSeed: coverSeed ?? _coverSeed,
    logoPath: clearLogoPath ? null : (logoPath ?? this.logoPath),
    coverPath: clearCoverPath ? null : (coverPath ?? this.coverPath),
    memberCount: memberCount ?? this.memberCount,
    approvalRequired: approvalRequired ?? this.approvalRequired,
    applicationsOpen: applicationsOpen ?? this.applicationsOpen,
    requireNote: requireNote ?? this.requireNote,
    founded: founded ?? this.founded,
    summary: summary ?? this.summary,
    about: about ?? this.about,
    conditions: conditions ?? this.conditions,
    social: social ?? this.social,
    presidentId: presidentId ?? this.presidentId,
    pinnedPostId: clearPinnedPostId
        ? null
        : (pinnedPostId ?? this.pinnedPostId),
    advisor: clearAdvisor ? null : (advisor ?? this.advisor),
    status: status ?? this.status,
    suspendReason: clearSuspendReason
        ? null
        : (suspendReason ?? this.suspendReason),
    lastMembershipRef: clearLastMembershipRef
        ? null
        : (lastMembershipRef ?? this.lastMembershipRef),
    createdBy: clearCreatedBy ? null : (createdBy ?? this.createdBy),
    createdAt: clearCreatedAt ? null : (createdAt ?? this.createdAt),
    updatedAt: clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    deletedBy: clearDeletedBy ? null : (deletedBy ?? this.deletedBy),
  );

  @override
  List<Object?> get props => [
    id,
    name,
    nameLower,
    categoryId,
    iconName,
    palette,
    pattern,
    coverSeed,
    logoPath,
    coverPath,
    memberCount,
    approvalRequired,
    applicationsOpen,
    requireNote,
    founded,
    summary,
    about,
    conditions,
    social,
    presidentId,
    pinnedPostId,
    advisor,
    status,
    suspendReason,
    lastMembershipRef,
    createdBy,
    createdAt,
    updatedAt,
    isDeleted,
    deletedAt,
    deletedBy,
  ];
}
