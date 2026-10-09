---
name: gu-decision-log
description: Kararları, soru cevaplarını, tasarım sapmalarını ve yeni tasarım kusurlarını (K-xx) docs altında kayda geçirme. Bir kilitli karar değişecekse, kullanıcı bir soruyu cevapladıysa, tasarımda kusur bulunduysa veya yeni bir kural doğduysa kullan.
---

# gu-decision-log

## Neyi nereye

| Olay | Dosya | Biçim |
|---|---|---|
| Soru turu cevabı (Q-xx / K-adayı) | `docs/decisions.md §B` | tablo satırı: seçim + tarih; `node tool/progress.js answer Q-xx "<seçim>"` |
| Yeni karar (kullanıcı onaylı) | `docs/decisions.md §A` | `D-37…`: karar · gerekçe · etkilenen dosyalar |
| Kilitli kararın değişmesi | `docs/decisions.md §C` süreci | `~~eski~~ → yeni`, tarih, neden; yansımaları **aynı commit'te** (`CLAUDE.md`, `docs/*`) |
| Tasarım kusuru / sapma | `docs/design-known-issues.md` | `K-24…`: kusur · etki · Flutter kararı; kullanıcıya bildir |
| Tasarımdan onaylı sapma | `docs/design-contract.md §8` | ekran · neden · onay tarihi |
| Task notu / bulgu | `docs/plans/T-xx.md` "Notlar" | |
| Bağlama borcu | `progress.json#pendingWiring` | `node tool/progress.js wiring add --declared-in T-xx --resolve-in T-yy --text "…" [--keys "ID.aksiyon,…"]` · `wiring close W-xx` |
| Widget/token | `docs/widget-catalog.md`, `docs/token-map.md` | aynı commit |

## Kurallar

- **Sessiz sapma yok.** D-xx/Q-xx/tasarım değişecekse önce `gu-ask-user`.
- Kayıt **olay anında** yazılır, task sonuna bırakılmaz.
- Cevaplar kullanıcının sözleriyle; yorum ayrı.
- Değişen karar → bağlı task'ların `docs/roadmap.md`/`task-map.json` etkisi `docs/PLAN.md` "Açık noktalar"da izlenir (roadmap otomatik üretilmiş dosyadır: elle düzenleme için kullanıcı onayı + `decisions.md` kaydı).
- Gizli bilgi (anahtar, servis hesabı) hiçbir belgeye yazılmaz (D-36).
