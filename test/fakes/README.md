# `test/fakes/` — el yazımı fake'ler

Mock kütüphanesi yok (packages.md §3, testing.md §1.2). Her fake:

- gerçek arayüzü uygular (`gu_data` repository/servis ya da `lib/core` arayüzü) ve bellekte çalışır;
- `FakeBase`'ten türer (`fake_base.dart`): çağrı günlüğü `calls` / `callsTo(method)`, tek seferlik hata `failNext([error])` → metot içinde `takeFailure()`;
- test yüzeyini (ör. `clubs`, `watchXController`) PLAN §16.3 tablosundaki adlarla açar;
- kendi `*_test.dart` dosyasına sahiptir (arayüz sözleşmesi);
- varsayılan kaydı `register_fakes.dart` → `registerDefaultFakes()` içine aynı commit'te eklenir (`pumpApp` her çağrıda `GetIt.I.reset()` + `registerDefaultFakes()`).

Dosya adı `fake_<ad>.dart`, sınıf `Fake<Ad>`. Saat/rastgelelik fake'leri (`FakeAppClock`, T-08) arayüzü doğduğu task'ta yazılır (CD-122(1)).
