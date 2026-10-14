import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/widget/event/event_card_status.dart';

/// `EventDetailViewModel.join` sonucu.
enum EventJoinOutcome {
  /// Kayıt alındı (`going`): TST-41 ("Biletini göster") gösterildi.
  going,

  /// Bekleme listesine eklendi: TST-43 ("{n}. sıra") gösterildi.
  waitlist,

  /// Katılım olmadı: süren işlem, çevrimdışı (TST-24), kayıt kapalı
  /// (TST-X2), etkinlik bitti (TST-X6), yetki yok (TST-X18) ya da
  /// beklenmeyen hata.
  failed,
}

/// EVT-02 alt çubuğunun türü — prototip `cta()` (`screens-events.js:44–53`),
/// sıra prototiptekiyle aynıdır (ilk eşleşen kazanır).
enum EventDetailBar {
  /// İptal edilmiş etkinlik: alt çubuk yerine iptal bandı.
  cancelled,

  /// Yönetici / süper admin: Düzenle · Katılımcılar · Yoklama başlat.
  manager,

  /// Danışman: salt okunur bandı.
  advisor,

  /// Etkinlik bitti: yoklaması alınmışsa "Katıldın" rozeti, değilse devre
  /// dışı "Etkinlik sona erdi" (TST-X6).
  ended,

  /// Kayıtlı: "Vazgeç" (DLG-14) + "Biletini göster" (EVT-03).
  going,

  /// Bekleme listesinde: sıra metni + "Ayrıl" (DLG-14).
  waitlist,

  /// Tek düğme (`EventCta`): kulübe başvur · bekleme listesine katıl ·
  /// kayıtlar kapalı · katıl.
  cta,
}

/// EVT-02 "Etkinlik" ekranının durumu (PLAN §12.6).
///
/// [event], [club] ve kullanıcının kaydı ([rsvp]) açılışta okunur; erişim
/// kipi ([access]) oturumdan canlı gelir. Bekleme sırası ([waitlistPosition])
/// yalnızca bu ekranda yapılan katılımdan hemen sonra bilinir: katılımcı
/// başkalarının kaydını sayamaz (`RsvpRepository.waitlistPosition`
/// yönetime açıktır) — sıra, katılımın ardından okunan
/// `events.waitlistCount`'tur (W-76).
final class EventDetailState extends Equatable {
  /// Varsayılan: etkinlik yok, ziyaretçi.
  const EventDetailState({
    this.event,
    this.club,
    this.rsvp,
    this.access = ClubAccess.visitor,
    this.waitlistPosition,
    this.isFetching = false,
    this.isRefreshing = false,
    this.isError = false,
    this.isNotFound = false,
    this.isDenied = false,
    this.isActing = false,
  });

  /// Etkinlik; yüklenene kadar `null`.
  final EventModel? event;

  /// Düzenleyen kulüp; yüklenene kadar `null`.
  final ClubModel? club;

  /// Kullanıcının katılım kaydı (vazgeçilmiş `cancelled` dahil); hiç
  /// katılmadıysa `null`.
  final RsvpModel? rsvp;

  /// Kullanıcının etkinliğin kulübüne erişim kipi (`SessionState.accessTo`).
  final ClubAccess access;

  /// Bu ekranda bekleme listesine katılınca okunan sıra ("{n}. sıra");
  /// bilinmiyorsa `null`.
  final int? waitlistPosition;

  /// İlk yükleme sürüyor mu (iskelet)?
  final bool isFetching;

  /// Görünen içerik iskeletsiz yenileniyor mu?
  final bool isRefreshing;

  /// İlk yükleme başarısız mı (hata görünümü)?
  final bool isError;

  /// Etkinlik ya da kulübü yok / silinmiş / askıda (SYS-04).
  final bool isNotFound;

  /// Etkinlik okunamadı (üyelere özel ya da taslak — `permissionDenied`):
  /// TST-X18 gösterildi, ekran Etkinlikler sekmesine döner (CD-57).
  final bool isDenied;

  /// Katılım / vazgeçme / hatırlatıcı yazımı sürüyor mu?
  final bool isActing;

  /// Etkin katılım kaydı (`going`, `waitlist`, `attended`); vazgeçilmiş kayıt
  /// ve kayıt yoksa `null`.
  RsvpModel? get activeRsvp {
    final mine = rsvp;
    return mine == null || mine.status == RsvpStatus.cancelled ? null : mine;
  }

  /// Kulübün içini görüyor mu (üyelere özel etkinlik, katılımcı önizlemesi)?
  bool get seesInside => switch (access) {
    ClubAccess.member ||
    ClubAccess.manager ||
    ClubAccess.advisor ||
    ClubAccess.superAdmin => true,
    ClubAccess.visitor || ClubAccess.pending || ClubAccess.rejected => false,
  };

  /// Etkinliği yönetiyor mu (yönetici ya da süper admin — prototip
  /// `manager`)?
  bool get canManage =>
      access == ClubAccess.manager || access == ClubAccess.superAdmin;

  /// Danışman mı (salt okunur)?
  bool get isAdvisor => access == ClubAccess.advisor;

  /// [nowUtc] anında etkinlik bitti mi (`endsAt < şimdi`)?
  bool isPastAt(DateTime nowUtc) => event?.endsAt.isBefore(nowUtc) ?? false;

  /// [nowUtc] anında başlıktaki durum rozeti (`EventCardStatus.of`).
  EventCardStatus? statusAt(DateTime nowUtc) {
    final current = event;
    if (current == null) return null;
    return EventCardStatus.of(
      event: current,
      rsvp: activeRsvp,
      canSeeInside: seesInside,
      nowUtc: nowUtc,
    );
  }

  /// [nowUtc] anında alt çubuğun türü; etkinlik yüklenmediyse `null`.
  EventDetailBar? barAt(DateTime nowUtc) {
    final current = event;
    if (current == null) return null;
    if (current.status == EventStatus.cancelled) {
      return EventDetailBar.cancelled;
    }
    if (canManage) return EventDetailBar.manager;
    if (isAdvisor) return EventDetailBar.advisor;
    if (isPastAt(nowUtc)) return EventDetailBar.ended;
    return switch (statusAt(nowUtc)) {
      EventCardStatus.going => EventDetailBar.going,
      EventCardStatus.waitlist => EventDetailBar.waitlist,
      _ => EventDetailBar.cta,
    };
  }

  @override
  List<Object?> get props => [
    event,
    club,
    rsvp,
    access,
    waitlistPosition,
    isFetching,
    isRefreshing,
    isError,
    isNotFound,
    isDenied,
    isActing,
  ];

  /// Verilen alanları değiştirilmiş kopya. [clearRsvp] kaydı,
  /// [clearWaitlistPosition] bekleme sırasını boşaltır.
  EventDetailState copyWith({
    EventModel? event,
    ClubModel? club,
    RsvpModel? rsvp,
    bool clearRsvp = false,
    ClubAccess? access,
    int? waitlistPosition,
    bool clearWaitlistPosition = false,
    bool? isFetching,
    bool? isRefreshing,
    bool? isError,
    bool? isNotFound,
    bool? isDenied,
    bool? isActing,
  }) => EventDetailState(
    event: event ?? this.event,
    club: club ?? this.club,
    rsvp: clearRsvp ? null : rsvp ?? this.rsvp,
    access: access ?? this.access,
    waitlistPosition: clearWaitlistPosition
        ? null
        : waitlistPosition ?? this.waitlistPosition,
    isFetching: isFetching ?? this.isFetching,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isError: isError ?? this.isError,
    isNotFound: isNotFound ?? this.isNotFound,
    isDenied: isDenied ?? this.isDenied,
    isActing: isActing ?? this.isActing,
  );
}
