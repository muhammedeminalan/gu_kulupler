---
name: gu-task-runner
description: docs/roadmap.md'deki tek bir T-xx task'ını baştan sona çalıştırır (seçim, okuma, plan modu, uygulama, kalite kapısı, inceleme ajanları, commit, rapor). Kullanıcı "devam", "sıradaki task", "T-17'yi çalıştır" dediğinde veya bir task bittiğinde kullan.
---

# gu-task-runner — task döngüsü

Protokol: [`prompts/task-calistir.md`](../../../prompts/task-calistir.md) — **bu beceri onun kısa kontrol listesidir**, çelişkide prompt kazanır.

## Başlamadan

- `node tool/progress.js show` / `next`. Kapılar: `planApproved`; T-01+ için `designAnalysisApproved`.
- Bağımlılıklar `done`/`skipped`. `git status` temiz.
- Aynı anda **tek** task. Atlama/birleştirme/yeniden sıralama yok.

## Plan kontrol listesi (`docs/plans/T-xx.md`, ExitPlanMode öncesi)

- [ ] Kapsam kimlikleri `docs/task-map.json` ile birebir (fazla/eksik yok).
- [ ] Okunan kaynaklar listelenmiş (reference-shots yolları dahil).
- [ ] Yeniden kullanılacak widget'lar `widget-catalog`'dan; yeni widget gerekçeli.
- [ ] Dosya listesi katman katman; ViewModel/State alanları ve metotları adıyla.
- [ ] Her aksiyon: `GuKey.action(...)` ↔ sonuç (rota/sheet/dialog/toast/durum).
- [ ] 5 durum (normal/yükleniyor/boş/hata/çevrimdışı) hangileri tasarımda varsa hepsi.
- [ ] Rota/geçiş: `navigation.md` satırları, kabuk görünürlüğü, durum çubuğu stili.
- [ ] ARB anahtarları (var mı / eklenecek mi), TR+EN.
- [ ] Veri: Rules + indeks + Rules testi + seed aynı commit'te (varsa).
- [ ] Test planı adıyla: widget, golden, matris, envanter, ViewModel, repository, Rules.
- [ ] Bağlama borçları: açılan ve kapanan `W-xx`.
- [ ] Riskler ve açık sorular (varsa önce `gu-ask-user`).
- [ ] `docs/roadmap.md §6` Bitti listesine uygun.

## Uygularken

`TaskCreate` ile alt görevler; sıra: model/servis → Rules+test → ViewModel+State → widget → ekran → rota → ARB → test/golden. Kırmızıyla ilerleme. Sapma gerekirse **dur ve sor.**

## Bitirirken

1. `bash tool/quality_gate.sh --task T-xx` tam yeşil.
2. Ajanlar (paralel): `gu-architecture-reviewer`, `gu-test-auditor`, UI varsa `gu-design-fidelity-reviewer`, veri varsa `gu-firebase-security-reviewer`. Kritik/önemli bulguyu düzelt, kapıyı tekrar koş.
3. Belgeler: widget-catalog, token-map, decisions, known-issues; `node tool/progress.js wiring close|open`; `node tool/progress.js done T-xx --commit <sha>`.
4. Commit: `feat(T-xx): <Türkçe açıklama>`; push yok.
5. Rapor ≤ 8 satır Türkçe; sonra sıradaki task'ın plan moduna geç.
