/// Storage çağrılarının hata sözlüğü (PLAN §10.1, D-34).
///
/// İlk altı üye `firebase_storage` `FirebaseException.code` karşılığıdır
/// ([fromCode]); son dört üye ([sizeLimit], [invalidType], [noFile],
/// [timeout]) SDK dışıdır, yalnızca uygulama kodu üretir ve [fromCode] bunları
/// **asla** döndürmez.
enum StorageError {
  /// `unauthorized` ve `unauthenticated` — Storage Rules reddi (TST-X18).
  unauthorized,

  /// `object-not-found` — dosya yok; yer tutucu gösterilir (sessiz).
  notFound,

  /// `canceled` — yükleme iptal edildi; sessiz.
  canceled,

  /// `quota-exceeded` — depolama kotası aşıldı (SYS-02).
  quotaExceeded,

  /// `retry-limit-exceeded` — SDK yeniden deneme sınırını aştı (SYS-02).
  retryLimitExceeded,

  /// `invalid-checksum`, `bucket-not-found`, `project-not-found`,
  /// `invalid-url`, `invalid-argument`, `no-default-bucket` ve eşleşmeyen her
  /// kod (SYS-02).
  unknown,

  /// Uygulama: sıkıştırma sonrası dosya `Limits.imageMaxBytes` sınırını
  /// aşıyor.
  sizeLimit,

  /// Uygulama: içerik türü `image/jpeg`, `image/png`, `image/webp` dışında.
  invalidType,

  /// Uygulama: seçilen dosya okunamadı (TST-32).
  noFile,

  /// SDK dışı: yükleme `Limits.storageUploadTimeout` içinde bitmedi (SYS-02).
  timeout;

  /// `firebase_storage` `FirebaseException.code` değerini sözlüğe çevirir.
  ///
  /// Eşleşme birebirdir (küçük harf, tireli). Tabloda olmayan her değer
  /// [unknown] olur.
  static StorageError fromCode(String code) => switch (code) {
    'unauthorized' || 'unauthenticated' => unauthorized,
    'object-not-found' => notFound,
    'canceled' => canceled,
    'quota-exceeded' => quotaExceeded,
    'retry-limit-exceeded' => retryLimitExceeded,
    _ => unknown,
  };
}
