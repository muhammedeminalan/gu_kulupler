import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/manage/activity_lookups.dart';

/// MGT-01 gösterge kartlarının değerleri (prototip `sel.kpis`,
/// `actions.js:73`). Sayılar sayaç alanlarından ya da tek okuma turundan
/// gelir; ekran yeniden saymaz.
final class MgtKpis extends Equatable {
  /// Varsayılan: hepsi sıfır.
  const MgtKpis({
    this.memberCount = 0,
    this.joinedThisMonth = 0,
    this.pendingCount = 0,
    this.upcomingEventCount = 0,
    this.announcementCount = 0,
  });

  /// "Toplam üye" — kulüp belgesinin `memberCount` sayacı.
  final int memberCount;

  /// "+x bu ay" — son 30 günün `member_joined` + `application_approved`
  /// kayıtları (grafikle aynı kaynak, CD-46).
  final int joinedThisMonth;

  /// "Bekleyen başvuru" — `listPending` toplamı.
  final int pendingCount;

  /// "Yaklaşan etkinlik" — yayındaki, başlamamış etkinlikler.
  final int upcomingEventCount;

  /// "Bu ay duyuru" — son 30 günün (silinmemiş) duyuruları.
  final int announcementCount;

  @override
  List<Object?> get props => [
    memberCount,
    joinedThisMonth,
    pendingCount,
    upcomingEventCount,
    announcementCount,
  ];

  /// Değişen alanlarla kopya.
  MgtKpis copyWith({
    int? memberCount,
    int? joinedThisMonth,
    int? pendingCount,
    int? upcomingEventCount,
    int? announcementCount,
  }) => MgtKpis(
    memberCount: memberCount ?? this.memberCount,
    joinedThisMonth: joinedThisMonth ?? this.joinedThisMonth,
    pendingCount: pendingCount ?? this.pendingCount,
    upcomingEventCount: upcomingEventCount ?? this.upcomingEventCount,
    announcementCount: announcementCount ?? this.announcementCount,
  );
}

/// MGT-01 "Yönetim paneli" durumu (PLAN §12.6 `ManageViewModel`).
///
/// * [access] / [role] oturumdan gelir; [access] `advisor` → [isReadOnly]
///   (Q-09: salt okunur bant, yazma eylemleri devre dışı + TST-26).
/// * [chart] son 8 haftanın haftalık yeni üye sayısıdır (en eski solda; boş
///   hafta 0 — CD-46).
/// * [upcomingEvents] en yakın ilk iki yaklaşan etkinlik; [attendanceEventId]
///   "Yoklama al" hedefi (en yakın yaklaşan, yoksa en son başlamış yayındaki
///   etkinlik; ikisi de yoksa `null` → TST-X12).
/// * [recentActivity] son beş faaliyet (tanınmayan tür süzülür); adları
///   [lookups]'tadır.
/// * [hasMembers] `false` → "Henüz üyen yok" kartı (danışman hariç).
final class ManageState extends Equatable {
  /// Varsayılan: içerik yok.
  const ManageState({
    this.access = ClubAccess.visitor,
    this.role,
    this.club,
    this.kpis = const MgtKpis(),
    this.chart = const [],
    this.announcementsToday = 0,
    this.upcomingEvents = const [],
    this.attendanceEventId,
    this.recentActivity = const [],
    this.lookups = const ActivityLookups(),
    this.hasMembers = true,
    this.isFetching = false,
    this.isRefreshing = false,
    this.isError = false,
  });

  /// Kullanıcının kulübe erişim kipi (`SessionState.accessTo`).
  final ClubAccess access;

  /// Kullanıcının kulüpteki aktif rolü (başlık rozeti); süper admin
  /// bakışında `null` olabilir.
  final ClubRole? role;

  /// Kulüp belgesi; okunmadıysa `null`.
  final ClubModel? club;

  /// Gösterge kartları.
  final MgtKpis kpis;

  /// Haftalık yeni üye sayıları (8 nokta, en eski solda).
  final List<int> chart;

  /// Bugün gönderilen bildirimli duyuru sayısı (`announcementCounters`).
  final int announcementsToday;

  /// İlk iki yaklaşan etkinlik (en yakın üstte).
  final List<EventModel> upcomingEvents;

  /// "Yoklama al" hedef etkinliği; yoksa `null`.
  final String? attendanceEventId;

  /// Son beş faaliyet kaydı (en yeni üstte).
  final List<ActivityModel> recentActivity;

  /// Faaliyet metinlerinin adları (eylemci, hedef kullanıcı, etkinlik).
  final ActivityLookups lookups;

  /// Kulübün sıradan (`member` rollü) üyesi var mı?
  final bool hasMembers;

  /// İlk okuma sürüyor (iskelet).
  final bool isFetching;

  /// Çek-yenile sürüyor (içerik kalır).
  final bool isRefreshing;

  /// Okuma başarısız (hata görünümü + "Yeniden dene").
  final bool isError;

  /// Danışman bakışı: salt okunur.
  bool get isReadOnly => access == ClubAccess.advisor;

  /// Süper admin bakışı (rozet).
  bool get isSuperAdmin => access == ClubAccess.superAdmin;

  /// "Henüz üyen yok" kartı görünür mü (`!members.length && !readOnly`,
  /// `screens-manage.js:22`).
  bool get showNewClubCard => club != null && !hasMembers && !isReadOnly;

  @override
  List<Object?> get props => [
    access,
    role,
    club,
    kpis,
    chart,
    announcementsToday,
    upcomingEvents,
    attendanceEventId,
    recentActivity,
    lookups,
    hasMembers,
    isFetching,
    isRefreshing,
    isError,
  ];

  /// Değişen alanlarla kopya; [clearRole] / [clearAttendanceEventId] ilgili
  /// alanı `null` yapar.
  ManageState copyWith({
    ClubAccess? access,
    ClubRole? role,
    bool clearRole = false,
    ClubModel? club,
    MgtKpis? kpis,
    List<int>? chart,
    int? announcementsToday,
    List<EventModel>? upcomingEvents,
    String? attendanceEventId,
    bool clearAttendanceEventId = false,
    List<ActivityModel>? recentActivity,
    ActivityLookups? lookups,
    bool? hasMembers,
    bool? isFetching,
    bool? isRefreshing,
    bool? isError,
  }) => ManageState(
    access: access ?? this.access,
    role: clearRole ? null : role ?? this.role,
    club: club ?? this.club,
    kpis: kpis ?? this.kpis,
    chart: chart ?? this.chart,
    announcementsToday: announcementsToday ?? this.announcementsToday,
    upcomingEvents: upcomingEvents ?? this.upcomingEvents,
    attendanceEventId: clearAttendanceEventId
        ? null
        : attendanceEventId ?? this.attendanceEventId,
    recentActivity: recentActivity ?? this.recentActivity,
    lookups: lookups ?? this.lookups,
    hasMembers: hasMembers ?? this.hasMembers,
    isFetching: isFetching ?? this.isFetching,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isError: isError ?? this.isError,
  );
}
