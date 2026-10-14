import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';
import 'package:gu_kulupler/features/events/provider/event_filter_state.dart';

/// EVT-01 görünümü (prototip `ui.eventView`; `EVT-01.view.<id>`).
enum EventListMode {
  /// Gün grupları altında kartlar (varsayılan).
  list,

  /// Ay takvimi + seçili günün kartları.
  calendar,
}

/// EVT-01 liste kipindeki hızlı çip (prototip `chip`, `screens-events.js:19`;
/// `EVT-01.chip.<id>`). Sıra tasarımdaki çip sırasıdır; tek seçimdir ve SHT-11
/// süzgecinin **üstüne** uygulanır.
enum EventListChip {
  /// "Tümü" (varsayılan).
  all,

  /// "Bugün" — başlangıcı bugünün Istanbul gününde.
  today,

  /// "Bu hafta" — başlangıcı bugünden itibaren 7 gün içinden önce.
  week,

  /// "Kulüplerim" — kullanıcının etkin üyesi olduğu kulüpler.
  mine,

  /// "Herkese açık" — `EventVisibility.public`.
  public,
}

/// EVT-01 "Etkinlikler" ekranının durumu (PLAN §12.6; süzgeç değer nesnesi
/// [EventFilterState], CD-108).
///
/// [events] istemci birleştirmesidir: herkese açık yaklaşanlar + kullanıcının
/// etkin üyesi olduğu her kulübün üyelere özel yaklaşanları; tekil, yalnızca
/// [clubs] (askıda olmayan) kulüplerin etkinlikleri, başlangıca göre artan.
/// Ekrandaki liste [visibleAt] ile türetilir (süzgeç + çip); takvim kipi
/// [events]'in tamamını kullanır (prototip `visibleEvents`).
///
/// Takvim günleri ([calendarMonth], [selectedDay]) **takvim günüdür**
/// (yalnızca yıl / ay / gün; Istanbul duvar saati — D-26).
final class EventListState extends Equatable {
  /// Varsayılan: etkinlik yok, süzgeç yok, liste kipi.
  const EventListState({
    this.events = const [],
    this.clubs = const [],
    this.rsvps = const {},
    this.memberClubIds = const {},
    this.filter = EventFilterState.none,
    this.chip = EventListChip.all,
    this.mode = EventListMode.list,
    this.calendarMonth,
    this.selectedDay,
    this.isFetching = false,
    this.isRefreshing = false,
    this.isError = false,
  });

  /// Birleştirilmiş etkinlikler (taslak yok; iptaller dahil), `startsAt ↑`.
  final List<EventModel> events;

  /// Askıda olmayan kulüpler (`fetchActiveClubs` sırası): kart kulüp adı /
  /// kapak ikonu ve SHT-11 kulüp çipleri.
  final List<ClubModel> clubs;

  /// Kullanıcının katılım kayıtları, etkinlik kimliğine göre (en yenisi).
  final Map<String, RsvpModel> rsvps;

  /// Kullanıcının etkin üyesi olduğu kulüpler (oturumdan canlı): "Kulüplerim"
  /// çipi, SHT-11 kulüp sırası ve kartın "içini görme" kararı.
  final Set<String> memberClubIds;

  /// SHT-11 süzgeci ve sıralaması.
  final EventFilterState filter;

  /// Hızlı çip.
  final EventListChip chip;

  /// Liste / takvim.
  final EventListMode mode;

  /// Takvimde gösterilen ay (ayın 1'i); `null` → bugünün ayı.
  final DateTime? calendarMonth;

  /// Takvimde seçili gün; `null` → bugün.
  final DateTime? selectedDay;

  /// İlk yükleme / "Yeniden dene" sürüyor (iskelet).
  final bool isFetching;

  /// Çek-yenile sürüyor (içerik ekranda kalır).
  final bool isRefreshing;

  /// Etkinlikler okunamadı (hata görünümü).
  final bool isError;

  /// Etkin süzgeç sayısı — "Filtre" çipinin rozeti (prototip `efCount`).
  int get activeFilterCount => filter.activeCount;

  /// Süzgeç ya da çip seçili mi? Boş görünümde "Filtreleri temizle"
  /// (`screens-events.js:30`).
  bool get hasActiveFilter =>
      filter.activeCount > 0 || chip != EventListChip.all;

  /// [clubId] kimlikli kulüp; listede yoksa `null`.
  ClubModel? clubById(String clubId) {
    for (final club in clubs) {
      if (club.id == clubId) return club;
    }
    return null;
  }

  /// Liste kipinin kaynağı (prototip `endsAt >= now || cancelled`): bitmemiş
  /// ya da iptal edilmiş etkinlikler.
  List<EventModel> upcomingAt(DateTime nowUtc) => [
    for (final event in events)
      if (!event.endsAt.isBefore(nowUtc) ||
          event.status == EventStatus.cancelled)
        event,
  ];

  /// Liste kipinde görünen etkinlikler: [upcomingAt] → [filter] (süzgeç +
  /// sıralama) → [chip]. "Bugün" [clock]'un Istanbul günüdür.
  List<EventModel> visibleAt(AppClock clock) {
    final now = clock.nowUtc();
    final today = clock.istanbulStartOfDay(now);
    final filtered = filter.apply(upcomingAt(now), clock: clock);
    bool matches(EventModel event) => switch (chip) {
      EventListChip.all => true,
      EventListChip.today =>
        !event.startsAt.isBefore(today) &&
            event.startsAt.isBefore(today.add(AppConstants.calendarDay)),
      EventListChip.week => event.startsAt.isBefore(
        today.add(AppConstants.eventWeekSpan),
      ),
      EventListChip.mine => memberClubIds.contains(event.clubId),
      EventListChip.public => event.visibility == EventVisibility.public,
    };
    return [
      for (final event in filtered)
        if (matches(event)) event,
    ];
  }

  /// [utc] anının Istanbul takvim günü (yerel `DateTime(y, m, d)`; saat yok —
  /// `GuCalendar` günü).
  static DateTime istanbulCalendarDay(DateTime utc) {
    final wall = utc.toUtc().add(Limits.istanbulUtcOffset);
    return DateTime(wall.year, wall.month, wall.day);
  }

  @override
  List<Object?> get props => [
    events,
    clubs,
    rsvps,
    memberClubIds,
    filter,
    chip,
    mode,
    calendarMonth,
    selectedDay,
    isFetching,
    isRefreshing,
    isError,
  ];

  /// Verilen alanları değiştirilmiş kopya.
  EventListState copyWith({
    List<EventModel>? events,
    List<ClubModel>? clubs,
    Map<String, RsvpModel>? rsvps,
    Set<String>? memberClubIds,
    EventFilterState? filter,
    EventListChip? chip,
    EventListMode? mode,
    DateTime? calendarMonth,
    DateTime? selectedDay,
    bool? isFetching,
    bool? isRefreshing,
    bool? isError,
  }) => EventListState(
    events: events ?? this.events,
    clubs: clubs ?? this.clubs,
    rsvps: rsvps ?? this.rsvps,
    memberClubIds: memberClubIds ?? this.memberClubIds,
    filter: filter ?? this.filter,
    chip: chip ?? this.chip,
    mode: mode ?? this.mode,
    calendarMonth: calendarMonth ?? this.calendarMonth,
    selectedDay: selectedDay ?? this.selectedDay,
    isFetching: isFetching ?? this.isFetching,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isError: isError ?? this.isError,
  );
}
