/// ADM-05 "Kullanıcılar" süzgeçleri — `/admin/users?filter=` sorgu
/// parametresinin değerleri (aksiyonlar `ADM-05.filter.<name>`).
///
/// Enum sırası ekran sırası değildir (ekranda Tümü · Askıda · Yöneticiler;
/// sıra görünümde tanımlıdır). Üye adı sorgudaki değerdir
/// (`AdminUsersFilter.suspended.name` → `?filter=suspended`); `filter` yoksa
/// ya da tanınmıyorsa ekran [all] ile açılır.
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
