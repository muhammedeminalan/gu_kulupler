/// ADM-04 "Şikayetler" sekmeleri — `/admin/reports?tab=` sorgu
/// parametresinin değerleri (aksiyonlar `ADM-04.tab.<name>`).
///
/// Sıra ekrandaki sekme sırasıdır. Üye adı sorgudaki değerdir
/// (`AdminReportsTab.resolved.name` → `?tab=resolved`); `tab` yoksa ya da
/// tanınmıyorsa ekran [open] ile açılır.
///
/// Rota sınıfıyla birlikte `routes/shell_route.dart` üzerinden de dışa
/// aktarılır (`AdminClubsTab` kalıbı).
enum AdminReportsTab {
  /// Açık şikayetler (varsayılan; `reports.status == open`).
  open,

  /// Çözülen şikayetler (`reports.status == resolved`).
  resolved,
}
