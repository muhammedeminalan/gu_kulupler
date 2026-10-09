# TASK ÇALIŞTIR — tek task'ın tam döngüsü

> **Kullanım:** Kullanıcı "devam" / "sıradaki task" dediğinde ya da bir task bittiğinde bu dosyayı yeniden uygula. İstenirse belirli task: "T-17'yi çalıştır".
> **Kural:** Aynı anda **yalnızca bir** task. Atlama, birleştirme, yeniden sıralama yok (D-32). Bu protokolün hiçbir adımı atlanmaz; atladığını fark edersen dur, geri dön.
> Kullanıcıya Türkçe, kısa. Soru = `AskUserQuestion`.

## 0. Kapılar ve durum

1. `node tool/progress.js show` — mevcut durum.
2. `gate.planApproved` **ve** (T-01 ve sonrası için) `gate.designAnalysisApproved` true olmalı; değilse ilgili faza dön (`prompts/00-baslat.md` / `prompts/03-faz1-tasarim-analizi.md`).
3. `node tool/progress.js next` — sıradaki task: durumu `pending`, bağımlılıkları `done`/`skipped`. Koşullu T-42: `Q-02` cevabı yoksa/Functions değilse `skipped` işaretle (gerekçe yaz).
4. `git status` temiz olmalı. Değilse kullanıcıya sor (kendi değişikliklerini ezme).
5. Tek cümleyle duyur: "T-xx başlıyor: <başlık>. Önce plan moduna geçiyorum." (başlangıç mesajı)

## 1. Oku (plan modundan önce)

| Ne | Nasıl |
|---|---|
| Task | `docs/roadmap.md` içindeki T-xx bölümü + `docs/task-map.json` girdisi (`node tool/check_design_coverage.js --task T-xx --list` kapsamı ve açılacak/kapanacak borçları yazdırır) |
| Bağlama borçları | `progress.json#pendingWiring` içinde `resolveIn` ∋ T-xx olanlar (**bu task kapatır**) ve bu task'ın `wires` listesi (**bu task açar**) |
| Tasarım | Her ekran/sheet/dialog/toast ID'si için `design/reference-shots/**` görüntüsünü **aç** (açık/koyu/EN/durumlar), prototip kaynağını (`design/prototype/app/*.js`) oku, `screens-actions.json` aksiyon listesini al |
| Sözleşmeler | İlgili `docs/*` bölümleri: UI → `design-contract.md`, `navigation.md`, `testing.md`; veri → `domain-model.md`, `firestore-rules-spec.md`, `soft-delete.md`; kusurlar → `design-known-issues.md` (ilgili K-xx) |
| Tekrar | `docs/widget-catalog.md` (varsa) ve `docs/design-analysis.md` — yeni widget yazmadan önce tara |
| Kararlar | `docs/decisions.md` (D-xx, cevaplanmış Q/K) — özellikle task'ın `Ön koşul soruları` |

Cevaplanmamış bir ön koşul sorusu (Q/K) varsa **plan modundan önce** `AskUserQuestion` ile sor.

## 2. Plan modu

1. `EnterPlanMode` + `node tool/progress.js plan T-xx` (sıra, kapılar ve cevaplanmamış ön koşul sorularını denetler; durum `planning`).
2. Planı `docs/plans/T-xx.md` dosyasına yaz (roadmap §8 şablonu, 11 madde). Zorunlu somutluk: dosya yolu listesi, sınıf/ViewModel/State adları, her aksiyon için `GuKey.action` anahtarı ↔ sonuç (rota/sheet/dialog/toast/durum), ARB anahtarları (var/yok), test listesi (adıyla), Rules/indeks değişikliği (varsa), bağlama borçları (açılan/kapanan W-xx), riskler.
3. Planı kendin denetle: [`.claude/skills/gu-task-runner/SKILL.md`](.claude/skills/gu-task-runner/SKILL.md) "Plan kontrol listesi".
4. Belirsizlik kaldıysa önce `AskUserQuestion`, sonra `ExitPlanMode`.
5. `ExitPlanMode` → **kullanıcı onayı**. Onay yoksa uygulamaya geçme. Onay sonrası `node tool/progress.js start T-xx` (`docs/plans/T-xx.md` yoksa reddeder).

## 3. Uygula

- Görev listesini `TaskCreate` ile kur (planın dosya grupları, testler, kapı, inceleme, belgeler, commit). Her biri bitince `TaskUpdate`.
- **Sıra:** model/servis/repository → Rules + indeks + Rules testi (veri task'larında aynı commit) → ViewModel + State (+ testleri) → widget'lar (`gu_ui` önce) → ekran/sheet/dialog/toast → rota → ARB → testler → golden.
- Her küçük adım sonrası ilgili testi koş; **kırmızıyla ilerleme.**
- Beceriler: UI → `gu-screen-from-design`, `gu-widget`; veri → `gu-firebase-model`, `gu-soft-delete`; rota → `gu-navigation`; metin → `gu-l10n`; test → `gu-testing`. İlgili beceri otomatik tetiklenmezse `Skill` aracıyla çağır.
- Sapma gereksinimi çıkarsa **dur → `AskUserQuestion`** (D-xx/Q-xx/K-xx değişmez; yeni K-xx doğrulanan kusurdur). Karar `decisions.md`'ye yazılır.
- Hook'lar uyarırsa (hardcode / hard delete) **uyarıyı gider**, susturma.

## 4. Doğrula

1. `bash tool/quality_gate.sh --task T-xx` — **tam yeşil** olana kadar düzelt. `--fast`/`--static` yalnızca ara kontrol içindir; `done` yalnızca tam kapıyı kabul eder ve kapıdan sonra kod değişirse reddeder. Bash aracı varsayılan 2 dk'da keser: `timeout: 600000` ver ya da arka planda çalıştır.
2. Tasarım kapsamı: `node tool/check_design_coverage.js --task T-xx --actions` (kapıda da koşar).
3. Cihaz matrisi, durum, aksiyon envanteri, golden: planlanan testlerin hepsi yeşil; **golden güncellemesi** yalnızca bilinçli ve kullanıcıya bildirilir.
4. **İnceleme ajanları** (paralel, salt okunur) — bulguları sınıflandır (kritik/önemli/küçük):
   - `gu-architecture-reviewer` (her task)
   - `gu-test-auditor` (her task)
   - `gu-design-fidelity-reviewer` (ekran/sheet/dialog/toast içeren task'lar; referans görüntüyle karşılaştırır)
   - `gu-firebase-security-reviewer` (Rules/repository/servis değişen task'lar)
   Kritik ve önemli bulgular **düzeltilir ve kapı yeniden koşar**; küçükler `docs/plans/T-xx.md` "Notlar"a yazılır. Ajanlara **yalnızca kodu/dosya yollarını ver, kendi sonucunu söyleme** (bağımsız okuma).
5. `docs/roadmap.md §6` 'Bitti' kontrol listesini tek tek işaretle (plan dosyasına yaz).

## 5. Belgeler ve kayıt

- `docs/widget-catalog.md` (yeni/değişen widget), `docs/token-map.md` (yeni token), `docs/decisions.md` (yeni karar), `docs/design-known-issues.md` (yeni K-xx).
- Bağlama borçları: bu task'ın **kapattıkları** → `node tool/progress.js wiring close W-xx`; **yeni açtığın** (task-map `wires`'te olmayan) → `wiring add --declared-in T-xx --resolve-in T-yy --text "…" --keys "ID.aksiyon,…"` (uygulanmayan giriş noktalarının `GuKey.action` anahtarları; borç kapanana dek `check_design_coverage` bunları akla). `wiring list` durumu gösterir. `done`, bu task'ta kapanması gereken açık borç varsa reddeder.
- `node tool/progress.js done T-xx --commit <sha>` (kapı sonucu ve notla).

## 6. Commit

- Conventional Commits, kapsam = task ID, açıklama Türkçe: `feat(T-17): kulüp listesi ve arama` (D-35). Q-17 dal akışına uy.
- Üretilen dosyalar commit edilmez; `--no-verify` yok; **`git push` yok** (kullanıcı isterse).
- Task büyükse mantıklı bölünmüş birden çok commit olabilir (hepsi aynı task ID'siyle; her biri kapıdan geçer).

## 7. Kullanıcıya rapor (Türkçe, ≤ 8 satır)

1. Ne yapıldı (ekran/sheet/dialog/toast sayısı, ana parçalar).
2. Kapı sonucu (analiz, test sayısı, matris, golden).
3. İnceleme ajanı bulguları ve ne yapıldı.
4. Açılan / kapanan bağlama borçları, kalan toplam borç.
5. Yeni K-xx / karar var mı.
6. **Bir sonraki task:** T-yy — başlığı. (Kullanıcıdan "devam" beklemeden sıradaki task'ın **plan moduna** gir; plan onayı doğal durma noktasıdır.)

## Hata ve tıkanma

- Kapı kırmızı ve 3 denemede çözülmedi → `node tool/progress.js block T-xx --note "…"`, kullanıcıya sebep + seçenekler (`AskUserQuestion`).
- Ortam sorunu (paket çözülmüyor, emülatör kalkmıyor) → belirt, geçici çözüm uydurma; kullanıcıya sor.
- Kapsam dışı iş çıktı → **yapma**; `docs/PLAN.md` "Açık noktalar"a ve ilgili task'a not ekle, kullanıcıya bildir.
