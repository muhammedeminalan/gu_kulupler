/// Admin kökünün bölmeleri — `/admin?tab=` sorgu parametresinin değerleri
/// (navigation.md §2.6; `AdminSegmentBar` Genel · Kulüpler · Şikayetler ·
/// Kullanıcılar → ADM-01 · ADM-02 · ADM-04 · ADM-05).
///
/// Kullanıcı kararı (2026-10-16): dört bölme tek sayfadır (sekme kökü, alt
/// çubuk görünür); bölme değişimi rota yığınını değiştirmez, içerik solarak
/// değişir. Sıra ekrandaki sıradır. Üye adı sorgudaki değerdir
/// (`AdminTab.reports.name` → `?tab=reports`); `tab` yoksa sayfa son seçili
/// bölmeyi korur (ilk açılışta [overview]).
///
/// Rota sınıfıyla birlikte `routes/shell_route.dart` üzerinden de dışa
/// aktarılır (`ClubDetailTab` kalıbı).
enum AdminTab {
  /// Genel bakış (ADM-01; varsayılan).
  overview,

  /// Kulüpler (ADM-02).
  clubs,

  /// Şikayetler (ADM-04).
  reports,

  /// Kullanıcılar (ADM-05).
  users,
}
