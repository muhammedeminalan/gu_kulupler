// Varsayılan fake kayıtları (CLAUDE.md §3, PLAN §16.2/§16.3).
//
// `pumpApp` her çağrıda `GetIt.I.reset()` sonrası bunu çağırır. Şimdilik
// kayıt yok: her fake kendi task'ında (T-10 servisler, T-12+ repository'ler)
// buraya bir satır ekler, ör.
//   GetIt.I.registerSingleton<AuthService>(FakeAuthService());

/// Varsayılan fake'leri `GetIt.I`'ye kaydeder.
void registerDefaultFakes() {}
