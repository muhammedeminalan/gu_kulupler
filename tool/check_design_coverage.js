#!/usr/bin/env node
'use strict';
/**
 * Tasarım kapsamı denetimi (D-17…D-22, docs/design-contract.md L2/L3).
 *
 *   node tool/check_design_coverage.js --map                # paket tutarlılığı: registry ↔ task-map ↔ progress (kod taranmaz)
 *   node tool/check_design_coverage.js --task T-12 --list   # task kapsamını yazdır (hata vermez)
 *   node tool/check_design_coverage.js --task T-12 [--actions]
 *   node tool/check_design_coverage.js                      # biten (done/review) task'ların kapsamı
 *   node tool/check_design_coverage.js --wiring             # açık bağlama borçları (açık varsa çıkış 1)
 *   node tool/check_design_coverage.js --all                # nihai: her şey + aksiyonlar + borç 0 + katalog + yer tutucu 0
 *   ek: --root <dir> · --json · --strict (uyarılar da hata)
 *
 * Kontroller (kapsamdaki her kimlik için):
 *   iz      Ekran/sheet/dialog/menü: `/// Design: <ID>` sınıf izi (lib/ veya packages/<paket>/lib; katalog dosyaları hariç)
 *           Toast: ToastId enum üyesinin üstünde `/// Design: TST-nn`
 *   katalog (T-07 / --all) KAT01–KAT04: ToastId · SheetId · DialogId · MenuId (CD-113; registry.json#menus) enum üyeleri ↔ registry
 *           Katalog dosyaları = kimlik enum'ları + lib/product/feedback/catalogs/{toasts,dialogs}/ (ToastSpec/DialogSpec kayıtları):
 *           buradaki `/// Design:` satırı sınıf izi, `ToastId.tstNN` / `DialogId.dlgNN` satırı kullanım sayılmaz
 *   test    test/ · packages/<paket>/test · integration_test altında kimliği (ya da ToastId.tstNN) anan bir test
 *   kullanım toast: `ToastId.tstNN` katalog dışında kullanılıyor (hata) · sheet/dialog: `SheetId.shtNN`/`DialogId.dlgNN` (uyarı; --all'da hata)
 *   aksiyon  (--actions / --all) GuKey.action('…') kümesi == screens-actions.json (muaflar hariç, `${…}` → `*`)
 *            AKS01 eksik · AKS02 fazla · AKS03 muaf (demo) uygulanmış · AKS04 borçla ertelendi · AKS05 biçim · AKS06 bilinmeyen önek
 * Kalıp dosyaları (pack_data.patternFile; satır başına kalıp, `*` joker, `#` sonrası gerekçe):
 *   tool/design_exempt_actions.txt   uygulanmayan (demo/mock) aksiyonlar — beklenmez; kodda bulunursa AKS03 (CD-122(4), K-02)
 *   tool/design_dynamic_actions.txt  envanterde olmayan koşullu/dinamik anahtarlar — kalıba uyan bulunmuş anahtar AKS02
 *                                    sayılmaz; AKS01 değişmez (CD-86)
 * Kabuk anahtarları `NAV.*` (K-17, CD-53, PLAN §19.10): yalnızca registry.tabRoot ekranlarında beklenir; bu ekranlarda
 *   bulunan küme = `<ID>.*` ∪ `NAV.*`. Sekme kökü olmayan ekranda `NAV.*` beklenmez ve o ekran için AKS02 üretmez;
 *   hiçbir sekme kökü envanterinde karşılığı olmayan `NAV.*` anahtarı ayrıca AKS02'dir.
 * Bağlama borcu (progress.json#pendingWiring): açık borç kaydındaki `actions` kalıpları eksik anahtarı aklar.
 */
const fs = require('fs');
const path = require('path');
const core = require('./lib/scan_core');
const data = require('./lib/pack_data');

const argv = process.argv.slice(2);
const root = core.projectRoot(argv);
const has = (f) => argv.includes(f);
const val = (f) => { const i = argv.indexOf(f); return i >= 0 && argv[i + 1] && !argv[i + 1].startsWith('--') ? argv[i + 1] : null; };

// Uygulanmayan (demo/mock) aksiyonlar — docs/design-contract.md §2; tek kaynak dosya (CD-122(4)). Değiştirmek kullanıcıya sorulur.
const EXEMPT_FILE = 'tool/design_exempt_actions.txt';
// Envanterde olmayan koşullu/dinamik anahtarlar (CD-86) — ekran task'ları kendi satırlarını ekler.
const DYNAMIC_FILE = 'tool/design_dynamic_actions.txt';
const EXEMPT_RES = data.patternFile(root, EXEMPT_FILE);
const DYNAMIC_RES = data.patternFile(root, DYNAMIC_FILE);
const isExempt = (key) => EXEMPT_RES.some((e) => e.re.test(key));
const isDynamic = (key) => DYNAMIC_RES.some((e) => e.re.test(key));
// Kabuk (alt sekme çubuğu) anahtarları — K-17, CD-53
const NAV_PREFIX = 'NAV';
const isNav = (key) => key.startsWith(NAV_PREFIX + '.');

const ID_RE = /\b(?:SYS|ONB|AUT|CLB|FED|EVT|NTF|PRF|SET|MGT|ADM)-\d{2}\b|\bEVT-MENU\b|\b(?:SHT|DLG)-\d{2}\b|\bTST-X?\d{1,2}\b/g;
const SCREEN_RE = /^(SYS|ONB|AUT|CLB|FED|EVT|NTF|PRF|SET|MGT|ADM)-\d{2}$/;
// Kimlik enum'ları (KAT01–KAT04) ve üye adı kalıbı: tst05 · shtX1 · dlg07 · evtMenu (pack_data.enumMember).
const ENUM_NAMES = 'ToastId|SheetId|DialogId|MenuId';
const MEMBER_NAME = '(?:tst|sht|dlg)[0-9X]\\w*|[a-z]{3}Menu';
// ToastSpec / DialogSpec kayıt dosyaları: kimlik enum'ları gibi katalogdur (iz ve kullanım kanıtı sayılmaz).
const CATALOG_DIR_RE = /^lib\/product\/feedback\/catalogs\/(?:toasts|dialogs)\//;

const errors = [];
const warns = [];
const err = (rule, id, msg) => errors.push({ rule, id, msg });
const warn = (rule, id, msg) => warns.push({ rule, id, msg });
const fatal = (msg) => { console.error('check_design_coverage: ' + msg); process.exit(2); };

let reg, inv, tm, pj;
try {
  reg = data.registry(root); inv = data.inventory(root); tm = data.taskMap(root);
  pj = data.readJson(root, 'docs/progress.json', true);
} catch (e) { fatal(e.message); }

const tasks = tm.tasks;
const taskIdx = new Map(tasks.map((t, i) => [t.id, i]));
const owner = new Map(); // ID → task id
for (const grp of Object.keys(tm.owners)) for (const [id, t] of Object.entries(tm.owners[grp])) owner.set(id, t);
const regIds = {
  screen: reg.screens.map((s) => s.id),
  sheet: reg.sheets.map((s) => s.id),
  dialog: reg.dialogs.map((s) => s.id),
  toast: reg.toasts.map((s) => s.id),
  menu: (reg.menus || []).filter((m) => !/^SHT-/.test(m)),
};
const excluded = new Set(Object.keys((tm.excluded && tm.excluded.toasts) || {}));
const titleOf = (id) => {
  const k = data.kindOfId(id);
  const list = k === 'screen' ? reg.screens : k === 'sheet' ? reg.sheets : k === 'dialog' ? reg.dialogs : k === 'toast' ? reg.toasts : [];
  const r = list.find((x) => x.id === id);
  return r ? (r.titleTr || r.textTr || '') : '';
};

// ── --map ───────────────────────────────────────────────────
function checkMap() {
  // 1) her kimlik tam bir task'ta
  const seen = new Map();
  for (const t of tasks) {
    for (const grp of ['screens', 'sheets', 'dialogs', 'toasts', 'menus']) {
      for (const id of t[grp] || []) {
        if (seen.has(id)) err('MAP01', id, `iki task'ta: ${seen.get(id)} ve ${t.id}`);
        seen.set(id, t.id);
        if (owner.get(id) !== t.id) err('MAP02', id, `owners=${owner.get(id)} ama ${t.id} listesinde`);
      }
    }
  }
  for (const k of Object.keys(regIds)) {
    for (const id of regIds[k]) {
      if (excluded.has(id)) { if (seen.has(id)) err('MAP03', id, 'muaf kimlik bir task\'a atanmış'); continue; }
      if (!seen.has(id)) err('MAP04', id, `registry'de var, hiçbir task'a atanmamış`);
    }
  }
  const regAll = new Set([].concat(...Object.values(regIds)));
  for (const id of seen.keys()) if (!regAll.has(id)) err('MAP05', id, `task-map'te var, registry'de yok`);
  // 2) toplamlar
  const tot = tm.totals;
  const count = (g) => tasks.reduce((a, t) => a + (t[g] || []).length, 0);
  if (count('screens') !== reg.screens.length) err('MAP06', '-', `ekran ${count('screens')} ≠ ${reg.screens.length}`);
  if (count('sheets') !== reg.sheets.length) err('MAP06', '-', `sheet ${count('sheets')} ≠ ${reg.sheets.length}`);
  if (count('dialogs') !== reg.dialogs.length) err('MAP06', '-', `dialog ${count('dialogs')} ≠ ${reg.dialogs.length}`);
  if (count('toasts') !== reg.toasts.length - excluded.size) err('MAP06', '-', `toast ${count('toasts')} ≠ ${reg.toasts.length - excluded.size}`);
  // 3) bağımlılık sırası
  for (const t of tasks) for (const d of t.deps || []) {
    if (!taskIdx.has(d)) err('MAP07', t.id, `bilinmeyen bağımlılık ${d}`);
    else if (taskIdx.get(d) >= taskIdx.get(t.id)) err('MAP08', t.id, `bağımlılık ${d} kendisinden sonra`);
  }
  // 4) aksiyon toplamı
  let total = 0, exempt = 0;
  for (const s of reg.screens) {
    const e = inv[s.id];
    if (!e) { err('MAP09', s.id, 'screens-actions.json\'da yok'); continue; }
    total += e.actions.length;
    exempt += e.actions.filter(isExempt).length;
  }
  if (total !== tot.actions) err('MAP10', '-', `aksiyon toplamı ${total} ≠ task-map ${tot.actions}`);
  if (exempt !== tot.exemptActions) err('MAP11', '-', `muaf aksiyon ${exempt} ≠ task-map ${tot.exemptActions} (${EXEMPT_FILE} değişti mi?)`);
  // 5) progress.json
  if (pj) {
    for (const t of tasks) if (!pj.tasks || !pj.tasks[t.id]) err('MAP12', t.id, 'progress.json#tasks içinde yok');
    const wid = new Set();
    for (const w of pj.pendingWiring || []) {
      if (wid.has(w.id)) err('MAP13', w.id, 'yinelenen bağlama borcu kimliği');
      wid.add(w.id);
      if (!taskIdx.has(w.declaredIn)) err('MAP14', w.id, `declaredIn ${w.declaredIn} geçersiz`);
      for (const r of w.resolveIn || []) {
        if (!taskIdx.has(r)) err('MAP14', w.id, `resolveIn ${r} geçersiz`);
        else if (taskIdx.has(w.declaredIn) && taskIdx.get(r) <= taskIdx.get(w.declaredIn)) err('MAP15', w.id, `kapanış ${r}, bildirimden (${w.declaredIn}) sonra olmalı`);
      }
    }
  }
  return { total, exempt };
}

// ── kod taraması ────────────────────────────────────────────
const isLibDart = (rel) => /\.dart$/.test(rel) && /^(lib|packages\/[^/]+\/lib)\//.test(rel) && !/\.(g|gen|freezed)\.dart$/.test(rel) && !/app_localizations/.test(rel);
const isTestDart = (rel) => /\.dart$/.test(rel) && /^(test|integration_test|packages\/[^/]+\/test)\//.test(rel);

function scanCode() {
  const libFiles = core.walk(root, (f) => isLibDart(core.toPosix(path.relative(root, f))));
  const testFiles = core.walk(root, (f) => isTestDart(core.toPosix(path.relative(root, f))));
  const S = {
    traces: new Map(),        // ID → [{file,line}] (katalog dışı sınıf izleri)
    catalogTraces: new Map(), // ID → [{file,line}] (enum dosyalarındaki izler)
    members: { ToastId: new Map(), SheetId: new Map(), DialogId: new Map(), MenuId: new Map() }, // üye adı → {file,line,traceIds[]}
    enumFiles: new Set(),
    refs: new Map(),          // 'ToastId.tst05' → [{file,line}] (katalog dışı kullanım)
    keys: [],                 // {key,file,line}
    todos: [],                // TODO(T-xx)
    testText: '',             // tüm test metni (birleşik)
  };
  const enumRe = new RegExp(`\\benum\\s+(${ENUM_NAMES})\\b`);
  const memberRe = new RegExp(`^\\s*(${MEMBER_NAME})\\s*(?:[(,;]|$)`);
  for (const f of libFiles) {
    const rel = core.toPosix(path.relative(root, f));
    const text = fs.readFileSync(f, 'utf8');
    const rawLines = text.split(/\r?\n/);
    const isEnumFile = enumRe.test(text);
    if (isEnumFile) S.enumFiles.add(rel);
    const isCatalogFile = isEnumFile || CATALOG_DIR_RE.test(rel);
    // izler (ham satırlar)
    rawLines.forEach((ln, i) => {
      const m = /^\s*\/\/\/\s*Design:\s*(.+?)\s*$/.exec(ln);
      if (!m) return;
      const ids = m[1].match(ID_RE) || [];
      const bucket = isCatalogFile ? S.catalogTraces : S.traces;
      for (const id of ids) { if (!bucket.has(id)) bucket.set(id, []); bucket.get(id).push({ file: rel, line: i + 1 }); }
    });
    // TODO(T-xx)
    rawLines.forEach((ln, i) => { if (/\/\/.*TODO\(T-\d\d\)/.test(ln)) S.todos.push({ file: rel, line: i + 1, text: ln.trim() }); });
    // enum üyeleri
    if (isEnumFile) {
      let cur = null; let depth = 0;
      rawLines.forEach((ln, i) => {
        const em = enumRe.exec(ln);
        if (em && /\{/.test(ln)) { cur = em[1]; depth = 0; }
        if (!cur) return;
        const mm = memberRe.exec(ln);
        if (mm && depth <= 1) {
          const traceIds = [];
          for (let k = i - 1; k >= Math.max(0, i - 6); k--) {
            const tm2 = /^\s*\/\/\/\s*Design:\s*(.+?)\s*$/.exec(rawLines[k]);
            if (tm2) { traceIds.push(...(tm2[1].match(ID_RE) || [])); break; }
            if (!/^\s*(\/\/|@|$)/.test(rawLines[k])) break;
          }
          S.members[cur].set(mm[1], { file: rel, line: i + 1, traceIds });
        }
        depth += (ln.match(/\(/g) || []).length - (ln.match(/\)/g) || []).length;
        if (/^\}/.test(ln)) cur = null;
      });
    }
    // kod (yorumsuz) üzerinde: referanslar ve GuKey.action
    const lines = core.parse(text, {});
    const { text: code, offs } = core.joinCode(lines);
    if (!isCatalogFile) {
      const rr = new RegExp(`\\b(${ENUM_NAMES})\\s*\\.\\s*(${MEMBER_NAME})\\b`, 'g');
      let m;
      while ((m = rr.exec(code))) {
        const k = m[1] + '.' + m[2];
        if (!S.refs.has(k)) S.refs.set(k, []);
        S.refs.get(k).push({ file: rel, line: core.lineAt(offs, m.index) + 1 });
      }
    }
    const kr = /\bGuKey\s*\.\s*action\s*\(\s*"\u0001(\d+)\u0001"/g;
    let km;
    while ((km = kr.exec(code))) {
      const pos = km.index + km[0].indexOf('\u0001');
      const li = core.lineAt(offs, pos);
      const s = lines[li].strs[parseInt(km[1], 10)];
      if (s === undefined) continue;
      S.keys.push({ key: s.replace(/\$\{[^}]*\}/g, '*').replace(/\$[A-Za-z_]\w*/g, '*'), file: rel, line: li + 1 });
    }
  }
  const parts = [];
  for (const f of testFiles) parts.push(fs.readFileSync(f, 'utf8'));
  S.testText = parts.join('\n');
  S.counts = { lib: libFiles.length, test: testFiles.length };
  return S;
}

// ── kapsam ──────────────────────────────────────────────────
const statusOf = (id) => (pj && pj.tasks && pj.tasks[id] && pj.tasks[id].status) || 'pending';
function idsOfTasks(taskIds) {
  const out = [];
  for (const tid of taskIds) {
    const t = tasks[taskIdx.get(tid)];
    if (!t) continue;
    for (const grp of ['screens', 'sheets', 'dialogs', 'toasts', 'menus']) for (const id of t[grp] || []) out.push(id);
  }
  return out;
}

function evidence(S, id, testRe, wantUsage, strictUsage) {
  const kind = data.kindOfId(id);
  const mem = data.enumMember(id);
  const res = { id, kind, trace: false, test: false, usage: kind === 'screen' || kind === 'menu' ? null : false };
  if (kind === 'toast') {
    const m = S.members.ToastId.get(mem);
    res.trace = !!(m && m.traceIds.includes(id));
    if (m && !m.traceIds.includes(id)) err('IZ02', id, `${m.file}:${m.line} ${mem} üyesinin üstündeki \`/// Design:\` izi ${id} değil (${m.traceIds.join(',') || 'yok'})`);
  } else {
    res.trace = S.traces.has(id);
  }
  // test: kimlik ya da enum referansı
  const enumRef = kind === 'toast' ? `ToastId\\.${mem}\\b` : kind === 'sheet' ? `SheetId\\.${mem}\\b` : kind === 'dialog' ? `DialogId\\.${mem}\\b` : null;
  res.test = testRe.test(id) || (enumRef ? new RegExp(enumRef).test(S.testText) : false);
  if (kind === 'toast') res.usage = S.refs.has(`ToastId.${mem}`);
  else if (kind === 'sheet') res.usage = S.refs.has(`SheetId.${mem}`);
  else if (kind === 'dialog') res.usage = S.refs.has(`DialogId.${mem}`);
  return res;
}

function wiringWaivers() {
  const out = [];
  for (const w of (pj && pj.pendingWiring) || []) {
    if (w.status !== 'open') continue;
    for (const a of w.actions || []) out.push({ id: w.id, re: data.globToRe(a), pattern: a });
  }
  return out;
}

function checkIds(S, ids, mode) {
  const rows = [];
  const idRegex = (id) => new RegExp('(?<![\\w-])' + id.replace(/[-]/g, '\\-') + '(?![\\w])');
  for (const id of ids) {
    const rx = idRegex(id);
    const testRe = { test: (s) => rx.test(S.testText) };
    const ev = evidence(S, id, testRe);
    const own = owner.get(id);
    const t = own ? tasks[taskIdx.get(own)] : null;
    if (!ev.trace) err('IZ01', id, ev.kind === 'toast' ? `ToastId.${data.enumMember(id)} üyesi veya üstündeki \`/// Design: ${id}\` izi yok (sahip ${own})` : `\`/// Design: ${id}\` sınıf izi yok (sahip ${own})`);
    if (!ev.test) err('TEST01', id, `testlerde "${id}"${ev.kind === 'toast' || ev.kind === 'sheet' || ev.kind === 'dialog' ? ` ya da ${ev.kind === 'toast' ? 'ToastId' : ev.kind === 'sheet' ? 'SheetId' : 'DialogId'}.${data.enumMember(id)}` : ''} anılmıyor — grup/test adı kimliği taşımalı (D-19)`);
    if (ev.usage === false) {
      const m = `${ev.kind === 'toast' ? 'ToastId' : ev.kind === 'sheet' ? 'SheetId' : 'DialogId'}.${data.enumMember(id)} katalog dışında hiç kullanılmıyor (ölü ${ev.kind})`;
      if (ev.kind === 'toast' || mode === 'all') err('KUL01', id, m); else warn('KUL01', id, m + ' — çağıran giriş noktası bağlama borcuysa progress.js wiring ile kaydet');
    }
    rows.push({ ...ev, title: titleOf(id), owner: own, actions: t && ev.kind === 'screen' ? (inv[id] || {}).actionCount : null });
  }
  return rows;
}

function checkActions(S, screenIds, mode) {
  const waivers = wiringWaivers();
  const rows = [];
  const byPrefix = new Map();
  for (const k of S.keys) {
    const m = /^([A-Z]{2,4}-(?:X?\d{1,2}|MENU)|NAV)\./.exec(k.key);
    if (!m) { err('AKS05', k.key, `${k.file}:${k.line} anahtar biçimi geçersiz (\`<ID>.<aksiyon>\` olmalı)`); continue; }
    if (!byPrefix.has(m[1])) byPrefix.set(m[1], []);
    byPrefix.get(m[1]).push(k);
  }
  // bilinmeyen kimlik öneki (yazım hatası)
  const known = new Set([].concat(...Object.values(regIds)).concat([NAV_PREFIX]));
  for (const [pre, list] of byPrefix) {
    if (!known.has(pre)) for (const k of list) err('AKS06', k.key, `${k.file}:${k.line} bilinmeyen kimlik öneki "${pre}"`);
  }
  const tabRoots = new Set(Object.values(reg.tabRoot || {}));
  const navRes = (byPrefix.get(NAV_PREFIX) || []).map((k) => ({ ...k, re: data.globToRe(k.key) }));
  for (const sid of screenIds) {
    if (!SCREEN_RE.test(sid)) continue;
    const e = inv[sid];
    if (!e) continue;
    // K-17/CD-53: sekme kökünde bulunan küme = ekran önekli anahtarlar ∪ kabuktaki NAV.* anahtarları
    const isRoot = tabRoots.has(sid);
    const foundRes = (byPrefix.get(sid) || []).map((k) => ({ ...k, re: data.globToRe(k.key) })).concat(isRoot ? navRes : []);
    // sekme kökü olmayan ekranda NAV.* beklenmez
    const expected = e.actions.filter((a) => !isExempt(a) && (isRoot || !isNav(a)));
    const missing = [];
    for (const a of expected) {
      if (foundRes.some((f) => f.re.test(a))) continue;
      const w = mode === 'all' ? null : waivers.find((x) => x.re.test(a));
      if (w) { warn('AKS04', a, `bağlama borcu ${w.id} ile ertelendi (${w.pattern})`); continue; }
      missing.push(a);
    }
    for (const a of missing) err('AKS01', a, `eksik aksiyon anahtarı — \`GuKey.action('${a}')\` (${sid})`);
    const extra = [];
    let dynamic = 0;
    for (const f of foundRes) {
      if (isNav(f.key)) continue; // NAV.* fazlalığı ekran başına değil, aşağıda sekme kökü envanterlerinin birleşimine göre
      if (e.actions.some((a) => f.re.test(a))) {
        if (e.actions.filter((a) => f.re.test(a)).every(isExempt)) err('AKS03', f.key, `${f.file}:${f.line} muaf (demo) aksiyon uygulanmış — K-02`);
        continue;
      }
      if (isDynamic(f.key)) { dynamic++; continue; } // CD-86: tool/design_dynamic_actions.txt
      extra.push(f);
      err('AKS02', f.key, `${f.file}:${f.line} envanterde olmayan fazla anahtar (${sid})`);
    }
    rows.push({ id: sid, expected: expected.length, found: expected.length - missing.length, missing: missing.length, extra: extra.length, dynamic });
  }
  // NAV.* fazla anahtar (CD-53): hiçbir sekme kökü envanterinde karşılığı yoksa (kapsamdan bağımsız, AKS05/AKS06 gibi)
  if (navRes.length) {
    const navInv = [...tabRoots].flatMap((r) => ((inv[r] && inv[r].actions) || []).filter(isNav));
    for (const f of navRes) {
      const hits = navInv.filter((a) => f.re.test(a));
      if (hits.length) {
        if (hits.every(isExempt)) err('AKS03', f.key, `${f.file}:${f.line} muaf (demo) aksiyon uygulanmış — K-02`);
        continue;
      }
      if (isDynamic(f.key)) continue;
      err('AKS02', f.key, `${f.file}:${f.line} hiçbir sekme kökü (registry.tabRoot: ${[...tabRoots].join(', ')}) envanterinde olmayan fazla NAV anahtarı`);
    }
  }
  return rows;
}

function checkCatalogs(S) {
  const defs = [
    ['ToastId', regIds.toast.filter((i) => !excluded.has(i))],
    ['SheetId', regIds.sheet],
    ['DialogId', regIds.dialog],
    // CD-113: kayıtlı menüler (registry.json#menus — SHT-01 açılır menü biçimi + EVT-MENU); registry'de menü yoksa enum aranmaz
    ['MenuId', reg.menus || [], true],
  ];
  for (const [en, ids, optional] of defs) {
    const mem = S.members[en];
    if (mem.size === 0 && optional && !ids.length) continue;
    if (mem.size === 0) { err('KAT01', en, `\`enum ${en}\` bulunamadı (lib/product/feedback/)`); continue; }
    const want = new Set(ids.map(data.enumMember));
    for (const id of ids) if (!mem.has(data.enumMember(id))) err('KAT02', id, `${en}.${data.enumMember(id)} üyesi yok`);
    for (const k of mem.keys()) if (!want.has(k)) err('KAT03', k, `${en}.${k} registry'de karşılığı yok / muaf (TST-58 enum'a girmez)`);
    for (const id of ids) {
      const m = mem.get(data.enumMember(id));
      if (m && !m.traceIds.includes(id)) err('KAT04', id, `${m.file}:${m.line} ${en}.${data.enumMember(id)} üstünde \`/// Design: ${id}\` yok`);
    }
  }
}

// ── çalıştır ────────────────────────────────────────────────
const out = { mode: null, scope: [], rows: [], actions: [] };
let mapInfo = null;
const modeAll = has('--all');
const taskArg = val('--task');
const wantActions = has('--actions') || modeAll;

if (has('--wiring')) {
  const open = ((pj && pj.pendingWiring) || []).filter((w) => w.status === 'open');
  for (const w of open) console.log(`${w.id}\t${w.declaredIn} → ${(w.resolveIn || []).join(',')}\t${w.text}`);
  console.log(open.length ? `\nAçık bağlama borcu: ${open.length} (T-43 başlangıcında 0 olmalı)` : 'Açık bağlama borcu yok.');
  process.exit(open.length ? 1 : 0);
}

mapInfo = checkMap();
if (has('--map')) {
  finish();
}

let scopeTasks;
if (taskArg) {
  if (!taskIdx.has(taskArg)) fatal(`bilinmeyen task: ${taskArg}`);
  scopeTasks = [taskArg];
  out.mode = `task ${taskArg}`;
} else if (modeAll) {
  scopeTasks = tasks.map((t) => t.id).filter((id) => statusOf(id) !== 'skipped');
  out.mode = 'all';
} else {
  scopeTasks = tasks.map((t) => t.id).filter((id) => ['done', 'review'].includes(statusOf(id)));
  out.mode = 'biten task\'lar';
}
let ids = idsOfTasks(scopeTasks);
// atlanan (skipped) task'ların kimlikleri kapsam dışı
out.scope = ids;

if (has('--list')) {
  const t = taskArg ? tasks[taskIdx.get(taskArg)] : null;
  if (t) console.log(`${t.id} · ${t.title}\n${t.goal}\n`);
  const bykind = { screen: [], sheet: [], dialog: [], toast: [], menu: [] };
  for (const id of ids) bykind[data.kindOfId(id)].push(id);
  for (const k of Object.keys(bykind)) {
    if (!bykind[k].length) continue;
    console.log(`${k.toUpperCase()} (${bykind[k].length})`);
    for (const id of bykind[k]) {
      const a = k === 'screen' && inv[id] ? `  · ${inv[id].actionCount} aksiyon (${inv[id].actions.filter(isExempt).length} muaf)  · ${inv[id].path}` : '';
      console.log(`  ${id.padEnd(8)} ${titleOf(id)}${a}`);
    }
  }
  const ws = ((pj && pj.pendingWiring) || []).filter((w) => w.status === 'open' && taskArg && (w.resolveIn || []).includes(taskArg));
  if (ws.length) { console.log('\nBu task\'ın KAPATACAĞI bağlama borçları'); for (const w of ws) console.log(`  ${w.id}  (${w.declaredIn})  ${w.text}`); }
  if (t && (t.wires || []).length) { console.log('\nBu task\'ın AÇACAĞI bağlama borçları (wires)'); for (const w of t.wires) console.log('  - ' + w); }
  process.exit(0);
}

const S = scanCode();
const catalogDone = modeAll || taskArg === 'T-07' || statusOf('T-07') === 'done';
if (catalogDone) checkCatalogs(S);
const rows = checkIds(S, ids, modeAll ? 'all' : 'task');
out.rows = rows;
if (wantActions) {
  const screenIds = ids.filter((i) => data.kindOfId(i) === 'screen');
  out.actions = checkActions(S, screenIds, modeAll ? 'all' : 'task');
}
// kapsam dışı iz uyarısı
if (!modeAll) {
  const inScope = new Set(ids);
  for (const [id, locs] of S.traces) {
    const o = owner.get(id);
    if (!o || inScope.has(id)) continue;
    if (['pending'].includes(statusOf(o)) && o !== taskArg) warn('KAP01', id, `${locs[0].file}:${locs[0].line} sahibi ${o} henüz başlamadı — kapsam dışı uygulama olabilir (roadmap §0.3)`);
  }
}
if (modeAll) {
  const open = ((pj && pj.pendingWiring) || []).filter((w) => w.status === 'open');
  for (const w of open) err('BORC01', w.id, `açık bağlama borcu: ${w.text}`);
  for (const t of S.todos) err('TODO01', t.file + ':' + t.line, `yer tutucu/ödenmemiş iş kaldı: ${t.text}`);
  for (const t of tasks) {
    const st = statusOf(t.id);
    if (!['done', 'skipped'].includes(st)) err('DURUM01', t.id, `task durumu "${st}" — nihai kapı için done/skipped olmalı`);
  }
}
finish();

function finish() {
  const strict = has('--strict');
  if (has('--json')) {
    console.log(JSON.stringify({ mode: out.mode, errors, warnings: warns, rows: out.rows, actions: out.actions }, null, 1));
    process.exit(errors.length || (strict && warns.length) ? 1 : 0);
  }
  if (has('--map') || !out.mode) {
    for (const e of errors) console.error(`[${e.rule}] ${e.id}: ${e.msg}`);
    if (errors.length) { console.error(`\ncheck_design_coverage --map: ${errors.length} hata`); process.exit(1); }
    console.log(`check_design_coverage --map: temiz (${tasks.length} task · ${reg.screens.length}/${reg.sheets.length}/${reg.dialogs.length}/${reg.toasts.length - excluded.size} + ${excluded.size} muaf toast + ${regIds.menu.length} menü · ${mapInfo.total} aksiyon, ${mapInfo.exempt} muaf)`);
    process.exit(0);
  }
  if (out.rows.length) {
    const mark = (b) => (b === null ? '·' : b ? '✓' : '✗');
    console.log(`Kapsam: ${out.mode} — ${out.rows.length} kimlik`);
    console.log('KİMLİK    İZ TEST KUL  SAHİP  BAŞLIK');
    for (const r of out.rows) console.log(`${r.id.padEnd(9)} ${mark(r.trace)}   ${mark(r.test)}    ${mark(r.usage)}   ${(r.owner || '').padEnd(5)}  ${(r.title || '').slice(0, 48)}`);
  } else console.log(`Kapsam: ${out.mode} — kapsamda kimlik yok`);
  if (out.actions.length) {
    const tot = out.actions.reduce((a, r) => a + r.expected, 0), fnd = out.actions.reduce((a, r) => a + r.found, 0);
    console.log(`\nAksiyon: ${fnd}/${tot} anahtar (${out.actions.length} ekran)`);
    for (const r of out.actions.filter((x) => x.missing || x.extra)) console.log(`  ${r.id}: ${r.found}/${r.expected}${r.extra ? `  fazla ${r.extra}` : ''}`);
  }
  if (warns.length) { console.log(''); for (const w of warns) console.log(`UYARI [${w.rule}] ${w.id}: ${w.msg}`); }
  if (errors.length) {
    console.error('');
    for (const e of errors) console.error(`HATA [${e.rule}] ${e.id}: ${e.msg}`);
    console.error(`\ncheck_design_coverage: ${errors.length} hata${warns.length ? `, ${warns.length} uyarı` : ''}`);
    process.exit(1);
  }
  if (strict && warns.length) { console.error(`\ncheck_design_coverage --strict: ${warns.length} uyarı`); process.exit(1); }
  console.log(`\ncheck_design_coverage: temiz${warns.length ? ` (${warns.length} uyarı)` : ''}`);
  process.exit(0);
}
