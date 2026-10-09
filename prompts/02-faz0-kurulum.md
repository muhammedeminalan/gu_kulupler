# 02 — FAZ 0 KURULUM (T-00: depo, workspace, kalite kapısı)

> **Önkoşul:** `docs/progress.json#gate.planApproved == true` (kullanıcı `docs/PLAN.md`'yi onayladı).
> Bu, roadmap'teki **T-00**'dır. `prompts/task-calistir.md` döngüsüyle çalışır (plan modu → onay → uygulama → kapı → commit); aşağısı T-00'a özel **oyun kitabıdır**: planın içeriğini bu adımlar belirler.
> T-00 **ekran/view/widget kodu içermez.** Tasarım analizi (Faz 1, `prompts/03-faz1-tasarim-analizi.md`) T-00'dan sonra, T-01'den önce yapılır.

## Kapsam (roadmap T-00)

Pub workspace · pubspec/analysis_options/build.yaml uzlaştırma · very_good_analysis · codegen/kalite kapısı bağlama · `.gitignore` (üretilen dosyalar) · `l10n.yaml` + ARB'den prototip-kabuğu anahtarlarının ayrılması (K-21) `{appName}` düzeltmesi (K-22) ve ARB dışa aktarım kusurlarının giderilmesi (K-23) · asset kayıtları · platform yapılandırması · `AppConstants` · ilk commit.

## Adımlar

### 1. Başlangıç durumu
1. `git status` — temiz değilse kullanıcıya **sor** (`AskUserQuestion`: "Mevcut değişiklikleri önce commit'leyelim mi / dokunmadan ilerleyelim mi"). Kullanıcının mevcut işini asla sessizce ezme.
2. Q-17 cevabına göre dal: tek dal ise `main`, dal akışı ise `chore/T-00-kurulum`.
3. Projedeki mevcut `pubspec.yaml`, `analysis_options.yaml`, `build.yaml`, `lib/main.dart`, `lib/firebase_options.dart` kullanıcınındır: **üzerine yazma**, `Edit` ile uzlaştır (`lib/firebase_options.dart` ve platform Firebase dosyaları aynen kalır). Paketle gelen `docs/reference/*.txt` dosyaları kullanıcının önceki `pubspec/analysis_options/build.yaml` örnekleridir (yalnızca karşılaştırma; uzantısı `.txt` — IDE onları paket sanmasın diye); `reference/` ise life_shared/hatayi_yasat konvansiyon örnekleridir (salt okunur, `reference/README.md`).

### 2. Workspace
1. Kök `pubspec.yaml`: `environment.sdk: ^3.12.2`; `workspace: [packages/gu_data, packages/gu_ui]`; `resolution: workspace` **hem kökte hem paketlerde**.
2. `packages/gu_data`, `packages/gu_ui`: `pubspec.yaml` (`publish_to: none`, `resolution: workspace`), `lib/<paket>.dart` barrel, boş `test/`. Q-05 üçüncü paket seçtiyse onu da aynı kalıpla.
3. Bağımlılık yönü: `gu_ui ↛ gu_data`; `gu_data`'da Flutter widget'ı yok. Bunu zorlayan **otomatik denetim** ekle: `tool/check_boundaries.sh` (pubspec bağımlılıkları + `import 'package:flutter/…'` taraması). Kapıya bağla.

### 3. Paketler (`docs/packages.md` + Q-cevapları)
1. `docs/packages.md §2` tablosundaki **koşulları** Q-cevaplarına göre çöz (Q-02/Q-06/Q-08/Q-19 …) ve yalnızca ilgili paketleri ekle.
2. `flutter pub add <paket>` (sürümü pub çözer) — her `gu_data`/`gu_ui` paketi için `--directory` veya paket klasöründe. **Sürüm sabitlemek** için gerekçe `docs/packages.md`'ye yazılır.
3. Kaldır: `google_fonts`, `flutter_lints` (ve Q'ya göre listedeki diğerleri). `uses-material-design: true` kalır.
4. Dev: `build_runner`, `riverpod_generator`, `go_router_builder`, `json_serializable`, `very_good_analysis`, `flutter_launcher_icons`, `flutter_native_splash`, `fake_cloud_firestore` + `firebase_auth_mocks` (Q-06).
5. `flutter pub get` + `flutter pub outdated` çıktısını PLAN'daki sürüm tablosuyla karşılaştır; çatışma varsa **dur** ve sor.

### 4. Lint ve codegen
1. `analysis_options.yaml`: `include: package:very_good_analysis/analysis_options.yaml`; `analyzer.exclude`: `**/*.g.dart`, `**/*.gen.dart`, `lib/l10n/app_localizations*.dart`, `design/**`, `reference/**`, `docs/reference/**`; `strict-casts/inference/raw-types: true`. Her gevşetme gerekçeli yorumla.
2. `build.yaml`: `json_serializable` → `explicit_to_json: true`, `field_rename` kuralı PLAN §9'daki gibi.
3. `tool/codegen.sh` çalışır olmalı (build_runner + gen-l10n). Üretilen dosyalar `.gitignore`'da.

### 5. Yerelleştirme
1. `l10n.yaml` mevcut (`arb-dir: lib/l10n`, `template-arb-file: app_tr.arb`, `output-localization-file: app_localizations.dart`, `nullable-getter: false`). Kurulu Flutter sürümünde `synthetic-package` seçeneği kaldırılmış olabilir; `flutter gen-l10n` uyarı verirse `l10n.yaml`'ı sürüme göre uyarla (üretilen `lib/l10n/app_localizations*.dart` commit edilmez, analyze'dan hariçtir).
2. `node tool/check_arb_parity.js --prune-prototype-only` → 186 prototip-kabuğu anahtarı `design/prototype-only-arb/` altına arşivlenir; `app_tr.arb` / `app_en.arb` **1235** anahtar kalır. Çıktıyı sayarak doğrula.
3. K-22: `legalGizlilikB1` ve `notifTypeSystemWelcomeTitle` içindeki literal ürün adı → `{appName}` (+ Türkçe iyelik eki için `docs/design-known-issues.md` K-22 çözümü). `@key` metadata `placeholders` ekle.
4. **K-23 (ARB dışa aktarım kusurları — `check_arb_parity.js` ARB08 olarak yakalar):**
   - `postComments` ve `timeInDays`: TR **ve** EN `@anahtar.placeholders` içinden sahte yer tutucuları sil (`Yorumlar`/`Comments`, `bug`/`today` — plural `=0{…}` dal metni yer tutucu sanılmış); yalnızca `count` (int) kalır.
   - `searchNoResults`: ICU'da `'{q}'` **tırnaklı literaldir** (`q` basılmaz). Düz tırnağı korumak için TR `''{q}'' için sonuç yok`, EN `No results for ''{q}''` (ICU kaçışı `''`). `flutter gen-l10n` çıktısını küçük bir widget/birim testiyle doğrula (`'sorgu' için sonuç yok`); gen-l10n kaçışı farklı yorumlarsa tipografik “{q}” kullan ve kullanıcıya bildir (referans görüntüde tırnak biçimini kontrol et).
   - Tek tek düzeltmeyi `docs/design-known-issues.md` K-23 satırına işle (durum: giderildi, commit).
5. `flutter gen-l10n` yeşil; `node tool/check_arb_parity.js --strict` yeşil (TR = EN = 1235, uyarı yok).

### 6. Varlıklar
1. `pubspec.yaml#flutter.assets`: `assets/icons/`, `assets/illustrations/`, `assets/covers/`, `assets/patterns/`, `assets/logo/` (alt klasörler dahil); `fonts:` Montserrat (400/500/600/700), Inter (400/500/600) — dosya adları `assets/fonts/` ile birebir.
2. `flutter_launcher_icons` / `flutter_native_splash` yapılandırması yazılır, **çalıştırma T-46'ya** (yayın) bırakılır; sadece yapılandırma dosyaları T-00'da.
3. SVG `rgba()` taraması (K-12): `tool/check_hardcode.sh` `assets/**/*.svg` dosyalarını da tarar (kapıdadır).

### 7. Platform (Q-13 + `docs/packages.md §5`)
1. iOS: SPM açık (kullanıcı ayarladı); `IPHONEOS_DEPLOYMENT_TARGET` Firebase'in gerektirdiğine göre; dikey kilit (`UISupportedInterfaceOrientations`).
2. Android: `minSdk` Firebase + `mobile_scanner` gereksinimi; `android:enableOnBackInvokedCallback="true"`; dikey kilit `screenOrientation`.
3. İzin metinleri (kamera/fotoğraf) **bu task'ta yazılmaz** — ilgili task'ta (T-14/T-35) eklenir; burada yalnızca yer tutucu yorum yok. Kullanıcıya bildir: "platform dosyalarında şunları değiştirdim: …".

### 8. Sabitler
`lib/core/constants/app_constants.dart`: `appName` (= 'GÜ Kulüpler'), `allowedEmailDomains`, `shareBaseUrl` (config, K-09), `supportEmail` (yoksa Açık nokta). Başka hiçbir yerde ürün adı/alan adı yok (D-01).

### 9. Kapı ve araçlar
1. `chmod +x tool/*.sh tool/hooks/*.sh`; `bash tool/verify_pack.sh` yeşil.
2. `.claude/settings.json` hook'ları etkin (`/hooks` ile doğrula).
3. `bash tool/quality_gate.sh --task T-00` — **boş iskelet üzerinde yeşil** olmalı: format → codegen → gen-l10n → analyze → hardcode → no-hard-delete → ARB → kapsam → test (boş test dizinleri için `test/smoke_test.dart` benzeri tek doğrulama testi **yazılabilir**: workspace çözülüyor mu).
4. `docs/progress.json` günceller: `node tool/progress.js done T-00 --commit <sha>`.

### 10. Commit
`chore(T-00): depo iskeleti, workspace ve kalite kapısı` — içerik: pubspec'ler, analysis_options, build.yaml, l10n/ARB, .gitignore, AppConstants, tool/, docs/progress.json. `git push` yok.

## Bitti ölçütleri (T-00)

- [ ] `flutter pub get` workspace'te yeşil; `flutter analyze --fatal-infos` temiz.
- [ ] `check_arb_parity --strict` → TR = EN = 1235; `{appName}` (K-22) ve ARB08 (K-23) düzeltmeleri uygulandı.
- [ ] `check_hardcode`, `check_no_hard_delete`, `check_boundaries` yeşil (iskelet üzerinde).
- [ ] Asset kayıtları geçerli (`flutter build` başlatmadan `flutter pub get` + `flutter test` hata vermiyor).
- [ ] Hiçbir feature/view kodu yok; `design/` ve `reference/` dokunulmadı.
- [ ] Kullanıcıya Türkçe özet + platform dosyası değişiklik listesi + **bir sonraki adım:** Faz 1 tasarım analizi (`prompts/03-faz1-tasarim-analizi.md`).
