/// ADM-04 "Şikayetler" sekmeleri — `/admin?tab=reports&reportsTab=` sorgu
/// parametresinin değerleri (aksiyonlar `ADM-04.tab.<name>`).
///
/// Sıra ekrandaki sekme sırasıdır. Üye adı sorgudaki değerdir
/// (`AdminReportsTab.resolved.name` → `?reportsTab=resolved`); parametre
/// yoksa ya da tanınmıyorsa bölme son seçili sekmeyi korur (ilk açılışta
/// [open]).
///
/// Rota sınıfıyla birlikte `routes/shell_route.dart` üzerinden de dışa
/// aktarılır (`AdminClubsTab` kalıbı).
enum AdminReportsTab {
  /// Açık şikayetler (varsayılan; `reports.status == open`).
  open,

  /// Çözülen şikayetler (`reports.status == resolved`).
  resolved,
}
