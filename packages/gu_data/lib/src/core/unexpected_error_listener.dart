/// Beklenmeyen hata dinleyicisi (T-44 · D2-03): `gu_data` hatayı
/// raporlamaz (Crashlytics uygulama katmanındadır — Q-05); servis ve
/// repository yardımcıları beklenmeyen hatayı bu geri çağrıyla dışarı verir,
/// `ProjectDependency` onu `CrashService.recordError(fatal: false)`'a bağlar.
///
/// [reason] kişisel veri içermez: hata kodu ve maskelenmiş koleksiyon kalıbı
/// (`firestore:parse:clubs/*/events/*`). Dinleyici fırlatmamalıdır; çağıran
/// yine de sarar.
typedef UnexpectedErrorListener =
    void Function(Object error, StackTrace stack, String reason);
