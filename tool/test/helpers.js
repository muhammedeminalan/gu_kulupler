'use strict';
// tool/test öz-testleri için ortak yardımcılar (CD-79). Test dosyası değildir (`*.test.js` değil).
const { spawnSync } = require('node:child_process');
const path = require('node:path');

const TOOL_DIR = path.resolve(__dirname, '..');
const FIXTURES = path.join(__dirname, 'fixtures');

/** tool/test/fixtures altındaki yol */
const fixture = (...parts) => path.join(FIXTURES, ...parts);

/** tool/<script> betiğini ayrı süreçte çalıştırır → { code, stdout, stderr } */
function runTool(script, args) {
  const r = spawnSync(process.execPath, [path.join(TOOL_DIR, script), ...args], { encoding: 'utf8' });
  if (r.error) throw r.error;
  return { code: r.status, stdout: r.stdout, stderr: r.stderr };
}

/**
 * `--json` çıktısını çözer: stdout tamamen JSON ise onu, değilse `{`/`[` ile başlayan son satırı
 * (check_arb_parity JSON'u uyarı/özet satırlarıyla birlikte yazar).
 */
function parseJson(stdout) {
  try { return JSON.parse(stdout); } catch (e) { /* satır satır dene */ }
  const line = stdout.split(/\r?\n/).reverse().find((l) => /^[{[]/.test(l.trim()));
  if (!line) throw new Error('JSON çıktı yok:\n' + stdout);
  return JSON.parse(line);
}

/** --json ile çalıştırıp { code, json, stderr } döndürür */
function runJson(script, args) {
  const r = runTool(script, [...args, '--json']);
  return { code: r.code, json: parseJson(r.stdout), stderr: r.stderr };
}

module.exports = { TOOL_DIR, FIXTURES, fixture, runTool, runJson, parseJson };
