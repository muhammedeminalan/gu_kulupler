#!/usr/bin/env node
'use strict';
/**
 * ARB denetimi (L9, D-16): TR ↔ EN eşitliği, ICU yer tutucu paritesi, metadata tutarlılığı.
 *
 *   node tool/check_arb_parity.js                       # eşitlik + ICU + metadata
 *   node tool/check_arb_parity.js --strict              # ürün adı literali (K-22) de hata
 *   node tool/check_arb_parity.js --unused              # kullanılmayan anahtarlar (yalnızca nihai kapı; tool/arb_dynamic_keys.txt ile istisna)
 *   node tool/check_arb_parity.js --prune-prototype-only [--dry-run]
 *        description'ı "Key assets.|panel.|qa.|ds.|map.|site." ile başlayan prototip-kabuğu anahtarlarını
 *        iki ARB'den çıkarıp design/prototype-only-arb/ altına arşivler (K-21; beklenen 1421 → 1235).
 *   ek: --root <dir> · --dir <arb-dir> (varsayılan l10n.yaml'daki arb-dir ya da lib/l10n)
 *
 * Kurallar: ARB01 anahtar kümesi · ARB02 boş değer · ARB03 anahtar adı · ARB04 ICU sözdizimi · ARB05 `other` yok ·
 *  ARB06 yer tutucu kümesi · ARB07 select durumları · ARB08 @key.placeholders ↔ kullanım · ARB09 ürün adı literali ·
 *  ARB10 description biçimi · ARB11 @@locale · ARB12 artık metadata · ARB13 plural sayaç tipi · ARB14 kullanılmayan anahtar
 */
const fs = require('fs');
const path = require('path');
const core = require('./lib/scan_core');

const argv = process.argv.slice(2);
const root = core.projectRoot(argv);
const has = (f) => argv.includes(f);
const val = (f) => { const i = argv.indexOf(f); return i >= 0 && argv[i + 1] && !argv[i + 1].startsWith('--') ? argv[i + 1] : null; };

const PROTOTYPE_GROUPS = ['assets', 'panel', 'qa', 'ds', 'map', 'site'];
const EXPECT_BEFORE = 1421, EXPECT_PRUNED = 186, EXPECT_AFTER = 1235;
const APP_NAME_LITERALS = ['GÜ Kulüpler', 'GU Kulupler', 'GÜ Kulupler'];

function arbDir() {
  const a = val('--dir');
  if (a) return path.resolve(root, a);
  try {
    const m = /^arb-dir:\s*(\S+)/m.exec(fs.readFileSync(path.join(root, 'l10n.yaml'), 'utf8'));
    if (m) return path.resolve(root, m[1]);
  } catch (e) { /* l10n.yaml yok */ }
  return path.join(root, 'lib/l10n');
}
const dir = arbDir();
const relDir = core.toPosix(path.relative(root, dir)) || '.';
const files = { tr: path.join(dir, 'app_tr.arb'), en: path.join(dir, 'app_en.arb') };

function load(lang) {
  if (!fs.existsSync(files[lang])) { console.error(`check_arb_parity: ${relDir}/app_${lang}.arb yok`); process.exit(2); }
  try { return JSON.parse(fs.readFileSync(files[lang], 'utf8')); } catch (e) { console.error(`check_arb_parity: app_${lang}.arb geçersiz JSON — ${e.message}`); process.exit(2); }
}
const isKey = (k) => !k.startsWith('@');

// ── mini ICU çözümleyici ───────────────────────────────────
/** @returns {{args: Map<string,{types:Set<string>,cases?:Set<string>}>, errors: string[]}} */
function parseIcu(msg) {
  const args = new Map();
  const errors = [];
  let i = 0;
  const n = msg.length;
  const note = (name, type, cases) => {
    if (!args.has(name)) args.set(name, { types: new Set(), cases: new Set() });
    const a = args.get(name);
    a.types.add(type);
    if (cases) for (const c of cases) a.cases.add(c);
  };
  function skipWs() { while (i < n && /\s/.test(msg[i])) i++; }
  /** düz metin + argümanlar; derinlik>0 ise eşleşmeyen '}' ile biter */
  function message(depth) {
    while (i < n) {
      const c = msg[i];
      if (c === "'") {
        if (msg[i + 1] === "'") { i += 2; continue; }
        if (msg[i + 1] === '{' || msg[i + 1] === '}') {
          const end = msg.indexOf("'", i + 1);
          if (end < 0) { errors.push('kapanmayan tırnaklı süslü parantez'); i = n; return; }
          i = end + 1; continue;
        }
        i++; continue;
      }
      if (c === '{') { i++; argument(); continue; }
      if (c === '}') {
        if (depth > 0) return;
        errors.push(`eşleşmeyen '}' (konum ${i})`); i++; continue;
      }
      i++;
    }
    if (depth > 0) errors.push("kapanmayan '{'");
  }
  function argument() {
    skipWs();
    const start = i;
    while (i < n && !/[,}\s]/.test(msg[i])) i++;
    const name = msg.slice(start, i);
    if (!/^[A-Za-z_]\w*$/.test(name)) { errors.push(`geçersiz yer tutucu adı "${name}"`); }
    skipWs();
    if (msg[i] === '}') { i++; note(name, 'simple'); return; }
    if (msg[i] !== ',') { errors.push(`"${name}" sonrası ',' ya da '}' bekleniyordu`); return; }
    i++; skipWs();
    const ts = i;
    while (i < n && !/[,}\s]/.test(msg[i])) i++;
    const type = msg.slice(ts, i);
    skipWs();
    if (type === 'plural' || type === 'select' || type === 'selectordinal') {
      if (msg[i] !== ',') { errors.push(`"${name}, ${type}" sonrası ',' bekleniyordu`); return; }
      i++;
      const cases = new Set();
      for (;;) {
        skipWs();
        if (i >= n) { errors.push(`"${name}" ${type} kapanmadı`); return; }
        if (msg[i] === '}') { i++; break; }
        const cs = i;
        while (i < n && !/[\s{]/.test(msg[i])) i++;
        const sel = msg.slice(cs, i);
        skipWs();
        if (msg[i] !== '{') { errors.push(`"${name}" ${type}: "${sel}" sonrası '{' bekleniyordu`); return; }
        i++;
        if (!/^offset:\d+$/.test(sel)) cases.add(sel);
        message(1);
        if (msg[i] !== '}') { errors.push(`"${name}" ${type}: "${sel}" dalı kapanmadı`); return; }
        i++;
      }
      if (!cases.has('other')) errors.push(`"${name}" ${type} için 'other' dalı yok`);
      note(name, type, type === 'select' ? cases : null);
      return;
    }
    // number / date / time vb.: biçim tanımına kadar oku
    if (msg[i] === ',') { i++; while (i < n && msg[i] !== '}') i++; }
    if (msg[i] !== '}') { errors.push(`"${name}, ${type}" kapanmadı`); return; }
    i++;
    note(name, type);
  }
  message(0);
  return { args, errors };
}

// ── denetim ────────────────────────────────────────────────
function lint() {
  const tr = load('tr'), en = load('en');
  const errs = [];
  const warns = [];
  const E = (rule, key, msg) => errs.push({ rule, key, msg });
  const W = (rule, key, msg) => warns.push({ rule, key, msg });
  if (tr['@@locale'] !== 'tr') E('ARB11', '@@locale', `app_tr.arb @@locale "${tr['@@locale']}" (tr olmalı)`);
  if (en['@@locale'] !== 'en') E('ARB11', '@@locale', `app_en.arb @@locale "${en['@@locale']}" (en olmalı)`);
  const kTr = Object.keys(tr).filter(isKey).filter((k) => !k.startsWith('@@'));
  const kEn = Object.keys(en).filter(isKey).filter((k) => !k.startsWith('@@'));
  const sTr = new Set(kTr), sEn = new Set(kEn);
  for (const k of kTr) if (!sEn.has(k)) E('ARB01', k, 'TR\'de var, EN\'de yok');
  for (const k of kEn) if (!sTr.has(k)) E('ARB01', k, 'EN\'de var, TR\'de yok');

  const checkMeta = (name, arb, keys, isTemplate) => {
    for (const mk of Object.keys(arb)) {
      if (!mk.startsWith('@') || mk.startsWith('@@')) continue;
      if (!(mk.slice(1) in arb)) E('ARB12', mk, `${name}: "${mk}" için ${mk.slice(1)} anahtarı yok (artık metadata)`);
    }
    for (const k of keys) {
      if (!/^[a-z][A-Za-z0-9]*$/.test(k)) E('ARB03', k, `${name}: anahtar adı lowerCamelCase olmalı (harf/rakam)`);
      const v = arb[k];
      if (typeof v !== 'string' || v.trim() === '') { E('ARB02', k, `${name}: değer boş ya da metin değil`); continue; }
      const meta = arb['@' + k];
      if (isTemplate) {
        const d = meta && meta.description;
        if (typeof d !== 'string' || !/^Key [A-Za-z0-9_]+(\.[A-Za-z0-9_]+)+$/.test(d)) W('ARB10', k, `description "Key grup.ad" biçiminde değil (${JSON.stringify(d)}); K-21 budaması buna dayanır`);
      }
      const parsed = parseIcu(v);
      for (const m of parsed.errors) E('ARB04', k, `${name}: ${m}`);
      for (const m of parsed.errors) if (/'other'/.test(m)) E('ARB05', k, `${name}: ${m}`);
      const declared = meta && meta.placeholders ? Object.keys(meta.placeholders) : [];
      const used = [...parsed.args.keys()];
      for (const u of used) if (!declared.includes(u)) (isTemplate ? E : W)('ARB08', k, `${name}: "{${u}}" kullanılıyor ama @${k}.placeholders içinde tanımlı değil`);
      for (const d of declared) {
        if (used.includes(d)) continue;
        const hint = v.includes("'{" + d + "}'") ? " — `'{" + d + "}'` ICU'da TIRNAKLI LİTERALDİR, değer basılmaz; düz tırnak için `''{" + d + "}''` ya da tipografik “{" + d + "}” kullan (K-23)"
          : /(?:=\d+|one|other|zero|two|few|many)\{[^{}]*\}/.test(v) ? ' — plural dal metni yer tutucu sanılmış; metadata\'dan sil (K-23)' : '';
        (isTemplate ? E : W)('ARB08', k, `${name}: placeholders.${d} tanımlı ama metinde kullanılmıyor${hint}`);
      }
      for (const [pn, pa] of parsed.args) {
        if (pa.types.has('plural') || pa.types.has('selectordinal')) {
          const t = meta && meta.placeholders && meta.placeholders[pn] && meta.placeholders[pn].type;
          if (t && !['int', 'num', 'double'].includes(t)) E('ARB13', k, `${name}: plural sayacı "${pn}" tipi ${t} (int/num olmalı)`);
        }
      }
    }
  };
  checkMeta('TR', tr, kTr, true);
  checkMeta('EN', en, kEn, false);

  // TR ↔ EN yer tutucu paritesi
  for (const k of kTr) {
    if (!sEn.has(k) || typeof tr[k] !== 'string' || typeof en[k] !== 'string') continue;
    const a = parseIcu(tr[k]).args, b = parseIcu(en[k]).args;
    const an = [...a.keys()].sort().join(','), bn = [...b.keys()].sort().join(',');
    if (an !== bn) E('ARB06', k, `yer tutucu kümeleri farklı: TR {${an}} ≠ EN {${bn}}`);
    else {
      for (const [pn, pa] of a) {
        const pb = b.get(pn);
        if (pa.types.has('select') !== pb.types.has('select')) E('ARB07', k, `"${pn}" TR'de ${[...pa.types]} EN'de ${[...pb.types]}`);
        else if (pa.types.has('select')) {
          const x = [...pa.cases].sort().join('|'), y = [...pb.cases].sort().join('|');
          if (x !== y) E('ARB07', k, `select "${pn}" durumları farklı: TR ${x} ≠ EN ${y}`);
        }
      }
    }
  }
  // ürün adı literali (K-22)
  for (const [name, arb, keys] of [['TR', tr, kTr], ['EN', en, kEn]]) {
    for (const k of keys) {
      if (typeof arb[k] === 'string' && APP_NAME_LITERALS.some((s) => arb[k].includes(s))) (has('--strict') ? E : W)('ARB09', k, `${name}: ürün adı literal — {appName} yer tutucusu kullan (K-22, D-01)`);
    }
  }
  return { errs, warns, tr, en, kTr, kEn };
}

// ── --unused ───────────────────────────────────────────────
function unusedKeys(keys) {
  const used = new Set();
  const files = core.walk(root, (f) => {
    const rel = core.toPosix(path.relative(root, f));
    return /\.dart$/.test(rel) && /^(lib|packages\/[^/]+\/lib)\//.test(rel) && !/app_localizations/.test(rel) && !/\.(g|gen)\.dart$/.test(rel);
  });
  for (const f of files) {
    const text = fs.readFileSync(f, 'utf8');
    const re = /\b(?:l10n|loc|localizations|strings)\s*\.\s*([a-z][A-Za-z0-9]*)\b/g;
    let m;
    while ((m = re.exec(text))) used.add(m[1]);
    // tear-off ve doğrudan AppLocalizations.of(context).key
    const re2 = /AppLocalizations\.of\([^)]*\)!?\s*\.\s*([a-z][A-Za-z0-9]*)\b/g;
    while ((m = re2.exec(text))) used.add(m[1]);
  }
  let allow = [];
  const ap = path.join(root, 'tool/arb_dynamic_keys.txt');
  if (fs.existsSync(ap)) allow = fs.readFileSync(ap, 'utf8').split(/\r?\n/).map((l) => l.replace(/#.*/, '').trim()).filter(Boolean);
  const allowed = (k) => allow.some((p) => (p.endsWith('*') ? k.startsWith(p.slice(0, -1)) : k === p));
  return keys.filter((k) => !used.has(k) && !allowed(k));
}

// ── --prune-prototype-only ─────────────────────────────────
function prune() {
  const dry = has('--dry-run');
  const tr = load('tr'), en = load('en');
  const before = Object.keys(tr).filter(isKey).filter((k) => !k.startsWith('@@')).length;
  const re = new RegExp(`^Key (${PROTOTYPE_GROUPS.join('|')})\\.`);
  const victims = Object.keys(tr).filter(isKey).filter((k) => !k.startsWith('@@')).filter((k) => tr['@' + k] && typeof tr['@' + k].description === 'string' && re.test(tr['@' + k].description));
  const byGroup = {};
  for (const k of victims) { const g = tr['@' + k].description.split(/[ .]/)[1]; byGroup[g] = (byGroup[g] || 0) + 1; }
  if (!victims.length) { console.log(`Budanacak prototip-kabuğu anahtarı yok (${before} anahtar).`); return 0; }
  // güvenlik: kodda kullanılıyorsa dur
  const used = unusedKeys(victims);
  const inUse = victims.filter((k) => !used.includes(k));
  if (inUse.length) {
    console.error(`DUR: budanacak ${inUse.length} anahtar kodda kullanılıyor (ör. ${inUse.slice(0, 5).join(', ')}). Önce kullanımı kaldır ya da kullanıcıya sor.`);
    return 1;
  }
  const arch = path.join(root, 'design/prototype-only-arb');
  const out = { tr: {}, en: {} };
  for (const lang of ['tr', 'en']) {
    const src = lang === 'tr' ? tr : en;
    const archived = { '@@locale': lang };
    const archPath = path.join(arch, `app_${lang}.arb`);
    if (fs.existsSync(archPath)) { try { Object.assign(archived, JSON.parse(fs.readFileSync(archPath, 'utf8'))); } catch (e) { /* üzerine yaz */ } }
    for (const k of victims) {
      if (k in src) archived[k] = src[k];
      if ('@' + k in src) archived['@' + k] = src['@' + k];
      delete src[k]; delete src['@' + k];
    }
    out[lang] = { kept: src, archived, archPath };
  }
  const after = Object.keys(tr).filter(isKey).filter((k) => !k.startsWith('@@')).length;
  console.log(`Prototip-kabuğu anahtarları: ${victims.length} (${Object.entries(byGroup).map(([g, c]) => `${g} ${c}`).join(' · ')})`);
  console.log(`Önce ${before} → sonra ${after} anahtar`);
  const expectedCase = before === EXPECT_BEFORE;
  if (expectedCase && (victims.length !== EXPECT_PRUNED || after !== EXPECT_AFTER)) {
    console.error(`HATA: beklenen ${EXPECT_BEFORE} → ${EXPECT_AFTER} (${EXPECT_PRUNED} budama); farklı sonuç — yazılmadı.`);
    return 1;
  }
  if (dry) { console.log('(--dry-run: dosyalara yazılmadı)'); return 0; }
  fs.mkdirSync(arch, { recursive: true });
  for (const lang of ['tr', 'en']) {
    const o = out[lang];
    fs.writeFileSync(files[lang], JSON.stringify(o.kept, null, 2) + '\n');
    fs.writeFileSync(o.archPath, JSON.stringify(o.archived, null, 2) + '\n');
  }
  fs.writeFileSync(path.join(arch, 'README.md'), '# Prototip-kabuğu ARB anahtarları (arşiv)\n\nK-21: Claude Design prototipinin Kontrol Paneli, Assets, Tasarım Sistemi, Ekran Haritası, Kalite Kontrol sayfaları ve site kabuğuna ait ' + victims.length + ' anahtar. Uygulamada kullanılmaz; yalnızca arşiv/referanstır. `node tool/check_arb_parity.js --prune-prototype-only` ile üretildi.\n');
  console.log(`Yazıldı: ${relDir}/app_{tr,en}.arb  ·  arşiv: design/prototype-only-arb/`);
  return 0;
}

// ── çalıştır ───────────────────────────────────────────────
if (has('--prune-prototype-only')) process.exit(prune());

const r = lint();
let errs = r.errs, warns = r.warns;
if (has('--unused')) {
  for (const k of unusedKeys(r.kTr)) errs.push({ rule: 'ARB14', key: k, msg: 'kodda hiç kullanılmıyor (dinamik kullanım ise tool/arb_dynamic_keys.txt\'ye gerekçeyle ekle)' });
}
for (const w of warns) console.log(`UYARI [${w.rule}] ${w.key}: ${w.msg}`);
for (const e of errs) console.error(`HATA [${e.rule}] ${e.key}: ${e.msg}`);
if (has('--json')) console.log(JSON.stringify({ tr: r.kTr.length, en: r.kEn.length, errors: errs, warnings: warns }));
if (errs.length) { console.error(`\ncheck_arb_parity: ${errs.length} hata, ${warns.length} uyarı (TR ${r.kTr.length} · EN ${r.kEn.length})`); process.exit(1); }
console.log(`check_arb_parity: temiz — TR ${r.kTr.length} · EN ${r.kEn.length} anahtar${warns.length ? `, ${warns.length} uyarı` : ''}`);
process.exit(0);
