/// Form alanı doğrulama hatası (PLAN §12.1 "Form State kalıbı").
///
/// ViewModel'ler `errors: Map<XField, FormFieldError>` tutar; ARB metnine
/// çeviri view katmanındadır (ViewModel yerelleştirme görmez).
enum FormFieldError {
  /// Zorunlu alan boş.
  required,

  /// Alt sınırdan kısa.
  tooShort,

  /// Üst sınırdan uzun.
  tooLong,

  /// E-posta biçimi bozuk.
  invalidEmail,

  /// E-posta alan adı izinli listede değil (D-27).
  domainNotAllowed,

  /// Şifre politikaya uymuyor.
  passwordWeak,

  /// Şifre tekrarı eşleşmiyor.
  passwordMismatch,

  /// Zorunlu onay (KVKK / gizlilik) verilmedi.
  consentMissing,

  /// Sayı / adet sınırı aşıldı.
  limitExceeded,

  /// Biçim geçersiz.
  invalidFormat,

  /// Bitiş, başlangıçtan önce.
  endBeforeStart,

  /// Kontenjan, katılımcı sayısının altında.
  capacityBelowGoing,
}

/// Form gönderiminin başarısızlık türü (PLAN §12.1): alana bağlanamayan
/// hatalar için.
enum SubmitError {
  /// Ağ yok / zaman aşımı.
  network,

  /// Yetki yok.
  permission,

  /// Çakışma (kayıt bu arada değişti).
  conflict,

  /// Diğer.
  unknown,
}
