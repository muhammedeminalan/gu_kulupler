/// CLB-03 "Kulüp" sekmeleri — `/clubs/:clubId?tab=` sorgu parametresinin
/// değerleri (navigation.md §2.2; aksiyonlar `CLB-03.tab.<name>`).
///
/// Sıra ekrandaki sekme sırasıdır (`screens-clubs.js:93`). Üye adı sorgudaki
/// değerdir (`ClubDetailTab.posts.name` → `?tab=posts`); `tab` yoksa ya da
/// tanınmıyorsa ekran [about] ile açılır.
///
/// Rota sınıfıyla birlikte `routes/shell_route.dart` üzerinden de dışa
/// aktarılır: kulübü belirli bir sekmeyle açan her feature (bildirimler,
/// etkinlikler, profil) tek import ile
/// `ClubDetailRoute(clubId: id, tab: ClubDetailTab.posts)` yazar (B05; aynı
/// gerekçe `LegalTab`, CD-134 madde 6).
enum ClubDetailTab {
  /// Hakkında (varsayılan).
  about,

  /// Etkinlikler.
  events,

  /// Gönderiler (FED-01 akışı; yalnızca kulübün içini görenlere açık).
  posts,

  /// Üyeler (ilk beş üye + "Tüm üyeler"; yalnızca kulübün içini görenlere
  /// açık).
  members,
}
