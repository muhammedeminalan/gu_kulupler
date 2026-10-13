import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/search/provider/search_scope.dart';

/// CLB-02 "Arama" ekranının durumu (PLAN §12.6).
///
/// * [query] alandaki ham metindir; sonuçlar [searchTerm] (kırpılmış metin)
///   içindir ve `Limits.searchDebounce` sonra hesaplanır — arada
///   [isSearching] `true`.
/// * [searchTerm] boşken ekran varsayılan görünümdedir: [recent], [popular]
///   ve (Kulüpler sekmesinde) [suggested].
/// * [clubPool] / [eventPool] istemci tarafı aramanın havuzlarıdır;
///   [isFetching] havuz okunurken, [isError] okunamadığında `true`.
final class SearchState extends Equatable {
  /// Varsayılan: boş sorgu, Kulüpler sekmesi, boş havuzlar.
  const SearchState({
    this.query = '',
    this.scope = SearchScope.clubs,
    this.recent = const [],
    this.popular = const [],
    this.clubPool = const [],
    this.eventPool = const [],
    this.suggested = const [],
    this.managerPreviews = const {},
    this.clubResults = const [],
    this.eventResults = const [],
    this.recentBackup = const [],
    this.pendingJoinIds = const {},
    this.isFetching = false,
    this.isSearching = false,
    this.isError = false,
  });

  /// Arama alanındaki metin (kırpılmamış).
  final String query;

  /// Seçili sonuç sekmesi.
  final SearchScope scope;

  /// Son aramalar, en yeni önde (≤ `Limits.recentSearchesMax`).
  final List<String> recent;

  /// Popüler aramalar (`StaticTables.popularSearches`).
  final List<String> popular;

  /// Aranan kulüpler: askıda olmayan tüm kulüpler.
  final List<ClubModel> clubPool;

  /// Aranan etkinlikler: yaklaşan, kullanıcının görebildiği etkinlikler.
  /// T-23'e kadar boştur (`EventRepository` yok).
  final List<EventModel> eventPool;

  /// "Sizin için önerilen kulüpler": kullanıcının üyesi olmadığı ilk üç
  /// kulüp, ilgi alanlarının kategorileri önde (`screens-clubs.js:41`).
  /// Havuz yüklenince bir kez kurulur; katılınca kart yerinde kalır.
  final List<ClubModel> suggested;

  /// Önerilen kulüplerin yöneticileri (kulüp kimliği → aktif başkan ve
  /// yönetim kurulu üyelikleri): kartın avatar grubu (CD-139). Okunamayan
  /// kulübün kaydı yoktur.
  final Map<String, List<MembershipModel>> managerPreviews;

  /// [searchTerm] ile eşleşen kulüpler ([clubPool] sırasıyla).
  final List<ClubModel> clubResults;

  /// [searchTerm] ile eşleşen etkinlikler ([eventPool] sırasıyla).
  final List<EventModel> eventResults;

  /// "Temizle"den önceki son aramalar (TST-06 "Geri al").
  final List<String> recentBackup;

  /// Katılım yazımı süren kulüpler (art arda "Katıl" yok sayılır).
  final Set<String> pendingJoinIds;

  /// Havuzlar okunuyor mu?
  final bool isFetching;

  /// Sorgu değişti, sonuçlar bekleniyor mu (debounce)?
  final bool isSearching;

  /// Havuzlar okunamadı mı?
  final bool isError;

  /// Aranan terim: [query] kırpılmış hali. Boşsa arama yoktur.
  String get searchTerm => query.trim();

  /// Sonuç görünümü mü (terim dolu), varsayılan görünüm mü?
  bool get hasTerm => searchTerm.isNotEmpty;

  @override
  List<Object?> get props => [
    query,
    scope,
    recent,
    popular,
    clubPool,
    eventPool,
    suggested,
    managerPreviews,
    clubResults,
    eventResults,
    recentBackup,
    pendingJoinIds,
    isFetching,
    isSearching,
    isError,
  ];

  /// Verilen alanları değiştirilmiş kopya.
  SearchState copyWith({
    String? query,
    SearchScope? scope,
    List<String>? recent,
    List<String>? popular,
    List<ClubModel>? clubPool,
    List<EventModel>? eventPool,
    List<ClubModel>? suggested,
    Map<String, List<MembershipModel>>? managerPreviews,
    List<ClubModel>? clubResults,
    List<EventModel>? eventResults,
    List<String>? recentBackup,
    Set<String>? pendingJoinIds,
    bool? isFetching,
    bool? isSearching,
    bool? isError,
  }) => SearchState(
    query: query ?? this.query,
    scope: scope ?? this.scope,
    recent: recent ?? this.recent,
    popular: popular ?? this.popular,
    clubPool: clubPool ?? this.clubPool,
    eventPool: eventPool ?? this.eventPool,
    suggested: suggested ?? this.suggested,
    managerPreviews: managerPreviews ?? this.managerPreviews,
    clubResults: clubResults ?? this.clubResults,
    eventResults: eventResults ?? this.eventResults,
    recentBackup: recentBackup ?? this.recentBackup,
    pendingJoinIds: pendingJoinIds ?? this.pendingJoinIds,
    isFetching: isFetching ?? this.isFetching,
    isSearching: isSearching ?? this.isSearching,
    isError: isError ?? this.isError,
  );
}
