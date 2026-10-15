import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/navigation/admin_users_filter.dart';
import 'package:gu_ui/gu_ui.dart';

/// ADM-05 arama kipi: girdide `@` varsa e-posta, yoksa ad önekiyle aranır
/// (PLAN §12 `AdminUsersViewModel`).
enum UserSearchMode {
  /// `adminRepository.listUsersByName` (`nameLower` öneki, sayfalı).
  name,

  /// `adminRepository.findUserByEmail` (`emailLower` öneki, tek okuma).
  email;

  /// [query] girdisinin kipi.
  static UserSearchMode of(String query) =>
      query.contains('@') ? UserSearchMode.email : UserSearchMode.name;
}

/// ADM-05 "Kullanıcılar" durumu (PLAN §12 `AdminUsersViewModel`; prototip
/// `AdminUsers`, `screens-admin.js:72–78`).
///
/// * [users] son okumanın sonucudur (ad kipinde sayfalar birikir —
///   [cursor]); süzgeç istemcidedir ([visible]).
/// * [managerUserIds] herhangi bir kulüpte etkin yönetici olanlar
///   (`adminRepository.listManagerUserIds`, `managers` süzgeci).
/// * [clubCounts] satır alt metnindeki "{n} kulüp" — kullanıcının etkin
///   üyelik sayısı (`membershipRepository.listMine`); okunamayan kullanıcıda
///   sayı yazılmaz.
/// * [pendingIds] askı / askıdan çıkarma yazımı süren kullanıcılar.
final class AdminUsersState extends Equatable {
  /// Varsayılan: içerik yok, tümü süzgeci.
  const AdminUsersState({
    this.query = '',
    this.mode = UserSearchMode.name,
    this.filter = AdminUsersFilter.all,
    this.users = const [],
    this.managerUserIds = const {},
    this.clubCounts = const {},
    this.cursor,
    this.pendingIds = const {},
    this.isLoaded = false,
    this.isFetching = false,
    this.isSearching = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.isError = false,
  });

  /// Arama girdisi (`ADM-05.search`; ham metin).
  final String query;

  /// [users] listesini üreten arama kipi.
  final UserSearchMode mode;

  /// Seçili süzgeç (`ADM-05.filter.<name>`).
  final AdminUsersFilter filter;

  /// Okunan kullanıcılar (sorgu sırasıyla; silinmişler gelmez).
  final List<UserModel> users;

  /// Etkin `board` / `president` üyeliği olan kullanıcılar.
  final Set<String> managerUserIds;

  /// Kullanıcı başına etkin üyelik sayısı (`uid` → sayı).
  final Map<String, int> clubCounts;

  /// Ad kipinde sonraki sayfanın imleci; son sayfada / e-posta kipinde
  /// `null`.
  final PageCursor? cursor;

  /// Yazımı süren kullanıcıların kimlikleri.
  final Set<String> pendingIds;

  /// En az bir okuma başarıyla bitti.
  final bool isLoaded;

  /// İlk okuma ya da "Yeniden dene" sürüyor (iskelet).
  final bool isFetching;

  /// Arama okuması sürüyor (iskelet).
  final bool isSearching;

  /// Çek-yenile sürüyor (içerik kalır).
  final bool isRefreshing;

  /// Sonraki sayfa okunuyor (listenin sonunda iskelet).
  final bool isLoadingMore;

  /// Okuma başarısız (hata görünümü + "Yeniden dene").
  final bool isError;

  /// Sonraki sayfa var mı?
  bool get hasMore => cursor != null;

  /// Ekrandaki satırlar: [filter] süzgecinden geçen kullanıcılar, ada göre
  /// (Türkçe; eş adda kimliğe göre — sıra kararlı) sıralı
  /// (`screens-admin.js:74`).
  List<UserModel> get visible =>
      [
        for (final user in users)
          if (switch (filter) {
            AdminUsersFilter.all => true,
            AdminUsersFilter.managers => managerUserIds.contains(user.uid),
            AdminUsersFilter.suspended => user.status == UserStatus.suspended,
          })
            user,
      ]..sort((a, b) {
        final byName = a.name.trCompareTo(b.name);
        return byName != 0 ? byName : a.uid.compareTo(b.uid);
      });

  /// [uid] kullanıcısı; listede yoksa `null`.
  UserModel? userById(String uid) {
    for (final user in users) {
      if (user.uid == uid) return user;
    }
    return null;
  }

  @override
  List<Object?> get props => [
    query,
    mode,
    filter,
    users,
    managerUserIds,
    clubCounts,
    cursor,
    pendingIds,
    isLoaded,
    isFetching,
    isSearching,
    isRefreshing,
    isLoadingMore,
    isError,
  ];

  /// Değişen alanlarla kopya; [clearCursor] imleci siler.
  AdminUsersState copyWith({
    String? query,
    UserSearchMode? mode,
    AdminUsersFilter? filter,
    List<UserModel>? users,
    Set<String>? managerUserIds,
    Map<String, int>? clubCounts,
    PageCursor? cursor,
    bool clearCursor = false,
    Set<String>? pendingIds,
    bool? isLoaded,
    bool? isFetching,
    bool? isSearching,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? isError,
  }) => AdminUsersState(
    query: query ?? this.query,
    mode: mode ?? this.mode,
    filter: filter ?? this.filter,
    users: users ?? this.users,
    managerUserIds: managerUserIds ?? this.managerUserIds,
    clubCounts: clubCounts ?? this.clubCounts,
    cursor: clearCursor ? null : cursor ?? this.cursor,
    pendingIds: pendingIds ?? this.pendingIds,
    isLoaded: isLoaded ?? this.isLoaded,
    isFetching: isFetching ?? this.isFetching,
    isSearching: isSearching ?? this.isSearching,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    isError: isError ?? this.isError,
  );
}
