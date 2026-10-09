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
7. `equatable ^2.1.0` (3.0.0'dan aşağı çekildi, T-00): `fake_cloud_firestore` ve `firebase_auth_mocks` (Q-06) yalnızca `equatable ^2.0.0` ile çözülür; 3.0.0'ın kırıcı değişiklikleri (runtimeType karşılaştırması, EquatableMixin, toString) projede kullanılmaz (CD-14).

## 2. Çalışma zamanı bağımlılıkları

### 2.1 Kök uygulama (`pubspec.yaml`)

> Kök `pubspec.yaml` `flutter:` bloğunda `generate: true` (gen-l10n ön koşulu, T-00; CD-51).

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
| `image_picker` | kamera/galeri | SHT-16 | Q-19 = yükle (kesin) |
| `flutter_image_compress` | yükleme öncesi boyutlandırma | SHT-16, AUT-05, PRF-02, FED-03, MGT-09 | Q-19 = yükle (kesin); `image` paketi kullanılmaz |
| `cached_network_image` | Storage'tan gelen fotoğraflar | avatar, kapak, gönderi görselleri | Q-19 = yükle (kesin) |
| `flutter_svg` | ikon/kapak/desen/illüstrasyon | her yer | — |
| `flutter_local_notifications`, `timezone` | cihazda planlı hatırlatıcı | SHT-13, EVT-02 | Q-07 = yerel hatırlatıcı (kesin), T-23 |
| `table_calendar` | takvim | SHT-28, EVT-01 | **Kaldırıldı (T-00)** — Q-08 = `GuCalendar` |
| `firebase_core`, `firebase_auth`, `cloud_firestore` | çekirdek | — | — |
| `firebase_storage` | fotoğraf | Q-19 | Q-19 = yükle (kesin); bucket/Blaze K-L → T-46 (`architecture.md §10`) |
| `firebase_messaging` | FCM | bildirim izni, jeton | **Eklenmez (Mod C, Q-02)**; T-42 Mod F'de eklenir |
| `cloud_functions` | callable (gerekirse) | — | **Eklenmez (Mod C, Q-02)**; T-42 Mod F'de eklenir |
| `firebase_remote_config` | sürüm kapısı, bakım, limit ipuçları | DLG-26 | — |
| `firebase_crashlytics` | hata raporu | D-23 | — |

**Kaldırıldı / eklenmedi (T-00):** `google_fonts` (D-12; mevcut pubspec'te zaten yoktu), `flutter_lints` (→ `very_good_analysis`), `flutter_gen_runner` (izinli listede değil; asset erişimi el yazımı kayıt defterleri `GuIcons` / `GuIllustrations` / `GuCovers`, D-13), `table_calendar` (Q-08 → `GuCalendar`), `cloud_functions` ve `firebase_messaging` (Q-02 Mod C; T-42 Mod F'de eklenir). `firebase_storage` ve `cached_network_image` **kalır** (Q-19 = yükle). `uses-material-design: true` kalır (Material widget'ları kullanılır; `Icons.*` kullanılmaz).

### 2.2 `packages/gu_data`
`cloud_firestore`, `firebase_auth`, `firebase_storage` (Q-19 = yükle, kesin), `firebase_remote_config`, `firebase_messaging` (yalnızca Mod F'de (T-42); Mod C'de yok), `firebase_crashlytics`, `equatable`, `json_annotation`, `meta`, `collection`, `crypto`/`dart:math Random.secure` (bilet kodu — **yalnızca `Random.secure()`**).
Dev: `build_runner`, `json_serializable`, `very_good_analysis`, `flutter_test` (sdk) — `test` paketi workspace'te çözülemez (`riverpod_generator` analyzer kısıtı, CD-15); `fake_cloud_firestore` + `firebase_auth_mocks` + `firebase_storage_mocks` (**Q-06**, kesin).

### 2.3 `packages/gu_ui`
`flutter`, `flutter_svg`, `equatable`, `meta`. **Başka paket yok** (Firebase, l10n, router, Riverpod'a bağımlı değil).
Dev: `flutter_test`, `very_good_analysis`.

## 3. Dev bağımlılıkları (kök)

`build_runner`, `riverpod_generator`, `go_router_builder`, `json_serializable`, `very_good_analysis`, `flutter_test`, `integration_test` (sdk), `flutter_launcher_icons`, `flutter_native_splash` (son ikisi: yapılandırma T-00, çalıştırma T-46). Test için ayrıca `fake_cloud_firestore`, `firebase_auth_mocks` (Q-06, kesin; `firebase_storage_mocks` yalnızca `gu_data`). **Mock kütüphanesi (mocktail/mockito) yok** — el yazımı fake'ler (CLAUDE.md §3). **Golden için üçüncü taraf paket yok** — Flutter'ın `matchesGoldenFile`'ı + `test/helpers/golden_helper.dart`.
Opsiyonel (yalnızca uyumlu sürüm bulunursa, aksi halde kullanılmaz): `riverpod_lint` / `custom_lint` — kullanılamazsa `docs/PLAN.md`'ye not. **T-00 dry-run: çözülemez** (analyzer kısıtı — `riverpod_generator 4.0.9 → analyzer >=13 <15`, `custom_lint` / `riverpod_lint` eski analyzer ister; PLAN §5) → kullanılmaz; T-44/T-46'da yeniden denenir.

## 4. Firebase tarafı (Node)

| Yer | Araç |
|---|---|
| `firebase/` | `firebase-tools` (kullanıcı makinesinde), `@firebase/rules-unit-testing`, `jest` veya Node test runner; `package.json` `firebase/test/` içinde |
| `functions/` (Mod F) | TypeScript, Node 20, `firebase-functions` v2, `firebase-admin`, `vitest`/`jest`; ESLint `google` |
| `tool/admin/` | `firebase-admin` (yalnızca `set_superadmin.js`; servis hesabı anahtarı **repoda yok**) |

## 5. Platform notları (görev başına doğrulanır)

- **iOS:** SPM (kullanıcı `enable-swift-package-manager: true` açtı); CocoaPods gerektiren paket çıkarsa `AskUserQuestion`. `Info.plist` izin metinleri (`NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSUserNotificationsUsageDescription` gerekmez; Mod C'de FCM yok → Push Capability **eklenmez**, T-42'de (Mod F) eklenir) **ARB'den değil** `InfoPlist.strings` yerelleştirmesiyle TR/EN; uygulama ad(lar)ı `AppConstants.appName` ile tutarlı.
- **Android:** `minSdk` Firebase + `mobile_scanner` gereksinimine göre; izinler `AndroidManifest.xml`; bildirim kanalı adları ARB'den; predictive back için `android:enableOnBackInvokedCallback="true"`.
- **Ekran yönü:** dikey kilit (Q-13) `SystemChrome.setPreferredOrientations` + platform dosyaları.
- **Uygulama ikonu / splash:** `assets/logo/app-icon-1024.png` → `flutter_launcher_icons`; native splash `flutter_native_splash` (tema renkleri `GuColors`'tan **türetilmiş sabit** olarak `flutter_native_splash.yaml`'a yazılır ve tokenlarla testle eşleştirilir). Üniversite resmi logosu **yoktur** (yer tutucu amblem; K12).

## 6. Bilinçli olarak YOK

> Not (T-00): aşağıdakilerden bazıları (`mockito`, `freezed_annotation`, `sqflite`) başka paketlerin **geçişli** bağımlılığı olarak `pubspec.lock`'ta görünür; doğrudan bağımlılık değildir ve import edilmez (`depend_on_referenced_packages` + `tool/check_boundaries.js` yakalar).

Freezed · `AsyncValue`/`hooks_riverpod` · `google_fonts` · `provider` · `bloc` · `auto_route` · `dio` (Firebase dışı HTTP yok) · `hive/isar/sqflite` · `mocktail/mockito` · `golden_toolkit/alchemist` · `get` (GetX) · `flutter_hooks` · `intl_utils`/`easy_localization` · `firebase_analytics` · `firebase_dynamic_links` (kullanımdan kalktı) · `firebase_app_check` (kapsam dışı; K-adayı) · reklam/izleyici SDK'ları.
