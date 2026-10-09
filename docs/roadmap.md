# Yol Haritası — T-00 … T-47

> **Bu dosya, `docs/task-map.json` ve `docs/progress.json` ile birlikte uygulama sırasını kilitler.** Task'lar **sırayla, birer birer** yapılır; atlanmaz, birleştirilmez, yeniden sıralanmaz (CLAUDE.md §0.4). Sıra değişikliği gerekirse önce kullanıcıya sorulur (`AskUserQuestion`).
> Kimlik kapsamı tasarım registry'sinden **otomatik doğrulanmıştır**: 51 ekran · 34 sheet · 32 dialog · 78 toast (77 + `TST-58` muaf) · 1 menü (`EVT-MENU`) · 1072 ekran aksiyonu (1060 uygulanan + 12 muaf demo) — her biri tam bir task'a atanmıştır (`node tool/check_design_coverage.js --map`).

## 0. Okuma ve kurallar

0. **Faz 1 (tasarım analizi) bir task değildir ama bir kapıdır:** T-00 bittikten sonra, T-01'den önce `prompts/03-faz1-tasarim-analizi.md` uygulanır ve `docs/design-analysis.md` kullanıcı tarafından onaylanır (`progress.json#gate.designAnalysisApproved`). Analiz, T-01…T-07 içerik dağılımını düzeltebilir (sıra değişmez).
1. **Sıra = kimlik sırası.** Her task'ın bağımlılıkları kendisinden önce gelir; hiçbir task ileri bir task'a bağımlı değildir.
2. **Task döngüsü** (her task için, `prompts/task-calistir.md`): (a) `progress.json` oku → sıradaki task → (b) **plan modu**: bu dosyadaki task bölümünü, ilgili `docs/*` bölümlerini ve ekranların `design/reference-shots` görüntülerini oku, task planını yaz → (c) kullanıcı onayı → (d) uygula → (e) testler → (f) `tool/quality_gate.sh --task T-xx` → (g) inceleme ajanları → (h) commit → (i) `progress.json` + `decisions.md` + `widget-catalog.md` güncelle → (j) kullanıcıya kısa özet ve bir sonraki task.
3. **Kapsam sınırı:** Task yalnızca kendi sütunlarındaki kimlikleri uygular. Başka task'a ait ekrana giden giriş noktası **o ekran gerçek olana kadar uygulanmaz**; bu bir **bağlama borcu**dur (§5). Bağlanamayan düğme **gizlenmez, ölü bırakılmaz**: borç listesine yazılır ve borcun kapanacağı task'ta bağlanır.
4. **Ekran kökü yer tutucuları:** `StatefulShellRoute` beş dal (clubs/events/notifications/profile/admin) T-11'de **geçici yer tutucu** kök sayfalarla kurulur (`Placeholder` yalnızca bu amaçla izinli; `// TODO(T-17)` biçiminde sahibi yazılı). T-43 yer tutucu taramasında sıfır olmalıdır.
5. **Ayrıntı-önce-liste sırası:** Bir listeye girmeden önce hedef detay ekranı yapılır (T-16 detay → T-17 liste; T-23 detay → T-24 liste), böylece liste satırları gerçek hedefe bağlanır.
6. **Backend task'ları (T-12, T-15, T-19, T-22, T-25, T-30, T-37)** ekran içermez; repository + Rules + Rules testleri + ViewModel altyapısını bitirir. Rules değişikliği **aynı commit'te** test ve indeksle gelir (`docs/firestore-rules-spec.md`).
7. **Koşullu task:** T-42 (Cloud Functions) yalnızca **Q-02 = Functions (Blaze)** ise yapılır; değilse `progress.json`'da `skipped` + gerekçe, ve T-25/T-45/T-46 Mod C varsayımıyla ilerler.
8. **Her task'ın ortak 'Bitti' tanımı** §6'dadır; task'a özel testler task bölümündedir.
9. **Bilinmeyen = soru.** Task planı sırasında soru çıkarsa `AskUserQuestion` (CLAUDE.md §0.5); yanıt `docs/decisions.md`'ye ve `progress.json#questionsAnswered`'a yazılır.

## 1. Faz özeti

| Faz | Başlık | Task'lar | Ekran | Sheet | Dialog | Toast |
|---|---|---|---|---|---|---|
| A | Temel (altyapı, tasarım sistemi, veri katmanı, uygulama iskeleti) | T-00–T-11 (12) | 4 | 0 | 2 | 2 |
| B | Kimlik ve onboarding | T-12–T-14 (3) | 7 | 4 | 7 | 8 |
| C | Kulüpler ve akış | T-15–T-21 (7) | 10 | 11 | 9 | 21 |
| D | Etkinlikler | T-22–T-24 (3) | 4 | 5 | 3 | 10 |
| E | Bildirimler, profil, ayarlar | T-25–T-29 (5) | 11 | 3 | 0 | 13 |
| F | Kulüp yönetimi | T-30–T-36 (7) | 10 | 10 | 8 | 18 |
| G | Süper admin | T-37–T-41 (5) | 5 | 1 | 3 | 5 |
| H | Sertleştirme ve yayın | T-42–T-47 (6) | 0 | 0 | 0 | 0 |

## 2. Task tablosu

| Task | Faz | Başlık | Bağımlı | Ekran | Sheet | Dlg | Toast | Aksiyon (muaf) | Kümülatif ekran/sheet/dlg/toast |
|---|---|---|---|---|---|---|---|---|---|
| **T-00** | A | Depo kurulumu ve kalite kapısı | — | 0 | 0 | 0 | 0 | 0 | 0/0/0/0 |
| **T-01** | A | Token katmanı, tema ve fontlar (gu_ui) | T-00 | 0 | 0 | 0 | 0 | 0 | 0/0/0/0 |
| **T-02** | A | Test altyapısı | T-01 | 0 | 0 | 0 | 0 | 0 | 0/0/0/0 |
| **T-03** | A | İkon ve görsel kayıtları | T-01 | 0 | 0 | 0 | 0 | 0 | 0/0/0/0 |
| **T-04** | A | gu_ui primitifler | T-02, T-03 | 0 | 0 | 0 | 0 | 0 | 0/0/0/0 |
| **T-05** | A | gu_ui girdiler | T-04 | 0 | 0 | 0 | 0 | 0 | 0/0/0/0 |
| **T-06** | A | gu_ui durum, gezinme ve takvim | T-04, T-05 | 0 | 0 | 0 | 0 | 0 | 0/0/0/0 |
| **T-07** | A | Overlay çerçeveleri ve geri bildirim servisi | T-04, T-06 | 0 | 0 | 0 | 0 | 0 | 0/0/0/0 |
| **T-08** | A | gu_data çekirdeği | T-00 | 0 | 0 | 0 | 0 | 0 | 0/0/0/0 |
| **T-09** | A | Modeller | T-08 | 0 | 0 | 0 | 0 | 0 | 0/0/0/0 |
| **T-10** | A | Firebase servisleri, emülatör ve Rules iskeleti | T-08, T-09 | 0 | 0 | 0 | 0 | 0 | 0/0/0/0 |
| **T-11** | A | Uygulama iskeleti ve sistem ekranları | T-07, T-10 | 4 | 0 | 2 | 2 | 7 | 4/0/2/2 |
| **T-12** | B | Kimlik ve profil arka ucu | T-11 | 0 | 0 | 0 | 0 | 0 | 4/0/2/2 |
| **T-13** | B | Onboarding, giriş, kayıt, yasal metin | T-12 | 4 | 1 | 2 | 1 | 45 (7) | 8/1/4/3 |
| **T-14** | B | E-posta doğrulama, şifre sıfırlama, profil tamamlama | T-13 | 3 | 3 | 5 | 7 | 12 (1) | 11/4/9/10 |
| **T-15** | C | Kulüp, üyelik, şikayet ve engel arka ucu | T-12 | 0 | 0 | 0 | 0 | 0 | 11/4/9/10 |
| **T-16** | C | Kulüp detayı ve başvuru akışı | T-15 | 3 | 5 | 5 | 10 | 30 | 14/9/14/20 |
| **T-17** | C | Kulüp listesi ve arama | T-16 | 2 | 1 | 0 | 1 | 67 | 16/10/14/21 |
| **T-18** | C | Üye listesi ve kullanıcı profili | T-16 | 2 | 1 | 1 | 1 | 87 | 18/11/15/22 |
| **T-19** | C | Gönderi, yorum, oy ve kaydetme arka ucu | T-15 | 0 | 0 | 0 | 0 | 0 | 18/11/15/22 |
| **T-20** | C | Kulüp akışı ve gönderi detayı | T-19, T-18 | 2 | 3 | 2 | 6 | 77 | 20/14/17/28 |
| **T-21** | C | Gönderi / duyuru / anket oluşturma | T-20 | 1 | 1 | 1 | 3 | 9 | 21/15/18/31 |
| **T-22** | D | Etkinlik ve katılım arka ucu | T-15 | 0 | 0 | 0 | 0 | 0 | 21/15/18/31 |
| **T-23** | D | Etkinlik detayı ve bilet | T-22, T-16 | 2 | 3 +menü | 3 | 10 | 15 (1) | 23/18/21/41 |
| **T-24** | D | Etkinlik listesi ve etkinliklerim | T-23, T-06 | 2 | 2 | 0 | 0 | 63 | 25/20/21/41 |
| **T-25** | E | Bildirim arka ucu ve dağıtıcı | T-22, T-19, T-12 | 0 | 0 | 0 | 0 | 0 | 25/20/21/41 |
| **T-26** | E | Bildirim merkezi ve tercihleri | T-25, T-16 | 2 | 1 | 0 | 5 | 44 | 27/21/21/46 |
| **T-27** | E | Profil | T-16, T-20, T-14 | 4 | 0 | 0 | 3 | 58 | 31/21/21/49 |
| **T-28** | E | Ayarlar, engellenenler, hakkında, destek | T-26, T-18 | 4 | 2 | 0 | 2 | 39 | 35/23/21/51 |
| **T-29** | E | Hesap silme (anonimleştirme) | T-28, T-15 | 1 | 0 | 0 | 3 | 3 | 36/23/21/54 |
| **T-30** | F | Yönetim arka ucu | T-15, T-22, T-19, T-25 | 0 | 0 | 0 | 0 | 0 | 36/23/21/54 |
| **T-31** | F | Yönetim paneli ve faaliyet geçmişi | T-30, T-27 | 2 | 0 | 0 | 1 | 50 | 38/23/21/55 |
| **T-32** | F | Başvuru yönetimi | T-31 | 1 | 2 | 2 | 4 | 33 | 39/25/23/59 |
| **T-33** | F | Üye yönetimi ve başkanlık devri | T-31 | 1 | 3 | 3 | 6 | 50 | 40/28/26/65 |
| **T-34** | F | Etkinlik yönetimi ve oluşturma | T-31, T-24 | 2 | 3 | 3 | 4 | 20 | 42/31/29/69 |
| **T-35** | F | Katılımcılar, yoklama ve QR tarayıcı | T-34, T-23 | 2 | 1 | 0 | 3 | 68 (3) | 44/32/29/72 |
| **T-36** | F | İçerik yönetimi ve kulüp ayarları | T-31, T-21 | 2 | 1 | 0 | 0 | 32 | 46/33/29/72 |
| **T-37** | G | Süper admin arka ucu ve betik | T-30 | 0 | 0 | 0 | 0 | 0 | 46/33/29/72 |
| **T-38** | G | Admin genel bakış | T-37 | 1 | 0 | 0 | 0 | 31 | 47/33/29/72 |
| **T-39** | G | Admin kulüpler ve kulüp oluşturma | T-37, T-36 | 2 | 0 | 1 | 2 | 47 | 49/33/30/74 |
| **T-40** | G | Admin şikayetler | T-37 | 1 | 1 | 2 | 3 | 17 | 50/34/32/77 |
| **T-41** | G | Admin kullanıcılar | T-37, T-40 | 1 | 0 | 0 | 0 | 168 | 51/34/32/77 |
| **T-42** | H | Cloud Functions (Mod F) *(koşullu)* | T-25, T-22, T-29 | 0 | 0 | 0 | 0 | 0 | 51/34/32/77 |
| **T-43** | H | Bütünleme: bağlama borçları, durumlar, tam matris | T-41 | 0 | 0 | 0 | 0 | 0 | 51/34/32/77 |
| **T-44** | H | Performans ve hata yönetimi doğrulaması | T-43 | 0 | 0 | 0 | 0 | 0 | 51/34/32/77 |
| **T-45** | H | Güvenlik gözden geçirme | T-43 | 0 | 0 | 0 | 0 | 0 | 51/34/32/77 |
| **T-46** | H | Mağaza ve yayın hazırlığı | T-44, T-45 | 0 | 0 | 0 | 0 | 0 | 51/34/32/77 |
| **T-47** | H | Teslim | T-46 | 0 | 0 | 0 | 0 | 0 | 51/34/32/77 |

Toplam: **51** ekran · **34** sheet (+ `EVT-MENU` açılır menü) · **32** dialog · **77** toast (+ `TST-58` muaf) · **1072** aksiyon (bunların **12**'si muaf demo aksiyonu — `design-contract.md §2`; uygulanan **1060**).

### 2.1 Muaf kimlikler

- `TST-58` — Yalnızca demo (K-02): 'Demo: … açılıyor' — uygulanmaz
- Aksiyon düzeyinde muaflar (`AUT-01.demoAccount.*`, `AUT-01.demoToggle`, `AUT-03.demoVerify`, `EVT-03.demoScan`, `MGT-07.demoScan.*`) — `design-contract.md §2`; ilgili task bölümlerinde ayrıca anılır.

## 3. Faz haritası ve bağımlılık özeti

```
A  Temel (altyapı, tasarım sistemi, veri katmanı, uygulama iskeleti)
    T-00  Depo kurulumu ve kalite kapısı                       ← —
    T-01  Token katmanı, tema ve fontlar (gu_ui)               ← T-00
    T-02  Test altyapısı                                       ← T-01
    T-03  İkon ve görsel kayıtları                             ← T-01
    T-04  gu_ui primitifler                                    ← T-02, T-03
    T-05  gu_ui girdiler                                       ← T-04
    T-06  gu_ui durum, gezinme ve takvim                       ← T-04, T-05
    T-07  Overlay çerçeveleri ve geri bildirim servisi         ← T-04, T-06
    T-08  gu_data çekirdeği                                    ← T-00
    T-09  Modeller                                             ← T-08
    T-10  Firebase servisleri, emülatör ve Rules iskeleti      ← T-08, T-09
    T-11  Uygulama iskeleti ve sistem ekranları                ← T-07, T-10
B  Kimlik ve onboarding
    T-12  Kimlik ve profil arka ucu                            ← T-11
    T-13  Onboarding, giriş, kayıt, yasal metin                ← T-12
    T-14  E-posta doğrulama, şifre sıfırlama, profil tamamlama ← T-13
C  Kulüpler ve akış
    T-15  Kulüp, üyelik, şikayet ve engel arka ucu             ← T-12
    T-16  Kulüp detayı ve başvuru akışı                        ← T-15
    T-17  Kulüp listesi ve arama                               ← T-16
    T-18  Üye listesi ve kullanıcı profili                     ← T-16
    T-19  Gönderi, yorum, oy ve kaydetme arka ucu              ← T-15
    T-20  Kulüp akışı ve gönderi detayı                        ← T-19, T-18
    T-21  Gönderi / duyuru / anket oluşturma                   ← T-20
D  Etkinlikler
    T-22  Etkinlik ve katılım arka ucu                         ← T-15
    T-23  Etkinlik detayı ve bilet                             ← T-22, T-16
    T-24  Etkinlik listesi ve etkinliklerim                    ← T-23, T-06
E  Bildirimler, profil, ayarlar
    T-25  Bildirim arka ucu ve dağıtıcı                        ← T-22, T-19, T-12
    T-26  Bildirim merkezi ve tercihleri                       ← T-25, T-16
    T-27  Profil                                               ← T-16, T-20, T-14
    T-28  Ayarlar, engellenenler, hakkında, destek             ← T-26, T-18
    T-29  Hesap silme (anonimleştirme)                         ← T-28, T-15
F  Kulüp yönetimi
    T-30  Yönetim arka ucu                                     ← T-15, T-22, T-19, T-25
    T-31  Yönetim paneli ve faaliyet geçmişi                   ← T-30, T-27
    T-32  Başvuru yönetimi                                     ← T-31
    T-33  Üye yönetimi ve başkanlık devri                      ← T-31
    T-34  Etkinlik yönetimi ve oluşturma                       ← T-31, T-24
    T-35  Katılımcılar, yoklama ve QR tarayıcı                 ← T-34, T-23
    T-36  İçerik yönetimi ve kulüp ayarları                    ← T-31, T-21
G  Süper admin
    T-37  Süper admin arka ucu ve betik                        ← T-30
    T-38  Admin genel bakış                                    ← T-37
    T-39  Admin kulüpler ve kulüp oluşturma                    ← T-37, T-36
    T-40  Admin şikayetler                                     ← T-37
    T-41  Admin kullanıcılar                                   ← T-37, T-40
H  Sertleştirme ve yayın
    T-42  Cloud Functions (Mod F)                              ← T-25, T-22, T-29
    T-43  Bütünleme: bağlama borçları, durumlar, tam matris    ← T-41
    T-44  Performans ve hata yönetimi doğrulaması              ← T-43
    T-45  Güvenlik gözden geçirme                              ← T-43
    T-46  Mağaza ve yayın hazırlığı                            ← T-44, T-45
    T-47  Teslim                                               ← T-46
```

## 4. Task ayrıntıları

---

### Faz A — Temel (altyapı, tasarım sistemi, veri katmanı, uygulama iskeleti)

#### T-00 — Depo kurulumu ve kalite kapısı

**Hedef.** Pub workspace (kök + packages/gu_data + packages/gu_ui), pubspec/analysis_options/build.yaml uzlaştırma (docs/reference/*), very_good_analysis, codegen.sh, quality_gate.sh bağlama, .gitignore (üretilen dosyalar), l10n.yaml + ARB'den prototip-kabuğu anahtarlarının ayrılması (K-21) {appName} düzeltmesi (K-22) ve ARB dışa aktarım kusurlarının giderilmesi (K-23), asset kayıtları (fontlar/ikonlar/kapaklar/desenler/logo), platform yapılandırması (iOS SPM, Android minSdk, dikey kilit), AppConstants, ilk commit.

**Bağımlılıklar:** —  
**Ön koşul soruları:** Q-03, Q-13, Q-17, Q-18

**Veri / servis:** `AppConstants.appName`, `pubspec/workspace`, `tool/* bağlama`

**Task'a özel testler:**
- tool/verify_pack.sh yeşil
- flutter analyze temiz boş iskelet
- check_arb_parity --strict 1235 anahtar (K-21/K-22/K-23)

#### T-01 — Token katmanı, tema ve fontlar (gu_ui)

**Hedef.** GuColors (27×2, ThemeExtension+lerp), GuTypography (11 stil), GuSpacing/GuGap/GuInsets, GuRadius, GuShadows, GuMotion, GuSizes (component-css.css'ten), GuBreakpoints; GuTheme (açık/koyu ThemeData, CardThemeData/DialogThemeData), context.gu extension, bundled TTF kaydı, Türkçe glif testi.

**Bağımlılıklar:** T-00  
**Ön koşul soruları:** Q-14

**Bileşenler / sınıflar:** `GuColors`, `GuTypography`, `GuSpacing`, `GuRadius`, `GuShadows`, `GuMotion`, `GuSizes`, `GuTheme`, `context.gu`

**Task'a özel testler:**
- Token testi (registry.json ↔ Dart)
- AA kontrast
- Türkçe glif golden

#### T-02 — Test altyapısı

**Hedef.** pump_app, device_matrix (320/390/430/tablet × tema × dil × ölçek; `GU_MATRIX=fast|full` dart-define ile hızlı/tam), golden_helper, overflow_detector, action_inventory (screens-actions.json okuyucu), design_ids (registry okuyucu), fake iskeleti, GuKey.action, check_design_coverage.js ilk bağlama.

**Bağımlılıklar:** T-01  
**Ön koşul soruları:** Q-16

**Bileşenler / sınıflar:** `GuKey`, `test/helpers/*`

**Task'a özel testler:**
- Yardımcıların kendi testleri
- Kasıtlı taşan widget'ın matriste kırmızı olması

#### T-03 — İkon ve görsel kayıtları

**Hedef.** GuIcon + GuIcons (130 Lucide SVG, srcIn renklendirme), GuLogo, GuIllustration (12), GuCover (palet×desen, 26 kapak + 4 desen), kapak üretici/ağır SVG performans önlemleri.

**Bağımlılıklar:** T-01  
**Ön koşul soruları:** —

**Bileşenler / sınıflar:** `GuIcon`, `GuIcons`, `GuLogo`, `GuIllustration`, `GuCover`, `ClubPalette`, `ClubPattern`

**Task'a özel testler:**
- GuIcons ↔ assets/icons 130 birebir
- her SVG yüklenir
- rgba() taraması
- golden

#### T-04 — gu_ui primitifler

**Hedef.** Düğme ailesi, çip, rozet ailesi, avatar, kart/satır, bölüm başlığı, ilerleme/donut/KPI, tarih rozeti, mini grafik.

**Bağımlılıklar:** T-02, T-03  
**Ön koşul soruları:** —

**Bileşenler / sınıflar:** `GuButton (filled/tonal/outline/text/danger × sm/md/lg + loading + ikon)`, `GuIconButton`, `GuChip`, `GuBadge`, `GuRoleBadge`, `GuStatusBadge`, `GuAvatar`, `GuAvatarGroup`, `GuDivider`, `GuSectionTitle`, `GuCard`, `GuTile`, `GuProgress`, `GuDonut`, `GuKpi`, `GuQuickAction`, `GuDateBadge`, `GuMiniLineChart`, `GuTapTarget`

**Task'a özel testler:**
- tüm durumlar (default/pressed/focus/disabled/loading/selected)
- golden açık+koyu
- dokunma hedefi
- 320 dp taşma

#### T-05 — gu_ui girdiler

**Hedef.** Metin girişi (çok satırlı, sayaç, şifre, hata/yardım), seçici alan, anahtar, onay kutusu, radyo, seçenek kartı, segment, sekmeler (kaydırılabilir; K-05), arama alanı, adım çubuğu, sayaç adımlayıcı.

**Bağımlılıklar:** T-04  
**Ön koşul soruları:** —

**Bileşenler / sınıflar:** `GuInput`, `GuPickerField`, `GuSwitch`, `GuCheckbox`, `GuRadio`, `GuOptionRow`, `GuOptionCard`, `GuSegmented`, `GuTabs`, `GuSearchField`, `GuStepbar`, `GuStepper`

**Task'a özel testler:**
- odak/hata/devre dışı durumları
- klavye ve Semantics
- golden
- 320×1.6 taşma

#### T-06 — gu_ui durum, gezinme ve takvim

**Hedef.** İskelet (skeleton), boş/hata/çevrimdışı durumları, liste durum yöneticisi (hata→yükleniyor→boş→dolu), bant (banner), liste sonu, uygulama çubuğu, yapışkan CTA, alt sekme çubuğu, başarı çizgisi animasyonu, takvim (Q-08), yenile-çek.

**Bağımlılıklar:** T-04, T-05  
**Ön koşul soruları:** Q-08

**Bileşenler / sınıflar:** `GuSkeleton`, `GuEmptyState`, `GuErrorState`, `GuOfflineState`, `GuListState`, `GuBanner`, `GuListEnd`, `GuAppBar`, `GuStickyCta`, `GuBottomNav`, `GuSuccessCheck`, `GuCalendar`, `GuRefresh`

**Task'a özel testler:**
- 5 durum
- takvim: Pazartesi başlangıç, TR/EN, ay geçişi
- golden

#### T-07 — Overlay çerçeveleri ve geri bildirim servisi

**Hedef.** GuSheetFrame, GuDialogFrame, GuPopMenu, GuToast + ToastHost (en çok 1; 4/6 sn; çubuk üstü), FeedbackService (showSheet/showDialog/showToast), SheetId/DialogId/ToastId enum'ları ve 78 toast kataloğu (metin/tür/aksiyon registry'den), GuSystemUi (D-20), GuPageTransitions (navigation §5), metin ölçeği sarmalayıcısı.

**Bağımlılıklar:** T-04, T-06  
**Ön koşul soruları:** —

**Bileşenler / sınıflar:** `GuSheetFrame`, `GuDialogFrame`, `GuPopMenu`, `GuToast`, `FeedbackService`, `SheetId`, `DialogId`, `ToastId`, `GuSystemUi`, `GuPageTransitions`, `GuTextScale`

**Task'a özel testler:**
- 78 toast katalog testi
- sheet: scrim/X/sürükle/geri
- dialog odak tuzağı
- toast kuyruğu
- durum çubuğu stilleri
- cihaz matrisi

#### T-08 — gu_data çekirdeği

**Hedef.** FirebaseResult/FirestoreResult/StorageResult, hata türleri, BaseFields, SoftDelete, AppClock (Istanbul günü), sabitler (FirestoreCollections/Fields, Limits, RoleCodes), statik tablolar (kategori, ilgi, fakülte/bölüm, mekân, yıl, tür), RolePolicy/ClubPermission (+tablo testi), e-posta alan adı doğrulayıcı, bilet kodu üretici (CSPRNG).

**Bağımlılıklar:** T-00  
**Ön koşul soruları:** —

**Veri / servis:** `FirebaseResult`, `SoftDelete`, `BaseFields`, `AppClock`, `Limits`, `RolePolicy`, `EmailDomainValidator`, `TicketCodeGenerator`, `static lookups`

**Task'a özel testler:**
- RolePolicy tablo testi (domain-model §3)
- ticket code biçim/entropi
- Istanbul gün sınırı
- SoftDelete payload

#### T-09 — Modeller

**Hedef.** Tüm koleksiyon modelleri (domain-model §2) + enum'lar + Timestamp dönüştürücü; json_serializable (explicit_to_json), Equatable, copyWith; membership/private/contact modeli.

**Bağımlılıklar:** T-08  
**Ön koşul soruları:** —

**Veri / servis:** `UserModel`, `ClubModel`, `MembershipModel`, `PostModel`, `PollModel`, `CommentModel`, `EventModel`, `RsvpModel`, `NotificationModel`, `ReportModel`, `ActivityModel`, `UserSettingsModel`, `BlockModel`, `SupportTicketModel`, `CounterModel`

**Task'a özel testler:**
- fromJson/toJson gidiş-dönüş
- demo-data.json tüm belgeleri ayrıştırır
- BaseFields varsayılanları

#### T-10 — Firebase servisleri, emülatör ve Rules iskeleti

**Hedef.** FirestoreService (softDelete/restore, delete YOK), StorageService, AuthService, MessagingService, RemoteConfigService, CrashService, AppEnvironment (ENV=emulator|production), firebase.json emülatörleri, deny-all firestore.rules/storage.rules + Rules test düzeneği, demo seed yükleyici (tool/seed).

**Bağımlılıklar:** T-08, T-09  
**Ön koşul soruları:** Q-01, Q-03, Q-06

**Veri / servis:** `FirestoreService`, `StorageService`, `AuthService`, `MessagingService`, `RemoteConfigService`, `CrashService`, `AppEnvironment`

**Firestore Rules kapsamı:** `tümü (deny-all)`

**Task'a özel testler:**
- servis birim testleri (Q-06)
- emülatör bağlantısı
- Rules: her yol varsayılan ret
- seed → emülatör

#### T-11 — Uygulama iskeleti ve sistem ekranları

**Hedef.** Bootstrap + hata yakalama (D-23), DI (GetIt+mixin), SessionViewModel (AuthStatus, rol çözümü), router (typed routes, AuthGuard, AppRedirect, StatefulShellRoute, geçişler), tema/dil/metin ölçeği tercihleri, çevrimdışı banner + zorunlu güncelleme/oturum katmanları, beş sekme kökü ve AppRedirect hedefleri (ONB-01, AUT-01, AUT-03, AUT-05) için geçici yer tutucu rotalar, SYS-01..04.

**Bağımlılıklar:** T-07, T-10  
**Ön koşul soruları:** Q-12, Q-13

| Ekran | Ad (TR / EN) | Yol | Sekme | Roller | Aksiyon | Not |
|---|---|---|---|---|---|---|
| `SYS-01` | Açılış / Splash | `/splash` | — | all | 0 |  |
| `SYS-02` | Bir şeyler ters gitti / Something went wrong | `/error` | — | all | 3 |  |
| `SYS-03` | Çevrimdışısın / You're offline | `/offline` | — | all | 2 |  |
| `SYS-04` | Bu içerik artık yok / This content is gone | `/not-found` | — | all | 2 |  |

**Dialog:** `DLG-26` Güncelleme gerekli; `DLG-27` Oturumun sona erdi

<details><summary><b>Toast (2)</b></summary>

| ID | Tür | Metin (TR) | Aksiyon etiketi | Kalıcı |
|---|---|---|---|---|
| `TST-24` | error | Çevrimdışısın. Bu işlem için internet bağlantısı gerekli. | — | — |
| `TST-25` | success | Tekrar çevrimiçisin. | — | — |

</details>

**Bileşenler / sınıflar:** `GuApp`, `AppShellView`, `SessionViewModel`, `AppRedirect`, `ErrorBoundary`

**Bağlama notları:**
- AppRedirect hedefi ONB-01 ve AUT-01 yer tutucu → T-13
- AppRedirect hedefi AUT-03 ve AUT-05 yer tutucu → T-14
- askıya alınmış hesap açılışında DLG-01 → T-13

**Task'a özel testler:**
- AppRedirect tablo testi
- rota envanteri (kabuk)
- çevrimdışı banner
- ErrorWidget.builder
- SYS ekranları matris

*Referans:* `design/reference-shots/screens/` altında bu ekranların açık/koyu/EN görüntüleri; durum görüntüleri `states/`.

---

### Faz B — Kimlik ve onboarding

#### T-12 — Kimlik ve profil arka ucu

**Hedef.** AuthRepository (kayıt + alan adı kısıtı, giriş + 5 deneme/30 sn kilit, doğrulama maili + 60 sn, şifre sıfırlama/değiştirme, çıkış), UserRepository (profil oluştur/güncelle, profileComplete), SettingsRepository, hesap durumu (askıda) çözümü; users/private/settings Rules + testleri.

**Bağımlılıklar:** T-11  
**Ön koşul soruları:** Q-04

**Veri / servis:** `AuthRepository`, `UserRepository`, `SettingsRepository`

**Firestore Rules kapsamı:** `users`, `users/private`, `settings`

**Task'a özel testler:**
- Rules: users/private/settings matrisi
- e-posta alan adı kuralı
- kilit/60 sn sayaçları
- ViewModel testleri

#### T-13 — Onboarding, giriş, kayıt, yasal metin

**Hedef.** ONB-01 karşılama, AUT-01 giriş, AUT-02 kayıt (doğrulama, alan adı, KVKK/gizlilik onayı), AUT-06 yasal metinler (push ile), dil menüsü.

**Bağımlılıklar:** T-12  
**Ön koşul soruları:** —

| Ekran | Ad (TR / EN) | Yol | Sekme | Roller | Aksiyon | Not |
|---|---|---|---|---|---|---|
| `ONB-01` | Karşılama / Welcome | `/onboarding` | — | guest | 4 |  |
| `AUT-01` | Giriş / Sign in | `/login` | — | guest | 17 |  |
| `AUT-02` | Kayıt ol / Create account | `/register` | — | guest | 13 |  |
| `AUT-06` | Yasal metinler / Legal | `/legal/:tip` | — | all | 11 |  |

**Sheet / menü:** `SHT-01` Dil

**Dialog:** `DLG-01` Hesabın askıya alındı; `DLG-02` Çok fazla deneme

<details><summary><b>Toast (1)</b></summary>

| ID | Tür | Metin (TR) | Aksiyon etiketi | Kalıcı |
|---|---|---|---|---|
| `TST-01` | error | E-posta veya şifre hatalı. | — | — |

</details>

**Bağlama notları:**
- AUT-01 demo hesap bölümü UYGULANMAZ (K-02)
- AUT-01 'Şifremi unuttum' → AUT-04 → T-14
- AUT-02 kayıt sonrası e-posta doğrulama → AUT-03 → T-14

**Task'a özel testler:**
- form doğrulama durumları
- askıya alınmış hesap → DLG-01 + çıkış
- tüm aksiyon anahtarları
- matris

*Referans:* `design/reference-shots/screens/` altında bu ekranların açık/koyu/EN görüntüleri; durum görüntüleri `states/`.

#### T-14 — E-posta doğrulama, şifre sıfırlama, profil tamamlama

**Hedef.** AUT-03, AUT-04, AUT-05 (bölüm/sınıf/ilgi alanı/avatar), fotoğraf kaynağı, izin diyalogları, ilk girişte bildirim ön izni, çıkış, kaydedilmemiş değişiklik uyarısı.

**Bağımlılıklar:** T-13  
**Ön koşul soruları:** Q-19

| Ekran | Ad (TR / EN) | Yol | Sekme | Roller | Aksiyon | Not |
|---|---|---|---|---|---|---|
| `AUT-03` | E-postanı doğrula / Verify your email | `/verify` | — | guest | 5 |  |
| `AUT-04` | Şifre sıfırlama / Reset password | `/reset` | — | guest | 3 |  |
| `AUT-05` | Profilini tamamla / Complete your profile | `/setup-profile` | — | guest | 4 |  |

**Sheet / menü:** `SHT-02` Bölüm seç; `SHT-03` Sınıf seç; `SHT-16` Fotoğraf kaynağı

**Dialog:** `DLG-03` Bildirimleri açalım mı?; `DLG-04` Kamera erişimi; `DLG-05` Fotoğraflarına erişim; `DLG-06` Çıkış yapılsın mı?; `DLG-25` Değişiklikler kaydedilmedi

<details><summary><b>Toast (7)</b></summary>

| ID | Tür | Metin (TR) | Aksiyon etiketi | Kalıcı |
|---|---|---|---|---|
| `TST-02` | info | E-postan henüz doğrulanmamış. Bağlantıya tıkladıktan sonra tekrar dene. | — | — |
| `TST-03` | success | Bağlantı gönderildi. Gelen kutunu kontrol et. | — | — |
| `TST-04` | info | En fazla 5 ilgi alanı seçebilirsin. | — | — |
| `TST-05` | success | Hoş geldin, Ayşe Demir! | — | — |
| `TST-X3` | info | Tekrar göndermek için 42 sn bekle. | — | — |
| `TST-32` | error | Kamera izni gerekli. | Ayarlara git | — |
| `TST-57` | success | Fotoğraf güncellendi. | — | — |

</details>

**Bağlama notları:**
- AUT-03 'Doğrulandı simüle et' UYGULANMAZ (K-02)
- TST-57/avatar yükleme: Q-19'a göre
- SHT-16 çoklu görsel sınırı (maxImages) parametresi hazır; TST-X5 sınırı FED-03 ile → T-21

**Task'a özel testler:**
- 60 sn yeniden gönderme
- izin reddi akışları
- profileComplete → router yönlendirmesi
- matris

*Referans:* `design/reference-shots/screens/` altında bu ekranların açık/koyu/EN görüntüleri; durum görüntüleri `states/`.

---

### Faz C — Kulüpler ve akış

#### T-15 — Kulüp, üyelik, şikayet ve engel arka ucu

**Hedef.** ClubRepository, MembershipRepository (başvur/katıl/iptal/ayrıl + yeniden başvuru kuralı + private/contact + sayaç batch'i + activity), ReportRepository, BlockRepository; clubs/memberships/reports/blocks/activity Rules + testleri.

**Bağımlılıklar:** T-12  
**Ön koşul soruları:** Q-09, Q-10

**Veri / servis:** `ClubRepository`, `MembershipRepository`, `ReportRepository`, `BlockRepository`, `ActivityRepository`

**Firestore Rules kapsamı:** `clubs`, `memberships`, `memberships/private`, `reports`, `blocks`, `activity`

**Task'a özel testler:**
- üyelik durum makinesi M1–M14 (başvuran tarafı)
- sayaç ±1 getAfter
- retryAfter 7 gün
- e-posta sızıntı testi (private/contact)

#### T-16 — Kulüp detayı ve başvuru akışı

**Hedef.** CLB-03 (hakkında, etkinlikler, gönderiler sekmesi iskeleti, kapaklı üst + durum çubuğu), CLB-04 başvuru gönderildi, CLB-05 başvuru durumu; başvuru sheet'i, kulüp menüsü, kulüp bildirim ayarları, şikayet, paylaş, harici bağlantı onayı; ClubCTA ve üyelik durumu görünümleri.

**Bağımlılıklar:** T-15  
**Ön koşul soruları:** —

| Ekran | Ad (TR / EN) | Yol | Sekme | Roller | Aksiyon | Not |
|---|---|---|---|---|---|---|
| `CLB-03` | Kulüp / Club | `/clubs/:id` | clubs | all | 21 | kapaklı üst → açık (beyaz) durum çubuğu ikonları |
| `CLB-04` | İsteğin kulüp yönetimine iletildi / Your request was sent to the club board | `/clubs/:id/applied` | clubs | all | 4 |  |
| `CLB-05` | Başvuru durumu / Application status | `/clubs/:id/application` | clubs | all | 5 |  |

**Sheet / menü:** `SHT-05` Katılma başvurusu; `SHT-06` Kulüp menüsü; `SHT-07` Kulüp bildirimleri; `SHT-10` Şikayet nedeni; `SHT-15` Paylaş

**Dialog:** `DLG-07` İsteği iptal et?; `DLG-08` Kulüpten ayrıl?; `DLG-09` Ayrılamazsın; `DLG-12` Şikayetin alındı; `DLG-32` Uygulamadan ayrılıyorsun

<details><summary><b>Toast (10)</b></summary>

| ID | Tür | Metin (TR) | Aksiyon etiketi | Kalıcı |
|---|---|---|---|---|
| `TST-07` | success | Notun kaydedildi. | — | — |
| `TST-08` | success | E-posta adresi kopyalandı. | — | — |
| `TST-34` | success | Kulübe katıldın! | Kulübe git | — |
| `TST-35` | success | Bağlantı kopyalandı. | — | — |
| `TST-38` | success | Kulüp bildirim ayarların güncellendi. | — | — |
| `TST-39` | info | Kulüpten ayrıldın. | — | — |
| `TST-40` | info | İsteğin iptal edildi. | — | — |
| `TST-X1` | info | Bu kulüp şu an başvuru almıyor. | — | — |
| `TST-X4` | info | … tarihine kadar tekrar başvuramazsın. | — | — |
| `TST-X16` | info | Önce "Tümünü sessize al" seçeneğini kapat. | — | — |

</details>

**Bileşenler / sınıflar:** `ClubCta`, `ClubHeader`, `ClubAboutSection`, `ApplicationStatusCard`, `ExternalLinkService`

**Bağlama notları:**
- CLB-03 'Gönderiler' sekmesi içeriği → T-20 (FED-01)
- 'Üye listesi' → T-18
- 'Yönetim paneli' (MGT-01) → T-31
- 'Kulüp ayarları' (MGT-09) → T-36
- DLG-09 → SHT-25 (başkanlık devri) → T-33
- etkinlik satırı → EVT-02 → T-23
- yazı oluştur → FED-03 → T-21
- 'Etkinlik oluştur' CTA → MGT-05 → T-34

**Task'a özel testler:**
- ziyaretçi/pending/rejected/member/manager/advisor/super görünümleri
- retryAfter geri sayım
- anında katılım vs başvuru
- durum çubuğu açık-ikon
- matris

*Referans:* `design/reference-shots/screens/` altında bu ekranların açık/koyu/EN görüntüleri; durum görüntüleri `states/`.

#### T-17 — Kulüp listesi ve arama

**Hedef.** CLB-01 (kategori çipleri, liste/ızgara geçişi, katıl düğmeleri, filtre), CLB-02 (son aramalar, popüler, istemci tarafı arama + 250 ms debounce; kulüp + etkinlik sonuçları), filtre sheet'i; ClubCard.

**Bağımlılıklar:** T-16  
**Ön koşul soruları:** —

| Ekran | Ad (TR / EN) | Yol | Sekme | Roller | Aksiyon | Not |
|---|---|---|---|---|---|---|
| `CLB-01` | Kulüpler / Clubs | `/clubs` | clubs | all | 44 |  |
| `CLB-02` | Arama / Search | `/clubs/search` | clubs | all | 23 |  |

**Sheet / menü:** `SHT-04` Filtre ve sıralama

<details><summary><b>Toast (1)</b></summary>

| ID | Tür | Metin (TR) | Aksiyon etiketi | Kalıcı |
|---|---|---|---|---|
| `TST-06` | info | Son aramalar temizlendi. | Geri al | — |

</details>

**Bileşenler / sınıflar:** `ClubCard`, `ClubFilterState`

**Bağlama notları:**
- CLB-01 → PRF-03 'Kulüplerim' → T-27
- CLB-02 etkinlik sonuçları → EVT-02 → T-23

**Task'a özel testler:**
- 5 durum (states/*.webp)
- filtre sayacı
- arama debounce
- TR büyük/küçük harf eşleşmesi (İ/ı)

*Referans:* `design/reference-shots/screens/` altında bu ekranların açık/koyu/EN görüntüleri; durum görüntüleri `states/`.

#### T-18 — Üye listesi ve kullanıcı profili

**Hedef.** CLB-06 (rol süzgeçleri, arama, sıralama, danışman grubu; yönetici menüleri), CLB-07 (başkasının profili: ortak kulüp gizliliği UI katmanında, engelle/şikayet menüsü); SHT-27 kullanıcı menüsü (profili gör, engelle/engeli kaldır, kullanıcıyı şikayet et); MemberRow, UserRow.

**Bağımlılıklar:** T-16  
**Ön koşul soruları:** —

| Ekran | Ad (TR / EN) | Yol | Sekme | Roller | Aksiyon | Not |
|---|---|---|---|---|---|---|
| `CLB-06` | Üyeler / Members | `/clubs/:id/members` | clubs | member | 84 |  |
| `CLB-07` | Profil / Profile | `/users/:id` | — | member | 3 |  |

**Sheet / menü:** `SHT-27` Kullanıcı

**Dialog:** `DLG-13` {name} engellensin mi?

<details><summary><b>Toast (1)</b></summary>

| ID | Tür | Metin (TR) | Aksiyon etiketi | Kalıcı |
|---|---|---|---|---|
| `TST-09` | info | Ayşe Demir engellendi. | Geri al | — |

</details>

**Bileşenler / sınıflar:** `MemberRow`, `UserRow`, `UserProfileHeader`, `UserMenuSheet`

**Bağlama notları:**
- üye satırı menüsü SHT-21 → T-33
- SHT-27 yorum satırları (Yorumu sil → DLG-11, Yorumu şikayet et) → T-20

**Task'a özel testler:**
- üye olmayan erişimi → kulüp sayfasına yönlendirme
- engelli kullanıcıların listeden süzülmesi
- matris

*Referans:* `design/reference-shots/screens/` altında bu ekranların açık/koyu/EN görüntüleri; durum görüntüleri `states/`.

#### T-19 — Gönderi, yorum, oy ve kaydetme arka ucu

**Hedef.** PostRepository (gönderi/duyuru/anket, beğeni, oy, sabitle + clubs.pinnedPostId, soft delete/restore), CommentRepository (commentCount batch), SavedPostRepository; posts/votes/comments/savedPosts/announcementCounters Rules + testleri.

**Bağımlılıklar:** T-15  
**Ön koşul soruları:** Q-10, Q-19

**Veri / servis:** `PostRepository`, `CommentRepository`, `SavedPostRepository`, `AnnouncementCounterRepository`

**Firestore Rules kapsamı:** `posts`, `posts/votes`, `comments`, `savedPosts`, `announcementCounters`

**Task'a özel testler:**
- likeCount/commentCount ±1
- oy değiştirilemez
- duyuru limiti 2/gün (Istanbul günü)
- soft delete + restore yetkileri

#### T-20 — Kulüp akışı ve gönderi detayı

**Hedef.** FED-01 (CLB-03 içinde: tür süzgeçleri, sabitli gönderi, anket oyu), FED-02 (yorumlar, beğeni, kaydet, menü), gönderi menüsü, yorumlar sheet'i, görsel görüntüleyici, silme diyalogları; PostCard, PollBlock, ImageGrid, CommentRow.

**Bağımlılıklar:** T-19, T-18  
**Ön koşul soruları:** —

| Ekran | Ad (TR / EN) | Yol | Sekme | Roller | Aksiyon | Not |
|---|---|---|---|---|---|---|
| `FED-01` | Akış / Feed | `/clubs/:id (Gönderiler)` | clubs | member | 61 |  |
| `FED-02` | Gönderi / Post | `/clubs/:id/posts/:postId` | clubs | member | 16 |  |

**Sheet / menü:** `SHT-08` Gönderi; `SHT-09` Yorumlar; `SHT-34` Görsel

**Dialog:** `DLG-10` Gönderi silinsin mi?; `DLG-11` Yorum silinsin mi?

<details><summary><b>Toast (6)</b></summary>

| ID | Tür | Metin (TR) | Aksiyon etiketi | Kalıcı |
|---|---|---|---|---|
| `TST-10` | info | Oyun kaydedildi. Anketlerde oy değiştirilemez. | — | — |
| `TST-11` | success | Kaydedilenlerden kaldırıldı. | Geri al | — |
| `TST-12` | success | Yorumun gönderildi. | — | — |
| `TST-26` | info | Danışman yetkisi salt okunurdur. | — | — |
| `TST-45` | info | … silindi. | Geri al | — |
| `TST-53` | success | Sabitleme kaldırıldı. | — | — |

</details>

**Bileşenler / sınıflar:** `PostCard`, `PollBlock`, `ImageGrid`, `CommentRow`, `PostMenu`

**Bağlama notları:**
- CLB-03 'Gönderiler' sekmesi artık gerçek (T-16 iskeleti dolar)
- SHT-27 yorum satırları artık gerçek (yönetici yorum menüsü)
- FED-01 'yazı oluştur' → FED-03 → T-21
- SHT-08 'Düzenle' → FED-03 düzenleme modu → T-21

**Task'a özel testler:**
- optimistik beğeni/kaydet geri alma
- anket: süre bitti/oy verildi/sonuç göster
- danışman salt okunur → TST-26
- gizli/silinmiş gönderi → SYS-04
- matris

*Referans:* `design/reference-shots/screens/` altında bu ekranların açık/koyu/EN görüntüleri; durum görüntüleri `states/`.

#### T-21 — Gönderi / duyuru / anket oluşturma

**Hedef.** FED-03 (tür seçimi, başlık/metin, görsel ekleme, anket seçenekleri/süre, duyuru bildirim anahtarı + günlük hak çubuğu, taslak, önizleme, düzenleme), duyuru limiti akışı; SHT-18 yönetilen kulüp seçici (FED-03 kulüp değiştirme; MGT-01 ve PRF-01 yeniden kullanır).

**Bağımlılıklar:** T-20  
**Ön koşul soruları:** Q-10, Q-19

| Ekran | Ad (TR / EN) | Yol | Sekme | Roller | Aksiyon | Not |
|---|---|---|---|---|---|---|
| `FED-03` | Yeni gönderi / New post | `/clubs/:id/compose` | clubs | manager | 9 |  |

**Sheet / menü:** `SHT-18` Yönetilen kulüp seç

**Dialog:** `DLG-24` Bugünkü duyuru hakkın doldu

<details><summary><b>Toast (3)</b></summary>

| ID | Tür | Metin (TR) | Aksiyon etiketi | Kalıcı |
|---|---|---|---|---|
| `TST-13` | success | Taslak kaydedildi. | — | — |
| `TST-14` | success | Yayınlandı. | Görüntüle | — |
| `TST-X5` | info | En fazla 4 görsel ekleyebilirsin. | — | — |

</details>

**Bileşenler / sınıflar:** `ComposeForm`, `AnnouncementQuotaBar`, `ManagedClubPickerSheet`

**Bağlama notları:**
- SHT-18 varsayılan davranışı (onSelect verilmezse) → MGT-01 → T-31

**Task'a özel testler:**
- limit 2/gün: 3. duyuru reddedilir
- bildirimsiz yayın sınırsız
- kaydedilmemiş değişiklik uyarısı
- görsel ≤ 4

*Referans:* `design/reference-shots/screens/` altında bu ekranların açık/koyu/EN görüntüleri; durum görüntüleri `states/`.

---

### Faz D — Etkinlikler

#### T-22 — Etkinlik ve katılım arka ucu

**Hedef.** EventRepository (taslak/yayın/iptal, kopyala, soft delete yalnız taslak), RsvpRepository (katıl/bekleme/vazgeç/yeniden katıl, bilet kodu, yoklama, terfi); events/rsvps Rules + sayaç testleri; kontenjan yarışı transaction'ı.

**Bağımlılıklar:** T-15  
**Ön koşul soruları:** Q-02, Q-07

**Veri / servis:** `EventRepository`, `RsvpRepository`

**Firestore Rules kapsamı:** `events`, `rsvps`

**Task'a özel testler:**
- kontenjan = 1, iki eşzamanlı katılım
- bekleme sırası
- goingCount/waitlistCount/attendedCount ±1
- members-only görünürlük sorguları

#### T-23 — Etkinlik detayı ve bilet

**Hedef.** EVT-02 (kapaklı üst + durum çubuğu, katıl/vazgeç/bekleme, hatırlatıcı, takvime ekle, paylaş, iptal edilmiş etkinlik), EVT-03 bilet (QR, canlı durum); EventCard bileşenleri.

**Bağımlılıklar:** T-22, T-16  
**Ön koşul soruları:** Q-07

| Ekran | Ad (TR / EN) | Yol | Sekme | Roller | Aksiyon | Not |
|---|---|---|---|---|---|---|
| `EVT-02` | Etkinlik / Event | `/events/:id` | events | all | 10 | kapaklı üst → açık (beyaz) ikonlar |
| `EVT-03` | Bilet / Ticket | `/events/:id/ticket` | events | member | 5 |  |

**Sheet / menü:** `SHT-12` Katılım onayı; `SHT-13` Hatırlatıcı; `SHT-14` Takvime ekle; `EVT-MENU` Etkinlik menüsü

**Dialog:** `DLG-14` Katılımdan vazgeç?; `DLG-15` Kontenjan doldu; `DLG-16` Etkinlik iptal edildi

<details><summary><b>Toast (10)</b></summary>

| ID | Tür | Metin (TR) | Aksiyon etiketi | Kalıcı |
|---|---|---|---|---|
| `TST-15` | success | Biletin okutuldu. İyi eğlenceler! | — | — |
| `TST-36` | success | Takvime eklendi. | — | — |
| `TST-37` | success | Hatırlatıcı ayarlandı. | — | — |
| `TST-41` | success | Kaydın alındı. Biletin hazır. | Biletini göster | — |
| `TST-42` | info | Katılımdan vazgeçtin. | — | — |
| `TST-43` | success | Bekleme listesine eklendin (2. sıra). | — | — |
| `TST-X2` | info | Bu etkinliğin kayıtları kapalı. | — | — |
| `TST-X6` | info | Bu etkinlik sona erdi. | — | — |
| `TST-X7` | info | Hatırlatıcı için önce etkinliğe katıl. | — | — |
| `TST-X8` | info | 3 kişi katılıyor. | — | — |

</details>

**Bileşenler / sınıflar:** `EventHeader`, `EventCta`, `TicketCard`, `EventCard`

**Bağlama notları:**
- yönetici düğmeleri: Düzenle (MGT-05) → T-34, Katılımcılar/Yoklama (MGT-06/07) → T-35

**Task'a özel testler:**
- rsvp durum makinesi görünümleri
- bilet durumları Geçerli/Okutuldu/İptal canlı
- ICS çıktısı
- yerel hatırlatıcı planlama (Q-07)
- matris

*Referans:* `design/reference-shots/screens/` altında bu ekranların açık/koyu/EN görüntüleri; durum görüntüleri `states/`.

#### T-24 — Etkinlik listesi ve etkinliklerim

**Hedef.** EVT-01 (liste/takvim, tür çipleri, filtre, istemci birleştirme: herkese açık + üye olunan kulüp başına sorgular), EVT-04 (yaklaşan/geçmiş/bekleme); takvim bileşeni entegrasyonu; SHT-28 tarih seçici (etkinlik filtresi özel tarih; MGT-05 yeniden kullanır).

**Bağımlılıklar:** T-23, T-06  
**Ön koşul soruları:** —

| Ekran | Ad (TR / EN) | Yol | Sekme | Roller | Aksiyon | Not |
|---|---|---|---|---|---|---|
| `EVT-01` | Etkinlikler / Events | `/events` | events | all | 56 |  |
| `EVT-04` | Etkinliklerim / My events | `/events/mine` | events | all | 7 |  |

**Sheet / menü:** `SHT-11` Etkinlik filtresi; `SHT-28` Tarih seç

**Bileşenler / sınıflar:** `EventListSection`, `EventFilterState`, `DatePickerSheet`

**Task'a özel testler:**
- 5 durum
- TR Pazartesi başlangıçlı takvim
- geçmiş = bitiş < şimdi
- matris

*Referans:* `design/reference-shots/screens/` altında bu ekranların açık/koyu/EN görüntüleri; durum görüntüleri `states/`.

---

### Faz E — Bildirimler, profil, ayarlar

#### T-25 — Bildirim arka ucu ve dağıtıcı

**Hedef.** NotificationRepository, NotificationDispatcher arayüzü + Mod'a göre uygulama (ClientFanOutDispatcher | ServerSideDispatcher), FCM jeton kaydı/çıkışta temizleme, yerel hatırlatıcı (Q-07), kullanıcı tercihleri ve sessiz saat filtreleri (okuyan tarafta), notifications Rules + testleri.

**Bağımlılıklar:** T-22, T-19, T-12  
**Ön koşul soruları:** Q-02, Q-07

**Veri / servis:** `NotificationRepository`, `NotificationDispatcher`, `PushTokenService`, `LocalReminderService`

**Firestore Rules kapsamı:** `notifications`

**Task'a özel testler:**
- bildirim üretim tablosu (domain-model §6) her tür
- tercih/sessiz saat filtresi
- Rules: tür-bazlı create (Mod C)
- jeton temizleme

#### T-26 — Bildirim merkezi ve tercihleri

**Hedef.** NTF-01 (gruplama, okundu, kaydır-sil + geri al, tümünü okundu, derin bağlantılar), NTF-02 (genel anahtarlar, hatırlatma zamanı, sessiz saatler, kulüp bazlı ayarlar), ön plan bildirim bandı; SHT-29 saat seçici (sessiz saatler/hatırlatma zamanı; MGT-05 yeniden kullanır).

**Bağımlılıklar:** T-25, T-16  
**Ön koşul soruları:** —

| Ekran | Ad (TR / EN) | Yol | Sekme | Roller | Aksiyon | Not |
|---|---|---|---|---|---|---|
| `NTF-01` | Bildirimler / Notifications | `/notifications` | notifications | all | 32 |  |
| `NTF-02` | Bildirim tercihleri / Notification preferences | `/settings/notifications` | notifications | all | 12 |  |

**Sheet / menü:** `SHT-29` Saat seç

<details><summary><b>Toast (5)</b></summary>

| ID | Tür | Metin (TR) | Aksiyon etiketi | Kalıcı |
|---|---|---|---|---|
| `TST-16` | info | Bildirim silindi. | Geri al | — |
| `TST-17` | success | Şikayetin incelendi ve gereken işlem yapıldı. Teşekkürler. | — | — |
| `TST-18` | success | Tüm bildirimler okundu olarak işaretlendi. | — | — |
| `TST-19` | success | Tercihin kaydedildi. | — | — |
| `TST-55` | info | Yeni bildirim: … | Görüntüle | — |

</details>

**Bileşenler / sınıflar:** `NotificationRow`, `NotificationGroup`, `QuietHoursPicker`, `TimePickerSheet`

**Bağlama notları:**
- application_received → MGT-02/SHT-19 → T-32
- new_report → ADM-04/SHT-26 → T-40
- system/varsayılan bildirim → SET-04 → T-28

**Task'a özel testler:**
- derin bağlantı tablosu (navigation §4.1) her tür
- silinmiş hedef → SYS-04
- okunmamış rozet 9+
- matris

*Referans:* `design/reference-shots/screens/` altında bu ekranların açık/koyu/EN görüntüleri; durum görüntüleri `states/`.

#### T-27 — Profil

**Hedef.** PRF-01 (özet, istatistikler, yönetilen kulüpler, ilgi alanları), PRF-02 (düzenle: ad, bölüm, sınıf, ilgi, biyografi, avatar), PRF-03 (aktif/bekleyen/geçmiş), PRF-04 (kaydedilenler).

**Bağımlılıklar:** T-16, T-20, T-14  
**Ön koşul soruları:** —

| Ekran | Ad (TR / EN) | Yol | Sekme | Roller | Aksiyon | Not |
|---|---|---|---|---|---|---|
| `PRF-01` | Profil / Profile | `/profile` | profile | all | 20 |  |
| `PRF-02` | Profili düzenle / Edit profile | `/profile/edit` | profile | all | 25 |  |
| `PRF-03` | Kulüplerim ve başvurularım / My clubs & applications | `/profile/clubs` | profile | all | 8 |  |
| `PRF-04` | Kaydedilenler / Saved | `/profile/saved` | profile | all | 5 |  |

<details><summary><b>Toast (3)</b></summary>

| ID | Tür | Metin (TR) | Aksiyon etiketi | Kalıcı |
|---|---|---|---|---|
| `TST-20` | info | Bu alan değiştirilemez. | — | — |
| `TST-21` | success | Değişiklikler kaydedildi. | — | — |
| `TST-X9` | info | Kaydedilecek değişiklik yok. | — | — |

</details>

**Bileşenler / sınıflar:** `ProfileHeader`, `MyClubRow`

**Bağlama notları:**
- yönetilen kulüp → MGT-01 → T-31
- PRF-01 ayarlar girişi → SET-01 → T-28

**Task'a özel testler:**
- 5 durum (PRF-03/04)
- PRF-03 EN 320×1.3 taşma (K-05)
- kaydedilmemiş değişiklik
- matris

*Referans:* `design/reference-shots/screens/` altında bu ekranların açık/koyu/EN görüntüleri; durum görüntüleri `states/`.

#### T-28 — Ayarlar, engellenenler, hakkında, destek

**Hedef.** SET-01 (tema, dil, metin boyutu, bildirim, engellenenler, hakkında, destek, şifre, çıkış, hesap sil girişi), SET-02, SET-04 (sürüm, lisanslar), SET-05 (SSS, destek talebi + ek, supportTickets).

**Bağımlılıklar:** T-26, T-18  
**Ön koşul soruları:** Q-14, Q-19

| Ekran | Ad (TR / EN) | Yol | Sekme | Roller | Aksiyon | Not |
|---|---|---|---|---|---|---|
| `SET-01` | Ayarlar / Settings | `/settings` | profile | all | 14 |  |
| `SET-02` | Engellenen kullanıcılar / Blocked users | `/settings/blocked` | profile | all | 3 |  |
| `SET-04` | Hakkında / About | `/settings/about` | profile | all | 8 |  |
| `SET-05` | Yardım ve destek / Help & support | `/settings/support` | profile | all | 14 |  |

**Sheet / menü:** `SHT-17` Tema; `SHT-32` Şifre değiştir

<details><summary><b>Toast (2)</b></summary>

| ID | Tür | Metin (TR) | Aksiyon etiketi | Kalıcı |
|---|---|---|---|---|
| `TST-23` | success | Mesajın alındı. Talep no: #GU-4821 | — | — |
| `TST-44` | success | Şifren değiştirildi. | — | — |

</details>

**Veri / servis:** `SupportRepository`

**Firestore Rules kapsamı:** `supportTickets`

**Bağlama notları:**
- SET-01 'Hesabımı sil' → SET-03 → T-29

**Task'a özel testler:**
- tema/dil/ölçek kalıcılığı
- şifre değiştirme yeniden doğrulama
- destek talebi biçimi #GU-XXXXXX
- matris

*Referans:* `design/reference-shots/screens/` altında bu ekranların açık/koyu/EN görüntüleri; durum görüntüleri `states/`.

#### T-29 — Hesap silme (anonimleştirme)

**Hedef.** SET-03 üç adımlı akış (uyarı, başkanlık ön koşulu, yeniden doğrulama + 'SİL'), anonimleştirme + soft delete işlem dizisi (parçalı), oturum kapatma, silinmiş kullanıcı davranışı.

**Bağımlılıklar:** T-28, T-15  
**Ön koşul soruları:** Q-11

| Ekran | Ad (TR / EN) | Yol | Sekme | Roller | Aksiyon | Not |
|---|---|---|---|---|---|---|
| `SET-03` | Hesabı sil / Delete account | `/settings/delete` | profile | all | 3 |  |

<details><summary><b>Toast (3)</b></summary>

| ID | Tür | Metin (TR) | Aksiyon etiketi | Kalıcı |
|---|---|---|---|---|
| `TST-22` | success | Hesabın silindi. Seni özleyeceğiz. | — | — |
| `TST-X10` | info | Önce başkanlığı devretmelisin. | — | — |
| `TST-X11` | info | Şifreni gir ve onaylamak için SİL yaz. | — | — |

</details>

**Firestore Rules kapsamı:** `users (status=deleted)`, `memberships (left/cancelled)`

**Bağlama notları:**
- başkan ise → devir akışı MGT-03/SHT-25 → T-33

**Task'a özel testler:**
- anonimleştirme alan listesi
- başkan engeli
- silinmiş kullanıcı yazamaz (Rules)
- erişim çağrısı bütçesi
- emülatör uçtan uca

*Referans:* `design/reference-shots/screens/` altında bu ekranların açık/koyu/EN görüntüleri; durum görüntüleri `states/`.

---

### Faz F — Kulüp yönetimi

#### T-30 — Yönetim arka ucu

**Hedef.** Başvuru karar/geri al (30 sn), üye çıkar, rol değiştir, başkanlık devri, kulüp ayarı güncelleme, etkinlik yayın/iptal/taslak, duyuru/sabitle, yoklama yazımları, activity günlüğü (aynı batch), danışman salt okunur kısıtı; ilgili Rules geçişleri M5–M13 + testleri.

**Bağımlılıklar:** T-15, T-22, T-19, T-25  
**Ön koşul soruları:** Q-09

**Veri / servis:** `ManagementRepository`, `AttendanceRepository`

**Firestore Rules kapsamı:** `memberships (yönetici geçişleri)`, `clubs (yönetim alanları)`, `events`, `rsvps (yoklama)`, `activity`

**Task'a özel testler:**
- üyelik geçiş tablosu M5–M13 hiyerarşi dahil
- 30 sn geri al penceresi
- devir tek batch
- Rules: danışman yazamaz

#### T-31 — Yönetim paneli ve faaliyet geçmişi

**Hedef.** MGT-01 (KPI, grafik, bekleyenler, yaklaşan etkinlikler, son hareketler, salt okunur bant, hızlı eylemler), MGT-10 (filtreler, sayfalama); yönetilen kulüp seçici SHT-18 (T-21'de yapıldı) burada MGT-01 girişine bağlanır; MgtHeader, ActivityRow.

**Bağımlılıklar:** T-30, T-27  
**Ön koşul soruları:** —

| Ekran | Ad (TR / EN) | Yol | Sekme | Roller | Aksiyon | Not |
|---|---|---|---|---|---|---|
| `MGT-01` | Yönetim paneli / Management panel | `/manage/:clubId` | clubs | manager | 28 |  |
| `MGT-10` | Faaliyet geçmişi / Activity log | `/manage/:clubId/activity` | clubs | manager | 22 |  |

<details><summary><b>Toast (1)</b></summary>

| ID | Tür | Metin (TR) | Aksiyon etiketi | Kalıcı |
|---|---|---|---|---|
| `TST-X12` | info | Yoklama alınacak etkinlik yok. | — | — |

</details>

**Bileşenler / sınıflar:** `MgtHeader`, `ActivityRow`, `MgtKpiGrid`

**Bağlama notları:**
- CLB-03/PRF-01/NTF-01 giriş noktaları artık gerçek
- MGT-01 hızlı eylem: Başvurular → MGT-02 → T-32
- MGT-01 hızlı eylem: Üyeler → MGT-03 → T-33
- MGT-01 hızlı eylem: Etkinlikler/Etkinlik oluştur → MGT-04, MGT-05 → T-34
- MGT-01 hızlı eylem: Yoklama → MGT-06 → T-35
- MGT-01 hızlı eylem: İçerik/Kulüp ayarları → MGT-08, MGT-09 → T-36

**Task'a özel testler:**
- danışman: yazma devre dışı + TST-26
- KPI sayıları sayaçlarla tutarlı
- matris

*Referans:* `design/reference-shots/screens/` altında bu ekranların açık/koyu/EN görüntüleri; durum görüntüleri `states/`.

#### T-32 — Başvuru yönetimi

**Hedef.** MGT-02 (sekmeler, arama, sıralama, tek dokunuş onay/red, çoklu seçim + toplu işlem, geri al), başvuru detayı, red nedeni, çakışma diyaloğu.

**Bağımlılıklar:** T-31  
**Ön koşul soruları:** —

| Ekran | Ad (TR / EN) | Yol | Sekme | Roller | Aksiyon | Not |
|---|---|---|---|---|---|---|
| `MGT-02` | Başvurular / Applications | `/manage/:clubId/applications` | clubs | manager | 33 |  |

**Sheet / menü:** `SHT-19` Başvuru detayı; `SHT-20` Red nedeni

**Dialog:** `DLG-17` Toplu işlem onayı; `DLG-18` Başvuru zaten sonuçlandırıldı

<details><summary><b>Toast (4)</b></summary>

| ID | Tür | Metin (TR) | Aksiyon etiketi | Kalıcı |
|---|---|---|---|---|
| `TST-27` | success | Ayşe Demir onaylandı. | Geri al | — |
| `TST-28` | info | Ayşe Demir reddedildi. | Geri al | — |
| `TST-54` | info | Başvurular kapatıldı. | — | — |
| `TST-X17` | success | Karar geri alındı; başvuru yeniden beklemede. | — | — |

</details>

**Bileşenler / sınıflar:** `ApplicationRow`

**Task'a özel testler:**
- iki yönetici çakışması → DLG-18
- geri al 30 sn
- retryAfter yazımı
- toplu onay sayaç tutarlılığı
- matris

*Referans:* `design/reference-shots/screens/` altında bu ekranların açık/koyu/EN görüntüleri; durum görüntüleri `states/`.

#### T-33 — Üye yönetimi ve başkanlık devri

**Hedef.** MGT-03 (rol süzgeçleri, arama, sıralama, CSV dışa aktarma, başkanlık devri girişi), üye işlemleri, rol seçici, çıkarma, rol değişimi, devir onayı ('DEVRET').

**Bağımlılıklar:** T-31  
**Ön koşul soruları:** —

| Ekran | Ad (TR / EN) | Yol | Sekme | Roller | Aksiyon | Not |
|---|---|---|---|---|---|---|
| `MGT-03` | Üye yönetimi / Member management | `/manage/:clubId/members` | clubs | manager | 50 |  |

**Sheet / menü:** `SHT-21` Üye işlemleri; `SHT-22` Rol seç; `SHT-25` Başkan ata

**Dialog:** `DLG-19` {name} çıkarılsın mı?; `DLG-20` Rol değişsin mi?; `DLG-21` Başkanlığı devret?

<details><summary><b>Toast (6)</b></summary>

| ID | Tür | Metin (TR) | Aksiyon etiketi | Kalıcı |
|---|---|---|---|---|
| `TST-29` | success | Dışa aktarma hazır. Dosya indirildi. | — | — |
| `TST-46` | success | Ayşe Demir artık …. | — | — |
| `TST-47` | info | Ayşe Demir kulüpten çıkarıldı. | Geri al | — |
| `TST-49` | success | Başkanlık Ayşe Demir kullanıcısına devredildi. | — | — |
| `TST-X18` | info | Bu işlem için yetkin yok. | — | — |
| `TST-X20` | info | Onaylamak için DEVRET yaz. | — | — |

</details>

**Bağlama notları:**
- CLB-06 üye menüsü (T-18), DLG-09 (T-16), SET-03 (T-29) giriş noktaları gerçek

**Task'a özel testler:**
- hiyerarşi: board yalnız member çıkarır; president hariç herkesi; president çıkarılamaz
- devir sonrası roller
- CSV içeriği

*Referans:* `design/reference-shots/screens/` altında bu ekranların açık/koyu/EN görüntüleri; durum görüntüleri `states/`.

#### T-34 — Etkinlik yönetimi ve oluşturma

**Hedef.** MGT-04 (yaklaşan/taslak/geçmiş/iptal), MGT-05 (form: tür, tarih/saat, mekân, kontenjan, görünürlük, kapak, hatırlatıcı; taslak/yayın), etkinlik menüsü, yayın/iptal/taslağa alma/kopyala/taslak silme.

**Bağımlılıklar:** T-31, T-24  
**Ön koşul soruları:** —

| Ekran | Ad (TR / EN) | Yol | Sekme | Roller | Aksiyon | Not |
|---|---|---|---|---|---|---|
| `MGT-04` | Etkinlik yönetimi / Event management | `/manage/:clubId/events` | clubs | manager | 10 |  |
| `MGT-05` | Etkinlik oluştur / Create event | `/manage/:clubId/events/new` | clubs | manager | 10 |  |

**Sheet / menü:** `SHT-23` Etkinlik menüsü; `SHT-30` Mekân seç; `SHT-31` Kapak seç

**Dialog:** `DLG-22` Etkinlik yayınlansın mı?; `DLG-23` Etkinlik iptal edilsin mi?; `DLG-31` Taslak silinsin mi?

<details><summary><b>Toast (4)</b></summary>

| ID | Tür | Metin (TR) | Aksiyon etiketi | Kalıcı |
|---|---|---|---|---|
| `TST-30` | success | Etkinlik yayınlandı. | Görüntüle | — |
| `TST-48` | info | Etkinlik iptal edildi. Katılımcılara haber verildi. | — | — |
| `TST-X15` | info | Kayıtlar kapatıldı. | — | — |
| `TST-X19` | success | Etkinlik taslağa alındı. | — | — |

</details>

**Bileşenler / sınıflar:** `EventForm`, `CoverPickerContent`

**Bağlama notları:**
- SHT-23 yönetici satırları: Katılımcılar/Yoklama/QR → MGT-06, MGT-07 → T-35
- MGT-05 tarih (SHT-28, T-24) ve saat (SHT-29, T-26) seçicileri yeniden kullanır

**Task'a özel testler:**
- form doğrulama (bitiş > başlangıç, kontenjan ≥ goingCount)
- yayın bildirimi sayısı
- taslak silme yalnız taslak
- kopya +7 gün
- matris

*Referans:* `design/reference-shots/screens/` altında bu ekranların açık/koyu/EN görüntüleri; durum görüntüleri `states/`.

#### T-35 — Katılımcılar, yoklama ve QR tarayıcı

**Hedef.** MGT-06 (özet çipleri, yoklama %, arama, Katıldı anahtarı, bekleyeni kayıtlıya al, tümünü katıldı yap), MGT-07 (kamera, flaş, kamera çevir, manuel kod, izin yeniden dene, sonuç sheet'i, 2 sn oto-kapanma), canlı bilet güncellemesi.

**Bağımlılıklar:** T-34, T-23  
**Ön koşul soruları:** —

| Ekran | Ad (TR / EN) | Yol | Sekme | Roller | Aksiyon | Not |
|---|---|---|---|---|---|---|
| `MGT-06` | Katılımcılar ve yoklama / Attendees & check-in | `/manage/:clubId/events/:id/attendance` | clubs | manager | 61 |  |
| `MGT-07` | QR tarayıcı / QR scanner | `/manage/:clubId/events/:id/scan` | clubs | manager | 7 | kamera ekranı → açık ikonlar |

**Sheet / menü:** `SHT-24` Tarama sonucu

<details><summary><b>Toast (3)</b></summary>

| ID | Tür | Metin (TR) | Aksiyon etiketi | Kalıcı |
|---|---|---|---|---|
| `TST-31` | success | Ayşe Demir katıldı olarak işaretlendi. | Geri al | — |
| `TST-X13` | success | Ayşe Demir kayıtlıya alındı. | — | — |
| `TST-X14` | info | Kontenjan dolu; önce yer açılmalı. | — | — |

</details>

**Bileşenler / sınıflar:** `AttendeeRow`, `ScannerOverlay`

**Bağlama notları:**
- MGT-07 demo tarama düğmeleri UYGULANMAZ (K-02/K-04)

**Task'a özel testler:**
- QR içeriği gu:ticket:v1 ayrıştırma
- Geçerli/Zaten okutulmuş/Geçersiz sonuçları
- yoklama penceresi
- kamera izni reddi
- durum çubuğu açık-ikon

*Referans:* `design/reference-shots/screens/` altında bu ekranların açık/koyu/EN görüntüleri; durum görüntüleri `states/`.

#### T-36 — İçerik yönetimi ve kulüp ayarları

**Hedef.** MGT-08 (gönderi/duyuru/anket listeleri, sabitle, düzenle, sil), MGT-09 (logo/kapak, kısa/uzun açıklama, koşullar, sosyal bağlantılar, başvuru anahtarları, kilitli ad), kategori seçici.

**Bağımlılıklar:** T-31, T-21  
**Ön koşul soruları:** —

| Ekran | Ad (TR / EN) | Yol | Sekme | Roller | Aksiyon | Not |
|---|---|---|---|---|---|---|
| `MGT-08` | İçerik yönetimi / Content management | `/manage/:clubId/content` | clubs | manager | 17 |  |
| `MGT-09` | Kulüp ayarları / Club settings | `/manage/:clubId/settings` | clubs | manager | 15 |  |

**Sheet / menü:** `SHT-33` Kategori seç

**Task'a özel testler:**
- kilitli ad → TST-20
- başvuru kapatma → TST-54 (T-32'de tanımlı, yeniden kullanılır)
- kaydedilmemiş değişiklik
- sabitleme tek gönderi

*Referans:* `design/reference-shots/screens/` altında bu ekranların açık/koyu/EN görüntüleri; durum görüntüleri `states/`.

---

### Faz G — Süper admin

#### T-37 — Süper admin arka ucu ve betik

**Hedef.** AdminRepository (kulüp oluştur/askıya al/aktifleştir, başkan ata, şikayet çöz (grup), kullanıcı askıya al/kaldır, istatistikler), tool/admin/set_superadmin.js, claim yenileme, ilgili Rules + testleri.

**Bağımlılıklar:** T-30  
**Ön koşul soruları:** Q-09

**Veri / servis:** `AdminRepository`

**Firestore Rules kapsamı:** `clubs (süper)`, `reports (çözüm)`, `users (askı)`, `private (collectionGroup)`

**Task'a özel testler:**
- claim olmadan hiçbir admin işlemi geçmez
- grup çözümü tek batch
- askıdaki kulüp/kullanıcı davranışı

#### T-38 — Admin genel bakış

**Hedef.** ADM-01 (KPI, grafik, en aktif kulüpler, bekleyen şikayetler).

**Bağımlılıklar:** T-37  
**Ön koşul soruları:** —

| Ekran | Ad (TR / EN) | Yol | Sekme | Roller | Aksiyon | Not |
|---|---|---|---|---|---|---|
| `ADM-01` | Admin / Admin | `/admin` | admin | admin | 31 |  |

**Bağlama notları:**
- ADM-01 hızlı eylem: Kulüpler → ADM-02 → T-39
- ADM-01 şikayetler → ADM-04 → T-40
- ADM-01 kullanıcılar → ADM-05 → T-41

**Task'a özel testler:**
- sayılar kaynakla tutarlı
- matris

*Referans:* `design/reference-shots/screens/` altında bu ekranların açık/koyu/EN görüntüleri; durum görüntüleri `states/`.

#### T-39 — Admin kulüpler ve kulüp oluşturma

**Hedef.** ADM-02 (liste, arama, menü, askıya al/aktifleştir), ADM-03 (kulüp oluştur/düzenle: ad benzersizliği, kategori, ikon, palet/desen, başkan ata, danışman — G-1).

**Bağımlılıklar:** T-37, T-36  
**Ön koşul soruları:** Q-09

| Ekran | Ad (TR / EN) | Yol | Sekme | Roller | Aksiyon | Not |
|---|---|---|---|---|---|---|
| `ADM-02` | Kulüpler / Clubs | `/admin/clubs` | admin | admin | 34 |  |
| `ADM-03` | Kulüp oluştur / Create club | `/admin/clubs/new` | admin | admin | 13 |  |

**Dialog:** `DLG-28` {club} askıya alınsın mı?

<details><summary><b>Toast (2)</b></summary>

| ID | Tür | Metin (TR) | Aksiyon etiketi | Kalıcı |
|---|---|---|---|---|
| `TST-33` | success | Kulüp oluşturuldu. | — | — |
| `TST-50` | info | Kulüp yeniden etkinleştirildi. | — | — |

</details>

**Task'a özel testler:**
- ad benzersizliği
- başkan ata → üyelik + presidentId tutarlılığı
- askı → kulüp kartı ve etkinlik gizleme

*Referans:* `design/reference-shots/screens/` altında bu ekranların açık/koyu/EN görüntüleri; durum görüntüleri `states/`.

#### T-40 — Admin şikayetler

**Hedef.** ADM-04 (sekmeler, süzgeçler, gruplama), şikayet detayı, içerik kaldırma, kullanıcı askı diyaloğu, şikayet kapatma.

**Bağımlılıklar:** T-37  
**Ön koşul soruları:** —

| Ekran | Ad (TR / EN) | Yol | Sekme | Roller | Aksiyon | Not |
|---|---|---|---|---|---|---|
| `ADM-04` | Şikayetler / Reports | `/admin/reports` | admin | admin | 17 |  |

**Sheet / menü:** `SHT-26` Şikayet detayı

**Dialog:** `DLG-29` İçerik kaldırılsın mı?; `DLG-30` {name} askıya alınsın mı?

<details><summary><b>Toast (3)</b></summary>

| ID | Tür | Metin (TR) | Aksiyon etiketi | Kalıcı |
|---|---|---|---|---|
| `TST-51` | success | İçerik kaldırıldı. | — | — |
| `TST-52` | info | Kullanıcının askısı kaldırıldı. | — | — |
| `TST-56` | info | Şikayet kapatıldı. | — | — |

</details>

**Task'a özel testler:**
- aynı hedefin çoklu şikayeti tek grup
- çözüm tüm açık belgeleri çözer
- report_resolved bildirimi

*Referans:* `design/reference-shots/screens/` altında bu ekranların açık/koyu/EN görüntüleri; durum görüntüleri `states/`.

#### T-41 — Admin kullanıcılar

**Hedef.** ADM-05 (arama: ad + e-posta, süzgeçler: yöneticiler/askıdakiler, askıya alma [DLG-30, T-40] / askıyı kaldırma [TST-52, T-40], kullanıcı profili CLB-07'ye geçiş).

**Bağımlılıklar:** T-37, T-40  
**Ön koşul soruları:** —

| Ekran | Ad (TR / EN) | Yol | Sekme | Roller | Aksiyon | Not |
|---|---|---|---|---|---|---|
| `ADM-05` | Kullanıcılar / Users | `/admin/users` | admin | admin | 168 |  |

**Task'a özel testler:**
- e-posta araması collectionGroup
- askıya alınan kullanıcı giriş yapamaz

*Referans:* `design/reference-shots/screens/` altında bu ekranların açık/koyu/EN görüntüleri; durum görüntüleri `states/`.

---

### Faz H — Sertleştirme ve yayın

#### T-42 — Cloud Functions (Mod F) *(koşullu: Q-02 = Functions (Blaze))*

**Hedef.** functions/ (TypeScript): bildirim tetikleyicileri, FCM push (tercih + sessiz saat), zamanlanmış etkinlik hatırlatıcısı, bekleme listesi otomatik terfisi, (Q-11'e göre) hesap silme temizliği; emülatör testleri; deploy YALNIZCA kullanıcı onayıyla.

**Bağımlılıklar:** T-25, T-22, T-29  
**Ön koşul soruları:** Q-02, Q-07, Q-11

**Task'a özel testler:**
- her tetikleyici emülatörde
- tercih/sessiz saat
- idempotensi

#### T-43 — Bütünleme: bağlama borçları, durumlar, tam matris

**Hedef.** Tüm 'wires' girişlerinin gerçek olduğunu doğrula; yer tutucu/Placeholder/TODO taraması; 5 durumun tüm listelerde doğrulanması; tam cihaz matrisi (51 ekran + 34 sheet + 32 dialog); aksiyon envanteri tam (1072 − muaflar); ARB 1235 eşit/kullanılmayan yok; erişilebilirlik taraması.

**Bağımlılıklar:** T-41  
**Ön koşul soruları:** —

**Task'a özel testler:**
- check_design_coverage --all
- tam matris
- wiring borcu = 0

#### T-44 — Performans ve hata yönetimi doğrulaması

**Hedef.** Soğuk açılış, liste kaydırma, kapak/desen SVG maliyeti, bellek, Crashlytics sahte hata ile doğrulama, ErrorWidget üretim davranışı, çevrimdışı senaryoları (Q-12).

**Bağımlılıklar:** T-43  
**Ön koşul soruları:** Q-12

**Task'a özel testler:**
- profil çıktısı (kullanıcıya)
- çevrimdışı yazma engeli TST-24

#### T-45 — Güvenlik gözden geçirme

**Hedef.** Rules tam matris + bütçe ölçümü, alan beyaz listeleri, sızıntı testleri (e-posta, gizli kaynak), bağımlılık taraması, gizli bilgi taraması, Mod C spam sınırlaması raporu; gu-firebase-security-reviewer ajanı.

**Bağımlılıklar:** T-43  
**Ön koşul soruları:** —

**Task'a özel testler:**
- firebase/test tam
- secrets taraması

#### T-46 — Mağaza ve yayın hazırlığı

**Hedef.** Uygulama ikonu/splash, izin metinleri (TR/EN), mağaza metinleri, gizlilik/KVKK bağlantıları, Apple 5.1.1(v) hesap silme netleştirme, sürümleme, imzalama, yayın kontrol listesi — kullanıcıyla birlikte; gerçek projeye deploy yalnızca onayla.

**Bağımlılıklar:** T-44, T-45  
**Ön koşul soruları:** Q-03, Q-11, Q-18

**Task'a özel testler:**
- release build derlenir
- kontrol listesi

#### T-47 — Teslim

**Hedef.** README, kurulum ve çalıştırma kılavuzu, bilinen sınırlamalar (rules-spec §9), docs/progress.json son durum, katkı notları, son tam kalite kapısı.

**Bağımlılıklar:** T-46  
**Ön koşul soruları:** —

**Task'a özel testler:**
- quality_gate tam yeşil

---

## 5. Bağlama borçları (wiring debt)

Bir task, sahibi **sonraki** bir task olan ekrana/sheet'e giden bir giriş noktası içeriyorsa o noktayı **uygulamaz**; `docs/progress.json#pendingWiring` altına işler. Borcu kapatan task, plan adımında 'bu task hangi borçları kapatır' bölümünü doldurur; commit'te ilgili `W-xx` `status: closed` olur. **T-43 başlangıcında açık borç sayısı 0 olmalıdır** (`node tool/check_design_coverage.js --wiring`).

| Borç | Açan | Not | Kapanacağı task |
|---|---|---|---|
| W-01 | T-11 | AppRedirect hedefi ONB-01 ve AUT-01 yer tutucu → T-13 | T-13 |
| W-02 | T-11 | AppRedirect hedefi AUT-03 ve AUT-05 yer tutucu → T-14 | T-14 |
| W-03 | T-11 | askıya alınmış hesap açılışında DLG-01 → T-13 | T-13 |
| W-05 | T-13 | AUT-01 'Şifremi unuttum' → AUT-04 → T-14 | T-14 |
| W-06 | T-13 | AUT-02 kayıt sonrası e-posta doğrulama → AUT-03 → T-14 | T-14 |
| W-09 | T-14 | SHT-16 çoklu görsel sınırı (maxImages) parametresi hazır; TST-X5 sınırı FED-03 ile → T-21 | T-21 |
| W-10 | T-16 | CLB-03 'Gönderiler' sekmesi içeriği → T-20 (FED-01) | T-20 |
| W-11 | T-16 | 'Üye listesi' → T-18 | T-18 |
| W-12 | T-16 | 'Yönetim paneli' (MGT-01) → T-31 | T-31 |
| W-13 | T-16 | 'Kulüp ayarları' (MGT-09) → T-36 | T-36 |
| W-14 | T-16 | DLG-09 → SHT-25 (başkanlık devri) → T-33 | T-33 |
| W-15 | T-16 | etkinlik satırı → EVT-02 → T-23 | T-23 |
| W-16 | T-16 | yazı oluştur → FED-03 → T-21 | T-21 |
| W-17 | T-16 | 'Etkinlik oluştur' CTA → MGT-05 → T-34 | T-34 |
| W-18 | T-17 | CLB-01 → PRF-03 'Kulüplerim' → T-27 | T-27 |
| W-19 | T-17 | CLB-02 etkinlik sonuçları → EVT-02 → T-23 | T-23 |
| W-20 | T-18 | üye satırı menüsü SHT-21 → T-33 | T-33 |
| W-21 | T-18 | SHT-27 yorum satırları (Yorumu sil → DLG-11, Yorumu şikayet et) → T-20 | T-20 |
| W-24 | T-20 | FED-01 'yazı oluştur' → FED-03 → T-21 | T-21 |
| W-25 | T-20 | SHT-08 'Düzenle' → FED-03 düzenleme modu → T-21 | T-21 |
| W-26 | T-21 | SHT-18 varsayılan davranışı (onSelect verilmezse) → MGT-01 → T-31 | T-31 |
| W-27 | T-23 | yönetici düğmeleri: Düzenle (MGT-05) → T-34, Katılımcılar/Yoklama (MGT-06/07) → T-35 | T-34, T-35 |
| W-28 | T-26 | application_received → MGT-02/SHT-19 → T-32 | T-32 |
| W-29 | T-26 | new_report → ADM-04/SHT-26 → T-40 | T-40 |
| W-30 | T-26 | system/varsayılan bildirim → SET-04 → T-28 | T-28 |
| W-31 | T-27 | yönetilen kulüp → MGT-01 → T-31 | T-31 |
| W-32 | T-27 | PRF-01 ayarlar girişi → SET-01 → T-28 | T-28 |
| W-33 | T-28 | SET-01 'Hesabımı sil' → SET-03 → T-29 | T-29 |
| W-34 | T-29 | başkan ise → devir akışı MGT-03/SHT-25 → T-33 | T-33 |
| W-36 | T-31 | MGT-01 hızlı eylem: Başvurular → MGT-02 → T-32 | T-32 |
| W-37 | T-31 | MGT-01 hızlı eylem: Üyeler → MGT-03 → T-33 | T-33 |
| W-38 | T-31 | MGT-01 hızlı eylem: Etkinlikler/Etkinlik oluştur → MGT-04, MGT-05 → T-34 | T-34 |
| W-39 | T-31 | MGT-01 hızlı eylem: Yoklama → MGT-06 → T-35 | T-35 |
| W-40 | T-31 | MGT-01 hızlı eylem: İçerik/Kulüp ayarları → MGT-08, MGT-09 → T-36 | T-36 |
| W-42 | T-34 | SHT-23 yönetici satırları: Katılımcılar/Yoklama/QR → MGT-06, MGT-07 → T-35 | T-35 |
| W-45 | T-38 | ADM-01 hızlı eylem: Kulüpler → ADM-02 → T-39 | T-39 |
| W-46 | T-38 | ADM-01 şikayetler → ADM-04 → T-40 | T-40 |
| W-47 | T-38 | ADM-01 kullanıcılar → ADM-05 → T-41 | T-41 |

**Uygulanmayan (kasıtlı) noktalar:**
- W-04 (T-13): AUT-01 demo hesap bölümü UYGULANMAZ (K-02)
- W-07 (T-14): AUT-03 'Doğrulandı simüle et' UYGULANMAZ (K-02)
- W-44 (T-35): MGT-07 demo tarama düğmeleri UYGULANMAZ (K-02/K-04)

## 6. Her task için ortak 'Bitti' tanımı

- [ ] Task planı kullanıcı tarafından onaylandı (plan modu çıkışı).
- [ ] Kapsamdaki tüm ekran/sheet/dialog/toast kimlikleri uygulandı; her sınıfın üstünde `/// Design: <ID>` izi var; toast'lar `ToastId` enum'unda.
- [ ] Aksiyon envanteri: ekrandaki `GuKey.action` kümesi `screens-actions.json` ile eşit (muaflar hariç) — `check_design_coverage.js --task T-xx --actions`.
- [ ] Davranış: her aksiyon beklenen rota/sheet/dialog/toast/durum sonucunu üretiyor (widget testi).
- [ ] Beş durum (yükleniyor/boş/hata/çevrimdışı/dolu) listeli ekranlarda test edildi.
- [ ] Cihaz matrisi (320/390/430/tablet × açık/koyu × TR/EN × ölçek 1.0/1.3/1.6) yeşil; taşma yok; durum çubuğu ikon rengi doğru.
- [ ] Golden dosyaları (Q-16 kapsamı) üretildi; `gu-design-fidelity-reviewer` referans görüntüyle karşılaştırdı, fark yok ya da K-xx olarak kayıtlı.
- [ ] Hardcode yok (metin → ARB, renk/boy → token, sayı → sabit); tekrarlı widget yok; yeni ortak widget `docs/widget-catalog.md`'de.
- [ ] Hard delete yok (`check_no_hard_delete.sh`); yeni yazma yolu varsa Rules + indeks + Rules testi aynı commit'te.
- [ ] `tool/quality_gate.sh --task T-xx` tam yeşil; inceleme ajanları (mimari, tasarım uyumu, Rules, test denetimi) kritik bulgusuz.
- [ ] `docs/progress.json`, `docs/decisions.md` (değişen/yeni karar), bağlama borçları güncel.
- [ ] Conventional Commit + task ID (Türkçe açıklama); `git push` yok.
- [ ] Kullanıcıya Türkçe kısa özet: ne yapıldı, sonuç, açık borç/risk, bir sonraki task.

## 7. Soru → task eşlemesi

Soru bankası: `prompts/01-soru-bankasi.md`. Cevaplar `docs/decisions.md` Q tablosuna ve `progress.json#questionsAnswered`'a yazılır. Aşağıdaki task'lar ilgili soru cevaplanmadan **planlanamaz** (başlatma turunda hepsi sorulur).

| Soru | Etkilediği task'lar |
|---|---|
| Q-01 | T-10 |
| Q-02 | T-22, T-25, T-42 |
| Q-03 | T-00, T-10, T-46 |
| Q-04 | T-12 |
| Q-06 | T-10 |
| Q-07 | T-22, T-23, T-25, T-42 |
| Q-08 | T-06 |
| Q-09 | T-15, T-30, T-37, T-39 |
| Q-10 | T-15, T-19, T-21 |
| Q-11 | T-29, T-42, T-46 |
| Q-12 | T-11, T-44 |
| Q-13 | T-00, T-11 |
| Q-14 | T-01, T-28 |
| Q-16 | T-02 |
| Q-17 | T-00 |
| Q-18 | T-00, T-46 |
| Q-19 | T-14, T-19, T-21, T-28 |

Task'a doğrudan bağlanmayan (genel/mimari) sorular: Q-05, Q-15, Q-20.

## 8. Task planı şablonu (plan modunda doldurulur)

```
# T-xx — <başlık>
1. Kapsam: kimlikler (ekran/sheet/dialog/toast), bileşenler, veri, Rules
2. Okunan kaynaklar: docs/… bölümleri, reference-shots dosyaları, prototip dosyaları
3. Yeniden kullanılan widget'lar (widget-catalog) / yeni widget'lar (neden mevcutlar yetmiyor)
4. Dosya listesi (oluşturulacak/değişecek) — katman katman
5. Durum modeli: State sınıfları, ViewModel metotları, repository çağrıları
6. Rota/geçiş: navigation.md satırları, kabuk görünürlüğü, durum çubuğu
7. ARB anahtarları (mevcut mu / eksik mi)
8. Test planı: widget/golden/matris/aksiyon envanteri/Rules/servis
9. Bağlama borçları: açılan / kapanan (W-xx)
10. Riskler ve açık sorular (AskUserQuestion ile sorulacaklar)
11. Bitti kontrol listesi (roadmap §6) ve commit planı
```

