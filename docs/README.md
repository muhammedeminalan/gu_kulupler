# Paket Haritası ve Okuma Sırası — GÜ Kulüpler Claude Code Paketi

> Bu paket, **Claude Design çıktısını** (51 ekran · 34 sheet · 32 dialog · 78 toast · 1 menü · 1072 aksiyon) Flutter + Firebase uygulamasına **sapmadan** çeviren Claude Code'un tek girdisidir. Zip, **Flutter projesinin köküne** açılır. Bu dosya: "neyin nerede olduğu" ve "hangi sırayla okunacağı".

## 1. Kullanıcı için — 5 adımda başlangıç

| # | Ne yap | Not |
|---|---|---|
| 1 | Zip'i Flutter proje kökünde aç (`gu-claude-pack.zip`) | macOS Finder'da `.claude/` **gizli** klasördür (⌘ + ⇧ + .). Terminalden: `unzip -o gu-claude-pack.zip` — mevcut `pubspec.yaml`/`analysis_options.yaml` pakette **yok**; ezilmez, T-00'da Claude Code uzlaştırır |
| 2 | `claude` aç, ilk mesaj: **`CLAUDE.md ve prompts/00-baslat.md dosyalarını oku ve uygula.`** | `CLAUDE.md` otomatik yüklenir; `prompts/00-baslat.md` ilk oturum protokolüdür |
| 3 | **5 tur açılır pencere** sorusunu yanıtla (20 soru) | Her tur 4 soru; ilk seçenek *(Önerilen)*. Kararlar `docs/decisions.md §B`'ye kilitlenir |
| 4 | `docs/PLAN.md`'yi oku, onayla (ya da değiştirt) | Onay: `node tool/progress.js gate plan` (Claude Code çalıştırır) |
| 5 | Sonra Claude Code kendi ilerler: **T-00** → Faz 1 analiz onayı → **T-01 … T-47** | Her task: plan → onay → uygulama → test → kapı → commit |

Kendi terminalinden **sen** çalıştıracağın tek şey: süper admin claim betiği (`tool/admin/README.md`, T-37'de). `git push`, `firebase deploy` ve gerçek projeye yazma **açık onayın olmadan** yapılmaz (`.claude/settings.json` bunları `ask`/`deny` yapar).

## 2. Claude Code için okuma sırası

Oturum başında `CLAUDE.md` yüklenir. Hook (`SessionStart`) `node tool/progress.js brief` ile durumu yazar.

| Sıra | Dosya | Ne zaman |
|---|---|---|
| 1 | [`CLAUDE.md`](../CLAUDE.md) | her oturum |
| 2 | `docs/README.md` (bu dosya) | ilk oturum |
| 3 | [`docs/decisions.md`](decisions.md) | ilk oturum + çelişkide. Kilitli D-xx / cevaplanmış Q-xx **değiştirilmez** |
| 4 | [`docs/architecture.md`](architecture.md) | ilk oturum; katman/DI/bildirim (§7) |
| 5 | [`docs/domain-model.md`](domain-model.md) | veri katmanı task'ları (T-08…) |
| 6 | [`docs/firestore-rules-spec.md`](firestore-rules-spec.md) | Rules / indeks / repository |
| 7 | [`docs/soft-delete.md`](soft-delete.md) | **her silme** — hard delete yok |
| 8 | [`docs/packages.md`](packages.md) | T-00, paket eklerken |
| 9 | [`docs/navigation.md`](navigation.md) | rota / geçiş / geri davranışı |
| 10 | [`docs/design-contract.md`](design-contract.md) | her ekran/sheet/dialog/toast |
| 11 | [`docs/design-known-issues.md`](design-known-issues.md) | tasarım dışa aktarımının bilinen kusurları (K-xx) |
| 12 | [`docs/testing.md`](testing.md) | test yazarken ve kapıda |
| 13 | [`docs/roadmap.md`](roadmap.md) + [`docs/task-map.json`](task-map.json) | task seçerken |
| 14 | [`docs/progress.json`](progress.json) | **elle düzenleme**; yalnızca `node tool/progress.js …` |

Kaynak hiyerarşisi (çelişkide üstteki kazanır): kullanıcının son talimatı → `docs/decisions.md` → `CLAUDE.md` → tasarım dışa aktarımı (görünüm/davranış) → brief (`design/prototype/claude-design-prompt.md`, iş kuralları) → diğer `docs/*` → `reference/*`. Çelişkiyi **sessizce çözme** — `AskUserQuestion` (bkz. `.claude/skills/gu-ask-user/SKILL.md`).

## 3. Yaşam döngüsü

```
prompts/00-baslat.md      keşif → 5 tur soru (20) → docs/decisions.md → docs/PLAN.md → DUR (Kapı 0: onay)
prompts/02-faz0-kurulum.md  T-00: depo kurulumu + kalite kapısı (pubspec, analysis_options, build.yaml, packages/*, tool/)
prompts/03-faz1-tasarim-analizi.md  Faz 1: docs/design-analysis.md + widget-catalog.md + token-map.md → DUR (Kapı 1: onay)
prompts/task-calistir.md  T-01 … T-47: plan modu → onay → uygulama → test → tool/quality_gate.sh → inceleme ajanları → commit → progress.js done
```

Durum makinesi: `node tool/progress.js next` sıradaki task'ı verir; `plan` → `start` → `review` → `done --commit <sha>`. `done`, **tam yeşil kapı kaydı** ve **kapıdan sonra kodun değişmemiş olması** ister (`--force` yalnızca kullanıcı bilerek geçiyorsa).

## 4. Dizin haritası

```
CLAUDE.md                     tek doğru kaynak: mimari, sert kurallar, kapılar
l10n.yaml                     gen-l10n ayarı (arb-dir lib/l10n · şablon app_tr.arb)
lib/l10n/app_tr.arb, app_en.arb   1235 anahtar (prototipe özgü 186 anahtar design/prototype-only-arb/'a ayrılır — T-00)
assets/                       fontlar, ikonlar (130 Lucide), çizimler (12), logo, desenler, kapaklar
prompts/                      00-baslat · 01-soru-bankasi · 02-faz0-kurulum · 03-faz1-tasarim-analizi · task-calistir
docs/                         sözleşmeler (aşağıda) + roadmap + progress; Claude Code'un yazdıkları: PLAN.md, design-analysis.md,
                              widget-catalog.md, token-map.md, plans/T-xx.md
design/                       Claude Design dışa aktarımı — SALT OKUNUR
  extracted/                  registry.json (kimlikler, token'lar, sabitler) · screens-actions.json (1072 aksiyon) ·
                              component-css.css · css-class-usage.json
  prototype/                  çalışan prototip kaynağı (app/*.js) + claude-design-prompt.md (iş kuralları brief'i)
  prototype-standalone/       tek dosyalık prototip + font/ikon/çizim/logo/desen/kapak kopyaları
  reference-shots/            ekran/sheet/dialog/toast/durum görüntüleri (açık+koyu, TR+EN) + index.json
  generated-reference/        üretilmiş renk/tipografi/tema referansı (K-11: yalnızca referans)
reference/                    konvansiyon örnek kodu (hatayi_yasat, life_shared) — SALT OKUNUR, birebir kopyalanmaz
.claude/
  settings.json               izin listeleri (ask/deny) + hook'lar (SessionStart, PostToolUse)
  skills/                     14 beceri: gu-kickoff · gu-task-runner · gu-ask-user · gu-decision-log · gu-design-analysis ·
                              gu-screen-from-design · gu-widget · gu-feature · gu-firebase-model · gu-soft-delete ·
                              gu-navigation · gu-l10n · gu-testing · gu-quality-gate
  agents/                     4 salt okunur denetçi: gu-architecture-reviewer · gu-design-fidelity-reviewer ·
                              gu-firebase-security-reviewer · gu-test-auditor
tool/                         kalite ve ilerleme araçları (aşağıda)
```

### `docs/` dosyaları

| Dosya | Rolü | Kim yazar |
|---|---|---|
| `decisions.md` | D-01…D-36 kilitli kararlar; Q-01…Q-20 soru cevapları (§B); K-xx cevapları | paket + Claude Code (yalnızca §B cevapları ve sapma kayıtları) |
| `architecture.md` | katmanlar, paket sınırları, DI, bootstrap, bildirim (Mod C/F) | paket |
| `domain-model.md` | koleksiyonlar, alanlar, durum makineleri, bildirim türleri | paket |
| `firestore-rules-spec.md` | Rules + indeks spesifikasyonu, geçiş makinesi M1–M14 | paket |
| `soft-delete.md` | soft delete sözleşmesi, `SoftDelete` API | paket |
| `packages.md` | paket listesi, sürüm politikası, koşullu paketler | paket |
| `navigation.md` | rota tablosu, geçişler, geri davranışı | paket |
| `design-contract.md` | tasarım 1:1 sözleşmesi, kimlik kapsamı, muaflar | paket |
| `design-known-issues.md` | K-01…K-23; yeni bulgular **K-24…** | paket + Claude Code |
| `testing.md` | test katmanları, cihaz matrisi, golden politikası, kapı | paket |
| `roadmap.md`, `task-map.json` | T-00…T-47, task→kimlik eşlemesi | paket (değişmez) |
| `progress.json` | durum, kapılar, bağlama borçları | `tool/progress.js` |
| `design-analysis.TEMPLATE.md` | Faz 1 şablonu (63 ön-doldurulmuş bileşen satırı, bölüm A–M) | paket |
| `reference/` | `pubspec/analysis_options/build.yaml` örnekleri (`.txt`) | paket |
| `PLAN.md` | nihai uygulama planı | **Claude Code** (Faz 0) |
| `design-analysis.md`, `widget-catalog.md`, `token-map.md` | Faz 1 çıktıları | **Claude Code** |
| `plans/T-xx.md` | her task'ın kalıcı planı | **Claude Code** |

### `tool/` betikleri

| Betik | Ne yapar | Ne zaman |
|---|---|---|
| `tool/verify_pack.sh` | paket bütünlüğü (dosyalar, sayılar, çapraz referanslar, `PACK_MANIFEST.json`) | ilk oturum; `bash tool/verify_pack.sh` |
| `tool/progress.js` | ilerleme / kapı / bağlama borcu (`next`, `plan`, `start`, `review`, `done`, `answer`, `gate`, `wiring`, `deviation`, `issue`) | sürekli |
| `tool/quality_gate.sh` | format → codegen → analyze → sınırlar → hardcode → hard-delete → ARB → tasarım → test → kapsam → Rules | her commit/task sonu; **uzun sürer: `timeout: 600000` ver** |
| `tool/codegen.sh` | `pub get` + `build_runner` + `gen-l10n` (`--watch`, `--clean`) | model/ViewModel/rota/ARB değişince |
| `tool/check_hardcode.sh` | renk/boyut/süre/metin hardcode taraması | hook + kapı |
| `tool/check_no_hard_delete.sh` | `.delete(…)`, Rules'ta `allow delete`/`allow write`, gerekçesiz `FieldValue.delete()` taraması | hook + kapı |
| `tool/check_boundaries.sh` | paket sınırları (`gu_ui ↛ gu_data`, Firebase SDK yalnızca `gu_data`, feature→feature import yasak) | hook + kapı |
| `tool/check_arb_parity.js` | ARB TR↔EN parite, ICU, lint (ARB01–ARB14), `--prune`, `--unused` | kapı; T-00 prune |
| `tool/check_design_coverage.js` | kimlik/aksiyon/katalog kapsamı (`--map`, `--task T-xx`, `--all`) | kapı |
| `tool/check_coverage.js` | test kapsamı eşikleri | tam kapı |
| `tool/hooks/post_edit.sh` | her dosya düzenlemesinde ilgili taramaları anında çalıştırır | otomatik (PostToolUse) |
| `tool/admin/` | süper admin claim betiği (`set_superadmin.js`) — **kullanıcı çalıştırır** | T-37 |
| `tool/seed/` | `demo-data.json` (donuk, kurgusal) + emülatör tohumlayıcı (T-10'da yazılır) | yalnızca emülatör |

## 5. Hangi iş için hangi dosya?

| İş | Oku |
|---|---|
| Ekran / sheet / dialog / toast uygulama | `design-contract.md` → `.claude/skills/gu-screen-from-design/SKILL.md` → ilgili `design/reference-shots/…` görüntüsü + `design/prototype/app/screens-*.js` + `design/extracted/screens-actions.json` |
| Ortak widget | `docs/widget-catalog.md` (önce tara) → `.claude/skills/gu-widget/SKILL.md` → `design/extracted/component-css.css` |
| Yeni feature dilimi | `architecture.md` → `.claude/skills/gu-feature/SKILL.md` → `reference/hatayi_yasat/` örnekleri |
| Model / repository / Rules | `domain-model.md` → `firestore-rules-spec.md` → `soft-delete.md` → `.claude/skills/gu-firebase-model/SKILL.md` → `reference/life_shared/` |
| Metin ekleme | `.claude/skills/gu-l10n/SKILL.md` (ARB; hardcode yasak) |
| Silme / geri alma | `soft-delete.md` + `.claude/skills/gu-soft-delete/SKILL.md` |
| Rota / geçiş | `navigation.md` + `.claude/skills/gu-navigation/SKILL.md` |
| Test | `testing.md` + `.claude/skills/gu-testing/SKILL.md` |
| Kapı kırmızı / hook uyardı | `.claude/skills/gu-quality-gate/SKILL.md` |
| Karar değişikliği, sapma, yeni tasarım kusuru | `.claude/skills/gu-decision-log/SKILL.md` |
| Task incelemesi | `.claude/agents/*` (salt okunur denetçiler; `gu-task-runner` çağırır) |

## 6. Sayılar (doğrulama için)

| Kalem | Değer | Kaynak |
|---|---|---|
| Ekran / sheet / dialog | 51 / 34 / 32 | `design/extracted/registry.json` |
| Toast | 78 (77 uygulanır + `TST-58` demo muaf) · ek: `EVT-MENU` menüsü | registry · `design-contract.md` |
| Aksiyon | 1072 (1060 uygulanan + 12 muaf demo) | `screens-actions.json` |
| ARB anahtarı | 1421 → 1235 (186 prototipe özgü ayrılır) | `lib/l10n/*.arb` · `tool/check_arb_parity.js` |
| Task | 48 (T-00…T-47), 8 faz (A–H); T-42 koşullu (Q-02) | `docs/roadmap.md` |
| Soru | 20 (Q-01…Q-20), 5 tur | `prompts/01-soru-bankasi.md` |
| Beceri / ajan | 14 / 4 | `.claude/` |

Sorun çıkarsa: `bash tool/verify_pack.sh` — eksik/bozuk dosyayı ve hangi dokümanın neye başvurduğunu söyler.
