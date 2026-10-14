/// EVT-04 sekmeleri — prototip `Segmented` sırası (`screens-events.js:93`;
/// `EVT-04.tab.<id>`) ve `/events/mine?tab=` sorgu parametresinin değerleri
/// (T-27: PRF-01 "Katıldığım etkinlik" kartı "Geçmiş" ile açar —
/// `screens-profile.js:12` `{tab:'past'}`).
///
/// Üye adı sorgudaki değerdir (`MyEventsTab.past.name` → `?tab=past`);
/// `tab` yoksa ya da tanınmıyorsa ekran [upcoming] ile açılır. Rota
/// sınıfıyla birlikte `routes/shell_route.dart` üzerinden de dışa aktarılır
/// (`MyClubsTab` kalıbı).
enum MyEventsTab {
  /// "Yaklaşan": kayıtlı (`going` / `attended`), bitmemiş, iptal edilmemiş.
  upcoming,

  /// "Geçmiş": bitmiş (`endsAt < şimdi`) ya da iptal edilmiş etkinlik.
  past,

  /// "Bekleme listesi": bekleme listesinde, bitmemiş, iptal edilmemiş.
  waitlist,
}
