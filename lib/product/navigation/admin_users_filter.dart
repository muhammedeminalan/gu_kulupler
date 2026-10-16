/// ADM-05 "Kullanıcılar" süzgeçleri — `/admin?tab=users&filter=` sorgu
/// parametresinin değerleri (aksiyonlar `ADM-05.filter.<name>`).
///
/// Enum sırası ekran sırası değildir (ekranda Tümü · Askıda · Yöneticiler;
/// sıra görünümde tanımlıdır). Üye adı sorgudaki değerdir
/// (`AdminUsersFilter.suspended.name` → `?filter=suspended`); `filter` yoksa
/// ya da tanınmıyorsa bölme son seçili süzgeci korur (ilk açılışta [all]).
///
/// Rota sınıfıyla birlikte `routes/shell_route.dart` üzerinden de dışa
/// aktarılır (`AdminClubsTab` kalıbı).
enum AdminUsersFilter {
  /// Tüm kullanıcılar (varsayılan).
  all,

  /// Herhangi bir kulüpte etkin yönetici (`board` / `president`) olanlar.
  managers,

  /// Askıdaki hesaplar (`users.status == suspended`).
  suspended,
}
