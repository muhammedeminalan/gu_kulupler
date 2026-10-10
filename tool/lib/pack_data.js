'use strict';
// Paket verisi okuyucuları (registry, task-map, progress, screens-actions). Bağımlılık yok.
const fs = require('fs');
const path = require('path');

function readJson(root, rel, optional) {
  const p = path.join(root, rel);
  if (!fs.existsSync(p)) {
    if (optional) return null;
    throw new Error(`Dosya yok: ${rel} (zip proje köküne açıldı mı? \`bash tool/verify_pack.sh\`)`);
  }
  try { return JSON.parse(fs.readFileSync(p, 'utf8')); } catch (e) { throw new Error(`${rel}: geçersiz JSON — ${e.message}`); }
}

const registry = (root) => readJson(root, 'design/extracted/registry.json');
const inventory = (root) => readJson(root, 'design/extracted/screens-actions.json');
const taskMap = (root) => readJson(root, 'docs/task-map.json');
const progress = (root) => readJson(root, 'docs/progress.json');

function writeProgress(root, obj) {
  obj.updated = new Date().toISOString();
  const p = path.join(root, 'docs/progress.json');
  const tmp = p + '.tmp';
  fs.writeFileSync(tmp, JSON.stringify(obj, null, 2) + '\n');
  fs.renameSync(tmp, p);
}

/** ID → kategori ('screen'|'sheet'|'dialog'|'toast'|'menu') */
function kindOfId(id) {
  if (/^TST-/.test(id)) return 'toast';
  if (/^SHT-/.test(id)) return 'sheet';
  if (/^DLG-/.test(id)) return 'dialog';
  if (/-MENU$/.test(id)) return 'menu';
  return 'screen';
}

/** SHT-05 → sht05 · TST-X12 → tstX12 */
function enumMember(id) { return id.slice(0, 3).toLowerCase() + id.slice(4); }

/** '*' joker → RegExp (tam eşleşme) */
function globToRe(g) { return new RegExp('^' + g.replace(/[.+?^${}()|[\]\\]/g, '\\$&').replace(/\*/g, '.*') + '$'); }

/**
 * Kalıp dosyası okuyucu (tool/design_exempt_actions.txt, tool/design_dynamic_actions.txt; biçim tool/arb_dynamic_keys.txt ile aynı):
 * satır başına bir kalıp (`*` joker), ilk `#` sonrası gerekçe; boş ve yalnızca yorum satırları atlanır.
 * Dosya yoksa boş dizi.
 * @returns {{pattern: string, reason: string, re: RegExp}[]}
 */
function patternFile(root, rel) {
  const p = path.join(root, rel);
  if (!fs.existsSync(p)) return [];
  const out = [];
  for (const raw of fs.readFileSync(p, 'utf8').split(/\r?\n/)) {
    const i = raw.indexOf('#');
    const pattern = (i >= 0 ? raw.slice(0, i) : raw).trim();
    if (!pattern) continue;
    const reason = i >= 0 ? raw.slice(i + 1).trim() : '';
    out.push({ pattern, reason, re: globToRe(pattern) });
  }
  return out;
}

module.exports = { readJson, registry, inventory, taskMap, progress, writeProgress, kindOfId, enumMember, globToRe, patternFile };
