import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';

/// CLB-07 "Profil" ekranının durumu (PLAN §12.6, `UserProfileViewModel`).
///
/// Ortak kulüp gizliliği arayüz katmanındadır (D-29, S-1): `users/{uid}`
/// doğrulanmış her kullanıcıya okunur; bakanın profili görme hakkı yoksa
/// [isHiddenByPrivacy] `true` olur ve ekran bölüm / sınıf, biyografi ve
/// ortak kulüpleri çizmez.
final class UserProfileState extends Equatable {
  /// Varsayılan: kullanıcı okunmadı.
  const UserProfileState({
    this.user,
    this.sharedClubIds = const [],
    this.sharedClubs = const [],
    this.roles = const [],
    this.contextMembership,
    this.isSelf = false,
    this.isSuperAdmin = false,
    this.isHiddenByPrivacy = false,
    this.isBlocked = false,
    this.isFetching = false,
    this.isError = false,
    this.isNotFound = false,
    this.isActing = false,
  });

  /// Profili açılan kullanıcı; okunmadıysa `null`. Silinmiş (anonimleştirilmiş)
  /// kullanıcı da buradadır ([isDeletedUser]).
  final UserModel? user;

  /// Bakanla ortak kulüpler: ikisinin de **aktif** üye olduğu kulüplerin
  /// kimlikleri (prototip `commonClubs`, `actions.js:66`). Gizlilik kararı
  /// bu listeye bakar; kulüp belgeleri ([sharedClubs]) okunamasa da dolu
  /// kalır.
  final List<String> sharedClubIds;

  /// "Ortak kulüpler" çipleri: [sharedClubIds] kulüplerinin belgeleri
  /// (silinmiş kulüp atlanır).
  final List<ClubModel> sharedClubs;

  /// Kullanıcının ortak kulüplerdeki üye dışı rolleri (başkan, yönetim
  /// kurulu, danışman), [sharedClubIds] sırasıyla — başlıktaki rol rozetleri
  /// (`screens-clubs.js:154`).
  final List<ClubRole> roles;

  /// Kullanıcının açılış kulübündeki (`?clubId=`) üyelik belgesi; yalnızca
  /// bakan o kulübün yöneticisi ya da süper adminse okunur (prototip
  /// `managerCtx`). Her durumda olabilir (bekleyen başvuru dahil).
  final MembershipModel? contextMembership;

  /// Profil oturumdaki kullanıcının kendisi mi (menü çizilmez, engellenemez).
  final bool isSelf;

  /// Kullanıcı süper admin mi (başlıktaki "Süper Admin" rozeti). Claim
  /// yalnızca kişinin kendi oturumunda okunabildiği için yalnızca [isSelf]
  /// iken `true` olabilir.
  final bool isSuperAdmin;

  /// Profil gizli mi: ortak kulüp yok ve bakan süper admin, açılış kulübünün
  /// yöneticisi ya da kullanıcının kendisi değil (D-29).
  final bool isHiddenByPrivacy;

  /// Kullanıcı bakan tarafından engellenmiş mi (iyimser güncellenir).
  final bool isBlocked;

  /// İlk okuma sürüyor (iskelet).
  final bool isFetching;

  /// Okuma başarısız (hata durumu + "Yeniden dene").
  final bool isError;

  /// Kullanıcı belgesi yok (→ SYS-04).
  final bool isNotFound;

  /// Engelle / engeli kaldır yazımı sürüyor.
  final bool isActing;

  /// Kullanıcı silinmiş mi (hesap silme — anonimleştirilmiş belge): ad
  /// "Silinmiş kullanıcı" olarak gösterilir, menü ve ayrıntılar çizilmez.
  bool get isDeletedUser {
    final user = this.user;
    return user != null && (user.isDeleted || user.isAnonymized);
  }

  /// Üst çubukta "⋮" menüsü (SHT-27) çizilir mi: kullanıcı okundu, kendisi
  /// değil ve silinmemiş.
  bool get canOpenMenu => user != null && !isSelf && !isDeletedUser;

  /// Bölüm / sınıf, biyografi ve ortak kulüpler çizilir mi.
  bool get showsDetails => !isHiddenByPrivacy && !isDeletedUser;

  @override
  List<Object?> get props => [
    user,
    sharedClubIds,
    sharedClubs,
    roles,
    contextMembership,
    isSelf,
    isSuperAdmin,
    isHiddenByPrivacy,
    isBlocked,
    isFetching,
    isError,
    isNotFound,
    isActing,
  ];

  /// Verilen alanları değiştirilmiş kopya. [clearContextMembership]
  /// [contextMembership]'i `null` yapar ve aynı adlı parametreden önce gelir.
  UserProfileState copyWith({
    UserModel? user,
    List<String>? sharedClubIds,
    List<ClubModel>? sharedClubs,
    List<ClubRole>? roles,
    MembershipModel? contextMembership,
    bool clearContextMembership = false,
    bool? isSelf,
    bool? isSuperAdmin,
    bool? isHiddenByPrivacy,
    bool? isBlocked,
    bool? isFetching,
    bool? isError,
    bool? isNotFound,
    bool? isActing,
  }) => UserProfileState(
    user: user ?? this.user,
    sharedClubIds: sharedClubIds ?? this.sharedClubIds,
    sharedClubs: sharedClubs ?? this.sharedClubs,
    roles: roles ?? this.roles,
    contextMembership: clearContextMembership
        ? null
        : contextMembership ?? this.contextMembership,
    isSelf: isSelf ?? this.isSelf,
    isSuperAdmin: isSuperAdmin ?? this.isSuperAdmin,
    isHiddenByPrivacy: isHiddenByPrivacy ?? this.isHiddenByPrivacy,
    isBlocked: isBlocked ?? this.isBlocked,
    isFetching: isFetching ?? this.isFetching,
    isError: isError ?? this.isError,
    isNotFound: isNotFound ?? this.isNotFound,
    isActing: isActing ?? this.isActing,
  );
}
