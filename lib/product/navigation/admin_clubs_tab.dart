/// ADM-02 "Kulüpler" sekmeleri — `/admin/clubs?tab=` sorgu parametresinin
/// değerleri (navigation.md §2.6; aksiyonlar `ADM-02.tab.<name>`).
///
/// Sıra ekrandaki sekme sırasıdır. Üye adı sorgudaki değerdir
/// (`AdminClubsTab.suspended.name` → `?tab=suspended`); `tab` yoksa ya da
/// tanınmıyorsa ekran [active] ile açılır.
///
/// Rota sınıfıyla birlikte `routes/shell_route.dart` üzerinden de dışa
/// aktarılır (`ManageEventsTab` kalıbı): `AdminClubsRoute(tab:
/// AdminClubsTab.suspended)` tek import ile yazılır.
enum AdminClubsTab {
  /// Etkin kulüpler (varsayılan).
  active,

  /// Askıdaki kulüpler (`clubs.status == suspended`).
  suspended,
}
