import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_ui/gu_ui.dart' show TurkishCaseX;

/// MGT-06 özet çipi — süzgeç başına bir değer (`MGT-06.summary.<id>`;
/// prototip `screens-manage.js:128`, sıra tasarımdaki gibi).
enum AttendanceSummaryFilter {
  /// "Kayıtlı {n}": bütün kayıtlılar (`going` + `attended`) ve bekleme
  /// listesi bölümü.
  all,

  /// "Katıldın {n}": yoklaması alınanlar.
  attended,

  /// "Gelmedi {n}": yoklaması alınmamış kayıtlılar (`going`).
  absent,

  /// "Bekleme listesi {n}": yalnızca bekleme listesi bölümü.
  waitlist,
}

/// Etkinliğin yoklama penceresine göre evresi (K-G: `startsAt −
/// Limits.attendanceWindowBefore … endsAt + Limits.attendanceWindowAfter`,
/// iki uç dahil — Rules ile aynı).
enum AttendancePhase {
  /// Pencere henüz açılmadı: bilgi bandı, anahtarlar devre dışı.
  beforeWindow,

  /// Pencere açık, etkinlik henüz başlamadı: prototipin "Etkinlik henüz
  /// başlamadı." bandı (`screens-manage.js:127`), anahtarlar etkin.
  beforeStart,

  /// Etkinlik başladı, pencere açık: bant yok.
  open,

  /// Pencere kapandı (`endsAt + 6 sa` geçti): bilgi bandı, anahtarlar devre
  /// dışı.
  closed;

  /// Yoklama yazılabilir mi (K-G)?
  bool get isWindowOpen => this == beforeStart || this == open;
}

/// DLG-17 toplu yoklamasının ilerlemesi (`markAllAttended` `onProgress`).
typedef AttendanceBulkProgress = ({int done, int total});

/// MGT-06 "Katılımcılar ve yoklama" ekranının durumu (PLAN §12.6
/// `AttendanceViewModel`).
///
/// * [rsvps] canlı akıştan gelen sunucu kayıtlarıdır
///   (`attendanceRepository.watchParticipants` — §10.6 #5; silinmiş ve
///   `cancelled` kayıtlar süzülmüş). İyimser yoklama değişiklikleri ayrı
///   tutulur ([marks]: kimlik → gösterilen durum); akış aynı durumu getirince
///   işaret düşer. Görünen kayıtlar [participants].
/// * Ad, bölüm, sınıf ve avatar güncel kullanıcı belgesindendir ([users] —
///   `userRepository.getUsers`; PLAN'daki `names` haritası yerine).
/// * Süzgeç ([summary]) ve arama ([query], Türkçe küçük harf) istemcidedir
///   ([visible]); kayıtlılar ada göre (Türkçe alfabe), bekleme listesi sıra
///   numarasıyla.
/// * [access] `advisor` → [isReadOnly] (Q-09: bant, anahtarlar devre dışı →
///   TST-26). [actorId]'nin kendi kaydı işaretlenemez (CD-153, rules-spec
///   §3.8).
final class AttendanceState extends Equatable {
  /// Varsayılan: içerik yok, süzgeç "Kayıtlı", pencere açık.
  const AttendanceState({
    this.access = ClubAccess.visitor,
    this.actorId,
    this.club,
    this.event,
    this.rsvps = const [],
    this.marks = const {},
    this.users = const {},
    this.summary = AttendanceSummaryFilter.all,
    this.query = '',
    this.pendingIds = const {},
    this.bulkProgress,
    this.phase = AttendancePhase.open,
    this.isExporting = false,
    this.isFetching = false,
    this.isError = false,
  });

  /// Oturumdaki kullanıcının kulübe erişimi.
  final ClubAccess access;

  /// Oturumdaki kullanıcının kimliği (yazımların aktörü); oturum yoksa
  /// `null`.
  final String? actorId;

  /// Kulüp (başlıktaki ad); okunamadıysa `null`.
  final ClubModel? club;

  /// Etkinlik (başlık, kontenjan, kayıt durumu, pencere); okunmadıysa `null`.
  final EventModel? event;

  /// Akıştan gelen katılım kayıtları (`going`, `waitlist`, `attended`).
  final List<RsvpModel> rsvps;

  /// İyimser yoklama işaretleri: kullanıcı kimliği → gösterilen durum.
  final Map<String, RsvpStatus> marks;

  /// Kimlik → güncel kullanıcı belgesi.
  final Map<String, UserModel> users;

  /// Seçili özet çipi.
  final AttendanceSummaryFilter summary;

  /// Arama alanındaki metin (yazıldığı gibi).
  final String query;

  /// Yazımı süren kayıtlar (anahtar / "Kayıtlıya al" ikinci kez çalışmaz).
  final Set<String> pendingIds;

  /// DLG-17 toplu yoklaması sürüyorsa ilerlemesi.
  final AttendanceBulkProgress? bulkProgress;

  /// Yoklama penceresi evresi (K-G).
  final AttendancePhase phase;

  /// CSV hazırlanıyor.
  final bool isExporting;

  /// İlk yükleme / "Yeniden dene" sürüyor (iskelet).
  final bool isFetching;

  /// Etkinlik ya da katılımcılar okunamadı (içerik yokken).
  final bool isError;

  /// Danışman bakışı (salt okunur).
  bool get isReadOnly => access == ClubAccess.advisor;

  /// Toplu yoklama sürüyor mu.
  bool get isBulkRunning => bulkProgress != null;

  /// Anahtarlar yazılabilir mi: danışman değil, pencere açık, etkinlik
  /// yayında, toplu işlem sürmüyor.
  bool get canMark =>
      !isReadOnly &&
      phase.isWindowOpen &&
      event?.status == EventStatus.published &&
      !isBulkRunning;

  /// [userId] oturumdaki yöneticinin kendisi mi (CD-153: işaretleyemez).
  bool isOwn(String userId) => userId == actorId;

  /// İyimser işaretler uygulanmış kayıtlar.
  List<RsvpModel> get participants => [
    for (final r in rsvps)
      if (marks[r.userId] case final status?) r.copyWith(status: status) else r,
  ];

  /// [userId] kaydı (iyimser durumuyla); yoksa `null`.
  RsvpModel? find(String userId) {
    for (final r in participants) {
      if (r.userId == userId) return r;
    }
    return null;
  }

  /// [userId]'nin görünen adı; kullanıcı belgesi okunmadıysa boş.
  String nameOf(String userId) => users[userId]?.name ?? '';

  /// Kayıtlılar (`going` + `attended`), ada göre (Türkçe alfabe).
  List<RsvpModel> get registered => [
    for (final r in participants)
      if (r.status == RsvpStatus.going || r.status == RsvpStatus.attended) r,
  ]..sort(_byName);

  /// Yoklaması alınanların sayısı.
  int get attendedCount => [
    for (final r in participants)
      if (r.status == RsvpStatus.attended) r,
  ].length;

  /// Bekleme listesi, sıra numarasına göre (`waitlistAt`, eşitlikte kimlik).
  List<RsvpModel> get waitlist => [
    for (final r in participants)
      if (r.status == RsvpStatus.waitlist) r,
  ]..sort(_byQueue);

  /// Yoklama yüzdesi, `0`–`100` tamsayı (prototip
  /// `Math.round(att / reg * 100)`); kayıtlı yoksa `0`.
  int get attendanceRate {
    final total = registered.length;
    return total == 0 ? 0 : (attendedCount * 100 / total).round();
  }

  /// Kontenjan dolu mu (kayıtlı sayısı `capacity`'ye ulaştı); sınırsız
  /// etkinlik hiç dolmaz.
  bool get isFull {
    final capacity = event?.capacity;
    return capacity != null && registered.length >= capacity;
  }

  /// Aramanın Türkçe küçük harfli, kırpılmış hâli.
  String get needle => query.trim().trLower();

  /// Görünen kayıtlılar: [summary] (bekleme listesinde boş) ve arama.
  List<RsvpModel> get visible {
    final term = needle;
    bool shown(RsvpModel r) => switch (summary) {
      AttendanceSummaryFilter.all => true,
      AttendanceSummaryFilter.attended => r.status == RsvpStatus.attended,
      AttendanceSummaryFilter.absent => r.status == RsvpStatus.going,
      AttendanceSummaryFilter.waitlist => false,
    };
    return [
      for (final r in registered)
        if (shown(r) &&
            (term.isEmpty || nameOf(r.userId).trLower().contains(term)))
          r,
    ];
  }

  /// Bekleme listesi bölümü çizilir mi ("Kayıtlı" ve "Bekleme listesi").
  bool get showsWaitlist =>
      summary == AttendanceSummaryFilter.all ||
      summary == AttendanceSummaryFilter.waitlist;

  /// Kayıtlılar bölümü çizilir mi (bekleme listesi süzgeci dışında).
  bool get showsRegistered => summary != AttendanceSummaryFilter.waitlist;

  /// [filter] çipinin sayısı.
  int countOf(AttendanceSummaryFilter filter) => switch (filter) {
    AttendanceSummaryFilter.all => registered.length,
    AttendanceSummaryFilter.attended => attendedCount,
    AttendanceSummaryFilter.absent => registered.length - attendedCount,
    AttendanceSummaryFilter.waitlist => waitlist.length,
  };

  int _byName(RsvpModel a, RsvpModel b) {
    final byName = nameOf(a.userId).trCompareTo(nameOf(b.userId));
    return byName != 0 ? byName : a.userId.compareTo(b.userId);
  }

  static int _byQueue(RsvpModel a, RsvpModel b) {
    final aAt = a.waitlistAt;
    final bAt = b.waitlistAt;
    if (aAt != null && bAt != null && aAt != bAt) return aAt.compareTo(bAt);
    if (aAt == null && bAt != null) return -1;
    if (aAt != null && bAt == null) return 1;
    return a.userId.compareTo(b.userId);
  }

  @override
  List<Object?> get props => [
    access,
    actorId,
    club,
    event,
    rsvps,
    marks,
    users,
    summary,
    query,
    pendingIds,
    bulkProgress,
    phase,
    isExporting,
    isFetching,
    isError,
  ];

  /// Verilen alanları değiştirilmiş kopya; `clear…` bayrakları alanı
  /// `null` yapar.
  AttendanceState copyWith({
    ClubAccess? access,
    String? actorId,
    ClubModel? club,
    EventModel? event,
    List<RsvpModel>? rsvps,
    Map<String, RsvpStatus>? marks,
    Map<String, UserModel>? users,
    AttendanceSummaryFilter? summary,
    String? query,
    Set<String>? pendingIds,
    AttendanceBulkProgress? bulkProgress,
    AttendancePhase? phase,
    bool? isExporting,
    bool? isFetching,
    bool? isError,
    bool clearActorId = false,
    bool clearBulkProgress = false,
  }) => AttendanceState(
    access: access ?? this.access,
    actorId: clearActorId ? null : actorId ?? this.actorId,
    club: club ?? this.club,
    event: event ?? this.event,
    rsvps: rsvps ?? this.rsvps,
    marks: marks ?? this.marks,
    users: users ?? this.users,
    summary: summary ?? this.summary,
    query: query ?? this.query,
    pendingIds: pendingIds ?? this.pendingIds,
    bulkProgress: clearBulkProgress ? null : bulkProgress ?? this.bulkProgress,
    phase: phase ?? this.phase,
    isExporting: isExporting ?? this.isExporting,
    isFetching: isFetching ?? this.isFetching,
    isError: isError ?? this.isError,
  );
}
