import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/navigation/my_events_tab.dart';

// Sekme türü rota sorgusuyla paylaşılır (ürün katmanı); durumu kullanan
// dosyalar ayrıca içe aktarmasın diye buradan da dışa aktarılır.
export 'package:gu_kulupler/product/navigation/my_events_tab.dart'
    show MyEventsTab;

/// Bir satır: kullanıcının kaydı + etkinliği.
typedef MyEventEntry = (RsvpModel, EventModel);

/// EVT-04 "Etkinliklerim" ekranının durumu (PLAN §12.6).
///
/// * [rsvps] kullanıcının katılım kayıtlarıdır (`listMine`, en yeni üstte;
///   açılışta vazgeçilmişler süzülür, ekranda vazgeçilen kayıt `cancelled`
///   olarak kalır ve çizilmez — prototip `rsvp.leave` kaydı siler).
/// * Etkinlikler kayıt sırasıyla [Limits.pageSize]'lık sayfalarla okunur
///   ([loadedCount] kayıt okundu; [hasMore]). Okunamayan (görünmeyen,
///   silinmiş) etkinliğin kaydı çizilmez.
/// * [pendingIds] vazgeçme yazımı süren etkinliklerdir: satır iyimser
///   gizlenir, hata gelirse geri gelir.
/// * Sekme ayrımı [tabOf] ile yapılır; görünen liste [visibleAt].
final class MyEventsState extends Equatable {
  /// Varsayılan: içerik yok, "Yaklaşan" sekmesi.
  const MyEventsState({
    this.tab = MyEventsTab.upcoming,
    this.rsvps = const [],
    this.events = const {},
    this.clubNames = const {},
    this.loadedCount = 0,
    this.pendingIds = const {},
    this.isFetching = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.isError = false,
  });

  /// Seçili sekme.
  final MyEventsTab tab;

  /// Kullanıcının katılım kayıtları (`createdAt ↓`).
  final List<RsvpModel> rsvps;

  /// Okunan etkinlikler, kimliğe göre.
  final Map<String, EventModel> events;

  /// Kulüp adları, kulüp kimliğine göre (alt satır; okunamazsa yalnızca
  /// saat).
  final Map<String, String> clubNames;

  /// Etkinliği okunmuş kayıt sayısı ([rsvps] başından).
  final int loadedCount;

  /// Vazgeçme yazımı süren etkinlik kimlikleri (satır gizli).
  final Set<String> pendingIds;

  /// İlk okuma sürüyor (iskelet).
  final bool isFetching;

  /// Çek-yenile sürüyor.
  final bool isRefreshing;

  /// Sonraki sayfa okunuyor.
  final bool isLoadingMore;

  /// Kayıtlar okunamadı ve gösterilecek içerik yok.
  final bool isError;

  /// Etkinliği henüz okunmamış kayıt var mı?
  bool get hasMore => loadedCount < rsvps.length;

  /// Sonraki sayfa istenebilir mi (başka okuma sürmüyor)?
  bool get wantsMore =>
      hasMore && !isFetching && !isRefreshing && !isLoadingMore && !isError;

  /// [event] bitmiş mi? Sınır: `endsAt < şimdi` (bitiş anı henüz geçmiş
  /// sayılmaz — roadmap T-24 "geçmiş = bitiş < şimdi").
  static bool isPast(EventModel event, DateTime nowUtc) =>
      event.endsAt.isBefore(nowUtc);

  /// [rsvp] kaydının sekmesi; vazgeçilmiş kayıt `null` (çizilmez).
  ///
  /// İptal edilmiş etkinlik "Geçmiş"tedir (prototip `screens-events.js:92`);
  /// bitmiş ya da iptal edilmiş etkinliğin bekleme kaydı da "Geçmiş"tedir
  /// (iki sekmede birden görünmez).
  static MyEventsTab? tabOf(
    RsvpModel rsvp,
    EventModel event,
    DateTime nowUtc,
  ) {
    if (rsvp.status == RsvpStatus.cancelled) return null;
    if (isPast(event, nowUtc) || event.status == EventStatus.cancelled) {
      return MyEventsTab.past;
    }
    return rsvp.status == RsvpStatus.waitlist
        ? MyEventsTab.waitlist
        : MyEventsTab.upcoming;
  }

  /// "Vazgeç" (`EVT-04.leave.<id>`) çizilir mi? Yalnızca kayıt `going` /
  /// `waitlist` iken (yoklaması alınmış kayıttan vazgeçilmez) ve etkinlik
  /// bitmeden (`endsAt > şimdi`; W-81 (b)), iptal edilmemişken.
  static bool canLeave(RsvpModel rsvp, EventModel event, DateTime nowUtc) =>
      (rsvp.status == RsvpStatus.going || rsvp.status == RsvpStatus.waitlist) &&
      event.endsAt.isAfter(nowUtc) &&
      event.status != EventStatus.cancelled;

  /// [tab] sekmesinin satırları: geçmiş başlangıcı en yeni üstte, diğerleri
  /// en yakın üstte (`screens-events.js:92`). Etkinliği okunmamış ve
  /// vazgeçme yazımı süren kayıtlar çizilmez.
  List<MyEventEntry> entriesOf(MyEventsTab tab, DateTime nowUtc) {
    final list = <MyEventEntry>[
      for (final rsvp in rsvps.take(loadedCount))
        if (!pendingIds.contains(rsvp.eventId))
          if (events[rsvp.eventId] case final event?)
            if (tabOf(rsvp, event, nowUtc) == tab) (rsvp, event),
    ];
    return list..sort(
      (a, b) => tab == MyEventsTab.past
          ? b.$2.startsAt.compareTo(a.$2.startsAt)
          : a.$2.startsAt.compareTo(b.$2.startsAt),
    );
  }

  /// Seçili sekmenin satırları ([entriesOf]).
  List<MyEventEntry> visibleAt(DateTime nowUtc) => entriesOf(tab, nowUtc);

  /// [eventId] etkinliğinin satırı (okunmuş kayıtlarda); yoksa `null`.
  MyEventEntry? entryOf(String eventId) {
    for (final rsvp in rsvps.take(loadedCount)) {
      if (rsvp.eventId != eventId) continue;
      final event = events[eventId];
      return event == null ? null : (rsvp, event);
    }
    return null;
  }

  @override
  List<Object?> get props => [
    tab,
    rsvps,
    events,
    clubNames,
    loadedCount,
    pendingIds,
    isFetching,
    isRefreshing,
    isLoadingMore,
    isError,
  ];

  /// Verilen alanları değiştirilmiş kopya.
  MyEventsState copyWith({
    MyEventsTab? tab,
    List<RsvpModel>? rsvps,
    Map<String, EventModel>? events,
    Map<String, String>? clubNames,
    int? loadedCount,
    Set<String>? pendingIds,
    bool? isFetching,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? isError,
  }) => MyEventsState(
    tab: tab ?? this.tab,
    rsvps: rsvps ?? this.rsvps,
    events: events ?? this.events,
    clubNames: clubNames ?? this.clubNames,
    loadedCount: loadedCount ?? this.loadedCount,
    pendingIds: pendingIds ?? this.pendingIds,
    isFetching: isFetching ?? this.isFetching,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    isError: isError ?? this.isError,
  );
}
