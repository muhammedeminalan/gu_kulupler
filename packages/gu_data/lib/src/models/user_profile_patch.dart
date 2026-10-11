import 'package:equatable/equatable.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/models/enums/year_level.dart';

/// `users/{uid}` belgesinde sahibinin değiştirebildiği alanların yaması
/// (PLAN §10.4 `UserRepository.updateProfile`; rules-spec §3.1 U).
///
/// Yalnızca **verilen** alanlar yazılır ([toJson]); verilmeyen alan belgede
/// olduğu gibi kalır. `status`, `staff`, `suspendReason` ve soft delete
/// alanları bu yamayla **değiştirilemez** (tipte yoktur; Rules da reddeder).
///
/// [nameLower] değerini çağıran üretir (ViewModel `name.trLower()`, CD-11) ve
/// [name] ile **birlikte** verir; `gu_data` Türkçe harf dönüşümü yapmaz.
final class UserProfilePatch extends Equatable {
  /// Verilen alanları taşıyan yama. [clearAvatarPath] profil fotoğrafını
  /// kaldırır (`avatarPath: null`, SHT-16 "Fotoğrafı kaldır") ve
  /// [avatarPath] ile birlikte verilemez.
  const UserProfilePatch({
    this.name,
    this.nameLower,
    this.avatarSeed,
    this.avatarPath,
    this.department,
    this.year,
    this.interests,
    this.bio,
    this.profileComplete,
    this.clearAvatarPath = false,
  }) : assert(
         !clearAvatarPath || avatarPath == null,
         'clearAvatarPath ile avatarPath birlikte verilemez',
       );

  /// Görünen ad (`Limits.nameMin`–`Limits.nameMax`).
  final String? name;

  /// [name] alanının Türkçe küçük harfli hali (çağıran üretir, CD-11).
  final String? nameLower;

  /// Avatar tohumu (boş olamaz).
  final String? avatarSeed;

  /// Profil fotoğrafının Storage yolu (`users/{uid}/{file}`).
  final String? avatarPath;

  /// Bölüm kimliği (`StaticTables.departmentIds`).
  final String? department;

  /// Sınıf / öğrenim düzeyi.
  final YearLevel? year;

  /// İlgi alanı kimlikleri (`StaticTables.interestIds`).
  final List<String>? interests;

  /// Kısa biyografi (≤ `Limits.bioMax`).
  final String? bio;

  /// Profil tamamlama adımı (AUT-05) bitti mi?
  final bool? profileComplete;

  /// `true` ise `avatarPath` alanı `null` yazılır (fotoğraf kaldırılır).
  final bool clearAvatarPath;

  /// Yama hiçbir alan taşımıyor mu?
  bool get isEmpty => toJson().isEmpty;

  /// Firestore `update` yükü: yalnızca verilen alanlar ([clearAvatarPath]
  /// verildiyse `avatarPath: null`). `updatedAt` servis tarafından eklenir.
  Map<String, Object?> toJson() => {
    FirestoreFields.name: ?name,
    FirestoreFields.nameLower: ?nameLower,
    FirestoreFields.avatarSeed: ?avatarSeed,
    if (clearAvatarPath)
      FirestoreFields.avatarPath: null
    else
      FirestoreFields.avatarPath: ?avatarPath,
    FirestoreFields.department: ?department,
    FirestoreFields.year: ?year?.json,
    FirestoreFields.interests: ?interests,
    FirestoreFields.bio: ?bio,
    FirestoreFields.profileComplete: ?profileComplete,
  };

  @override
  List<Object?> get props => [
    name,
    nameLower,
    avatarSeed,
    avatarPath,
    department,
    year,
    interests,
    bio,
    profileComplete,
    clearAvatarPath,
  ];
}
