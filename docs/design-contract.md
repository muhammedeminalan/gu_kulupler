# Tasarım Sözleşmesi (1:1 uyum)

> D-17…D-22 bu dokümanda **ölçülebilir** hale gelir. Tasarım = `design/` altındaki Claude Design dışa aktarımı (**salt okunur**). "Birebir" şu demektir: aynı ekran/sheet/dialog/toast kümesi, aynı aksiyonlar, aynı token'lar, aynı ölçüler/boşluklar, aynı metinler (ARB), aynı durumlar, her iki temada ve her iki dilde.

## 1. Kaynaklar ve öncelik

| Ne için | Kaynak (dosya) | Not |
|---|---|---|
| Ekran/sheet/dialog/toast **kimliği**, rota, rol, başlık, ikon/rozet eşlemeleri | `design/extracted/registry.json` | Tek doğruluk kaynağı (51/34/32/78) |
| Her ekranın **aksiyon anahtarları** | `design/extracted/screens-actions.json` | 1072 anahtar; `GuKey.action('<anahtar>')` |
| **Token** değerleri | `design/extracted/registry.json#tokens`, `design/generated-reference/colors/tokens.json`, `typography.json` | 27 renk × 2 tema, 11 tip stili, boşluk/radius/gölge/hareket |
| **Bileşen ölçüleri** (btn 48/40/56, chip 38, input 48…) | `design/extracted/component-css.css`, `css-class-usage.json` | CSS'ten okunur; Dart sabitine çevrilir (`GuSizes`) |
| **Görünüm referansı** | `design/reference-shots/{screens,sheets,dialogs,toasts,states}/*.webp` + `index.json` | 390×844, DPR 2, açık+koyu, TR+EN; **Demo FAB gizli** |
| **Davranış / akış** | `design/prototype/app/*.js` (`actions.js`, `screens-*.js`, `sheets.js`, `dialogs.js`, `flows`) | Preact → Flutter **anlamsal çeviri**; kopyalanmaz |
| **İş kuralları, metin sözleşmesi** | `design/prototype/claude-design-prompt.md` | Veri modeli önerileri (§16 `clubs/{id}/members/...`) **geçersiz** — `docs/domain-model.md` esastır (D-25) |
| Etkileşimli prototip | `design/prototype-standalone/GU Kulupler - Standalone.html` | Tarayıcıda açılır; Kontrol Paneli ile rol/tema/dil/ağ/veri durumu zorlanır |
| Üretilmiş referans kod | `design/generated-reference/` | **Yalnızca referans** (D-14): kullanımdan kalkmış `CardTheme`/`DialogTheme` içerir |

Çelişki sırası `docs/decisions.md §0`.

## 2. Kimlik sistemi

- **Ekran:** `SYS-01…04, ONB-01, AUT-01…06, CLB-01…07, FED-01…03, EVT-01…04, NTF-01…02, PRF-01…04, SET-01…05, MGT-01…10, ADM-01…05` = **51**. `FED-01` bağımsız rota değil, `CLB-03` içindeki **Gönderiler** sekmesinin akışıdır (ID envanterde ayrıdır, Flutter'da `ClubDetailView` içinde `ClubFeedTab`; test ve `/// Design:` izi ayrı tutulur).
- **Sheet** `SHT-01…34`; **Dialog** `DLG-01…32`; **Toast** `TST-01…58` + prototipe özgü `TST-X1…X20` = **78**.
- Brief ve prototip ID'leri **birebir aynıdır** (doğrulandı). Brief'te olmayan 20 ek toast (`TST-X*`) prototipten gelir ve **uygulanır**.
- **Sınıf izi (D-19):** her ekran/sheet/dialog widget'ının üstünde `/// Design: CLB-01` (birden fazla ise virgülle). Toast için `ToastId` enum üyesinin dokümantasyon yorumu `/// Design: TST-12`.
- **Aksiyon anahtarı (D-18):** `GuKey.action('CLB-01.join.c03')`. Dinamik kısım şablonlanır: kodda `GuKey.action('CLB-01.join.${club.id}')`; envanter karşılaştırması şablonu `*` olarak genişletir. Sekme çubuğu: `NAV.tab.<tab>` (ortak kabuk, ayrı ekranlarda tekrar sayılır; kabuk bir kez uygulanır).
- **Uygulanmayan (demo/mock) aksiyonlar** — envanterden **muaf** (`tool/check_design_coverage.js` `EXEMPT_ACTIONS` listesi, gerekçeli):
  `AUT-01.demoAccount.*` (6), `AUT-01.demoToggle`, `AUT-03.demoVerify` (e-posta bağlantısı gerçekte posta kutusundan), `EVT-03.demoScan`, `MGT-07.demoScan.valid|used|invalid`, ayrıca Kontrol Paneli / Demo FAB / cihaz çerçevesi / sahte durum çubuğu / `TST-58` ("Demo: … açılıyor"). Bunların işlevi gerçek akışlarla karşılanır (örn. `MGT-07.demoScan.*` yerine gerçek QR okutma ve manuel kod).

## 3. Doğrulama katmanları (her biri otomatik; kırmızıysa commit yok)

| # | Katman | Ne doğrular | Araç / test |
|---|---|---|---|
| L1 | **Token testi** | `GuColors` (27 × 2), `GuTypography` (11), `GuSpacing`, `GuRadius`, `GuShadows`, `GuMotion`, `GuSizes` değerleri `registry.json#tokens`/`component-css.css` ile birebir; AA kontrast çiftleri | `packages/gu_ui/test/tokens/*` (JSON'u okur) |
| L2 | **ID envanteri** | 51 ekran / 34 sheet / 32 dialog / 78 toast sınıfı/enum'u var; `/// Design:` izi var; her biri `docs/task-map.json`'da tam bir task'a atanmış | `node tool/check_design_coverage.js` |
| L3 | **Aksiyon envanteri** | Ekranda bulunan `GuKey.action` kümesi = `screens-actions.json` (muaflar hariç); fazla/eksik anahtar = hata | `check_design_coverage.js --actions`; widget testi `findsOneWidget` |
| L4 | **Davranış testi** | Her aksiyon beklenen sonucu üretir (rota / sheet / dialog / toast / durum değişikliği) — prototipteki `data-action → sonuç` tablosundan | ekran widget testi |
| L5 | **Görünüm** | Golden (açık/koyu × TR/EN) **ve** referans görüntüyle gözle karşılaştırma | `gu-design-fidelity-reviewer` ajanı (`reference-shots`); golden dosyaları commit edilir |
| L6 | **Cihaz matrisi** | 320/390/430/tablet × açık/koyu × TR/EN × metin ölçeği 1.0/1.3/1.6; **taşma = fail** | `test/helpers/device_matrix.dart` |
| L7 | **Durum çubuğu** | `AnnotatedRegion<SystemUiOverlayStyle>` değeri ekran haritasıyla (§5) uyumlu | `GuSystemUi` widget testi |
| L8 | **A11y/dokunma** | `Semantics` etiketi; etkin dokunma alanı ≥ 44/48 (`GuTapTarget`) | widget testi `meetsGuideline(androidTapTargetGuideline)` + iOS |
| L9 | **ARB** | TR/EN anahtar eşitliği; kullanılmayan/eksik anahtar yok; ICU parametreleri tutarlı | `check_arb_parity.js` |

## 4. Token eşlemesi

| Prototip (CSS / registry) | Dart | Not |
|---|---|---|
| `brand.primary`, `bg.canvas`, `text.heading`… (27) | `GuColors.brandPrimary`, `bgCanvas`, `textHeading`… (`ThemeExtension<GuColors>`, `lerp` içerir) | grup + ad camelCase; her iki tema |
| `TYPE_SCALE` display, titleL/M/S, bodyL/M/S, labelL/M, caption, overline (11) | `GuTypography` (Montserrat: display/title*/overline; Inter: body*/label*/caption) | `height = line/size`; `overline`: `letterSpacing 0.08em` + büyük harf (TR yerel ayarlı `toUpperCase`, "İ" doğru) |
| `SPACING` [4,8,12,16,20,24,32,40,48] | `GuSpacing.s4…s48` + `GuGap.*` (SizedBox) + `GuInsets.*` | sayısal literal yasak |
| `RADIUS` sm12 md16 lg20 xl28 full999 | `GuRadius.sm/md/lg/xl/full` (+ `BorderRadius` getter) | |
| `SHADOWS` e0–e3 | `GuShadows.e0…e3` (`List<BoxShadow>`) | e3 = alt sheet üstü gölge |
| `MOTION` fast120 base200 slow320 + easing eğrileri | `GuMotion.fast/base/slow`, `GuMotion.easeStandard/Emphasized` | `MediaQuery.disableAnimations` → süre 0 |
| `--safe-top:54px` (mock) | `MediaQuery.viewPadding.top` | **sabit 54 yok** |
| `--ts` (metin ölçeği) | `MediaQuery.textScaler` ∘ uygulama ölçeği (Q-14) | yalnızca yazı tipi |
| Bileşen yükseklikleri (btn 48/40/56, text btn 44, iconbtn 48/40, chip 38, input 48, badge 22, appbar 56) | `GuSizes.*` (CSS'ten) | görsel ölçü; etkin alan `GuTapTarget` ile ≥ 44/48 |
| Renk + ikon eşleri (`roleBadge`, `statusBadge`, `notifIcon`, `notifCat`, `actCat`) | `GuRoleBadgeStyle`, `GuStatusBadgeStyle`, `NotificationVisuals`, `ActivityVisuals` (haritalar `registry.json`'dan türetilmiş sabitler + test) | |
| Palet (`red/slate/bordeaux`) × desen (`dots/lines/mountain/waves`) | `ClubPalette`, `ClubPattern` → kapak üreticisi (`GuCover`) | kapak SVG'leri `assets/covers`, desenler `assets/patterns` |

## 5. Durum çubuğu haritası (D-20)

Varsayılan: tema parlaklığına göre (açık tema → koyu ikonlar; koyu tema → açık ikonlar). `GuSystemUi(style: …)` ile **ekran kapsayıcısı** belirler; ekran ekran elle `SystemChrome` çağrılmaz.

| Ekran | Üst alan | Stil |
|---|---|---|
| tüm ekranlar (varsayılan) | tema yüzeyi | tema parlaklığı |
| **CLB-03** Kulüp (kapak görseli üstte) | koyu kapak | **açık ikon** (her iki temada) |
| **EVT-02** Etkinlik (kapaklı) | koyu kapak | **açık ikon**; kapaksız varyantta varsayılan |
| **MGT-07** QR tarayıcı | siyah kamera | **açık ikon** |
| Sheet/dialog scrim açıkken | scrim | alttaki ekranın stili korunur |

Referans ölçüm: `design/reference-shots/screens/*__light__tr.webp` üst 54 px parlaklığı (yalnızca bu üç ekran < 110). Splash (SYS-01) ve onboarding (ONB-01) **açık zemin** üzerindedir (varsayılan).

## 6. Durumlar (her liste/veri bloğu)

`normal · yükleniyor (skeleton) · boş · hata · çevrimdışı` — tasarımda `states/{ID}__{empty|error|offline|loading}.webp` olan ekranlar: CLB-01, CLB-02, CLB-03, EVT-01, EVT-04, NTF-01, PRF-03, PRF-04, MGT-03, MGT-04, ADM-02, ADM-04, ADM-05 (13 ekran). MGT-05'in `loading/empty/error` yakalamaları artefakttır (3 dosya özdeş, normal form; kaynakta liste durumu yok) → MGT-05'e yalnızca çevrimdışı bandı uygulanır; CLB-02/CLB-03 yakalamaları da artefakt, kanıt kaynak (`ui.js:95–99`, `screens-clubs.js:51`, etkinlik sekmesi `ListState`) + `ds_cards.webp` (K-51). Diğer listelerde (üye, katılımcı, gönderi, yorum, faaliyet, başvuru vb.) aynı bileşenler (`GuListState`: `GuSkeleton`, `GuEmptyState`, `GuErrorState`, `GuOfflineState`) kullanılır ve testlenir; ekran görüntüsü yoksa bileşenin tasarım sistemi sayfasındaki hali referanstır (`design/reference-shots/prototype-pages-desktop/`).
Sıra: **hata → yükleniyor → boş → dolu**; çevrimdışı banner üstte kalıcı (CLAUDE.md §4).

## 7. Kontrol listesi — bir ekran "bitti" sayılması için

1. `/// Design: <ID>` var, rota `docs/navigation.md` ile uyumlu.
2. Tüm aksiyon anahtarları var (L3), her biri sonuç üretiyor (L4).
3. Referans görüntüyle (açık+koyu, TR+EN) yan yana karşılaştırıldı; ölçü/boşluk/renk/ikon/metin farkı yok; golden üretildi.
4. 5 durum (varsa) uygulandı ve test edildi.
5. Cihaz matrisi (L6) yeşil; durum çubuğu (L7); dokunma/a11y (L8).
6. Hardcode yok, tekrarlı widget yok, ARB TR+EN tam.
7. Bilinen tasarım kusuru etkiliyorsa `docs/design-known-issues.md` kararı uygulandı ve ekran notlarında anıldı.
8. `docs/widget-catalog.md` ve `docs/progress.json` güncellendi.

## 8. Sapma prosedürü

Tasarımdan **bilinçli** sapma yalnızca (a) `design-known-issues.md`'de kayıtlı bir kusur düzeltmesi, ya da (b) kullanıcının `AskUserQuestion` ile onayladığı değişiklik olabilir. Sessiz sapma = hata. Her onaylı sapma `docs/decisions.md`'ye (K-xx) ve ilgili ekranın golden notuna yazılır.
