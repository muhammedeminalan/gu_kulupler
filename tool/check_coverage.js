#!/usr/bin/env node
'use strict';
/**
 * Satır kapsamı eşikleri (docs/testing.md §8).
 *   node tool/check_coverage.js [--root dir] [--json]
 * Girdi: kök ve packages/<paket>/coverage/lcov.info (flutter test --coverage).
 * Eşikler: gu_data ≥ 90 · gu_ui ≥ 90 · lib/features/<f>/(provider|view_model) ≥ 90 · lib/features/<f>/view ≥ 80.
 * Hariç: *.g.dart, *.gen.dart, *.freezed.dart, firebase_options.dart, lib/l10n/app_localizations*.
 * lcov'da hiç görünmeyen (teste yüklenmemiş) kaynak dosyalar UYARI olarak listelenir.
 * Hiçbir grupta dosya yoksa (boş iskelet) başarıyla geçer.
 */
const fs = require('fs');
const path = require('path');
const core = require('./lib/scan_core');

const argv = process.argv.slice(2);
const root = core.projectRoot(argv);

const EXCLUDE = /\.(g|gen|freezed)\.dart$|(^|\/)firebase_options\.dart$|(^|\/)lib\/l10n\/app_localizations/;
const GROUPS = [
  { name: 'gu_data', min: 90, test: (p) => /^packages\/gu_data\/lib\//.test(p) },
  { name: 'gu_ui', min: 90, test: (p) => /^packages\/gu_ui\/lib\//.test(p) },
  { name: 'provider/view_model', min: 90, test: (p) => /^lib\/features\/[^/]+\/(provider|view_model)\//.test(p) },
  { name: 'view', min: 80, test: (p) => /^lib\/features\/[^/]+\/view\//.test(p) },
];

function readLcov(file, prefix) {
  const out = new Map();
  let cur = null;
  for (const ln of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
    if (ln.startsWith('SF:')) {
      let p = ln.slice(3).replace(/\\/g, '/');
      if (path.isAbsolute(p)) p = core.toPosix(path.relative(root, p));
      else p = (prefix ? prefix + '/' : '') + p.replace(/^\.\//, '');
      cur = { file: p, lf: 0, lh: 0 };
    } else if (ln.startsWith('LF:') && cur) cur.lf = parseInt(ln.slice(3), 10) || 0;
    else if (ln.startsWith('LH:') && cur) cur.lh = parseInt(ln.slice(3), 10) || 0;
    else if (ln === 'end_of_record' && cur) {
      const prev = out.get(cur.file);
      if (prev) { prev.lf = Math.max(prev.lf, cur.lf); prev.lh = Math.max(prev.lh, cur.lh); } else out.set(cur.file, cur);
      cur = null;
    }
  }
  return out;
}

const sources = [['coverage/lcov.info', '']];
for (const d of fs.existsSync(path.join(root, 'packages')) ? fs.readdirSync(path.join(root, 'packages')) : []) sources.push([`packages/${d}/coverage/lcov.info`, `packages/${d}`]);
const cov = new Map();
let found = 0;
for (const [rel, prefix] of sources) {
  const f = path.join(root, rel);
  if (!fs.existsSync(f)) continue;
  found++;
  for (const [k, v] of readLcov(f, prefix)) cov.set(k, v);
}

const warns = [], errs = [], rows = [];
for (const g of GROUPS) {
  const members = [...cov.values()].filter((c) => g.test(c.file) && !EXCLUDE.test(c.file));
  const lf = members.reduce((a, c) => a + c.lf, 0), lh = members.reduce((a, c) => a + c.lh, 0);
  // lcov'da olmayan kaynaklar
  const srcs = core.walk(root, (f) => /\.dart$/.test(f)).map((f) => core.toPosix(path.relative(root, f))).filter((p) => g.test(p) && !EXCLUDE.test(p));
  const missing = srcs.filter((p) => !cov.has(p) && fs.readFileSync(path.join(root, p), 'utf8').split('\n').length > 8);
  if (!members.length && !srcs.length) { rows.push({ group: g.name, min: g.min, pct: null, files: 0 }); continue; }
  const pct = lf ? (100 * lh) / lf : (srcs.length ? 0 : null);
  rows.push({ group: g.name, min: g.min, pct, files: members.length, lines: `${lh}/${lf}` });
  if (pct !== null && pct + 1e-9 < g.min) errs.push(`${g.name}: %${pct.toFixed(1)} < %${g.min} (${lh}/${lf} satır)`);
  if (found === 0 && srcs.length) errs.push(`${g.name}: ${srcs.length} kaynak dosya var ama kapsam raporu yok (flutter test --coverage çalışmadı)`);
  for (const m of missing.slice(0, 20)) warns.push(`${g.name}: ${m} hiçbir testte yüklenmiyor (kapsam dışı kalıyor)`);
  if (missing.length > 20) warns.push(`${g.name}: … ve ${missing.length - 20} dosya daha`);
}

if (argv.includes('--json')) { console.log(JSON.stringify({ rows, errors: errs, warnings: warns }, null, 1)); process.exit(errs.length ? 1 : 0); }
for (const r of rows) console.log(`${r.group.padEnd(20)} ${r.pct === null ? '—' : r.pct.toFixed(1).padStart(5) + '%'}  (eşik ${r.min}%)  ${r.lines || ''}`);
for (const w of warns) console.log('UYARI ' + w);
for (const e of errs) console.error('HATA ' + e);
if (errs.length) { console.error(`\ncheck_coverage: ${errs.length} hata`); process.exit(1); }
console.log('check_coverage: temiz');
