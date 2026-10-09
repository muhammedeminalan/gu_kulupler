'use strict';
// Ortak tarama çekirdeği: Dart/TS/Rules kaynaklarını yorum ve string içeriklerinden ayırır,
// kural motorunu çalıştırır. Bağımlılık yok (yalnızca Node ≥ 18).
const fs = require('fs');
const path = require('path');

const SKIP_DIRS = new Set(['node_modules', '.git', '.dart_tool', 'build', '.idea', '.gradle', 'Pods', '.symlinks', 'ephemeral', '.pub-cache']);
const STR_MARK = '\u0001';

function toPosix(p) { return p.split(path.sep).join('/'); }

function projectRoot(argv) {
  const i = argv.indexOf('--root');
  if (i >= 0 && argv[i + 1]) return path.resolve(argv[i + 1]);
  return path.resolve(__dirname, '..', '..');
}

function walk(dir, accept, out) {
  out = out || [];
  let ents;
  try { ents = fs.readdirSync(dir, { withFileTypes: true }); } catch (e) { return out; }
  for (const e of ents) {
    if (e.isDirectory()) {
      if (SKIP_DIRS.has(e.name)) continue;
      walk(path.join(dir, e.name), accept, out);
    } else if (e.isFile() || e.isSymbolicLink()) {
      const full = path.join(dir, e.name);
      if (accept(full)) out.push(full);
    }
  }
  return out;
}

/**
 * Bir kaynak metni satır satır çözümler.
 * Döndürür: lines[i] = { no, raw, code, comment, strs: [] }
 *  - code: yorumlar atılmış, her string literal'i  "\u0001<idx>\u0001" ile değiştirilmiş satır
 *  - strs: string literal içerikleri (dizin = idx)
 * Dart: tek/çift/üçlü tırnak ve r'..' ham string; TS: ayrıca ters tırnak; satır (//) ve blok yorumları.
 */
function parse(text, opts) {
  opts = opts || {};
  const backtick = !!opts.backtick;
  const rawLines = text.split(/\r?\n/);
  const out = [];
  let inBlock = false;
  let triple = null;      // aktif üçlü tırnak: "'''" | '"""'
  let tripleRaw = false;
  let tripleBuf = '';
  let tripleIdxHolder = null;
  for (let ln = 0; ln < rawLines.length; ln++) {
    const raw = rawLines[ln];
    const strs = [];
    let code = '';
    let comment = '';
    let i = 0;
    const n = raw.length;
    // satır başında üçlü tırnak devam ediyorsa
    if (triple) {
      const end = raw.indexOf(triple);
      if (end < 0) { tripleBuf += raw + '\n'; out.push({ no: ln + 1, raw, code: '', comment: '', strs }); continue; }
      tripleBuf += raw.slice(0, end);
      strs.push(tripleBuf);
      code += '"' + STR_MARK + (strs.length - 1) + STR_MARK + '"';
      i = end + 3; triple = null; tripleBuf = '';
    }
    while (i < n) {
      const c = raw[i];
      const c2 = raw[i + 1];
      if (inBlock) {
        const end = raw.indexOf('*/', i);
        if (end < 0) { comment += raw.slice(i); i = n; break; }
        comment += raw.slice(i, end); i = end + 2; inBlock = false; continue;
      }
      if (c === '/' && c2 === '/') { comment += raw.slice(i + 2); i = n; break; }
      if (c === '/' && c2 === '*') { inBlock = true; i += 2; continue; }
      // raw prefix (Dart): r' veya r"
      let isRaw = false;
      let q = null;
      if ((c === 'r') && (c2 === "'" || c2 === '"') && !/[\w$]/.test(raw[i - 1] || ' ')) { isRaw = true; q = c2; i += 1; }
      else if (c === "'" || c === '"' || (backtick && c === '`')) q = c;
      if (q) {
        const isTriple = raw.substr(i, 3) === q + q + q && q !== '`';
        if (isTriple) {
          const end = raw.indexOf(q + q + q, i + 3);
          if (end < 0) { triple = q + q + q; tripleRaw = isRaw; tripleBuf = raw.slice(i + 3) + '\n'; i = n; break; }
          strs.push(raw.slice(i + 3, end));
          code += '"' + STR_MARK + (strs.length - 1) + STR_MARK + '"';
          i = end + 3; continue;
        }
        let j = i + 1; let buf = '';
        while (j < n) {
          const d = raw[j];
          if (!isRaw && d === '\\') { buf += raw.slice(j, j + 2); j += 2; continue; }
          if (d === q) break;
          buf += d; j++;
        }
        strs.push(buf);
        code += '"' + STR_MARK + (strs.length - 1) + STR_MARK + '"';
        i = j + 1; continue;
      }
      code += c; i++;
    }
    out.push({ no: ln + 1, raw, code, comment, strs });
  }
  return out;
}

const IGNORE_RE = /ignore-hardcode\s*:\s*(\S.{3,})/;
const ALLOW_FIELD_RE = /allow-field-delete\s*:\s*(\S.{3,})/;

function markerOn(lines, idx, re) {
  if (re.test(lines[idx].comment)) return true;
  const prev = lines[idx - 1];
  if (prev && prev.code.trim() === '' && re.test(prev.comment)) return true;
  return false;
}

/** Tüm kodu tek metinde birleştirir; indeks → satır eşlemesi için ofset tablosu döndürür. */
function joinCode(lines) {
  let text = '';
  const offs = [];
  for (const l of lines) { offs.push(text.length); text += l.code + '\n'; }
  return { text, offs };
}
function lineAt(offs, pos) {
  let lo = 0, hi = offs.length - 1;
  while (lo < hi) { const mid = (lo + hi + 1) >> 1; if (offs[mid] <= pos) lo = mid; else hi = mid - 1; }
  return lo;
}

function hasNonZeroNumber(s) {
  const re = /(?<![\w.$])(\d+(?:\.\d+)?)(?![\w])/g;
  let m;
  while ((m = re.exec(s))) { if (parseFloat(m[1]) !== 0) return true; }
  return false;
}

function strOf(lines, idx, ref) {
  // "\u0001k\u0001" → literal içeriği
  const k = parseInt(ref, 10);
  return lines[idx].strs[k];
}

function runRules(relPath, content, rules, parseOpts) {
  const lines = parse(content, parseOpts);
  const { text, offs } = joinCode(lines);
  const viol = [];
  const seen = new Set();
  for (const rule of rules) {
    if (!rule.scope(relPath)) continue;
    if (rule.fn) {
      for (const v of rule.fn({ relPath, lines, text, offs })) {
        const key = rule.id + ':' + v.line;
        if (seen.has(key)) continue;
        seen.add(key);
        viol.push({ file: relPath, line: v.line, rule: rule.id, msg: v.msg || rule.msg, text: (lines[v.line - 1] || {}).raw });
      }
      continue;
    }
    const re = new RegExp(rule.re.source, rule.re.flags.includes('g') ? rule.re.flags : rule.re.flags + 'g');
    let m;
    while ((m = re.exec(text))) {
      if (m[0].length === 0) { re.lastIndex++; continue; }
      if (rule.test && !rule.test(m, lines, text)) continue;
      const idx = lineAt(offs, m.index);
      const key = rule.id + ':' + (idx + 1);
      if (seen.has(key)) continue;
      if (rule.ignorable !== false && markerOn(lines, idx, IGNORE_RE)) continue;
      if (rule.allowMarker && markerOn(lines, idx, rule.allowMarker)) continue;
      seen.add(key);
      viol.push({ file: relPath, line: idx + 1, rule: rule.id, msg: rule.msg, text: lines[idx].raw });
    }
  }
  // gerekçesiz ignore işaretleri
  lines.forEach((l, i) => {
    if (/ignore-hardcode\b/.test(l.comment) && !IGNORE_RE.test(l.comment)) {
      viol.push({ file: relPath, line: i + 1, rule: 'HC00', msg: '`ignore-hardcode` işaretinde gerekçe zorunlu (// ignore-hardcode: <gerekçe>)', text: l.raw });
    }
  });
  return viol;
}

function report(viol, argv, title) {
  viol.sort((a, b) => (a.file < b.file ? -1 : a.file > b.file ? 1 : a.line - b.line));
  if (argv.includes('--json')) { console.log(JSON.stringify(viol, null, 1)); }
  else {
    for (const v of viol) {
      console.error(`${v.file}:${v.line}: [${v.rule}] ${v.msg}`);
      if (v.text) console.error('    ' + v.text.trim().slice(0, 160));
    }
    if (viol.length) console.error(`\n${title}: ${viol.length} ihlal`);
    else console.log(`${title}: temiz`);
  }
  return viol.length ? 1 : 0;
}

function filesFromArgs(argv, root) {
  const i = argv.indexOf('--files');
  if (i < 0) return null;
  const out = [];
  for (let j = i + 1; j < argv.length && !argv[j].startsWith('--'); j++) {
    const p = path.isAbsolute(argv[j]) ? argv[j] : path.resolve(process.cwd(), argv[j]);
    out.push(p);
  }
  return out.filter((p) => fs.existsSync(p) && toPosix(path.relative(root, p)) && !toPosix(path.relative(root, p)).startsWith('..'));
}

module.exports = { parse, runRules, walk, toPosix, projectRoot, report, filesFromArgs, hasNonZeroNumber, strOf, STR_MARK, IGNORE_RE, ALLOW_FIELD_RE, markerOn, joinCode, lineAt };
