---
name: gu-ask-user
description: Kullanıcıya seçenekli soru sorma kuralları (AskUserQuestion açılır penceresi). Belirsizlik, kilitli kararla çelişki, kapsam dışı istek, birden çok geçerli yaklaşım veya soru bankası turu olduğunda kullan; asla düz metinle seçenekli soru sorma.
---

# gu-ask-user — AskUserQuestion kuralları

**Kural:** Seçenek sunulabilecek her soru **`AskUserQuestion`** ile sorulur. Düz sohbet metniyle "A mı B mi?" **yasak.** Araç şeması yüklü değilse önce `ToolSearch` ile `select:AskUserQuestion` yükle.

## Biçim

| Alan | Kural |
|---|---|
| Çağrı başına soru | **1–4** (aynı konuya ait olanları grupla; bağımlı sorular ayrı çağrı) |
| `header` | ≤ **12 karakter**, isim gibi ("Backend", "Takvim") |
| `options` | **2–4**, birbirini dışlar; "Diğer" seçeneğini **sen ekleme** (araç ekler) |
| `label` | 1–5 kelime, Türkçe |
| `description` | tek kısa cümle: *neyi getirir / neyi götürür* |
| Öneri | Önerin varsa **ilk seçenek** yap ve etiketin sonuna ` (Önerilen)` ekle; gerekçeyi description'a yaz |
| `multiSelect` | yalnızca seçenekler gerçekten birlikte seçilebilirse |
| `preview` | görsel/kod karşılaştırması gerekiyorsa (ör. iki yerleşim); yoksa kullanma |
| Dil | Türkçe, jargonsuz; "ne seçersem ne olur" açık olsun |

## Ne zaman sor

- Cevaplanmamış Q-xx / K-adayı; soru bankası turu.
- İki kilitli kaynak çelişiyor ya da bir D-xx/Q-xx **gerçekten uygulanamıyor**.
- Tasarımda olmayan bir durum/davranış gerekiyor (uydurma).
- Docs'ta "K-sorusu adayı" olarak işaretlenmiş nokta.
- Paket listesinde olmayan bağımlılık gerekiyor (gerekçe + alternatif + bakım durumu).
- Geri dönülemez/riskli işlem (gerçek Firebase'e yazma, deploy, kalıcı silme, `git push`, golden toplu güncelleme).
- Task planı sırasında çıkan, planı etkileyen belirsizlik.

## Ne zaman SORMA

- Cevap `CLAUDE.md`, `docs/*`, `design/*` içinde zaten yazılıysa — oku.
- Salt biçim/isimlendirme tercihi (CLAUDE.md konvansiyonunu uygula).
- Kullanıcının daha önce cevapladığı soru (`docs/decisions.md`, `progress.json#questionsAnswered`).

## Cevabı işle

1. `docs/decisions.md` tablosuna **olduğu gibi** yaz (seçilen etiket, tarih). Serbest ("Diğer") cevap: kullanıcının sözleri tırnak içinde + kısa yorum; belirsizse tek soruyla netleştir.
2. `node tool/progress.js answer <Q-xx|K-xx> "<seçim>"`.
3. Etkilenen dosyaları/ task'ları söyle (kısa).
4. Kullanıcı soruyu reddeder/yanıtlamazsa: önerilen seçeneği **uygulama**; işi bekleyen kısmı durdur, kalan bağımsız işe geç ve bunu bildir.

## Şablon

```json
{
  "questions": [{
    "header": "Takvim",
    "question": "Etkinlik takvimi hangi bileşenle yapılsın?",
    "multiSelect": false,
    "options": [
      {"label": "Kendi GuCalendar (Önerilen)", "description": "Token'larla 1:1, ek paket yok; yazması daha uzun."},
      {"label": "table_calendar paketi", "description": "Hızlı; tasarıma uydurmak için yoğun özelleştirme + bağımlılık."}
    ]
  }]
}
```
