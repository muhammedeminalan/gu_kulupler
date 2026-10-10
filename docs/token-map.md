# Token Haritası — `docs/token-map.md` (Faz 1 TASLAĞI)

> **Kaynak hiyerarşisi:** `docs/PLAN.md §7` (bağlayıcı plan) → bu dosyada `design/extracted/registry.json#tokens`, `design/generated-reference/colors/tokens.json`, `design/generated-reference/typography.json` ve `design/extracted/component-css.css` (427 satır) ile satır satır **doğrulandı**. Her satır: **ad → değer → kaynak (dosya:satır)**.
> Doğrulama sonucu (betikle): `registry.json#tokens.COLORS` (27) == `tokens.json#colors` (27, `usage` dahil); `RADIUS`/`SHADOWS`/`MOTION`/`SPACING` eşit; `TYPE_SCALE` (11) == `typography.json#scale`. `component-css.css` ile `core.js` içindeki CSS aynı (satır numaraları bu dosyada `component-css.css`'e göredir; `core.js` içindeki CSS `component-css.css`'e göre −22 satır kaymıştır: css:199 `.badge-brand` ↔ core.js:177, css:426 ↔ core.js:404).
> Kurallar: ad kuralı registry `grup.ad` → `grupAd` (design-contract §4); CSS türevi değerler aynı sınıfta `/// CSS-derived` grubunda (CD-20); literal yalnızca `packages/gu_ui/lib/src/tokens/` ve `/theme/` içinde (HC02/HC03/HC04/HC07/HC17). Açık nokta yok (CD-107: kullanıcıya soru 0); Faz 1 bulguları ve CD kapanışları §13'tedir.
> Kısaltmalar: `css:N` = `design/extracted/component-css.css` satır N · `ui:N` = `design/prototype/app/ui.js` satır N · `art:N` = `art.js` · `shell:N` = `shell.js` · `cards:N` = `cards.js` · `sheets:N` = `sheets.js` · `core:N` = `core.js` · `reg` = `registry.json#tokens` · `tj` = `colors/tokens.json`.

> **T-01 uygulama notu (2026-10-09):** Bu harita `packages/gu_ui/lib/src/tokens/*` olarak uygulandı. Sapmalar CD-120 (1)–(8): `GuSizes` N = **402** (inceleme sonrası + K-46 2: `viewerZoomScale`, `applicationLeaveOffsetX`), `emblemIconSizes` + 14, 4 sayaç `int`, `GuMotion` + `spinCurve`/`shimmerCurve`/`scanCurve`, `GuTypography` 43 alan (inceleme sonrası + `toastAction`) + `avatarMoreFor` + `nonScalingStyleNames` (K-57), tüm stiller `leadingDistribution: even`; `GuShadows` blur CSS σ'sına çevrilir (`cssBlurToRadius`, §6); `GuMotion` + `easeCss`, `viewerZoom` (§7); (8) §8.8 `coverIcon` kaynağı art.js:34; §12 gölge ve tipografi regex'leri testlerde genişletildi (birimsiz `0`, `Npx/Npx` biçimi); `expectedNonTextContrastFailures` 10 çift = tema bazında 11 kayıt (switch rayı açık + koyu ayrı satır). K-55 avatar baş harf kontrastı.

## 0. Sayım özeti (PLAN §7 ↔ doğrulanan)

| Grup | PLAN §7 | Doğrulanan | Fark |
|---|---|---|---|
| Renk (`GuColors`) | 27 × 2 | 27 × 2 (`reg.COLORS`, `tj.colors`) | yok |
| `GuComponentColors` | 13 | **18** (CD-87): CSS'ten 13 (§2 #1–13) + JS satır içi 5 (§2 #14–18: `scanMutedForeground`, `scanPanelScrim`, `scanOutlineBorder`, `viewerHintForeground`, `qrModule`); #6 `toastActionForeground` koyu `#1E2024` (CD-98, K-41) | +5 (CD-87); decisions.md CD-17 satırına "→ CD-87: 18" notu |
| Tipografi ölçek | 11 | 11 (`reg.TYPE_SCALE`, css:87–97) | yok |
| Tipografi CSS türevi | 26 (25 + `mapPlaceholder`; +2 boyut türevi) | 26 doğrulandı + **4 ek** (`bannerAction`, `toastAction` CSS; `splashTitle`, `ticketCode` K-46); `logoWordmarkBase` yazılmaz (CD-90) | §3.2 |
| Boşluk | 9 + 3 CSS (`s2 s6 s10`) | 9 + **2** CSS'te tanımlı (`gap2`, `gap6`); `gap10`/`pb8`/`pt24` CSS'te tanımsız → `GuSpacing.s10` yazılmaz (CD-99, K-42) | §4; PLAN §7.3 addendum (CD-99) |
| Radius | 5 + 9 türev | 5 + 9 doğrulandı | yok |
| Gölge | 4 + 3 türev | 4 + 3 doğrulandı (`ctaBar`, `fab`, `switchThumb`; + 4 token olmayan türev §6.2: `scanLineGlow`, `timelineDotRing`, `calendarTodayRing`, `highlight` — widget içinde tema rengi + `GuSizes`) | §6 |
| Hareket | 5 + 17 keyframe/ölçek + toast 2 | 5 + 17 + 2 doğrulandı + **6 ek** (`countdownTick` CD-97; `longPress`, `heartPopReset`, `applicationLeave`, `viewerDoubleTap`, `viewerZoom` K-46) + `easeCss` (CSS `ease`, eğrisi yazılmamış geçişler); `refreshSettle` = `base` (ayrı sabit yok); SHT-24 oto-kapanma `AppDurations.qrSuccessAutoClose` (`GuMotion` dışı, CD-58) | §7 |
| `GuSizes` | 364 assert (353 ölçü + 11 ikon) | PLAN §7.7.1–7.7.6 satırlarının tamamı doğrulandı (353) + F-L **ek** 26 (taslaktaki 34 − 4 logo oranı CD-90 − 4 ad genişliği K-29/CD-106a) + 2 `/// Platform-derived` (CD-97) + K-46 8 + K-47 1 (`avatarGroupSizes`) + 11 ikon; `illustrationSizes` (K-48) ve `logoSizes` mevcut liste sabitlerini günceller → aday 401; **T-01 nihai N = 402** (`miniChartFillOpacity` → `GuOpacity.miniChartFill`, CD-120; inceleme sonrası K-46 + 2: `viewerZoomScale`, `applicationLeaveOffsetX`) | §8 |
| `GuOpacity` | 8 | 8 + 1 ek (`coverIcon` .12) | §8.8 |
| `GuBreakpoints` | 6 | 6 | yok |
| AA kontrast beklenen kusur | 3 çift + disabled muaf | metin **4 çift** (CD-100): CD-22'nin 3'ü (4.35 / 2.12 / 2.54) + `brandPrimaryText/bgSurfaceRaised` koyu 4.45; metin dışı **10 çift** (K-43'ün 9'u + CD-110 `switch` kapalı rayı; CD-100); toast eylem metni koyu CD-98 ile 12.45 (K-41) | §10 |

## 1. Renkler — `GuColors` (27 × açık/koyu; `ThemeExtension<GuColors>`, `lerp` alan alan)

Kaynak: `reg.COLORS[k] = [açık, koyu]` (core:15–24 tanım), `tj.colors[k].{light,dark,usage}`; CSS değişkenleri css:3–45 (açık), css:46–75 (koyu). Dart: `Color(0xAARRGGBB)`; `rgba(r,g,b,a)` → `AA = round(a × 255)` (.48 → 0x7A, .60 → 0x99).

| # | Registry adı | `GuColors` alanı | Açık | Koyu | Açık Dart | Koyu Dart | Kullanım (`COLOR_USAGE`) | Kaynak |
|---|---|---|---|---|---|---|---|---|
| 1 | `brand.primary` | `brandPrimary` | `#D00A2D` | `#D00A2D` | `Color(0xFFD00A2D)` | `Color(0xFFD00A2D)` | Dolu butonlar, aktif sekme göstergesi, rozetler | css:4 / css:47 |
| 2 | `brand.primaryText` | `brandPrimaryText` | `#D00A2D` | `#F2536C` | `Color(0xFFD00A2D)` | `Color(0xFFF2536C)` | Link, ikon, vurgulu metin | css:5 / css:48 |
| 3 | `brand.primaryPressed` | `brandPrimaryPressed` | `#A80824` | `#B8082A` | `Color(0xFFA80824)` | `Color(0xFFB8082A)` | Basılı durum | css:6 / css:49 |
| 4 | `brand.onPrimary` | `brandOnPrimary` | `#FFFFFF` | `#FFFFFF` | `Color(0xFFFFFFFF)` | `Color(0xFFFFFFFF)` | Kırmızı üstü metin/ikon | css:7 / css:50 |
| 5 | `brand.primaryContainer` | `brandPrimaryContainer` | `#FCE8EC` | `#3A0C16` | `Color(0xFFFCE8EC)` | `Color(0xFF3A0C16)` | Tonal arka plan | css:8 / css:51 |
| 6 | `brand.onPrimaryContainer` | `brandOnPrimaryContainer` | `#7A0619` | `#FFD9E0` | `Color(0xFF7A0619)` | `Color(0xFFFFD9E0)` | Tonal üstü metin | css:9 / css:52 |
| 7 | `bg.canvas` | `bgCanvas` | `#FAF9F6` | `#17191C` | `Color(0xFFFAF9F6)` | `Color(0xFF17191C)` | Sayfa zemini | css:10 / css:53 |
| 8 | `bg.surface` | `bgSurface` | `#FFFFFF` | `#1E2024` | `Color(0xFFFFFFFF)` | `Color(0xFF1E2024)` | Kart yüzeyi | css:11 / css:54 |
| 9 | `bg.surfaceMuted` | `bgSurfaceMuted` | `#F1F5F9` | `#292E35` | `Color(0xFFF1F5F9)` | `Color(0xFF292E35)` | Girdi, çip, ikincil alan | css:12 / css:55 |
| 10 | `bg.surfaceRaised` | `bgSurfaceRaised` | `#FFFFFF` | `#23272E` | `Color(0xFFFFFFFF)` | `Color(0xFF23272E)` | Sheet, dialog | css:13 / css:56 |
| 11 | `border.default` | `borderDefault` | `#E2E8F0` | `#39414B` | `Color(0xFFE2E8F0)` | `Color(0xFF39414B)` | Kenarlık | css:14 / css:57 |
| 12 | `border.soft` | `borderSoft` | `#EEF1F5` | `#303740` | `Color(0xFFEEF1F5)` | `Color(0xFF303740)` | Ayraç | css:15 / css:58 |
| 13 | `text.primary` | `textPrimary` | `#101828` | `#F1F1ED` | `Color(0xFF101828)` | `Color(0xFFF1F1ED)` | Gövde | css:16 / css:59 |
| 14 | `text.heading` | `textHeading` | `#1D293D` | `#F5F5F1` | `Color(0xFF1D293D)` | `Color(0xFFF5F5F1)` | Başlık | css:17 / css:60 |
| 15 | `text.secondary` | `textSecondary` | `#45556C` | `#C6CCD4` | `Color(0xFF45556C)` | `Color(0xFFC6CCD4)` | İkincil | css:18 / css:61 |
| 16 | `text.muted` | `textMuted` | `#62748E` | `#AEB5BF` | `Color(0xFF62748E)` | `Color(0xFFAEB5BF)` | Yardımcı, zaman damgası | css:19 / css:62 |
| 17 | `text.disabled` | `textDisabled` | `#A3AEBF` | `#6B7480` | `Color(0xFFA3AEBF)` | `Color(0xFF6B7480)` | Devre dışı | css:20 / css:63 |
| 18 | `state.success` | `stateSuccess` | `#15803D` | `#4ADE80` | `Color(0xFF15803D)` | `Color(0xFF4ADE80)` | Onaylandı, katıldı | css:21 / css:64 |
| 19 | `state.successContainer` | `stateSuccessContainer` | `#DCFCE7` | `#0F2E1A` | `Color(0xFFDCFCE7)` | `Color(0xFF0F2E1A)` | Başarı zemini | css:22 / css:65 |
| 20 | `state.warning` | `stateWarning` | `#B45309` | `#FBBF24` | `Color(0xFFB45309)` | `Color(0xFFFBBF24)` | Beklemede, dikkat | css:23 / css:66 |
| 21 | `state.warningContainer` | `stateWarningContainer` | `#FEF3C7` | `#3A2A0A` | `Color(0xFFFEF3C7)` | `Color(0xFF3A2A0A)` | Uyarı zemini | css:24 / css:67 |
| 22 | `state.danger` | `stateDanger` | `#B42318` | `#FF7A70` | `Color(0xFFB42318)` | `Color(0xFFFF7A70)` | Hata, silme | css:25 / css:68 |
| 23 | `state.dangerContainer` | `stateDangerContainer` | `#FEE4E2` | `#3B1512` | `Color(0xFFFEE4E2)` | `Color(0xFF3B1512)` | Hata zemini | css:26 / css:69 |
| 24 | `state.info` | `stateInfo` | `#1D5FAD` | `#7DB7F2` | `Color(0xFF1D5FAD)` | `Color(0xFF7DB7F2)` | Bilgi | css:27 / css:70 |
| 25 | `state.infoContainer` | `stateInfoContainer` | `#E3F0FC` | `#0F2538` | `Color(0xFFE3F0FC)` | `Color(0xFF0F2538)` | Bilgi zemini | css:28 / css:71 |
| 26 | `overlay.scrim` | `overlayScrim` | `rgba(16,24,40,.48)` | `rgba(0,0,0,.60)` | `Color(0x7A101828)` | `Color(0x99000000)` | Sheet/dialog arkası | css:29 / css:72 |
| 27 | `focus.ring` | `focusRing` | `#D00A2D` | `#F2536C` | `Color(0xFFD00A2D)` | `Color(0xFFF2536C)` | 2 px halka, 2 px offset (css:82) | css:30 / css:73 |

API (PLAN §7.1): `const GuColors({required Color brandPrimary, – 27 zorunlu})`, `static const light`, `static const dark`, `Brightness brightness`, `GuColors copyWith({Color? brandPrimary, –})`, `GuColors lerp(GuColors? other, double t)`, `List<Object?> get props` (27). Material rengi yalnızca `Colors.transparent` (HC02). Görsel referans: `design/reference-shots/prototype-pages-desktop/ds_colors.webp` (27 örnek × 2 tema, adlar registry ile aynı — açıldı, doğrulandı).

### 1.1 Koyu temada farklı token kullanan bileşenler (`.gu-root[data-theme="dark"]` kuralları; widget `context.gu.isDark` ile seçer)

| CSS seçici | Açık | Koyu | Kaynak | Flutter yeri |
|---|---|---|---|---|
| `.card` kenarlık | `borderSoft` | `borderDefault` | css:203 / css:204 | `GuCard` (T-04) |
| `.chip` zemin | `bgSurface` | `bgSurfaceMuted` | css:176 / css:177 | `GuChip` (T-04) |
| `.chip` kenarlık | `borderDefault` | `#4A5362` (`component.chipBorder`) | css:176 / css:177 | `GuChip` |
| `.chip.is-selected` | zemin `brandPrimaryContainer`, kenarlık `brandPrimary`, metin `brandOnPrimaryContainer`, ikon `brandPrimaryText` | zemin `brandPrimary`, kenarlık `brandPrimary`, metin+ikon `brandOnPrimary`; `.chip-count` zemin `brandOnPrimary`, metin `brandPrimary` | css:181 / css:182–183 | `GuChip` |
| `.seg>button[aria-selected]` | zemin `bgSurface` + gölge `e1` | zemin `bgSurfaceRaised` + kenarlık 1 `borderDefault` | css:222 / css:223 | `GuSegmented` (T-05) |
| `.sheet` | — | üst kenarlık 1 `borderDefault` | css:269 | `GuSheetFrame` (T-07) |
| `.dialog` | — | kenarlık 1 `borderDefault` | css:283 | `GuDialogFrame` (T-07) |
| `.fab` gölge | `e2` | `0 4px 16px rgba(0,0,0,.4)` (`GuShadows.fab`) | css:158 / css:159 | `GuFab` (T-04, CD-25) |
| `.ctabar` gölge | `0 -4px 16px rgba(16,24,40,.06)` | yok | css:296 / css:299 | `GuStickyCta` (T-06) |
| `.toast .toast-action` | zemin `rgba(255,255,255,.12)`, metin `#FFF` | zemin `rgba(0,0,0,.08)`, metin `var(--text-heading)` (= toast zemini, 1.2; Flutter koyu değeri `bgSurface` koyu `#1E2024` — CD-98, K-41, §10.3) | css:293 / css:294 | `GuToast` (T-07) |
| `--e1/--e2/--e3` | listeler | `none` | css:37–39 / css:74 | `GuShadows.dark` |
| `.avatar-group .avatar` kenarlığı, `.nav-badge` kenarlığı | `bgSurface` | `bgSurface` (token koyu değeri) | css:218, css:137 | `GuAvatarGroup`, `GuBottomNav` |

## 2. Registry dışı CSS bileşen renkleri — `GuComponentColors` (18 alan: 13 CSS + 5 JS satır içi, CD-87; `ThemeExtension`, CD-17)

| # | Alan | CSS kaynağı | Açık | Koyu | Dart (açık / koyu) |
|---|---|---|---|---|---|
| 1 | `chipBorder` | `.chip{border:1px solid var(--border-default)}` css:176 · koyu `.chip{border-color:#4A5362}` css:177 | `#E2E8F0` (= `borderDefault`) | `#4A5362` | `Color(0xFFE2E8F0)` / `Color(0xFF4A5362)` |
| 2 | `onCoverScrim` | `.iconbtn.on-cover{background:rgba(0,0,0,.28)}` css:155 | `rgba(0,0,0,.28)` | aynı | `Color(0x47000000)` |
| 3 | `onCoverScrimPressed` | `.iconbtn.on-cover:hover{background:rgba(0,0,0,.4)}` css:155 (`:hover` → basılı, K-53) | `rgba(0,0,0,.4)` | aynı | `Color(0x66000000)` |
| 4 | `onCoverForeground` | `.iconbtn.on-cover{color:#fff}` css:155 · `.statusbar.on-dark{color:#fff}` css:115 (mock) · `.viewer{color:#fff}` css:409 · `.scan-view{color:#fff}` css:401 | `#FFFFFF` | aynı | `Color(0xFFFFFFFF)` |
| 5 | `toastActionBackground` | `.toast .toast-action{background:rgba(255,255,255,.12)}` css:293 · koyu `rgba(0,0,0,.08)` css:294 | `rgba(255,255,255,.12)` | `rgba(0,0,0,.08)` | `Color(0x1FFFFFFF)` / `Color(0x14000000)` |
| 6 | `toastActionForeground` | `.toast .toast-action{color:#fff}` css:293 · koyu `color:var(--text-heading)` css:294 | `#FFFFFF` | `#1E2024` (= `bgSurface` koyu, toast metniyle aynı; kontrast 12.45 — CD-98, K-41; CSS'teki koyu değer `#F5F5F1` toast zeminiyle aynı, 1.2) | `Color(0xFFFFFFFF)` / `Color(0xFF1E2024)` |
| 7 | `scanViewGradientStart` | `.scan-view{background:radial-gradient(ellipse at 50% 40%,#2a2f3a,#0b0d12 75%)}` css:401 | `#2A2F3A` | aynı | `Color(0xFF2A2F3A)` |
| 8 | `scanViewGradientEnd` | aynı satır css:401 (`75%` durağı → `GuSizes.scanGradientStop = 0.75`, merkez `Alignment(0, -0.2)`) | `#0B0D12` | aynı | `Color(0xFF0B0D12)` |
| 9 | `scanBoxCorner` | `.scan-box>i{border:3px solid #fff}` css:403 | `#FFFFFF` | aynı | `Color(0xFFFFFFFF)` |
| 10 | `viewerBackground` | `.viewer{background:#000}` css:409 | `#000000` | aynı | `Color(0xFF000000)` |
| 11 | `qrBackground` | `.qr` bloğu `background:#fff` css:326 · art.js:102 `qrSVG` arka plan `<rect fill="#fff">`; modül rengi ayrı alan #18 `qrModule` (CD-87) | `#FFFFFF` | aynı | `Color(0xFFFFFFFF)` |
| 12 | `avatarInitials` | `.avatar{color:#fff}` css:217 · art.js:42 `avatarSVG` `fill="#fff"` | `#FFFFFF` | aynı | `Color(0xFFFFFFFF)` |
| 13 | `coverInk` | art.js:5–7 `PALETTES.*.ink` | `#FFFFFF` | aynı | `Color(0xFFFFFFFF)` |
| 14 | `scanMutedForeground` | JS satır içi (CSS'te yok): MGT-07 izin açıklaması, sayaç ve ipucu metni `color:rgba(255,255,255,.7)` screens-manage.js:149, :151, :152 | `rgba(255,255,255,.7)` | aynı | `Color(0xB3FFFFFF)` |
| 15 | `scanPanelScrim` | MGT-07 alt panel `background:rgba(0,0,0,.35)` screens-manage.js:153 | `rgba(0,0,0,.35)` | aynı | `Color(0x59000000)` |
| 16 | `scanOutlineBorder` | MGT-07 outline düğme `borderColor: 'rgba(255,255,255,.4)'` screens-manage.js:149, :154 | `rgba(255,255,255,.4)` | aynı | `Color(0x66FFFFFF)` |
| 17 | `viewerHintForeground` | SHT-34 yakınlaştırma ipucu `color:rgba(255,255,255,.6)` sheets.js:162 | `rgba(255,255,255,.6)` | aynı | `Color(0x99FFFFFF)` |
| 18 | `qrModule` | art.js:102 `qrSVG(seed, size = 220, color = '#101828')` modül rengi (= `textPrimary` açık; koyu temada da sabit); `qrForeground` ile aynı alan (CD-106h) | `#101828` | aynı | `Color(0xFF101828)` |

JS satır içi alanlar (#14–18) açık = koyu (CD-87); token testi değeri JS literalinden doğrular. Fener açık durumu (screens-manage.js:151 `background: '#fff', color: '#000'`) mevcut `onCoverForeground` / `viewerBackground` değerlerini kullanır; MGT-07 demo satırı (`rgba(255,255,255,.6)` screens-manage.js:155, `common.demo`) maket, alan yazılmaz (K-02).

Statik sabitler (aynı dosya, `/// CSS-derived`): `avatarHueShift = 36`, `avatarSaturation1 = 0.48`, `avatarLightness1 = 0.42`, `avatarSaturation2 = 0.55`, `avatarLightness2 = 0.32` (art.js:41 `avatarColors`: `hue = hashStr('av:'+seed) % 360`, `hue2 = (hue+36) % 360`, `hsl(hue 48% 42%)` → `hsl(hue2 55% 32%)`, gradyan `135deg` = `Alignment.topLeft → bottomRight`); `hashStr` = FNV-1a 32 bit, offset `2166136261`, asal `16777619`, `>>> 0` (core:418) → Dart `GuStableHash.fnv1a32` (`packages/gu_ui/lib/src/utils/stable_hash.dart`, CD-94; `input.codeUnits` = JS `charCodeAt`; Dart `String.hashCode` kararlı değildir). Kapak paletleri (art.js:4–8; SVG varlıklarında gömülü, kodda yalnızca referans — `GuClubPalettes.of(GuCoverPalette)` → `GuClubPaletteColors{start, middle, end, ink, patternOpacity}`, `tokens/gu_club_palettes.dart`, T-03; test `tokens/gu_club_palettes_test.dart` değerleri art.js'ten okur): `red` `#A80824/#D00A2D/#F3B8C2` desen alfa .55 · `slate` `#14213A/#1D293D/#3F5F8F` alfa .45 · `bordeaux` `#4A0C19/#7A1F30/#D9BC8C` alfa .5; gradyan durakları `0 / .55 / 1`, açı `15–104°` seed'e bağlı (art.js:32). İllüstrasyon renkleri varlıkta sabit: taban `#62748E` (= `textMuted` açık; `Illustration` bileşeni `currentColor = var(--text-disabled)` verir, art.js:88 — varlık SVG'leri bu değerle dışa aktarılmış: `assets/illustrations` 12 SVG'de taban `#62748E` (stroke 24, fill 12), `currentColor` yok (`grep`, bu analizde) → geçerli değer `#62748E`; K-20), vurgu `#D00A2D` (art.js:87). Logo yer tutucu: `#D00A2D` amblem, metin açık `#1D293D` / koyu `#F5F5F1` (art.js:53–55; `placeholder-emblem(-dark).svg` varlıkları).

## 3. Tipografi — `GuTypography` (11 ölçek + 26 CSS türevi [PLAN'daki 25 + `mapPlaceholder`] + 4 ek + 2 boyut türevi = 43 alan)

Fontlar `assets/fonts` (7 TTF, doğrulandı: `Montserrat-{Regular,Medium,SemiBold,Bold}.ttf`, `Inter-{Regular,Medium,SemiBold}.ttf`; kayıt PLAN §7.10). `height = line / size` (4 ondalık). Renk CSS'teki gibi bağlanır (`GuTypography.resolve(GuColors)`): `.t-display/.t-title-*` → `textHeading` (css:87–90); `.t-caption/.t-overline` → `textMuted` (css:96–97); gövde/etiket → `textPrimary` (kök `.gu-root{color:var(--text-primary)}` css:77). Kök yazı: `font-size:15px; line-height:1.47; font-family:Inter` (css:77) = `bodyM`. Tüm stiller `leadingDistribution: TextLeadingDistribution.even` taşır (CSS yarım satır aralığı üste ve alta eşit dağılır; `*For(size)` türevleri dahil). **Ölçeklenmeyen stiller (K-57):** prototip bu kuralları `calc(Npx*var(--ts))` yerine sabit px ile yazar → `GuTypography.nonScalingStyleNames` = `countBadge` (css:137/157/186), `countBadgeLg` (css:200), `avatarMore` (css:218 + art.js:50), `calendarHead` (css:317), `dateBadgeMonth` (css:319), `swipeAction` (css:337), `tooltip` (css:341), `mapPlaceholder` (css:410), `avatarInitialsBase` (art.js:45–46 `fontSize: fs + 'px'`), `donutValueBase` (ui.js:93 SVG `font-size=${size / 4.5}`); widget bunları `TextScaler.noScaling` ile çizer. Kapsam dışı sabit px kuralları (`.statusbar` D-20, `.code/.pre` K-02, site chrome/panel/demo-fab mock) eşlenmez; token testi CSS'teki tüm sabit px font kurallarını tarar (yeni kural kırmızı). Görsel referans: `prototype-pages-desktop/ds_type.webp` (11 stil × 2 tema; Türkçe glif örneği `ğüşiöç İ`).

### 3.1 Ölçek (11) — `reg.TYPE_SCALE` = `typography.json#scale` (eşit)

| # | Registry id | Alan | Font / dosya | Boyut | Satır | Ağırlık | `height` | `letterSpacing` | Renk | CSS |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `display` | `display` | Montserrat / `Montserrat-Bold.ttf` | 28 | 34 | 700 | 1.2143 | 0 | `textHeading` | css:87 `700 28px/1.214` |
| 2 | `titleL` | `titleL` | Montserrat / Bold | 22 | 28 | 700 | 1.2727 | 0 | `textHeading` | css:88 |
| 3 | `titleM` | `titleM` | Montserrat / SemiBold | 18 | 24 | 600 | 1.3333 | 0 | `textHeading` | css:89 |
| 4 | `titleS` | `titleS` | Montserrat / SemiBold | 16 | 22 | 600 | 1.3750 | 0 | `textHeading` | css:90 |
| 5 | `bodyL` | `bodyL` | Inter / Regular | 16 | 24 | 400 | 1.5000 | 0 | `textPrimary` | css:91 |
| 6 | `bodyM` | `bodyM` | Inter / Regular | 15 | 22 | 400 | 1.4667 | 0 | `textPrimary` | css:92 |
| 7 | `bodyS` | `bodyS` | Inter / Regular | 13 | 18 | 400 | 1.3846 | 0 | `textPrimary` | css:93 |
| 8 | `labelL` | `labelL` | Inter / SemiBold | 14 | 20 | 600 | 1.4286 | 0 | `textPrimary` | css:94 |
| 9 | `labelM` | `labelM` | Inter / SemiBold | 12 | 16 | 600 | 1.3333 | 0 | `textPrimary` | css:95 |
| 10 | `caption` | `caption` | Inter / Medium | 12 | 16 | 500 | 1.3333 | 0 | `textMuted` | css:96 |
| 11 | `overline` | `overline` | Montserrat / SemiBold | 11 | 14 | 600 | 1.2727 | `0.88` (0.08em × 11) | `textMuted` | css:97 (`letter-spacing:0.08em; text-transform:uppercase` → çağıran `upperFor(locale)`, CD-11) |

Not: CSS `line-height` değerleri 3 ondalıktır (1.214, 1.273, 1.333, 1.375, 1.500, 1.467, 1.385, 1.429, 1.333, 1.333, 1.273); Dart `height` `line/size`'dan 4 ondalıkla türetilir, token testi ± 0.0005 toleransla CSS'i okur (PLAN §7.14).

### 3.2 CSS bileşen tipografisi (`/// CSS-derived`; `ts` ölçek çarpanı yalnızca `font`'ta, K-08)

| # | Alan | CSS seçici (satır) | Font | Boyut | `height` | Ağırlık | Ek |
|---|---|---|---|---|---|---|---|
| 1 | `button` | `.btn` css:139 `600 14px/1.3 Inter` | Inter | 14 | 1.3 | 600 | `.fab` css:158 aynı (`600 14px Inter`, satır yüksekliği yok → `height: null`) |
| 2 | `buttonSm` | `.btn-sm` css:141 `font-size:13px` | Inter | 13 | 1.3 | 600 | `= button.copyWith(fontSize: 13)` |
| 3 | `buttonLg` | `.btn-lg` css:141 `font-size:16px` | Inter | 16 | 1.3 | 600 | `= button.copyWith(fontSize: 16)` |
| 4 | `chip` | `.chip` css:176 `600 13px/1.33 Inter` | Inter | 13 | 1.33 | 600 | |
| 5 | `badge` | `.badge` css:188 `600 12px/1 Inter` | Inter | 12 | 1.0 | 600 | |
| 6 | `countBadge` | `.nav-badge` css:137, `.dot-badge` css:157, `.chip-count` css:186 `700 11px/18px` | Inter | 11 | 1.6364 | 700 | metin `brandOnPrimary` (`#fff`); Inter 700 paketli değil (D-12) → Flutter en yakın 600'ü çizer (K-56); ölçeklenmez (K-57) |
| 7 | `countBadgeLg` | `.badge-count` css:200 `700 11px/20px` | Inter | 11 | 1.8182 | 700 | Inter 700 → 600 çizilir (K-56); ölçeklenmez (K-57) |
| 8 | `fieldLabel` | `.field-label` css:162 `600 12px/1.33` | Inter | 12 | 1.33 | 600 | renk `textSecondary` |
| 9 | `input` | `.input input,.input textarea` css:166 `400 15px/1.47` | Inter | 15 | 1.47 | 400 | yer tutucu `textMuted` css:167; metin `textPrimary` |
| 10 | `fieldHelp` | `.field-help` css:171 `500 12px/1.33`, `.field-counter` css:172 `500 12px` | Inter | 12 | 1.33 | 500 | `textMuted`; hata `stateDanger` css:171; sayaç `tabularFigures` css:172, `is-over` → `stateDanger` |
| 11 | `segment` | `.seg>button` css:221 `600 13px/1.2` | Inter | 13 | 1.2 | 600 | pasif `textSecondary`, seçili `textHeading` css:222 |
| 12 | `tab` | `.tabs>button` css:226 `600 14px/1.2` | Inter | 14 | 1.2 | 600 | pasif `textMuted`, seçili `brandPrimaryText` css:227 |
| 13 | `navLabel` | `.bottomnav>button` css:134 `600 11px/1.2` | Inter | 11 | 1.2 | 600 | pasif `textMuted`, aktif `brandPrimaryText` css:135 |
| 14 | `banner` | `.banner` css:248 `500 13px/1.4` | Inter | 13 | 1.4 | 500 | renk türe göre (css:250–255) |
| 15 | `toast` | `.toast` css:290 `500 13px/1.4` | Inter | 13 | 1.4 | 500 | metin `bgSurface` (toast zemini `textHeading`) |
| 16 | `swipeAction` | `.notif-under` css:337 `600 13px` | Inter | 13 | null | 600 | metin `#fff` (`brandOnPrimary`), zemin `stateInfo`/`stateDanger` css:338 (K-25) |
| 17 | `kpiValue` | `.kpi .kpi-value` css:303 `700 26px/1.1 Montserrat` | Montserrat | 26 | 1.1 | 700 | `tabularFigures`, `textHeading`; `is-accent` → `brandPrimaryText` css:304 |
| 18 | `dateBadgeDay` | `.date-badge b` css:319 `700 18px/1 Montserrat` | Montserrat | 18 | 1.0 | 700 | |
| 19 | `dateBadgeMonth` | `.date-badge span` css:319 `600 11px/1 Inter; uppercase` | Inter | 11 | 1.0 | 600 | büyük harf çağıranda (`upperFor(locale)`) |
| 20 | `calendarHead` | `.cal-head` css:317 `600 11px Inter` | Inter | 11 | null | 600 | `textMuted` |
| 21 | `calendarDay` | `.cal-day` css:314 `500 13px Inter` | Inter | 13 | null | 500 | `textPrimary`; `is-other`/disabled `textDisabled`, seçili `#fff` css:315 |
| 22 | `wheel` | `.wheel>button` css:322 `600 18px Montserrat` | Montserrat | 18 | null | 600 | pasif `textMuted`, seçili `textHeading` |
| 23 | `avatarMore` | `.avatar-group .more` css:218 `600 11px Inter` | Inter | 11 | null | 600 | `textSecondary`; gerçek boyut `max(10, round(size × .38))` art.js:50 → `avatarMore` (11 px taban) + `GuTypography.avatarMoreFor(size)` = `max(GuSizes.avatarMoreMinFont, round(size × GuSizes.avatarMoreFontRatio))` (T-01) |
| 24 | `quick` | `.quick` css:305 `600 12px/1.3 Inter` | Inter | 12 | 1.3 | 600 | `textHeading` |
| 25 | `tooltip` | `.tooltip` css:341 `600 11px Inter` | Inter | 11 | null | 600 | metin `bgSurface`, zemin `textHeading` |
| 26 | `mapPlaceholder` | `.map-ph` css:410 `500 12px ui-monospace,monospace` | **Inter** (mono paketlenmez, CD-19 / K-26) | 12 | null | 500 | `tabularFigures`, `textMuted` |

PLAN §7.2.1 tablosunda 26 satır vardır (`mapPlaceholder` dahil); yukarıdaki 26 satır birebir doğrulandı. **PLAN'a ek (CSS/JS'te var, planda yok — §13):**

| # | Alan | Kaynak | Font | Boyut | `height` | Ağırlık | Ek |
|---|---|---|---|---|---|---|---|
| 27 | `bannerAction` | `.banner .btn-text{color:inherit;text-decoration:underline}` css:257 (+ `.btn` yazı css:139) | Inter | 14 | 1.3 | 600 | `= button.copyWith(decoration: TextDecoration.underline)`, renk banner metniyle aynı (`inherit`) |
| 28 | `splashTitle` | screens-auth.js:33 SYS-01 `class="t-title-l" style="letter-spacing:.04em"` (kabuk splash örtüsü shell.js:35 aynı) | Montserrat | 22 | 1.2727 | 700 | `= titleL.copyWith(letterSpacing: 0.88)` (0.04em × 22); sürüm metni `caption` |
| 29 | `ticketCode` | screens-events.js:83 EVT-03 bilet kodu `class="t-title-s tnum" style="letter-spacing:.12em"` (`/// JS-derived`, K-46) | Montserrat | 16 | 1.3750 | 600 | `= titleS.copyWith(letterSpacing: 1.92, fontFeatures: [FontFeature.tabularFigures()])` (0.12em × 16; `.tnum` css:99) |
| 30 | `toastAction` | `.toast .toast-action{font-weight:700}` css:293 + `.toast` yazısı `500 calc(13px*var(--ts))/1.4 Inter` css:290 (düğme `font:inherit` css:79; shell.js:21 `<button class="toast-action">`) (`/// CSS-derived`, T-01 inceleme) | Inter | 13 | 1.4 | 700 | `= toast.copyWith(fontWeight: FontWeight.w700)`; renk `bgSurface` = `GuComponentColors.toastActionForeground` (açık `#FFF`, koyu `#1E2024` CD-98; toast widget'ı component rengini uygular); Inter 700 → 600 çizilir (K-56); `--ts` ile ölçeklenir |

Boyuta bağlı iki stil (PLAN §7.2.1 ile aynı): `avatarInitialsBase` = Montserrat 700, `fontSize = round(size × GuSizes.avatarInitialsRatio)` (art:45 `Math.round(size * 0.4)`), `letterSpacing = fontSize × 0.02` (css:217 `.02em`), renk `GuComponentColors.avatarInitials` ile aynı (`#FFF`; `GuAvatar` T-04 component rengini uygular); `avatarMore` boyutu `GuTypography.avatarMoreFor(size)` = `max(GuSizes.avatarMoreMinFont, round(size × GuSizes.avatarMoreFontRatio))` (art:50); `donutValueBase` = Montserrat 700, `fontSize = size / GuSizes.donutValueDivisor` (ui:93 `size / 4.5`), renk `textHeading`. `.code`/`.pre` (css:343–344, ui-monospace) yalnızca `DEMO_PASSWORD` mock'unda (AUT-01, K-02) → stil yazılmaz. `.statusbar` (css:114 `600 15px/1 Inter`) mock, yazılmaz (D-20). `GuTypography` alan sayısı: 11 + 26 + 4 ek (`bannerAction`, `toastAction`, `splashTitle`, `ticketCode`) + 2 taban = **43** (token testi `.t-*` 11 + bileşen seçicileri için `font:` regex'i ile okur; `bannerAction` `.btn` satırından + `text-decoration` kontrolü; `splashTitle`/`ticketCode` JS kaynaklı → sabit beklenti). `logoWordmarkBase` yazılmaz (CD-90: yalnızca amblem varyantı, yazı işareti ekranda ayrı `Text`).

## 4. Boşluk — `GuSpacing` / `GuGap` / `GuInsets` (9 + CSS türevi)

Kaynak: `reg.SPACING = [4,8,12,16,20,24,32,40,48]` (core:45) = `tj.spacing`; görsel `ds_space.webp` (4–48 kutuları). CSS yardımcı sınıfları css:101 (`.gap2 .gap4 .gap6 .gap8 .gap12 .gap16 .gap20 .gap24`), css:102 (`.p16 .px16 .py8 .py12 .py16 .pb16 .pb24 .pt8 .pt16 .p12 .p20`), css:103 (`.mt4 .mt8 .mt12 .mt16 .mt24 .mb8 .mb12 .mb16 .mb24`).

| Registry değeri | `GuSpacing` | `GuGap` (`SizedBox`) | `GuInsets` (`EdgeInsets`) | CSS kullanım kanıtı |
|---|---|---|---|---|
| 4 | `s4` | `h4` (`width: 4`), `v4` (`height: 4`) | `all4` | `.gap4` css:101, `.mt4` css:103, `.row gap` yok (8) |
| 8 | `s8` | `h8`, `v8` | `all8`, `h8`, `v8` | `.gap8` css:101, `.py8` `.pt8` css:102, `.mt8 .mb8` css:103, `.row{gap:8px}` css:100 |
| 12 | `s12` | `h12`, `v12` | `all12`, `h12`, `v12` | `.gap12` css:101, `.p12 .py12` css:102, `.mt12 .mb12` css:103 |
| 16 | `s16` | `h16`, `v16` | `all16`, `h16` (= sayfa yatay dolgusu `px16`), `v16`, `h16v8`, `h16v12` | `.gap16`, `.p16 .px16 .py16 .pb16 .pt16`, `.mt16 .mb16` css:101–103 |
| 20 | `s20` | `h20`, `v20` | `all20`, `h20v12` | `.gap20` css:101, `.p20` css:102 |
| 24 | `s24` | `h24`, `v24` | `all24`, `h24` | `.gap24` css:101, `.pb24` css:102, `.mt24 .mb24` css:103 |
| 32 | `s32` | `h32`, `v32` | `all32` | `.empty{padding:32px 24px}` css:300, `.onb-track>section{padding:0 32px}` css:393 |
| 40 | `s40` | `h40`, `v40` | — | `.notif-icon` 40 css:405 (ölçü), splash sürüm `bottom:40px` screens-auth.js:33 |
| 48 | `s48` | `h48`, `v48` | — | `.btn/.input/.iconbtn/.tabs>button` 48 (ölçüler `GuSizes`'ta) |

CSS türevi (`/// CSS-derived`; token testi `.gap(\d+)\{gap:(\d+)px\}` ile okur):

| Sabit | Değer | Kaynak | Durum |
|---|---|---|---|
| `GuSpacing.s2` | 2 | `.gap2{gap:2px}` css:101; kullanım `css-class-usage.json` 6 ekran / 43 | doğrulandı |
| `GuSpacing.s6` | 6 | `.gap6{gap:6px}` css:101; 23 ekran / 313 | doğrulandı |
| `GuSpacing.s10` | yazılmaz | PLAN §7.3 `.gap10` der; **CSS'te `.gap10` kuralı yok** (css:101'de yok, `core.js` CSS'inde de yok). JS'de `gap10` 5 ekranda 32 kez kullanılır (`css-class-usage.json`: FED-01, FED-02, FED-03, SET-04, ADM-01; ayrıca cards.js ×3, sheets.js ×3, dialogs.js ×1, shell.js ×1). Tarayıcıda etkisizdir: `.row gap10` → 8 px (`.row{gap:8px}` css:100), `.col gap10` → 0 px. Aynı durumda `pb8` (ADM-05, SHT-25, SHT-30) ve `pt24` (CLB-07 `screens-clubs.js:158`) — hiçbiri CSS'te tanımlı değil | **CD-99, K-42:** referans görüntüyle 1:1 — `s10` yazılmaz; `.row gap10` → `GuSpacing.s8`, `.col gap10` → boşluk yok, `pb8`/`pt24` → dolgu yok; token testi CSS-derived boşluk grubunu 2 değerle (`s2`, `s6`) doğrular; PLAN §7.3 addendum Faz 1 commit'inde |

Bileşen içi dolgular (3, 6, 10, 14) `GuSizes`'tadır (§8). `GuInsets.sym({double h, double v})` / `GuInsets.only({double left = 0, double top = 0, double right = 0, double bottom = 0})` yalnızca `GuSpacing`/`GuSizes` sabitleriyle çağrılır (HC04 tanımlayıcı içindeki rakamı literal saymaz). `hscroll` = yatay liste `padding: GuInsets.h16` + ayraç `GuGap.h8` + dikey `GuSizes.hscrollPaddingY` (css:105 `padding:3px 16px; gap:8px`).

## 5. Radius — `GuRadius` (5 + 9 CSS türevi)

Kaynak: `reg.RADIUS = {sm:12, md:16, lg:20, xl:28, full:999}` (core:46), CSS css:31–35; görsel `ds_space.webp` (`r.sm 12 – r.full 999`).

| Registry | `GuRadius` double | `BorderRadius` sabiti | CSS kullanımı (satır) |
|---|---|---|---|
| `sm` 12 | `sm` | `borderSm` | `.btn` 139, `.input` 163, `.picker` 173, `.seg` 220, `.toast` 290, `.cal-day` 314, `.date-badge` 318, `.quick-icon` 306, `.emblem.is-sm` 399, `.poll-opt` 328, `.map-ph` 410, `.qr` 326, PostCard aksiyon düğmesi cards:124 (`border-radius:12px`), `.panel`/`.account-row` (mock) |
| `md` 16 | `md` | `borderMd` | `.option-card` 245, `.banner.is-card` 249, `.popmenu` 279, `.quick` 305, `.fab` 158 |
| `lg` 20 | `lg` | `borderLg` | `.card` 203, `.dialog` 282, `.ticket` 323, `.emblem` 398 |
| `xl` 28 | `xl` | `borderXl`, `topXl` (`BorderRadius.vertical(top: Radius.circular(28))`) | `.sheet{border-radius:var(--r-xl) var(--r-xl) 0 0}` 268 |
| `full` 999 | `full` | `borderFull` | `.iconbtn` 154, `.badge` 188, `.avatar` (`50%`) 217, `.switch` (13 = yükseklik/2) 231, `.notif-icon` (`50%`) 405, `.sk.circle` 264, `.dot` 201, `.radio` 238, `.timeline-dot` 310 |

CSS türevi (`/// CSS-derived`; test `border-radius:(\d+)px` kümesinden):

| Sabit | Değer | Kaynak |
|---|---|---|
| `chip` | 10 | `.chip` css:176, `.seg>button` css:221, `.popmenu .tile` css:280 |
| `emblemXs` | 9 | `.emblem.is-xs` css:400 |
| `skeleton` | 8 | `.sk` css:263, `.toast-action` css:293 |
| `checkbox` | 6 | `.check` css:238, `:focus-visible` css:82, `.tooltip` css:341, `.code` css:343 (mock) |
| `scanCorner` | 4 | `.scan-box>i` css:403, `.dots>i` css:394 (8 px nokta → 4) |
| `progress` | 3 | `.prog`/`.prog>i` css:259–260, nav göstergesi `0 0 3px 3px` css:136 → `navIndicator = BorderRadius.vertical(bottom: Radius.circular(3))` |
| `handle` | 2 | `.sheet-handle` css:271, `.stepbar>i` css:320, sekme göstergesi `2px 2px 0 0` css:228 → `tabIndicator = BorderRadius.vertical(top: Radius.circular(2))` |
| `imageGrid` | 14 | `.img-grid` css:407 |
| `switchTrack` | 13 | `.switch` css:231 (`= switchHeight / 2`) |

`.nav-badge`/`.dot-badge`/`.chip-count` 9 = `countBadge` yüksekliği 18 / 2 ve `.badge-count` 10 = 20 / 2 → ayrı sabit yazılmaz, `borderFull` kullanılır (görsel eşdeğer). `.cover` oranlı kutular kart içinde `overflow:hidden` ile kırpılır (css:203), kendi yarıçapı yoktur.

## 6. Gölgeler — `GuShadows` (`ThemeExtension`; 4 + 3 CSS türevi)

Kaynak: `reg.SHADOWS` (core:47), CSS css:36–39 (açık), css:74 (koyu `--e1: none; --e2: none; --e3: none`); görsel `ds_space.webp` (e0–e3, koyu temada düz). Dönüşüm: CSS `x y blur rgba(r,g,b,a)` → `BoxShadow(offset: Offset(x, y), blurRadius: GuShadows.cssBlurToRadius(blur), spreadRadius: 0, color: Color(0xAA101828))`. CSS `box-shadow` bulanıklığı Gauss σ = `blur / 2` çizer; Flutter `blurRadius` r'yi σ = `r × 0.57735 + 0.5`'e çevirir (`Shadow.convertRadiusToSigma`) → aynı σ için `r = (blur / 2 − 0.5) / 0.57735` (σ ≤ 0.5 → 0). CSS blur değeri doğrudan `blurRadius` yazılmaz (12 → σ 7.43 ≠ 6). `const` gölgeler formülü CSS değeri okunur kalacak biçimde yazar (`(12 / 2 - _sigmaOffset) / _sigmaScale`); token testi her katmanda `Shadow.convertRadiusToSigma(blurRadius) == blur / 2` doğrular. Tablolardaki `cssBlurToRadius(N)` = `GuShadows.cssBlurToRadius(N)` (N = CSS blur; Flutter değeri 2 → 0.8660, 3 → 1.7321, 12 → 9.5263, 16 → 12.9904, 32 → 26.8468).

| Registry | Alan | Açık (`List<BoxShadow>`) | Koyu | Kaynak |
|---|---|---|---|---|
| `e0` `none` | `e0` | `const []` | `const []` | css:36 |
| `e1` | `e1` | `[BoxShadow(offset: Offset(0, 1), blurRadius: cssBlurToRadius(2), color: Color(0x0F101828)), BoxShadow(offset: Offset(0, 1), blurRadius: cssBlurToRadius(3), color: Color(0x14101828))]` (.06 → 0x0F, .08 → 0x14) | `const []` | css:37 / css:74 |
| `e2` | `e2` | `[BoxShadow(offset: Offset(0, 4), blurRadius: cssBlurToRadius(12), color: Color(0x1A101828))]` (.10 → 0x1A) | `const []` | css:38 / css:74 |
| `e3` | `e3` | `[BoxShadow(offset: Offset(0, -8), blurRadius: cssBlurToRadius(32), color: Color(0x29101828))]` (.16 → 0x29) | `const []` | css:39 / css:74 |

Kullanım (CSS): `e1` `.card` css:203, `.seg` seçili css:222; `e2` `.fab` css:158, `.popmenu` css:279, `.dialog` css:282, `.toast` css:290, `.emblem` css:398; `e3` `.sheet` css:268.

### 6.1 CSS türevi (`/// CSS-derived`; `GuShadows` 3 alan: `ctaBar`, `fab`, `switchThumb`)

| Alan | Açık | Koyu | Kaynak |
|---|---|---|---|
| `ctaBar` | `[BoxShadow(offset: Offset(0, -4), blurRadius: cssBlurToRadius(16), color: Color(0x0F101828))]` | `const []` | `.ctabar` css:296 / css:299 `box-shadow:none` |
| `fab` | `= e2` | `[BoxShadow(offset: Offset(0, 4), blurRadius: cssBlurToRadius(16), color: Color(0x66000000))]` (.4 → 0x66) | css:158 / css:159 |
| `switchThumb` | `[BoxShadow(offset: Offset(0, 1), blurRadius: cssBlurToRadius(2), color: Color(0x33000000))]` (.2 → 0x33) | aynı | `.switch>i` css:234 |

`lerp`: `BoxShadow.lerpList(a, b, t) ?? const []`. Kullanım: `context.gu.shadows.e1`.

### 6.2 Token olmayan türevler (`GuShadows`'a girmez; Faz 1 inceleme notu)

Renk tema token'ına bağlı olduğu için `GuShadows` alanı olmaz; ilgili widget `context.gu.colors.*` + `GuSizes` ile kurar (token testi yalnızca `GuSizes` değerlerini doğrular). Bulanıklığı olan türevler `blurRadius`'u widget'ta `GuShadows.cssBlurToRadius(<CSS blur>)` ile verir (ör. `scanLineGlow`: `cssBlurToRadius(GuSizes.scanLineGlow)`); blur 0 olanlar (`timelineDotRing`, `highlight` halkası) dönüşüm gerektirmez.

| Alan | Açık | Koyu | Kaynak |
|---|---|---|---|
| `scanLineGlow` | `[BoxShadow(blurRadius: GuShadows.cssBlurToRadius(12), color: brandPrimary)]` (renk tema token'ı → `GuShadows` değil, `ScanOverlay` içinde `context.gu.colors.brandPrimary` + `GuSizes.scanLineGlow 12`) | aynı | `.scanline{box-shadow:0 0 12px var(--brand-primary)}` css:335 |
| `timelineDotRing` | halka = `BoxShadow(spreadRadius: 2, color: <durum rengi>)` (blur 0) — renk token'ı duruma bağlı (`borderDefault` / `stateSuccess` / `brandPrimary` / `stateDanger`) → `GuTimelineDot` içinde `context.gu.colors.*` + `GuSizes.timelineDotRing 2` | aynı | css:310–311 `box-shadow:0 0 0 2px –` |
| `calendarTodayRing` | `inset 0 0 0 2px brandPrimary` → Flutter `Border.all(width: GuSizes.calendarTodayRing, color: brandPrimary)` (inset gölge yerine kenarlık) | aynı | `.cal-day.is-today` css:315 |
| `highlight` | `0 0 0 3px brandPrimary` → `e1` (1.5 s) → `GuCard.highlight` `TweenSequence<List<BoxShadow>>`; `GuSizes.highlightRingWidth 3` | koyu: halka → `[]` | `@keyframes highlight` css:426 |

## 7. Hareket — `GuMotion` (5 + keyframe türevleri + toast)

Kaynak: `reg.MOTION = {fast:120, base:200, slow:320, easeStandard:'cubic-bezier(.2,0,0,1)', easeEmphasized:'cubic-bezier(.3,0,0,1)'}` (core:48), CSS css:40–44; görsel `ds_motion.webp` ("fast: 120ms · base: 200ms · slow: 320ms · easeStandard · easeEmphasized; prefers-reduced-motion: yalnızca solma").

| Registry | `GuMotion` | Dart | Kullanım (CSS satırı) |
|---|---|---|---|
| `fast` 120 | `fast` | `Duration(milliseconds: 120)` | `.btn` transition css:139, `.iconbtn` 154, `.input` border/bg 163, `.chip` 176, `.seg>button` 221, `.tabs>button` 226, `.bottomnav>button` 134, `.check/.radio` 237, `.card.is-tappable` 206, `.pressable` 340 |
| `base` 200 | `base` | `Duration(milliseconds: 200)` | `pushIn/popIn/fadeIn` ekran css:121, `.scrim` 267, `.popmenu`/`.dialog` `dialogIn` 279/282, `.switch` 231/234, `.dots>i` 394, `.notif-front` 339, `.viewer` 409, yenile göstergesi `height .2s` ui:162, ok dönüşü `transform .2s` ui:162, azaltılmış harekette tüm overlay `fadeIn` css:427 |
| `slow` 320 | `slow` | `Duration(milliseconds: 320)` | `.sheet` `sheetIn` css:268, `.toast` `toastIn` 290, `.heart.is-liked` `pop` 331, `.check-draw` 332, `.prog>i` width 260, `.drawer` (mock) 388 |
| `easeStandard` | `easeStandard` | `Cubic(0.2, 0, 0, 1)` | `--ease-standard`'ı **açıkça yazan** kurallar (CSS varsayılanı değil): ekran geçişi css:121, `.popmenu`/`.dialog` 279/282, switch **topuzu** `.switch>i` 234, `.prog>i` 260, `.poll-fill` 329, draw 332–333, shake 334, `.notif-front` 339, highlight 208, splashOut 425 |
| `easeEmphasized` | `easeEmphasized` | `Cubic(0.3, 0, 0, 1)` | `.sheet` 268, `.toast` 290, `.heart` 331, `.splash .logo` 392, SHT-34 yakınlaştırma sheets.js:161 |
| — (CSS `ease`) | `easeCss` (`/// CSS-derived`) | `Cubic(0.25, 0.1, 0.25, 1)` (= `Curves.ease`) | zamanlama fonksiyonu **yazılmamış** `transition`/`animation` = CSS anahtar kelimesi `ease`: css:134 (`.bottomnav>button`), 139 (`.btn`), 154 (`.iconbtn`), 163 (`.input`), 176 (`.chip`), 206 (`.card.is-tappable`), 221 (`.seg>button`), 226 (`.tabs>button`), 231 (switch **rayı** `.switch`), 237 (`.check/.radio`), 267 (`.scrim` fadeIn), 340 (`.pressable`), 394 (`.dots>i`), 409 (`.viewer` fadeIn), 427 (azaltılmış hareket fadeIn); JS ui.js:162 ×2 (yenile göstergesi `height .2s`, ok `transform .2s`), screens-manage.js:57 (`opacity .25s, transform .25s`). Token testi CSS'teki tüm `transition`/`animation` bildirimlerini ve prototip JS `transition:` dizgelerini tarar; liste değişirse kırmızı |

### 7.1 CSS keyframe/JS türevleri (`/// CSS-derived`; test `@keyframes`/`animation:` satırlarından)

| Sabit | Değer | Kaynak |
|---|---|---|
| `spin` | 800 ms, `Curves.linear`, sonsuz | `.spinner{animation:spin .8s linear infinite}` css:153; `@keyframes spin` css:418 |
| `shimmer` | 1200 ms, linear, sonsuz; gradyan `90deg` %25/%50/%75 durakları `bgSurfaceMuted/borderSoft/bgSurfaceMuted`, `background-size 200%` | `.sk` css:263; `@keyframes shimmer` css:417 |
| `circleDraw` | 500 ms, standard, `forwards` (dasharray 200) | `.circle-draw` css:333 |
| `checkDraw` | `= slow` (320), gecikme `checkDrawDelay = 200` ms (dasharray 60) | `.check-draw{animation:draw var(--motion-slow) .2s –}` css:332 |
| `shake` | 400 ms, standard; `translateX` −8/+8/−5/+5 → `shakeOffsets = [0, -8, 8, -5, 5, 0]` (`GuMotion.shakeOffsets` tek kaynak; ayrı `GuSizes` sabiti yok — T-01) | `.shake` css:334; `@keyframes shake` css:421; JS sıfırlama 450 ms ui:112 (CSS 400 esastır) |
| `scan` | 2200 ms, `Curves.easeInOut`, sonsuz, `top 8% ↔ 90%` | `.scanline` css:335; `@keyframes scan` css:422 |
| `splash` | 1200 ms, emphasized; `scale .7 → 1.05 (%60) → 1`, opaklık 0 → 1 | `.splash .logo` css:392; `@keyframes splash` css:423; shell.js:74 `GU.splashUntil = Date.now() + 1200` |
| `splashStartScale` / `splashPeakScale` / `splashPeakAt` (**ek**, T-11) | 0.7 / 1.05 / 0.6 (tepe karesi %60; opaklık %0 → %60 arası 0 → 1) | `@keyframes splash{0%{opacity:0;transform:scale(.7)}60%{opacity:1;transform:scale(1.05)}100%{transform:scale(1)}}` css:423 — SYS-01 `SplashView` logo animasyonu |
| `splashOut` | 300 ms, gecikme `splashOutDelay = 1300` ms, standard | `.splash-overlay{animation:splashOut .3s 1.3s –}` css:425 |
| `highlight` | 1500 ms, standard | `.card.is-highlight` css:208; `@keyframes highlight` css:426 |
| `fill` | 600 ms, standard (anket dolumu + donut dasharray) | `.poll-opt .poll-fill{transition:width .6s}` css:329; `Donut` `transition:stroke-dasharray .6s` ui:93 |
| `pressScale` | 0.98 | `.btn:active` css:140, `.pressable:active` css:340 |
| `cardPressScale` | 0.99 | `.card.is-tappable:active` css:206 |
| `heartPopScale` | 1.35 (%40'ta) | `@keyframes pop` css:419 |
| `dialogEnterScale` | 0.96 | `@keyframes dialogIn` css:415 |
| `toastEnterOffsetY` | 24 | `@keyframes toastIn` css:416 |
| `pushEnterOffsetX` | 16 (`popIn` −16) | `@keyframes pushIn/popIn` css:412–413 — yalnızca `navigation.md §5` `fade` istisnaları; platform geçişi D-06 |
| `sheetEnter` | `translateY(100%) → 0`, `slow` + emphasized | `@keyframes sheetIn` css:414 |
| `toastDefault` | 4000 ms | core:567 `props.undo \|\| props.action ? 6000 : 4000` (CD-24; CLAUDE.md §7) |
| `toastUndo` | 6000 ms | core:567 (aksiyonlu/geri al'lı) |
| `refreshSettle` → `GuMotion.base` (ayrı sabit yazılmaz) | 200 ms + `easeCss` (yenileme bitince gösterge yüksekliği 48 → 0; ok dönüşü `transform .2s` aynı) | ui:162 `transition: refreshing ? 'height .2s' : 'none'` |
| `AppDurations.qrSuccessAutoClose` (`GuMotion` dışı) | `Duration(seconds: 2)` (SHT-24 `valid` sonucu kendiliğinden kapanır) | sheets:114 `setTimeout(close, 2000)` → `lib/core/constants/app_durations.dart` (dosya T-26'da açılır, sabit T-35'te eklenir; PLAN §4.4, CD-24, CD-58 kalıbı); `sheet_timings.dart` yazılmaz |
| `countdownTick` (**ek**, CD-97) | 1000 ms (`Duration(seconds: 1)`) | core.js:658 `useCountdown` `setInterval(() => tick((x) => x + 1), 1000)`; `GuCountdown.tick` varsayılanı (CD-96) |
| `longPress` (**ek**, `/// JS-derived`, K-46) | 550 ms | cards:144 `setTimeout(() => { setMenu(true); moved.current = true; }, 550)` (bildirim satırı uzun basma menüsü) |
| `heartPopReset` (**ek**, `/// JS-derived`, K-46) | 400 ms | cards:100 `setTimeout(() => setPopped(false), 400)` (beğeni kalbi animasyon sıfırlama) |
| `applicationLeave` (**ek**, `/// JS-derived`, K-46) | 250 ms, `easeCss`; kayma `GuSizes.applicationLeaveOffsetX` 40 | screens-manage.js:48 onay sonrası `setTimeout` 250 ms + :57 `transition: 'opacity .25s, transform .25s'`, `translateX(40px)` (MGT-02 başvuru satırı çıkışı) |
| `viewerDoubleTap` (**ek**, `/// JS-derived`, K-46) | 300 ms | sheets:159 `if (now - lastTap.current < 300) setZoom(!zoom)` (SHT-34 çift dokunma yakınlaştırma) |
| `viewerZoom` (**ek**, `/// JS-derived`, K-46) | 300 ms, `easeEmphasized`; ölçek `GuSizes.viewerZoomScale` 1.8 | sheets:161 `transform: zoom && k === i ? 'scale(1.8)' : 'none', transition: 'transform .3s var(--ease-emphasized)'` (SHT-34 yakınlaştırma geçişi). Aynı anlamda mevcut 300 ms'lik süre yok: `splashOut` (css:425 splash örtüsü) ve `viewerDoubleTap` (dokunma eşiği) farklı kavramlar → ayrı sabit |

Prototipe özgü sahte gecikmeler (**sabit yazılmaz**): yeniden dene 800 ms ui:106, yenileme 700 ms ui:160, `useBusy` çağrıları. Azaltılmış hareket: `context.gu.duration(d)` → `MediaQuery.disableAnimationsOf` ise `Duration.zero`; sürekli animasyonlar (`spin`, `shimmer`, `scan`) durur; overlay giriş animasyonu yalnızca solma (css:427 `prefers-reduced-motion` kuralı: `.screen/.sheet/.dialog/.toast → fadeIn base`, `.sk → none`). İş süreleri (`lockedUntil` 30 s dialogs.js:20, 60 s kilit, 7 gün) `Limits`'tedir (`gu_data`).

## 8. Boyutlar — `GuSizes` (CSS/JS'ten ölçülen; görsel ölçü, dokunma alanı `GuTapTarget` ile ≥ 44/48, D-22/K-03)

Ad kuralı `<bileşen><Özellik>[<Varyant>]`, `static const double`. Her satır **ad → değer → kaynak**. Token testi `test/helpers/css_measure.dart` ile `cssValue(seçici, özellik)` okur; JS kaynaklı satırlar sabit beklentiyle test edilir. PLAN §7.7'deki tüm sabitler doğrulandı; işaretli (**ek**) satırlar PLAN'da olmayıp CSS/JS'te bulunanlardır (§13).

### 8.1 Uygulama çubuğu, alt sekme, yapışkan CTA (`ds_nav.webp`)

| Sabit | Değer | Kaynak |
|---|---|---|
| `appBarMinHeight` | 56 | `.appbar{min-height:56px}` css:127 |
| `appBarPaddingY` / `appBarPaddingX` / `appBarGap` | 4 / 8 / 4 | `.appbar{padding:4px 8px;gap:4px}` css:127 |
| `appBarTitlePaddingX` | 8 | `.appbar-title{padding:0 8px}` css:129 |
| `appBarLargePaddingTop` / `appBarLargePaddingX` / `appBarLargePaddingBottom` | 8 / 16 / 12 | `.appbar-large{padding:8px 16px 12px}` css:130 |
| `appBarBorder` | 1 | `.appbar.is-surface{border-bottom:1px solid var(--border-soft)}` css:128 |
| `bottomNavHeight` | 56 | `.bottomnav>button{min-height:56px}` css:134 (`--nav-h:84` = 56 + mock `--safe-bottom:28` css:77; gerçek `viewPadding.bottom`, K-07) |
| `bottomNavGap` / `bottomNavIcon` / `bottomNavBorder` | 3 / 24 / 1 | css:134 `gap:3px`; shell:12 `Icon size=24`; css:133 `border-top:1px` |
| `bottomNavIndicatorWidth` / `bottomNavIndicatorHeight` | 28 / 3 | `::before{width:28px;height:3px}` css:136 |
| `navBadgeMinWidth` / `navBadgeHeight` / `navBadgePaddingX` / `navBadgeBorder` / `navBadgeTop` / `navBadgeOffsetX` | 18 / 18 / 5 / 2 / 6 / 4 | `.nav-badge{top:6px;left:calc(50% + 4px);min-width:18px;height:18px;padding:0 5px;border:2px solid}` css:137 |
| `ctaBarPaddingY` / `ctaBarPaddingX` / `ctaBarGap` / `ctaBarBorder` | 12 / 16 / 12 / 1 | `.ctabar{padding:12px 16px calc(12px + safe);gap:12px;border-top:1px}` css:296; `.in-nav{padding-bottom:12px}` css:297 |

### 8.2 Düğmeler (`ds_buttons.webp`)

| Sabit | Değer | Kaynak |
|---|---|---|
| `buttonHeight` / `buttonHeightSm` / `buttonHeightLg` | 48 / 40 / 56 | `.btn{min-height:48px}` css:139; `.btn-sm{min-height:40px}` `.btn-lg{min-height:56px}` css:141 (min-height, K-08) |
| `buttonPaddingX` / `buttonPaddingXSm` / `buttonPaddingXLg` | 20 / 14 / 24 | css:139 `padding:0 20px`; css:141 `0 14px` / `0 24px` |
| `buttonGap` | 8 | css:139 `gap:8px` |
| `buttonIcon` / `buttonIconSm` / `buttonIconTrailing` | 20 / 18 / 18 | ui:14 `size=${size === 'sm' ? 18 : 20}`, `iconRight` 18 |
| `buttonBorder` | 1 | `.btn-outline` css:144, `.btn-danger-outline` css:146 |
| `textButtonHeight` / `textButtonPaddingX` | 44 / 12 | `.btn-text{padding:0 12px;min-height:44px}` css:145 |
| `ghostButtonPaddingX` | 12 | `.btn-ghost{padding:0 12px}` css:148 (ONB-01, AUT-01, AUT-02 kullanır — `css-class-usage.json` 3 ekran) |
| `bannerTextButtonHeight` / `bannerTextButtonPaddingX` | 36 / 10 | `.banner .btn-text{min-height:36px;padding:0 10px}` css:257 |
| `spinner` / `spinnerStroke` | 20 / 2.5 | `.spinner{width:20px;height:20px;border:2.5px solid currentColor;border-right-color:transparent}` css:153 (270° yay); `.btn .spinner` merkezde `margin:-10px 0 0 -10px` css:152 (= −spinner/2, ayrı sabit yok) |
| `focusRingWidth` / `focusRingOffset` | 2 / 2 | `:focus-visible{outline:2px solid var(--focus-ring);outline-offset:2px}` css:82; `.btn.is-focus` css:150 |
| `iconButton` / `iconButtonSm` / `iconButtonXs` / `iconButtonIcon` | 48 / 40 / 32 / 24 | `.iconbtn{width:48px;height:48px}` css:154; `.is-sm` 40 css:156; toast kapat `width:32px;height:32px` + ikon 16 shell:21; ui:17 `size = 24` |
| `dotBadgeTop` / `dotBadgeRight` / `dotBadgeMinWidth` / `dotBadgeHeight` / `dotBadgePaddingX` | 8 / 8 / 18 / 18 / 5 | `.iconbtn .dot-badge{top:8px;right:8px;min-width:18px;height:18px;padding:0 5px}` css:157 |
| `onCoverBlur` | 6 | `.iconbtn.on-cover{backdrop-filter:blur(6px)}` css:155 (`BackdropFilter` sigma 6) |
| `fabHeight` / `fabPaddingLeft` / `fabPaddingRight` / `fabGap` / `fabMargin` | 56 / 16 / 20 / 8 / 16 | `.fab{right:16px;bottom:calc(safe + 16px);height:56px;padding:0 20px 0 16px;gap:8px}` css:158 (radius `GuRadius.md`) |
| `quickPaddingY` / `quickPaddingX` / `quickGap` / `quickIconBox` / `quickIcon` / `quickBorder` | 14 / 8 / 8 / 40 / 20 / 1 | `.quick{padding:14px 8px;gap:8px;border:1px}` css:305; `.quick-icon{width:40px;height:40px}` css:306; ui:128 `Icon size=20` |

### 8.3 Girdiler (`ds_inputs.webp`, `ds_selection.webp`)

| Sabit | Değer | Kaynak |
|---|---|---|
| `fieldGap` | 6 | `.field{gap:6px}` css:161 |
| `inputHeight` / `inputPaddingX` / `inputGap` / `inputBorder` | 48 / 14 / 8 / 1 | `.input{min-height:48px;padding:0 14px;gap:8px;border:1px solid transparent}` css:163 |
| `inputMultilinePaddingY` / `textareaMinHeight` / `textareaRows` | 12 / 88 / 4 | `.input.is-multiline{padding:12px 14px}` `.input textarea{min-height:88px}` css:169; ui:29 `rows \|\| 4` |
| `inputIcon` / `inputLockIcon` / `fieldHelpIcon` / `fieldHelpGap` | 20 / 18 / 14 / 4 | ui:28 `in-icon size=20`; ui:30 `lock size=18`; ui:33 `triangle-alert size=14`; `.field-help{gap:4px}` css:171 |
| `counterThresholdRatio` | 0.8 | ui:23 `Math.floor(maxLength * 0.8)` |
| `pickerHeight` / `pickerPaddingX` / `pickerChevron` | 48 / 14 / 20 | `.picker{min-height:48px;padding:0 14px}` css:173; ui:39 `chevron-down size=20` |
| `switchWidth` / `switchHeight` / `switchThumb` / `switchThumbInset` / `switchThumbTravel` | 44 / 26 / 20 / 3 / 18 | `.switch{width:44px;height:26px}` css:231; `>i{top:3px;left:3px;width:20px;height:20px}` css:234; `translateX(18px)` css:235 |
| `switchHitInsetY` / `switchHitInsetX` | 11 / 4 | `.switch::after{inset:-11px -4px}` css:232 (→ `GuTapTarget`: 44×26 + 2×(4,11) = 52×48) |
| `checkbox` / `checkboxBorder` / `checkboxIcon` / `radioDot` / `checkHitInset` | 22 / 2 / 16 / 12 / 13 | `.check,.radio{width:22px;height:22px;border:2px}` css:237; ui:46 `check size=16 stroke=3` (K-24); `.radio>i{width:12px}` css:241; `::after{inset:-13px}` css:239 (→ 48×48) |
| `optionRowMinHeight` / `optionRowPaddingY` / `optionRowPaddingX` / `optionRowGap` | 52 / 6 / 16 / 12 | `.option-row{min-height:52px;padding:6px 16px;gap:12px}` css:243; devre dışı opaklık .5 satır içi stil ui:49 |
| `optionCardPaddingY` / `optionCardPaddingX` / `optionCardGap` / `optionCardBorder` | 14 / 16 / 12 / 1 | `.option-card{padding:14px 16px;gap:12px;border:1px}` css:245 (radius `md`; seçili css:246) |
| `segmentPadding` / `segmentGap` / `segmentHeight` / `segmentPaddingX` / `segmentItemGap` / `segmentIcon` | 3 / 2 / 40 / 8 / 6 / 16 | `.seg{padding:3px;gap:2px}` css:220; `.seg>button{min-height:40px;padding:0 8px;gap:6px}` css:221; ui:59 `size=16` |
| `tabHeight` / `tabPaddingX` / `tabPaddingXScroll` / `tabGap` / `tabIcon` / `tabIndicatorHeight` / `tabIndicatorInset` / `tabBorder` | 48 / 8 / 16 / 6 / 16 / 2 / 16 / 1 | `.tabs>button{min-height:48px;padding:0 8px;gap:6px}` css:226; `.is-scroll>button{padding:0 16px}` css:229; ui:62 `size=16`; `::after{left:16px;right:16px;height:2px}` css:228; `.tabs{border-bottom:1px}` css:224 |
| `tabIndicatorBottomOverlap` (**ek**) | 1 | `::after{bottom:-1px}` css:228 — gösterge alt kenarlığın üstüne 1 px biner |
| `stepbarGap` / `stepbarHeight` | 6 / 4 | `.stepbar{gap:6px}` `>i{height:4px}` css:320 |
| `wheelHeight` / `wheelItemHeight` / `wheelMaskStart` / `wheelMaskEnd` | 160 / 40 / 0.3 / 0.7 | `.wheel{height:160px;mask-image:linear-gradient(transparent,#000 30%,#000 70%,transparent)}` css:321; `>button{height:40px}` css:322 |
| `wheelSpacer` / `wheelSelectionBorder` (**ek**) | 60 / 1 | sheets:138 üst/alt `height:60px` boşluk (= (160 − 40) / 2); seçim çizgileri `top:50%; height:40px; border-top/bottom 1px borderDefault` sheets:140 |

### 8.4 Çip, rozet, nokta (`ds_badges.webp`, `ds_selection.webp`)

| Sabit | Değer | Kaynak |
|---|---|---|
| `chipHeight` / `chipPaddingX` / `chipGap` / `chipBorder` / `chipIcon` / `chipRemoveIcon` / `chipHitInset` | 38 / 14 / 6 / 1 / 16 / 14 / 6 | `.chip{min-height:38px;padding:0 14px;gap:6px;border:1px}` css:176; ui:55 `size=16`; ui:56 `x size=14`; `.chip::after{inset:-6px}` css:179 |
| `chipRemoveMarginRight` (**ek**) | −4 | ui:56 `style="margin-right:-4px"` (kaldır ikonu sağ dolguyu daraltır) |
| `chipCountMinWidth` / `chipCountHeight` / `chipCountPaddingX` | 18 / 18 / 5 | `.chip .chip-count{min-width:18px;height:18px;padding:0 5px}` css:186 |
| `badgeHeight` / `badgePaddingX` / `badgeGap` / `badgeIcon` / `badgeBorder` | 22 / 8 / 4 / 12 / 1 | `.badge{height:22px;padding:0 8px;gap:4px}` css:188; ui:66–68 `size=12 stroke=2.2` (K-24); `.badge-board{border:1px}` css:190 |
| `countBadgeMinWidth` / `countBadgeHeight` / `countBadgePaddingX` | 20 / 20 / 6 | `.badge-count{min-width:20px;height:20px;padding:0 6px}` css:200 |
| `dot` | 8 | `.dot{width:8px;height:8px}` css:201 |
| `hitInset` | 6 | `.hit::after{inset:-6px}` css:107 |

### 8.5 Kart, satır, avatar, görsel bileşenler (`ds_cards.webp`, `ds_special.webp`, `ds_feedback.webp`)

| Sabit | Değer | Kaynak |
|---|---|---|
| `cardBorder` / `cardBodyPadding` / `highlightRingWidth` | 1 / 16 / 3 | `.card{border:1px}` css:203; `.card-body{padding:16px}` css:207; `@keyframes highlight{0 0 0 3px}` css:426 |
| `tileMinHeight` / `tilePaddingY` / `tilePaddingX` / `tileGap` / `tileInCardPaddingY` / `tileChevron` | 56 / 8 / 16 / 12 / 10 / 20 | `.tile{min-height:56px;padding:8px 16px;gap:12px}` css:211; `.tile.in-card{padding:10px 16px}` css:214; ui:75 `chevron-right size=20`; `.trailing{gap:4px}` css:212 (= `s4`) |
| `groupHeadPaddingTop` / `groupHeadPaddingX` / `groupHeadPaddingBottom` | 12 / 16 / 6 | `.group-head{padding:12px 16px 6px}` css:215 (sticky) |
| `sectionTitleMarginTop` / `sectionTitleMarginBottom` / `sectionTitleFirstMarginTop` / `sectionTitleGap` | 24 / 12 / 8 / 8 | `.section-title{gap:8px;padding:0 16px;margin:24px 0 12px}` css:108; `:first-child{margin-top:8px}` css:109 |
| `divider` | 1 | `.divider{height:1px}` css:106 |
| `avatar` (varsayılan) | 40 | art:43 `size = 40` |
| `avatarSizes` (liste) | 30, 32, 36, 40, 44, 48, 56, 96, 120 | prototip `Avatar size=` dağılımı (bundle/pages hariç 26 çağrı: 30×1, 32×5, 36×6, 40×5(+2 varsayılan), 44×1, 48×1, 56×1, 96×3, 120×1) — `double` parametre, test kümeyi doğrular |
| `avatarGroupSize` / `avatarGroupOverlap` / `avatarGroupBorder` / `avatarGroupMax` / `avatarMorePaddingX` / `avatarMoreMinFont` / `avatarMoreFontRatio` | 28 / 8 / 2 / 4 / 6 / 10 / 0.38 | art:48 `size = 28, max = 4`; `.avatar-group .avatar{border:2px;margin-left:-8px}` css:218; `.more` `padding 0 6px; fontSize max(10, round(size×.38))` art:50; kullanılan boyut kümesi `avatarGroupSizes` satırında (K-47) |
| `avatarGroupSizes` (liste, **ek**, K-47) | 24, 28, 32 | cards:38 ClubCard `size=${24}`; screens-clubs.js:92 CLB-03 `size=${28}`; screens-events.js:69 EVT-02 (`EVT-02.attendeesPreview`) `size=${32}` — `GuAvatarGroup.size` varsayılanı 28, test kümeyi doğrular |
| `avatarInitialsRatio` | 0.4 | art:45 `Math.round(size * 0.4)` |
| `emblem` / `emblemSm` / `emblemXs` / `emblemBorder` | 72 / 44 / 32 / 1 | `.emblem{width:72px;border:1px}` css:398; `.is-sm` 44 css:399; `.is-xs` 32 css:400 (kullanım 6 / 22 / 14) |
| `emblemIconSizes` (liste, **ek**, PLAN'da yok) | 16, 20, 22 | cards:31 `is-xs` içinde `size=16`; sheets:88 `is-sm` içinde `size=20`; cards:36 `is-sm` içinde `size=22` → `GuEmblem` ikon boyutunu çağıran verir, test kümeyi doğrular |
| `logoSizes` (liste) | 20, 72, 80, 96 | `Logo size=` ekran kullanımları: screens-clubs.js:210 FED-03 bildirim önizlemesi 20 (`emblem is-xs` içinde), screens-auth.js:68 AUT-01 72, screens-profile.js:99 SET-04 80, screens-auth.js:33 SYS-01 96 (+ shell.js:35 kabuk splash 96); PLAN'daki 32 = shell.js:52 `SideMenu` (prototip site menüsü maketi) → kümeden çıkar; `GuLogo` yalnızca amblem (CD-90) |
| `kpiPaddingY` / `kpiPaddingX` / `kpiGap` / `kpiIcon` | 14 / 16 / 6 / 16 | `.kpi{padding:14px 16px;gap:6px}` css:302; ui:127 `size=16` |
| `dateBadgeWidth` / `dateBadgeHeight` / `dateBadgeMonthTop` | 48 / 52 / 3 | `.date-badge{width:48px;height:52px}` css:318; `span{margin-top:3px}` css:319 |
| `coverRatio16x9` / `coverRatio3x2` / `coverRatio1x1` | 16/9, 3/2, 1 | `.cover.r16-9/.r3-2/.r1-1` css:209 (`AspectRatio`); kapak SVG `viewBox 640×360` art:29 |
| `coverIconScale` / `coverIconOffsetXRatio` / `coverIconOffsetYRatio` / `coverIconStroke` (**ek**, CD-26 ikon katmanı) | 0.8 / 0.85 / 0.9 / 1.1 | art:33–34 `k = h/24*0.8; ix = w − 24k×0.85; iy = h − 24k×0.9; stroke-width 1.1; opacity .12` — kalınlık `flutter_svg` ile 1.75 kalır (K-24 kapsamı), opaklık `GuOpacity.coverIcon` |
| `parallaxHeight` / `parallaxFactor` / `parallaxBarPaddingX` | 220 / 0.4 / 8 | `.parallax{height:220px}` css:395; `translateY(py × .4px)` css:396; `.parallax-bar{padding:calc(safe − 4px) 8px 0;gap:4px}` css:397 |
| `parallaxBarTopOffset` (**ek**) | 4 | css:397 `calc(var(--safe-top) - 4px)` → `viewPadding.top − 4`; aynı değer `.viewer` üst satırı sheets:160 `padding:calc(safe − 4px) 8px 0` |
| `imageGridGap` / `imageGridRadius` | 4 / 14 | `.img-grid{gap:4px;border-radius:14px}` css:407 (n1 16:9, n2/n4 2 sütun, n3 `2fr 1fr` ilk hücre 2 satır css:407–408) |
| `notifIcon` | 40 | `.notif-icon{width:40px;height:40px}` css:405 |
| `notifIconLg` / `notifIconLgIcon` (**ek**) | 72 / 36 | SHT-24 sonuç ikonu sheets:116 satır içi `width:72px;height:72px` + `Icon size=36` |
| `timelineItemMinHeight` / `timelineGap` / `timelineRailWidth` / `timelineDot` / `timelineDotBorder` / `timelineDotRing` / `timelineDotTop` / `timelineLineWidth` / `timelineLineMarginY` | 56 / 12 / 24 / 12 / 2 / 2 / 4 / 2 / 4 | `.timeline-item{gap:12px;min-height:56px}` css:308; `.timeline-rail{width:24px}` css:309; `.timeline-dot{width:12px;border:2px;box-shadow:0 0 0 2px;margin-top:4px}` css:310; `.timeline-line{width:2px;margin:4px 0}` css:312 |
| `pollOptionPaddingY` / `pollOptionPaddingX` / `pollOptionGap` / `pollOptionBorder` | 10 / 12 / 4 / 1 | `.poll-opt{gap:4px;padding:10px 12px;border:1px}` css:328 (radius `sm`) |
| `ticketCutDash` / `ticketNotch` / `ticketNotchTop` / `ticketNotchOffset` / `ticketCutMarginX` | 2 / 24 / 13 / 28 / 16 | `.ticket-cut{height:1px;border-top:2px dashed;margin:0 16px}` css:324; `::before/::after{top:-13px;width:24px;height:24px}` `left/right:-28px` css:325 |
| `qr` / `qrPadding` / `qrBlurSigma` / `qrVoidLineHeight` / `qrVoidAngleDeg` / `qrVoidLeft` / `qrVoidWidth` | 220 / 12 / 3 / 4 / −30 / 0.10 / 0.80 | `.qr{width:220px;height:220px;padding:12px}` css:326; `.is-blur svg{filter:blur(3px)}` `.is-void::after{left:10%;width:80%;height:4px;rotate(-30deg)}` css:327 |
| `scanBox` / `scanCorner` / `scanCornerStroke` / `scanLineHeight` / `scanLineInsetX` / `scanLineGlow` / `scanLineTopMin` / `scanLineTopMax` | 240 / 36 / 3 / 2 / 0.10 / 12 / 0.08 / 0.90 | `.scan-box{width:240px}` css:402; `>i{width:36px;border:3px}` css:403; `.scanline{left:10%;right:10%;height:2px;box-shadow:0 0 12px}` css:335; `@keyframes scan{top:8% ↔ 90%}` css:422 |
| `scanGradientStop` (**ek**) | 0.75 | `.scan-view` css:401 `#0b0d12 75%` (merkez `50% 40%` → `Alignment(0, -0.2)`) |
| `mapPlaceholderHeight` / `mapPlaceholderStripe` / `mapPlaceholderBorder` | 120 / 10 / 1 | `.map-ph{height:120px;repeating-linear-gradient(45deg,– 0 10px,– 10px 20px);border:1px}` css:410 |
| `miniChartHeight` / `miniChartViewW` / `miniChartViewH` / `miniChartPad` / `miniChartPoint` / `miniChartPointSelected` / `miniChartPointStroke` / `miniChartLine` | 120 / 320 / 110 / 10 / 4 / 6 / 2 / 2.5 | `.mini-chart{height:120px}` css:342; ui:134 `w = 320, h = 110, pad = 10`; ui:137 `r = sel ? 6 : 4`, `stroke-width="2"`, çizgi `stroke-width="2.5"`; dolum opaklığı `GuOpacity.miniChartFill .6` |
| `tooltipPaddingY` / `tooltipPaddingX` / `tooltipOffsetYRatio` | 4 / 8 / −1.10 | `.tooltip{padding:4px 8px;transform:translate(-50%,-110%)}` css:341 |
| `donut` / `donutStroke` / `donutValueDivisor` | 96 / 10 / 4.5 | ui:93 `size = 96, stroke = 10`, `font-size = size / 4.5`, yarıçap `(size − stroke) / 2`, başlangıç `rotate(-90)` |
| `successCheck` / `successCheckSizes` / `successCircleStroke` / `successCheckStroke` / `successCircleR` | 96 / [72, 110] / 4 / 5 / 40 | ui:151 `size = 96`, `viewBox 96`, `circle r=40 stroke-width=4`, `path stroke-width=5` (M30 49 l12 12 24-26); kullanım 72×1, 110×1 |
| `progressHeight` / `progressHeightThin` / `progressMinWidth` | 6 / 4 / 40 | `.prog{height:6px;min-width:40px}` css:259; `.is-thin{height:4px}` css:261 |
| `skeletonRadius` / `skeletonLineHeight` / `skeletonTitleHeight` / `skeletonSubHeight` / `skeletonCardCover` / `skeletonAvatar` | 8 / 14 / 16 / 12 / 140 / 40 | `.sk{border-radius:8px}` css:263; ui:94 `h = 14`; ui:97 kart `h=140`, `60%/16`, `90%`, `40%`; ui:98 satır `40 circle`, `55%/14`, `80%/12` |
| `skeletonWidthRatios` (liste) | 0.55, 0.80, 0.60, 0.90, 0.40 | ui:97–98 |
| `emptyPaddingY` / `emptyPaddingX` / `emptyGap` / `emptyCompactPaddingY` / `emptyCompactPaddingX` / `emptyDescMaxWidth` / `emptyInlinePaddingY` | 32 / 24 / 12 / 20 / 16 / 280 / 24 | `.empty{gap:12px;padding:32px 24px}` css:300; ui:101 compact `padding:20px 16px`; ui:101/107 `max-width:280px`; ui:107 inline `padding:24px 16px` |
| `illustration` / `illustrationCompact` / `illustrationSizes` | 140 / 96 / [56, 72, 80, 96, 100, 140, 160, 200] | art:88 `size = 140`; ui:101/107 compact/inline 96; liste (K-48): screens-profile.js:14 PRF-01 56, screens-clubs.js:26 CLB-01 72, screens-manage.js:23 MGT-01 80, screens-clubs.js:158 CLB-07 `locked` 96, screens-clubs.js:56 CLB-02 / :84 CLB-03 100, varsayılan 140, screens-auth.js:114 AUT-03 160, screens-auth.js:48 ONB-01 200 |
| `listEndPaddingTop` / `listEndPaddingX` / `listEndPaddingBottom` | 20 / 16 / 8 | ui:123 `padding:20px 16px 8px` |
| `hscrollPaddingY` / `hscrollGap` | 3 / 8 | `.hscroll{gap:8px;padding:3px 16px}` css:105 |
| `gridGap` | 12 | `.grid2/.grid3{gap:12px}` css:110 |
| `screenScrollBottomExtra` | 8 | `.screen-scroll{padding-bottom:calc(safe + 8px)}` css:123 |
| `pageDot` / `pageDotActiveWidth` / `pageDotGap` | 8 / 24 / 6 | `.dots{gap:6px}` `>i{width:8px;height:8px}` `.is-active{width:24px}` css:394 |
| `splashGap` | 16 | `.splash{gap:16px}` css:391 |
| `splashLogo` / `splashVersionBottom` (**ek**) | 96 / 40 | screens-auth.js:33 SYS-01 `Logo size=${96}`, sürüm `t-caption` `position:absolute;bottom:40px` (kabuk splash örtüsü shell.js:35 aynı) |
| `onboardingPaddingX` / `onboardingGap` | 32 / 16 | `.onb-track>section{padding:0 32px;gap:16px}` css:393 |
| `calendarGap` / `calendarDayMinHeight` / `calendarDayMinHeightCompact` / `calendarDayGap` / `calendarTodayRing` / `calendarDot` / `calendarDotGap` / `calendarDotsHeight` / `calendarDotsMax` / `calendarHeadPaddingY` / `calendarWeeks` | 2 / 44 / 36 / 2 / 2 / 4 / 2 / 4 / 3 / 4 / 6 | `.cal-grid{gap:2px}` css:313; `.cal-day{gap:2px;min-height:44px;aspect-ratio:1}` css:314; ui:149 compact `minHeight:36px`; `.is-today{inset 0 0 0 2px}` css:315; `.dots{gap:2px;height:4px} i{4px}` css:316; ui:149 `Math.min(3, dotsFor(k))`; `.cal-head{padding:4px 0}` css:317; 42 hücre (6 hafta) |

### 8.6 Overlay'ler (`ds_overlays.webp`, `reference-shots/sheets|dialogs|toasts`)

| Sabit | Değer | Kaynak |
|---|---|---|
| `sheetMaxHeightRatio` / `sheetMenuMaxHeightRatio` / `sheetFullHeightRatio` | 0.90 / 0.80 / 0.90 | `.sheet{max-height:90%}` css:268; `.is-menu{max-height:80%}` css:270; `.sheet-full{height:90%}` css:278 (K-07: `× (yükseklik − üst inset)`) |
| `sheetHandleWidth` / `sheetHandleHeight` / `sheetHandleTop` | 36 / 4 / 8 | `.sheet-handle{width:36px;height:4px;margin:8px auto 0}` css:271 (renk `borderDefault`) |
| `sheetHeadMinHeight` / `sheetHeadPaddingY` / `sheetHeadPaddingLeft` / `sheetHeadPaddingRight` / `sheetHeadGap` | 56 / 6 / 20 / 8 / 8 | `.sheet-head{gap:8px;padding:6px 8px 6px 20px;min-height:56px}` css:272 |
| `sheetBodyPaddingX` / `sheetBodyPaddingBottom` / `sheetBodyFlushPaddingBottom` | 16 / 16 / 8 | `.sheet-body{padding:0 16px 16px}` css:274; `.is-flush{padding:0 0 8px}` css:275 |
| `sheetFootPaddingY` / `sheetFootPaddingX` / `sheetFootGap` / `sheetFootBorder` | 12 / 16 / 12 / 1 | `.sheet-foot{padding:12px 16px calc(12px + safe);border-top:1px;gap:12px}` css:276 |
| `sheetDragCloseThreshold` | 120 | ui:173 `if (dy > 120) close()` (CD-24); görüntüleyici aynı eşik sheets:158 |
| `viewerDragFadeDistance` (**ek**) | 400 | sheets:160 `opacity: 1 − dy / 400` (`ImageViewer`, T-20) |
| `sheetBorderDark` | 1 | css:269 `border-top:1px solid var(--border-default)` |
| `popMenuTop` / `popMenuRight` / `popMenuMinWidth` / `popMenuPadding` / `popMenuBorder` / `popMenuTileMinHeight` / `popMenuTilePaddingY` / `popMenuTilePaddingX` | 48 / 12 / 200 / 6 / 1 / 48 / 6 / 12 | `.popmenu{top:calc(safe + 48px);right:12px;min-width:200px;padding:6px;border:1px}` css:279; `.popmenu .tile{min-height:48px;padding:6px 12px}` css:280 |
| `dialogMaxWidth` / `dialogMarginX` / `dialogPaddingTop` / `dialogPaddingX` / `dialogPaddingBottom` / `dialogGap` / `dialogMaxHeightRatio` / `dialogActionsGap` / `dialogActionsTop` / `dialogIconBox` / `dialogIcon` | 320 / 24 / 24 / 20 / 16 / 12 / 0.85 / 6 / 8 / 40 / 20 | `.dialog{width:min(320px,calc(100% - 48px));padding:24px 20px 16px;gap:12px;max-height:85%}` css:282; `.dialog-actions{gap:6px;margin-top:8px}` css:284; ui:186 `notif-icon` 40 + `size=20` |
| `toastMarginX` / `toastBottomExtra` / `toastPaddingTop` / `toastPaddingRight` / `toastPaddingBottom` / `toastPaddingLeft` / `toastGap` / `toastAccent` / `toastIcon` / `toastActionHeight` / `toastActionPaddingX` / `toastCloseButton` / `toastCloseIcon` | 12 / 12 / 12 / 8 / 12 / 14 / 10 / 4 / 18 / 36 / 10 / 32 / 16 | `.toast-wrap{left:12px;right:12px;bottom:calc(safe + 12px)}` css:288; `.above-nav{bottom:calc(nav-h + 12px)}` css:289; `.toast{padding:12px 8px 12px 14px;gap:10px;border-left:4px}` css:290; shell:21 ikon 18; `.toast-action{min-height:36px;padding:0 10px}` css:293; kapat 32 / ikon 16 shell:21 |
| `bannerPaddingY` / `bannerPaddingX` / `bannerGap` / `bannerIcon` / `bannerCardMarginX` / `bannerDismissIcon` | 10 / 16 / 10 / 18 / 16 / 18 | `.banner{gap:10px;padding:10px 16px}` css:248; `.is-card{margin:0 16px}` css:249; ikon 18 ve kapat ikonu 18 (ui:86–91 `Banner`; `ds_banners.webp` ile doğrulandı) |
| `refreshTriggerDistance` / `refreshMaxPull` / `refreshIndicatorHeight` / `refreshPullFactor` / `refreshIcon` | 60 / 90 / 48 / 0.6 / 20 | ui:159 `Math.min(90, dy × 0.6)`; ui:160 `pull > 60`; ui:162 `refreshing ? 48 : pull`, `arrow-up size=20`, dönüş `pull > 60 ? 0 : 180` (CD-24, CD-28) |

### 8.7 İkon boyutları (`GuIcon` varsayılanı 24)

Prototip `Icon size=` dağılımı (ui/cards/shell/sheets/dialogs/screens-*; bundle hariç): `icon12 = 12` (6; rozet), `icon14 = 14` (27; yardım/kaldır/satır içi meta), `icon16 = 16` (19; çip/segment/sekme/KPI/onay), `icon18 = 18` (27; sm düğme, banner, toast, kilit), `icon20 = 20` (77; düğme, girdi, chevron, hızlı eylem, dialog), `icon22 = 22` (10; PostCard aksiyonları, amblem-sm), `icon24 = 24` (1 + 3 varsayılan; ikon düğme, alt sekme), `icon30 = 30` (1), `icon34 = 34` (1), `icon36 = 36` (1; SHT-24), `icon64 = 64` (1). Küme PLAN §7.7.7 ile aynı (11 sabit); sayımlar bundle'sız olduğundan PLAN'dakinden küçüktür. SVG gerçekleri: 130 dosya, `viewBox 0 0 24 24`, `stroke #1D293D`, `stroke-width 1.75`, `fill none`; prototip `stroke=2.2` (Badge/RoleBadge/StatusBadge, 3 yer) ve `stroke=3` (Checkbox, OptionRow, 2 yer) → K-24 (CD-21).

### 8.8 Opaklıklar — `GuOpacity` (`tokens/gu_opacity.dart`; HC17)

| Sabit | Değer | Kaynak |
|---|---|---|
| `disabled` | 0.5 | `.btn[aria-disabled]` css:149, `.chip` css:185, `.tile` css:213, `.switch` css:236, `.check,.radio` css:242, `OptionRow` satır içi ui:49 |
| `iconButtonDisabled` | 0.45 | `.iconbtn[aria-disabled]{opacity:.45}` css:156 |
| `inputDisabled` | 0.6 | `.input.is-disabled{opacity:.6}` css:165 |
| `qrBlurred` | 0.5 | `.qr.is-blur svg{opacity:.5}` css:327 |
| `miniChartFill` | 0.6 | ui:137 `opacity=".6"` |
| `tonalPressedBrightness` / `tonalPressedDarken` | 0.96 / 0.04 | `.btn-tonal:hover{filter:brightness(.96)}` css:143 (`:hover` → basılı, K-53) → `Color.lerp(brandPrimaryContainer, Color(0xFF000000), 0.04)` |
| `dangerPressedDarken` | 0.08 | `.btn-danger:hover{filter:brightness(.92)}` css:147 (`:hover` → basılı, K-53) |
| `coverIcon` (**ek**) | 0.12 | art.js:34 kapak ikon katmanı `opacity=".12"` (CD-26) |

Mock opaklıklar yazılmaz: `.homebar .85` css:117, durum çubuğu sinyal `.3` shell:10.

### 8.9 Ürün/ekran düzeyinde satır içi ölçüler (**ek**, 20 sabit: F-L 10 + K-30/K-31/K-32/K-46/CD-91 10; ad genişlikleri yazılmaz — K-29, CD-106a; `lib/product/widget` da literal yazamaz → `GuSizes` "product" grubu, `/// JS-derived`)

| Sabit | Değer | Kaynak |
|---|---|---|
| `iconButtonCountPaddingX` / `iconButtonCountGap` / `postActionIcon` (**ek**, K-32) | 10 / 6 / 22 | cards:124–125 `.iconbtn style="width:auto;padding:0 10px;gap:6px;border-radius:12px"` (sayaçlı `GuIconButton` varyantı, radius `GuRadius.sm`), `heart/message-circle size=22`; `bookmark size=22` cards:128 |
| `clubCardBodyPaddingTop` / `clubCardBodyPaddingX` / `clubCardBodyPaddingBottom` / `clubCardEmblemOffset` (**ek**) | 10 / 12 / 12 / 10 | cards:32 `padding:10px 12px 12px`; cards:31 `left:10px;bottom:10px` |
| `commentAvatar` / `applicationRowAvatar` / `postAvatar` (**ek**) | 32 / 44 / 40 | sheets:48, cards:175, cards:110 (hepsi `avatarSizes` kümesinde) |
| `iconButtonTonal` (**ek**, K-32) | 44 | cards:176 onay/ret `IconButton` `width: '44px', height: '44px'` + `state*Container` zemin (`GuIconButton(tone: success/danger)`) |
| `myClubCardWidth` (**ek**, K-30) | 132 | cards:42 `MyClubChip` kartı `width:132px` |
| `applicationRowMinHeight` (**ek**, K-31) | 64 | cards:172 `ApplicationRow` `padding:6px 8px 6px 16px;min-height:64px` |
| `avatarBadgeBorder` (**ek**, CD-91) | 2 | screens-profile.js:11 PRF-01 kamera rozeti `border:2px solid var(--bg-canvas)`; konum `right:-2px;bottom:-2px` = −`avatarBadgeBorder` (ayrı sabit yok) |
| `parallaxEmblemOverlap` (**ek**, K-46) | 36 | screens-clubs.js:89 CLB-03 amblem kapsayıcısı `margin-top:-36px` (amblem kapağın altına 36 px biner) |
| `notificationSwipeDeadZone` / `notificationSwipeThreshold` / `notificationSwipeMax` (**ek**, K-46) | 8 / 90 / 140 | cards:145 `Math.abs(d) > 8` → kaydırma başlar, `Math.max(-140, Math.min(140, d))`; cards:146 `dx < -90` sil, `dx > 90` okundu (NTF-01 `swipeDelete`/`swipeRead`) |
| `viewerZoomScale` (**ek**, K-46; T-01 inceleme) | 1.8 | sheets:161 `transform: zoom && k === i ? 'scale(1.8)' : 'none'` (SHT-34 çift dokunma yakınlaştırması; süre `GuMotion.viewerZoom`) |
| `applicationLeaveOffsetX` (**ek**, K-46; T-01 inceleme) | 40 | screens-manage.js:57 `transform: leaving.includes(m.userId) ? 'translateX(40px)' : 'none'` (MGT-02 başvuru satırı çıkışı; süre `GuMotion.applicationLeave`) |

Ad kesme genişlikleri yazılmaz (K-29, CD-106a, D-21): cards:110 `max-width:170px` (PostCard yazar), ui:131 `200px` (UserRow), cards:167 `190px` (MemberRow), cards:175 `170px` (ApplicationRow) → ad `Flexible` + `TextOverflow.ellipsis` (`maxLines: 1`), rozet esnemez; `emptyDescMaxWidth 280` (§8.5) korunur.

### 8.10 Platform türevi dokunma hedefleri (**ek**, `/// Platform-derived`, CD-97)

| Sabit | Değer | Kaynak |
|---|---|---|
| `tapTargetIos` / `tapTargetAndroid` | 44 / 48 | D-22, K-03 (etkin dokunma alanı ≥ 44 pt iOS / 48 dp Android); `GuTapTarget.minSizeFor(TargetPlatform)` okur; PLAN §4 `gu_sizes.dart` satırı; CSS'te karşılığı yok → sabit beklentiyle test edilir (CD-97) |

Sayım (CD-97 formülü): PLAN §7.7.1–7.7.6 ölçüleri (353) + 11 ikon = 364 doğrulandı. F-L **ek** sabitleri 26 (taslaktaki 34'ten 4 logo oranı — CD-90 — ve 4 ad genişliği — K-29, CD-106a — çıkarıldı): 8.3 → `tabIndicatorBottomOverlap`, `wheelSpacer`, `wheelSelectionBorder` (3) · 8.4 → `chipRemoveMarginRight` (1) · 8.5 → `emblemIconSizes`, `coverIconScale`, `coverIconOffsetXRatio`, `coverIconOffsetYRatio`, `coverIconStroke`, `parallaxBarTopOffset`, `notifIconLg`, `notifIconLgIcon`, `scanGradientStop`, `splashLogo`, `splashVersionBottom` (11) · 8.6 → `viewerDragFadeDistance` (1) · 8.9 → F-L 10. Ek gruplar: `/// Platform-derived` 2 (`tapTargetIos`, `tapTargetAndroid`; §8.10, CD-97) · K-46 JS-derived 10 (§8.9: `iconButtonTonal`, `myClubCardWidth`, `applicationRowMinHeight`, `avatarBadgeBorder`, `parallaxEmblemOverlap`, `notificationSwipeDeadZone`, `notificationSwipeThreshold`, `notificationSwipeMax`; T-01 inceleme sonrası `viewerZoomScale`, `applicationLeaveOffsetX`) · K-47 1 (`avatarGroupSizes`). Mevcut liste sabitleri yalnızca değer günceller, sayıyı değiştirmez: `illustrationSizes` (K-48), `logoSizes` (32 maketi çıkar, FED-03 20 girer). Bu dosyadaki aday toplam 364 + 26 + 2 + 8 + 1 = 401 (**T-01 nihai N = 402**: CD-120 ile `miniChartFillOpacity` çıktı → 400, inceleme sonrası K-46 + 2 → 402); `expect(table.length, N)` nihai `N` T-01 planında bu listeden yazılır (CD-97; PLAN'daki 364 değişir). `GuMotion` ekleri (§7.1: `countdownTick` + K-46 5 süre, `easeCss`), `GuTypography.ticketCode`/`toastAction` (§3.2) ve `GuOpacity.coverIcon` (§8.8) bu sayıma girmez.

## 9. Kırılım noktaları — `GuBreakpoints` (Q-13, CD-29)

| Sabit | Değer | Kaynak / kullanım |
|---|---|---|
| `maxContentWidth` | 480 | CD-29: `GuContentColumn` (`Center` + `ConstrainedBox(maxWidth: 480)`), `GuApp.builder` gövdeyi (T-11), `GuSheetFrame`/`GuDialogFrame`/`GuToast` kendini sarar (T-07); `GuBottomNav`/`GuAppBar` tam genişlik; prototip tablet görünümü `ds_t820.webp`/`map_t820.webp` cihazı 390 genişlikte ortalar (shell:53 `Frame` ölçekler) — Flutter'da 480 sütun kararı Q-13 |
| `phoneSmall` | 320 | cihaz matrisi "küçük" (testing.md §5: 320 × 640; sağ taşma sıfır, D-21) |
| `phoneReference` | 390 | `.device{width:390px;height:844px}` css:112 (tasarım/golden boyutu) |
| `phoneLarge` | 430 | cihaz matrisi "büyük" |
| `tablet` | 768 | cihaz matrisi "tablet"; prototip `mobile = w < 768` shell:65 |
| `referenceHeight` | 844 | css:112 (golden yüksekliği) |

`GuBreakpoints.isWide(BuildContext) => MediaQuery.sizeOf(context).width > maxContentWidth`; dikey kilit, yatay yerleşim yok (Q-13).

## 10. AA kontrast — `gu_contrast_test.dart` beklentileri (CD-22, K-25)

Yöntem: WCAG 2.1 bağıl parlaklık, `(L1 + 0.05) / (L2 + 0.05)`; eşik 4.5 (normal metin), 3.0 (≥ 24 px ya da ≥ 18.66 px ve 700; ayrıca metin dışı öğeler WCAG 1.4.11). Değerler `registry.json#tokens.COLORS` hex'lerinden betikle hesaplandı (bu analizde yeniden üretildi; PLAN §7.14.1 ile birebir aynı sonuçlar).

### 10.1 Metin çiftleri (eşik 4.5) — token testi tablosu

| Ön plan | Arka plan | Kullanım (CSS) | Açık | Koyu | Beklenti |
|---|---|---|---|---|---|
| `textPrimary` | `bgCanvas` | gövde (css:77) | 16.86 | 15.55 | ≥ 4.5 |
| `textPrimary` | `bgSurface` | kart gövdesi | 17.75 | 14.41 | ≥ 4.5 |
| `textPrimary` | `bgSurfaceMuted` | girdi metni (css:163) | 16.20 | 12.07 | ≥ 4.5 |
| `textPrimary` | `bgSurfaceRaised` | sheet gövdesi | 17.75 | 13.24 | ≥ 4.5 |
| `textHeading` | `bgCanvas` / `bgSurface` / `bgSurfaceRaised` / `bgSurfaceMuted` | başlıklar, `btn-outline` (css:144), seg seçili | 13.88 / 14.62 / 14.62 / 13.34 | 16.12 / 14.93 / 13.71 / 12.50 | ≥ 4.5 |
| `textSecondary` | `bgSurface` / `bgCanvas` / `bgSurfaceMuted` / `bgSurfaceRaised` | ikincil, `badge-member` (css:192), seg pasif (css:221), `banner-readonly` (css:254), `ni-neutral` (css:406), `field-label` (css:162) | 7.58 / 7.20 / 6.92 / 7.58 | 10.09 / 10.89 / 8.45 / 9.27 | ≥ 4.5 |
| `textMuted` | `bgSurface` / `bgCanvas` / `bgSurfaceRaised` | caption, sekme pasif (css:226), alt sekme pasif (css:134), wheel pasif (css:322) | 4.76 / 4.52 / 4.76 | 7.89 / 8.52 / 7.25 | ≥ 4.5 |
| `textMuted` | `bgSurfaceMuted` | `badge-neutral`/`badge-full` (css:198, 12 px 600), `.picker .ph` (css:174), girdi yer tutucu (css:167) | **4.35** | 6.61 | açık **4.5 altı** → `expectedContrastFailures` (Q-15: renk değişmez) |
| `textDisabled` | `bgSurface` / `bgCanvas` | devre dışı, `cal-day.is-other` (css:315) | 2.24 / 2.13 | 3.45 / 3.72 | WCAG 1.4.3 "inactive" istisnası → testte muaf |
| `brandOnPrimary` | `brandPrimary` / `brandPrimaryPressed` | dolu buton (css:142), seçili çip koyu (css:182), seçili gün (css:315), `badge-brand` (css:199), `nav-badge`/`dot-badge`/`chip-count`/`badge-count` | 5.58 / 7.71 | 5.58 / 6.76 | ≥ 4.5 |
| `brandOnPrimaryContainer` | `brandPrimaryContainer` | tonal buton (css:143), `badge-president` (css:189), seçili çip açık (css:181), `date-badge` (css:318) | 9.58 | 13.06 | ≥ 4.5 |
| `brandPrimaryText` | `bgSurface` / `bgCanvas` / `bgSurfaceRaised` / `brandPrimaryContainer` | link (css:81), `btn-text` (css:145), aktif sekme (css:227), `kpi.is-accent` (css:304), `ni-brand` (css:406), `quick-icon` (css:306) | 5.58 / 5.30 / 5.58 / 4.75 | 4.84 / 5.22 / 4.45* / 5.01 | ≥ 4.5; *`bgSurfaceRaised` koyu **4.45** (sheet içi bağlantı metni) → `expectedContrastFailures` 4. satır (CD-100, K-25); ikon/büyük metin olarak 3.0 eşiğini geçer |
| `stateSuccess` | `stateSuccessContainer` / `bgSurface` / `bgCanvas` | `badge-success` (css:195), `banner-success` (css:255), `ni-success` (css:406) | 4.57 / 5.02 / 4.76 | 8.45 / 9.36 / 10.11 | ≥ 4.5 |
| `stateWarning` | `stateWarningContainer` / `bgSurface` / `bgCanvas` | `badge-pending`/`badge-advisor` (css:194/191), `banner-warning` (css:252) | 4.51 / 5.02 / 4.77 | 8.30 / 9.77 / 10.55 | ≥ 4.5 |
| `stateDanger` | `stateDangerContainer` / `bgSurface` / `bgCanvas` | `badge-danger` (css:196), `banner-danger` (css:253), hata metni (css:171), `tile.is-danger` (css:213), `btn-danger-outline` (css:146) | 5.45 / 6.57 / 6.24 | 6.35 / 6.42 / 6.94 | ≥ 4.5 |
| `stateInfo` | `stateInfoContainer` / `bgSurface` / `bgCanvas` | `badge-info` (css:197), `banner-info` (css:251) | 5.51 / 6.38 / 6.06 | 7.40 / 7.71 / 8.33 | ≥ 4.5 |
| `bgSurface` | `textHeading` | toast metni (css:290), `badge-superadmin` (css:193), `banner-offline` (css:250), tooltip (css:341) | 14.62 | 14.93 | ≥ 4.5 |
| `textHeading` | `brandPrimaryContainer` | seçili `option-card` (css:246) | 12.45 | 15.44 | ≥ 4.5 |
| `brandOnPrimary` (`#FFF`) | `stateInfo` | `.notif-under .u-left` kaydırma etiketi (css:338; 13 px 600) | 6.38 | **2.12** | koyu **4.5 altı** → `expectedContrastFailures` |
| `brandOnPrimary` (`#FFF`) | `stateDanger` | `.notif-under .u-right` (css:338) **ve `.btn-danger`** (css:147; SHT-10/SHT-20 gönder, DLG-07/08/10/11/13/14 onay düğmeleri — `ds_buttons.webp` koyu "danger" satırı) | 6.57 | **2.54** | koyu **4.5 altı** → `expectedContrastFailures`; kullanım listesi PLAN'a göre genişler (§13) |
| `brandOnPrimary` | `stateSuccess` / `stateWarning` | **kullanım yok** (CSS'te bu çiftler tanımlı değil) | 5.02 / 5.02 | 1.74 / 1.67 | test dışı (kullanılmayan çift) |
| `#62748E` (illüstrasyon tabanı) | `bgCanvas` | `GuIllustration` (grafik, eşik 3.0) | 4.52 | **3.70** | geçer (K-20) |
| `toastActionForeground` koyu | toast aksiyon zemini (`textHeading` + `rgba(0,0,0,.08)` = `#E1E1DE`) | `.toast .toast-action` koyu (css:294) | 10.0 (`#FFF` on `#384354`) | CSS değeri `#F5F5F1`: **1.2** → `#1E2024`: **12.45** | **K-41** (§10.3): CD-98 ile `#1E2024` → ≥ 4.5 geçer; `expectedContrastFailures`'ta değil |

`expectedContrastFailures` (CD-22'nin 3 çifti + CD-100 ile 4. çift): `(textMuted, bgSurfaceMuted, light, 4.35)`, `(brandOnPrimary, stateInfo, dark, 2.12)`, `(brandOnPrimary, stateDanger, dark, 2.54)`, `(brandPrimaryText, bgSurfaceRaised, dark, 4.45)`; `textDisabled` çiftleri muaf. Liste dışı bir çift 4.5 altına inerse test kırmızı; listedeki çift 4.5'i geçerse test kırmızı (liste güncellenir). Toast eylem metni (`toastActionForeground` koyu `#1E2024`, CD-98) 12.45 ile eşiği geçer, listeye girmez. decisions.md CD-22 satırına "→ CD-100: 4 çift" notu Faz 1 commit'inde.

### 10.2 Metin dışı öğeler (WCAG 1.4.11, eşik 3.0) — PLAN'da yok; K-43, CD-100

| Öğe | Renkler | Açık | Koyu | Not |
|---|---|---|---|---|
| Toast ikonu | `stateSuccess/stateDanger/stateInfo` on `textHeading` (css:291) | 2.91 / 2.22 / 2.29 | 1.59 / 2.32 / 1.94 | her iki temada 3.0 altı (TST-27 görüntüsünde ikon silik) |
| Alt sekme aktif göstergesi, `switch` açık ray, `check` dolu, `dot`, `nav-badge` zemini | `brandPrimary` on `bgSurface` | 5.58 | **2.92** | koyu 3.0 altı (sınırda) |
| İlerleme dolumu / ray | `brandPrimary` on `bgSurfaceMuted` (css:259–260) | 5.09 | **2.45** | koyu |
| Sheet içinde `brandPrimary` öğeleri | `brandPrimary` on `bgSurfaceRaised` | 5.58 | **2.69** | koyu |
| `switch` kapalı ray, `sheet-handle`, `stepbar` boş, `timeline-dot` boş, `timeline-line` | `borderDefault` on `bgSurface`/`bgCanvas`/`bgSurfaceRaised` | 1.23 / 1.17 / 1.23 | 1.58 / 1.70 / 1.45 | her iki tema; `switch` kapalı rayı (`borderDefault` on `bgSurface` 1.23 açık / 1.58 koyu) `nonTextPairs` + `expectedNonTextContrastFailures` listesinde **10. çift** (CD-110); ayraç, iz ve boş durum öğeleri (`sheet-handle`, `stepbar`, `timeline`) kapsam dışı; renk değişmez (Q-15) |
| Avatar baş harfleri | `#FFF` on `hsl(h 48% 42%)` (art:41) | en düşük 2.80 (ton taraması 0–359°) | aynı | metin (büyük: ≥ 18.66 px 700 için 3.0) → 24 px üstü avatarlarda sınırda |
| `on-cover` ikon düğmesi | `#FFF` on `rgba(0,0,0,.28)` ∘ kapak durakları | 3.23 (`#F3B8C2`) – 17.76 | aynı | geçer |
| `focusRing` | on `bgCanvas` / `bgSurface` | 5.30 / 5.58 | 5.22 / 4.84 | geçer |
| `check`/`radio` boş kenarlık | `textMuted` on `bgSurface` | 4.76 | 7.89 | geçer |

Karar CD-100 (K-43): token testine `nonTextPairs` grubu (eşik 3.0) ve ayrı `expectedNonTextContrastFailures` listesi eklenir — **10 çift** (CD-100'ün 9'u + CD-110): toast ikonu `stateSuccess`/`stateDanger`/`stateInfo` on `textHeading` açık (2.91 / 2.22 / 2.29) ve koyu (1.59 / 2.32 / 1.94); koyu `brandPrimary` on `bgSurface` (2.92), on `bgSurfaceMuted` (2.45), on `bgSurfaceRaised` (2.69); `switch` kapalı rayı `borderDefault` on `bgSurface` açık 1.23 / koyu 1.58 (CD-110). Renkler Q-15 gereği değişmez; liste dışı çift 3.0 altına inerse ya da listedeki çift 3.0'ı geçerse test kırmızı.

### 10.3 K-41 — koyu temada toast aksiyon metni görünmüyor (kanıt; karar CD-98)

- CSS: `.toast{background:var(--text-heading);color:var(--bg-surface)}` (css:290) + `.gu-root[data-theme="dark"] .toast .toast-action{color:var(--text-heading);background:rgba(0,0,0,.08)}` (css:294). Koyu temada `--text-heading = #F5F5F1` hem toast zemini hem aksiyon metnidir → metin `#F5F5F1` on `#E1E1DE` = **1.2**.
- Görüntü: `design/reference-shots/toasts/TST-27__dark.webp` ("Geri al" düğmesi açık gri zemin üstünde silik), karşılaştırma `toasts/TST-27__light.webp` ("Geri al" beyaz, 10.0); `prototype-pages-desktop/ds_overlays.webp` koyu bölme (TST-27 "Geri al" aynı kusur). Açık temada `rgba(255,255,255,.12)` ∘ `#1D293D` = `#384354` üstünde `#FFF` = 10.0 (sorun yok).
- Etki: 78 toast'tan eylem etiketi taşıyan 15'i (`registry.json#toasts.actionLabelTr`, K-44) ve geri al'lı çağrılar (`props.undo`, core:567) CSS değeriyle koyu temada okunamaz.
- Karar (CD-98, K-41): `toastActionForeground` koyu = `bgSurface` koyu `#1E2024` (toast metniyle aynı; `#1E2024` on `#E1E1DE` = **12.45**); açık değer `#FFFFFF` ve `toastActionBackground` (`rgba(255,255,255,.12)` / `rgba(0,0,0,.08)`) CSS'teki gibi; registry 27 renk (`GuColors`) değişmez; tasarım hatası düzeltmesi, bilinçli sapma (D-17); TST koyu golden'ları bu değerle üretilir (T-01, T-07).

## 11. Durum çubuğu haritası — `GuSystemUi` (D-20; design-contract §5; T-07)

Kaynak: shell.js:24 `darkChrome = theme === 'dark' || ['CLB-03', 'EVT-02', 'MGT-07'].includes(route.screen)` → `.statusbar.on-dark{color:#fff}` css:115 (mock çubuk, D-20 gereği Flutter'da `AnnotatedRegion`). Referans ölçüm: `reference-shots/screens/{CLB-03,EVT-02,MGT-07}__light__tr.webp` üst 54 px parlaklığı < 110 (design-contract §5); SHT-34: `reference-shots/sheets/SHT-34__light.webp` (siyah zemin, beyaz ikonlar).

| Durum | `statusBarColor` | `statusBarIconBrightness` (Android) | `statusBarBrightness` (iOS) | `systemNavigationBarColor` | `systemNavigationBarIconBrightness` | Kaynak |
|---|---|---|---|---|---|---|
| açık tema, `auto` (tüm ekranlar) | `Colors.transparent` | `Brightness.dark` (koyu ikon) | `Brightness.light` | `bgSurface` (sekme kökü, `.bottomnav` css:133) / `bgCanvas` (iç ekran, `.screen` css:119) | `Brightness.dark` | shell.js:24 `theme === 'light'` |
| koyu tema, `auto` | `Colors.transparent` | `Brightness.light` | `Brightness.dark` | `bgSurface` / `bgCanvas` | `Brightness.light` | shell.js:24 `theme === 'dark'` |
| `lightIcons` (her iki tema) | `Colors.transparent` | `Brightness.light` | `Brightness.dark` | temadan | temadan | shell.js:24 ekran listesi + SHT-34 (CD-89) |

İstisnalar (4; `GuSystemUi(style: GuSystemUiStyle.lightIcons)`): **CLB-03** Kulüp (parallax kapak `.parallax-bar` css:397 + `.iconbtn.on-cover` css:155; T-16) · **EVT-02** Etkinlik kapaklı varyant (kapaksızda `auto`; T-23) · **MGT-07** QR tarayıcı (`.scan-view` css:401; T-35) — üçü shell.js:24 listesinden · **SHT-34** `ImageViewer` (tam ekran siyah zemin `.viewer{background:#000}` css:409) kendi `GuSystemUi(style: GuSystemUiStyle.lightIcons)` kapsayıcısını verir (CD-89, K-49; design-contract §5 4. satır T-20 commit'inde; PLAN §7.12 istisna tablosu 4 satır okunur; T-20). `systemNavigationBarDividerColor = borderSoft` (css:133 `border-top`), `systemNavigationBarContrastEnforced = false`. Sheet/dialog scrim açıkken alttaki ekranın stili korunur (modal rota `AnnotatedRegion` eklemez; tek istisna SHT-34). Splash (SYS-01, `.splash{background:var(--bg-canvas)}` css:391) ve ONB-01 açık zemin → `auto`. `SystemChrome.setSystemUIOverlayStyle` hiçbir ekranda doğrudan çağrılmaz; test `SystemChrome.latestStyle` okur (PLAN §7.12).

## 12. Token testinin okuduğu dosyalar (design-contract L1; ayrıntı `design-analysis.md §L`)

| Test (`packages/gu_ui/test/`) | Okuduğu kaynak | Doğruladığı |
|---|---|---|
| `tokens/gu_colors_test.dart` | `../../design/extracted/registry.json#tokens.COLORS` + `COLOR_USAGE` (27) ve `../../design/generated-reference/colors/tokens.json#colors` | §1 tablosu (ARGB tam eşitlik, iki JSON eşit — bu analizde betikle doğrulandı), `lerp(0/1)`, `props.length == 27` |
| `tokens/gu_component_colors_test.dart` | `component-css.css` regex: `\.chip\{[^}]*\}` koyu blok `#4A5362` (css:177), `rgba\(0,0,0,\.28\)` (css:155), `rgba\(255,255,255,\.12\)` (css:293), `rgba\(0,0,0,\.08\)` (css:294), `#2a2f3a`/`#0b0d12` (css:401), `\.qr\{[^}]*background:#fff` (css:326), `\.viewer\{[^}]*background:#000` (css:409); JS literalleri `rgba(255,255,255,.7)` / `rgba(0,0,0,.35)` / `rgba(255,255,255,.4)` (screens-manage.js:149–154), `rgba(255,255,255,.6)` (sheets.js:162), `#101828` (art.js:102) | §2 (18 alan; #6 koyu `#1E2024` sabit beklenti, CD-98) |
| `tokens/gu_typography_test.dart` | `registry.json#tokens.TYPE_SCALE` (11) + `typography.json#scale` + CSS `font:` bildirimleri `CssMeasure` ile (`font:\s*(\d+)\s+calc\((\d+)px\*var\(--ts\)\)(?:\/([\d.]+)(?:px)?)?\s+(Montserrat\|Inter)`; ölçek css:87–97; bileşenler §3.2 satırları); JS art.js:45/50, ui.js:93, screens-auth.js:33, shell.js:21/35, screens-events.js:83 | §3.1 + §3.2 (`mapPlaceholder` `.map-ph` 500/12 okunur, aile Inter beklenir — CD-19; `splashTitle`/`ticketCode` em değeri JS'ten okunur; `toastAction` css:290/293; Inter 700 kümesi K-56; sabit px font kuralı taraması ↔ `nonScalingStyleNames` K-57; `leadingDistribution.even`; nöbetçi `copyWith`/`lerp`) |
| `tokens/gu_spacing_test.dart` | `registry.json#tokens.SPACING` + `CssMeasure` `.gapN{gap}` (css:101), `.p*/.px*/.py*` (css:102) | §4 (9 + `s2`, `s6`; `s10` yazılmaz — CD-99, K-42) |
| `tokens/gu_radius_test.dart` | `registry.json#tokens.RADIUS` + `CssMeasure` (`--r-*`, seçici bazlı `border-radius`, tüm `border-radius` px kümesi) | §5 (5 + 9) |
| `tokens/gu_shadows_test.dart` | `registry.json#tokens.SHADOWS` + `CssMeasure` (`--e*` css:36–39, koyu blok `--e1: none` css:74, `.ctabar`/`.fab`/`.switch>i` `box-shadow`) | §6 (ofset, renk; her katmanda `Shadow.convertRadiusToSigma(blurRadius) == CSS blur / 2`; `cssBlurToRadius`; nöbetçi `copyWith`/`lerp`) |
| `tokens/gu_motion_test.dart` | `registry.json#tokens.MOTION` + `CssMeasure` (`--motion-*`/`--ease-*`, `@keyframes` adımları, `animation:`/`transition:` css:153, 208, 263, 329, 332–335, 392, 411–426) + tüm CSS `transition`/`animation` bildirimleri ve prototip JS `transition:` dizgeleri (zamanlama fonksiyonu taraması) | §7 (+ toast 4000/6000 sabit beklenti, core:567; `countdownTick` 1000 core.js:658 ve K-46 5 süre JS kaynaklı sabit beklenti; `easeCss` satır listesi) |
| `tokens/gu_sizes_test.dart` | `component-css.css` seçici bazlı `test/helpers/css_measure.dart` (`cssValue('.btn','min-height') == 48`); JS kaynaklı satırlar sabit beklenti | §8 tüm satırlar (`/// Platform-derived` 2 sabit beklenti, §8.10); `expect(table.length, N)` (N nihai listeden, CD-97) |
| `tokens/gu_sizes_test.dart` `GuOpacity` grubu | CSS `opacity:\.(\d+)`, `filter:brightness\(\.(\d+)\)` | §8.8 |
| `tokens/gu_breakpoints_test.dart` | sabit beklenti (`480/320/390/430/768/844`) | §9, `isWide` 479/481 |
| `tokens/gu_contrast_test.dart` | `GuColors.light/dark` | §10.1 çiftleri + `expectedContrastFailures` (4 çift, CD-100); §10.2 `nonTextPairs` + `expectedNonTextContrastFailures` (10 çift, K-43, CD-100, CD-110) |
| `extensions/string_x_test.dart` | — | `trLower/trUpper/upperFor/initials` (CD-11; `initials` core:422 `toLocaleUpperCase('tr')`) |
| `tokens/gu_fonts_glyph_golden_test.dart` | `assets/fonts` (`FontLoader`; yüz listesi `helpers/test_fonts.dart`) | Türkçe glif golden'ı |
| `helpers/test_fonts_test.dart` | kök `pubspec.yaml` `flutter: fonts:` bloğu (regex) | test font listesi (`flutter_test_config.dart` + glif golden) == pubspec |
| `helpers/design_sources_test.dart`, `helpers/css_measure_test.dart` | sabit dizgeler + `component-css.css` | `parseCssColor` (`#RGB`, `#RRGGBB`, `rgba` alfa yuvarlaması), `CssMeasure` (son tanım kazanır, `declarations`, `splitList`) |
| `theme/gu_theme_test.dart` | `CssMeasure` (`.dialog` css:282, `.input` css:163, tema blokları) | PLAN §7.9.3 tablosu; `dialogTheme.constraints` maxWidth 320 + `insetPadding` yatay 24 (Dialog genişliği min(320, ekran − 48)); `textSelectionTheme.cursorColor = textPrimary`; `colorScheme` tamamı `ColorScheme.light/dark(15 alan)` |
| `theme/gu_system_ui_test.dart` | `SystemChrome.latestStyle` | §11 (4 istisna: CLB-03, EVT-02, MGT-07, SHT-34) |

## 13. Faz 1 bulguları, CD kapanışları ve PLAN §7'den sapmalar (açık iş yok — CD-107; K numaraları CD-103: K-24–K-27 PLAN'da önceden atanmış, K-28 T-00'da kullanıldı, K-29–K-40 GHIJK, F-L taslağının K-29/K-30/K-31'i → **K-41/K-42/K-43**)

| # | Bulgu | Kanıt | Etki | Karar |
|---|---|---|---|---|
| K-41 (taslak K-29) | Koyu temada toast aksiyon metni (`Geri al`, eylem etiketi) CSS değeriyle okunamıyor: metin ve toast zemini aynı token (`--text-heading`), kontrast **1.2** | css:290 + css:294; `reference-shots/toasts/TST-27__dark.webp`; `ds_overlays.webp` koyu bölme | eylem etiketli 15 toast ve geri al'lı çağrılar koyu temada | **CD-98 ile kapatıldı:** `GuComponentColors.toastActionForeground` koyu = `bgSurface` koyu `#1E2024` (12.45); açık değer ve `toastActionBackground` CSS'teki gibi; bilinçli sapma (D-17), TST koyu golden'ları bu değerle (T-01, T-07). §2 #6, §10.3 |
| K-42 (taslak K-30) | Prototipte CSS'te tanımsız yardımcı sınıflar: `gap10` (5 ekran / 32 kullanım), `pb8` (ADM-05, SHT-25, SHT-30), `pt24` (CLB-07) — tarayıcıda etkisiz (`.row gap10` → 8 px, `.col gap10` → 0) | css:101–102'de yok; `css-class-usage.json#gap10`; `grep gap10 design/prototype/app/*.js`; `screens-clubs.js:158` | PLAN §7.3 `GuSpacing.s10`'u CSS'ten doğrulayan token testi kırmızı olurdu; referans görüntüler 8/0 ile üretilmiş | **CD-99 ile kapatıldı:** referans görüntüyle 1:1 — `GuSpacing.s10` yazılmaz; `.row gap10` → `GuSpacing.s8`, `.col gap10` → boşluk yok, `pb8`/`pt24` → dolgu yok; token testi CSS-derived boşluk 2 değer (`s2`, `s6`); PLAN §7.3 addendum Faz 1 commit'inde (T-01 + FED-01/02/03, SET-04, ADM-01, ADM-05, SHT-25, SHT-30, CLB-07 task'ları) |
| K-43 (taslak K-31) | Metin dışı kontrast (WCAG 1.4.11, 3.0) altı 9 çift (+ CD-110 `switch` kapalı rayı `borderDefault/bgSurface` 1.23 / 1.58 = 10): toast ikonları her iki temada (açık 2.91 / 2.22 / 2.29, koyu 1.59 / 2.32 / 1.94); koyu temada `brandPrimary` on `bgSurface` / `bgSurfaceMuted` / `bgSurfaceRaised` (2.92 / 2.45 / 2.69: alt sekme göstergesi, switch açık, ilerleme dolumu, nav rozeti). Ayrıca metin çifti `brandPrimaryText` on `bgSurfaceRaised` koyu 4.45 (sheet içi bağlantı) | §10.2 hesapları (`registry.json` hex'leri) | AA metin dışı ölçüt; renk değişmez (Q-15) | **CD-100 ile kapatıldı:** `nonTextPairs` (3.0) + `expectedNonTextContrastFailures` (10 çift, CD-110); `brandPrimaryText/bgSurfaceRaised` koyu `expectedContrastFailures` 4. satır (CD-22 3 → 4, K-25) |
| K-53 (Faz 1 inceleme) | Dokunma basılı rengi CSS'te yalnızca `.btn:active` ölçek .98 (css:140) + `.btn-primary.is-pressed` (css:142); diğer bileşenlerde yalnızca masaüstü `:hover` kuralı | css:140–148, 155, 180, 212, 244 | §2 `onCoverScrimPressed`, §8.8 `tonalPressedBrightness` / `dangerPressedDarken` ve A.2 pressed hücreleri `:hover` kuralından türetilmiştir | `:hover` rengi = mobil basılı rengi (K-53, bilinçli yorum, D-17 kaydı); token adları `*Pressed*` kalır |
| K-25 genişleme | `brandOnPrimary/stateDanger` koyu 2.54 çiftinin kullanımı yalnızca `.notif-under` değil; `.btn-danger` (SET-03 son adım, SHT-10/SHT-20 gönder, DLG-07/08/10/11/13/14 onay) da aynı çift | css:147; screens-profile.js:91 (SET-03 `variant="danger"`); sheets:52, sheets:101; dialogs.js `danger: true` varyantı; `ds_buttons.webp` koyu "danger" | kusurun kapsamı büyür; golden'lar bu değerle üretilir | **CD-82 addendum:** K-25 satırının kullanım listesi genişletilir; PLAN §8.2 #1 "`btn-danger` hiçbir ekranda kullanılmıyor" notu geçersiz (`btn-danger` SET-03 ekranında ve sheet/dialog'larda, `btn-ghost` 3 ekranda: ONB-01, AUT-01, AUT-02); golden + ekran testi zorunlu |
| PLAN'a ek tipografi | `bannerAction` (altı çizili banner eylemi), `splashTitle`, `ticketCode` (K-46), `toastAction` (T-01 inceleme); `logoWordmarkBase` yazılmaz (CD-90) | css:257; screens-auth.js:33 (+ shell.js:35); screens-events.js:83; css:290 + css:293 | HC07: widget'ta literal yazılamaz | `GuTypography`'ye 4 alan (§3.2 #27–30); T-01 planı (CD-97) |
| PLAN'a ek ölçüler | §8'de **ek** işaretli F-L 26 sabit (`tabIndicatorBottomOverlap`, `chipRemoveMarginRight`, `wheelSpacer`, `wheelSelectionBorder`, `parallaxBarTopOffset`, `viewerDragFadeDistance`, `scanGradientStop`, `notifIconLg`/`notifIconLgIcon`, `splashLogo`/`splashVersionBottom`, `emblemIconSizes`, 4 kapak ikon sabiti, §8.9 F-L 10) + §8.9 K-46 8 + `avatarGroupSizes` (K-47) + `tapTargetIos`/`tapTargetAndroid` (§8.10, CD-97); değer güncellenen listeler `illustrationSizes` (K-48) ve `logoSizes`; çıkarılanlar 4 logo oranı (CD-90) ve 4 ad genişliği (K-29, CD-106a); ayrıca `GuOpacity.coverIcon`, `GuComponentColors` +5 (CD-87) | §8, §2 | `expect(table.length, 364)` sabiti değişir | T-01 planında nihai `N` (CD-97; bu dosyadaki aday 401); CD-20 "iki tablo" kuralı korunur (registry / CSS-derived / JS-derived / Platform-derived alt grupları) |
| PLAN'a ek süreler | `countdownTick` 1000 (CD-97); K-46 `longPress` 550, `heartPopReset` 400, `applicationLeave` 250, `viewerDoubleTap` 300, `viewerZoom` 300 (T-01 inceleme); `easeCss` (eğrisi yazılmamış geçişler); SHT-24 oto-kapanma 2 s; `refreshSettle` = `base` | core.js:658; cards:144, cards:100, screens-manage.js:48, sheets:159, sheets:161; sheets:114; ui:162 | `check_hardcode` widget'ta süre literalini reddeder | `GuMotion` §7.1'e 6 sabit + `easeCss` (CD-97; `/// JS-derived` K-46); SHT-24 → `AppDurations.qrSuccessAutoClose = Duration(seconds: 2)` (`lib/core/constants/app_durations.dart`, dosya T-26, sabit T-35; PLAN §4.4, CD-58 kalıbı; `sheet_timings.dart` yazılmaz); `refreshSettle` ayrı sabit değil |
| Illüstrasyon taban rengi | `Illustration` bileşeni `color: var(--text-disabled)` verir (art:88) ama PLAN §7.1.2 varlık tabanını `#62748E` (= `textMuted` açık) sayar | art:88; `assets/illustrations` 12 SVG: taban `#62748E` (stroke 24, fill 12), vurgu `#D00A2D`, `currentColor` yok (`grep`, bu analizde); `ds_feedback.webp` | kontrast hesabı (K-20) gömülü hex ile yapılır | Token testi ve §10.1 illüstrasyon satırı `#62748E` okur; prototip görünümüyle karşılaştırma T-03 golden'ında, kendi başına yeniden renklendirme yapılmaz (K-20) |
| K numaralandırma | PLAN §7.14.1 "Faz 1 yeni bulguları K-28'den başlar" der; K-28 T-00'da ARB `#` kusuruna verildi | `docs/design-known-issues.md` K-28 satırı | çakışma | CD-103: K-29–K-40 GHIJK, K-41–K-43 F-L, K-44–K-50 A2/A3/BCDE; `docs/design-known-issues.md` Faz 1 commit'inde (`gu-decision-log`) |
