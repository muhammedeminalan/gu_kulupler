#!/usr/bin/env node
'use strict';
/**
 * Hard delete denetimi (D-10, docs/soft-delete.md §6).
 *   node tool/check_no_hard_delete.js [--files a b] [--root dir] [--list]
 * Taranır: lib/, packages/<paket>/lib, functions/src, tool/ (test dizinleri ve bu kontrol betikleri hariç),
 *          firebase/*.rules (Rules).
 * İstisna: yalnızca ALAN temizleme için  // allow-field-delete: <gerekçe>  (FieldValue.delete()).
 *          Belge/dosya/hesap silme için satır içi istisna YOKTUR.
 */
const fs = require('fs');
const path = require('path');
const core = require('./lib/scan_core');

const argv = process.argv.slice(2);
const root = core.projectRoot(argv);

const isTest = (p) => /(^|\/)(test|integration_test|__tests__)\//.test(p) || /_test\.(dart|ts|js)$/.test(p) || /\.test\.(ts|js)$/.test(p);
const isSelf = (p) => /^tool\/(check_|lib\/|hooks\/|progress\.js|quality_gate)/.test(p);
const isDartSrc = (p) => /\.dart$/.test(p) && /^(lib|packages\/[^/]+\/lib|tool)\//.test(p) && !isTest(p) && !isSelf(p) && !/\.(g|gen)\.dart$/.test(p);
const isTsSrc = (p) => /\.(ts|js)$/.test(p) && /^(functions\/src|tool\/(admin|seed))\//.test(p) && !isTest(p) && !isSelf(p);
const isRules = (p) => /(^|\/)(firestore|storage)\.rules$/.test(p);

const dartRules = [
  { id: 'HD01', msg: '.delete(…) yasak (Firestore/Storage/Auth) → softDelete/restore', scope: isDartSrc, re: /\.delete\s*\(/, test: (m, lines, text) => !/FieldValue\.delete\s*\($/.test(text.slice(Math.max(0, m.index - 11), m.index + m[0].length)) && !/FieldValue$/.test(text.slice(Math.max(0, m.index - 10), m.index)) },
  { id: 'HD02', msg: 'deleteDoc/deleteApp/recursiveDelete/deleteUser yasak', scope: isDartSrc, re: /\b(?:deleteDoc|deleteDocument|deleteApp|recursiveDelete|deleteUser|deleteAll)\b/ },
  { id: 'HD03', msg: '`delete*` adlı metot/işlev tanımı yasak (repository/servis arayüzünde silme yok) → softDelete*/restore*/anonymize*', scope: isDartSrc, re: /(?<![\w.])delete[A-Z]\w*\s*\(/ },
  { id: 'HD04', msg: 'delete adlı üye: `Future<…> delete(`', scope: isDartSrc, re: /\b(?:Future|FutureOr)\s*<[^;{]*>\s+delete\s*\(|\bvoid\s+delete\s*\(/ },
  {
    id: 'HD05', msg: 'FieldValue.delete() yalnızca alan temizlemede ve gerekçeli: // allow-field-delete: <gerekçe>',
    scope: isDartSrc, re: /\bFieldValue\.delete\s*\(\s*\)/, allowMarker: core.ALLOW_FIELD_RE, ignorable: false,
  },
  { id: 'HD06', msg: 'Storage dosya silme yasak (Reference.delete) → yeni dosya + yol alanı güncelle', scope: isDartSrc, re: /\b(?:ref|reference|storageRef|child\([^)]*\))\s*\.\s*delete\b/i },
];
const tsRules = [
  { id: 'HD11', msg: '.delete() yasak (functions/tool) → soft delete alanları', scope: isTsSrc, re: /\.delete\s*\(\s*(?:\)|[^)]*\))/, test: (m, lines, text) => !/FieldValue\.delete\s*\(/.test(text.slice(Math.max(0, m.index - 11), m.index + 9)) },
  { id: 'HD12', msg: 'recursiveDelete/bulkWriter.delete/deleteUser/deleteFiles yasak', scope: isTsSrc, re: /\b(?:recursiveDelete|deleteUser|deleteUsers|deleteFiles|bulkWriter\s*\(\s*\)\s*\.\s*delete)\b|\.deleteFile\b|\.deleteBucket\b/ },
  { id: 'HD13', msg: 'FieldValue.delete() gerekçesiz: // allow-field-delete: <gerekçe>', scope: isTsSrc, re: /\bFieldValue\.delete\s*\(\s*\)/, allowMarker: core.ALLOW_FIELD_RE, ignorable: false },
];

// Rules: comment-sanitized text; `allow` ifadelerini ayrıştır.
function checkRules(rel, content) {
  const lines = core.parse(content, {});
  const viol = [];
  const text = lines.map((l) => l.code).join('\n');
  const re = /\ballow\s+([a-z ,]+?)\s*(?::\s*if\b([^;]*))?;/g;
  let m;
  while ((m = re.exec(text))) {
    const ops = m[1].split(',').map((s) => s.trim());
    const cond = (m[2] || '').trim();
    const ln = text.slice(0, m.index).split('\n').length;
    const denies = cond === 'false';
    if (!m[2] && !denies) {
      viol.push({ file: rel, line: ln, rule: 'HD21', msg: '`allow …;` koşulsuz (herkese açık) yasak', text: lines[ln - 1].raw });
      continue;
    }
    if (ops.includes('write') && !denies) viol.push({ file: rel, line: ln, rule: 'HD20', msg: '`allow write` delete\'i de kapsar → ayrı create/update kullan', text: lines[ln - 1].raw });
    if (ops.includes('delete') && !denies) viol.push({ file: rel, line: ln, rule: 'HD22', msg: '`allow delete` yalnızca `if false` olabilir', text: lines[ln - 1].raw });
  }
  return viol;
}

if (argv.includes('--list')) {
  for (const r of dartRules.concat(tsRules)) console.log(`${r.id}\t${r.msg}`);
  console.log('HD20\tallow write (delete kapsar)  · HD21 koşulsuz allow · HD22 allow delete ≠ if false');
  process.exit(0);
}

let files = core.filesFromArgs(argv, root);
if (!files) files = core.walk(root, (f) => /\.(dart|ts|js|rules)$/.test(f));
let viol = [];
for (const f of files) {
  const rel = core.toPosix(path.relative(root, f));
  const content = fs.readFileSync(f, 'utf8');
  if (isRules(rel)) { viol = viol.concat(checkRules(rel, content)); continue; }
  if (/\.dart$/.test(rel)) viol = viol.concat(core.runRules(rel, content, dartRules));
  else if (/\.(ts|js)$/.test(rel)) viol = viol.concat(core.runRules(rel, content, tsRules, { backtick: true }));
}
// HC00 (hardcode ignore) bu denetimde anlamsız → ele
viol = viol.filter((v) => v.rule !== 'HC00');
process.exit(core.report(viol, argv, 'check_no_hard_delete'));
