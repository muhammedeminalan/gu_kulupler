---
name: gu-screen-from-design
description: Bir tasarım ID'sini (ekran, sheet, dialog, toast) Flutter'a 1:1 çevirir. Referans görüntü + prototip kaynağı okuma, aksiyon envanteri, 5 durum, durum çubuğu, geçiş, responsive, cihaz matrisi, golden. Herhangi bir CLB-/EVT-/MGT-/ADM- vb. ekranı veya SHT-/DLG-/TST- uygularken kullan.
---

# gu-screen-from-design — tasarımı 1:1 çevirme

Sözleşme: `docs/design-contract.md`. Kusurlar: `docs/design-known-issues.md`. Bu beceri ekran başına uygulama sırasıdır.

## 1. Oku (yazmadan önce)

1. `design/extracted/registry.json` → ID'nin yolu/sekmesi/rolü; `screens-actions.json` → **aksiyon listesi** (`<ID>.<aksiyon>`).
2. `design/reference-shots/**/<ID>*` — **tüm** görüntüleri aç: açık/koyu/EN, durumlar (`states/`), klavye varyantı varsa.
3. `design/prototype/app/screens-*.js` (veya `sheets.js`/`dialogs.js`) içindeki ilgili blok: yapı, koşullar, hangi aksiyon neyi açıyor/yazıyor. **Port etme; anlamsal çevir** (Preact → Flutter).
4. İlgili iş kuralı: `docs/domain-model.md` / `design/prototype/claude-design-prompt.md` bölümü; ilgili K-xx.

## 2. Haritala (plan dosyasına yaz)

| Çıktı | İçerik |
|---|---|
| Bölüm ağacı | AppBar → içerik bölümleri → sticky CTA; her bölüm hangi `Gu*`/`product` widget'ı |
| Aksiyon tablosu | `GuKey.action(...)` ↔ ekranın sonucu (rota / sheet / dialog / toast / durum değişimi) |
| Durumlar | normal · yükleniyor (skeleton) · boş · hata · çevrimdışı · (role/durum varyantları) — tasarımda ne varsa |
| Veri | ViewModel State alanları, hangi repository çağrıları, canlı mı tek seferlik mi |
| Sistem arayüzü | durum çubuğu ikon rengi (design-contract §5), klavye, güvenli alan, kabuk (alt çubuk) görünürlüğü |
| Bağlama | başka task'a giden noktalar → `pendingWiring` |

## 3. Uygula

- Sınıf üstünde `/// Design: <ID>`; her etkileşimli öğeye `GuKey.action`.
- Mevcut widget'larla kur (`widget-catalog`); eksik varsa `gu-widget`.
- Koşullu render: **hata → yükleniyor → boş → dolu**; çevrimdışı banner kök katmanda.
- **Responsive:** `LayoutBuilder`/`Flexible`/`Wrap`/ellipsis; sabit genişlik yok; 320 dp'de sağ taşma sıfır; klavye açıkken kaydırma.
- **Durum çubuğu:** ekran `GuSystemUi` stilini bildirir (kapaklı/koyu zemin → açık ikon); elle `SystemChrome` yok.
- **Geçişler:** platform varsayılanı; özel yalnızca `navigation.md §5`. Sheet/dialog/toast yalnızca `FeedbackService`.
- **Metin:** yalnızca ARB; tarih/sayı `intl` + İstanbul saat dilimi.
- **Mock'lar uygulanmaz** (K-02): Demo FAB, kontrol paneli, "(Demo)" düğmeleri, `demoScan`, `demoVerify`, `demoAccount`.

## 4. Doğrula (hepsi yeşil olmadan bitmez)

1. Aksiyon envanteri: `node tool/check_design_coverage.js --task T-xx --actions` ve widget testi.
2. Her aksiyonun sonuç testi (rota/sheet/dialog/toast/durum).
3. Durum testleri; cihaz matrisi (`DeviceMatrix`); golden.
4. **Referans karşılaştırma:** kendi golden/çıktını `reference-shots` ile **yan yana aç**, ölçü · boşluk · renk · metin · ikon · durum farklarını yaz; fark varsa düzelt veya K-xx olarak kaydet. Gerekirse `gu-design-fidelity-reviewer` ajanını çağır.

## 5. Yaygın hatalar

- Prototipteki `--safe-top: 54px` veya sabit 844 px yüksekliği taklit etmek (mock — gerçek inset kullan).
- Görsel ölçüyü dokunma hedefi için büyütmek (görsel 1:1 kalır; alan `GuTapTarget` ile genişler).
- Tasarımda olmayan boş/hata durumu uydurmak.
- Rol varyantını (ziyaretçi/pending/rejected/member/manager/advisor/super) atlamak.
