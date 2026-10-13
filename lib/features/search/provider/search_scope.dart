/// CLB-02 "Arama" ekranının sonuç sekmesi (prototip `params.tab`,
/// `screens-clubs.js:38`). Ekranı açan rota yalnızca başlangıç sekmesini
/// seçer; iki sekme de her iki rotada vardır (PLAN §13.9). Sıra ekrandaki
/// sekme sırasıdır (`CLB-02.tab.clubs`, `CLB-02.tab.events`).
enum SearchScope {
  /// "Kulüpler" — `ClubsSearchRoute` (`/clubs/search`).
  clubs,

  /// "Etkinlikler" — `EventsSearchRoute` (`/events/search`).
  events,
}
