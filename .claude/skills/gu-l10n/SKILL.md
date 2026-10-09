---
name: gu-l10n
description: ARB tabanlı yerelleştirme (TR şablon, EN) kuralları. UI'a metin eklerken, ARB anahtarı eklerken/değiştirirken, çoğul/parametre/tarih biçimi veya Türkçe büyük-küçük harf konularında kullan.
---

# gu-l10n

Kurallar `CLAUDE.md §8`, kararlar D-07/D-02/D-01. Araçlar: `l10n.yaml`, `lib/l10n/app_tr.arb` (şablon), `app_en.arb`, `tool/check_arb_parity.js`.

## Kurallar

1. **UI'da string literal yok.** Her metin `context.l10n.<anahtar>`.
2. **Anahtar adı** tasarım anahtarının camelCase'i (`a11y.back → a11yBack`, `club.cta.createEvent → clubCtaCreateEvent`). Orijinal anahtar `@anahtar.description` içinde kalır.
3. **TR ve EN anahtar kümesi eşit** (1235). Yeni metin: önce **iki ARB'ye birden**, sonra kullanım. `node tool/check_arb_parity.js` kapıdadır; kullanılmayan anahtar uyarı verir.
4. **Parametre/çoğul ICU:** `{count, plural, =0{…} one{…} other{…}}`; `{name}` yer tutucuları `@anahtar.placeholders` ile tipli. **String birleştirme yok.**
5. **Ürün adı** `{appName}` yer tutucusu (D-01/K-22) — literal ad yok; Türkçe iyelik eki gerekiyorsa ayrı parametre (`{appNameDative}`).
6. **Tarih/saat/sayı** `intl` + `Europe/Istanbul`; TR hafta Pazartesi başlar; "Bugün/Yarın" ARB'de; göreli süreler ICU.
7. **Türkçe büyük/küçük harf:** `İ ı I i` — `toUpperCase()/toLowerCase()` doğrudan kullanılmaz; `trLower/trUpper` yardımcısı (locale `tr`). Arama eşleşmesi ve "SİL"/"DEVRET" doğrulaması bununla.
8. **Platform metinleri** (izin açıklamaları, bildirim kanalı adları): iOS `InfoPlist.strings` TR/EN; Android kanal adları ARB'den.
9. **Yerel ayar:** kullanıcı tercihi (SHT-01) `shared_preferences`; `MaterialApp.locale`.
10. Hata/toast metinleri `ToastId` kataloğu üzerinden; metin `registry.json#toasts` (TR) ile **eşleşir** (K-01).

## Yeni metin ekleme

```jsonc
// app_tr.arb
"clubMembersEmpty": "Henüz üye yok",
"@clubMembersEmpty": { "description": "Key club.members.empty" }
// app_en.arb
"clubMembersEmpty": "No members yet"
```
Sonra `flutter gen-l10n` (tool/codegen.sh) → `context.l10n.clubMembersEmpty`.

**ICU tuzakları (K-23, `check_arb_parity.js` ARB04–ARB08 yakalar):** `'{q}'` tırnaklı **literaldir** — düz tırnak için `''{q}''` (ya da tipografik “{q}”); plural dal metni (`=0{bugün}`) yer tutucu değildir, `placeholders`'a yazılmaz; `@anahtar.description` her zaman `Key grup.ad` biçimindedir; plural sayacı `int`/`num` tipindedir; `select` durumları TR/EN'de aynıdır.

## Test

TR/EN eşitliği · ICU parametre tipleri · çoğul biçimleri (0/1/n) · Türkçe harf dönüşümü (`trLower("ISPARTA") == "ısparta"`, `trLower("İSTANBUL") == "istanbul"`, `trUpper("istanbul") == "İSTANBUL"`) · ekran testlerinde TR ve EN ayrı · EN'de uzun metinle taşma (matris).
