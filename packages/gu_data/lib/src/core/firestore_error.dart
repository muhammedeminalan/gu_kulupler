/// Firestore çağrılarının hata sözlüğü (PLAN §10.1, D-34).
///
/// İlk on bir üye `FirebaseException.code` karşılığıdır ([fromCode]); son beş
/// üye ([timeout], [parse], [offline], [conflict], [ruleViolation]) SDK
/// dışıdır, yalnızca uygulama kodu üretir ve [fromCode] bunları **asla**
/// döndürmez.
enum FirestoreError {
  /// `permission-denied` — Security Rules reddi (TST-X18).
  permissionDenied,

  /// `unauthenticated` — oturum düşmüş (DLG-27).
  unauthenticated,

  /// `not-found` — belge yok ya da soft delete edilmiş (SYS-04).
  notFound,

  /// `already-exists` — belge zaten var (DLG-18 ya da repository'ye özel).
  alreadyExists,

  /// `aborted` — transaction çekişmesi; `RetryPolicy` yeniden dener.
  aborted,

  /// `unavailable` ve `deadline-exceeded` — servis geçici olarak erişilemez
  /// (SYS-02 / TST-24); `RetryPolicy` yeniden dener.
  unavailable,

  /// `invalid-argument` — program hatası (SYS-02).
  invalidArgument,

  /// `failed-precondition` — ön koşul tutmadı; emülatörde eksik indeks.
  failedPrecondition,

  /// `resource-exhausted` — kota aşıldı (SYS-02).
  resourceExhausted,

  /// `cancelled` — çağrı iptal edildi (ekran kapandı); sessiz.
  cancelled,

  /// `data-loss`, `internal`, `unimplemented`, `out-of-range`, `unknown` ve
  /// eşleşmeyen her kod (SYS-02).
  unknown,

  /// SDK dışı: çağrı `Limits.firestoreTimeout` içinde dönmedi (SYS-02).
  timeout,

  /// SDK dışı: belge var ama modele ayrıştırılamadı (SYS-04).
  parse,

  /// Uygulama: `ConnectivityGate` çevrimdışıyken yazmayı engelledi (TST-24).
  offline,

  /// Uygulama: transaction içinde beklenen durum tutmadı (DLG-18).
  conflict,

  /// Uygulama: iş kuralı reddi; hangi kural olduğu [FirestoreRuleCode] ile
  /// `FirestoreFailureDetail` içinde taşınır.
  ruleViolation;

  /// `FirebaseException.code` değerini (`permission-denied`, `not-found` …)
  /// sözlüğe çevirir.
  ///
  /// Eşleşme birebirdir (küçük harf, tireli; kırpma ya da büyük/küçük harf
  /// dönüşümü yapılmaz). Tabloda olmayan her değer [unknown] olur.
  static FirestoreError fromCode(String code) => switch (code) {
    'permission-denied' => permissionDenied,
    'unauthenticated' => unauthenticated,
    'not-found' => notFound,
    'already-exists' => alreadyExists,
    'aborted' => aborted,
    'unavailable' || 'deadline-exceeded' => unavailable,
    'invalid-argument' => invalidArgument,
    'failed-precondition' => failedPrecondition,
    'resource-exhausted' => resourceExhausted,
    'cancelled' => cancelled,
    _ => unknown,
  };
}

/// [FirestoreError.ruleViolation] ile dönen iş kuralı reddinin türü
/// (PLAN §10.1).
///
/// Kullanıcıya gösterilecek geri bildirimi (toast, diyalog, sheet) ViewModel
/// bu koda göre seçer.
enum FirestoreRuleCode {
  /// Kulüp başvuruya kapalı (`applicationsOpen == false`) — TST-X1.
  applicationsClosed,

  /// Ret ya da çıkarma sonrası bekleme süresi dolmadı (`retryAfter`
  /// gelecekte) — TST-X4.
  retryCooldown,

  /// Reddedilmiş ya da çıkarılmış kullanıcı anında katılamaz; başvuru akışına
  /// yönlendirilir — SHT-05.
  reapplyNeedsReview,

  /// Etkinlik kontenjanı dolu — DLG-15.
  capacityFull,

  /// Etkinlik kaydı kapalı — TST-X2.
  registrationClosed,

  /// Etkinlik sona ermiş — TST-X6.
  eventEnded,

  /// Günlük duyuru sınırı doldu — DLG-24.
  announcementLimit,

  /// Başkan, başkanlığı devretmeden kulüpten ayrılamaz — DLG-09.
  presidentCannotLeave,

  /// Başkan üyelikten çıkarılamaz — TST-X10.
  presidentCannotBeRemoved,

  /// Kayıtlı katılımcısı olan etkinlik taslağa alınamaz (K-F).
  eventHasRegistrations,

  /// Yoklama penceresi kapalı (K-G) — MGT-06 bandı.
  attendanceWindowClosed,

  /// İşlem yalnızca kulüp üyelerine açık — TST-X18.
  notMember,
}
