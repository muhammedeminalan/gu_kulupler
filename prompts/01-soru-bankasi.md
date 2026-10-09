# Soru Bankası — 20 soru, 5 tur

> **Kullanım:** `prompts/00-baslat.md` §3 bu dosyayı sırayla uygular. Her tur **tek bir `AskUserQuestion` çağrısıdır** (4 soru). Düz metinle soru **sorulmaz** (`.claude/skills/gu-ask-user/SKILL.md`).
> **Kural:** İlk seçenek **önerilen**dir ve etiketinin sonuna ` (Önerilen)` eklenir. Kullanıcı "Diğer" ile serbest metin girebilir (araç otomatik ekler) — serbest cevap belirsizse aynı konuyu tek soruyla netleştir.
> **Cevaplar** `docs/decisions.md §B` tablosuna **olduğu gibi** yazılır (seçilen etiket + tarih) ve `docs/progress.json#questionsAnswered`'a işlenir. Cevaplanan Q-xx, D-xx gibi **kilitlenir**.
> **Sıra bağımlılığa göre kurulmuştur:** Tur 1'in cevapları (Blaze/Storage) sonraki turların seçeneklerini değiştirir; aşağıdaki **"Uyarlama"** satırlarına göre seçenekleri ele/ekle (bir seçeneği çıkarırsan, 2'nin altına inme).
> `header` en çok 12 karakter. Seçenek `label`ı 1–5 kelime, `description` tek kısa cümle (neyi getirir / neyi götürür).

## Tur özeti

| Tur | Konu | Sorular |
|---|---|---|
| 1 | Firebase altyapısı | Q-02 Functions/Blaze · Q-19 Fotoğraf yükleme · Q-01 Backend modu · Q-03 Ortamlar |
| 2 | Kimlik, paket, test, takvim | Q-04 Kimlik doğrulama · Q-05 Paket yapısı · Q-06 Servis testi · Q-08 Takvim |
| 3 | Bildirim ve veri kuralları | Q-07 Hatırlatıcı/bildirim · Q-09 Rol kaynağı · Q-10 Duyuru limiti · Q-11 Hesap silme |
| 4 | Çevrimdışı, cihaz, gezinme | Q-12 Çevrimdışı · Q-13 Cihaz kapsamı · Q-14 Yazı boyutu · Q-20 Sekmeler arası geri |
| 5 | Tasarım ve süreç | Q-15 Tasarım bulguları · Q-16 Golden · Q-17 Git akışı · Q-18 CI |

**Tur sonu:** Cevapları `decisions.md`'ye yaz → kısa özet göster (Türkçe, tablo) → sonraki tura geç. Tüm turlar bitince §K-adayları'nı değerlendir (en çok **2 ek tur**, her tur ≤ 4 soru).

**Tur öncesi keşif (sormadan öğren):** `firebase.json`, `.firebaserc`, `lib/firebase_options.dart`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, `pubspec.yaml`, `git log --oneline | head`, `firebase --version`, `flutter --version` mevcut mu bak ve sorulara **bağlam** olarak ekle ("projede `gu-kulupler-xxxx` kimliği var" gibi). Plan türünü (Spark/Blaze) komutla **öğrenemezsin** — Q-02'nin açıklamasında kullanıcıya "Firebase konsolu → Kullanım ve faturalandırma" bakmasını söyle ve cevabı sor.

---

## TUR 1 — Firebase altyapısı

### Q-02 · Cloud Functions / Blaze planı
- **header:** `Functions`
- **soru:** Sunucu tarafı kod (Cloud Functions) kullanılacak mı? Bu, Blaze (kullandıkça öde, kredi kartı gerekir) planını gerektirir.
- **seçenekler:**
  1. **Önce yalnızca istemci (Önerilen)** — Mod C ile başla (Spark yeter): uygulama içi bildirim listesi + cihazda planlı hatırlatıcı; push ve otomatik bekleme terfisi sonra karar. `NotificationDispatcher` sayesinde sonradan Functions'a geçiş kod dalı değiştirmez.
  2. **Functions kullan (Blaze)** — Mod F: gerçek push (FCM), zamanlanmış hatırlatıcı, otomatik terfi, sunucu tarafı hesap temizliği; T-42 yapılır, Blaze + kart gerekir.
  3. **Yalnızca istemci, kesin** — Functions hiç yapılmayacak; T-42 kalıcı olarak atlanır, push olmayacağı ürün kararı olur.
- **Etki:** T-25, T-42 (koşullu), T-45, T-46; Q-07, Q-11 seçenekleri; `docs/architecture.md §7`; `docs/packages.md §2.1` (`firebase_messaging`, `cloud_functions`).
- **Not (Storage):** Firebase, Eylül 2024'ten beri **yeni projelerde Spark planında varsayılan Storage bucket'ı vermiyor** (Blaze gerekir; Blaze'de ücretsiz kota vardır). Bu yüzden Q-02 ile Q-19 birlikte değerlendirilir — soruyu sorarken bunu açıklamaya ekle.
- **Uyarlama:** Cevap 1 ya da 3 → Q-07'de FCM seçeneği yok; Q-11'de "Functions ile kalıcı silme" yok. Cevap 1 → T-42 `pending` kalır, T-43 başında **bir kez daha** sorulur (`AskUserQuestion`: "Functions'a geçelim mi?"). Cevap 3 → T-42 `skipped`.

### Q-19 · Fotoğraf / görsel yükleme
- **header:** `Fotoğraf`
- **soru:** Kullanıcı fotoğrafları (profil resmi, kulüp logo/kapağı, gönderi görselleri, destek ekran görüntüsü) Firebase Storage'a yüklensin mi?
- **seçenekler:**
  1. **Storage'a yükle (Önerilen)** — Avatar, logo/kapak, gönderi görseli (≤ 4, ≤ 5 MB, istemci sıkıştırma); `image_picker`, `flutter_image_compress`, `cached_network_image`, `firebase_storage`. **Blaze veya mevcut bucket gerekir** (Q-02 notuna bak).
  2. **Yalnızca profil + kulüp** — Avatar ve kulüp logo/kapağı yüklenir; gönderiye görsel eklenmez (FED-03 "görsel ekle" ve SHT-34 galerisi **K-18 kuralıyla** sorulur/uyarlanır).
  3. **Yükleme yok** — Avatar baş harf/şablon, kapak tasarım şablonu (renk × desen); `firebase_storage`, `image_picker` paketleri hiç eklenmez, Storage Rules tamamen kilitli.
- **Etki:** `docs/packages.md §2.1`; `docs/firestore-rules-spec.md §7`; T-14, T-19, T-21, T-28, T-34, T-36, T-39; K-18 (design-known-issues).
- **Uyarlama:** Q-02 sonucu Spark ve kullanıcı bucket'ı olmadığını söylediyse → seçenek 1'in açıklamasına "Blaze'e geçişi gerektirir" yaz ve 2/3'ü öne çıkar; öneri **2** olur (etiketi `(Önerilen)` taşır).
- **Cevap 2 veya 3 ise ek soru:** K-18/G-3 — "Gönderi görsel akışı (FED-03 `addImage`, SHT-34) tasarımda var; nasıl ele alınsın?" → (a) yer tutucu desenle görsel yok akışı gizlenir (tasarımdan sapma, onaylı) (b) seçici açılır ama yükleme yok uyarısı (c) kullanıcı Blaze'e geçince açılır (T-21 notlu). Bu, K-adayı turuna eklenir.

### Q-01 · Backend geliştirme modu
- **header:** `Backend`
- **soru:** Geliştirme sırasında veri nerede çalışsın?
- **seçenekler:**
  1. **Emülatör önce (Önerilen)** — Tüm geliştirme ve testler Firebase Emulator Suite'te (`ENV=emulator`); gerçek projeye yalnızca sen onaylayınca (Rules/index deploy, canlı deneme) dokunulur.
  2. **Doğrudan gerçek proje** — Hızlı başlar ama test verisi canlıya karışır; Rules testleri yine emülatörde yazılır.
  3. **Önce sahte repository** — Firebase'siz arayüz geliştirme (bellek içi fake'ler), backend sonra bağlanır; iki kat iş.
- **Etki:** T-10, T-12, T-43; `docs/architecture.md §5`; `AppEnvironment`; `tool/seed`.
- **Uyarlama:** Cevap 3 → T-10 kapsamına "InMemory repository seti" eklenir (`docs/PLAN.md`'de açık not); K-sorusu: "fake'ler kalıcı mı geçici mi".

### Q-03 · Firebase ortamları
- **header:** `Ortam`
- **soru:** Kaç Firebase projesiyle çalışacağız?
- **seçenekler:**
  1. **Tek proje + emülatör (Önerilen)** — Mevcut/gelecek tek gerçek proje ve yerel emülatör; en az kurulum.
  2. **dev + prod iki proje** — `--dart-define=ENV=dev|prod`, iki `firebase_options`; test verisi canlıdan ayrı, bakım iki kat.
  3. **Şimdilik yalnızca emülatör** — Gerçek proje bağlama T-46'ya (yayın hazırlığı) kalır.
- **Etki:** T-00 (`.firebaserc`, `firebase.json`), T-10, T-46; `docs/architecture.md §5`.
- **Uyarlama:** Keşifte `firebase_options.dart` zaten varsa açıklamaya proje kimliğini yaz; "yeniden üretme" kuralını hatırlat (`flutterfire configure` yalnızca sen istersen).

**Tur 1 sonu:** yaz → özet → Tur 2.

---

## TUR 2 — Kimlik, paket, test, takvim

### Q-04 · Kimlik doğrulama yöntemi
- **header:** `Kimlik`
- **soru:** Kayıt ve e-posta doğrulama nasıl çalışsın? (Tasarım: e-posta + şifre, "Doğruladım" düğmesi, 60 sn yeniden gönder.)
- **seçenekler:**
  1. **E-posta/şifre + Firebase doğrulama bağlantısı (Önerilen)** — Tasarımla birebir: Firebase yerleşik doğrulama e-postası (TR şablon konsoldan), kullanıcı bağlantıya tıklayıp uygulamaya dönüp "Doğruladım" der; alan adı kısıtı Rules'ta.
  2. **Bağlantıyla uygulamaya geri dönüş** — Doğrulama bağlantısı doğrudan uygulamayı açar; kendi alan adı + App Links gerekir (şu an alan adı yok, K-09) ve tasarımda yok.
  3. **6 haneli kod** — Functions + e-posta servisi gerekir; tasarımda kod giriş alanı yok (tasarım sapması).
- **Etki:** T-12, T-14; `docs/firestore-rules-spec.md §3` (`email_verified`); D-27.
- **Uyarlama:** Cevap 2 veya 3 → `design-contract.md §8` sapma prosedürü başlatılır; öneri 1'e dön denir, yine de seçerse karar `decisions.md`'de "tasarım sapması" olarak işaretlenir.

### Q-05 · Paket yapısı
- **header:** `Paketler`
- **soru:** D-11 gereği `gu_data` + `gu_ui` iki paketi var. Üçüncü bir paket ekleyelim mi?
- **seçenekler:**
  1. **Yalnızca iki paket (Önerilen)** — Daha az yapılandırma; ortak yardımcılar (`AppLogger`, sabitler) `gu_data`/`gu_ui` içinde bölünür.
  2. **+ `gu_core`** — Logger, sonuç tipleri, saf Dart sabitleri/uzantılar ayrı pakette; `gu_data` ve `gu_ui` buna bağlanır.
  3. **+ `gu_testing`** — Ortak fake'ler ve test yardımcıları paylaşılan pakette; uygulama ve paket testleri aynı fake'leri kullanır.
- **Etki:** T-00, T-02, T-08; `docs/architecture.md §2`; `docs/packages.md`.
- **Not:** Seçilen üçüncü paket de `gu_ui ↛ gu_data` kuralına uyar.

### Q-06 · Servis / repository test yaklaşımı
- **header:** `Servis testi`
- **soru:** `gu_data` servis ve repository testleri nasıl yazılsın?
- **seçenekler:**
  1. **fake_cloud_firestore + el yazımı fake (Önerilen)** — Servis testleri bellek içi Firestore ile hızlı; Rules ve transaction yarışları emülatörde ayrıca test edilir.
  2. **Yalnızca emülatör** — Gerçek davranış, yavaş; her testte emülatör gerekir (CI'da zorunlu olur).
  3. **Yalnızca el yazımı fake** — En hızlı; sorgu/sayaç davranışı doğrulanmaz, Rules testleri tek koruma.
- **Etki:** T-02, T-10 ve backend task'ları (T-12, T-15, T-19, T-22, T-25, T-30, T-37); `docs/testing.md`; `docs/packages.md §2.2`.

### Q-08 · Takvim bileşeni
- **header:** `Takvim`
- **soru:** Etkinlik takvimi (EVT-01, SHT-28) hangi bileşenle yapılsın?
- **seçenekler:**
  1. **Kendi `GuCalendar` (Önerilen)** — Token'larla birebir, Pazartesi başlangıç, nokta göstergeleri tasarımdaki gibi; ek paket yok.
  2. **`table_calendar` paketi** — Hazır ve hızlı; tasarıma 1:1 uydurmak için yoğun özelleştirme + ek bağımlılık.
- **Etki:** T-06, T-24, `docs/packages.md §2.1`.

**Tur 2 sonu:** yaz → özet → Tur 3.

---

## TUR 3 — Bildirim ve veri kuralları

### Q-07 · Hatırlatıcı ve bildirim teslimi
- **header:** `Bildirim`
- **soru:** Etkinlik hatırlatıcısı (SHT-13) ve bildirimler cihaza nasıl ulaşsın?
- **seçenekler:**
  1. **Cihazda planlı hatırlatıcı + uygulama içi liste (Önerilen)** — `flutter_local_notifications`; push yok; Spark ile çalışır.
  2. **Yalnızca uygulama içi liste** — Hatırlatıcı seçici (SHT-13) kaydedilir ama cihaz bildirimi planlanmaz (tasarımdan işlevsel kayıp, K-sorusu doğurur).
  3. **FCM push + zamanlanmış Function** — Gerçek push; yalnızca **Q-02 = Functions** ise gösterilir.
- **Etki:** T-23, T-25, T-26, T-42; `docs/packages.md §2.1` (`flutter_local_notifications`, `timezone`, `firebase_messaging`).
- **Uyarlama:** Q-02 = Functions → seçenek 3 ilk sıraya (Önerilen) ve 1 ikinci sıraya geçer. Q-02 = 1 veya 3 → seçenek 3 yok.

### Q-09 · Rol / yetki kaynağı
- **header:** `Roller`
- **soru:** Kulüp içi roller (başkan, yönetim, danışman, üye) nerede tutulup nasıl denetlensin? (Süper admin zaten yalnızca custom claim — D-28.)
- **seçenekler:**
  1. **Üyelik belgesi + Rules (Önerilen)** — Rol `memberships/{kulüp}_{kullanıcı}` içinde; Rules `get()` ile denetler (erişim çağrısı bütçesi `firestore-rules-spec.md §5`); ek altyapı yok.
  2. **Rol custom claim'de** — Kulüp başına claim; Functions + token yenileme gerekir, claim boyut sınırı (1 KB) ve gecikme sorunu.
  3. **Kulüp belgesinde `managerIds[]`** — Rules daha ucuz ama rol geçmişi/yetki katmanları (board vs member) zayıf.
- **Etki:** T-15, T-30, T-37; `docs/domain-model.md §3`; `docs/firestore-rules-spec.md`.

### Q-10 · Duyuru limiti ve sayaçlar
- **header:** `Duyuru`
- **soru:** "Günde en çok 2 bildirimli duyuru" kuralı nasıl zorlansın?
- **seçenekler:**
  1. **Rules + sayaç belgesi (Önerilen)** — `announcementCounters/{kulüp}_{İstanbul günü}`; atlatılamaz, ek servis yok. Remote Config yalnızca arayüz ipucu.
  2. **Yalnızca istemci denetimi** — Hızlı; değiştirilmiş istemciyle aşılır (güvenlik zayıf).
  3. **Cloud Functions ile** — Sunucu tarafı; **Q-02 = Functions** gerekir.
- **Etki:** T-19, T-21; `docs/firestore-rules-spec.md §4`.
- **Uyarlama:** Q-02 ≠ Functions → seçenek 3 yok.

### Q-11 · Hesap silme ve kişisel veri
- **header:** `Hesap silme`
- **soru:** SET-03 "hesabı sil" ne yapsın? (Uygulamada hard delete yok — D-10.)
- **seçenekler:**
  1. **Anonimleştir + soft delete (Önerilen)** — Profil alanları temizlenir, hesap `deleted` olur, üyelikler `left`; Auth kimliği kalır ve giriş engellenir. Apple "uygulama içi silme başlatma" şartını karşılar; kalıcı temizlik uygulama dışı yönetici işlemi.
  2. **Anonimleştir + sunucuda Auth silme** — 1'e ek olarak Function Auth kimliğini kalıcı siler; **Q-02 = Functions** gerekir.
  3. **Yalnızca devre dışı bırak** — Hesap pasifleşir, veri korunur; mağaza incelemesinde silme şartı riski.
- **Etki:** T-29, T-42, T-46; `docs/domain-model.md §11`; `docs/soft-delete.md`.
- **Uyarlama:** Q-02 ≠ Functions → seçenek 2 yok.

**Tur 3 sonu:** yaz → özet → Tur 4.

---

## TUR 4 — Çevrimdışı, cihaz, gezinme

### Q-12 · Çevrimdışı / önbellek
- **header:** `Çevrimdışı`
- **soru:** İnternet yokken uygulama nasıl davransın?
- **seçenekler:**
  1. **Okuma önbellekten, yazma engellenir (Önerilen)** — Firestore kalıcı önbellek açık; üstte kalıcı banner (SYS-03), yazma işlemleri TST-24 ile engellenir (tasarım kuralı).
  2. **Tam çevrimdışı yazma kuyruğu** — İşlemler bağlantı gelince gönderilir; sayaç/kapasite çakışmaları ve tasarımdaki TST-24 kuralıyla çelişir.
  3. **Önbellek kapalı** — Her açılış ağ ister; en basit ama zayıf deneyim.
- **Etki:** T-11, T-44; `docs/architecture.md §9`.

### Q-13 · Cihaz kapsamı
- **header:** `Cihazlar`
- **soru:** Hangi cihaz yönlendirmeleri desteklensin?
- **seçenekler:**
  1. **Telefon dikey; tablette ortalanmış 480 dp sütun (Önerilen)** — Yön kilidi dikey; tablet/katlanabilirde içerik 480 dp ortalanır, taşma ve uzama yok.
  2. **Dikey kilit, tablette tam genişlik** — Tek sütun tasarımı geniş ekranda gerilir; ek düzen tasarımı yok.
  3. **Yatay serbest** — Yatay yerleşim tasarımda yok (D-31 kapsam dışı) → ek tasarım gerektirir.
- **Etki:** T-00 (platform), T-11 (`GuApp` builder), `docs/testing.md §4` (tablet matrisi).

### Q-14 · Yazı boyutu davranışı
- **header:** `Yazı boyutu`
- **soru:** SET-01'deki yazı boyutu (%100/130/160) sistem ayarıyla nasıl birleşsin?
- **seçenekler:**
  1. **Uygulama içi × sistem, üst sınır 1.6 (Önerilen)** — Seçilen oran sistem ölçeğiyle çarpılır, en çok 1.6; sabit yükseklikler `min-height`.
  2. **Yalnızca sistem ölçeği** — SET-01 satırı yalnızca sistem ayarını gösterir/yönlendirir (tasarımdan sapma).
  3. **Yalnızca uygulama içi** — Sistem ölçeği yok sayılır; erişilebilirlik zayıflar.
- **Etki:** T-01, T-07 (`GuTextScale`), T-28; K-08.

### Q-20 · Sekmeler arası bağlantıda geri davranışı
- **header:** `Sekme geri`
- **soru:** Bir sekmeden başka sekmenin ekranına geçince (örn. Bildirimler → kulüp sayfası, Profil → Kulüplerim) "geri" nereye döner?
- **seçenekler:**
  1. **Hedefin ev sekmesine geç (Önerilen)** — Ekran kendi sekme yığınında açılır; "geri" o sekmenin kökünü gösterir, çağıran sekme yığını korunur; guard'lı rotalar `go` ile kalır (`navigation.md §4` varsayılan A).
  2. **Kök navigatörde `push`** — Prototipe en sadık: geri her zaman çağırana döner; D-05 `go` kuralından sapma, ekran içi koruma gerekir.
  3. **Sekme başına çift alt ağaç** — Her sekmede paylaşılan ekranların kopyası; geri doğal ama rota tablosu şişer.
- **Etki:** T-11 (router), T-16/T-18/T-26/T-27 giriş noktaları; `docs/navigation.md §4`, §6.

**Tur 4 sonu:** yaz → özet → Tur 5.

---

## TUR 5 — Tasarım ve süreç

### Q-15 · Tasarım bulgularının ele alınışı
- **header:** `Tasarım`
- **soru:** `docs/design-known-issues.md` (K-01…K-23) tasarımda bulunan kusurlar ve Flutter'daki çözümleri. Nasıl ilerleyelim?
- **seçenekler:**
  1. **Flutter'da çöz (Önerilen)** — Listedeki kararlar uygulanır; tasarım dokunulmaz, ek dışa aktarım beklenmez.
  2. **Önce Claude Design'da düzelt** — Yeni dışa aktarım beklenir; `design/` yenilenir, registry/task-map doğrulaması tekrar koşar.
  3. **Karışık** — Kritik olanlar (K-03 dokunma hedefi, K-05 taşma) Flutter'da, kalanlar daha sonra tasarımda.
- **Etki:** tüm UI task'ları; `docs/design-known-issues.md` başlığı.

### Q-16 · Golden test kapsamı
- **header:** `Golden`
- **soru:** Golden (ekran görüntüsü) testleri hangi kapsamda tutulsun?
- **seçenekler:**
  1. **Önerilen kapsam (Önerilen)** — Tüm `gu_ui` widget'ları (açık+koyu) + her ekran 390 × açık × TR (+ koyu) + sheet/dialog/toast; EN ve tam matris için taşma testi.
  2. **Tam matris golden** — Her ekran × tema × dil × ölçek; çok dosya, yavaş, repo şişer.
  3. **Yalnızca `gu_ui` widget'ları** — Ekranlar yalnızca taşma/davranış testi; tasarım uyumu tek başına gözle karşılaştırmaya kalır.
- **Etki:** T-02 (`golden_helper`), tüm UI task'ları; `docs/testing.md §7`.

### Q-17 · Git akışı
- **header:** `Git`
- **soru:** Commit'ler nasıl düzenlensin? (`git push` yalnızca sen isteyince.)
- **seçenekler:**
  1. **Tek dal + task başına commit (Önerilen)** — `main` üzerinde `feat(T-12): …` biçiminde, kalite kapısı yeşilse.
  2. **Task başına dal** — `feat/T-12-…` dalı; birleştirmeyi sen yaparsın.
  3. **Task başına dal + PR** — `gh` ile PR açılır (push gerektirir; her seferinde onay sorulur).
- **Etki:** T-00, `prompts/task-calistir.md`; D-35.

### Q-18 · CI
- **header:** `CI`
- **soru:** Otomatik doğrulama (GitHub Actions) kurulsun mu?
- **seçenekler:**
  1. **Şimdilik yok, yerel kalite kapısı (Önerilen)** — `tool/quality_gate.sh` yeterli; CI T-46'da yeniden sorulur.
  2. **GitHub Actions: analiz + test** — Her push'ta `flutter analyze` + `flutter test`.
  3. **Actions + emülatör Rules testleri** — 2'ye ek Firebase emülatörü ile Rules testleri; daha uzun süre.
- **Etki:** T-00, T-46; `.github/workflows` (seçilirse).

**Tur 5 sonu:** yaz → özet → K-adayları.

---

## K-adayları (en çok 2 ek tur)

Dokümanlarda **açıkça** "kullanıcıya sor" diye işaretlenmiş, kod yazmadan önce netleşmesi gereken konular. Her biri için `docs/PLAN.md` "Açık noktalar" bölümüne bir satır eklenir; yukarıdaki cevaplardan **çıkarılabilenleri sorma** (örn. Q-19 = 1 ise G-3/G-4 yükleme sorusu gerekmez).

| Aday | Konu | Önerilen seçenekler (ilk = öneri) | Kaynak |
|---|---|---|---|
| K-A | **G-1 Danışman hesabı bağlama** | (1) `clubs.advisor{name,title,userId?}` + `tool/admin` betiğiyle bağlama · (2) Yalnızca ad/unvan, hesap bağlama yok · (3) ADM-03'te hesap arama alanı (tasarıma ek) | `domain-model §12` |
| K-B | **G-3 Gönderi görselleri** | Q-19 cevabına göre; (2)/(3) ise: (a) ekle düğmesini gizle (b) uyarıyla göster | `design-known-issues K-18` |
| K-C | **G-4 Kapak seçimi (SHT-31)** | (1) Şablon (renk × desen) + Q-19 evetse yükleme · (2) Yalnızca şablon | `domain-model §12` |
| K-D | **Paylaşım kök adresi (K-09)** | (1) `AppConstants.shareBaseUrl` yer tutucu adres, yalnızca kopyala/paylaş · (2) Gerçek alan adın varsa gir (Diğer) | `design-known-issues K-09` |
| K-E | **DebugMenu** (emülatör build'inde rol/tema/dil/ağ değiştirici) | (1) Evet, yalnızca emülatör/debug build · (2) Hayır | `design-known-issues K-02` |
| K-F | **Kayıtlı katılımcı varken taslağa alma** | (1) Reddet (Rules: `goingCount == 0` şartı) · (2) İzin ver, kayıtlar `cancelled` olsun + bildirim | `firestore-rules-spec §3 events` |
| K-G | **Yoklama zaman penceresi** | (1) Başlangıçtan 2 saat önce – bitişten 6 saat sonra (Rules'ta, öneri) · (2) Pencere yok, yönetici istediği zaman yoklama alır | `firestore-rules-spec §3 rsvps` |
| K-H | **Kulüp adı benzersizliği** | (1) Yalnızca ADM-03'te `nameLower` sorgusu (yarış kabul) · (2) `clubNames/{nameLower}` kilit belgesi (kesin) | `firestore-rules-spec §9` |
| K-I | **Firebase App Check** | (1) Şimdilik hayır, T-45'te yeniden sor · (2) Evet (Play Integrity/DeviceCheck kurulumu) | `packages.md §6` |
| K-J | **Mod C spam sınırlaması** (Q-02 ≠ F ise) | (1) Kabul, rapora yaz · (2) Bildirim create başına kota kuralı | `firestore-rules-spec §9` |

**Kural:** Aday sayısı 4'ü aşarsa **önem sırasına göre** (K-A, K-B/K-C, K-F, K-G) en önemli 4–8'ini sor; kalanları `PLAN.md`'de "ilgili task planında sorulacak" diye ilgili T-xx'e bağla (task planı sırasında `AskUserQuestion`).

---

## Cevap kaydı biçimi (`docs/decisions.md §B`)

```
| Q-02 | Cloud Functions / Blaze planı | Önce yalnızca istemci (Mod C); T-43 başında yeniden sorulur | 2026-10-08 |
```

Serbest ("Diğer") cevaplarda kullanıcının sözleri **tırnak içinde** aynen yazılır, yanına yorumun eklenir; yorum belirsizse onay sorusu sorulur.
