/// MGT-04 "Etkinlik yönetimi" sekmeleri — `/clubs/:clubId/manage/events?tab=`
/// sorgu parametresinin değerleri (navigation.md §2.2; aksiyonlar
/// `MGT-04.tab.<name>`).
///
/// Sıra ekrandaki sekme sırasıdır. Üye adı sorgudaki değerdir
/// (`ManageEventsTab.draft.name` → `?tab=draft`); `tab` yoksa ya da
/// tanınmıyorsa ekran [published] ile açılır.
///
/// Rota sınıfıyla birlikte `routes/shell_route.dart` üzerinden de dışa
/// aktarılır (`ApplicationsTab` kalıbı): `ManageEventsRoute(clubId: id,
/// tab: ManageEventsTab.draft)` tek import ile yazılır.
enum ManageEventsTab {
  /// Yayındaki, henüz bitmemiş etkinlikler (varsayılan).
  published,

  /// Taslaklar.
  draft,

  /// Bitmiş yayındaki etkinlikler (`endsAt < şimdi`, türetilmiş durum —
  /// domain-model §2.7).
  past,

  /// İptal edilen etkinlikler.
  cancelled,
}
