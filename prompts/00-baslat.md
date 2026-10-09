# 00 — BAŞLAT (Faz 0: keşif → sorular → karar kaydı → `docs/PLAN.md` → DUR)

> Bu, projeye **ilk** verilen görevdir. `CLAUDE.md` otomatik yüklenir; bu dosya ilk oturumun adım adım protokolüdür.
> **Bu oturumda tek satır uygulama kodu yazılmaz.** Çıktılar yalnızca: `docs/decisions.md` (cevaplar), `docs/progress.json`, `docs/PLAN.md`.
> Kullanıcıya her zaman Türkçe yaz. Kısa tut. Sorular yalnızca `AskUserQuestion` açılır penceresiyle.

## Rol

Sen bu projenin **yürütücüsüsün**: planı kullanıcı onaylar, sen sapmadan uygularsın. Mimari, paketler ve kararlar `docs/decisions.md`, `docs/architecture.md`, `docs/packages.md` içinde **kilitlidir**; sen onları yeniden tasarlamazsın — **somutlaştırırsın** (dosya düzeyine, alan düzeyine, sürüm düzeyine indirirsin) ve boşlukları kullanıcıya sorarsın.

## Adım 1 — Paketi doğrula ve keşfet (salt okunur)

1. `bash tool/verify_pack.sh` çalıştır. Kırmızıysa **dur**: hangi dosya eksik/bozuk, kullanıcıya söyle (zip'in proje köküne açıldığından emin ol).
2. Sırayla oku (özetini kafanda tut, kullanıcıya yazma): `CLAUDE.md` → `docs/README.md` → `docs/decisions.md` → `docs/architecture.md` → `docs/domain-model.md` → `docs/firestore-rules-spec.md` → `docs/soft-delete.md` → `docs/navigation.md` → `docs/testing.md` → `docs/packages.md` → `docs/design-contract.md` → `docs/design-known-issues.md` → `docs/roadmap.md` → `design/prototype/claude-design-prompt.md` (iş kuralları; ekran ekran değil, ilgili bölümler).
3. Tasarım envanterini gör: `design/extracted/registry.json` (51 ekran / 34 sheet / 32 dialog / 78 toast), `design/extracted/screens-actions.json` (1072 aksiyon), `design/reference-shots/` klasör yapısı, `design/prototype/app/` dosya listesi. `node tool/check_design_coverage.js --map` ile `docs/task-map.json`'ın registry ile tutarlılığını doğrula.
4. Mevcut Flutter projesine bak: `pubspec.yaml`, `analysis_options.yaml`, `build.yaml`, `lib/`, `ios/`, `android/`, `firebase.json`, `.firebaserc`, `lib/firebase_options.dart`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, `git status`, `git log --oneline | head`, `flutter --version`, `dart --version`, `firebase --version`, `node --version`. Bulduklarını "durum notu"na yaz (kullanıcıya göstereceğin kısa liste).
5. Çelişki ara: mevcut `pubspec.yaml` ↔ `docs/packages.md` (kaldırılacaklar: `google_fonts`, `flutter_lints`…), mevcut `analysis_options.yaml` ↔ D-08, SDK sürümü ↔ `docs/packages.md §1`. Bulduğun her çelişkiyi "Açık noktalar" listesine ekle (henüz çözme).

## Adım 2 — Kullanıcıya durum notu

Kısa Türkçe mesaj (tablo): paket doğrulaması sonucu · mevcut proje durumu · keşfedilen çelişkiler · "şimdi 5 tur soru soracağım (20 soru), her biri açılır pencere olacak" bilgisi. Kullanıcıdan onay **bekleme**; hemen Adım 3'e geç.

## Adım 3 — Soru turları

1. `.claude/skills/gu-ask-user/SKILL.md` kurallarını uygula.
2. `AskUserQuestion` araç şeması yüklü değilse önce `ToolSearch` ile yükle (`select:AskUserQuestion`).
3. `prompts/01-soru-bankasi.md` içindeki **5 turu sırayla** uygula; her tur **tek çağrı, 4 soru**. Seçenekleri o dosyada yazıldığı gibi kullan (yalnızca orada belirtilen **Uyarlama** kurallarına göre ele/ekle). İlk seçenek `(Önerilen)`.
4. Her turdan sonra: cevapları `docs/decisions.md §B` tablosuna yaz (`SEÇİM` + tarih), `docs/progress.json#questionsAnswered`'a işle, kullanıcıya **3–5 satırlık özet** ver, sonraki tura geç.
5. Cevaba göre **etkilenen dosyaları** not al (bellekte): `docs/packages.md` koşulları, `docs/roadmap.md` T-42 durumu, `docs/navigation.md §4` varsayılanı, `docs/testing.md` golden kapsamı. Dosyaları **bu oturumda yeniden yazma**; PLAN.md "Kararlardan doğan uyarlamalar" bölümünde listele. (İstisna: kullanıcı açıkça "evet, belgeleri güncelle" derse.)
6. Beş tur bitince **K-adayları** (`01-soru-bankasi.md` son bölüm): cevaplardan çıkarılamayanları seç, en çok **2 ek tur** (≤ 4 soru/tur) sor; kalanı PLAN'daki "ilgili task planında sorulacak" listesine bağla.

## Adım 4 — Planı yaz (plan modu)

1. `EnterPlanMode` çağır (araç yüklü değilse `ToolSearch`).
2. `docs/PLAN.md`'yi **aşağıdaki başlık düzeniyle** yaz. Her bölüm **somut**: dosya yolu, sınıf adı, alan adı, sürüm, komut, sayı. "Uygun şekilde", "gerekirse", "daha sonra belirlenir" gibi ifadeler **yasak**; belirsizlik varsa "Açık noktalar"a gider ve soru olarak sorulur.
3. Yazdıktan sonra kendini denetle (Adım 5), sonra `ExitPlanMode` ile **kullanıcı onayına** sun. Onay gelmeden Adım 6'ya geçme.

### `docs/PLAN.md` — zorunlu içindekiler

| § | Başlık | İçerik (somut) |
|---|---|---|
| 0 | Belge bilgisi | Tarih, sürüm (v1), hangi karar kümesine dayanır (D-01…D-36 + Q-01…Q-20 + K-xx cevapları) |
| 1 | Kapsam ve başarı ölçütü | 51 ekran / 34 sheet / 32 dialog / 77 toast (+ muaflar) / 1060 aksiyon; "bitti" = roadmap §6 + `check_design_coverage.js --all` yeşil |
| 2 | Karar özeti | Tüm D-xx (tek satır) ve **cevaplanmış Q/K tablosu** (kullanıcının seçimi + sonucu: hangi dosya/task değişir) |
| 3 | Kararlardan doğan uyarlamalar | Cevaplara göre: `packages.md` ekle/çıkar listesi, T-42 durumu, Mod C/F, navigasyon varsayılanı (Q-20), golden kapsamı (Q-16), Storage (Q-19), git/CI. Hangi `docs/*` satırı değişecek (hangi task'ta) |
| 4 | Repo ve dizin ağacı | Tam ağaç (kök, `packages/gu_data`, `packages/gu_ui`, `lib/core|product|features/*`, `firebase/`, `functions/` (varsa), `tool/`, `test/`) — **her `features/<x>` klasörü ve içindeki dosya grupları**; hangi task'ta oluşur |
| 5 | Paketler | Kök + `gu_data` + `gu_ui` bağımlılık tabloları (paket · amaç · task · koşul), `flutter pub add --dry-run` ile doğrulanmış **sürümler** (ağ yoksa "T-00'da çözülür" ve nedeni), kaldırılacaklar, platform notları (iOS SPM, Android minSdk, izinler, izin metinleri) |
| 6 | Katmanlar ve sınır kuralları | `view → viewmodel → repository → service`; paket bağımlılık yönü; import kısıtlarını **otomatik denetleyen** kural (analyzer/`tool/` betiği) |
| 7 | Token ve tema | `registry.json#tokens` → `GuColors/GuTypography/GuSpacing/GuRadius/GuShadows/GuMotion/GuSizes` eşleme tablosu (isim → değer), `context.gu` extension sözleşmesi, font/ikon kayıt planı, durum çubuğu planı (`GuSystemUi`) |
| 8 | Widget stratejisi | `docs/design-analysis.md`'ye giden **çekirdek widget** ön listesi (Faz 1 çıktısı değil, ön plan): `gu_ui` vs `lib/product/widget/` ayrımı kuralı, tekrar yasağı denetimi (widget-catalog), her widget'ın durum matrisi |
| 9 | Veri modeli | `domain-model.md` → Dart model sınıfları: koleksiyon · sınıf · alan · tip · nullable · varsayılan · validator · JSON anahtarı; enum'lar; Timestamp dönüştürücü; ID kuralları; **alan düzeyi** tablolar (en az: users, clubs, memberships, posts, events, rsvps, notifications, reports) |
| 10 | Servis ve repository'ler | Her servis/repository: arayüz imzaları (metot adı + dönüş tipi), `FirebaseResult` eşlemesi, soft delete yolları, sayaç batch'leri, sorgu sözleşmesi (rules-spec §6) |
| 11 | Firestore Rules ve indeksler | Koleksiyon × rol × işlem matrisi, geçiş makinesi M1–M14 uygulama planı, erişim çağrısı bütçesi, `firestore.indexes.json` listesi, Storage Rules (Q-19), Rules test planı (rol × işlem, delete=ret) |
| 12 | State (ViewModel'ler) | Her feature için ViewModel · State alanları · metotlar · dinleyici (canlı/tek seferlik) — sayfalama ve 5 durum |
| 13 | Navigasyon | `docs/navigation.md` rota tablosunun **typed route sınıfı adlarıyla** nihai hali, guard/redirect testleri, geçiş istisnaları, Q-20 uygulaması |
| 14 | Yerelleştirme | ARB akışı (1235 anahtar, K-21/K-22/K-23), anahtar adlandırma kuralı, parite/kullanılmayan anahtar denetimi, tarih/sayı biçimleri |
| 15 | Bildirim mimarisi | Mod C/F kararı, `NotificationDispatcher` arayüzü, tür × alıcı tablosu (domain-model §6), tercih/sessiz saat uygulama yeri |
| 16 | Test stratejisi | Katman × test türü, `test/helpers` listesi, cihaz matrisi parametreleri, golden politikası (Q-16), Rules testleri, kapsam hedefleri |
| 17 | Kalite kapısı ve araçlar | `tool/*` betiklerinin sırası, hook'lar, commit/dal akışı (Q-17), CI (Q-18) |
| 18 | Task listesi | `docs/roadmap.md` T-00…T-47 **aynen**; cevaplara göre **değişen** task'lar (ör. T-42 atlanır) ve gerekçesi; **sapma yoksa "değişiklik yok"** yaz |
| 19 | Tasarım uyumu planı | L1–L9 hangi task'ta ilk kez koşar, referans görüntü karşılaştırma süreci, K-01…K-23 uygulama yeri, muaf liste |
| 20 | Riskler | Her risk: olasılık · etki · önlem · sahibi task (en az: Rules karmaşıklığı/erişim çağrısı bütçesi, ağır SVG, Storage/Blaze, iOS SPM uyumu, paket sürüm çakışması, tasarım-Flutter boşlukları) |
| 21 | Kullanıcıdan gerekenler | Adım adım: Firebase konsol işleri, `flutterfire`/CLI, cihaz/simülatör, imzalama, mağaza hesapları — hangi task'tan **önce** gerekli |
| 22 | Açık noktalar | Çözülmemiş çelişkiler/boşluklar → hangi task planında `AskUserQuestion` ile sorulacak |
| 23 | Onay kontrol listesi | Kullanıcının tek bakışta onaylayacağı 10–15 maddelik özet |

## Adım 5 — Plan öz denetimi (onaya sunmadan önce)

- [ ] Her §'de somut isim/sayı var; "TBD/gerekirse" yok.
- [ ] D-xx ile çelişen satır yok; çelişki varsa §22'de.
- [ ] Cevaplanan her Q-xx §2–§3'te yansıtılmış.
- [ ] §18 roadmap ile birebir; sıra/birleştirme yok.
- [ ] Hard delete, hardcode, tekrarlı widget, Freezed/AsyncValue, `google_fonts` içeren hiçbir öneri yok.
- [ ] Uygulama kodu yazılmadı (`git status` yalnızca `docs/` ve `prompts` dışı dosya göstermiyor).
- [ ] `node tool/check_design_coverage.js --map` yeşil.

## Adım 6 — DUR ve bekle

Onaydan sonra yalnızca şunu yap: `docs/progress.json#gate.planApproved = true`, kullanıcıya "Faz 0 kurulum (T-00) için `prompts/02-faz0-kurulum.md` ile devam edebilirim" de ve **bekle**. Kullanıcı "devam" demeden T-00'ı başlatma.

## Yasaklar (bu oturum)

❌ Kod yazmak · ❌ `flutter create`/`pub add`/`firebase` komutlarıyla proje değiştirmek (salt okunur komutlar ve `--dry-run` serbest) · ❌ düz metinle seçenekli soru · ❌ cevapsız soruya "makul varsayım" · ❌ docs sözleşmelerini yeniden yazmak · ❌ `git commit` (yalnızca kullanıcı isterse `docs/` için tek commit).
