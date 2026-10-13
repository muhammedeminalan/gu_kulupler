# `test/fakes/` — el yazımı fake'ler

Mock kütüphanesi yok (packages.md §3, testing.md §1.2). Her fake:

- gerçek arayüzü uygular (`gu_data` repository/servis ya da `lib/core` arayüzü) ve bellekte çalışır;
- `FakeBase`'ten türer (`fake_base.dart`): çağrı günlüğü `calls` / `callsTo(method)`, tek seferlik hata `failNext([error])` → metot içinde `takeFailure()`;
- test yüzeyini (ör. `clubs`, `watchXController`) PLAN §16.3 tablosundaki adlarla açar;
- kendi `*_test.dart` dosyasına sahiptir (arayüz sözleşmesi);
- varsayılan kaydı `register_fakes.dart` → `registerDefaultFakes()` içine aynı commit'te eklenir (`pumpApp` her çağrıda `GetIt.I.reset()` + `registerDefaultFakes()`).

Kuralları olan bir katmanın fake'i o kuralları **yeniden yazmaz**: gerçek sınıfı bellekteki alt katman fake'i üzerinde çalıştırır ve üstüne çağrı günlüğü + `failNext` ekler — `FakeFirestoreService` (gerçek servis + `FakeFirebaseFirestore`), `FakeAuthRepository` (gerçek `FirebaseAuthRepository` + `FakeAuthService` + `FakeAppClock`: giriş kilidi, 60 sn bekleme, alan adı / şifre ön denetimi gerçek koddur). `registerDefaultFakes` `AuthService` ve `AuthRepository` için **aynı** `FakeAuthService`'i paylaştırır. Doğrulanmış oturumun `active` çözülmesi için `FakeUserRepository.putActive(uid)` ile profil kurulur (belge yoksa oturum `profileIncomplete` çözülür — T-12).

T-15 fake'leri (`FakeClubRepository`, `FakeMembershipRepository`, `FakeReportRepository`, `FakeBlockRepository`, `FakeActivityRepository`, `FakeNotificationDispatcher`) veriyi bellekteki haritalarda tutar (`clubs`, `memberships`, `contacts`, `reports`, `blocks`, `entries`). `FakeMembershipRepository` üyelik durum makinesini (M1–M4, M7, M8) kendi içinde uygular; kulüp koşullarını ve `memberCount` sayacını **paylaşılan** `FakeClubRepository`'den okur / işler (`registerDefaultFakes` aynı örneği verir) ve kurallarının gerçek `FirebaseMembershipRepository` ile aynı olduğu `fake_membership_repository_test.dart` içinde karşılaştırmalı sınanır — repository'ye geçiş eklendiğinde (T-30) fake ve o tablo birlikte genişler. Üyelik kurmak için `put(membership)`, akışa elle olay yazmak için `watchMyMembershipsController(uid)`; aktif üyelik rolü oturumda `SessionViewModel` üzerinden çözülür.

Dosya adı `fake_<ad>.dart`, sınıf `Fake<Ad>`. Saat/rastgelelik fake'leri (`FakeAppClock`, T-08) arayüzü doğduğu task'ta yazılır (CD-122(1)).

Sayfalı liste döndüren fake'ler ortak `FakePager.slice(list, page)` yardımcısını kullanır (`fake_pager.dart`); "sonraki sayfa var" demek için `PageCursor.fake()` üretir (`gu_data`; belgeli kurucu `@internal`'dır, paket dışından çağrılamaz). İmleç opaktır: kaldığı yer fake içinde kimlikle tutulur (`Expando<int>`); kalıp `page_cursor_fake_test.dart` içindedir (PLAN §16.3, CD-129).

Fake olmayan iki yardımcı da buradadır (PLAN §13.4, §16.3):

- `fake_session_states.dart` — hazır `SessionState` örnekleri (`FakeSessionStates.signedOut`, `activeManager('c01')` …); yönlendirme tablosu, guard ve kabuk testleri oturumu bunlarla kurar.
- `test_router.dart` — `TestRouter`: gerçek `GoRouter` + sahte oturum (`sessionViewModelProvider.overrideWithBuild`). `TestRouter.pump` uygulamanın gerçek rota ağacını, `TestRouter.pumpShell` gerçek `AppShellView`'ı derin test dallarıyla çizer; `locationLog`, `stackDepth(tab)`, `tapTab`, `systemBack`, `session=`.
