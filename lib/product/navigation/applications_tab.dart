/// MGT-02 "Başvurular" sekmeleri — `/clubs/:clubId/manage/applications?tab=`
/// sorgu parametresinin değerleri (navigation.md §2.2; aksiyonlar
/// `MGT-02.tab.<name>`).
///
/// Sıra ekrandaki sekme sırasıdır (`screens-manage.js:55` `Tabs`). Üye
/// adı sorgudaki değerdir (`ApplicationsTab.approved.name` →
/// `?tab=approved`); `tab` yoksa ya da tanınmıyorsa ekran [pending] ile
/// açılır.
///
/// Rota sınıfıyla birlikte `routes/shell_route.dart` üzerinden de dışa
/// aktarılır: faaliyet satırı (W-95) tek import ile
/// `ManageApplicationsRoute(clubId: id, tab: ApplicationsTab.rejected)` yazar
/// (`ClubDetailTab` kalıbı).
enum ApplicationsTab {
  /// Bekleyen başvurular (varsayılan).
  pending,

  /// Onaylanan başvurular.
  approved,

  /// Reddedilen başvurular.
  rejected,
}
