#!/usr/bin/env node
'use strict';
/**
 * Yerel admin paneli — tool/admin betiklerini tarayıcıdan, tek butonla çalıştırır (yalnızca bu bilgisayar).
 *
 *   Masaüstündeki "GÜ Admin Paneli" uygulaması başlatır (tool/admin/panel/make_launcher.sh kurar).
 *   Elle: GOOGLE_APPLICATION_CREDENTIALS=~/.secrets/gu-kulupler-admin.json node tool/admin/panel.js [--port 4848]
 *
 * Nasıl çalışır:
 *  - Betikler DEĞİŞTİRİLMEDEN alt süreç olarak koşar; çıktıları panele düşer. Her işlem önce KURU çalışır (önizleme),
 *    "Evet, uygula" deyince `--yes` + panel onayı (GU_ADMIN_PANEL_CONFIRM = proje kimliği) ile yeniden koşar.
 *  - Yalnızca 127.0.0.1'de dinler; Host / Origin / özel başlık denetimi başka sitelerin ve DNS yeniden bağlamanın
 *    istek atmasını engeller. Aynı anda tek işlem. Anahtar REPO DIŞINDA (D-36); panel anahtarı okumaz, betiğe yolunu
 *    verir. Belge / hesap silinmez (D-10). 2 saat boşta kalınca kendiliğinden kapanır.
 */
const { spawn } = require('child_process');
const fs = require('fs');
const http = require('http');
const path = require('path');
const crypto = require('crypto');
const { UsageError, parseArgs, resolveTarget } = require('./lib/admin_cli');
const { SCRIPTS, buildArgs } = require('./lib/panel_spec');

const NAME = 'panel';
const SPEC = { values: ['--port', '--key'], flags: [] };
const HTML_FILE = path.join(__dirname, 'panel', 'index.html');
const BODY_MAX = 16 * 1024;
const OUTPUT_MAX = 200 * 1024;
const RUN_TIMEOUT_MS = 15 * 60 * 1000;
const IDLE_SHUTDOWN_MS = 2 * 60 * 60 * 1000;
const PANEL_HEADER = 'x-gu-panel';

/** Alt süreçte betiği koşar; çıktı (stdout + stderr) ve çıkış kodu. */
function runScript(file, args, env) {
  return new Promise((resolve) => {
    const child = spawn(process.execPath, [path.join(__dirname, file), ...args], {
      cwd: path.resolve(__dirname, '..', '..'),
      env,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    let output = '';
    const add = (chunk) => {
      if (output.length < OUTPUT_MAX) output += chunk.toString('utf8');
    };
    child.stdout.on('data', add);
    child.stderr.on('data', add);
    const timer = setTimeout(() => child.kill('SIGTERM'), RUN_TIMEOUT_MS);
    child.on('close', (code) => {
      clearTimeout(timer);
      resolve({ code: code ?? 1, output: output.slice(0, OUTPUT_MAX) });
    });
    child.on('error', (e) => {
      clearTimeout(timer);
      resolve({ code: 1, output: `başlatılamadı: ${e.message}` });
    });
  });
}

/**
 * Panel sunucusu. `run` testte sahte koşucuyla değiştirilir.
 * @param {{projectId: string, keyPath: string, port: number, run?: Function, onIdle?: Function}} config
 */
function createPanelServer({ projectId, keyPath, port, run = runScript, onIdle = () => {} }) {
  const hosts = new Set([`127.0.0.1:${port}`, `localhost:${port}`]);
  const origins = new Set([`http://127.0.0.1:${port}`, `http://localhost:${port}`]);
  let busy = false;
  let idleTimer = null;
  const touch = () => {
    clearTimeout(idleTimer);
    idleTimer = setTimeout(onIdle, IDLE_SHUTDOWN_MS);
    idleTimer.unref?.();
  };
  touch();

  const send = (res, status, body, headers = {}) => {
    const isJson = typeof body !== 'string';
    res.writeHead(status, {
      'Content-Type': isJson ? 'application/json; charset=utf-8' : 'text/html; charset=utf-8',
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
      'Referrer-Policy': 'no-referrer',
      ...headers,
    });
    res.end(isJson ? JSON.stringify(body) : body);
  };

  const readJson = (req) => new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on('data', (c) => {
      size += c.length;
      if (size > BODY_MAX) {
        reject(new Error('istek çok büyük'));
        req.destroy();
      } else chunks.push(c);
    });
    req.on('end', () => {
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}'));
      } catch (e) {
        reject(new Error('geçersiz JSON'));
      }
    });
    req.on('error', reject);
  });

  return http.createServer(async (req, res) => {
    if (!hosts.has(req.headers.host || '')) return send(res, 403, { error: 'izinsiz Host' });
    const url = new URL(req.url, `http://${req.headers.host}`);
    touch();

    if (req.method === 'GET' && url.pathname === '/health') return send(res, 200, { ok: true });
    if (req.method === 'GET' && url.pathname === '/') {
      const nonce = crypto.randomBytes(16).toString('base64');
      const html = fs.readFileSync(HTML_FILE, 'utf8').replaceAll('__NONCE__', nonce);
      return send(res, 200, html, {
        'Content-Security-Policy': `default-src 'none'; script-src 'nonce-${nonce}'; style-src 'unsafe-inline'; connect-src 'self'; img-src 'self' data:; base-uri 'none'; form-action 'none'; frame-ancestors 'none'`,
      });
    }

    // API: aynı köken + özel başlık (başka siteler bu başlıkla istek atamaz; CORS ön isteğine yanıt verilmez).
    if (!url.pathname.startsWith('/api/')) return send(res, 404, { error: 'bulunamadı' });
    const origin = req.headers.origin;
    if (origin && !origins.has(origin)) return send(res, 403, { error: 'izinsiz köken' });
    if (req.headers[PANEL_HEADER] !== '1') return send(res, 403, { error: 'panel başlığı yok' });

    if (req.method === 'GET' && url.pathname === '/api/info') {
      const scripts = Object.fromEntries(Object.entries(SCRIPTS).map(([id, s]) => [id, { title: s.title, values: s.values, flags: s.flags }]));
      return send(res, 200, { projectId, keyFile: path.basename(keyPath), scripts });
    }

    if (req.method === 'POST' && url.pathname === '/api/run') {
      if (!String(req.headers['content-type'] || '').startsWith('application/json')) return send(res, 415, { error: 'JSON bekleniyor' });
      if (busy) return send(res, 409, { error: 'başka bir işlem sürüyor' });
      let body;
      let built;
      try {
        body = await readJson(req);
        built = buildArgs(body.id, body, body.apply === true);
      } catch (e) {
        return send(res, 400, { error: e.message });
      }
      const env = { ...process.env, GOOGLE_APPLICATION_CREDENTIALS: keyPath };
      delete env.GU_ADMIN_PANEL_CONFIRM;
      if (body.apply === true) env.GU_ADMIN_PANEL_CONFIRM = projectId;
      busy = true;
      const started = Date.now();
      try {
        const result = await run(built.file, built.args, env);
        return send(res, 200, { ...result, apply: body.apply === true, durationMs: Date.now() - started });
      } finally {
        busy = false;
      }
    }

    if (req.method === 'POST' && url.pathname === '/api/shutdown') {
      send(res, 200, { ok: true });
      return setImmediate(onIdle);
    }
    return send(res, 404, { error: 'bulunamadı' });
  });
}

function main() {
  const args = parseArgs(process.argv.slice(2), SPEC);
  const port = args.port ? Number(args.port) : 4848;
  if (!Number.isInteger(port) || port < 1024 || port > 65535) throw new UsageError('--port 1024–65535 olmalı');
  let target;
  try {
    target = resolveTarget({ emulator: false, project: null, key: args.key }, process.env);
  } catch (e) {
    console.error(`${NAME}: ${e.message}`);
    process.exit(2);
  }
  const server = createPanelServer({
    projectId: target.projectId,
    keyPath: target.keyPath,
    port,
    onIdle: () => {
      console.log(`${NAME}: kapanıyor`);
      server.close(() => process.exit(0));
      setTimeout(() => process.exit(0), 2000).unref();
    },
  });
  server.on('error', (e) => {
    console.error(`${NAME}: ${e.code === 'EADDRINUSE' ? `${port} portu kullanımda (panel zaten açık olabilir)` : e.message}`);
    process.exit(1);
  });
  server.listen(port, '127.0.0.1', () => {
    console.log(`${NAME}: http://127.0.0.1:${port}/ · proje ${target.projectId}`);
  });
}

if (require.main === module) {
  try {
    main();
  } catch (e) {
    console.error(`${NAME}: ${e.message}`);
    process.exit(e instanceof UsageError ? 2 : 1);
  }
}

module.exports = { createPanelServer, runScript };
