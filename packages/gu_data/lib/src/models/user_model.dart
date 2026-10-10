import 'package:equatable/equatable.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/core/base_fields.dart';
import 'package:gu_data/src/models/enums/user_status.dart';
import 'package:gu_data/src/models/enums/year_level.dart';
import 'package:gu_data/src/utils/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

/// Kullanıcının herkese açık profili — `users/{uid}` (PLAN §9.6.1,
/// domain-model §2.1).
///
/// E-posta bu modelde **yoktur** (D-29); `UserAccountModel` içindedir. Süper
/// admin bir alan değil ID token claim'idir (D-28).
///
/// Belge kimliği ([uid]) JSON'a yazılmaz ve JSON'dan okunmaz: okurken
/// [UserModel.fromJson] çağrısına `id` olarak verilir.
@JsonSerializable()
final class UserModel extends Equatable with BaseFields {
  /// Kullanıcı profili oluşturur.
  const UserModel({
    required this.name,
    required this.nameLower,
    required this.avatarSeed,
    this.uid = '',
    this.avatarPath,
    this.department,
    this.year,
    this.interests = const [],
    this.bio = '',
    this.status = UserStatus.active,
    this.suspendReason,
    this.staff = false,
    this.profileComplete = false,
    this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
  });

  /// Firestore map'inden model üretir; [id] belgenin kimliğidir (`uid`).
  ///
  /// Eksik alanlar yapıcı varsayılanını alır, tanınmayan anahtarlar yok
  /// sayılır. Zorunlu alan eksikse ya da `status` bilinmeyen bir değerse
  /// `CheckedFromJsonException` fırlatır; bilinmeyen `year` `null` okunur.
  factory UserModel.fromJson(Map<String, Object?> json, {required String id}) =>
      _$UserModelFromJson(json).copyWith(uid: id);

  /// Belge kimliği: Firebase Auth `uid`'i.
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String uid;

  /// Görünen ad (`Limits.nameMin`–`Limits.nameMax`). Hesap silindiğinde
  /// `Anonymization.deletedUserName` olur.
  @JsonKey(name: FirestoreFields.name)
  final String name;

  /// [name] alanının Türkçe kurallarıyla küçük harfli hali; ada göre aralık
  /// sorgusu içindir (ADM-05). Değeri çağıran üretir (CD-11): `gu_data`
  /// Türkçe harf dönüşümü yapmaz.
  @JsonKey(name: FirestoreFields.nameLower)
  final String nameLower;

  /// Avatar rengi ve harfi için tohum (boş olamaz).
  @JsonKey(name: FirestoreFields.avatarSeed)
  final String avatarSeed;

  /// Profil fotoğrafının Storage yolu (`users/{uid}/{file}`); fotoğraf yoksa
  /// `null`.
  @JsonKey(name: FirestoreFields.avatarPath)
  final String? avatarPath;

  /// Bölüm kimliği (`StaticTables.departmentIds`: `d01`–`d24`).
  @JsonKey(name: FirestoreFields.department)
  final String? department;

  /// Sınıf / öğrenim düzeyi. Tanınmayan bir değer `null` okunur.
  @JsonKey(
    name: FirestoreFields.year,
    unknownEnumValue: JsonKey.nullForUndefinedEnumValue,
  )
  final YearLevel? year;

  /// İlgi alanı kimlikleri (`StaticTables.interestIds`). Öğrencide
  /// `Limits.interestsMin`–`Limits.interestsMax`; personelde ve silinmiş
  /// hesapta boş olabilir.
  @JsonKey(name: FirestoreFields.interests)
  final List<String> interests;

  /// Kısa biyografi (en çok `Limits.bioMax` karakter).
  @JsonKey(name: FirestoreFields.bio)
  final String bio;

  /// Hesap durumu; yalnızca süper admin ya da hesap silme akışı değiştirir.
  @JsonKey(name: FirestoreFields.status)
  final UserStatus status;

  /// Askıya alma gerekçesi; yalnızca [status] `suspended` iken doludur.
  @JsonKey(name: FirestoreFields.suspendReason)
  final String? suspendReason;

  /// Akademik / idari personel mi? Yalnızca seed ve yönetim betiği yazar.
  @JsonKey(name: FirestoreFields.staff)
  final bool staff;

  /// Profil tamamlama adımı (AUT-05) bitti mi?
  @JsonKey(name: FirestoreFields.profileComplete)
  final bool profileComplete;

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

  /// Bu belge `createdBy` taşımaz; kimlik [uid] alanıdır.
  @override
  String? get createdBy => null;

  /// Hesap etkin ve silinmemiş mi?
  bool get isActive => status == UserStatus.active && !isDeleted;

  /// Hesap silinip anonimleştirildi mi?
  bool get isAnonymized => status == UserStatus.deleted;

  /// Firestore'a yazılacak map. Belge kimliği ve `null` alanlar yazılmaz;
  /// zaman alanları `Timestamp` olur (servis ortak alanları sunucu zamanıyla
  /// ezer).
  Map<String, Object?> toJson() => _$UserModelToJson(this);

  /// Verilen alanları değiştirilmiş kopya.
  ///
  /// `null` olabilen bir alanı `null` yapmak için ilgili `clear…` bayrağı
  /// `true` verilir; bayrak aynı alan için verilen değerden önce gelir.
  UserModel copyWith({
    String? uid,
    String? name,
    String? nameLower,
    String? avatarSeed,
    String? avatarPath,
    String? department,
    YearLevel? year,
    List<String>? interests,
    String? bio,
    UserStatus? status,
    String? suspendReason,
    bool? staff,
    bool? profileComplete,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
    String? deletedBy,
    bool clearAvatarPath = false,
    bool clearDepartment = false,
    bool clearYear = false,
    bool clearSuspendReason = false,
    bool clearCreatedAt = false,
    bool clearUpdatedAt = false,
    bool clearDeletedAt = false,
    bool clearDeletedBy = false,
  }) => UserModel(
    uid: uid ?? this.uid,
    name: name ?? this.name,
    nameLower: nameLower ?? this.nameLower,
    avatarSeed: avatarSeed ?? this.avatarSeed,
    avatarPath: clearAvatarPath ? null : avatarPath ?? this.avatarPath,
    department: clearDepartment ? null : department ?? this.department,
    year: clearYear ? null : year ?? this.year,
    interests: interests ?? this.interests,
    bio: bio ?? this.bio,
    status: status ?? this.status,
    suspendReason: clearSuspendReason
        ? null
        : suspendReason ?? this.suspendReason,
    staff: staff ?? this.staff,
    profileComplete: profileComplete ?? this.profileComplete,
    createdAt: clearCreatedAt ? null : createdAt ?? this.createdAt,
    updatedAt: clearUpdatedAt ? null : updatedAt ?? this.updatedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
    deletedBy: clearDeletedBy ? null : deletedBy ?? this.deletedBy,
  );

  @override
  List<Object?> get props => [
    uid,
    name,
    nameLower,
    avatarSeed,
    avatarPath,
    department,
    year,
    interests,
    bio,
    status,
    suspendReason,
    staff,
    profileComplete,
    createdAt,
    updatedAt,
    isDeleted,
    deletedAt,
    deletedBy,
  ];
}
