---
name: gu-design-analysis
description: Tasarım dışa aktarımını analiz edip docs/design-analysis.md üretir (çekirdek widget'lar, util'ler, extension'lar, sabitler, token eşlemesi, tekrar analizi). T-00 sonrası T-01 öncesi Faz 1'de, veya kullanıcı "tasarımı analiz et" dediğinde kullan.
---

# gu-design-analysis — Faz 1

Protokol: [`prompts/03-faz1-tasarim-analizi.md`](../../../prompts/03-faz1-tasarim-analizi.md). Şablon: `docs/design-analysis.TEMPLATE.md`. Çıktılar: `docs/design-analysis.md`, `docs/widget-catalog.md` (planlı), `docs/token-map.md` (taslak).

## Çalışma biçimi

1. Girdileri **gerçekten** aç: `design/extracted/component-css.css`, `css-class-usage.json`, `registry.json#tokens`, `design/prototype/app/{ui,cards,shell,core,sheets,dialogs}.js`, ilgili `design/reference-shots/states/*` ve ekran görüntüleri (`Read` ile görüntüle).
2. Şablondaki ≈ 60 bileşen satırının **tamamını** doldur; her satır: prototip adı · kaynak:satır · CSS sınıfları · varyantlar · durumlar · token'lar · kullanıldığı ekran ID'leri · Flutter adı · konum (`gu_ui` | `lib/product/widget/`) · API taslağı · referans görüntü.
3. **Tekrar tablosu** (D-16): aynı işi yapan bileşenleri birleştirme önerisiyle ver; kararsızsan `gu-ask-user`.
4. Her hardcode edilebilir değeri (boy, süre, renk, metin, limit) bir token/sabit/ARB satırına eşle.
5. Tasarımda **olmayan** durum uydurma; var olanı kanıtla (görüntü/CSS).
6. Tutarsızlıkları `docs/design-known-issues.md`'ye **K-24…** olarak ekle (ekran · kanıt · karar).
7. T-01…T-07 dağılımını roadmap `components` listeleriyle karşılaştır; fark varsa tabloda göster (task sırası değişmez).
8. Plan modunda yaz, `ExitPlanMode` ile onaya sun; onay gelince `node tool/progress.js gate analysis`. Komut `⟂` (doldurulmamış hücre) kalmışsa, `widget-catalog.md`/`token-map.md` yoksa veya A–K bölümleri eksikse reddeder — önce `grep -n '⟂' docs/design-analysis.md`.

## Kalite ölçütü

- Boş hücre yok ("—" bile gerekçelidir).
- Her bileşen için en az bir referans görüntü ve bir kullanım ekranı.
- Yeni K-xx varsa kullanıcıya özetle.
- Uygulama kodu yazılmadı.
