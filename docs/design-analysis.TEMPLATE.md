# Tasarım Analizi — `docs/design-analysis.md`

> **Bu bir ŞABLONDUR** (`docs/design-analysis.TEMPLATE.md`). `docs/design-analysis.md` olarak kopyala, her yerini doldur. Tarifi: `prompts/03-faz1-tasarim-analizi.md`.
>
> **Ön-doldurulmuş hücreler İPUCUDUR, kanıt değildir.** Her satırı prototip kaynağını (`design/prototype/app/*.js`), `design/extracted/component-css.css` ve `design/reference-shots/` görüntülerini **açarak doğrula**; yanlışı düzelt, eksiği ekle.
>
> **`⟂` = doldurulmamış hücre.** `node tool/progress.js gate analysis` içinde herhangi bir `⟂` kaldıysa onay verilmez. Bir hücre gerçekten uygulanamazsa `⟂` yerine **gerekçe** yaz ("tasarımda yok: …", "birleştirildi → X").
>
> Şablonda olmayan bileşen bulursan **satır ekle** (numarayı `A+1` ver). Kapsam dışı (prototip maketi) olanları §A.3'e gerekçesiyle yaz.
>
> Kurallar: hardcode yok (CLAUDE.md §1) · tekrar eden widget yok (D-16) · tasarımda olmayan durum uydurulmaz · token adları `registry.json#tokens` ile birebir.

## 0. Özet (en son doldur)

| Metrik | Değer |
|---|---|
| Bileşen satırı (A.1) | ⟂ |
| Birleştirme önerisi (G) | ⟂ |
| Yeni bulgu (K-24…) | ⟂ |
| Roadmap içerik değişikliği (J) | ⟂ |
| Kullanıcıya sorulan soru | ⟂ |

## A. Bileşen envanteri

### A.1 Kimlik tablosu (ön-doldurulmuş)

`Ekran#` = bileşenin CSS sınıflarının kullanıldığı **ekran sayısı**, `Toplam` = sınıf kullanım toplamı (`css-class-usage.json`; yaklaşık, ipucu — `.tile`, `.is-selected`, `.card` gibi **genel sınıflar sayıyı şişirir**; gerçek kullanım yeri için `grep` ile bileşen çağrısını ara, A.2'ye ekran **ID**'leriyle yaz). Sınıfı olmayan bileşenlerde `—`.

| # | Prototip | Kaynak (dosya:satır) | CSS sınıfları | Ekran# | Toplam | Flutter adı (öneri) | Konum | Task |
|---|---|---|---|---|---|---|---|---|
| 1 | Button | `design/prototype/app/ui.js:9` | `.btn` `.btn-primary` `.btn-tonal` `.btn-outline` `.btn-text` `.btn-danger-outline` `.btn-danger` `.btn-ghost` `.btn-sm` `.btn-lg` `.btn-full` | 31 | 263 | GuButton | gu_ui | T-04 |
| 2 | IconButton | `design/prototype/app/ui.js:17` | `.iconbtn` `.is-brand` `.badge-count` | 47 | 257 | GuIconButton | gu_ui | T-04 |
| 3 | Spinner | `design/prototype/app/ui.js:7` | `.spinner` | — | — | GuSpinner (roadmap'te ayrı sınıf yok → §H) | gu_ui | T-04 |
| 4 | Input | `design/prototype/app/ui.js:22` | `.field` `.field-label` `.field-help` `.field-counter` `.input` `.is-multiline` `.is-readonly` `.in-icon` | 20 | 151 | GuInput | gu_ui | T-05 |
| 5 | Picker | `design/prototype/app/ui.js:36` | `.picker` | 4 | 5 | GuPickerField | gu_ui | T-05 |
| 6 | Switch | `design/prototype/app/ui.js:42` | `.switch` | 5 | 64 | GuSwitch | gu_ui | T-05 |
| 7 | Checkbox | `design/prototype/app/ui.js:46` | `.check` | 1 | 1 | GuCheckbox | gu_ui | T-05 |
| 8 | Radio | `design/prototype/app/ui.js:47` | `.radio` | — | — | GuRadio | gu_ui | T-05 |
| 9 | OptionRow | `design/prototype/app/ui.js:48` | `.tile` `.is-selected` `.trailing` | 30 | 555 | GuOptionRow (+ GuOptionCard) | gu_ui | T-05 |
| 10 | Chip | `design/prototype/app/ui.js:53` | `.chip` `.is-selected` | 17 | 108 | GuChip | gu_ui | T-04 |
| 11 | Segmented | `design/prototype/app/ui.js:58` | `.seg` | 11 | 12 | GuSegmented | gu_ui | T-05 |
| 12 | Tabs | `design/prototype/app/ui.js:61` | `.tabs` `.is-sticky` `.is-active` | 8 | 9 | GuTabs | gu_ui | T-05 |
| 13 | Badge | `design/prototype/app/ui.js:66` | `.badge` `.badge-neutral` `.badge-success` `.badge-danger` `.badge-pending` `.badge-info` `.badge-full` | 26 | 346 | GuBadge | gu_ui | T-04 |
| 14 | RoleBadge | `design/prototype/app/ui.js:67` | `.badge` `.badge-president` `.badge-board` `.badge-advisor` `.badge-member` `.badge-superadmin` | 26 | 371 | GuRoleBadge | gu_ui | T-04 |
| 15 | StatusBadge | `design/prototype/app/ui.js:68` | `.badge` `.badge-success` `.badge-danger` `.badge-neutral` `.badge-pending` `.badge-full` | 26 | 343 | GuStatusBadge | gu_ui | T-04 |
| 16 | Card | `design/prototype/app/ui.js:70` | `.card` `.card-body` `.is-tappable` `.is-muted` `.is-accent` `.pressable` | 23 | 194 | GuCard | gu_ui | T-04 |
| 17 | Tile | `design/prototype/app/ui.js:74` | `.tile` `.tile-text` `.trailing` `.in-card` `.is-plain` | 25 | 1039 | GuTile | gu_ui | T-04 |
| 18 | AppBar | `design/prototype/app/ui.js:79` | `.appbar` `.appbar-large` `.appbar-title` | 43 | 86 | GuAppBar | gu_ui | T-06 |
| 19 | Banner | `design/prototype/app/ui.js:86` | `.banner` `.banner-info` `.banner-warning` `.banner-danger` `.banner-text` | 3 | 9 | GuBanner | gu_ui | T-06 |
| 20 | Progress | `design/prototype/app/ui.js:92` | `.prog` `.is-thin` `.is-success` `.is-warning` `.is-danger` | 7 | 63 | GuProgress | gu_ui | T-04 |
| 21 | Donut | `design/prototype/app/ui.js:93` | — | — | — | GuDonut | gu_ui | T-04 |
| 22 | Skeleton / SkeletonList | `design/prototype/app/ui.js:94` | `.sk` | — | — | GuSkeleton | gu_ui | T-06 |
| 23 | EmptyState | `design/prototype/app/ui.js:100` | `.empty` `.ill` | 6 | 11 | GuEmptyState | gu_ui | T-06 |
| 24 | ErrorState | `design/prototype/app/ui.js:104` | `.empty` `.ill` | 6 | 11 | GuErrorState | gu_ui | T-06 |
| 25 | OfflineState | `design/prototype/app/ui.js:110` | `.empty` `.ill` | 6 | 11 | GuOfflineState | gu_ui | T-06 |
| 26 | ListState | `design/prototype/app/ui.js:115` | — | — | — | GuListState | gu_ui | T-06 |
| 27 | SectionTitle | `design/prototype/app/ui.js:122` | `.section-title` | 1 | 3 | GuSectionTitle | gu_ui | T-04 |
| 28 | ListEnd | `design/prototype/app/ui.js:123` | `.center` `.t-caption` | 42 | 286 | GuListEnd | gu_ui | T-06 |
| 29 | StickyCTA | `design/prototype/app/ui.js:124` | `.ctabar` `.in-nav` | 9 | 9 | GuStickyCta | gu_ui | T-06 |
| 30 | Stepbar | `design/prototype/app/ui.js:125` | `.stepbar` `.is-done` | 3 | 5 | GuStepbar | gu_ui | T-05 |
| 31 | DateBadge | `design/prototype/app/ui.js:126` | `.date-badge` | 4 | 20 | GuDateBadge | gu_ui | T-04 |
| 32 | KPI | `design/prototype/app/ui.js:127` | `.kpi` `.kpi-value` `.is-accent` `.pressable` | 4 | 47 | GuKpi | gu_ui | T-04 |
| 33 | Quick | `design/prototype/app/ui.js:128` | `.quick` `.quick-icon` `.pressable` | 4 | 35 | GuQuickAction | gu_ui | T-04 |
| 34 | UserRow | `design/prototype/app/ui.js:129` | `.tile` `.row` `.avatar` | 46 | 1275 | (Tile+Avatar bileşimi → birleştirme adayı, §G; roadmap: T-18 `UserRow`) | lib/product/widget/member/ | T-18 |
| 35 | MiniLineChart | `design/prototype/app/ui.js:133` | `.mini-chart` | 2 | 2 | GuMiniLineChart | gu_ui | T-04 |
| 36 | Calendar | `design/prototype/app/ui.js:140` | `.grid3` `.dot` `.is-active` | 5 | 8 | GuCalendar | gu_ui | T-06 |
| 37 | SuccessCheck | `design/prototype/app/ui.js:151` | `.circle-draw` `.check-draw` | 1 | 2 | GuSuccessCheck | gu_ui | T-06 |
| 38 | Scroll (yenile-çek) | `design/prototype/app/ui.js:154` | `.screen-scroll` `.no-safe` | 48 | 50 | GuRefresh | gu_ui | T-06 |
| 39 | SheetFrame | `design/prototype/app/ui.js:167` | `.sheet` `.scrim` | — | — | GuSheetFrame | gu_ui | T-07 |
| 40 | DialogFrame | `design/prototype/app/ui.js:182` | `.dialog` `.scrim` | — | — | GuDialogFrame | gu_ui | T-07 |
| 41 | PopMenu | `design/prototype/app/ui.js:191` | `.popmenu` | — | — | GuPopMenu | gu_ui | T-07 |
| 42 | Toast | `design/prototype/app/shell.js:20` | `.toast` | — | — | GuToast (+ToastHost) | gu_ui | T-07 |
| 43 | BottomNav | `design/prototype/app/shell.js:11` | — | — | — | GuBottomNav | gu_ui | T-06 |
| 44 | StatusBar | `design/prototype/app/shell.js:10` | — | — | — | (prototip cihaz maketi — yapılmaz; GuSystemUi) | — | T-07 |
| 45 | Icon | `design/prototype/app/icons.js:73` | `.in-icon` | 14 | 24 | GuIcon + GuIcons | gu_ui | T-03 |
| 46 | Avatar | `design/prototype/app/art.js:43` | `.avatar` | 21 | 366 | GuAvatar | gu_ui | T-04 |
| 47 | AvatarGroup | `design/prototype/app/art.js:48` | `.avatar-group` | 3 | 17 | GuAvatarGroup | gu_ui | T-04 |
| 48 | Logo | `design/prototype/app/art.js:63` | `.logo` `.emblem` | 16 | 46 | GuLogo | gu_ui | T-03 |
| 49 | Cover | `design/prototype/app/art.js:36` | `.cover` `.r16-9` `.r1-1` `.on-cover` `.parallax` | 9 | 82 | GuCover | gu_ui | T-03 |
| 50 | Illustration | `design/prototype/app/art.js:88` | `.ill` | 6 | 8 | GuIllustration | gu_ui | T-03 |
| 51 | ClubCTA | `design/prototype/app/cards.js:19` | `.card` `.btn` | 37 | 186 | lib/product/widget/club/ | ekran task'ı (T-16; roadmap bileşen listesinde adı yok → §H) | T-16 |
| 52 | ClubCard | `design/prototype/app/cards.js:28` | `.card` `.cover` | 22 | 129 | lib/product/widget/club/ | ekran task'ı (T-17) | T-17 |
| 53 | MyClubChip | `design/prototype/app/cards.js:41` | `.chip` | 17 | 92 | lib/product/widget/club/ | ekran task'ı (T-17; roadmap'te adı yok → §H) | T-17 |
| 54 | EventCard | `design/prototype/app/cards.js:68` | `.card` `.date-badge` | 23 | 113 | lib/product/widget/event/ | ekran task'ı (T-23) | T-23 |
| 55 | PollBlock | `design/prototype/app/cards.js:83` | `.poll-opt` `.prog` | 7 | 32 | lib/product/widget/post/ | ekran task'ı (T-20) | T-20 |
| 56 | ImageGrid | `design/prototype/app/cards.js:92` | `.img-grid` | 1 | 2 | lib/product/widget/post/ | ekran task'ı (T-20) | T-20 |
| 57 | PostCard | `design/prototype/app/cards.js:96` | `.card` `.heart` `.is-liked` `.more` | 21 | 119 | lib/product/widget/post/ | ekran task'ı (T-20) | T-20 |
| 58 | NotificationRow | `design/prototype/app/cards.js:139` | `.notif-row` `.notif-icon` `.notif-front` `.notif-under` `.ni-brand` `.ni-danger` `.ni-info` `.ni-neutral` `.ni-warning` | 6 | 73 | lib/product/widget/notification/ | ekran task'ı (T-26) | T-26 |
| 59 | MemberRow | `design/prototype/app/cards.js:165` | `.tile` `.avatar` | 34 | 719 | lib/product/widget/member/ | ekran task'ı (T-18) | T-18 |
| 60 | ApplicationRow | `design/prototype/app/cards.js:170` | `.tile` `.badge` | 32 | 592 | lib/product/widget/member/ | ekran task'ı (T-32) | T-32 |
| 61 | MgtHeader | `design/prototype/app/screens-manage.js:7` | `.appbar` | 43 | 43 | lib/product/widget/manage/ | ekran task'ı (T-31) | T-31 |
| 62 | ActivityRow | `design/prototype/app/screens-manage.js:34` | `.timeline` `.timeline-item` `.timeline-dot` `.timeline-line` `.timeline-rail` | 1 | 12 | lib/product/widget/manage/ | ekran task'ı (T-31) | T-31 |
| 63 | Wheel (tarih/saat tekerleği) | `design/prototype/app/sheets.js:137` | `.wheel` | — | — | GuWheelPicker (roadmap'te adı geçmiyor; `TimePickerSheet` T-26, `DatePickerSheet` T-24 kullanır → §H) | gu_ui | T-05? |

### A.2 Ayrıntı tablosu (doldur)

Her satır A.1 numarasıyla eşleşir. **Varyant / boyut** ve **Durumlar** sütunlarındaki metin koddan çıkarılan ipucudur.

| # | Varyant / boyut | Durumlar (tasarımda **kanıtlı** olanlar) | Token'lar | Kullanıldığı ekranlar (ID) | API taslağı (parametreler) | Referans görüntü |
|---|---|---|---|---|---|---|
| 1 | primary/tonal/outline/text/danger-outline/danger/ghost × sm/md/lg; icon, iconRight, iconOnly, full | default, pressed, focus, disabled (+onDisabledClick), loading | brand.*, state.danger*, r-*, motion-fast | ⟂ | ⟂ | states/ + ekran görüntüleri · ⟂ |
| 2 | size 24/…, small, onCover, brand, rozet sayacı | default, pressed, focus, disabled | bg.surface*, text.* | ⟂ | ⟂ | ⟂ |
| 3 | size | sürekli dönüş (reduced-motion?) | brand.primary | ⟂ | ⟂ | ⟂ |
| 4 | tek/çok satır, ikon, trailing, sayaç (≥%80), kilitli/salt-okunur, type password/email… | default, focus, filled, error, disabled, readOnly/locked, counter-over | border.*, state.danger, text.* | ⟂ | ⟂ | ⟂ |
| 5 | ikon, yardım, hata | default, pressed, error, disabled, doldurulmuş/yer tutucu | border.* | ⟂ | ⟂ | ⟂ |
| 6 | on/off | default, pressed, focus, disabled (+onDisabledClick) | brand.primary, bg.surface-muted | ⟂ | ⟂ | ⟂ |
| 7 | checked/unchecked | default, focus, disabled | brand.primary | ⟂ | ⟂ | ⟂ |
| 8 | checked/unchecked | default, focus, disabled | brand.primary | ⟂ | ⟂ | ⟂ |
| 9 | radio/checkbox, leading, trailing, alt metin | default, selected, pressed, disabled | border.*, brand.primary-container | ⟂ | ⟂ | ⟂ |
| 10 | seçilebilir, sayaçlı, kaldırılabilir (input chip), ikonlu | default, selected, pressed, disabled | brand.primary-container, r-full | ⟂ | ⟂ | ⟂ |
| 11 | 2–4 seçenek | default, selected, pressed | bg.surface-muted | ⟂ | ⟂ | ⟂ |
| 12 | sticky, scroll (K-05: kaydırılabilir) | default, active, pressed | brand.primary, border.* | ⟂ | ⟂ | ⟂ |
| 13 | kind: neutral/success/danger/pending/info/full; ikonlu | statik | state.*-container | ⟂ | ⟂ | ⟂ |
| 14 | 5 rol (ROLE_BADGE tablosu) | statik | brand.*, state.* | ⟂ | ⟂ | ⟂ |
| 15 | 21 durum (STATUS_BADGE tablosu) | statik | state.*-container | ⟂ | ⟂ | ⟂ |
| 16 | tappable, muted, highlight | default, pressed, focus | bg.surface, e1, r-md | ⟂ | ⟂ | ⟂ |
| 17 | leading, title, subtitle, sub2, trailing, chevron, danger, inCard, plain | default, pressed, disabled | text.*, border.soft | ⟂ | ⟂ | ⟂ |
| 18 | normal/large, surface, closeIcon, subtitle, titleNode, geri | default, scrolled? | bg.canvas, text.heading | ⟂ | ⟂ | ⟂ |
| 19 | info/warning/danger/offline/readonly/success; kapatılabilir, eylem | statik, dismissed | state.*-container | ⟂ | ⟂ | ⟂ |
| 20 | thin, kind | statik (0–100) | brand.primary, bg.surface-muted | ⟂ | ⟂ | ⟂ |
| 21 | size/stroke | animasyonlu dolum | brand.primary | ⟂ | ⟂ | ⟂ |
| 22 | daire, tile/card/… liste varyantı | shimmer | bg.surface-muted | ⟂ | ⟂ | states/*__loading · ⟂ |
| 23 | illustration, başlık, açıklama, CTA, ikincil eylem, compact | statik | text.* | ⟂ | ⟂ | states/*__empty · ⟂ |
| 24 | inline/tam; yeniden dene, ana sayfa | default, retry-busy | state.danger | ⟂ | ⟂ | states/*__error · ⟂ |
| 25 | tam ekran | default, shake (çevrimdışıyken yeniden dene) | text.* | ⟂ | ⟂ | states/*__offline · ⟂ |
| 26 | hata→yükleniyor→boş→dolu yöneticisi | 4 durum (+inline error) | — | ⟂ | ⟂ | states/ · ⟂ |
| 27 | alt metin, sağda metin eylemi | statik | text.heading | ⟂ | ⟂ | ⟂ |
| 28 | — | statik | text.muted | ⟂ | ⟂ | ⟂ |
| 29 | inNav (alt sekme çubuğunun üstü) | statik | bg.surface, e3? | ⟂ | ⟂ | ⟂ |
| 30 | step/total | statik | brand.primary | ⟂ | ⟂ | ⟂ |
| 31 | — | statik | brand.primary-container | ⟂ | ⟂ | ⟂ |
| 32 | accent, ikonlu, tıklanabilir | default, pressed | e1 | ⟂ | ⟂ | ⟂ |
| 33 | ikon + etiket | default, pressed, disabled | brand.primary-container | ⟂ | ⟂ | ⟂ |
| 34 | boyut 40, rozet, inCard, chevron, silinmiş kullanıcı | default, pressed | — | ⟂ | ⟂ | ⟂ |
| 35 | noktaya dokununca ipucu | default, seçili nokta | brand.primary | ⟂ | ⟂ | ⟂ |
| 36 | compact, min/max, noktalar (etkinlik günleri), Pazartesi başlangıç (TR) | default, bugün, seçili, diğer ay, devre dışı | brand.primary | ⟂ | ⟂ | ⟂ |
| 37 | size | çizim animasyonu | state.success | ⟂ | ⟂ | ⟂ |
| 38 | onRefresh; pull > 60 | idle, pulling, refreshing | — | ⟂ | ⟂ | ⟂ |
| 39 | full, flush, menu, footer, hideHeader, dirty (DLG-25) | sürükleyerek kapatma (>120), X, geri, dirty | e3, r-xl, overlay.scrim | ⟂ | ⟂ | reference-shots/sheets · ⟂ |
| 40 | danger, icon, dismissable | odak tuzağı, Esc | r-lg, overlay.scrim | ⟂ | ⟂ | reference-shots/dialogs · ⟂ |
| 41 | EVT-MENU | odak tuzağı | e2 | ⟂ | ⟂ | ⟂ |
| 42 | tür (info/success/warning/danger), undo/eylem, 4/6 sn | kuyruk (en çok 1) | state.* | ⟂ | ⟂ | reference-shots/toasts · ⟂ |
| 43 | 5 sekme (rol: admin yalnızca superadmin) | default, active, rozet | bg.surface, border.* | ⟂ | ⟂ | ⟂ |
| 44 | tema başına açık/koyu ikon | — | — | ⟂ | ⟂ | ⟂ |
| 45 | 130 Lucide, size/stroke/renk | statik | text.* | ⟂ | ⟂ | ⟂ |
| 46 | size, fotoğraf/baş harf (initials), seed rengi | statik, yükleniyor? | brand.* | ⟂ | ⟂ | ⟂ |
| 47 | max 4, +N | statik | — | ⟂ | ⟂ | ⟂ |
| 48 | emblem/…; placeholder | statik | — | ⟂ | ⟂ | ⟂ |
| 49 | palet × desen (26+4), oran 16:9 / 1:1 | statik | club palet token'ları | ⟂ | ⟂ | ⟂ |
| 50 | 12 çizim | statik | text.disabled | ⟂ | ⟂ | ⟂ |
| 51 | üyelik durumuna göre CTA | üye/başvuru/bekliyor/… | — | ⟂ | ⟂ | ⟂ |
| 52 | liste/ızgara | default, pressed | — | ⟂ | ⟂ | ⟂ |
| 53 | — | default, pressed | — | ⟂ | ⟂ | ⟂ |
| 54 | liste/öne çıkan | default, pressed, dolu, iptal | — | ⟂ | ⟂ | ⟂ |
| 55 | oy öncesi/sonrası, süresi dolmuş | default, voted, closed | — | ⟂ | ⟂ | ⟂ |
| 56 | 1–4+ görsel | statik | — | ⟂ | ⟂ | ⟂ |
| 57 | post/duyuru/anket | default, liked, saved, pinned | — | ⟂ | ⟂ | ⟂ |
| 58 | kategori ikonu, okunmamış, kaydırarak sil/okundu? | okunmuş/okunmamış | — | ⟂ | ⟂ | ⟂ |
| 59 | rol rozeti, eylem menüsü | default, pressed | — | ⟂ | ⟂ | ⟂ |
| 60 | başvuru durumu | beklemede/onay/ret | — | ⟂ | ⟂ | ⟂ |
| 61 | yönetim ekranları ortak başlığı | — | — | ⟂ | ⟂ | ⟂ |
| 62 | etkinlik günlüğü satırı | — | — | ⟂ | ⟂ | ⟂ |
| 63 | değerler listesi, snap | default, seçili | — | ⟂ | ⟂ | ⟂ |

### A.3 Kapsam dışı (prototip maketi — Flutter'da yapılmaz)

Gerekçeyle tut; ekle/çıkar:

| Prototip | Neden |
|---|---|
| `Device`, `Frame`, `Panel`, `SideMenu`, `Site` (`shell.js`) | Cihaz çerçevesi / prototip paneli / tanıtım sitesi — `design/prototype-only-arb/` ile aynı grup |
| `PermissionSim` (`dialogs.js`) | OS izin penceresi simülasyonu — gerçek izin istemi platformdan gelir |
| `StatusBar` (`shell.js`) | Cihaz durum çubuğu maketi — Flutter'da `GuSystemUi` (D-20) |
| `scan-view` / `scanline` / `qr` demo (EVT-03/MGT-07) | Demo tarama — `EXEMPT_ACTIONS` ile muaf; gerçek QR T-23/T-34'te |
| ⟂ | ⟂ |

## B. Yardımcılar (util)

Prototipte `GU.*` altında (`core.js`) bulunanlar. **Dart karşılığı · konum (`gu_data` \| `gu_ui` \| `lib/core`) · test**.

| Prototip | Kaynak | Ne yapar | Dart karşılığı | Konum | Test | Not |
|---|---|---|---|---|---|---|
| `cx` | core.js:414 | sınıf birleştirme | — (Flutter'da gerekmez) | — | — | kapsam dışı |
| `clamp` | core.js:415 | sayı sınırlama | `num.clamp` | — | — | yerleşik |
| `uid` | core.js:417 | ID üretimi | Firestore `doc().id` | `gu_data` | ⟂ | istemci üretimi yalnızca geçici anahtar için |
| `hashStr` / `mulberry32` / `rngFor` | core.js:418–420 | seed → rastgele (kapak/avatar) | `ClubSeed` / `stableHash` | ⟂ | ⟂ | Dart `String.hashCode` **kararlı değil** — FNV-1a yaz |
| `initials` | core.js:422 | baş harfler | `String.initials` ext | ⟂ | ⟂ | TR `İ/ı` |
| `slug` | core.js:423 | ASCII slug | `String.slugTr` ext | ⟂ | ⟂ | ğüşıöç eşleme |
| `copyText` / `fallbackCopy` | core.js:424–425 | panoya kopyala | `Clipboard.setData` | ⟂ | ⟂ | |
| `downloadBlob` / `downloadText` | core.js:426–427 | dosya indir | ⟂ | ⟂ | ⟂ | mobilde `share_plus`? (Q-xx) |
| `escapeHtml` | core.js:428 | HTML kaçışı | — | — | — | kapsam dışı |
| `startOfDay` / `today0` / `at` / `dayKey` / `isSameDay` / `dayDiff` | core.js:431–437 | gün aritmetiği | `DateTime` ext (İstanbul) | ⟂ | ⟂ | `Europe/Istanbul`, DST yok (UTC+3) |
| `fmt.*` (`date` `time` `dateShort` `dateLong` `dateTime` `monthYear` `monthShort` `weekdayShort` `range` `rel`) | core.js:626–638 | yerelleştirilmiş tarih/saat | `DateFormatter` / `intl` | ⟂ | ⟂ | göreli zaman ARB `time.*` anahtarları |
| `fmtNum` | core.js:447 | sayı biçimi | `NumberFormat` | ⟂ | ⟂ | |
| `icu` / `tFor` / `defineDictionary` | core.js:442–470 | ICU mesaj motoru | **`gen-l10n`** (yazılmaz) | — | — | ARB + `AppLocalizations`; kapsam dışı |
| `useForm` / `useBusy` / `useCountdown` / `useTicker` | core.js:646–674 | form / meşgul / geri sayım | ViewModel + mixin | ⟂ | ⟂ | §E |
| `useFocusTrap` | core.js:659 | odak tuzağı | `FocusTraversalGroup` | `gu_ui` | ⟂ | §E |
| TR küçük harf (`toLocaleLowerCase('tr')` kullanımları) | ⟂ | arama normalizasyonu | `String.trLower` | ⟂ | ⟂ | `I→ı`, `İ→i` |
| ⟂ | ⟂ | ⟂ | ⟂ | ⟂ | ⟂ | `grep -o "GU\.[a-zA-Z]*" design/prototype/app/*.js` ile kalanları tara |

## C. Extension'lar

| Extension | Pakette | Üyeler | Kapsam sınırı | Test |
|---|---|---|---|---|
| `BuildContext.gu` | `gu_ui` | `colors` `text` `spacing` `radius` `shadows` `motion` `sizes` | yalnızca tema token'ları (veri yok) | ⟂ |
| `BuildContext.l10n` | `lib/core` | `AppLocalizations.of(context)` | tek giriş noktası | ⟂ |
| `DateTime` (İstanbul) | ⟂ | ⟂ | ⟂ | ⟂ |
| `String` (`trLower`, `initials`, `slugTr`) | ⟂ | ⟂ | ⟂ | ⟂ |
| `num` / `int` (sayı/süre) | ⟂ | ⟂ | ⟂ | ⟂ |
| `List` / `Iterable` | ⟂ | ⟂ | ⟂ | ⟂ |

## D. Sabitler (tek kaynak)

Her sabit **tek dosyada** durur; ikinci kopya yasak. Prototipteki kaynak: `design/extracted/registry.json#constants` (+ `eventTypes`, `years`, `popularSearches`).

| Grup | İçerik | Dosya (öneri) | Paket | Test |
|---|---|---|---|---|
| Limitler (`Limits`) | ad/bio/başlık uzunlukları, görsel sayısı, anket seçenek sayısı, sayfa boyutu… | ⟂ | `gu_data` | ⟂ |
| Süreler | toast 4/6 sn, debounce, OTP bekleme, hareket (120/200/320 ms) | ⟂ | ⟂ | ⟂ |
| Regex'ler | e-posta, alan adı (`ogr.gumushane.edu.tr`, `gumushane.edu.tr`), şifre kuralı | ⟂ | ⟂ | ⟂ |
| Firestore adları | koleksiyon / alan adları (`docs/domain-model.md`) | ⟂ | `gu_data` | ⟂ |
| Rota adları / yolları | `ROUTE_PATH` karşılığı (typed routes) | ⟂ | `lib/product/navigation` | ⟂ |
| Kategori / ilgi / fakülte / bölüm / mekân / yıl / etkinlik türü | `registry.json#constants`, `eventTypes`, `years` | ⟂ | ⟂ | ⟂ |
| Remote Config anahtarları | ⟂ | ⟂ | ⟂ | ⟂ |
| ID enum'ları | `ScreenId` `SheetId` `DialogId` `ToastId` | ⟂ | `gu_ui`/`lib` | katalog testi |
| Demo hesaplar / seed | `demoAccounts`, `tool/seed/demo-data.json` (donuk) | — | emülatör seed | ⟂ |

## E. Mixin / taban sınıflar

| Ad | Sorumluluk | API taslağı | Konum | Test |
|---|---|---|---|---|
| `ProjectDependencyMixin` | GetIt erişimi (D-xx) | ⟂ | ⟂ | ⟂ |
| `AppProviderMixin` | Riverpod ortak davranış | ⟂ | ⟂ | ⟂ |
| Form doğrulama mixin'i | `useForm` karşılığı | ⟂ | ⟂ | ⟂ |
| Sayfalama mixin'i | sonsuz liste, `ListState` ile | ⟂ | ⟂ | ⟂ |
| Optimistik güncelleme mixin'i | ±1 sayaç, geri alma | ⟂ | ⟂ | ⟂ |
| Kaydedilmemiş değişiklik koruması | `dirty` → DLG-25 | ⟂ | ⟂ | ⟂ |
| Klavye / odak mixin'i | ⟂ | ⟂ | ⟂ | ⟂ |
| `GuKey` | test anahtarları (`GuKey.action('…')`) | ⟂ | `gu_ui` | ⟂ |
| `GuTapTarget` | min 44/48 dp dokunma hedefi | ⟂ | `gu_ui` | ⟂ |
| `GuSystemUi` | durum çubuğu / navigasyon çubuğu stili (D-20) | ⟂ | `gu_ui` | ⟂ |

## F. Token eşleme taslağı (→ `docs/token-map.md`)

Kaynak: `design/extracted/registry.json#tokens` (+ `colors/tokens.json`). Anlamsal adlar **registry'deki adlarla** birebir; uydurma ad yok.

| Grup | Sayı | Dart tipi | Not |
|---|---|---|---|
| Renk | 27 × 2 (açık/koyu) | `GuColors` (`ThemeExtension`, `lerp`) | `COLORS`, `COLOR_USAGE` |
| Tipografi | 11 stil | `GuTypography` | `TYPE_SCALE`; metin ölçeği `--ts` |
| Boşluk | 9 (`4…48`) | `GuSpacing`/`GuGap`/`GuInsets` | `SPACING` |
| Radius | 5 (`sm md lg xl full`) | `GuRadius` | `RADIUS` |
| Gölge | 4 (`e0…e3`) | `GuShadows` | `SHADOWS` |
| Hareket | 3 süre + 2 eğri | `GuMotion` | `MOTION` |
| Boyutlar | ⟂ | `GuSizes` | `component-css.css`'ten: btn, input, chip, tile, appbar, tabbar… yükseklikleri |

Açık işler: ⟂ (eşleşmeyen renk, iki farklı yükseklik, eksik token → §K).

## G. Tekrarlar ve birleştirme önerileri (D-16)

Aynı işi yapan ama farklı görünen/adlanan bileşenler. Her satıra **karar** yaz.

| Aday grup | Kanıt (kaynak/CSS) | Öneri | Gerekçe | Karar |
|---|---|---|---|---|
| `Tile` ↔ `UserRow` ↔ `MemberRow` ↔ `OptionRow` | ⟂ | ⟂ | ⟂ | ⟂ |
| `Badge` ↔ `StatusBadge` ↔ `RoleBadge` | ⟂ | ⟂ | ⟂ | ⟂ |
| `Card` ↔ `Tile.in-card` ↔ `KPI` | ⟂ | ⟂ | ⟂ | ⟂ |
| `EmptyState` ↔ `ErrorState` ↔ `OfflineState` | ⟂ | ⟂ | ⟂ | ⟂ |
| `Chip` ↔ `Segmented` ↔ `Tabs` | ⟂ | ⟂ | ⟂ | ⟂ |
| `Progress` ↔ `Stepbar` | ⟂ | ⟂ | ⟂ | ⟂ |
| ⟂ | ⟂ | ⟂ | ⟂ | ⟂ |

Tekrar bulunmadıysa: **"tekrar bulunmadı"** + karşılaştırma tablosu.

## H. Boşluklar (tasarımda var, roadmap'te adı yok / tersi)

Başlangıç adayları (doğrula):

| Aday | Durum | Öneri | Task |
|---|---|---|---|
| `Spinner` | `GuButton.loading` içinde kullanılıyor; roadmap'te ayrı sınıf yok | `GuSpinner` | T-04 |
| `Wheel` (tarih/saat tekerleği) | `sheets.js` — sheet'lerde tarih/saat seçimi | `GuWheelPicker` | T-05? (Q-xx) |
| `Timeline` (`timeline-*`) | etkinlik günlüğü / başvuru geçmişi | ⟂ | ⟂ |
| `Dots` / `onb-track` | onboarding sayfa göstergesi | ⟂ | ⟂ |
| `Fab` | ⟂ | ⟂ | ⟂ |
| `Parallax` kapak başlığı | ⟂ | ⟂ | ⟂ |
| `Divider` | `GuDivider` roadmap'te var; CSS `divider` | doğrula | T-04 |
| ⟂ | ⟂ | ⟂ | ⟂ |

## I. Adlandırma

- Dart sınıfları `Gu` önekli (yalnızca `gu_ui`); ürün widget'ları önek**siz** (`lib/product/widget/…`).
- Kaynak ↔ Dart ad eşlemesi tablosu: ⟂ (A.1'in "Flutter adı" sütunu yeterliyse "A.1" yaz).
- Çakışma / ikilik: ⟂

## J. Task dağılımı (T-01 … T-07) ve roadmap farkı

`docs/roadmap.md` task bölümlerindeki `Bileşenler / sınıflar` listeleriyle karşılaştır. Task sırası **değişmez**; yalnızca içerik dağılımı onayla düzeltilir.

| Task | Roadmap'teki bileşenler | Analizde eklenen | Analizde çıkan / birleşen | Not |
|---|---|---|---|---|
| T-01 | `GuColors` `GuTypography` `GuSpacing` `GuRadius` `GuShadows` `GuMotion` `GuSizes` `GuTheme` `context.gu` | ⟂ | ⟂ | ⟂ |
| T-02 | `GuKey` `test/helpers/*` | ⟂ | ⟂ | ⟂ |
| T-03 | `GuIcon` `GuIcons` `GuLogo` `GuIllustration` `GuCover` `ClubPalette` `ClubPattern` | ⟂ | ⟂ | ⟂ |
| T-04 | `GuButton` `GuIconButton` `GuChip` `GuBadge` `GuRoleBadge` `GuStatusBadge` `GuAvatar` `GuAvatarGroup` `GuDivider` `GuSectionTitle` `GuCard` `GuTile` `GuProgress` `GuDonut` `GuKpi` `GuQuickAction` `GuDateBadge` `GuMiniLineChart` `GuTapTarget` | ⟂ | ⟂ | ⟂ |
| T-05 | `GuInput` `GuPickerField` `GuSwitch` `GuCheckbox` `GuRadio` `GuOptionRow` `GuOptionCard` `GuSegmented` `GuTabs` `GuSearchField` `GuStepbar` `GuStepper` | ⟂ | ⟂ | ⟂ |
| T-06 | `GuSkeleton` `GuEmptyState` `GuErrorState` `GuOfflineState` `GuListState` `GuBanner` `GuListEnd` `GuAppBar` `GuStickyCta` `GuBottomNav` `GuSuccessCheck` `GuCalendar` `GuRefresh` | ⟂ | ⟂ | ⟂ |
| T-07 | `GuSheetFrame` `GuDialogFrame` `GuPopMenu` `GuToast` `FeedbackService` `SheetId` `DialogId` `ToastId` `GuSystemUi` `GuPageTransitions` `GuTextScale` | ⟂ | ⟂ | ⟂ |

Yardımcı / extension / sabit / mixin dağılımı (B–E): hangi task'ta yazılır → ⟂

## K. Riskler ve yeni bulgular

- Tasarımın kendi içinde çelişen / eksik yerleri → `docs/design-known-issues.md`'ye **K-24…** olarak da ekle (K-01…K-23 mevcut; yeni numara K-24'ten).
- Performans riskleri (ağır SVG kapaklar, uzun listeler, golden süresi): ⟂
- Erişilebilirlik riskleri (kontrast, dokunma hedefi, metin ölçeği 1.6): ⟂
- Açık sorular (kullanıcıya `AskUserQuestion`): ⟂

| Bulgu | Kanıt | Etki | Öneri | K-no |
|---|---|---|---|---|
| ⟂ | ⟂ | ⟂ | ⟂ | K-24 |

## L. Doğrulama stratejisi (bileşen bazlı)

| Katman | Plan |
|---|---|
| Durum testleri | A.2'de "kanıtlı" durumların hepsi; tasarımda olmayan durum test edilmez |
| Golden | açık + koyu, TR; token testi `registry.json`'dan okunur |
| Matris | `GU_MATRIX=fast\|full` (`docs/testing.md`) |
| Dokunma hedefi | `GuTapTarget` ≥ 44 dp |
| Anlamsal etiket | ikon-düğmeler dahil, `Semantics` |
| Token testi okuyacağı dosyalar | ⟂ |

## M. Çıktılar (kontrol listesi)

- [ ] `docs/design-analysis.md` — bu şablonun doldurulmuş hali, **hiç `⟂` yok**
- [ ] `docs/widget-catalog.md` — her planlı widget · konum · durum (`planned`) · task · tasarım ID'leri (D-16)
- [ ] `docs/token-map.md` — §F taslağı
- [ ] `docs/design-known-issues.md` — yeni K-24… satırları
- [ ] Kullanıcıya Türkçe özet + `ExitPlanMode` + onay → `node tool/progress.js gate analysis`
