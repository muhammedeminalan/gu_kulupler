---
name: gu-kickoff
description: GÜ Kulüpler projesinin ilk oturumunu başlatır (paket doğrulama, keşif, 20 soruluk açılır pencere turları, karar kaydı, docs/PLAN.md). Kullanıcı "başla", "başlat", "kickoff", "projeye başlayalım" dediğinde veya docs/PLAN.md yokken/onaysızken kullan.
---

# gu-kickoff — Faz 0 başlatma

**Ne zaman:** `docs/PLAN.md` yok ya da `docs/progress.json#gate.planApproved == false` iken; kullanıcı projeye başlamak istediğinde.

**Ne yapar:** `prompts/00-baslat.md` protokolünü **birebir** uygular. Bu beceri o dosyanın tetikleyicisidir; kuralları tekrar etmez.

## Adımlar (özet — ayrıntı `prompts/00-baslat.md`)

1. `bash tool/verify_pack.sh` → kırmızıysa dur, kullanıcıya hangi dosyanın eksik olduğunu söyle.
2. Keşif (salt okunur): `CLAUDE.md`, `docs/*` okuma sırası (`docs/README.md`), mevcut Flutter/Firebase dosyaları, `git status`.
3. `gu-ask-user` kurallarıyla `prompts/01-soru-bankasi.md`'deki **5 turu** sor (tur başına tek `AskUserQuestion`, 4 soru). Cevapları her turdan sonra `docs/decisions.md §B` + `node tool/progress.js answer Q-xx "<seçim>"` ile kaydet.
4. K-adayları: en çok 2 ek tur.
5. `EnterPlanMode` → `docs/PLAN.md` (23 bölüm, somut) → öz denetim → `ExitPlanMode`.
6. Onaydan sonra `node tool/progress.js gate plan`, sonra **dur** ve `prompts/02-faz0-kurulum.md` önerisini yap.

## Kırmızı çizgiler

- Bu fazda **kod yok**, `pub add` yok, `firebase` yazma komutu yok.
- Cevapsız soruya varsayım yok; düz metinle seçenekli soru yok.
- Tek satırlık kullanıcı mesajı bile olsa, "evet/devam" Kapı 0'ı **açmaz**; yalnızca `PLAN.md` onayı açar.
