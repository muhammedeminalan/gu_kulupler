import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/navigation/admin_clubs_tab.dart';
import 'package:gu_ui/gu_ui.dart';

/// ADM-02 "Kulüpler" durumu (PLAN §12 `AdminClubsViewModel`; prototip
/// `AdminClubs`, `screens-admin.js:29–35`).
///
/// * [clubs] tek kulüp okumasıdır (`ClubRepository.fetchActiveClubs` —
///   silinmemiş tüm kulüpler, askıdakiler dahil); sekme ve arama istemcidedir
///   ([visible]).
/// * [presidents] satırlardaki "Başkan: …" adlarının profilleridir
///   (`UserRepository.getUsers`); okunamayan başkanın adı çizilmez.
/// * [pendingIds] askı / etkinleştirme / başkan atama yazımı süren kulüpler
///   (aynı kulüpte ikinci yazım yok sayılır).
final class AdminClubsState extends Equatable {
  /// Varsayılan: içerik yok, etkin sekme.
  const AdminClubsState({
    this.tab = AdminClubsTab.active,
    this.clubs = const [],
    this.presidents = const {},
    this.query = '',
    this.pendingIds = const {},
    this.isLoaded = false,
    this.isFetching = false,
    this.isRefreshing = false,
    this.isError = false,
  });

  /// Seçili sekme (`ADM-02.tab.<name>`).
  final AdminClubsTab tab;

  /// Silinmemiş tüm kulüpler (askıdakiler dahil).
  final List<ClubModel> clubs;

  /// Başkan profilleri (`uid` → profil).
  final Map<String, UserModel> presidents;

  /// Arama metni (`ADM-02.search`; ada göre, Türkçe küçük harf).
  final String query;

  /// Yazımı süren kulüplerin kimlikleri.
  final Set<String> pendingIds;

  /// En az bir okuma başarıyla bitti.
  final bool isLoaded;

  /// İlk okuma sürüyor (iskelet).
  final bool isFetching;

  /// Çek-yenile sürüyor (içerik kalır).
  final bool isRefreshing;

  /// Okuma başarısız (hata görünümü + "Yeniden dene").
  final bool isError;

  /// Arama terimi (kırpılmış, Türkçe küçük harf).
  String get needle => query.trim().trLower();

  /// Ekrandaki satırlar: [tab] durumundaki, adı [needle]'ı içeren kulüpler,
  /// ada göre (Türkçe) sıralı (`screens-admin.js:31`).
  List<ClubModel> get visible {
    final status = switch (tab) {
      AdminClubsTab.active => ClubStatus.active,
      AdminClubsTab.suspended => ClubStatus.suspended,
    };
    final term = needle;
    return [
      for (final club in clubs)
        if (club.status == status &&
            (term.isEmpty || club.name.trLower().contains(term)))
          club,
    ]..sort((a, b) => a.name.trCompareTo(b.name));
  }

  /// [clubId] kulübü; listede yoksa `null`.
  ClubModel? clubById(String clubId) {
    for (final club in clubs) {
      if (club.id == clubId) return club;
    }
    return null;
  }

  @override
  List<Object?> get props => [
    tab,
    clubs,
    presidents,
    query,
    pendingIds,
    isLoaded,
    isFetching,
    isRefreshing,
    isError,
  ];

  /// Değişen alanlarla kopya.
  AdminClubsState copyWith({
    AdminClubsTab? tab,
    List<ClubModel>? clubs,
    Map<String, UserModel>? presidents,
    String? query,
    Set<String>? pendingIds,
    bool? isLoaded,
    bool? isFetching,
    bool? isRefreshing,
    bool? isError,
  }) => AdminClubsState(
    tab: tab ?? this.tab,
    clubs: clubs ?? this.clubs,
    presidents: presidents ?? this.presidents,
    query: query ?? this.query,
    pendingIds: pendingIds ?? this.pendingIds,
    isLoaded: isLoaded ?? this.isLoaded,
    isFetching: isFetching ?? this.isFetching,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isError: isError ?? this.isError,
  );
}
