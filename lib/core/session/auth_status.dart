/// Oturumun çözülmüş durumu (architecture §6, PLAN §12.2) — router
/// yönlendirmesinin (`AppRedirect`) tek girdisi.
///
/// Altı değerdir. `users.status == 'deleted'` ayrı bir değer **değildir**:
/// silinmiş hesap oturumu kapatılarak [signedOut]'a düşer.
enum AuthStatus {
  /// Oturum henüz çözülmedi (açılış) → SYS-01.
  unknown,

  /// Oturum yok → ONB-01 (ilk açılış) ya da AUT-01.
  signedOut,

  /// Oturum var, e-posta doğrulanmamış → AUT-03.
  unverified,

  /// E-posta doğrulanmış, profil eksik → AUT-05.
  profileIncomplete,

  /// Doğrulanmış ve profili tamam: uygulama rotaları açık.
  active,

  /// Hesap askıda → AUT-01 + DLG-01 (oturum kapatılır).
  suspended,
}
