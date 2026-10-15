# T-44 · Performans ölçümü (çizim / bellek + profil araçları)

> Grup A raporu. Kapsam: PLAN R-02 (kapak SVG maliyeti), §21 #11 (profil ölçümü cihaz ister). Bu task'ta koşulan ölçümler: SVG mikro ölçümü ve widget testleri içindeki kurulum sayımları. Gerçek cihazdaki profil ölçümünü kullanıcı T-46'da koşar (yeni borç).

## 1. Bu task'ta yapılan düzeltmeler (ölçülebilir etki)

| Bulgu | Değişiklik | Ölçüm (widget testi, 390 × 844) |
|---|---|---|
| P1-01 | FED-01 artık tembel bir sliver grubu (`SliverMainAxisGroup` + `SliverList.separated`). CLB-03 sekme gövdesi sliver oldu. Yalnızca "Devamı" ile açılmış `PostCard` canlı tutulur. | 60 görselli gönderide **3 kart kuruluyor, 3 adres isteniyor**. Önce `Column` 60 kartın hepsini kurup 60 adres istiyordu. Tek beğenide yalnızca kurulu **6 kart** yeniden kuruluyor; önce 20 kartın hepsi kuruluyordu. |
| P1-03 | Yol başına sağlayıcı: `storageImageProvider(path)`, `ref.storageImage`, `ref.postImagesOf`. Avatar, logo ve kapak yardımcıları buna geçti. FED-01'de her kart kendi `Consumer`'ında çiziliyor. | Bir adres geldiğinde `ClubFeedTab` **0 kez** yeniden kuruluyor. `PostCard` **yalnızca ilgili kartta** (1) yeniden kuruluyor. Önce genel çözücü değişiyor, sekme ve bütün kartlar yeniden kuruluyordu. |
| P1-02 | `BoundedImage.coverEdgePx`: görsel kısa kenarı kutu kenarına inecek boyutta çözülüyor (germe yok, büyütme yok). Tüm avatar, logo ve EVT-01 kapak çağrı yerleri gerçek boyutlarını veriyor. | 1600 × 1200 kaynak, 40 dp avatarda @3x **160 × 120** çözülüyor (önce 1600 × 1200). Bellek: ≈ 7,7 MB → ≈ 77 KB (görsel başına, RGBA). |
| P1-04 | `PostImage` yer tutucu SVG'yi yalnızca yükleme ya da hata sırasında çiziyor. İlk kare gelince alttaki SVG ağaçtan çıkıyor. | Testte görsel yüklendikten sonra hücrede `GuCover` ve `SvgPicture` **yok**. |
| D2-07 | Logo yüklenemezse `errorBuilder` tasarımdaki ikonlu amblemi çiziyor. | Bozuk baytla hata yüzeye çıkmıyor; aynı ikon, boyut ve renk çiziliyor. |
| D3-05 | CLB-03 açıkken akış ViewModel'i canlı tutuluyor (`listenManual`). Sekmeden çıkınca süzgeç sıfırlanıyor. | Gönderiler → Hakkında → Gönderiler geçişinde `listFeed`, `getClub` ve `listManagers` çağrı sayısı değişmiyor (**0 ek okuma**, iskelet yok). Önce her dönüşte 25–60 okuma yapılıyordu. |

Golden'lar (FED-01, CLB-03, `post_cards`, SHT-34) `--update-goldens` olmadan birebir geçti.

## 2. R-02 · Kapak SVG mikro ölçümü (`benchmark/cover_svg_bench_test.dart`)

- **Komut:** `flutter test benchmark/`. Ham çıktı `build/cover_svg_bench.json` dosyasına yazılır. Kalite kapısı bu klasörü koşmaz.
- **Ortam:** debug (JIT) `flutter test`, macOS. Isınma turu atıldı; her dosya 7 kez ölçüldü ve ortanca alındı. Cihazdaki AOT profil derlemesinde mutlak süreler daha düşüktür. Anlamlı olan, dosyalar arası oran ile ilk ve önbellekli ölçüm arasındaki fark.
- **Ölçülen yol:** uygulamanın yolu (`SvgPicture` → `SvgLoader.loadBytes` → `vg.loadPicture`).
  - **İlk:** önbellek boş. XML ayrıştırma, vector_graphics derleme ve `Picture` çözümü birlikte.
  - **Önbellekli:** derlenmiş baytlar `svg.cache`'te; yalnızca `Picture` çözümü.

| Küme | Adet | Toplam bayt | `<circle>` | İlk (toplam) | Önbellekli (toplam) |
|---|---|---|---|---|---|
| Kapaklar (`assets/covers`) | 26 | 458 305 | 4 204 | **50,0 ms** | **4,5 ms** |

**En ağır 5 kapak** (hepsi ≈ 700 daireli "dots" deseni):

| Dosya | Bayt | Öğe | İlk ms | Önbellekli ms |
|---|---|---|---|---|
| `template-red-dots.svg` | 59 423 | 706 | 7,06 | 0,52 |
| `template-bordeaux-dots.svg` | 58 723 | 706 | 6,95 | 0,55 |
| `fotograf-ve-sinema-kulubu.svg` | 59 216 | 703 | 6,91 | 0,54 |
| `template-slate-dots.svg` | 59 423 | 706 | 6,85 | 0,53 |
| `doga-sporlari-ve-dagcilik-kulubu.svg` | 58 419 | 702 | 6,75 | 0,54 |

- **"dots" dışı kapaklar:** 0,19–0,77 ms ilk, 0,04–0,09 ms önbellekli.
- **Desenler** (`assets/patterns`):

  | Desen | İlk ms | Önbellekli ms |
  |---|---|---|
  | `dots.svg` | 6,54 | 0,54 |
  | `lines.svg` | 0,60 | 0,07 |
  | `waves.svg` | 0,27 | 0,04 |
  | `mountain.svg` | 0,13 | 0,03 |

- **İkonlu şablon** (`GuCovers.composeTemplate`, ikon `mountain`): ortanca ilk 0,66 ms. "dots" şablonlarında 6,8–7,0 ms. Her şablon × ikon çifti ayrı önbellek anahtarıdır, bu yüzden ilk çizimde ayrıca ayrıştırılır.

### R-02 değerlendirmesi

- **Ayrıştırma:** 26 kapağın hepsi ilk kez ≈ 50 ms (debug JIT), "dots" kapak başına ≈ 7 ms.
  - CLB-01'in ilk ekranında 2–4 kapak çizilir: ilk karede en kötü ≈ 14–28 ms ek iş (debug). Cihazda AOT'de bunun 2–5 katı daha hızlı olması beklenir. Ayrıca `SvgLoader` uygulama derlemesinde ayrıştırmayı `compute` ile ayrı isolate'ta yapar; UI iş parçacığını yalnızca `Picture` çözümü (≈ 0,5 ms) bekler.
  - Önbellekli yükleme ≈ 0,5 ms: aynı kapak ikinci kez çizildiğinde maliyet ihmal edilebilir.
  - **Sonuç:** ayrıştırma takılma kaynağı değil.
- **Açık risk (cihazda ölçülecek):** raster maliyeti. `GuCover` `RepaintBoundary` içinde ve `SvgPicture` varsayılan `RenderingStrategy.picture` ile çiziliyor. Impeller'da raster önbelleği yok, bu yüzden 700 daireli kapak her karede yeniden rasterleşir. Kaydırmada 3–4 "dots" kapak varsa kare başına ≈ 2 800 daire çizimi demek.
  - Bu maliyet yalnızca cihazda görülür; aşağıdaki CLB-01 kaydırma ölçümü bunun içindir.
  - Raster süresi 90p > 16 ms ya da takılan kare > %1 çıkarsa: yeni bir K-xx açılır ve kullanıcıya sorulur (PLAN R-02).
  - Bu durumdaki seçenek `SvgPicture(renderingStrategy: RenderingStrategy.raster)`: kapak boyutunda bir kez rasterleşir ve tekrar kullanılır. Bellek bedeli: 358 × 201 dp @3x kapak başına ≈ 2,6 MB.
  - **Bu task'ta `gu_cover.dart` değiştirilmedi** (görünüm ve golden riski; karar cihaz ölçümüne bağlı).

## 3. Kullanıcının gerçek cihazda koşacağı profil ölçümü (T-46 borcu)

### Hazırlık

1. **Emülatör ve seed:**

   ```bash
   firebase emulators:start --only auth,firestore,storage --project demo-gu-kulupler
   FIREBASE_STORAGE_EMULATOR_HOST=127.0.0.1:9199 node tool/seed/seed_emulator.js --project demo-gu-kulupler
   ```

   Ayrıntı: `tool/seed/README.md`. Senaryolar seed'deki demo üyeyle (`u_mehmet`, `c01` üyesi) oturum açar; parola kodda `DebugDemoAccounts`'tan okunur.

2. **Gerçek cihaz:** emülatörler LAN'a açık olmalı. `firebase.json` içindeki emülatörlere `"host": "0.0.0.0"` eklenir (ya da bu ayarla ayrı bir yapılandırma kullanılır). Cihaza Mac'in LAN IP'si verilir: `--dart-define=EMULATOR_HOST=192.168.x.y`. İzin verilen adresler: özel IPv4 ya da `.local` (CD-131).

3. **Android:** profil derlemesinde şifresiz trafik izni yok. `usesCleartextTraffic` yalnızca `android/app/src/debug/AndroidManifest.xml` içinde (W-53). Bütünlemede depoya **eklenmedi** (CD-132 (7): şifresiz trafik yalnızca debug manifest'inde). Android'de ölçmek için ölçüm süresince yerelde `android/app/src/profile/AndroidManifest.xml` `<application android:usesCleartextTraffic="true"/>` eklenip ölçümden sonra geri alınır; tercih edilen yol iOS cihazdır (ek ayar gerekmez).

4. Ölçüm **`--profile`** ile koşar. Debug ölçümü anlamsızdır; release derlemesi emülatöre bağlanmayı reddeder (CD-131).

### Komutlar

Her senaryo ayrı uygulama sürecidir. `-d <cihaz>` ile hedef cihaz seçilir.

```bash
# 1) Açılış: AppBootstrap.run → ilk kare → SplashHold sonrası CLB-01
flutter drive --profile -d <cihaz> \
  --driver=test_driver/perf_driver.dart \
  --target=integration_test/perf/startup_perf_test.dart \
  --dart-define=ENV=emulator --dart-define=EMULATOR_HOST=<Mac LAN IP>

# 2) CLB-01 kaydırma (kapak SVG'leri, logolar)
flutter drive --profile -d <cihaz> \
  --driver=test_driver/perf_driver.dart \
  --target=integration_test/perf/club_list_scroll_perf_test.dart \
  --dart-define=ENV=emulator --dart-define=EMULATOR_HOST=<Mac LAN IP>

# 3) FED-01 akış kaydırma (CLB-03 "Gönderiler", c01)
flutter drive --profile -d <cihaz> \
  --driver=test_driver/perf_driver.dart \
  --target=integration_test/perf/feed_scroll_perf_test.dart \
  --dart-define=ENV=emulator --dart-define=EMULATOR_HOST=<Mac LAN IP>
```

**Açılış ölçümü iki kez koşulmalı.** İlk koşuda oturum yoksa giriş de ölçüme girer ve bu `startup_signed_in_during_run: true` olarak raporlanır. Auth emülatör oturumu cihazda saklandığı için ikinci koşu saf açılıştır.

### Çıktılar (`build/`)

| Dosya | İçerik |
|---|---|
| `startup.timeline_summary.json`, `clb01_scroll.timeline_summary.json`, `fed01_scroll.timeline_summary.json` | `TimelineSummary` özeti |
| `<anahtar>.timeline.json` | Ham zaman çizelgesi: DevTools → Performance → "Load" ya da `ui.perfetto.dev` |
| `perf_report_data.json` | `startup_first_frame_ms`, `startup_club_list_ms`, `startup_signed_in_during_run` |

### Neye bakılır (eşik: 60 Hz için kare başına 16 ms)

| Alan (`*.timeline_summary.json`) | Hedef |
|---|---|
| `average_frame_build_time_millis` | < 8 ms |
| `90th_percentile_frame_build_time_millis` | < 16 ms |
| `99th_percentile_frame_build_time_millis` | < 16 ms |
| `average_frame_rasterizer_time_millis` | < 8 ms |
| `90th_percentile_frame_rasterizer_time_millis` | < 16 ms (R-02: kapak rasteri burada görünür) |
| `99th_percentile_frame_rasterizer_time_millis` | < 16 ms |
| `missed_frame_build_budget_count` / `missed_frame_rasterizer_budget_count` | toplam karenin %1'inden az (`frame_count`) |
| `worst_frame_build_time_millis` / `worst_frame_rasterizer_time_millis` | tek seferlik sıçramalar: ilk kapak ayrıştırma ve görsel çözümü |
| `average_memory_usage` / `90th_percentile_memory_usage` (varsa) | akışta kaydırma süresince sabit kalmalı (P1-01: tembel liste) |
| `perf_report_data.json` → `startup_club_list_ms` | ikinci koşuda (oturum hazır) kabul edilebilir açılış; ilk kareyle farkı `SplashHold` + oturum çözümü + CLB-01 okumasıdır |

120 Hz cihazlarda (ProMotion) kare bütçesi 8,3 ms'dir. `TimelineSummary` takılma sayısını 16 ms'ye göre hesaplar; 120 Hz'te 90p değerine ayrıca bakılır.

**Not:** seed'de `c01` akışı 7 gönderidir. FED-01 ölçümü kısa listede kare maliyetini gösterir. Uzun liste davranışı (tembel liste) widget testinde 60 gönderiyle doğrulandı. Cihazda uzun liste için emülatörde gönderi eklenip senaryo yeniden koşulur.

## 4. Kalite kapısı

`tool/quality_gate.sh` `flutter test` komutunu kökte argümansız koşar, yani yalnızca `test/` çalışır. `integration_test/perf/`, `benchmark/` ve `test_driver/` koşulmaz. Hepsi `flutter analyze` kapsamındadır ve temizdir. Format denetimi `integration_test/` klasörünü de kapsar. `flutter_driver` (sdk) dev bağımlılığı eklendi.

## 5. Bağımlılıklar (`flutter pub outdated`, 2026-10-15 — yükseltme yapılmadı)

- **Güvenlik:** `flutter pub outdated --json` hiçbir paket için `isCurrentAffectedByAdvisory`, `isDiscontinued` ya da `isCurrentRetracted` bildirmedi; `flutter pub get` de danışma uyarısı vermedi. **Güvenlik nedeniyle zorunlu yükseltme yok.**
- **Doğrudan bağımlılıklar (12 eski):**

  | Paket | Şimdiki | En yeni | Tür |
  |---|---|---|---|
  | `go_router` | 18.0.2 | 18.1.0 | küçük sürüm, kısıt içinde (kilitli) |
  | `cached_network_image` | 4.0.3 | 4.0.4 | yama; şu anki çözümde erişilemez (pub "Resolvable" 4.0.3 — geçişli kısıt) |
  | `intl` | 0.20.2 | 0.20.3 | yama (Flutter SDK'nın sabitlediği sürüm) |
  | `meta` | 1.18.0 | 1.19.0 | SDK sabiti |
  | `equatable` | 2.1.0 | 3.0.0 | ana sürüm |
  | FlutterFire (`firebase_core` 4.15 → 5, `cloud_firestore` 6.10 → 7, `firebase_auth` 6.7 → 7, `firebase_storage` 13.6 → 14, `firebase_messaging` 16.7 → 17, `firebase_crashlytics` 5.4 → 6, `firebase_remote_config` 6.7 → 7) | — | — | ana sürüm hattı (birlikte yükseltilir) |

- **Geliştirme:** `build_runner` 2.15.1 → 2.17.1, `very_good_analysis` 10.3.0 → 11.0.0 (yeni lint kuralları — ayrı iş).
- **Geçişli:** 54 paket; yalnızca `sqflite*`, `synchronized`, `vector_graphics_compiler`, `vm_service`, `archive`, `image` vb. kilit içinde yükseltilebilir (yama / küçük sürüm).
- **T-45 notu:** sürüm öncesi yükseltme önerilmez (ana sürüm FlutterFire hattı Rules / SDK davranışı değiştirebilir, golden ve emülatör testleri yeniden doğrulama ister). Yayından sonra ayrı bir task: önce kilit içi yamalar (`flutter pub upgrade` — `go_router` 18.1.0 dahil), sonra FlutterFire ana hattı tek seferde + tam kapı + Rules testleri. `pubspec.yaml`'daki tek T-44 değişikliği `flutter_driver` (sdk) geliştirme bağımlılığıdır.
