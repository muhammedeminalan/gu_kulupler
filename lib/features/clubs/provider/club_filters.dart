import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';

/// SHT-04 "Üyelik durumu" seçeneği (prototip `f.membership`,
/// `sheets.js:23`).
enum ClubMembershipFilter {
  /// "Tümü" — süzme yok.
  all,

  /// "Üye olduklarım".
  mine,

  /// "Üye olmadıklarım".
  notMine,
}

/// SHT-04 "Sırala" seçeneği (prototip `f.sort`: `popular` / `new` / `az`,
/// `sheets.js:25`). Sıra tasarımdaki satır sırasıdır.
enum ClubSort {
  /// "Popüler" — üye sayısı, çoktan aza (varsayılan).
  popular,

  /// "Yeni eklenen" — oluşturulma anı, yeniden eskiye.
  newest,

  /// "A–Z" — ad (`ClubModel.nameLower`, Türkçe kurallarıyla üretilmiş).
  az,
}

/// Kulüp listesinin süzgeci ve sıralaması — CLB-01 kategori çipleri + SHT-04
/// (prototip `GU.clubFilters`, `screens-clubs.js:5–16`; CD-108).
///
/// Değer nesnesidir: `ClubListState.filters` alanında yaşar, SHT-04 taslağını
/// bunun kopyası üzerinde tutar ve "Sonuçları göster" ile geri verir.
/// Varsayılan ([none]) hiçbir şeyi süzmez, "Popüler" sıralar.
final class ClubFilters extends Equatable {
  /// Varsayılan: süzme yok, "Popüler" (prototip `DEFAULT_FILTERS`).
  const ClubFilters({
    this.categoryIds = const <String>{},
    this.membership = ClubMembershipFilter.all,
    this.applicationsOpenOnly = false,
    this.instantOnly = false,
    this.sort = ClubSort.popular,
  });

  /// Süzgeçsiz varsayılan ("Temizle" / `CLB-01.clearFilters`).
  static const ClubFilters none = ClubFilters();

  /// Seçili kategoriler (`k01…k08`); boş = tümü. CLB-01 çipleri tek kategori
  /// yazar, SHT-04 çoklu seçer.
  final Set<String> categoryIds;

  /// Üyelik durumu.
  final ClubMembershipFilter membership;

  /// "Yalnızca başvurusu açık" (`applicationsOpen`).
  final bool applicationsOpenOnly;

  /// "Anında katılım olanlar" (`approvalRequired == false`).
  final bool instantOnly;

  /// Sıralama.
  final ClubSort sort;

  /// Etkin süzgeç sayısı — "Filtrele ve sırala" düğmesinin yanındaki sayaç
  /// (prototip `activeFilterCount`): kategori (kaç tane seçilirse seçilsin
  /// 1), üyelik, başvurusu açık, anında katılım, varsayılan dışı sıralama.
  int get activeCount =>
      (categoryIds.isNotEmpty ? 1 : 0) +
      (membership != ClubMembershipFilter.all ? 1 : 0) +
      (applicationsOpenOnly ? 1 : 0) +
      (instantOnly ? 1 : 0) +
      (sort != ClubSort.popular ? 1 : 0);

  /// CLB-01 şeridinde seçili görünen kategori: tam bir kategori seçiliyse o,
  /// değilse `null` ("Tümü" yalnızca hiç kategori yokken seçilidir).
  String? get singleCategoryId =>
      categoryIds.length == 1 ? categoryIds.single : null;

  /// [clubs] listesini süzer ve sıralar (prototip `applyClubFilters`).
  ///
  /// Askıdaki kulüpler listeye girmez. [memberClubIds] kullanıcının etkin
  /// üyesi olduğu kulüplerdir (üyelik süzgeci için). Eşitlikte girdi sırası
  /// korunur (kararlı sıralama).
  List<ClubModel> apply(
    Iterable<ClubModel> clubs, {
    Set<String> memberClubIds = const <String>{},
  }) {
    final out = [
      for (final club in clubs)
        if (_matches(club, memberClubIds)) club,
    ];
    final order = {
      for (final (index, club) in out.indexed) club.id: index,
    };
    int byInput(ClubModel a, ClubModel b) => order[a.id]! - order[b.id]!;
    int orElseInput(int result, ClubModel a, ClubModel b) =>
        result != 0 ? result : byInput(a, b);
    out.sort(
      (a, b) => switch (sort) {
        ClubSort.popular => orElseInput(
          b.memberCount.compareTo(a.memberCount),
          a,
          b,
        ),
        ClubSort.newest => orElseInput(_byNewest(a, b), a, b),
        ClubSort.az => orElseInput(a.nameLower.compareTo(b.nameLower), a, b),
      },
    );
    return out;
  }

  bool _matches(ClubModel club, Set<String> memberClubIds) {
    if (club.status != ClubStatus.active) return false;
    if (categoryIds.isNotEmpty && !categoryIds.contains(club.categoryId)) {
      return false;
    }
    final isMember = memberClubIds.contains(club.id);
    if (membership == ClubMembershipFilter.mine && !isMember) return false;
    if (membership == ClubMembershipFilter.notMine && isMember) return false;
    if (applicationsOpenOnly && !club.applicationsOpen) return false;
    if (instantOnly && club.approvalRequired) return false;
    return true;
  }

  /// Yeniden eskiye; oluşturulma anı olmayan kulüp sona düşer.
  static int _byNewest(ClubModel a, ClubModel b) {
    final (left, right) = (a.createdAt, b.createdAt);
    if (left == null || right == null) {
      return left == right ? 0 : (left == null ? 1 : -1);
    }
    return right.compareTo(left);
  }

  @override
  List<Object?> get props => [
    categoryIds,
    membership,
    applicationsOpenOnly,
    instantOnly,
    sort,
  ];

  /// Verilen alanları değiştirilmiş kopya.
  ClubFilters copyWith({
    Set<String>? categoryIds,
    ClubMembershipFilter? membership,
    bool? applicationsOpenOnly,
    bool? instantOnly,
    ClubSort? sort,
  }) => ClubFilters(
    categoryIds: categoryIds ?? this.categoryIds,
    membership: membership ?? this.membership,
    applicationsOpenOnly: applicationsOpenOnly ?? this.applicationsOpenOnly,
    instantOnly: instantOnly ?? this.instantOnly,
    sort: sort ?? this.sort,
  );
}
