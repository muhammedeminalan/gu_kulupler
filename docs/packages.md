# Paket Kararları

> Kilitli: D-03 (Riverpod/Equatable, Freezed yok), D-04 (GetIt), D-05 (go_router), D-07 (intl/ARB), D-08 (very_good_analysis), D-09 (json_serializable), D-11 (workspace + 2 paket), D-12 (bundled font, `google_fonts` yok), D-13 (flutter_svg).
> Bu liste **izin verilen** paketlerdir. Listede olmayan bir paket gerekirse: önce standart kütüphane/`gu_ui` ile çözüp çözülemeyeceğine bak; çözülemiyorsa **`AskUserQuestion` ile sor** (gerekçe + alternatif + bakım durumu).

## 1. Sürüm politikası

1. Kullanıcının mevcut `pubspec.yaml`'ı `docs/reference/pubspec.yaml.txt`'de referans olarak durur; **sürümler `flutter pub add` / `dart pub add` ile çözülür** (en güncel uyumlu). Sürümü aşağı çekmek veya sabitlemek için gerekçe yaz.
2. `sdk: ^3.12.2` (kullanıcının SDK'sı). Pub **workspace** (`resolution: workspace`) kökte ve paketlerde.
3. Bir paketin **major** sürümü atlanıyorsa (ör. `firebase_*` BoM'u) `CHANGELOG` okunur; kırıcı değişiklik varsa `docs/PLAN.md` "Riskler"e yazılır.
4. `flutter pub outdated` Faz H'de çalıştırılır; güvenlik düzeltmeleri dışında **işin ortasında yükseltme yok**.
5. Paket eklemek = aynı commit'te `docs/packages.md`'ye (bu tabloya) satır + gerekçe.
6. Platform yapılandırması (iOS **SPM**, Android `minSdk`, izin metinleri `Info.plist` / `AndroidManifest.xml`) paketle **aynı task'ta** yapılır ve kullanıcıya bildirilir.

## 2. Çalışma zamanı bağımlılıkları

### 2.1 Kök uygulama (`pubspec.yaml`)

| Paket | Amaç | Nerede (tasarım ID) | Koşul |
|---|---|---|---|
| `flutter_localizations` (sdk), `intl` | ARB l10n, tarih/sayı | tüm UI | — |
| `flutter_riverpod`, `riverpod_annotation` | state | tüm ViewModel'ler | — |
| `go_router` | rota | `lib/product/navigation` | — |
| `get_it` | DI | `lib/core/di` | — |
| `equatable` | state eşitliği | State sınıfları | — |
| `shared_preferences` | tema/dil/metin ölçeği, ilk açılış bayrağı, son aramalar | SHT-01/17, ONB-01, CLB-02 | — |
| `connectivity_plus` | çevrimdışı banner (SYS-03) | kök katman | — |
| `package_info_plus` | sürüm/build | SET-04 | — |
| `url_launcher` | e-posta/Instagram/web, Google Takvim, Ayarlar | CLB-03, DLG-32, SHT-14 | — |
| `share_plus` | .ics / bağlantı paylaşma | SHT-14, SHT-15 | — |
| `path_provider` | .ics geçici dosyası | SHT-14 | — |
| `permission_handler` | kamera/fotoğraf/bildirim izni, "Ayarlara git" | DLG-03/04/05, TST-32 | — |
| `mobile_scanner` | QR okuma | MGT-07 | — |
| `qr_flutter` | QR üretme | EVT-03 | — |
| `image_picker` | kamera/galeri | SHT-16 | Q-19 ≠ "yükleme yok" |
| `flutter_image_compress` (veya `image`) | yükleme öncesi boyutlandırma | SHT-16, AUT-05, PRF-02, FED-03, MGT-09 | Q-19 |
| `cached_network_image` | Storage'tan gelen fotoğraflar | avatar, kapak, gönderi görselleri | Q-19 ≠ "yükleme yok" |
| `flutter_svg` | ikon/kapak/desen/illüstrasyon | her yer | — |
| `flutter_local_notifications`, `timezone` | cihazda planlı hatırlatıcı | SHT-13, EVT-02 | Q-07 = yerel hatırlatıcı |
| `table_calendar` | takvim | SHT-28, EVT-01 | **Q-08 = table_calendar** (önerilen değil; öneri `GuCalendar`) |
| `firebase_core`, `firebase_auth`, `cloud_firestore` | çekirdek | — | — |
| `firebase_storage` | fotoğraf | Q-19 | Q-19 ≠ "yükleme yok" (yeni projede Blaze gerekir — `architecture.md §10`) |
| `firebase_messaging` | FCM | bildirim izni, jeton | **Q-02 = Functions (Mod F)** |
| `cloud_functions` | callable (gerekirse) | — | Q-02 = Functions **ve** callable gerekiyorsa |
| `firebase_remote_config` | sürüm kapısı, bakım, limit ipuçları | DLG-26 | — |
| `firebase_crashlytics` | hata raporu | D-23 | — |

**Kaldırılacaklar** (kullanıcının mevcut pubspec'inde var): `google_fonts` (D-12), `flutter_lints` (→ `very_good_analysis`); Q'ya göre `table_calendar`, `cloud_functions`, `firebase_messaging`, `firebase_storage`, `cached_network_image`. `uses-material-design: true` kalır (Material widget'ları kullanılır; `Icons.*` kullanılmaz).

### 2.2 `packages/gu_data`
`cloud_firestore`, `firebase_auth`, `firebase_storage` (Q-19), `firebase_remote_config`, `firebase_messaging` (Mod F), `firebase_crashlytics`, `equatable`, `json_annotation`, `meta`, `collection`, `crypto`/`dart:math Random.secure` (bilet kodu — **yalnızca `Random.secure()`**).
Dev: `build_runner`, `json_serializable`, `very_good_analysis`, `test`, `fake_cloud_firestore` + `firebase_auth_mocks` (+ `firebase_storage_mocks`) **Q-06**.

### 2.3 `packages/gu_ui`
`flutter`, `flutter_svg`, `equatable`, `meta`. **Başka paket yok** (Firebase, l10n, router, Riverpod'a bağımlı değil).
Dev: `flutter_test`, `very_good_analysis`.

## 3. Dev bağımlılıkları (kök)

`build_runner`, `riverpod_generator`, `go_router_builder`, `json_serializable`, `very_good_analysis`, `flutter_test`, `integration_test` (sdk), `flutter_launcher_icons`, `flutter_native_splash`. Test için ayrıca `fake_cloud_firestore`, `firebase_auth_mocks` (Q-06). **Mock kütüphanesi (mocktail/mockito) yok** — el yazımı fake'ler (CLAUDE.md §3). **Golden için üçüncü taraf paket yok** — Flutter'ın `matchesGoldenFile`'ı + `test/helpers/golden_helper.dart`.
Opsiyonel (yalnızca uyumlu sürüm bulunursa, aksi halde kullanılmaz): `riverpod_lint` / `custom_lint` — kullanılamazsa `docs/PLAN.md`'ye not.

## 4. Firebase tarafı (Node)

| Yer | Araç |
|---|---|
| `firebase/` | `firebase-tools` (kullanıcı makinesinde), `@firebase/rules-unit-testing`, `jest` veya Node test runner; `package.json` `firebase/test/` içinde |
| `functions/` (Mod F) | TypeScript, Node 20, `firebase-functions` v2, `firebase-admin`, `vitest`/`jest`; ESLint `google` |
| `tool/admin/` | `firebase-admin` (yalnızca `set_superadmin.js`; servis hesabı anahtarı **repoda yok**) |

## 5. Platform notları (görev başına doğrulanır)

- **iOS:** SPM (kullanıcı `enable-swift-package-manager: true` açtı); CocoaPods gerektiren paket çıkarsa `AskUserQuestion`. `Info.plist` izin metinleri (`NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSUserNotificationsUsageDescription` gerekmez ama FCM için Push Capability) **ARB'den değil** `InfoPlist.strings` yerelleştirmesiyle TR/EN; uygulama ad(lar)ı `AppConstants.appName` ile tutarlı.
- **Android:** `minSdk` Firebase + `mobile_scanner` gereksinimine göre; izinler `AndroidManifest.xml`; bildirim kanalı adları ARB'den; predictive back için `android:enableOnBackInvokedCallback="true"`.
- **Ekran yönü:** dikey kilit (Q-13) `SystemChrome.setPreferredOrientations` + platform dosyaları.
- **Uygulama ikonu / splash:** `assets/logo/app-icon-1024.png` → `flutter_launcher_icons`; native splash `flutter_native_splash` (tema renkleri `GuColors`'tan **türetilmiş sabit** olarak `flutter_native_splash.yaml`'a yazılır ve tokenlarla testle eşleştirilir). Üniversite resmi logosu **yoktur** (yer tutucu amblem; K12).

## 6. Bilinçli olarak YOK

Freezed · `AsyncValue`/`hooks_riverpod` · `google_fonts` · `provider` · `bloc` · `auto_route` · `dio` (Firebase dışı HTTP yok) · `hive/isar/sqflite` · `mocktail/mockito` · `golden_toolkit/alchemist` · `get` (GetX) · `flutter_hooks` · `intl_utils`/`easy_localization` · `firebase_analytics` · `firebase_dynamic_links` (kullanımdan kalktı) · `firebase_app_check` (kapsam dışı; K-adayı) · reklam/izleyici SDK'ları.
