---
name: gu-quality-gate
description: tool/quality_gate.sh kalite kapısını çalıştırma ve çıktısını yorumlama. Commit öncesi, task bitişinde, "kapı kırmızı" veya "hook uyardı" durumlarında kullan.
---

# gu-quality-gate

```
bash tool/quality_gate.sh --task T-xx      # task bitişi (done için ZORUNLU)
bash tool/quality_gate.sh --fast           # ara kontrol
bash tool/quality_gate.sh --static         # testsiz statik kontrol
bash tool/quality_gate.sh --final          # T-47: nihai
```

Sıra: **biçim → codegen (+gen-l10n) → `flutter analyze --fatal-infos` → sınır denetimi → hardcode → no-hard-delete → ARB eşitliği (`--strict`) → tasarım haritası + kapsam → testler (+ kapsam eşikleri) → Rules/Functions testi** (`firebase/`, `functions/` varsa). Kırmızıyken **commit yok**, `--no-verify` yok.

## Modlar

| Mod | Ne zaman | `progress.js done` için geçerli mi |
|---|---|---|
| `--fast` | geliştirme sırasında ara kontrol (biçim + analiz + taramalar + **hızlı matris** `GU_MATRIX=fast`; codegen/kapsam/Rules yok) | ❌ |
| `--static` | yalnızca statik: test koşmaz | ❌ |
| `--task T-xx` | task bitişi: **tam matris** + kapsam eşikleri + Rules + `check_design_coverage.js --task T-xx --actions` | ✅ (kod sonradan değişmediği sürece) |
| (bayraksız) | faz sonu: biten task'ların kapsamı | ❌ |
| `--final` | T-47: tüm kimlikler/aksiyonlar, kullanılmayan ARB, açık borç 0, yer tutucu 0 | ✅ (task `FINAL`) |

`done` komutu `tool/.cache/last_gate.json` kaydına bakar: aynı task, **tam mod**, **geçti** ve kod (docs/ hariç) kapıdan sonra değişmemiş olmalı. Kapıdan sonra kod değiştirdiysen kapıyı yeniden koş.

## Çalıştırma notları (Claude Code)

- Bash aracının varsayılan zaman aşımı 2 dk'dır; tam kapı daha uzun sürer → `timeout: 600000` ver ya da arka planda çalıştır ve `tool/.cache/gate-logs/` loglarını oku.
- Çıktı kısadır: her adım tek satır; başarısız adımın son 45 satırı gösterilir, tam log `tool/.cache/gate-logs/NN-ad.log`. Uzun log'u bağlamına dökme; yalnızca ilgili kısmı oku.
- `GU_GATE_VERBOSE=1` çıktıyı akıtır; `GU_GATE_STATIC_ONLY=1` flutter/dart adımlarını atlar (yalnızca Flutter kurulu olmayan ortamlar için).

## Hata → çözüm

| Kapı | Tipik sebep | Çözüm |
|---|---|---|
| analyze | `--fatal-infos`, `very_good_analysis` | Kodu düzelt; `// ignore:` yalnızca gerekçeli |
| hardcode | renk/boşluk/radius/süre/metin/ikon literal | Token/ARB/`GuIcons`; eksik token → token katmanına ekle (`token-map.md`) |
| no-hard-delete | `.delete(`, `deleteDoc`, `allow write` | `softDelete/restore` (`gu-soft-delete`) |
| ARB | TR/EN eşit değil, ICU yer tutucu uyumsuzluğu (ARB06–08), ürün adı literali (ARB09), kullanılmayan anahtar (`--final`) | İkisine birden ekle/çıkar; ICU tuzakları için `gu-l10n`; dinamik kullanılan anahtar `tool/arb_dynamic_keys.txt` (gerekçeli) |
| design coverage | ID'ye `/// Design:` izi / test / kullanım yok (IZ01, TEST01, KUL01), aksiyon anahtarı eksik/fazla (AKS01/AKS02), katalog (KAT*) | İzi/test/anahtarı ekle; fazlalığı sil. Başka task'ın ekranına giden giriş noktası ise **bağlama borcu**: `node tool/progress.js wiring add … --keys "<ID>.<aksiyon>"` (anahtar borç kapanana dek aklanır). Muaf liste (`EXEMPT_ACTIONS`) değişikliği kullanıcıya sorulur |
| boundaries | `gu_ui` → `gu_data` import, `gu_data` → `flutter/material` | Katman ihlalini düzelt |
| test | kırık/eksik test | Düzelt; **silme/skip yok** |
| kapsam | gu_data/gu_ui ≥ %90, provider/view_model ≥ %90, view ≥ %80 (`check_coverage.js`) | Eksik davranış testlerini yaz; lcov'da görünmeyen dosya = hiç test yüklemiyor |
| golden | piksel farkı | Referansla karşılaştır; bilinçli ise `--update-goldens <dosya>` + kullanıcıya bildir |

## Hook'lar (`.claude/settings.json`)

`PostToolUse` → dosya yazılınca `tool/hooks/post_edit.sh`: `.dart` (lib/, packages/*/lib) için hardcode + hard delete + katman sınırı; Rules/Functions/`tool/admin` için hard delete; `assets/**/*.svg` için rgba taraması. İhlalde çıkış 2 ve mesaj geri beslenir. Uyarı = düzelt, geçme. `SessionStart` → `node tool/progress.js brief` (ilerleme özeti).

## Rapor

Kapı sonucunu kullanıcıya tek satırda ver ("Kapı yeşil: analiz 0, test 412/412, matris 72×6, kapsam T-17 tam"). Kırmızıyı örtbas etme.
