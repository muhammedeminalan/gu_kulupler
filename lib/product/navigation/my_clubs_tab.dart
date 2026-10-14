/// PRF-03 "Kulüplerim" sekmeleri — `/profile/clubs?tab=` sorgu
/// parametresinin değerleri (navigation.md §2.5, PLAN §13.3.5).
///
/// Sıra ekrandaki sekme sırasıdır (`screens-profile.js` PRF-03 `Tabs`). Üye
/// adı sorgudaki değerdir (`MyClubsTab.pending.name` → `?tab=pending`); `tab`
/// yoksa ya da tanınmıyorsa ekran [active] ile açılır. Aksiyon anahtarları
/// tasarımın adlarıdır: [past] sekmesinin anahtarı `PRF-03.tab.history`.
///
/// Rota sınıfıyla birlikte `routes/shell_route.dart` üzerinden de dışa
/// aktarılır: Kulüpler sekmesi (CLB-01 "Kulüplerim" W-18, CLB-04
/// "Başvurularım" W-65) tek import ile
/// `MyClubsRoute(tab: MyClubsTab.pending)` yazar (`ClubDetailTab` kalıbı).
enum MyClubsTab {
  /// Aktif üyelikler (varsayılan).
  active,

  /// Bekleyen başvurular.
  pending,

  /// Geçmiş: ayrılınan, iptal edilen, reddedilen, çıkarılan üyelikler.
  past,
}
