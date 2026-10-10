/// Kimlik (Auth) çağrılarının hata sözlüğü (PLAN §10.1, D-34).
///
/// İlk on iki üye `FirebaseAuthException.code` karşılığıdır ([fromCode]); son
/// dört üye ([domainNotAllowed], [lockedOut], [resendCooldown],
/// [emailNotVerified]) uygulama kurallarıdır, yalnızca uygulama kodu üretir ve
/// [fromCode] bunları **asla** döndürmez.
enum AuthError {
  /// `invalid-email` — e-posta biçimi geçersiz (AUT-01/02 alan hatası).
  invalidEmail,

  /// `user-disabled` — hesap askıda (DLG-01).
  userDisabled,

  /// `user-not-found`, `wrong-password`, `invalid-credential`,
  /// `INVALID_LOGIN_CREDENTIALS` — e-posta ya da şifre hatalı (TST-01).
  invalidCredentials,

  /// `email-already-in-use` — e-posta kayıtlı (AUT-02 alan hatası).
  emailAlreadyInUse,

  /// `weak-password` — şifre zayıf (AUT-02 alan hatası).
  weakPassword,

  /// `too-many-requests` — çok fazla deneme (DLG-02).
  tooManyRequests,

  /// `network-request-failed` — ağ yok (TST-24).
  network,

  /// `requires-recent-login` — yeniden kimlik doğrulama gerekir (SHT-32).
  requiresRecentLogin,

  /// `user-token-expired`, `user-mismatch`, `invalid-user-token` — oturum
  /// geçersiz (DLG-27).
  sessionExpired,

  /// `invalid-action-code`, `expired-action-code` — sıfırlama bağlantısı
  /// geçersiz (AUT-04).
  invalidActionCode,

  /// `operation-not-allowed` — sağlayıcı kapalı; yapılandırma hatası (SYS-02).
  operationNotAllowed,

  /// Eşleşmeyen her kod (SYS-02).
  unknown,

  /// Uygulama: e-posta alan adı `EmailDomainPolicy.allowedDomains` dışında
  /// (AUT-02 alan hatası; CD-76).
  domainNotAllowed,

  /// Uygulama: `LoginThrottle` kilitli (DLG-02 geri sayımı).
  lockedOut,

  /// Uygulama: doğrulama e-postası bekleme süresi dolmadı (TST-X3).
  resendCooldown,

  /// Uygulama: e-posta doğrulanmamış (TST-02).
  emailNotVerified;

  /// `FirebaseAuthException.code` değerini sözlüğe çevirir.
  ///
  /// Eşleşme birebirdir (kırpma ya da büyük/küçük harf dönüşümü yapılmaz;
  /// `INVALID_LOGIN_CREDENTIALS` SDK'nın büyük harfli yazımıdır). Tabloda
  /// olmayan her değer [unknown] olur.
  static AuthError fromCode(String code) => switch (code) {
    'invalid-email' => invalidEmail,
    'user-disabled' => userDisabled,
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' ||
    'INVALID_LOGIN_CREDENTIALS' => invalidCredentials,
    'email-already-in-use' => emailAlreadyInUse,
    'weak-password' => weakPassword,
    'too-many-requests' => tooManyRequests,
    'network-request-failed' => network,
    'requires-recent-login' => requiresRecentLogin,
    'user-token-expired' ||
    'user-mismatch' ||
    'invalid-user-token' => sessionExpired,
    'invalid-action-code' || 'expired-action-code' => invalidActionCode,
    'operation-not-allowed' => operationNotAllowed,
    _ => unknown,
  };
}
