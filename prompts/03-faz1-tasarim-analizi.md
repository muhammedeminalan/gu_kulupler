# 03 — FAZ 1: TASARIM ANALİZİ (→ `docs/design-analysis.md`, sonra DUR)

> **Önkoşul:** T-00 bitti (`progress.json#tasks.T-00.status == "done"`).
> **Çıktı:** `docs/design-analysis.md` (şablon: `docs/design-analysis.TEMPLATE.md`) + `docs/widget-catalog.md` (planlı widget listesi) + `docs/token-map.md` (taslak).
> **Kural:** Bu fazda **uygulama kodu yazılmaz**. Analiz onaylanmadan `T-01` (token/tema) başlamaz ve hiçbir ekran/view yazılmaz (CLAUDE.md Kapı 1).
> Kullanıcıya Türkçe, kısa. Belirsiz her nokta `AskUserQuestion`.

## Amaç

Kullanıcının talebi: *"Önce tasarımı analiz et: çekirdek widget'lar, util'ler, extension'lar, sabitler… tekrar eden widget yazılmasın, hardcode olmasın."* Analiz, T-01…T-07'nin (token, test altyapısı, ikon/görsel kayıtları, gu_ui primitifleri/girdileri/durumları/overlay'leri) **tek doğru girdisidir**.

## Girdiler (bunları gerçekten oku)

| Ne | Nerede |
|---|---|
| Bileşen CSS (ölçüler, durumlar) | `design/extracted/component-css.css`, `design/extracted/css-class-usage.json` |
| Token'lar | `design/extracted/registry.json#tokens`, `design/generated-reference/colors/tokens.json` |
| Prototip bileşen kaynağı | `design/prototype/app/ui.js`, `cards.js`, `shell.js`, `core.js`, `sheets.js`, `dialogs.js` |
| Ekran kaynağı (kullanım yerleri) | `design/prototype/app/screens-*.js` |
| Görsel referans | `design/reference-shots/{screens,sheets,dialogs,toasts,states}` — **bileşen durumları** için `states/` ve ilgili ekran görüntüleri; görüntüleri `Read` ile **gerçekten aç** |
| Tasarım brief'i | `design/prototype/claude-design-prompt.md` (bileşen/durum/erişilebilirlik gereksinimleri) |
| Bilinen kusurlar | `docs/design-known-issues.md` |
| Ürettirilmiş referans kod | `design/generated-reference/` (yalnızca referans; K-11) |

## Adımlar

1. **Bileşen envanteri.** `docs/design-analysis.TEMPLATE.md` §A tablosunu (≈ 60 prototip bileşeni önceden listelenmiştir) kopyala ve **her satırı doldur**: prototip adı · kaynak dosya:satır · CSS sınıfları · varyant/boyut · durumlar · kullandığı token'lar · kullanıldığı ekranlar (`css-class-usage.json` + `grep`) · önerilen Flutter adı · konum (`gu_ui` | `lib/product/widget/`) · API taslağı (parametreler) · referans görüntü yolu. Şablonda olmayan bileşen bulursan **ekle**.
2. **Tekrar analizi.** Aynı işi yapan ama farklı görünen/adlanan bileşenleri bul (örn. `Tile` ↔ `Row` ↔ `OptionRow`, `Badge` ↔ `StatusBadge` ↔ `RoleBadge`, `Card` ↔ `Tile.in-card`). Birleştirme önerisini gerekçesiyle yaz (D-16). Kararsızsan `AskUserQuestion`.
3. **Durum matrisi.** Her bileşen için default/pressed/focus/disabled/loading/selected/error/read-only hangileri tasarımda **var** (görüntü/CSS kanıtı) → test matrisi bunlardan türer. Tasarımda olmayan durum uydurulmaz.
4. **Yardımcılar (util).** Prototipte `GU.*` altındaki yardımcıları (tarih/saat biçimleri, `pad2`, göreli zaman, debounce, odak tuzağı, TR küçük harf eşleme, para/sayı, ID üretimi) listele → Dart karşılığı, konumu (`gu_data` | `gu_ui` | `lib/core`), testi. TR `İ/ı` büyük-küçük harf kuralı özel dikkat.
5. **Extension'lar.** `context.gu` (colors/text/spacing/radius/shadows/motion/sizes), `context.l10n`, `DateTime` (İstanbul), `String` (trLower, initials), `num`/`int`, `List`. Hangi extension hangi pakette; kapsam sınırı.
6. **Sabitler.** Limitler (`Limits`), süreler, regex'ler, alan adları, kategori/ilgi/fakülte/bölüm/mekân/yıl/tür tabloları, Remote Config anahtarları, rota adları, Firestore alan/koleksiyon adları, toast/dialog/sheet ID enum'ları. Hangi dosyada duracak, **tek kaynak**.
7. **Mixin / taban sınıflar.** `ProjectDependencyMixin`, `AppProviderMixin`, ekran mixin'leri (form doğrulama, sayfalama, optimistik güncelleme, kaydedilmemiş değişiklik koruması, klavye/odak), `GuKey`, `GuTapTarget`, `GuSystemUi`. Her biri için sorumluluk, API, test.
8. **Token eşleme taslağı.** `registry.json#tokens` → Dart adları tablosu (`docs/token-map.md` taslağı): renk (27 × 2), tipografi (11), boşluk, radius, gölge, hareket, boyut (CSS'ten: `btn`, `input`, `chip`, `tile`, `appbar`, `tabbar`… yükseklikleri). Anlamsal renk adlarını **registry'deki adlarla** eşle, uydurma ad yok.
9. **Overlay'ler.** Sheet/dialog/toast çerçevelerinin ortak davranışı (scrim, X, sürükle, geri, odak tuzağı, klavye, `full`/`flush`/`menu`/`footer` varyantları), `FeedbackService` API'si ve ID katalogları.
10. **Boşluklar ve tutarsızlıklar.** Tasarımın kendi içinde çelişen/eksik yerleri (renk eşleşmeyen, iki farklı yükseklik, eksik durum) → `docs/design-known-issues.md`'ye **K-24…** olarak ekle ve kullanıcıya bildir; çözüm gerekiyorsa `AskUserQuestion`.
11. **Görev dağılımı.** Her bileşeni, yardımcıyı, extension'ı ve sabiti **T-01…T-07**'ye ata (roadmap'teki `components` listeleriyle karşılaştır). Roadmap'e **eklenen/çıkan** bileşen varsa tek tabloda göster; task sırası değişmez, yalnızca içerik dağılımı onayla düzeltilir.
12. **Widget kataloğu.** `docs/widget-catalog.md` iskeleti: her planlı widget · konum · durum (`planned`) · task · tasarım ID'leri. Sonraki task'lar bunu günceller; yeni widget yazmadan önce taranır (D-16).
13. **Doğrulama stratejisi.** Bileşen bazlı test planı: durum testleri, golden, matris, dokunma hedefi, anlamsal etiket; token testinin JSON'dan okuyacağı dosyalar.

## Çıktı kalite ölçütü

- Şablondaki **her** bileşen satırı doldurulmuş ya da "tasarımda yok / birleştirildi → X" gerekçesiyle kapatılmış.
- Her bileşen için en az bir referans görüntü yolu ve en az bir kullanıldığı ekran ID'si var.
- Hardcode edilebilecek her değer (ölçü, süre, renk, metin, limit) bir token/sabit/ARB satırına eşlenmiş.
- Tekrar tablosu (adım 2) boş değilse kararlar yazılı; boşsa "tekrar bulunmadı" ve kanıt (karşılaştırma tablosu).
- `T-01…T-07` dağılımı roadmap ile uyumlu.

## Onay

1. `EnterPlanMode` → dosyaları yaz → denetle → `ExitPlanMode` ile kullanıcıya sun.
2. Kullanıcıya Türkçe özet: bileşen sayısı · önerilen birleştirmeler · yeni K-xx bulguları · roadmap içerik değişiklikleri · açık sorular.
3. Onay gelince `node tool/progress.js gate analysis` (= `gate.designAnalysisApproved = true`), `T-01` planına geç (`prompts/task-calistir.md`). Komut şunlar yoksa **reddeder**: `docs/widget-catalog.md`, `docs/token-map.md`, `docs/design-analysis.md`'de A–K bölümleri, ve `⟂` içeren her (blockquote `>` olmayan) satır. Bu yüzden onaydan **önce** `grep -n '⟂' docs/design-analysis.md` ile kendin tara.
4. Onay gelmezse düzeltmeleri uygula; **onaysız T-01 yok.**
