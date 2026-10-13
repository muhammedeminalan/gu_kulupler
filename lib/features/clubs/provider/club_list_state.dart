import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/clubs/provider/club_filters.dart';

/// CLB-01 liste görünümü (prototip `ui.viewMode`; `CLB-01.toggleView`).
enum ClubListLayout {
  /// Tek sütun, geniş kartlar (varsayılan).
  list,

  /// İki sütun, küçük kartlar.
  grid,
}

/// CLB-01 "Kulüpler" ekranının durumu (PLAN §12.6; süzgeç değer nesnesi
/// CD-108).
///
/// [clubs] tek seferde okunan tüm kulüplerdir (≤ `Limits.clubsFetchMax`);
/// ekranda görünen liste [visible] ile türetilir (istemci süzme + sıralama).
/// [memberClubIds] oturumdan canlı gelir. [managerPreviews] kartlar ekrana
/// geldikçe dolar (CD-139).
final class ClubListState extends Equatable {
  /// Varsayılan: kulüp yok, süzgeç yok, liste görünümü.
  const ClubListState({
    this.clubs = const [],
    this.filters = ClubFilters.none,
    this.layout = ClubListLayout.list,
    this.memberClubIds = const {},
    this.managerPreviews = const {},
    this.pendingJoinIds = const {},
    this.isFetching = false,
    this.isRefreshing = false,
    this.isError = false,
  });

  /// Okunan kulüpler (askıdakiler dahil; silinmişler yok).
  final List<ClubModel> clubs;

  /// Kategori çipleri + SHT-04 süzgeci ve sıralaması.
  final ClubFilters filters;

  /// Liste / ızgara.
  final ClubListLayout layout;

  /// Kullanıcının etkin üyesi olduğu kulüpler (`SessionState.roleIn`):
  /// "Üye olduklarım / olmadıklarım" süzgeci.
  final Set<String> memberClubIds;

  /// Kulüp → yönetici üyelikleri (başkan önde): liste kartındaki avatar
  /// grubu. Anahtarı olmayan kulübün önizlemesi henüz okunmamıştır.
  final Map<String, List<MembershipModel>> managerPreviews;

  /// Anında katılımı yazılan ve oturuma henüz yansımamış kulüpler: kartları
  /// iyimser olarak "üye" çizilir; yazım başarısız olursa geri alınır.
  final Set<String> pendingJoinIds;

  /// İlk yükleme / "Yeniden dene" sürüyor (iskelet).
  final bool isFetching;

  /// Çek-yenile sürüyor (içerik ekranda kalır).
  final bool isRefreshing;

  /// Kulüpler okunamadı (hata görünümü).
  final bool isError;

  /// Ekranda listelenen kulüpler: [filters] ile süzülmüş ve sıralanmış
  /// (askıdakiler yok).
  List<ClubModel> get visible =>
      filters.apply(clubs, memberClubIds: memberClubIds);

  /// Etkin süzgeç sayısı ("Filtre / Sırala" yanındaki sayaç).
  int get activeFilterCount => filters.activeCount;

  /// [clubId] kimlikli kulüp; listede yoksa `null`.
  ClubModel? clubById(String clubId) {
    for (final club in clubs) {
      if (club.id == clubId) return club;
    }
    return null;
  }

  @override
  List<Object?> get props => [
    clubs,
    filters,
    layout,
    memberClubIds,
    managerPreviews,
    pendingJoinIds,
    isFetching,
    isRefreshing,
    isError,
  ];

  /// Verilen alanları değiştirilmiş kopya.
  ClubListState copyWith({
    List<ClubModel>? clubs,
    ClubFilters? filters,
    ClubListLayout? layout,
    Set<String>? memberClubIds,
    Map<String, List<MembershipModel>>? managerPreviews,
    Set<String>? pendingJoinIds,
    bool? isFetching,
    bool? isRefreshing,
    bool? isError,
  }) => ClubListState(
    clubs: clubs ?? this.clubs,
    filters: filters ?? this.filters,
    layout: layout ?? this.layout,
    memberClubIds: memberClubIds ?? this.memberClubIds,
    managerPreviews: managerPreviews ?? this.managerPreviews,
    pendingJoinIds: pendingJoinIds ?? this.pendingJoinIds,
    isFetching: isFetching ?? this.isFetching,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isError: isError ?? this.isError,
  );
}
