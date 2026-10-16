/// ADM-02 "Kulüpler" sekmeleri — `/admin?tab=clubs&clubsTab=` sorgu
/// parametresinin değerleri (navigation.md §2.6; aksiyonlar
/// `ADM-02.tab.<name>`).
///
/// Sıra ekrandaki sekme sırasıdır. Üye adı sorgudaki değerdir
/// (`AdminClubsTab.suspended.name` → `?clubsTab=suspended`); parametre yoksa
/// ya da tanınmıyorsa bölme son seçili sekmeyi korur (ilk açılışta
/// [active]).
///
/// Rota sınıfıyla birlikte `routes/shell_route.dart` üzerinden de dışa
/// aktarılır (`ManageEventsTab` kalıbı): `AdminRoute(tab: AdminTab.clubs,
/// clubsTab: AdminClubsTab.suspended)` tek import ile yazılır.
enum AdminClubsTab {
  /// Etkin kulüpler (varsayılan).
  active,

  /// Askıdaki kulüpler (`clubs.status == suspended`).
  suspended,
}
