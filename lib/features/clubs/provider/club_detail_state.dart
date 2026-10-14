import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/navigation/club_detail_tab.dart';

// `JoinOutcome` kart "Katıl" akışıyla ortaktır (CLB-02 — `ClubJoinMixin`);
// bu dosyayı içe aktaranlar aynı adı görmeye devam eder.
export 'package:gu_kulupler/product/mixin/club_join_mixin.dart'
    show JoinOutcome;

/// `ClubDetailViewModel.leave` sonucu.
enum LeaveOutcome {
  /// Kullanıcı kulüpten ayrıldı (TST-39 gösterildi).
  left,

  /// Kullanıcı vazgeçti (DLG-08 "Vazgeç", scrim, geri).
  cancelled,

  /// Başkan devretmeden ayrılamaz: DLG-09 gösterildi ve "Tamam" ile kapandı.
  solePresident,

  /// DLG-09'da "Başkanlığı devret" seçildi: çağıran devir akışını başlatır
  /// (SHT-25 → DLG-21).
  transferRequested,

  /// Ayrılma olmadı: üyelik yok, süren işlem var, çevrimdışı (TST-24), yetki
  /// yok (TST-X18) ya da beklenmeyen hata.
  failed,
}

/// CLB-03 "Kulüp" ekranının durumu (PLAN §12.6).
///
/// [access] ve [membership] oturumdan gelir (canlı); [club] tek seferlik
/// okunur. [managers] herkese yüklenir: etkin yönetici üyelikleri doğrulanmış
/// her kullanıcıya okunur (rules-spec §3.4 R(d), CD-139). [memberPreview]
/// kulübün içini görende ([seesInside]) ilk etkin üyelerden, görmeyende
/// yöneticilerden kurulur — tam üye listesi üyelere özeldir (R(c)).
final class ClubDetailState extends Equatable {
  /// Varsayılan: kulüp yok, ziyaretçi, hakkında sekmesi.
  const ClubDetailState({
    this.club,
    this.access = ClubAccess.visitor,
    this.membership,
    this.tab = ClubDetailTab.about,
    this.events = const [],
    this.rsvps = const {},
    this.isEventsFetching = false,
    this.isEventsError = false,
    this.managers = const [],
    this.memberPreview = const [],
    this.isFetching = false,
    this.isRefreshing = false,
    this.isError = false,
    this.isNotFound = false,
    this.isActing = false,
  });

  /// Kulüp; yüklenene kadar `null`.
  final ClubModel? club;

  /// Kullanıcının kulübe erişim kipi (`SessionState.accessTo`).
  final ClubAccess access;

  /// Kullanıcının bu kulüpteki üyelik belgesi (her durumda); yoksa `null`.
  final MembershipModel? membership;

  /// Seçili sekme (`?tab=`).
  final ClubDetailTab tab;

  /// Etkinlikler sekmesinin içeriği: kulübün yayındaki / iptal edilmiş
  /// etkinliklerinden bir sayfa (`listClubEvents`, en yeni başlangıç üstte);
  /// kulübün içini görmeyene yalnızca herkese açık olanlar. Taslak yok.
  final List<EventModel> events;

  /// Kullanıcının bu kulübün etkinliklerindeki katılım kayıtları, etkinlik
  /// kimliğine göre (kart durum rozeti ve hızlı eylem — `EventCardStatus`);
  /// vazgeçilmiş kayıtlar dahil (durum türetimi yok sayar).
  final Map<String, RsvpModel> rsvps;

  /// Etkinlikler okunuyor mu (sekme iskeleti)?
  final bool isEventsFetching;

  /// Etkinlikler okunamadı mı (sekme içi hata)?
  final bool isEventsError;

  /// Yönetim kurulu: aktif başkan ve yönetim kurulu üyelikleri, başkan önde.
  final List<MembershipModel> managers;

  /// İlk [memberPreviewLimit] aktif üye: başlıktaki avatar grubu (ilk dördü)
  /// ve "Üyeler" sekmesindeki önizleme satırları.
  final List<MembershipModel> memberPreview;

  /// Önizleme için okunan üye sayısı — "Üyeler" sekmesi ilk beş üyeyi çizer
  /// (`members.slice(0, 5)`, `screens-clubs.js:106`).
  static const int memberPreviewLimit = 5;

  /// İlk yükleme sürüyor mu (iskelet)?
  final bool isFetching;

  /// Var olan içerik yenileniyor mu (iskelet yok)?
  final bool isRefreshing;

  /// Kulüp yüklenemedi mi (ekran içi hata)?
  final bool isError;

  /// Kulüp yok / silinmiş mi (→ SYS-04)?
  final bool isNotFound;

  /// Süren bir üyelik yazımı var mı (katıl / ayrıl)?
  final bool isActing;

  /// Kullanıcı kulübün içini görüyor mu: gönderiler, üye listesi, üyelere
  /// özel etkinlikler (Rules `seesInside`; prototip `canSeeInside`,
  /// `actions.js:29`).
  bool get seesInside => switch (access) {
    ClubAccess.member ||
    ClubAccess.manager ||
    ClubAccess.advisor ||
    ClubAccess.superAdmin => true,
    ClubAccess.visitor || ClubAccess.pending || ClubAccess.rejected => false,
  };

  /// Kullanıcı kulübü yönetiyor mu (yönetici ya da süper admin)? Alt çubukta
  /// "Yönetim" ve "Etkinlik oluştur" bu kipte çizilir.
  bool get canManage =>
      access == ClubAccess.manager || access == ClubAccess.superAdmin;

  /// Kullanıcının kulüpteki **aktif** rolü; aktif üyelik yoksa `null`
  /// (başlıktaki rol rozeti).
  ClubRole? get activeRole => RolePolicy.activeRole(
    status: membership?.status,
    role: membership?.role,
  );

  /// [now] anında yeniden başvuru beklemesi sürüyorsa beklemenin biteceği an;
  /// bekleme yoksa ya da dolduysa `null` (`cards.js:15`).
  DateTime? retryAfterAt(DateTime now) {
    final retryAfter = membership?.retryAfter;
    return retryAfter != null && retryAfter.isAfter(now) ? retryAfter : null;
  }

  @override
  List<Object?> get props => [
    club,
    access,
    membership,
    tab,
    events,
    rsvps,
    isEventsFetching,
    isEventsError,
    managers,
    memberPreview,
    isFetching,
    isRefreshing,
    isError,
    isNotFound,
    isActing,
  ];

  /// Verilen alanları değiştirilmiş kopya. [clearMembership] üyeliği `null`
  /// yapar (değerine üstün gelir).
  ClubDetailState copyWith({
    ClubModel? club,
    ClubAccess? access,
    MembershipModel? membership,
    bool clearMembership = false,
    ClubDetailTab? tab,
    List<EventModel>? events,
    Map<String, RsvpModel>? rsvps,
    bool? isEventsFetching,
    bool? isEventsError,
    List<MembershipModel>? managers,
    List<MembershipModel>? memberPreview,
    bool? isFetching,
    bool? isRefreshing,
    bool? isError,
    bool? isNotFound,
    bool? isActing,
  }) => ClubDetailState(
    club: club ?? this.club,
    access: access ?? this.access,
    membership: clearMembership ? null : membership ?? this.membership,
    tab: tab ?? this.tab,
    events: events ?? this.events,
    rsvps: rsvps ?? this.rsvps,
    isEventsFetching: isEventsFetching ?? this.isEventsFetching,
    isEventsError: isEventsError ?? this.isEventsError,
    managers: managers ?? this.managers,
    memberPreview: memberPreview ?? this.memberPreview,
    isFetching: isFetching ?? this.isFetching,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isError: isError ?? this.isError,
    isNotFound: isNotFound ?? this.isNotFound,
    isActing: isActing ?? this.isActing,
  );
}
