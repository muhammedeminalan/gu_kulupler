import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';

/// ADM-01 dönem çipleri (prototip `range`, `screens-admin.js:12/19`;
/// varsayılan `30`). Pencere "+x yeni" alt metnini ve katılım oranı kartını
/// belirler; KPI sayaçları, grafik (CD-46: son 8 hafta) ve en aktif kulüpler
/// pencereden bağımsızdır.
enum AdminRange {
  /// Son 7 gün (bugün dahil).
  days7('7'),

  /// Son 30 gün (bugün dahil).
  days30('30'),

  /// İçinde bulunulan akademik dönemin başından bugüne (güz 1 Eylül, bahar
  /// 1 Şubat — Istanbul; yaz bahar dönemine sayılır).
  term('term');

  const AdminRange(this.id);

  /// Aksiyon anahtarı soneki (`ADM-01.range.<id>`).
  final String id;
}

/// "Etkinlik katılım oranı" kartının değerleri: pencerede başlamış ve
/// bitmiş, yayındaki herkese açık etkinliklerin sayaç toplamları
/// (`goingCount` kayıtlıyı — yoklaması alınanlar dahil, CD-130 — ve
/// `attendedCount` katılanı sayar).
final class AdminAttendance extends Equatable {
  /// Varsayılan: hepsi sıfır.
  const AdminAttendance({
    this.eventCount = 0,
    this.registered = 0,
    this.attended = 0,
  });

  /// Geçmiş etkinlik sayısı.
  final int eventCount;

  /// Kayıt toplamı.
  final int registered;

  /// Katılım toplamı.
  final int attended;

  /// Katılım oranı yüzdesi (kayıt yoksa 0).
  double get rate => registered == 0 ? 0 : attended * 100 / registered;

  @override
  List<Object?> get props => [eventCount, registered, attended];
}

/// ADM-01 "Admin" genel bakış durumu (PLAN §12 `AdminViewModel`).
///
/// * [stats] dört `count()` sayacıdır (`AdminRepository.stats`): etkin kulüp,
///   silinmemiş kullanıcı, açık şikayet (CD-37), yaklaşan etkinlik.
/// * [suspendedClubCount] ve [topClubs] tek kulüp okumasından gelir
///   (`ClubRepository.fetchActiveClubs` — askıdakiler dahil).
/// * [chart] son 8 haftanın tüm kulüplerdeki haftalık yeni üye sayısıdır (en
///   eski solda; boş hafta 0 — CD-46); [newCount] aynı metriğin [range]
///   penceresindeki toplamıdır ("+x yeni").
final class AdminState extends Equatable {
  /// Varsayılan: içerik yok.
  const AdminState({
    this.range = AdminRange.days30,
    this.stats = const AdminStats(),
    this.suspendedClubCount = 0,
    this.newCount = 0,
    this.chart = const [],
    this.topClubs = const [],
    this.attendance = const AdminAttendance(),
    this.isLoaded = false,
    this.isFetching = false,
    this.isRefreshing = false,
    this.isError = false,
  });

  /// Seçili dönem çipi.
  final AdminRange range;

  /// KPI sayaçları.
  final AdminStats stats;

  /// Askıdaki kulüp sayısı.
  final int suspendedClubCount;

  /// [range] penceresindeki yeni üyelikler (`member_joined` +
  /// `application_approved`, tüm kulüpler).
  final int newCount;

  /// Haftalık yeni üye sayıları (8 nokta, en eski solda).
  final List<int> chart;

  /// En kalabalık beş etkin kulüp (`memberCount` azalan).
  final List<ClubModel> topClubs;

  /// [range] penceresinin katılım toplamları.
  final AdminAttendance attendance;

  /// En az bir okuma turu başarıyla bitti (içerik çizilebilir).
  final bool isLoaded;

  /// İlk okuma sürüyor (iskelet).
  final bool isFetching;

  /// Çek-yenile sürüyor (içerik kalır).
  final bool isRefreshing;

  /// Okuma başarısız (hata görünümü + "Yeniden dene").
  final bool isError;

  @override
  List<Object?> get props => [
    range,
    stats,
    suspendedClubCount,
    newCount,
    chart,
    topClubs,
    attendance,
    isLoaded,
    isFetching,
    isRefreshing,
    isError,
  ];

  /// Değişen alanlarla kopya.
  AdminState copyWith({
    AdminRange? range,
    AdminStats? stats,
    int? suspendedClubCount,
    int? newCount,
    List<int>? chart,
    List<ClubModel>? topClubs,
    AdminAttendance? attendance,
    bool? isLoaded,
    bool? isFetching,
    bool? isRefreshing,
    bool? isError,
  }) => AdminState(
    range: range ?? this.range,
    stats: stats ?? this.stats,
    suspendedClubCount: suspendedClubCount ?? this.suspendedClubCount,
    newCount: newCount ?? this.newCount,
    chart: chart ?? this.chart,
    topClubs: topClubs ?? this.topClubs,
    attendance: attendance ?? this.attendance,
    isLoaded: isLoaded ?? this.isLoaded,
    isFetching: isFetching ?? this.isFetching,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isError: isError ?? this.isError,
  );
}
