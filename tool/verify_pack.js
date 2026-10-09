#!/usr/bin/env node
'use strict';
/**
 * Claude paketi doğrulayıcısı: zip eksiksiz mi, bozulmadan mı açıldı, iç referanslar tutarlı mı.
 *   node tool/verify_pack.js [--root dir] [--no-hash] [--quick] [--json]
 *   node tool/verify_pack.js --make-manifest        # (paketi hazırlayan için) PACK_MANIFEST.json üretir
 *
 * Kontroller:
 *  V01 gerekli dosyalar (PACK_MANIFEST.json#required)      V02 donmuş dosyaların SHA-256'sı (design/, assets/, demo veri)
 *  V03 JSON'lar geçerli                                     V04 sayılar: 51/34/32/78 · 1072 aksiyon · 48 task · ARB TR=EN
 *  V05 task-map ↔ registry (check_design_coverage --map)    V06 skill/ajan başlıkları
 *  V07 dokümanlardaki dosya yolu başvuruları gerçekten var  V08 settings.json hook hedefleri
 *  V09 ortam: Node ≥ 18, (uyarı) flutter/dart/firebase yolu
 * Çıkış: 0 temiz · 1 hata.
 */
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const cp = require('child_process');
const core = require('./lib/scan_core');

const argv = process.argv.slice(2);
const root = core.projectRoot(argv);
const has = (f) => argv.includes(f);
const errors = [], warns = [];
const E = (rule, msg) => errors.push({ rule, msg });
const W = (rule, msg) => warns.push({ rule, msg });
const exists = (rel) => fs.existsSync(path.join(root, rel));

const FROZEN_PREFIXES = ['design/', 'assets/'];
const FROZEN_FILES = ['tool/seed/demo-data.json'];
const SKIP_WALK = new Set(['.git', 'node_modules', '.dart_tool', 'build', '.cache']);
const MANIFEST_NAME = 'PACK_MANIFEST.json';

function listAll(dir, base, out) {
  out = out || [];
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (SKIP_WALK.has(e.name) || e.name === '.DS_Store') continue;
    const full = path.join(dir, e.name);
    const rel = core.toPosix(path.relative(base, full));
    if (e.isDirectory()) listAll(full, base, out);
    else if (e.isFile()) out.push(rel);
  }
  return out;
}
const sha = (file) => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');

// ── manifest üretimi ───────────────────────────────────────
if (has('--make-manifest')) {
  const all = listAll(root, root).filter((r) => r !== MANIFEST_NAME && !r.startsWith('tool/.cache/')).sort();
  const frozen = {};
  for (const r of all) if (FROZEN_PREFIXES.some((p) => r.startsWith(p)) || FROZEN_FILES.includes(r)) frozen[r] = sha(path.join(root, r));
  const manifest = {
    pack: 'gu-claude-pack', schema: 1, generated: new Date().toISOString().slice(0, 10),
    note: 'required = pakette bulunması gereken dosyalar; frozen = asla değiştirilmeyen (design/, assets/, demo veri) dosyaların SHA-256 özeti.',
    counts: { files: all.length, frozen: Object.keys(frozen).length },
    required: all.filter((r) => !(r in frozen)),
    frozen,
  };
  fs.writeFileSync(path.join(root, MANIFEST_NAME), JSON.stringify(manifest, null, 1) + '\n');
  console.log(`${MANIFEST_NAME}: ${manifest.required.length} gerekli + ${manifest.counts.frozen} donmuş dosya`);
  process.exit(0);
}

// ── V09 ortam ──────────────────────────────────────────────
{
  const major = parseInt(process.versions.node.split('.')[0], 10);
  if (major < 18) E('V09', `Node ${process.versions.node} — Node ≥ 18 gerekli`);
  if (!has('--quick')) {
    for (const [bin, hint] of [['flutter', 'Flutter SDK'], ['dart', 'Dart SDK'], ['git', 'git']]) {
      try { cp.execFileSync(bin, ['--version'], { stdio: 'ignore' }); } catch (e) { W('V09', `${bin} PATH'te yok (${hint}) — kalite kapısı için gerekli`); }
    }
  }
}

// ── V01 / V02 manifest ─────────────────────────────────────
let manifest = null;
if (exists(MANIFEST_NAME)) {
  try { manifest = JSON.parse(fs.readFileSync(path.join(root, MANIFEST_NAME), 'utf8')); } catch (e) { E('V01', `${MANIFEST_NAME} bozuk JSON`); }
} else E('V01', `${MANIFEST_NAME} yok — zip proje köküne açılmamış olabilir`);
if (manifest) {
  const missing = manifest.required.filter((r) => !exists(r));
  if (missing.length) E('V01', `${missing.length} gerekli dosya eksik: ${missing.slice(0, 12).join(', ')}${missing.length > 12 ? ' …' : ''}`);
  const frozenMissing = Object.keys(manifest.frozen).filter((r) => !exists(r));
  if (frozenMissing.length) E('V02', `${frozenMissing.length} donmuş dosya eksik: ${frozenMissing.slice(0, 8).join(', ')}${frozenMissing.length > 8 ? ' …' : ''}`);
  if (!has('--no-hash') && !has('--quick')) {
    const bad = [];
    for (const [r, h] of Object.entries(manifest.frozen)) if (exists(r) && sha(path.join(root, r)) !== h) bad.push(r);
    if (bad.length) E('V02', `${bad.length} donmuş dosya DEĞİŞMİŞ/BOZUK (design/ ve assets/ salt okunur): ${bad.slice(0, 8).join(', ')}${bad.length > 8 ? ' …' : ''}`);
  }
}

// ── V03 JSON ───────────────────────────────────────────────
const jsonFiles = ['design/extracted/registry.json', 'design/extracted/screens-actions.json', 'design/extracted/css-class-usage.json', 'docs/task-map.json', 'docs/progress.json', '.claude/settings.json', 'tool/seed/demo-data.json', 'design/reference-shots/index.json', 'design/generated-reference/typography.json'];
const J = {};
for (const f of jsonFiles) {
  if (!exists(f)) continue;
  try { J[f] = JSON.parse(fs.readFileSync(path.join(root, f), 'utf8')); } catch (e) { E('V03', `${f}: geçersiz JSON — ${e.message}`); }
}

// ── V04 sayılar ────────────────────────────────────────────
{
  const reg = J['design/extracted/registry.json'], inv = J['design/extracted/screens-actions.json'], tm = J['docs/task-map.json'];
  if (reg) {
    const c = [reg.screens.length, reg.sheets.length, reg.dialogs.length, reg.toasts.length];
    if (c.join('/') !== '51/34/32/78') E('V04', `registry sayıları ${c.join('/')} (51/34/32/78 beklenir)`);
  }
  if (inv) {
    const n = Object.values(inv).reduce((a, v) => a + (v.actionCount || 0), 0);
    if (n !== 1072) E('V04', `aksiyon toplamı ${n} (1072 beklenir)`);
  }
  if (tm && tm.tasks.length !== 48) E('V04', `task sayısı ${tm.tasks.length} (48 beklenir)`);
  try {
    const dirArb = path.join(root, 'lib/l10n');
    const k = (l) => Object.keys(JSON.parse(fs.readFileSync(path.join(dirArb, `app_${l}.arb`), 'utf8'))).filter((x) => !x.startsWith('@')).length;
    const tr = k('tr'), en = k('en');
    if (tr !== en) E('V04', `ARB anahtar sayıları farklı: TR ${tr} ≠ EN ${en}`);
    else if (![1421, 1235].includes(tr)) W('V04', `ARB anahtar sayısı ${tr} (ham 1421 ya da budanmış 1235 beklenir)`);
  } catch (e) { E('V04', `lib/l10n ARB okunamadı: ${e.message}`); }
}

// ── V05 task-map ↔ registry ────────────────────────────────
if (exists('tool/check_design_coverage.js') && J['docs/task-map.json'] && J['design/extracted/registry.json']) {
  const r = cp.spawnSync(process.execPath, [path.join(root, 'tool/check_design_coverage.js'), '--map', '--root', root], { encoding: 'utf8' });
  if (r.status !== 0) E('V05', `check_design_coverage --map başarısız:\n${(r.stderr || r.stdout).trim().split('\n').slice(0, 8).join('\n')}`);
}

// ── V06 skill / ajan başlıkları ────────────────────────────
function frontmatter(file) {
  const t = fs.readFileSync(file, 'utf8');
  const m = /^---\r?\n([\s\S]*?)\r?\n---/.exec(t);
  if (!m) return null;
  const o = {};
  for (const ln of m[1].split(/\r?\n/)) { const mm = /^([A-Za-z_-]+):\s*(.*)$/.exec(ln); if (mm) o[mm[1]] = mm[2].trim(); }
  return o;
}
{
  const sd = path.join(root, '.claude/skills');
  if (fs.existsSync(sd)) {
    for (const d of fs.readdirSync(sd, { withFileTypes: true })) {
      if (!d.isDirectory()) continue;
      const f = path.join(sd, d.name, 'SKILL.md');
      if (!fs.existsSync(f)) { E('V06', `skills/${d.name}/SKILL.md yok`); continue; }
      const fm = frontmatter(f);
      if (!fm || fm.name !== d.name) E('V06', `skills/${d.name}: frontmatter name ("${fm && fm.name}") klasör adıyla aynı olmalı`);
      else if (!fm.description || fm.description.length < 20) E('V06', `skills/${d.name}: description eksik/kısa`);
    }
  }
  const ad = path.join(root, '.claude/agents');
  if (fs.existsSync(ad)) {
    for (const f of fs.readdirSync(ad)) {
      if (!f.endsWith('.md')) continue;
      const fm = frontmatter(path.join(ad, f));
      if (!fm || fm.name !== f.replace(/\.md$/, '')) E('V06', `agents/${f}: frontmatter name dosya adıyla aynı olmalı`);
      else if (!fm.description) E('V06', `agents/${f}: description eksik`);
    }
  }
}

// ── V07 doküman başvuruları ────────────────────────────────
const LATER = [
  /^docs\/PLAN\.md$/, /^docs\/design-analysis\.md$/, /^docs\/widget-catalog\.md$/, /^docs\/token-map\.md$/, /^docs\/plans(\/|$)/,
  /^design\/prototype-only-arb(\/|$)/, /^tool\/\.cache(\/|$)/, /^tool\/arb_dynamic_keys\.txt$/, /^tool\/seed\/seed_emulator\.js$/,
  /^docs\/README\.TEMPLATE/,
];
{
  const mdFiles = listAll(root, root).filter((r) => r.endsWith('.md') && (r === 'CLAUDE.md' || /^(docs|prompts|\.claude|tool)\//.test(r)) && !r.startsWith('design/') && !r.startsWith('docs/reference/') && !r.startsWith('docs/brief/'));
  const seen = new Set();
  const rxTick = /`([^`\n]+)`/g;
  const rxLink = /\]\(([^)\s]+)\)/g;
  const PATH_RE = /^(?:\.\/)?(CLAUDE\.md|(?:docs|prompts|tool|design|assets|\.claude)\/[A-Za-z0-9_.\-\/]+)$/;
  for (const f of mdFiles) {
    const text = fs.readFileSync(path.join(root, f), 'utf8');
    const cands = [];
    let m;
    while ((m = rxTick.exec(text))) {
      const whole = m[1].trim();
      // boşluklu yol (ör. "GU Kulupler - Standalone.html"): tamamı var olan bir yolsa tek parça say
      if (/\s/.test(whole) && /^(?:docs|prompts|tool|design|assets|\.claude)\//.test(whole) && exists(whole.replace(/^\.\//, ''))) continue;
      cands.push(whole.split(/\s+/)[0]);
    }
    while ((m = rxLink.exec(text))) if (!/^https?:/.test(m[1])) cands.push(m[1]);
    for (let c of cands) {
      c = c.replace(/[#:].*$/, '').replace(/[.,;)]+$/, '');
      if (!PATH_RE.test(c)) continue;
      if (/\bT-xx|\bxx\b|\bNN\b|\*|<|>/.test(c)) continue;
      const rel = c.replace(/^\.\//, '');
      // bulunduğu klasöre göre göreli bağlantılar (ör. ../docs/x.md) PATH_RE'ye girmez; yalnızca kök-göreli yollar denetlenir
      if (LATER.some((re) => re.test(rel))) continue;
      const key = f + '→' + rel;
      if (seen.has(key)) continue;
      seen.add(key);
      if (!exists(rel)) E('V07', `${f}: başvurulan yol yok → ${rel}`);
    }
  }
}

// ── V08 settings hook hedefleri ────────────────────────────
{
  const s = J['.claude/settings.json'];
  if (s && s.hooks) {
    const cmds = JSON.stringify(s.hooks).match(/tool\/[A-Za-z0-9_\/.\-]+/g) || [];
    for (const c of new Set(cmds)) if (!exists(c)) E('V08', `.claude/settings.json hook hedefi yok: ${c}`);
  }
  for (const sh of ['tool/quality_gate.sh', 'tool/codegen.sh', 'tool/hooks/post_edit.sh', 'tool/check_hardcode.sh', 'tool/check_no_hard_delete.sh', 'tool/check_boundaries.sh']) {
    if (exists(sh)) {
      try { fs.accessSync(path.join(root, sh), fs.constants.X_OK); } catch (e) { W('V08', `${sh} çalıştırılabilir değil → chmod +x tool/*.sh tool/hooks/*.sh`); }
    }
  }
}

// ── çıktı ──────────────────────────────────────────────────
if (has('--json')) { console.log(JSON.stringify({ errors, warnings: warns }, null, 1)); process.exit(errors.length ? 1 : 0); }
for (const w of warns) console.log(`UYARI [${w.rule}] ${w.msg}`);
for (const e of errors) console.error(`HATA [${e.rule}] ${e.msg}`);
if (errors.length) {
  console.error(`\nverify_pack: ${errors.length} hata${warns.length ? `, ${warns.length} uyarı` : ''}`);
  console.error('Zip, Flutter projesinin KÖKÜNE açılmış olmalı (CLAUDE.md, docs/, design/ yan yana). Eksik/bozuk dosyaları zip\'ten yeniden aç.');
  process.exit(1);
}
console.log(`verify_pack: temiz${manifest ? ` — ${manifest.required.length} gerekli + ${Object.keys(manifest.frozen).length} donmuş dosya` : ''}${warns.length ? `, ${warns.length} uyarı` : ''}`);
process.exit(0);
