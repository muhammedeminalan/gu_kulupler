import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';

/// PRF-01'deki bir kulüp satırı: kulüp belgesi + oturumdaki aktif rol.
typedef ProfileClub = ({ClubModel club, ClubRole role});

/// PRF-01 istatistik kartları (`screens-profile.js:12`, `PRF-01.stat.*`).
final class ProfileStats extends Equatable {
  /// Sayımlar.
  const ProfileStats({
    this.clubCount = 0,
    this.eventCount = 0,
    this.pendingCount = 0,
  });

  /// "Kulüp": belgesi okunan aktif üyelikler (prototip `myClubs`).
  final int clubCount;

  /// "Katıldığım etkinlik": yoklaması alınmış kayıtlar (`attended`).
  final int eventCount;

  /// "Bekleyen başvuru": karar bekleyen üyelikler (prototip `pendingOf`).
  final int pendingCount;

  @override
  List<Object?> get props => [clubCount, eventCount, pendingCount];
}

/// PRF-01 "Profil" ekranının durumu (PLAN §12.6, `ProfileViewModel`).
///
/// * [user], [isSuperAdmin] ve [memberships] oturumdan gelir (canlı;
///   `SessionState`); kulüp belgeleri ([clubs]) ve [attendedCount] okunur.
/// * Satırlar ve sayımlar türetilir: [myClubs] (aktif üyelikler, oturum
///   sırasıyla; belgesi okunamayan kulüp atlanır), [managedClubs] (rolü
///   yönetim kurulu / başkan / danışman), [stats].
/// * Profil fotoğrafı değişirken seçilen görsel [avatarPreview]'dır (iyimser);
///   yazım bitince oturum yenilenir ve önizleme kalkar.
final class ProfileState extends Equatable {
  /// Varsayılan: hiçbir şey okunmadı.
  const ProfileState({
    this.user,
    this.isSuperAdmin = false,
    this.memberships = const [],
    this.clubs = const {},
    this.attendedCount = 0,
    this.avatarPreview,
    this.isUpdatingAvatar = false,
    this.isFetching = false,
    this.isRefreshing = false,
    this.isError = false,
  });

  /// Yönetilen kulüp sayılan roller (prototip `managedClubs`,
  /// `actions.js:32`).
  static const Set<ClubRole> managerRoles = {
    ClubRole.board,
    ClubRole.president,
    ClubRole.advisor,
  };

  /// Oturumdaki kullanıcı; oturum çözülmediyse `null`.
  final UserModel? user;

  /// "Süper Admin" rozeti (claim oturumdadır).
  final bool isSuperAdmin;

  /// Kullanıcının üyelikleri (oturum sırasıyla, her durum).
  final List<MembershipModel> memberships;

  /// Aktif üyeliklerin kulüp belgeleri, kimliğe göre.
  final Map<String, ClubModel> clubs;

  /// Yoklaması alınmış (`attended`) katılım kaydı sayısı.
  final int attendedCount;

  /// Yüklenmekte olan yeni profil fotoğrafı (yerel bayt); yoksa `null`.
  final Uint8List? avatarPreview;

  /// Profil fotoğrafı yazımı sürüyor.
  final bool isUpdatingAvatar;

  /// İlk okuma sürüyor (iskelet).
  final bool isFetching;

  /// Çek-yenile sürüyor (içerik kalır).
  final bool isRefreshing;

  /// Okuma başarısız (hata durumu + "Yeniden dene").
  final bool isError;

  /// "Kulüplerim": aktif üyelikler, belgesi okunanlar.
  List<ProfileClub> get myClubs => [
    for (final membership in memberships)
      if (membership.isActiveMember)
        if (clubs[membership.clubId] case final club?)
          (club: club, role: membership.role),
  ];

  /// "Yönettiğim kulüpler": [myClubs] içinde rolü [managerRoles]'ta olanlar.
  List<ProfileClub> get managedClubs => [
    for (final entry in myClubs)
      if (managerRoles.contains(entry.role)) entry,
  ];

  /// İstatistik kartlarının sayıları.
  ProfileStats get stats => ProfileStats(
    clubCount: myClubs.length,
    eventCount: attendedCount,
    pendingCount: memberships
        .where((m) => m.status == MembershipStatus.pending)
        .length,
  );

  @override
  List<Object?> get props => [
    user,
    isSuperAdmin,
    memberships,
    clubs,
    attendedCount,
    avatarPreview,
    isUpdatingAvatar,
    isFetching,
    isRefreshing,
    isError,
  ];

  /// Verilen alanları değiştirilmiş kopya; [clearAvatarPreview]
  /// [avatarPreview]'ı kaldırır ve ondan önce gelir.
  ProfileState copyWith({
    UserModel? user,
    bool? isSuperAdmin,
    List<MembershipModel>? memberships,
    Map<String, ClubModel>? clubs,
    int? attendedCount,
    Uint8List? avatarPreview,
    bool clearAvatarPreview = false,
    bool? isUpdatingAvatar,
    bool? isFetching,
    bool? isRefreshing,
    bool? isError,
  }) => ProfileState(
    user: user ?? this.user,
    isSuperAdmin: isSuperAdmin ?? this.isSuperAdmin,
    memberships: memberships ?? this.memberships,
    clubs: clubs ?? this.clubs,
    attendedCount: attendedCount ?? this.attendedCount,
    avatarPreview: clearAvatarPreview
        ? null
        : avatarPreview ?? this.avatarPreview,
    isUpdatingAvatar: isUpdatingAvatar ?? this.isUpdatingAvatar,
    isFetching: isFetching ?? this.isFetching,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isError: isError ?? this.isError,
  );
}
