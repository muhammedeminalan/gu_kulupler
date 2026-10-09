# Kararlar Defteri

> Bu dosya **projenin karar kaydıdır**. İki bölümü vardır:
> **A) Kilitli kararlar (D-xx):** Kullanıcı tarafından önceden verilmiştir. Claude Code bunları **değiştiremez, yorumlayıp esnetemez**. Bir D-xx kararının gerçekten uygulanamaz olduğunu fark ederse işi durdurur ve `AskUserQuestion` ile kullanıcıya sorar.
> **B) Soru turu kararları (Q-xx):** Faz 0'da kullanıcıya `AskUserQuestion` açılır penceresiyle sorulur; cevaplar bu dosyadaki **"SEÇİM"** alanlarına yazılır. Cevaplandıktan sonra Q-xx de D-xx gibi kilitlenir.

## 0. Kaynak hiyerarşisi (çelişki olursa yukarıdaki kazanır)

1. Kullanıcının sohbetteki son açık talimatı.
2. Bu dosya (`docs/decisions.md`) — D-xx ve cevaplanmış Q-xx.
3. `CLAUDE.md`.
4. Tasarım dışa aktarımı: **görünüm ve davranış** için `design/prototype*`, `design/extracted/*`, `design/reference-shots/*`.
5. `design/prototype/claude-design-prompt.md` — **iş kuralları** (roller, yetki matrisi, üyelik durum makinesi, limitler, metinler). Not: brief ile prototipin ekran/sheet/dialog ID'leri **birebir aynıdır** (51/34/32, doğrulandı); tek fark prototipin brief'te olmayan **20 ek toast** (`TST-X1…X20`) içermesidir (brief 58, prototip 78). **Kimlik için tek kaynak `design/extracted/registry.json`'dur** (ayrıntı: `docs/design-contract.md` §2).
6. Diğer `docs/*` dosyaları (mimari, veri modeli, rules).
7. `reference/*` (life_shared, hatayi_yasat) — yalnızca **konvansiyon örneği**; birebir kopyalanacak hazır kod değil. Hatay'a özgü modeller (Place, News, Merchant…) **asla** alınmaz.

Çelişki bulursan: durma, **sessizce seçme**. Çelişkiyi `docs/PLAN.md` içindeki "Açık noktalar" bölümüne yaz ve `AskUserQuestion` ile sor.

---

## A. Kilitli kararlar

| ID | Karar | Gerekçe / not |
|---|---|---|
| D-01 | Ürün adı **tek sabitten** okunur: `AppConstants.appName = 'GÜ Kulüpler'`. Kod/ARB'de başka yerde hardcode yok. | Brief K-kuralı; ad sonradan değişebilir. |
| D-02 | **Dil politikası:** kod, identifier, dosya adı, commit tipi İngilizce; dokümanlar, `docs/PLAN.md`, commit açıklaması, kullanıcıya mesajlar **Türkçe**. Arayüz metni **yalnızca ARB** (TR şablon, EN). | Kullanıcı Türkçe konuşuyor. |
| D-03 | **State management:** `flutter_riverpod` v3 + `@riverpod` codegen, `Notifier` tabanlı `final class XViewModel extends _$XViewModel with ProjectDependencyMixin`. State = `final class XState extends Equatable` + **elle yazılmış `copyWith`**. **Freezed yok. `AsyncValue` yok** (açık `isLoading/isFetching/isError` bayrakları). | Referans repo ile aynı; kullanıcı onayı. |
| D-04 | **DI:** GetIt (servisler/global) + Riverpod (state). View dosyasında `GetIt.I` **yasak**; erişim mixin üzerinden. | Referans konvansiyon. |
| D-05 | **Routing:** `go_router` + `go_router_builder` (typed routes), sekmeler için `StatefulShellRoute.indexedStack`. Guard'lı rotalara **daima `go`**. `push` yalnızca guard'sız geçici overlay (`AUT-06` yasal metin). Rota tablosu `docs/navigation.md`; sekmeler arası bağlantı davranışı Q-20. | `docs/navigation.md`. Referans repo kuralı (`hatayi_yasat/CLAUDE.md §5`). |
| D-06 | **Sayfa geçişleri platformun kendi varsayılanı:** iOS = Cupertino (kenardan geri kaydırma), Android = Material (predictive back). Bir sekmenin yığını diğerine karışmaz. Özel geçiş yalnızca `docs/navigation.md §5` tablosundakiler. | Kullanıcı gereksinimi. |
| D-07 | **Yerelleştirme:** `flutter_localizations` + `intl` + ARB (`l10n.yaml`: `arb-dir: lib/l10n`, `template-arb-file: app_tr.arb`). 1421 anahtar pakette hazır (`lib/l10n/app_tr.arb`, `app_en.arb`); bunların **186'sı prototip kabuğuna aittir** ve `T-00`'da ayrılır → uygulamada **1235** anahtar (`docs/design-known-issues.md` K-21). UI'da hardcoded string yasak. | |
| D-08 | **Lint:** `very_good_analysis` + proje `analysis_options.yaml`. Üretilen dosyalar commit **edilmez** (`*.g.dart`, `*.gen.dart`, `lib/l10n/app_localizations*.dart`); `tool/codegen.sh` ile üretilir. | Referans konvansiyon. |
| D-09 | **JSON:** `json_serializable` + `explicit_to_json: true`. Modeller Firestore'a `Map` olarak yazılır. | Önceki oturumda yaşanan hata. |
| D-10 | **Soft delete — uygulamada hiçbir yerde hard delete yok.** Servisler yalnızca `softDelete` ve `restore` sunar; `delete` metodu **yazılmaz**. Rules'ta `allow delete: if false`. Ayrıntı: `docs/soft-delete.md`. | Kullanıcının açık, tekrarlı talimatı. |
| D-11 | **Paket yapısı:** Pub workspace; kök uygulama + `packages/gu_data` (modeller, servisler, repository'ler, soft delete) + `packages/gu_ui` (token, tema, ikon, çekirdek widget, overlay çerçeveleri). Q-05 ile **yalnızca üçüncü paket eklenip eklenmeyeceği** sorulur. | |
| D-12 | **Fontlar paketli TTF:** Montserrat (400/500/600/700) + Inter (400/500/600) `assets/fonts/`. `google_fonts` **kullanılmaz** (çevrimdışı ve ilk-açılış güvenilirliği). Türkçe glif (ğ ş İ ı ç ö ü ₺) testle doğrulanır. | Flutter woff2 desteklemez; TTF'ler pakette hazır. |
| D-13 | **İkonlar:** 130 Lucide SVG (`assets/icons/*.svg`) `flutter_svg` ile; tek `GuIcon` widget'ı + `GuIcons` kayıt defteri. `Icons.*` (Material) kullanılmaz. SVG'ler sabit renkli (`#1D293D`) olduğundan renk **`ColorFilter.srcIn`** ile verilir. | |
| D-14 | **Tasarım token'ları tek kaynaktan:** `design/generated-reference/colors/tokens.json` + `design/extracted/registry.json#tokens`. Dart'ta `GuColors` (ThemeExtension, 27 renk × açık/koyu), `GuTypography` (11 stil), `GuSpacing`, `GuRadius`, `GuShadows`, `GuMotion`, `GuSizes`. Üretilmiş `app_theme.dart`/`app_colors.dart` **yalnızca referanstır** (kullanımdan kalkmış `CardTheme`/`DialogTheme` içerir) — kopyalanmaz. | |
| D-15 | **Hardcode yasağı:** renk, boyut, boşluk, radius, süre, font, metin, ikon, URL, limit sayısı kodda sabit yazılmaz; token/sabit/ARB'den gelir. `tool/check_hardcode.sh` kapıdadır. | Kullanıcı gereksinimi. |
| D-16 | **Tekrarlı widget yasağı:** Yeni widget yazmadan önce `docs/widget-catalog.md` (Faz 1'de üretilir) taranır; benzeri varsa genişletilir. İki yerde aynı iş yapan widget = hata. | Kullanıcı gereksinimi. |
| D-17 | **Tasarıma birebir uyum** (1:1). Doğrulama katmanları `docs/design-contract.md`'de: token testi, ID envanteri, aksiyon anahtarları, referans ekran görüntüsü karşılaştırması, golden, cihaz matrisi, kontrast. Sapma yok; sapma gerekiyorsa `docs/design-known-issues.md`'de **kayıtlı** olmalı veya kullanıcıya sorulmalı. | Kullanıcı gereksinimi. |
| D-18 | **Aksiyon anahtarı sözleşmesi:** Her etkileşimli öğe `GuKey.action('<EKRAN-ID>.<aksiyon>')` (= `ValueKey<String>`) taşır; `design/extracted/screens-actions.json` envanteriyle birebir eşleşir. Dinamik kısım şablonlanır (`CLB-01.card.${id}`). `tool/check_design_coverage.js --actions` doğrular. | "Ölü öğe yok" kuralının ölçülebilir hali. |
| D-19 | **Tasarım ID izi:** Her ekran/sheet/dialog/toast sınıfının üstünde `/// Design: <ID>` yorumu; her biri için en az bir test, adında/grubunda aynı ID'yi taşır. | `check_design_coverage.js`. |
| D-20 | **Durum çubuğu:** tema parlaklığına göre tek `SystemUiOverlayStyle`; koyu zemin/kapak üstünde başlayan ekranlarda (CLB-03 kapak, EVT-02 kapaklı, MGT-07 tarayıcı) açık-ikon override; `GuSystemUi` kapsayıcısı ile, ekran ekran elle değil. Testle doğrulanır. | Kullanıcı gereksinimi. |
| D-21 | **Responsive:** 320 dp genişlikten itibaren sağ taşma (overflow) **sıfır**. Metin ölçeği 1.0/1.3/1.6 × açık/koyu × TR/EN cihaz-matrisi testi her ekranda. Sabit genişlik yok; `LayoutBuilder`/`Flexible`/`Wrap`/ellipsis kullanılır. | Kullanıcı gereksinimi. |
| D-22 | **Dokunma hedefi:** görsel ölçü tasarımdaki gibi (btn 48/40/56, chip 38, input 48…) kalır; **etkin dokunma alanı ≥ 44 pt (iOS) / 48 dp (Android)** `GuTapTarget` ile sağlanır. | `docs/design-known-issues.md` K-03. |
| D-23 | **Çökme/hata yönetimi:** `runZonedGuarded` + `FlutterError.onError` + `PlatformDispatcher.instance.onError` → Crashlytics (debug'da konsol). Kullanıcıya SYS-02 / toast; asla kırmızı hata ekranı. `ErrorWidget.builder` üretimde nötr bir `GuErrorState` döndürür. | |
| D-24 | **Tema:** açık/koyu/sistem; `MaterialApp.router` `theme` ve `darkTheme` ikisini de alır. Tercih `shared_preferences`'ta. İki tema da her ekranda çalışır (test matrisinde). | |
| D-25 | **Veri modeli düz (flat) koleksiyonlar:** `users, clubs, memberships, posts, comments, events, rsvps, notifications, reports, activity, settings, blocks, savedPosts, supportTickets, announcementCounters` + alt koleksiyonlar (`posts/{id}/votes`, `users/{uid}/private`). Ayrıntı `docs/domain-model.md`. Doküman ID'leri: üyelik `${clubId}_${userId}`, katılım `${eventId}_${userId}`. | Demo veriyle birebir eşleşir; sorgusu kolay. |
| D-26 | **Zaman:** Firestore'da UTC `Timestamp`; `createdAt/updatedAt/deletedAt` **sunucu zamanı** (`FieldValue.serverTimestamp()`); gösterimde `Europe/Istanbul`. Takvim TR'de Pazartesi başlar. | |
| D-27 | **E-posta alan adı kısıtı** (`ALLOWED_EMAIL_DOMAINS = ogr.gumushane.edu.tr, gumushane.edu.tr`) hem istemcide hem **Security Rules'ta** (`request.auth.token.email` regex + `email_verified`) zorunlu. | |
| D-28 | **Süper admin yalnızca custom claim** (`superadmin: true`) ile; claim `tool/admin/set_superadmin.js` (Admin SDK, kullanıcının kendi makinesinde) ile atanır. Firestore alanıyla yetki yükseltme **yok**. | Yetki yükseltme riskini kapatır. |
| D-29 | **Profil gizliliği:** e-posta `users/{uid}/private/account` içinde, yalnızca sahibi okur; yönetici bağlamında gösterilen **e-posta**, `memberships/{id}/private/contact` alt dokümanından (yalnızca başvuran + yöneticiler + süper admin okur); ad/bölüm/sınıf üyelik dokümanındaki `applicant` anlık görüntüsünden gelir. `users/{uid}` (ad, avatar, bölüm, sınıf, ilgi, biyografi) doğrulanmış kullanıcılar tarafından okunur; "ortak kulüp yoksa gizle" kuralı **arayüz katmanında** uygulanır (Rules ile uygulanamaz — kabul edilmiş sınırlama). | `docs/domain-model.md §2.1–2.2, §2.4`. |
| D-30 | **Bilet kodu:** CSPRNG ile üretilen `GU-XXXX-XXXX` (32'lik alfabe, benzer karakterler yok); QR içeriği `gu:ticket:v1:{eventId}:{code}`; doğrulama = etkinliğe kapsamlı Firestore araması. İstemci tarafında "imza" yok. | |
| D-31 | **Kapsam dışı (brief §17):** kulüp içi görev/Kanban, bütçe, sertifika PDF, sohbet, kulüp kurma başvurusu, admin web paneli, global akış/stories/kullanıcı arama, ödeme/sponsor, gerçek harita, çoklu üniversite, tablet/yatay yerleşim (Q-13 cevabı hariç), danışman etkinlik onayı. **Bunlar için ekran/buton/"yakında" etiketi yazılmaz.** | |
| D-32 | **Süreç:** Faz 0 → `docs/PLAN.md` onayı → Faz 1 tasarım analizi onayı → her task ayrı **plan modunda**, sırayla, tek tek; her task test + kalite kapısı + commit ile biter. Task'lar ve sırası `docs/roadmap.md`'dedir; **atlanamaz, sırası değiştirilemez, birleştirilemez** (kullanıcıya sorulmadan). | Kullanıcı gereksinimi. |
| D-33 | **Test zorunluluğu:** her widget, servis, repository, ViewModel için test. Kural/Rules için emülatör testi. Ayrıntı `docs/testing.md`. | Kullanıcı gereksinimi. |
| D-34 | **Hata sonuç tipi:** `FirebaseResult<T, E>` (sealed: `FirebaseSuccess` / `FirebaseFailure`), `FirestoreResult<T>` / `StorageResult<T>` typedef'leri; hata yutulmaz, enum'lu hata türüne çevrilir. | life_shared konvansiyonu. |
| D-35 | **Commit:** Conventional Commits (`feat|fix|test|refactor|chore|docs`), kapsam olarak task ID: `feat(T-12): kulüp listesi ve filtre`. `git push` **yalnızca kullanıcı isterse**. | |
| D-36 | **Gizli bilgi:** servis hesabı JSON'u, API anahtarı, `.env` repoya girmez; `.gitignore`'da. `firebase_options.dart` ve `GoogleService-Info.plist`/`google-services.json` istemci anahtarları olduğundan commit edilebilir (kullanıcıya hatırlat). | |

---

## B. Soru turu kararları (Faz 0'da doldurulur)

Her sorunun metni, seçenekleri ve **öneri** (ilk seçenek) `prompts/01-soru-bankasi.md`'dedir. Claude Code soruları oradaki **turlar** halinde `AskUserQuestion` ile sorar ve cevapları aşağıya **olduğu gibi** yazar.

| ID | Konu | SEÇİM | Tarih |
|---|---|---|---|
| Q-01 | Backend geliştirme modu | Emülatör önce (`ENV=emulator`; gerçek projeye yalnızca kullanıcı onayıyla) | 2026-10-08 |
| Q-02 | Cloud Functions / Blaze planı | Önce yalnızca istemci (Mod C, Spark); T-42 `pending` kalır, T-43 başında yeniden sorulur | 2026-10-08 |
| Q-03 | Firebase ortamları | Tek proje (`gu-kulupler`) + yerel emülatör | 2026-10-08 |
| Q-04 | Kimlik doğrulama yöntemi | E-posta/şifre + Firebase yerleşik doğrulama bağlantısı (tasarımla birebir); alan adı kısıtı Rules'ta | 2026-10-08 |
| Q-05 | Paket yapısı (üçüncü paket?) | Yalnızca iki paket (`gu_data` + `gu_ui`) | 2026-10-08 |
| Q-06 | Servis/repository test yaklaşımı | `fake_cloud_firestore` + el yazımı fake; Rules/transaction yarışları emülatörde | 2026-10-08 |
| Q-07 | Hatırlatıcı ve bildirim teslimi | Cihazda planlı hatırlatıcı (`flutter_local_notifications` + `timezone`) + uygulama içi liste; push yok | 2026-10-08 |
| Q-08 | Takvim bileşeni | Kendi `GuCalendar`; `table_calendar` T-00'da kaldırılır | 2026-10-08 |
| Q-09 | Rol/yetki kaynağı | Üyelik belgesi + Rules (`memberships/{clubId}_{userId}.role`); not: ilk seçim "Rol custom claim'de" idi, Q-02 (istemci) ve D-28 ile çeliştiği için netleştirme sorusuyla öneriye dönüldü | 2026-10-08 |
| Q-10 | Duyuru limiti ve sayaçlar | Rules + sayaç belgesi (`announcementCounters/{clubId}_{yyyyMMdd}`) | 2026-10-08 |
| Q-11 | Hesap silme ve kişisel veri | Anonimleştir + soft delete; Auth kimliği kalır, giriş engellenir; kalıcı temizlik uygulama dışı | 2026-10-08 |
| Q-12 | Çevrimdışı/önbellek | Okuma önbellekten, yazma engellenir (Firestore kalıcı önbellek; SYS-03 banner + TST-24) | 2026-10-08 |
| Q-13 | Cihaz kapsamı | Telefon dikey kilit; tablet/katlanabilirde ortalanmış 480 dp sütun (`GuBreakpoints`) | 2026-10-08 |
| Q-14 | Yazı boyutu davranışı | Uygulama içi (%100/130/160) × sistem ölçeği, üst sınır 1.6; sabit yükseklikler min-height (K-08) | 2026-10-08 |
| Q-15 | Tasarım bulgularının ele alınışı | Flutter'da çöz; K-01…K-23 kararları uygulanır, tasarım dokunulmaz | 2026-10-08 |
| Q-16 | Golden test kapsamı | Önerilen kapsam: tüm `gu_ui` widget'ları (açık+koyu) + her ekran 390 × açık × TR (+ koyu) + sheet/dialog/toast; EN ve tam matris taşma testi | 2026-10-08 |
| Q-17 | Git akışı | Task başına dal (`feat/T-xx-<kisa-ad>`, T-00 için `chore/T-00-kurulum`); merge akışı K-K cevabına göre | 2026-10-08 |
| Q-18 | CI | Şimdilik CI yok; `tool/quality_gate.sh` yerel; T-46'da yeniden sorulur | 2026-10-08 |
| Q-19 | Fotoğraf/görsel yükleme | Storage'a yükle (avatar, logo/kapak, gönderi görseli ≤4 ≤5 MB, destek eki); bucket/Blaze durumu T-46 öncesi doğrulanır (Açık noktalar) | 2026-10-08 |
| Q-20 | Sekmeler arası bağlantıda geri davranışı | Hedefin ev sekmesine geç (`navigation.md §4` varsayılan A); guard'lı rotalar `go` | 2026-10-08 |

### Claude Code'un kendi sorduğu ek sorular
_(Faz 0 sonunda, en çok 2 ek tur; her biri "K-xx" ile numaralanır ve cevabıyla buraya yazılır.)_

| ID | Konu | SEÇİM | Tarih |
|---|---|---|---|
| K-K | Dal/merge akışı (Q-17 ayrıntısı) | Task başına dal (`chore/T-00-kurulum`, `feat/T-xx-<kisa-ad>`); kapı yeşil + commit sonrası `main`'e yerel `git merge --no-ff`'i Claude yapar, onay beklemez, `git push` yok. Kullanıcı sözü: "merge işleminide sen yap direk benden onay bekleme" | 2026-10-08 |
| K-L | Storage bucket / Blaze (Q-19 × Q-02) | Şimdi bilinmiyor; geliştirme emülatör Storage ile sürer; T-46 öncesi konsol kontrolü, gerekirse Blaze (PLAN §21) | 2026-10-08 |
| K-A | G-1 Danışman hesabı bağlama | `clubs.advisor{name,title,userId?}` + `advisor` üyeliği `tool/admin/set_advisor.js` ile (T-37); ADM-03 yalnızca ad+unvan | 2026-10-08 |
| K-D | K-09 Paylaşım kök adresi | Yer tutucu `AppConstants.shareBaseUrl = https://kulupler.gumushane.edu.tr`; yalnızca kopyala/paylaş; App Links yok | 2026-10-08 |
| K-N | Destek e-postası (DLG-01 mailto, SET-04) | Yer tutucu `AppConstants.supportEmail = kulupler-destek@gumushane.edu.tr` | 2026-10-08 |
| K-E | DebugMenu (K-02) | Evet, yalnızca `ENV=emulator`/debug build; T-11 iskelet, T-43 tamamlanır; release derlemesine girmez | 2026-10-08 |
| K-F | Kayıtlı varken taslağa alma (rules-spec §3.7) | Reddet: `published→draft` yalnızca `goingCount == 0` (Rules + UI devre dışı) | 2026-10-08 |
| K-G | Yoklama zaman penceresi (rules-spec §3.8) | `startsAt − 2 sa ≤ request.time ≤ endsAt + 6 sa` Rules'ta; dışı MGT-06 bilgi bandı | 2026-10-08 |
| K-B | G-3 Gönderi görselleri | _(türetildi, sorulmadı)_ Q-19 = yükle → Storage `images[]`; K-18 akışı tam uygulanır | 2026-10-08 |
| K-C | G-4 Kapak seçimi (SHT-31) | _(türetildi, sorulmadı)_ Şablon (3 palet × 4 desen) + "Galeriden seç" → Storage `coverPath` | 2026-10-08 |
| K-H | Kulüp adı benzersizliği | _(ertelendi)_ T-39 planında sorulacak; öneri `nameLower` sorgusu | 2026-10-08 |
| K-I | Firebase App Check | _(ertelendi)_ T-45'te sorulacak; şimdilik yok | 2026-10-08 |
| K-J | Mod C spam sınırlaması | _(ertelendi)_ T-25 planında sorulacak; öneri "kabul, riske yaz" | 2026-10-08 |

### Claude'un kendi verdiği kararlar (otonom mod, 2026-10-08/09)
_(Kullanıcı: "karar gerektiren yer çıkarsa app akışını bozmayan öneri varsa kendin ver, en sonda söyle." Taslak ajanlarının 97 açık noktasına verilen kararlar; kaynak: docs/PLAN.md §22. Ücretli/geri alınamaz konular karar değil, §21 kullanıcı maddesidir.)_

| ID | Konu | KARAR | Etkilenen § / task |
|---|---|---|---|
| CD-01 | PLAN onayı (I-1) | Kullanıcının gece talimatı ("yatıyorum, kendin ver") yazılı madde 2'yi geçersiz kılar: PLAN.md onayı Claude tarafından `node tool/progress.js gate plan` ile verilir; ExitPlanMode açılmaz; progress.json#deviations[1] geçerli | §0, §3-h, §17; Faz 0 |
| CD-02 | gu_ui overlay klasör adı (A-1) | `packages/gu_ui/lib/src/overlay/` (tekil; check_hardcode HC12b ile uyumlu); architecture.md §2 satırı T-00 commit'inde `overlay/` yapılır | §4, §7; T-00 |
| CD-03 | git merge izni (A-2, H-1) | T-00'da `.claude/settings.json` allow listesine `Bash(git merge --no-ff:*)` ve `Edit(docs/decisions.md)` eklenir (sırasıyla K-K merge'i ve karar kaydı için); `git merge` genel kalıbı ask'te kalır | §17; T-00 |
| CD-04 | Merge commit tipi (A-3) | `chore(T-xx): main'e birleştir — <başlık>` (D-35 tip listesine uyar) | §17; T-00+ |
| CD-05 | .gitignore eksikleri (A-4) | T-00'da eklenir: `tool/.cache/`, `**/coverage/`, `packages/*/.dart_tool/`, `lib/l10n/app_localizations*.dart` | §17, §3; T-00 |
| CD-06 | check_boundaries B07/B08 (A-5) | T-00'da eklenir: B07 kompozisyon kökü dışında `product/`/`core/` → `features/` import yasak ve `core/` → Firebase SDK yasak (beyaz liste: lib/main.dart, lib/core/bootstrap/*, lib/core/di/project_dependency.dart, lib/core/env/app_environment.dart, lib/product/navigation/routes/*, lib/product/navigation/shell/*); B08 gu_data barrel/arayüz dosyaları Firebase SDK tipi export/import edemez | §6, §17; T-00 |
| CD-07 | depend_on_referenced_packages (A-6) | `true` (varsayılan); her paket kendi bağımlılığını bildirir | §5, §6; T-00 |
| CD-08 | Cihaz servisleri konumu (A-7, B-4, H-6) | `lib/product/service/<ad>_service.dart` (arayüz + impl; fake'ler `test/fakes/`): ConnectivityService, UrlLauncherService, ShareService, PermissionService, ImagePickerService, FileService (path_provider), AppInfoService (package_info_plus), LocalReminderService; architecture.md §3'e satır T-11'de | §4, §10, §12; T-11 |
| CD-09 | LocalReminderService zamanlaması (A-8, B-4, H-6) | T-23: `flutter_local_notifications` + `timezone` eklenir, `lib/product/service/local_reminder_service.dart` (schedule(rsvp, event), cancel(rsvpId), rescheduleAll(), ensureChannel(l10n)) + FakeLocalReminderService + SHT-13 akışı gerçek planlama; T-25: settings tercihleri (eventReminders, reminderTime) + açılışta yeniden planlama + event_reminder liste belgesi (CD-44). Android `AndroidScheduleMode.inexactAllowWhileIdle`; SCHEDULE_EXACT_ALARM/USE_EXACT_ALARM yazılmaz | §5, §10, §15, §18; T-23, T-25 |
| CD-10 | FED-01 feature klasörü (A-9) | `features/clubs/view/widget/club_feed_tab.dart` (`/// Design: FED-01`) + `features/clubs/provider/club_feed_view_model.dart`; `feed` feature'ı yalnızca FED-02, FED-03 | §4, §12; T-20 |
| CD-11 | Türkçe büyük/küçük harf (A-10, D-3, G-5) | `packages/gu_ui/lib/src/extensions/string_x.dart` → `trLower()/trUpper()` (İ→i, I→ı); `nameLower` uygulama katmanında (ViewModel) hesaplanıp repository'ye verilir, gu_data bilmez; Rules'ta `nameLower == name.lower()` eşitliği YOK, yalnızca `is string && size() in 2..60`; users sahibi beyaz listesine `nameLower` eklenir (T-12), clubs süper admin yazar (T-37). tool/seed tohumlayıcısı kendi TR lower fonksiyonunu taşır | §7, §9, §11, §14; T-01, T-12, T-15 |
| CD-12 | integration_test (A-11, F-11) | `integration_test/` T-14'te `auth_flow_test.dart` ile açılır; başvuru→onay T-32, etkinlik→bilet→yoklama T-35, hesap silme T-29; tümü T-43 ve T-45'te yeniden koşar | §4, §16, §18 |
| CD-13 | go_router_builder generate_for (A-12) | `lib/product/navigation/**.dart`; her `routes/*_routes.dart` kendi `part` satırını taşır | §5, §13; T-00 |
| CD-14 | equatable sürümü (B-1) | `equatable: ^2.1.0`'a indirilir (fake_cloud_firestore/firebase_auth_mocks zorunluluğu; 3.0.0 kırıcı değişiklikleri projede kullanılmıyor); gerekçe docs/packages.md §1'e T-00'da | §5, §3; T-00 |
| CD-15 | gu_data test koşucusu (B-2) | gu_data dev bağımlılığı `flutter_test` (sdk); `test` paketi eklenmez; packages.md §2.2 satırı T-00'da güncellenir | §5, §16; T-00 |
| CD-16 | DLG-05 galeri izni (B-3) | DLG-05 ön açıklama diyaloğu; "İzin ver" doğrudan image_picker galeri seçicisini açar (Android Photo Picker / iOS PHPicker); READ_MEDIA_IMAGES manifest'e yazılmaz; NSPhotoLibraryUsageDescription + NSCameraUsageDescription iOS'ta yazılır (T-14); kamera için Permission.camera + DLG-04 + TST-32 | §5, §12; T-14 |
| CD-17 | Registry dışı CSS renkleri (C-1) | Ayrı `GuComponentColors` (ThemeExtension, 13 renk, light/dark, lerp) + `context.gu.component`; GuColors 27'de kalır; token testi 27'yi registry'den, 13'ü component-css.css'ten doğrular | §7; T-01 |
| CD-18 | context.gu getter kümesi (C-2) | Statik sabit sınıflar: GuSpacing, GuGap, GuInsets, GuRadius, GuMotion, GuSizes, GuOpacity, GuBreakpoints; `context.gu` yalnızca tema bağımlı: colors, text, shadows, component, isDark, reduceMotion, duration(Duration), textScaler (CLAUDE.md §6 tablosuyla uyumlu) | §7; T-01 |
| CD-19 | Harita yer tutucu fontu (C-3) | `GuTypography.mapPlaceholder` = Inter 500/12 + tabularFigures; mono font eklenmez; design-known-issues K-26 (Faz 1'de yazılır) | §7; T-06, T-23 |
| CD-20 | CSS türevi token'lar (C-4) | Aynı token sınıflarında `/// CSS-derived` işaretli ayrı grup; token testi registry sayılarını (27/11/9/5/4/5) ve CSS türevlerini ayrı doğrular; docs/token-map.md iki tablo | §7; T-01 |
| CD-21 | İkon kalınlığı (C-5) | 1.75 sabit kabul; rozet 2.2 / onay 3 varyantı üretilmez; design-known-issues K-24 (Faz 1) | §7, §19; Faz 1, T-03 |
| CD-22 | AA kontrast kusurları (C-6) | Renk değişmez (Q-15); token testinde `expectedContrastFailures` listesi (text.muted/bg.surfaceMuted açık 4.35; #FFF/state.info koyu 2.12; #FFF/state.danger koyu 2.54; text.disabled muaf); design-known-issues K-25 (Faz 1) | §7, §19; T-01, Faz 1 |
| CD-23 | Varlık konumu (C-7) | Kök `assets/` (docs ile uyumlu); gu_ui testleri `packages/gu_ui/test/flutter_test_config.dart` içinde FontLoader(`../../assets/fonts`) + dosya tabanlı GuTestAssetBundle; ikon parite testi `Directory('../../assets/icons')` okur | §7, §16; T-01, T-03 |
| CD-24 | UI zaman/mesafe sabitleri (C-8) | gu_ui'da: `GuMotion.toastDefault` (4000 ms), `GuMotion.toastUndo` (6000 ms), `GuSizes.sheetDragCloseThreshold` (120), `GuSizes.refreshTriggerDistance` (60/90); iş süreleri (60 sn, 30 sn, 7 gün) `Limits`'te | §7, §8; T-07 |
| CD-25 | Roadmap dışı 12 gu_ui bileşeni (C-9) | §8.3 atamaları kabul: GuSpinner/GuFab/GuTimeline/GuGroupHeader/GuHorizontalList/GuIconBox/GuTicketFrame → T-04; GuWheelPicker → T-05; GuPageDots/GuParallaxHeader/GuMapPlaceholder/GuContentColumn → T-06; GuEmblem → T-03; product: ClubCta (T-16), MyClubChip (T-17), QrCodeView (T-23); feature: ScanOverlay (T-35), ImageViewer (T-20). Sıra değişmez; Faz 1 tablosu bunu onaylar | §8, §18; Faz 1 |
| CD-26 | GuCover ikon katmanı (C-10) | T-03 planında 12 şablon SVG grep ile denetlenir; ikon gömülü değilse GuCover sağ altta `GuIcon(color: component.coverInk)` katmanı çizer | §7, §8; T-03 |
| CD-27 | Tekrar birleştirme (C-11) | GuTile tek primitif; UserRow (product) = GuTile + GuAvatar; MemberRow = UserRow + GuRoleBadge; GuRoleBadge/GuStatusBadge GuBadge'i sarar (stil haritaları registry tablo testli); GuEmptyState tek gövde, GuErrorState/GuOfflineState onu sarar | §8; Faz 1, T-04, T-06 |
| CD-28 | Çek-yenile (C-12) | Özel `GuRefresh` (1:1), platform yerlisi yok | §8; T-06 |
| CD-29 | 480 dp sütun kapsamı (C-13, G-10) | `GuContentColumn` (gu_ui, T-06) `ConstrainedBox(maxWidth: GuBreakpoints.maxContentWidth=480) + Center`; GuApp.builder gövdeyi (T-11), GuSheetFrame/GuDialogFrame/GuToast kendini sarar (T-07); GuBottomNav ve GuAppBar tam genişlik | §7, §8, §13; T-06, T-07, T-11 |
| CD-30 | Tanımsız üst sınırlar (D-1) | `Limits`: clubNameMax=60, adminReasonMax=300, conditionsMax=10, conditionTextMax=120, placeTextMax=120, pollOptionTextMax=60, instagramHandlePattern=`^@?[A-Za-z0-9._]{1,30}$`, foundedMin=1900, foundedMax = AppClock yılı; Rules aynı sayılar (parite testi) | §9, §11; T-08 |
| CD-31 | Limits sınıf adı (D-2, I-6) | `Limits` (`packages/gu_data/lib/src/constants/limits.dart`); domain-model §9 `GuLimits` → `Limits` T-08 commit'inde | §9; T-08 |
| CD-32 | Saat kayması toleransı (D-4, E-6) | `Limits.clockSkewTolerance = Duration(minutes: 5)`; Rules'ta `retryAfter` ve `poll.endsAt` için `[request.time + d − 5m, request.time + d + 5m]`; istemci `AppClock.nowUtc()` ile hesaplar; parite etiketi `// limit: clockSkewToleranceMinutes` | §9, §11; T-15, T-19 |
| CD-33 | Şikayet nedenleri/hedefleri (D-5) | Tasarım 1:1: `ReportReason` 6 (spam, harassment, inappropriate, misinformation, offtopic, other), `ReportTargetType` 5 (post, comment, user, club, event; event için targetClubId = event.clubId); domain-model §2.10 + rules-spec §3.10 T-15 commit'inde güncellenir | §9, §11; T-15 |
| CD-34 | Hatırlatıcı seçenekleri (D-6) | `ReminderOption` 4 (none, 15m, 1h, 1d); `settings.reminderTime` 1h·1d kalır; domain-model §2.8 + rules-spec §3.8 T-22 commit'inde | §9, §11, §15; T-22, T-23 |
| CD-35 | Kapak palet/desen adları ARB'de yok (D-7) | ARB'de yok (doğrulandı; SHT-31'de palet adı görünür etiket, desen adı Semantics/aria-label). T-00'da EKLENMEZ; SHT-31'i uygulayan **T-34** aynı commit'te 7 anahtar ekler: `coverPaletteRed/Slate/Bordeaux` (adlar prototip `core.js#PALETTES` TR/EN) + `coverPatternMountain/Lines/Dots/Waves` (registry#patterns TR/EN) → 1235 → 1242; `check_arb_parity` 1235'i yalnızca prune anında denetler (doğrulandı) | §14; T-34 |
| CD-36 | NotificationDispatcher zamanlaması (E-1) | Arayüz + `NoopNotificationDispatcher` T-15'te (`packages/gu_data/lib/src/notifications/`); `ClientFanOutDispatcher` T-25'te DI'a bağlanır; bağlama borcu W-NB-01 T-15 açar, T-25 kapatır | §10, §15, §18; T-15, T-25 |
| CD-37 | new_report Mod C (E-2, F-2) | Mod C'de `new_report` belgesi üretilmez (alıcı kümesi istemcide bilinemez, D-28); ADM-01 KPI + ADM-04 listesi `reports where status=='open'` ile gösterir; `notifyNewReport` arayüzde kalır, ClientFanOutDispatcher no-op; Mod F'de Function üretir; §20 riskine yazılır | §15, §11, §20; T-25 |
| CD-38 | event_new ilgi-eşleşmeli fan-out (E-3, F-3) | Dahil: `UserRepository.listByInterests(interestIds, limit)`; `Limits.eventNewInterestFanOutMax = 200`; indeks users (interests ARRAY_CONTAINS, isDeleted ASC); aşan kısım yazılmaz + AppLogger.warn; DLG-22 "{n}" = üyeler + eşleşen (≤200) | §10, §11, §15; T-25 |
| CD-39 | Storage posts yazar denetimi (E-4) | İstemci yüklemede `customMetadata.clubId`; storage.rules `isManagerOf(metadata.clubId)` için `firestore.get(memberships/{clubId}_{uid})` (1 okuma); firestore.rules posts create `images[i].path.matches('posts/' + postId + '/.*')`; postId istemcide önceden üretilir (`doc().id`) | §10, §11; T-19, T-21 |
| CD-40 | firebase/package.json konumu (E-5) | `firebase/package.json` (kalite kapısı `(cd firebase && npm test)`); testler `firebase/test/`; packages.md §4 T-10 commit'inde | §11, §17; T-10 |
| CD-41 | Sayaç–belge eşliği referansı (E-7) | Sayaç taşıyan belgeye son yazım referansı eklenir: `clubs.lastMembershipRef`, `events.lastRsvpRef`, `posts.lastCommentRef`, `announcementCounters.lastPostRef` (string yol; yalnızca sayaç batch'inde, touches beyaz listesine sayaçla birlikte); Rules `getAfter(/databases/$(database)/documents/$(ref))` ile geçişi doğrular; domain-model §2 tablolarına T-15/T-19/T-22 commit'lerinde satır eklenir | §9, §10, §11; T-15, T-19, T-22 |
| CD-42 | Cihaz matrisi sayısı (F-1, H-4, I-5) | 48 temel kombinasyon (4 × 2 × 2 × 3); klavye + 4 güvenli alan varyantı ayrı (yalnızca 390×844×açık×TR×1.0); testing.md §5 "72" → "48" T-02 commit'inde | §16; T-02 |
| CD-43 | Sessiz saat × yerel hatırlatıcı (F-4) | Yerel hatırlatıcı sessiz saate uymaz (kullanıcının seçtiği zamanda çalar); ayar kaydedilir, Mod C'de etkisiz; UI aynen | §15; T-25 |
| CD-44 | event_reminder liste belgesi (F-5) | Yerel hatırlatıcı tetiklenince/dokununca cihaz kendi `userId` için `event_reminder` belgesini yazar; Rules create: `userId == uid() && type == 'event_reminder'`; böylece NTF-01 + rozet tasarımla aynı | §11, §15; T-25 |
| CD-45 | FED-03 taslak (F-6) | Yerel: shared_preferences `compose_draft_<clubId>` (JSON, görseller yol); kulüp başına tek taslak; açılışta yüklenir; Firestore'da draft yok | §12; T-21 |
| CD-46 | Panel grafik verisi (F-7) | MGT-01 GuMiniLineChart: `activity` (member_joined + application_approved) son 8 hafta, haftalık, istemci toplar; ADM-01 aynı metrik tüm kulüpler (8 `count()` sorgusu); KPI "+x bu ay" aynı kaynaktan | §12; T-31, T-38 |
| CD-47 | Etkinlik kapak Storage yolu (F-8) | `events/{eventId}/cover.jpg` (yönetici, image/* ≤5 MB, update/delete ret); MGT-05 akışı: önce `createDraft` (eventId), sonra kapak yükleme; architecture §10 listesine T-22 commit'inde | §10, §11; T-22, T-34 |
| CD-48 | maintenance_message gösterimi (F-9) | Gösterilir: GuApp.builder'da `GuBanner.info` (tasarım sistemi "bilgi bandı" varyantı), SYS-03 çevrimdışı bandının altında, kapatılamaz, metin Remote Config'ten; yeni ekran/ID yok; design-known-issues K-27 "tasarımda yeri yok, mevcut banner bileşeni" | §12, §15; T-11 |
| CD-49 | Fan-out kalıcı kuyruk (F-10) | Eklenmez; kabul edilmiş sınırlama (§20 risk, K-J ile birlikte); Mod F çözer | §15, §20; T-25 |
| CD-50 | Golden varyantları (F-12) | Varsayılan görünüm açık+koyu zorunlu; `states/` referansı olan 14 ekranın 4 durumu ve CLB-03 7 rol / MGT-* danışman görünümleri de golden (≈ +132 PNG); diğer varyantlar davranış testi | §16, §19; T-02+ |
| CD-51 | K-23 searchNoResults (G-1) — KESİNLEŞTİ (2026-10-09 deneyi) | İzole `flutter gen-l10n` denemesi (scratchpad/l10n_probe2): varsayılan `use-escaping: false` ile `'{q}' için sonuç yok` → Dart `'\'$q\' için sonuç yok'` (sorgu DÜZ tırnakla basılır, doğru); `''{q}''` → `''$q''` (çift tırnak, YANLIŞ). Karar: ARB metni (TR/EN) DEĞİŞMEZ, tipografik tırnak yok; `tool/check_arb_parity.js` mini-ICU çözümleyicisi `l10n.yaml#use-escaping` değerini okur (yok/false → tek tırnak düz karakterdir, `''` kaçışı aranmaz; true → ICU kuralı) ve ARB08 `searchNoResults` hatası kalkar; `postComments`/`timeInDays` sahte placeholder metadata'ları yine silinir; design-known-issues K-23 "searchNoResults: metin doğru, araç düzeltildi (T-00)". Ek bulgu: kök `pubspec.yaml`'da `flutter: generate: true` yok → T-00 ekler (gen-l10n ön koşulu). `test/l10n/arb_fixes_test.dart` üç anahtarı doğrular | §14, §17; T-00 |
| CD-52 | SessionState.onboardingSeen (G-2) | `SessionState`'e `bool onboardingSeen` eklenir (kaynak AppInitFlags/shared_preferences); `AppRedirect.resolve(SessionState, Uri)` imzası korunur | §12, §13; T-11 |
| CD-53 | NAV.tab.* sayımı (G-3) | T-02'de `tool/check_design_coverage.js` checkActions'a `NAV` öneki eklenir (K-17); NAV anahtarları yalnızca registry#tabRoot ekranlarında beklenir; task-map toplamları değişmez | §19, §17; T-02 |
| CD-54 | MGT-05/ADM-03 çift rota (G-4) | `EventFormRoute` + `EventEditRoute` (tek `EventFormView`), `AdminClubFormRoute` + `AdminClubEditRoute` (tek `AdminClubFormView`); navigation.md §2 T-11 commit'inde | §13; T-11 |
| CD-55 | GuPageTransitions konumu (G-6) | `lib/product/navigation/gu_page_transitions.dart` (T-07'de yazılır, uygulama katmanı); gu_ui yalnızca `GuTheme.pageTransitionsTheme`; Faz 1 görev tablosu notlar | §7, §13; T-07 |
| CD-56 | EN tarih yerel ayarı (G-7) | `AppDateFormats.intlLocale`: tr → `tr_TR`, en → `en_GB`; bootstrap `initializeDateFormatting` ikisi için | §14; T-11 |
| CD-57 | Üyelere özel etkinlik derin bağlantı (G-8) | permission-denied → `ToastId.tstX18` + `EventsRoute().go`; not-found/isDeleted → `NotFoundRoute` | §13; T-23 |
| CD-58 | 250 ms sheet gecikmesi (G-9) | `lib/core/constants/app_durations.dart` → `AppDurations.postNavigationSheetDelay = 250 ms` | §13, §15; T-26 |
| CD-59 | iOS deployment target (H-2) | `IPHONEOS_DEPLOYMENT_TARGET = 15.0` (3 yapılandırma) + Podfile `platform :ios, '15.0'`; T-00'da native build ÇALIŞTIRILMAZ (kullanıcı: build gerekmez); doğrulama T-46'da release build adımında | §5; T-00, T-46 |
| CD-60 | Android minSdk (H-3) | `minSdk = flutter.minSdkVersion` ifadesi KORUNUR (Flutter 3.44.9 → 24; flutter_local_notifications/image_picker_android/permission_handler_android/url_launcher_android 24 ister, firebase/mobile_scanner 23 — PLAN §5.6.2 kanıtı); literal yazılmaz; apk build T-00da çalıştırılmaz, T-46da | §5; T-00, T-46 |
| CD-61 | K-12 ölçüm (H-5) | design-known-issues K-12 "~55 KB, ~300 daire" → "60 KB, 700–701 <circle>" T-03 commit'inde | §19, §20; T-03 |
| CD-62 | MessagingService/PushTokenService (H-7, I-2) | Mod C'de yazılmaz; `fcmTokens[]` modelde boş liste; roadmap listesi değişmez, T-10/T-25 planlarına "Mod C: yok" notu | §10, §15, §18; T-10, T-25 |
| CD-63 | K-H kulüp adı benzersizliği (H-8, I-9) | Şimdi karar: ADM-03'te `nameLower` eşitlik sorgusu (yarış kabul; rules-spec §9.4); kilit belgesi yok | §11, §22; T-39 |
| CD-64 | K-I App Check (H-9, I-10) | Şimdi karar: Hayır (konsol adımı + mağaza kimlikleri gerektirir); T-45 raporuna "önerilir" notu | §22; T-45 |
| CD-65 | K-J Mod C spam (H-10, I-11) | Şimdi karar: Kabul; §20 riski + T-45 güvenlik raporu; kota kuralı yazılmaz | §20, §22; T-25, T-45 |
| CD-66 | Q-02 yeniden sorma / T-42 (H-13, I-4) | T-43 başında kullanıcıya SORULMAZ (Blaze ücretli = kullanıcı kararı; otonom modda tek güvenli seçenek Mod C): `node tool/progress.js skip T-42 --note "Mod C ile teslim; Functions sonraki sürüm (kullanıcı kararı)"`; final raporda "Functions'a geçiş" bölümü | §18, §22; T-43 |
| CD-67 | CI (H-14) | T-46'da yeniden sorulmaz: CI yok (Q-18); final raporda öneri | §17, §22; T-46 |
| CD-68 | Yer tutucular (H-15, H-16) | supportEmail/shareBaseUrl/logo yer tutucuları kalır; final raporda "değiştirilecek 3 değer" listesi | §22; T-46 |
| CD-69 | DebugMenu girişi (I-3) | GuApp.builder'da yalnızca `AppEnvironment.debugMenuEnabled` iken görünen köşe düğmesi (`ValueKey('debug.open')`, GuKey.action değil) → `/debug` rotası (`DebugMenuRoute`, guard debugMenuEnabled); EXEMPT_ACTIONS değişmez; release'te `kReleaseMode` ile derleme dışı | §12, §13; T-11, T-43 |
| CD-70 | Prompt/CLAUDE.md'ye otonom not (I-7) | Eklenmez; deviations + PLAN §3-h yeterli | §3; — |
| CD-71 | .firebaserc / emulators sahibi (I-8) | T-10 (roadmap T-10 hedefi); T-00 yalnızca pubspec/analysis/build/l10n/platform/AppConstants/.gitignore/settings | §3, §18; T-10 |
| CD-72 | Yerel hatırlatıcı tıklaması → rota (I-12) | `NotificationNavigator.open` aynı çözücü: going → `/events/:eid/ticket`, waitlist → `/events/:eid`; soğuk açılış `getNotificationAppLaunchDetails()` splash sonrası | §13, §15; T-25, T-26 |
| CD-73 | Faz 0 commit | Pack dosyaları + Faz 0 çıktıları `main`'e tek commit: `docs(faz0): Claude Code paketi, kararlar ve uygulama planı` (T-00 "git status temiz" ön koşulu için; push yok) | §17; Faz 0 |
| CD-74 | Java/emülatör ön koşulu (H-18) | T-10 planında `java -version` kontrol edilir; Java yoksa Rules testleri koşamaz → kapı Rules adımı için `GU_GATE_SKIP_RULES=1` benzeri bir atlama YOK; bunun yerine: Java yoksa `firebase emulators` yerine Android Studio JBR (`/Applications/Android Studio.app/Contents/jbr/Contents/Home`) JAVA_HOME olarak denenir; o da yoksa task `blocked` + kullanıcıya sabah raporu (durma noktası b) | §21, §22; T-10 |
| CD-75 | K-22 Türkçe iyelik eki | `notifTypeSystemWelcomeTitle` TR = `{appNameDative} hoş geldin`, EN = `Welcome to {appNameDative}` — tek yer tutucu; değer `AppLocalizationsX.appNameWelcomeArg` extension'ından gelir (TR → `AppConstants.appNameDative = "GÜ Kulüpler’e"`, EN → `AppConstants.appName`); `legalGizlilikB1` TR+EN `{appName}`; iki sabit tek dosyada (D-01), ad değişince ikisi birlikte değişir (PLAN §14.3) | §14; T-00 |
| CD-76 | ALLOWED_EMAIL_DOMAINS tek kaynağı | T-00: `lib/core/constants/app_constants.dart` içinde `allowedEmailDomains` listesi; T-08: liste `packages/gu_data/lib/src/constants/email_domain_policy.dart` (`EmailDomainPolicy.allowedDomains`) olur ve `AppConstants.allowedEmailDomains` ona delege eder (tek kaynak gu_data; Rules regex paritesi testi gu_data listesini okur) | §9, §10; T-00, T-08 |

Kullanıcıya bırakılanlar (§21'de kalır, karar verilmez): K-L bucket/Blaze (T-46), Firestore veritabanı region'u (konsolda zaten varsa aynen; yoksa kullanıcı; öneri europe-west3), Apple 5.1.1(v) nihai onayı (T-46), gerçek logo/alan adı/e-posta (T-46), git push, firebase deploy, süper admin claim betiği (T-37; emülatörde Claude `--emulator` ile çalıştırabilir, gerçek projede kullanıcı).

---

## C. Karar değişikliği süreci

1. Değişiklik önerisi **gerekçe + etkilenen dosyalar + alternatif** ile `AskUserQuestion`'a konur.
2. Kullanıcı onaylarsa bu dosyada ilgili satır güncellenir (`~~eski~~ → yeni`, tarih, neden) ve `CLAUDE.md` / `docs/*` içindeki yansımaları **aynı commit'te** düzeltilir.
3. Onay yoksa eski karar geçerlidir.
