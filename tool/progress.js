#!/usr/bin/env node
'use strict';
/**
 * İlerleme / kapı / bağlama borcu takibi — docs/progress.json (tek doğruluk kaynağı, git'te).
 *
 *   node tool/progress.js show [--json]                 durum özeti
 *   node tool/progress.js brief                          oturum başı kısa özet (hook; her zaman çıkış 0)
 *   node tool/progress.js next                           sıradaki task (+ uyarılar)
 *   node tool/progress.js plan T-xx                      plan moduna girerken: durum planning
 *   node tool/progress.js start T-xx                     plan onaylandıktan sonra: in_progress
 *   node tool/progress.js review T-xx                    inceleme aşaması
 *   node tool/progress.js done T-xx --commit <sha>[,<sha>] [--gate "özet"] [--note "…"]
 *   node tool/progress.js block T-xx --note "…"          tıkandı (3 denemede çözülmedi)
 *   node tool/progress.js unblock T-xx
 *   node tool/progress.js skip T-xx --note "gerekçe"     yalnızca koşullu task (T-42)
 *   node tool/progress.js answer Q-xx "<seçilen etiket>" soru cevabını kaydet (kilitler)
 *   node tool/progress.js gate plan|analysis [--revoke]  kullanıcı onay kapıları
 *   node tool/progress.js wiring list
 *   node tool/progress.js wiring add --declared-in T-xx --resolve-in T-yy[,T-zz] --text "…" [--keys "CLB-03.manage,…"]
 *   node tool/progress.js wiring open|close W-xx [--note "…"] [--force]
 *   node tool/progress.js deviation "metin" [--task T-xx]  sapma kaydı (kullanıcı onaylı)
 *   node tool/progress.js issue "K-23 …"                   yeni bilinen kusur kaydı
 *   node tool/progress.js record-gate --task T-xx --status pass|fail --mode full|fast   (quality_gate.sh çağırır)
 *   ek: --root <dir> · --json
 */
const fs = require('fs');
const path = require('path');
const cp = require('child_process');
const core = require('./lib/scan_core');
const data = require('./lib/pack_data');

const argv = process.argv.slice(2);
const root = core.projectRoot(argv);
const cmd = argv[0];

// ── argüman çözümleme ──────────────────────────────────────
const BOOL = new Set(['--json', '--revoke', '--force']);
function parseArgs(a) {
  const pos = [], flags = {};
  for (let i = 1; i < a.length; i++) {
    const t = a[i];
    if (t === '--root') { i++; continue; }
    if (t.startsWith('--')) {
      if (BOOL.has(t)) { flags[t.slice(2)] = true; continue; }
      const v = a[i + 1];
      if (v === undefined || v.startsWith('--')) { flags[t.slice(2)] = true; continue; }
      flags[t.slice(2)] = v; i++;
    } else pos.push(t);
  }
  return { pos, flags };
}
const { pos, flags } = parseArgs(argv);

const die = (msg, code) => { console.error('progress: ' + msg); process.exit(code || 1); };
const now = () => new Date().toISOString();
const today = () => now().slice(0, 10);

// brief hiçbir koşulda hata vermez
if (cmd === 'brief') { try { brief(); } catch (e) { /* sessiz */ } process.exit(0); }

let tm, pj;
try { tm = data.taskMap(root); pj = data.progress(root); } catch (e) { die(e.message, 2); }
const tasks = tm.tasks;
const idx = new Map(tasks.map((t, i) => [t.id, i]));
const T = (id) => tasks[idx.get(id)];
const st = (id) => (pj.tasks[id] && pj.tasks[id].status) || 'pending';
const isDone = (id) => ['done', 'skipped'].includes(st(id));
const save = () => data.writeProgress(root, pj);
const requireTask = () => {
  const id = pos[0];
  if (!id || !idx.has(id)) die(`geçerli bir task kimliği ver (T-00 … T-${String(tasks.length - 1).padStart(2, '0')})`);
  return id;
};
const answered = () => pj.questionsAnswered || {};
const openWiring = () => (pj.pendingWiring || []).filter((w) => w.status === 'open');

function nextTask() {
  for (const t of tasks) if (!isDone(t.id)) return t;
  return null;
}
function unmetDeps(id) { return (T(id).deps || []).filter((d) => !isDone(d)); }
function unansweredQuestions(id) { return (T(id).questions || []).filter((q) => !(q in answered())); }
function conditionalHint(t) {
  if (!t.conditional) return null;
  const q02 = answered()['Q-02'];
  const ok = q02 && /functions|blaze/i.test(q02.answer || '');
  return ok ? null : `${t.id} koşullu (${t.conditional}). Q-02 cevabı ${q02 ? `"${q02.answer}"` : 'yok'} → \`node tool/progress.js skip ${t.id} --note "Q-02 = Functions değil (Mod C)"\``;
}
function gateReason(id) {
  if (!pj.gate.planApproved) return 'docs/PLAN.md henüz onaylanmadı (gate.planApproved=false) — prompts/00-baslat.md';
  if (id !== 'T-00' && !isDone('T-00')) return 'T-00 bitmeden başka task başlayamaz';
  if (id !== 'T-00' && !pj.gate.designAnalysisApproved) return 'docs/design-analysis.md onayı yok (gate.designAnalysisApproved=false) — prompts/03-faz1-tasarim-analizi.md';
  return null;
}
const active = () => tasks.find((t) => ['planning', 'in_progress', 'review'].includes(st(t.id)));

function setStatus(id, status, extra) {
  const r = pj.tasks[id];
  r.status = status;
  if (extra) Object.assign(r, extra);
  if (['planning', 'in_progress', 'review'].includes(status)) pj.currentTask = id;
  else if (pj.currentTask === id) pj.currentTask = null;
}

function gitHas(sha) {
  try { cp.execFileSync('git', ['-C', root, 'rev-parse', '--verify', '--quiet', sha + '^{commit}'], { stdio: 'ignore' }); return true; }
  catch (e) { return e.code === 'ENOENT' ? null : false; }
}
function lastGate() {
  try { return JSON.parse(fs.readFileSync(path.join(root, 'tool/.cache/last_gate.json'), 'utf8')); } catch (e) { return null; }
}
/** Çalışma ağacının (docs/ ve tool/.cache hariç, .gitignore'a saygılı) içerik özeti; git yoksa null. */
function treeHash() {
  let idx = null;
  try {
    const git = (args, env) => cp.execFileSync('git', ['-C', root].concat(args), { env: Object.assign({}, process.env, env || {}), stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim();
    const gitDir = path.resolve(root, git(['rev-parse', '--git-dir']));
    idx = path.join(gitDir, 'gu-gate-index');
    try { fs.unlinkSync(idx); } catch (e) { /* yok */ }
    const env = { GIT_INDEX_FILE: idx };
    try { git(['rev-parse', '--verify', '--quiet', 'HEAD'], env); git(['read-tree', 'HEAD'], env); } catch (e) { /* ilk commit öncesi: boş indeks */ }
    git(['add', '-A', '--', '.'], env);
    git(['rm', '-r', '-q', '--cached', '--ignore-unmatch', '--', 'docs', 'tool/.cache'], env);
    return git(['write-tree'], env);
  } catch (e) { return null; }
  finally { if (idx) { try { fs.unlinkSync(idx); } catch (e) { /* yok */ } } }
}

// ── komutlar ───────────────────────────────────────────────
function show() {
  if (flags.json) { console.log(JSON.stringify(pj, null, 2)); return; }
  const count = (s) => tasks.filter((t) => st(t.id) === s).length;
  const qs = answered();
  console.log(`İLERLEME  (güncelleme: ${pj.updated || '—'})`);
  console.log(`Kapılar : plan onayı ${pj.gate.planApproved ? '✓' : '✗'} · tasarım analizi onayı ${pj.gate.designAnalysisApproved ? '✓' : '✗'}`);
  console.log(`Sorular : ${Object.keys(qs).length} cevaplandı`);
  console.log(`Task'lar: ${count('done')} done · ${count('skipped')} skipped · ${count('in_progress') + count('planning') + count('review')} aktif · ${count('blocked')} blocked · ${count('pending')} pending (toplam ${tasks.length})`);
  const phases = Object.keys(tm.phases);
  for (const p of phases) {
    const ts = tasks.filter((t) => t.phase === p);
    const d = ts.filter((t) => isDone(t.id)).length;
    console.log(`  Faz ${p} ${String(d).padStart(2)}/${ts.length}  ${tm.phases[p]}`);
  }
  const a = active();
  if (a) console.log(`Aktif   : ${a.id} — ${a.title} [${st(a.id)}]`);
  const n = nextTask();
  if (n && (!a || a.id !== n.id)) console.log(`Sıradaki: ${n.id} — ${n.title}`);
  if (!n) console.log('Sıradaki: yok — tüm task\'lar tamam');
  const ow = openWiring();
  console.log(`Bağlama borcu: ${ow.length} açık (T-43 başlangıcında 0 olmalı)`);
  if (pj.deviations && pj.deviations.length) console.log(`Sapma kaydı: ${pj.deviations.length}`);
  if (pj.knownIssuesAdded && pj.knownIssuesAdded.length) console.log(`Eklenen kusur: ${pj.knownIssuesAdded.length}`);
}

function brief() {
  const tmx = data.taskMap(root), pjx = data.progress(root);
  const ts = tmx.tasks;
  const stx = (id) => (pjx.tasks[id] && pjx.tasks[id].status) || 'pending';
  const done = ts.filter((t) => ['done', 'skipped'].includes(stx(t.id))).length;
  const act = ts.find((t) => ['planning', 'in_progress', 'review'].includes(stx(t.id)));
  const nxt = ts.find((t) => !['done', 'skipped'].includes(stx(t.id)));
  const blocked = ts.filter((t) => stx(t.id) === 'blocked').map((t) => t.id);
  const ow = (pjx.pendingWiring || []).filter((w) => w.status === 'open').length;
  const L = [];
  L.push(`[GÜ Kulüpler] ilerleme: ${done}/${ts.length} task · plan onayı ${pjx.gate.planApproved ? 'var' : 'YOK'} · tasarım analizi onayı ${pjx.gate.designAnalysisApproved ? 'var' : 'YOK'} · açık bağlama borcu ${ow}`);
  if (act) L.push(`Aktif task: ${act.id} — ${act.title} [${stx(act.id)}]. Kaldığın yerden devam et (docs/plans/${act.id}.md).`);
  else if (nxt) L.push(`Sıradaki task: ${nxt.id} — ${nxt.title}.`);
  if (blocked.length) L.push(`TIKALI task: ${blocked.join(', ')} — kullanıcıya sor.`);
  if (!pjx.gate.planApproved) L.push('Sonraki adım: prompts/00-baslat.md (soru turları → docs/PLAN.md → onay).');
  else if (!ts.length || !['done'].includes(stx('T-00'))) L.push('Sonraki adım: prompts/02-faz0-kurulum.md (T-00).');
  else if (!pjx.gate.designAnalysisApproved) L.push('Sonraki adım: prompts/03-faz1-tasarim-analizi.md (docs/design-analysis.md → kullanıcı onayı).');
  else L.push('Task döngüsü: prompts/task-calistir.md · kurallar: CLAUDE.md · kapı: bash tool/quality_gate.sh --task T-xx');
  console.log(L.join('\n'));
}

function next() {
  const a = active();
  if (a) { console.log(`Aktif task var: ${a.id} — ${a.title} [${st(a.id)}]`); }
  const bl = tasks.filter((t) => st(t.id) === 'blocked');
  if (bl.length) console.log(`UYARI: tıkalı task: ${bl.map((t) => t.id).join(', ')} — önce kullanıcıyla çöz.`);
  const n = nextTask();
  if (!n) { console.log('Tüm task\'lar tamam.'); return; }
  console.log(`${n.id} — ${n.title}  (Faz ${n.phase})`);
  console.log(n.goal);
  const miss = unmetDeps(n.id);
  if (miss.length) console.log(`UYARI: bağımlılıklar bitmemiş: ${miss.join(', ')}`);
  const g = gateReason(n.id);
  if (g) console.log(`KAPI: ${g}`);
  const h = conditionalHint(n);
  if (h) console.log(`KOŞUL: ${h}`);
  const uq = unansweredQuestions(n.id);
  if (uq.length) console.log(`SORU: cevaplanmamış ön koşul: ${uq.join(', ')} — plan modundan önce AskUserQuestion`);
  const closes = openWiring().filter((w) => (w.resolveIn || []).includes(n.id));
  if (closes.length) console.log(`Kapatacağı bağlama borçları: ${closes.map((w) => w.id).join(', ')}`);
}

function plan() {
  const id = requireTask();
  const g = gateReason(id); if (g) die(g);
  const a = active(); if (a && a.id !== id) die(`aktif task var: ${a.id} [${st(a.id)}] — önce onu bitir/tıka`);
  if (st(id) === 'done' || st(id) === 'skipped') die(`${id} zaten ${st(id)}`);
  const n = nextTask();
  if (n && n.id !== id) die(`sıra dışı: sıradaki task ${n.id}; ${id} başlatılamaz (D-32). Sıra değişikliği için kullanıcıya sor`);
  const miss = unmetDeps(id); if (miss.length) die(`bağımlılıklar bitmemiş: ${miss.join(', ')}`);
  const uq = unansweredQuestions(id); if (uq.length) die(`cevaplanmamış ön koşul sorusu: ${uq.join(', ')} — AskUserQuestion ile sor, sonra \`answer\``);
  const h = conditionalHint(T(id)); if (h) die(h);
  setStatus(id, 'planning');
  save();
  console.log(`${id} planlama aşamasında. Planı docs/plans/${id}.md dosyasına yaz.`);
}

function start() {
  const id = requireTask();
  if (st(id) !== 'planning' && st(id) !== 'pending' && st(id) !== 'blocked') die(`${id} durumu ${st(id)}; start yalnızca planning/pending/blocked'tan`);
  if (st(id) === 'pending') { plan(); }
  const r = pj.tasks[id];
  if (!fs.existsSync(path.join(root, 'docs/plans', id + '.md'))) die(`docs/plans/${id}.md yok — önce planı yaz ve kullanıcıya onaylat`);
  setStatus(id, 'in_progress', { startedAt: r.startedAt || now() });
  save();
  console.log(`${id} başladı (in_progress).`);
}

function review() {
  const id = requireTask();
  if (st(id) !== 'in_progress') die(`${id} durumu ${st(id)}; review yalnızca in_progress'ten`);
  setStatus(id, 'review'); save(); console.log(`${id} inceleme aşamasında.`);
}

function done() {
  const id = requireTask();
  if (!['in_progress', 'review'].includes(st(id))) die(`${id} durumu ${st(id)}; done yalnızca in_progress/review'dan`);
  const commit = flags.commit;
  if (!commit || commit === true) die('--commit <sha> zorunlu (commit yoksa task bitmez)');
  const shas = String(commit).split(',').map((s) => s.trim()).filter(Boolean);
  for (const s of shas) {
    const ok = gitHas(s);
    if (ok === false) die(`commit bulunamadı: ${s}`);
    if (ok === null) console.error('uyarı: git bulunamadı; sha doğrulanamadı');
  }
  // bu task'ta kapanması gereken borçlar
  const ti = idx.get(id);
  const stale = openWiring().filter((w) => (w.resolveIn || []).length && Math.max(...w.resolveIn.map((r) => idx.get(r))) <= ti);
  if (stale.length) die(`kapanması gereken açık bağlama borcu: ${stale.map((w) => w.id).join(', ')} → \`wiring close\` (ya da kullanıcı onaylı sapma: \`deviation\`)`);
  // kalite kapısı kaydı
  if (!flags.force) {
    const g = lastGate();
    if (!g || g.task !== id || g.status !== 'pass' || g.mode !== 'full') die(`${id} için TAM yeşil kalite kapısı kaydı yok (tool/.cache/last_gate.json). \`bash tool/quality_gate.sh --task ${id}\` çalıştır.`);
    const started = pj.tasks[id].startedAt;
    if (started && g.at < started) die('kalite kapısı kaydı task başlangıcından eski');
    const th = treeHash();
    if (th && g.tree && th !== g.tree) die('kod, kalite kapısından SONRA değişti (docs/ hariç). Tam kapıyı yeniden çalıştır: bash tool/quality_gate.sh --task ' + id);
  }
  const r = pj.tasks[id];
  const commits = new Set(r.commits || []); shas.forEach((s) => commits.add(s));
  const note = typeof flags.note === 'string' ? flags.note : r.notes;
  setStatus(id, 'done', { finishedAt: now(), commits: [...commits], gate: typeof flags.gate === 'string' ? flags.gate : 'yeşil', notes: note || '' });
  save();
  const n = nextTask();
  console.log(`${id} tamam (${shas.join(', ')}). ${n ? `Sıradaki: ${n.id} — ${n.title}` : 'Tüm task\'lar tamam.'}`);
}

function block() {
  const id = requireTask();
  if (typeof flags.note !== 'string') die('--note "<sebep>" zorunlu');
  setStatus(id, 'blocked', { notes: ((pj.tasks[id].notes ? pj.tasks[id].notes + ' | ' : '') + flags.note) });
  save(); console.log(`${id} tıkandı. Kullanıcıya sebep + seçenekleri sun (AskUserQuestion).`);
}
function unblock() {
  const id = requireTask();
  if (st(id) !== 'blocked') die(`${id} tıkalı değil`);
  setStatus(id, pj.tasks[id].startedAt ? 'in_progress' : 'planning'); save(); console.log(`${id} yeniden aktif.`);
}

function skip() {
  const id = requireTask();
  const t = T(id);
  if (!t.conditional) die(`${id} koşullu değil; atlanamaz (D-32)`);
  if (typeof flags.note !== 'string') die('--note "<gerekçe>" zorunlu');
  const q02 = answered()['Q-02'];
  if (t.id === 'T-42' && q02 && /functions|blaze/i.test(q02.answer || '') && !flags.force) die('Q-02 = Functions (Blaze) → T-42 yapılmalı; atlamak için kullanıcı onayı + --force');
  setStatus(id, 'skipped', { finishedAt: now(), notes: flags.note });
  save(); console.log(`${id} atlandı: ${flags.note}`);
}

function answer() {
  const id = pos[0], text = pos.slice(1).join(' ');
  if (!id || !/^[A-Z]-[A-Za-z0-9]+$/.test(id)) die('kullanım: answer <Q-xx|K-x> "<seçim>"');
  if (!text) die('cevap metni boş');
  if (!pj.questionsAnswered || Array.isArray(pj.questionsAnswered)) pj.questionsAnswered = {};
  const prev = pj.questionsAnswered[id];
  if (prev && !flags.force) die(`${id} zaten cevaplanmış ("${prev.answer}") ve kilitli; değiştirmek kullanıcı onaylı sapmadır (--force + deviation)`);
  pj.questionsAnswered[id] = { answer: text, answeredAt: now() };
  save(); console.log(`${id} kaydedildi: ${text}`);
}

function gate() {
  const which = pos[0];
  const key = which === 'plan' ? 'planApproved' : which === 'analysis' ? 'designAnalysisApproved' : null;
  if (!key) die('kullanım: gate plan|analysis [--revoke]');
  if (!flags.revoke) {
    if (key === 'planApproved' && !fs.existsSync(path.join(root, 'docs/PLAN.md'))) die('docs/PLAN.md yok');
    if (key === 'designAnalysisApproved') {
      if (!pj.gate.planApproved) die('plan onayı yok');
      if (!isDone('T-00')) die('T-00 bitmeden tasarım analizi onaylanamaz');
      if (!fs.existsSync(path.join(root, 'docs/design-analysis.md'))) die('docs/design-analysis.md yok');
      if (!flags.force) {
        const bad = [];
        for (const f of ['docs/widget-catalog.md', 'docs/token-map.md']) if (!fs.existsSync(path.join(root, f))) bad.push(`${f} yok`);
        const txt = fs.readFileSync(path.join(root, 'docs/design-analysis.md'), 'utf8');
        const open = txt.split('\n').reduce((n, l, i) => (l.includes('⟂') && !/^\s*>/.test(l) ? (n.push(i + 1), n) : n), []);
        if (open.length) bad.push(`docs/design-analysis.md içinde doldurulmamış ⟂ hücre var (satır: ${open.slice(0, 8).join(', ')}${open.length > 8 ? ', …' : ''}; toplam ${open.length})`);
        for (const h of ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K']) if (!new RegExp(`^##\\s+${h}[.)\\s]`, 'm').test(txt)) bad.push(`docs/design-analysis.md: "## ${h}." bölümü yok`);
        if (bad.length) die(`analiz eksik, onay verilemez:\n  - ${bad.join('\n  - ')}\n(Kullanıcı bilerek geçiyorsa: --force)`);
      }
    }
  }
  pj.gate[key] = !flags.revoke;
  save(); console.log(`gate.${key} = ${pj.gate[key]}`);
}

function wiring() {
  const sub = pos[0];
  const list = pj.pendingWiring = pj.pendingWiring || [];
  if (sub === 'list' || !sub) {
    for (const w of list) console.log(`${w.id}\t${w.status}\t${w.declaredIn} → ${(w.resolveIn || []).join(',')}\t${w.text}${w.actions && w.actions.length ? `  [anahtar: ${w.actions.join(', ')}]` : ''}`);
    console.log(`\n${openWiring().length} açık / ${list.length} toplam`);
    return;
  }
  if (sub === 'add') {
    const di = flags['declared-in'], ri = flags['resolve-in'], text = flags.text;
    if (typeof di !== 'string' || !idx.has(di)) die('--declared-in T-xx zorunlu');
    if (typeof ri !== 'string') die('--resolve-in T-yy[,T-zz] zorunlu');
    const res = ri.split(',').map((s) => s.trim());
    for (const r of res) { if (!idx.has(r)) die(`geçersiz task: ${r}`); if (idx.get(r) <= idx.get(di)) die(`${r}, ${di} sonrasında olmalı`); }
    if (typeof text !== 'string' || text.length < 8) die('--text "<ne bağlanacak>" zorunlu');
    const max = Math.max(0, ...list.map((w) => parseInt(String(w.id).slice(2), 10) || 0));
    const id = 'W-' + String(max + 1).padStart(2, '0');
    const w = { id, declaredIn: di, text, resolveIn: res, status: 'open' };
    if (typeof flags.keys === 'string') w.actions = flags.keys.split(',').map((s) => s.trim()).filter(Boolean);
    list.push(w); save(); console.log(`${id} açıldı: ${text}`);
    return;
  }
  if (sub === 'open' || sub === 'close') {
    const w = list.find((x) => x.id === pos[1]);
    if (!w) die(`bilinmeyen borç: ${pos[1]}`);
    if (sub === 'close') {
      if (w.status === 'closed') die(`${w.id} zaten kapalı`);
      const cur = pj.currentTask;
      if (!flags.force && !(cur && (w.resolveIn || []).includes(cur))) die(`${w.id} yalnızca ${(w.resolveIn || []).join('/')} içinde kapatılır (aktif: ${cur || 'yok'})`);
      w.status = 'closed'; w.closedIn = cur || null; w.closedAt = now();
      if (typeof flags.note === 'string') w.closeNote = flags.note;
    } else {
      w.status = 'open'; delete w.closedIn; delete w.closedAt;
    }
    save(); console.log(`${w.id} → ${w.status}`);
    return;
  }
  die('kullanım: wiring list | add … | open W-xx | close W-xx');
}

function addLog(key, entry) {
  pj[key] = pj[key] || [];
  pj[key].push(entry); save();
}

function recordGate() {
  const t = flags.task, s = flags.status, m = flags.mode;
  if (!t || !s || !m) die('kullanım: record-gate --task T-xx --status pass|fail --mode full|fast');
  const dir = path.join(root, 'tool/.cache');
  fs.mkdirSync(dir, { recursive: true });
  const tree = treeHash();
  const file = path.join(dir, 'last_gate.json');
  const prev = lastGate();
  // aynı kodda geçmiş TAM yeşil kaydı, sonraki fast/static koşusu ezmesin
  if (prev && prev.status === 'pass' && prev.mode === 'full' && prev.task === t && m !== 'full' && tree && prev.tree === tree) return;
  fs.writeFileSync(file, JSON.stringify({ task: t, status: s, mode: m, at: now(), tree }, null, 1) + '\n');
}

switch (cmd) {
  case 'show': show(); break;
  case 'next': next(); break;
  case 'plan': plan(); break;
  case 'start': start(); break;
  case 'review': review(); break;
  case 'done': done(); break;
  case 'block': block(); break;
  case 'unblock': unblock(); break;
  case 'skip': skip(); break;
  case 'answer': answer(); break;
  case 'gate': gate(); break;
  case 'wiring': wiring(); break;
  case 'deviation': if (!pos[0]) die('kullanım: deviation "metin" [--task T-xx]'); addLog('deviations', { date: today(), task: flags.task || pj.currentTask || null, text: pos.join(' ') }); console.log('sapma kaydedildi'); break;
  case 'issue': if (!pos[0]) die('kullanım: issue "K-23 …"'); addLog('knownIssuesAdded', { date: today(), task: flags.task || pj.currentTask || null, text: pos.join(' ') }); console.log('kusur kaydedildi'); break;
  case 'record-gate': recordGate(); break;
  default:
    die('komut: show | brief | next | plan | start | review | done | block | unblock | skip | answer | gate | wiring | deviation | issue | record-gate', 2);
}
