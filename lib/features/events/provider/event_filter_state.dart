import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';

/// SHT-11 "Tarih" çipi (prototip `f.date`: `all` / `today` / `week` /
/// `month` / `custom`, `sheets.js:56`). Sıra tasarımdaki çip sırasıdır.
enum EventDatePreset {
  /// "Tümü" — tarih süzgeci yok (varsayılan).
  all,

  /// "Bugün" — bugünün Istanbul günü.
  today,

  /// "Bu hafta" — bugünden itibaren 7 gün (prototip `t0 + 7 * DAY`).
  week,

  /// "Bu ay" — bugünden itibaren 30 gün (prototip `t0 + 30 * DAY`).
  month,

  /// "Özel aralık" — SHT-28 ile seçilen [EventFilterState.from] →
  /// [EventFilterState.to] (iki uç dahil).
  custom,
}

/// SHT-11 "Görünürlük" segmenti (prototip `f.visibility`: `all` / `public`
/// / `members`, `sheets.js:59`).
enum EventVisibilityFilter {
  /// "Tümü" (varsayılan).
  all,

  /// "Herkese açık" (`EventVisibility.public`).
  public,

  /// "Yalnızca üyeler" (`EventVisibility.membersOnly`).
  members,
}

/// SHT-11 "Sırala" satırı (prototip `f.sort`: `date` / `popular`,
/// `sheets.js:61`). Sıra tasarımdaki satır sırasıdır.
enum EventSort {
  /// "Tarihe göre" — başlangıç anı, yakından uzağa (varsayılan).
  date,

  /// "Popüler" — kayıtlı sayısı (`goingCount`), çoktan aza.
  popular,
}

/// Etkinlik listesinin süzgeci ve sıralaması — SHT-11 (prototip
/// `GU.eventFilters` / `DEFAULT_EF`, `screens-events.js:5–14`; CD-108,
/// `ClubFilters` kalıbı).
///
/// Değer nesnesidir: `EventListState.filter` alanında yaşar, SHT-11 taslağını
/// bunun kopyası üzerinde tutar ve "Uygula" ile geri verir. Varsayılan
/// ([none]) hiçbir şeyi süzmez, tarihe göre sıralar.
///
/// [from] / [to] **takvim günüdür** (yalnızca yıl / ay / gün okunur; saat ve
/// saat dilimi yok sayılır — SHT-28 / `GuCalendar` seçimi); [apply] onları
/// Istanbul günü olarak yorumlar (D-26). Yalnızca [datePreset] `custom`
/// iken anlamlıdır; [withDatePreset] başka bir seçimde ikisini de siler.
final class EventFilterState extends Equatable {
  /// Varsayılan: süzme yok, tarihe göre (prototip `DEFAULT_EF`).
  const EventFilterState({
    this.datePreset = EventDatePreset.all,
    this.from,
    this.to,
    this.clubIds = const <String>{},
    this.types = const <EventType>{},
    this.visibility = EventVisibilityFilter.all,
    this.freeOnly = false,
    this.sort = EventSort.date,
  });

  /// Süzgeçsiz varsayılan ("Temizle" / `SHT-11.clear`).
  static const EventFilterState none = EventFilterState();

  /// Tarih çipi.
  final EventDatePreset datePreset;

  /// Özel aralığın ilk günü (takvim günü; dahil). `custom` dışında `null`.
  final DateTime? from;

  /// Özel aralığın son günü (takvim günü; dahil); `null` → üst sınır yok.
  final DateTime? to;

  /// Seçili kulüpler; boş = tümü.
  final Set<String> clubIds;

  /// Seçili etkinlik türleri; boş = tümü.
  final Set<EventType> types;

  /// Görünürlük.
  final EventVisibilityFilter visibility;

  /// "Yalnızca boş kontenjan" — kontenjanı dolu etkinlik (`isFull`) düşer.
  final bool freeOnly;

  /// Sıralama.
  final EventSort sort;

  /// Etkin süzgeç sayısı — EVT-01 "Filtre" düğmesinin rozeti (prototip
  /// `efCount`): tarih, kulüp (kaç tane seçilirse seçilsin 1), tür (aynı),
  /// görünürlük, boş kontenjan, varsayılan dışı sıralama.
  int get activeCount =>
      (datePreset != EventDatePreset.all ? 1 : 0) +
      (clubIds.isNotEmpty ? 1 : 0) +
      (types.isNotEmpty ? 1 : 0) +
      (visibility != EventVisibilityFilter.all ? 1 : 0) +
      (freeOnly ? 1 : 0) +
      (sort != EventSort.date ? 1 : 0);

  /// [day] takvim gününün Istanbul'daki başlangıcı (UTC an): yalnızca yıl /
  /// ay / gün okunur (UTC+3 sabit, DST yok — domain-model §1.5).
  static DateTime istanbulDayStart(DateTime day) => DateTime.utc(
    day.year,
    day.month,
    day.day,
  ).subtract(Limits.istanbulUtcOffset);

  /// [events] listesini süzer ve sıralar (prototip `applyEventFilters`).
  ///
  /// Saf fonksiyondur: "bugün" [clock]'un Istanbul günüdür (`DateTime.now()`
  /// yok). Tarih aralıkları yarı açıktır (`[başlangıç, bitiş)`), başlangıç
  /// anına (`startsAt`) uygulanır. Geçmiş / iptal / askı süzgeci burada
  /// **yoktur** (çağıranın kaynak listesindedir). Eşitlikte girdi sırası
  /// korunur (kararlı sıralama).
  List<EventModel> apply(
    Iterable<EventModel> events, {
    required AppClock clock,
  }) {
    final (start, end) = _range(clock);
    final out = [
      for (final event in events)
        if (_matches(event, start, end)) event,
    ];
    final order = {
      for (final (index, event) in out.indexed) event.id: index,
    };
    int orElseInput(int result, EventModel a, EventModel b) =>
        result != 0 ? result : order[a.id]! - order[b.id]!;
    out.sort(
      (a, b) => switch (sort) {
        EventSort.date => orElseInput(a.startsAt.compareTo(b.startsAt), a, b),
        EventSort.popular => orElseInput(
          b.goingCount.compareTo(a.goingCount),
          a,
          b,
        ),
      },
    );
    return out;
  }

  /// Tarih çipinin `[start, end)` aralığı; `null` uç → sınır yok.
  (DateTime?, DateTime?) _range(AppClock clock) {
    final today = clock.istanbulStartOfDay(clock.nowUtc());
    return switch (datePreset) {
      EventDatePreset.all => (null, null),
      EventDatePreset.today => (today, today.add(AppConstants.calendarDay)),
      EventDatePreset.week => (today, today.add(AppConstants.eventWeekSpan)),
      EventDatePreset.month => (today, today.add(AppConstants.eventMonthSpan)),
      EventDatePreset.custom => switch ((from, to)) {
        (null, _) => (null, null),
        (final first?, null) => (istanbulDayStart(first), null),
        (final first?, final last?) => (
          istanbulDayStart(first),
          istanbulDayStart(last).add(AppConstants.calendarDay),
        ),
      },
    };
  }

  bool _matches(EventModel event, DateTime? start, DateTime? end) {
    final startsAt = event.startsAt;
    if (start != null && startsAt.isBefore(start)) return false;
    if (end != null && !startsAt.isBefore(end)) return false;
    if (clubIds.isNotEmpty && !clubIds.contains(event.clubId)) return false;
    if (types.isNotEmpty && !types.contains(event.type)) return false;
    switch (visibility) {
      case EventVisibilityFilter.all:
        break;
      case EventVisibilityFilter.public:
        if (event.visibility != EventVisibility.public) return false;
      case EventVisibilityFilter.members:
        if (event.visibility != EventVisibility.membersOnly) return false;
    }
    if (freeOnly && event.isFull) return false;
    return true;
  }

  /// Tarih çipini değiştirir; `custom` dışındaki seçim özel aralığı siler.
  EventFilterState withDatePreset(EventDatePreset preset) => EventFilterState(
    datePreset: preset,
    from: preset == EventDatePreset.custom ? from : null,
    to: preset == EventDatePreset.custom ? to : null,
    clubIds: clubIds,
    types: types,
    visibility: visibility,
    freeOnly: freeOnly,
    sort: sort,
  );

  /// SHT-28 ile seçilen özel aralık ([to] `null` → üst sınır yok).
  EventFilterState withCustomRange({required DateTime from, DateTime? to}) =>
      EventFilterState(
        datePreset: EventDatePreset.custom,
        from: from,
        to: to,
        clubIds: clubIds,
        types: types,
        visibility: visibility,
        freeOnly: freeOnly,
        sort: sort,
      );

  @override
  List<Object?> get props => [
    datePreset,
    from,
    to,
    clubIds,
    types,
    visibility,
    freeOnly,
    sort,
  ];

  /// Verilen alanları değiştirilmiş kopya. [from] / [to] `null` ile
  /// silinemez: tarih için [withDatePreset] / [withCustomRange].
  EventFilterState copyWith({
    EventDatePreset? datePreset,
    DateTime? from,
    DateTime? to,
    Set<String>? clubIds,
    Set<EventType>? types,
    EventVisibilityFilter? visibility,
    bool? freeOnly,
    EventSort? sort,
  }) => EventFilterState(
    datePreset: datePreset ?? this.datePreset,
    from: from ?? this.from,
    to: to ?? this.to,
    clubIds: clubIds ?? this.clubIds,
    types: types ?? this.types,
    visibility: visibility ?? this.visibility,
    freeOnly: freeOnly ?? this.freeOnly,
    sort: sort ?? this.sort,
  );
}
