import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/navigation/my_clubs_tab.dart';

/// Bir satır: kullanıcının üyeliği + kulübü.
typedef MyClubEntry = (MembershipModel, ClubModel);

/// PRF-03 "Kulüplerim" ekranının durumu (PLAN §12.6).
///
/// * [memberships] kullanıcının **tüm** üyelikleridir (kulüp kimliği →
///   üyelik). Kaynak oturumun canlı üyelik akışıdır
///   (`SessionState.memberships`, `watchMyMemberships` her durumu dinler);
///   çek-yenile `membershipRepository.listMine` ile tazeler. Ayrı bir
///   "geçmiş" sorgusu yoktur — akış ayrılınan / iptal edilen / reddedilen /
///   çıkarılan üyelikleri de taşır.
/// * [clubs] satırların kulüpleridir (`clubRepository.getClubs`, toplu).
///   Kulübü okunamayan (silinmiş) üyelik çizilmez (prototip
///   `.filter((m) => m.club)`).
/// * [pendingIds] yazımı süren (ayrılma / iptal) kulüplerdir: satır iyimser
///   olarak yeni sekmesine geçer, yazım reddedilirse geri döner.
/// * Sekme ayrımı [tabOf]; sıra en yeni karar / başvuru üstte ([dateOf]).
final class MyClubsState extends Equatable {
  /// Varsayılan: içerik yok, "Üyeliklerim" sekmesi.
  const MyClubsState({
    this.tab = MyClubsTab.active,
    this.memberships = const {},
    this.clubs = const {},
    this.pendingIds = const {},
    this.isFetching = false,
    this.isRefreshing = false,
    this.isError = false,
  });

  /// Seçili sekme.
  final MyClubsTab tab;

  /// Kullanıcının üyelikleri, kulüp kimliğine göre.
  final Map<String, MembershipModel> memberships;

  /// Okunan kulüpler, kimliğe göre.
  final Map<String, ClubModel> clubs;

  /// Ayrılma / iptal yazımı süren kulüp kimlikleri.
  final Set<String> pendingIds;

  /// İlk okuma sürüyor (iskelet).
  final bool isFetching;

  /// Çek-yenile sürüyor.
  final bool isRefreshing;

  /// Kulüpler okunamadı ve gösterilecek içerik yok.
  final bool isError;

  /// [status] üyeliğinin sekmesi: aktif → [MyClubsTab.active], bekleyen →
  /// [MyClubsTab.pending]; ayrılınan, iptal edilen, reddedilen, çıkarılan →
  /// [MyClubsTab.past] (PLAN §12.6; prototip yalnızca reddedilen /
  /// çıkarılanı gösterir, `screens-profile.js:42`).
  static MyClubsTab tabOf(MembershipStatus status) => switch (status) {
    MembershipStatus.active => MyClubsTab.active,
    MembershipStatus.pending => MyClubsTab.pending,
    MembershipStatus.left ||
    MembershipStatus.cancelled ||
    MembershipStatus.rejected ||
    MembershipStatus.removed => MyClubsTab.past,
  };

  /// Satırın tarihi (alt satır + sıralama): prototip `decidedAt || appliedAt`.
  /// Kullanıcının kendi geçişinde (ayrılma, iptal) karar anı yoktur; son
  /// güncelleme anı kullanılır.
  static DateTime? dateOf(MembershipModel membership) =>
      switch (membership.status) {
        MembershipStatus.left || MembershipStatus.cancelled =>
          membership.updatedAt ?? membership.decidedAt ?? membership.appliedAt,
        _ => membership.decidedAt ?? membership.appliedAt,
      };

  /// [tab] sekmesinin satırları, en yeni tarih üstte; kulübü okunmamış
  /// üyelik çizilmez.
  List<MyClubEntry> entriesOf(MyClubsTab tab) {
    final list = <MyClubEntry>[
      for (final membership in memberships.values)
        if (tabOf(membership.status) == tab)
          if (clubs[membership.clubId] case final club?) (membership, club),
    ];
    return list..sort((a, b) {
      final left = dateOf(a.$1);
      final right = dateOf(b.$1);
      if (left == null || right == null) {
        return (left == null ? 1 : 0) - (right == null ? 1 : 0);
      }
      return right.compareTo(left);
    });
  }

  /// Seçili sekmenin satırları ([entriesOf]).
  List<MyClubEntry> get visible => entriesOf(tab);

  /// [clubId] kulübünün satırı; üyelik ya da kulüp yoksa `null`.
  MyClubEntry? entryOf(String clubId) {
    final membership = memberships[clubId];
    final club = clubs[clubId];
    if (membership == null || club == null) return null;
    return (membership, club);
  }

  @override
  List<Object?> get props => [
    tab,
    memberships,
    clubs,
    pendingIds,
    isFetching,
    isRefreshing,
    isError,
  ];

  /// Verilen alanları değiştirilmiş kopya.
  MyClubsState copyWith({
    MyClubsTab? tab,
    Map<String, MembershipModel>? memberships,
    Map<String, ClubModel>? clubs,
    Set<String>? pendingIds,
    bool? isFetching,
    bool? isRefreshing,
    bool? isError,
  }) => MyClubsState(
    tab: tab ?? this.tab,
    memberships: memberships ?? this.memberships,
    clubs: clubs ?? this.clubs,
    pendingIds: pendingIds ?? this.pendingIds,
    isFetching: isFetching ?? this.isFetching,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isError: isError ?? this.isError,
  );
}
